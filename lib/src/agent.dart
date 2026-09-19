import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'bounded_stream.dart';
import 'contracts.dart';
import 'model_store.dart';
import 'models.dart';

/// Computes a reply from a finalized transcript.
typedef LocalReplyLogic = Future<String> Function(String transcript);

/// Owns one bounded, half-duplex local voice session.
final class LocalVoiceAgent {
  LocalVoiceAgent._(this._native, this._logic, this.outputRate);

  /// Validates assets and creates the inactive native session.
  static Future<LocalVoiceAgent> create({
    required LocalModelBundle models,
    LocalReplyLogic? logic,
    bool useLocalLlm = false,
    ConversationMode mode = ConversationMode.halfDuplex,
    LocalModelStore? modelStore,
    NativeVoicePlatform? nativePlatform,
  }) async {
    if (mode == ConversationMode.fullDuplexRequired) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'Full duplex is not qualified.',
        fatal: false,
      );
    }
    final checked = await (modelStore ?? const FileModelStore()).validate(
      models,
    );
    final root = await Directory(models.directory).resolveSymbolicLinks();
    final paths = <String, String>{
      for (final entry in checked.files.where(
        (entry) => entry.role != 'license',
      ))
        entry.role: '$root${Platform.pathSeparator}${entry.path}',
    };
    if (useLocalLlm && !paths.containsKey('llmModel')) {
      throw const AgentFailure(
        AgentErrorCode.missingAsset,
        'llmModel is required.',
        fatal: false,
      );
    }
    if (!useLocalLlm) paths.remove('llmModel');
    final native = nativePlatform ?? MethodChannelVoicePlatform();
    try {
      final agent = LocalVoiceAgent._(
        native,
        useLocalLlm ? null : (logic ?? ((text) async => 'You said: $text')),
        await native.create(paths: paths, mode: 'halfDuplex'),
      );
      agent._events = BoundedEventStream<AgentEvent>(
        capacity: 32,
        terminalValue: () => AgentEvent(
          sequence: ++agent._eventSequence,
          generation: agent._generation,
          kind: AgentEventKind.fault,
          lifecycle: AgentLifecycle.failed,
          activity: TurnActivity.idle,
          failure: capacityFailure(),
        ),
        onOverflow: () async {
          agent.lifecycle = AgentLifecycle.failed;
          agent._started = false;
          agent._invalidate();
          try {
            await native.stop();
          } catch (_) {}
        },
      );
      return agent;
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
  }

  final NativeVoicePlatform _native;
  final LocalReplyLogic? _logic;
  late BoundedEventStream<AgentEvent> _events;
  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;
  Future<void>? _logicFuture;
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _disposing = false;
  bool _polling = false;
  bool _logicBlocked = false;
  int _generation = 0;
  int _epoch = 0;
  int _eventSequence = 0;
  int _lastNativeSequence = 0;

  /// Source-verified capabilities; these do not imply physical qualification.
  final AgentCapabilities capabilities = const AgentCapabilities();

  /// Native output sample rate.
  final int outputRate;

  /// Current lifecycle state.
  AgentLifecycle lifecycle = AgentLifecycle.ready;

  /// Current turn activity.
  TurnActivity activity = TurnActivity.idle;

  /// Bounded single-listener events.
  Stream<AgentEvent> get events => _events.stream;

  /// Starts capture; concurrent calls share one operation.
  Future<void> start() {
    _live();
    if (lifecycle == AgentLifecycle.failed) {
      return Future<void>.error(
        const AgentFailure(
          AgentErrorCode.invalidState,
          'The agent failed.',
          fatal: true,
        ),
      );
    }
    if (_started) return Future<void>.value();
    if (_startFuture != null) return _startFuture!;
    if (_stopFuture != null) {
      return Future<void>.error(
        const AgentFailure(
          AgentErrorCode.invalidState,
          'Stopping.',
          fatal: false,
        ),
      );
    }
    final epoch = _epoch;
    final result = _start(epoch);
    _startFuture = result;
    unawaited(
      result.then(
        (_) {
          if (identical(_startFuture, result)) _startFuture = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_startFuture, result)) _startFuture = null;
        },
      ),
    );
    return result;
  }

  Future<void> _start(int epoch) async {
    try {
      await _native.start();
      if (_disposed || epoch != _epoch) {
        await _native.stop();
        return;
      }
      _started = true;
      lifecycle = AgentLifecycle.running;
      activity = TurnActivity.listening;
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _poll(epoch),
      );
    } on PlatformException catch (e) {
      throw _platformFailure(e);
    }
  }

  /// Interrupts native work and invalidates late replies.
  Future<void> interrupt() async {
    _live();
    _advanceGeneration();
    activity = TurnActivity.interrupting;
    try {
      await _native.interrupt();
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
  }

  /// Stops capture; concurrent calls share one operation.
  Future<void> stop() {
    if (_disposed || (!_started && _startFuture == null)) {
      return Future<void>.value();
    }
    if (_stopFuture != null) return _stopFuture!;
    final result = _stop();
    _stopFuture = result;
    unawaited(
      result.then(
        (_) {
          if (identical(_stopFuture, result)) _stopFuture = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_stopFuture, result)) _stopFuture = null;
        },
      ),
    );
    return result;
  }

  Future<void> _stop() async {
    lifecycle = AgentLifecycle.stopping;
    _invalidate();
    try {
      await _native.stop();
    } on PlatformException catch (error) {
      lifecycle = AgentLifecycle.failed;
      throw _platformFailure(error);
    } finally {
      _started = false;
      if (lifecycle == AgentLifecycle.stopping) {
        lifecycle = _disposed ? AgentLifecycle.disposed : AgentLifecycle.ready;
      }
      activity = TurnActivity.idle;
    }
  }

  /// Releases the session and closes events; repeated calls share shutdown.
  Future<void> dispose() {
    if (_disposeFuture != null) return _disposeFuture!;
    if (_disposed) return Future<void>.value();
    _disposeFuture = _dispose();
    unawaited(
      _disposeFuture!.then(
        (_) {
          _disposeFuture = null;
        },
        onError: (Object error, StackTrace stackTrace) {
          _disposeFuture = null;
        },
      ),
    );
    return _disposeFuture!;
  }

  Future<void> _dispose() async {
    _disposing = true;
    _invalidate();
    try {
      await _native.dispose();
      _disposed = true;
      _started = false;
      lifecycle = AgentLifecycle.disposed;
      activity = TurnActivity.idle;
      await _events.close();
    } on PlatformException catch (error) {
      lifecycle = AgentLifecycle.failed;
      activity = TurnActivity.idle;
      throw _platformFailure(error);
    } finally {
      _disposing = false;
    }
  }

  void _invalidate() {
    _generation++;
    _epoch++;
    _timer?.cancel();
    _timer = null;
    _logicBlocked = _logicFuture != null;
  }

  void _advanceGeneration() {
    _generation++;
    _logicBlocked = _logicFuture != null;
  }

  Future<void> _poll(int epoch) async {
    if (_polling || _disposed || !_started || epoch != _epoch) return;
    _polling = true;
    try {
      final values = await _native.poll();
      if (_disposed || !_started || epoch != _epoch) return;
      for (final value in values) {
        _accept(value);
        if (_disposed || !_started || epoch != _epoch) {
          break;
        }
      }
    } on PlatformException catch (e) {
      _fatal(_platformFailure(e));
    } catch (e) {
      _fatal(AgentFailure(AgentErrorCode.inferenceFailed, '$e', fatal: true));
    } finally {
      _polling = false;
    }
  }

  void _accept(Map<String, Object?> value) {
    final kind = '${value['kind']}';
    if (kind == 'suspended') {
      _invalidate();
      _started = false;
      lifecycle = AgentLifecycle.suspended;
      activity = TurnActivity.idle;
      _events.add(
        AgentEvent(
          sequence: ++_eventSequence,
          generation: value['generation'] is int
              ? value['generation']! as int
              : _generation,
          kind: AgentEventKind.state,
          lifecycle: lifecycle,
          activity: activity,
        ),
      );
      return;
    }
    final sequence = value['sequence'];
    final generation = value['generation'];
    final eventActivity = _activity('${value['activity']}');
    if (sequence is! int || generation is! int || eventActivity == null) {
      _fatal(
        const AgentFailure(
          AgentErrorCode.invalidAsset,
          'Malformed native event.',
          fatal: true,
        ),
      );
      return;
    }
    if (generation < _generation || sequence <= _lastNativeSequence) return;
    _lastNativeSequence = sequence;
    _generation = generation;
    activity = eventActivity;
    final eventKind = switch (kind) {
      'state' => AgentEventKind.state,
      'partial' => AgentEventKind.partialTranscript,
      'final' => AgentEventKind.finalTranscript,
      'reply' => AgentEventKind.replyText,
      'error' => AgentEventKind.fault,
      _ => null,
    };
    if (eventKind == null) {
      _fatal(
        const AgentFailure(
          AgentErrorCode.invalidAsset,
          'Unknown native event.',
          fatal: true,
        ),
      );
      return;
    }
    final code = _code('${value['code']}');
    final failure = kind == 'error'
        ? AgentFailure(
            code,
            value['text'] as String? ?? 'Native failure.',
            fatal:
                code == AgentErrorCode.capacityExceeded ||
                code == AgentErrorCode.inferenceFailed,
          )
        : null;
    _events.add(
      AgentEvent(
        sequence: ++_eventSequence,
        generation: generation,
        kind: eventKind,
        lifecycle: lifecycle,
        activity: activity,
        text: value['text'] as String?,
        failure: failure,
      ),
    );
    if (failure?.fatal ?? false) {
      _fatal(failure!);
      return;
    }
    if (kind == 'final' && value['text'] is String) {
      _logicRun(generation, value['text']! as String);
    }
  }

  void _logicRun(int generation, String text) {
    if (_logic == null) return;
    if (_logicBlocked || _logicFuture != null) {
      _emit(
        const AgentFailure(
          AgentErrorCode.capacityExceeded,
          'Previous logic has not settled.',
          fatal: false,
        ),
      );
      unawaited(_backgroundInterrupt());
      return;
    }
    Future<String> reply;
    try {
      reply = _logic(text);
    } catch (e) {
      _logicError(generation, e);
      return;
    }
    final run = reply
        .then((result) async {
          if (result.runes.length > 240 || utf8.encode(result).length > 960) {
            throw const AgentFailure(
              AgentErrorCode.capacityExceeded,
              'Reply exceeds bounds.',
              fatal: false,
            );
          }
          if (!_disposed && generation == _generation) {
            await _native.reply(generation: generation, text: result);
          }
        })
        .catchError((Object e, StackTrace _) {
          _logicError(generation, e);
        })
        .whenComplete(() {
          _logicFuture = null;
          _logicBlocked = false;
        });
    _logicFuture = run;
  }

  void _logicError(int generation, Object error) {
    if (!_disposed && generation == _generation) {
      _emit(
        error is AgentFailure
            ? error
            : AgentFailure(
                AgentErrorCode.inferenceFailed,
                '$error',
                fatal: false,
              ),
      );
      _advanceGeneration();
      unawaited(_backgroundInterrupt());
    }
  }

  void _emit(AgentFailure error) => _events.add(
    AgentEvent(
      sequence: ++_eventSequence,
      generation: _generation,
      kind: AgentEventKind.fault,
      lifecycle: lifecycle,
      activity: activity,
      failure: error,
    ),
  );
  void _fatal(AgentFailure error) {
    lifecycle = AgentLifecycle.failed;
    activity = TurnActivity.idle;
    _emit(error);
    _started = false;
    _invalidate();
    unawaited(_backgroundStop());
  }

  Future<void> _backgroundInterrupt() async {
    try {
      await _native.interrupt();
    } on PlatformException catch (error) {
      _fatal(_platformFailure(error));
    } catch (error) {
      _fatal(
        AgentFailure(AgentErrorCode.inferenceFailed, '$error', fatal: true),
      );
    }
  }

  Future<void> _backgroundStop() async {
    try {
      await _native.stop();
    } on PlatformException catch (error) {
      _emit(_platformFailure(error));
    } catch (error) {
      _emit(
        AgentFailure(AgentErrorCode.inferenceFailed, '$error', fatal: true),
      );
    }
  }

  void _live() {
    if (_disposed || _disposing) {
      throw const AgentFailure(
        AgentErrorCode.invalidState,
        'Disposed.',
        fatal: false,
      );
    }
  }
}

TurnActivity? _activity(String v) => switch (v) {
  'idle' => TurnActivity.idle,
  'listening' => TurnActivity.listening,
  'recognizing' => TurnActivity.recognizing,
  'thinking' => TurnActivity.thinking,
  'speaking' => TurnActivity.speaking,
  'interrupting' => TurnActivity.interrupting,
  _ => null,
};
AgentErrorCode _code(String v) => AgentErrorCode.values.firstWhere(
  (e) => e.name == v,
  orElse: () => AgentErrorCode.inferenceFailed,
);
AgentFailure _platformFailure(PlatformException e) =>
    AgentFailure(_code(e.code), e.message ?? e.code, fatal: false);

/// Flutter method-channel native platform.
final class MethodChannelVoicePlatform implements NativeVoicePlatform {
  /// Creates the production channel bridge.
  MethodChannelVoicePlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flutter_local_voice_agent');
  final MethodChannel _channel;
  @override
  Future<int> create({
    required Map<String, String> paths,
    required String mode,
  }) async {
    final rate = objectMap(
      await _channel.invokeMethod<Object?>('create', {
        'paths': paths,
        'mode': mode,
      }),
    )['outputRate'];
    if (rate is! int || rate <= 0) {
      throw const FormatException('Invalid output rate.');
    }
    return rate;
  }

  @override
  Future<void> dispose() => _channel.invokeMethod<void>('dispose');
  @override
  Future<void> interrupt() => _channel.invokeMethod<void>('interrupt');
  @override
  Future<List<Map<String, Object?>>> poll() async {
    final result = await _channel.invokeMethod<Object?>('poll');
    if (result is! List || result.length > 32) {
      throw const FormatException('Invalid poll response.');
    }
    return result.map(objectMap).toList(growable: false);
  }

  @override
  Future<void> reply({required int generation, required String text}) =>
      _channel.invokeMethod<void>('reply', {
        'generation': generation,
        'text': text,
      });
  @override
  Future<void> start() => _channel.invokeMethod<void>('start');
  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}
