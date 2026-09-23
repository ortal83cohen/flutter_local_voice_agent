import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bounded_stream.dart';
import 'contracts.dart';
import 'model_store.dart';
import 'models.dart';
import 'native_paths_stub.dart' if (dart.library.io) 'native_paths_io.dart';
import 'web_defaults.dart';

/// Test-only host override. When true, create takes the web session path.
@visibleForTesting
bool? debugOverrideIsWeb;

/// Computes a reply from a finalized transcript.
typedef LocalReplyLogic = Future<String> Function(String transcript);

/// Owns one bounded, half-duplex local voice session.
final class LocalVoiceAgent {
  LocalVoiceAgent._(
    this._session,
    this._logic,
    this.outputRate,
    this._speakerId,
  );

  /// Validates assets and creates the inactive session.
  static Future<LocalVoiceAgent> create({
    required LocalModelBundle models,
    LocalReplyLogic? logic,
    bool useLocalLlm = false,
    ConversationMode mode = ConversationMode.halfDuplex,
    LocalModelStore? modelStore,
    NativeVoicePlatform? nativePlatform,
    VoiceSessionBackend? sessionBackend,
    int speakerId = 0,
  }) async {
    if (mode == ConversationMode.fullDuplexRequired) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'Full duplex is not qualified.',
        fatal: false,
      );
    }
    if (speakerId < 0) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'Speaker id must be greater than or equal to zero.',
        fatal: false,
      );
    }
    if (_isWebHost()) {
      return _createWeb(
        models: models,
        logic: logic,
        useLocalLlm: useLocalLlm,
        modelStore: modelStore,
        sessionBackend: sessionBackend,
        speakerId: speakerId,
      );
    }
    _refuseUnsupportedNativeHost();
    final checked = await (modelStore ?? const FileModelStore()).validate(
      models,
    );
    final paths = await nativeModelPathMap(checked, models);
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
      final outputRate = await native.create(
        paths: paths,
        mode: 'halfDuplex',
        speakerId: speakerId,
      );
      return await _bindSession(
        session: _NativeSessionBackend(native, outputRate),
        logic: useLocalLlm
            ? null
            : (logic ?? ((text) async => 'You said: $text')),
        outputRate: outputRate,
        speakerId: speakerId,
      );
    } on MissingPluginException catch (error) {
      throw AgentFailure(
        AgentErrorCode.unsupportedProfile,
        error.message ??
            'The native voice plugin is not registered on this host.',
        fatal: false,
      );
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
  }

  static Future<LocalVoiceAgent> _createWeb({
    required LocalModelBundle models,
    required LocalReplyLogic? logic,
    required bool useLocalLlm,
    required LocalModelStore? modelStore,
    required VoiceSessionBackend? sessionBackend,
    required int speakerId,
  }) async {
    if (useLocalLlm) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'Local LLM is not supported on Flutter web.',
        fatal: false,
      );
    }
    final store =
        modelStore ?? webModelStoreDefault?.call() ?? const FileModelStore();
    webCreateBundle = models;
    try {
      await store.validate(models);
      await webWasmGuard?.call();
      final backend = sessionBackend ?? webSessionBackendDefault?.call();
      if (backend == null) {
        throw const AgentFailure(
          AgentErrorCode.unsupportedProfile,
          'The web session backend is not registered.',
          fatal: false,
        );
      }
      final outputRate = await backend.ensureCreated();
      return await _bindSession(
        session: backend,
        logic: logic ?? ((text) async => 'You said: $text'),
        outputRate: outputRate,
        speakerId: speakerId,
      );
    } finally {
      webCreateBundle = null;
    }
  }

  static Future<LocalVoiceAgent> _bindSession({
    required VoiceSessionBackend session,
    required LocalReplyLogic? logic,
    required int outputRate,
    required int speakerId,
  }) async {
    final agent = LocalVoiceAgent._(session, logic, outputRate, speakerId);
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
          await session.stop();
        } catch (_) {}
      },
    );
    return agent;
  }

  final VoiceSessionBackend _session;
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

  /// Last speaker id accepted by create or a successful setter.
  int get speakerId => _speakerId;
  int _speakerId;

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
      await _session.start();
      if (_disposed || epoch != _epoch) {
        await _session.stop();
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

  /// Updates the speaker id used by the next synthesized reply.
  Future<void> setSpeakerId(int speakerId) async {
    _live();
    if (speakerId < 0) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'Speaker id must be greater than or equal to zero.',
        fatal: false,
      );
    }
    try {
      await _session.setSpeakerId(speakerId);
    } on PlatformException catch (error) {
      throw _platformFailure(error);
    }
    _speakerId = speakerId;
  }

  /// Interrupts native work and invalidates late replies.
  Future<void> interrupt() async {
    _live();
    _advanceGeneration();
    activity = TurnActivity.interrupting;
    try {
      await _session.interrupt();
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
      await _session.stop();
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
      await _session.dispose();
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
      final values = await _session.poll();
      if (values.isNotEmpty) {
        debugPrint(
          'FLVA poll events=${values.length} kinds=${values.map((value) => value['kind']).join(',')}',
        );
      }
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
    debugPrint(
      'FLVA event kind=$kind sequence=$sequence generation=$generation activity=${eventActivity.name} textLength=${(value['text'] as String?)?.length ?? 0}',
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
          _validateLogicReply(result);
          if (!_disposed && generation == _generation) {
            await _session.reply(generation: generation, text: result);
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
      await _session.interrupt();
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
      await _session.stop();
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

bool _isWebHost() => debugOverrideIsWeb ?? kIsWeb;

/// Refuses fuchsia and any other non-native non-web target.
void _refuseUnsupportedNativeHost() {
  final supported = switch (defaultTargetPlatform) {
    TargetPlatform.android => true,
    TargetPlatform.iOS => true,
    TargetPlatform.macOS => true,
    TargetPlatform.windows => true,
    TargetPlatform.linux => true,
    TargetPlatform.fuchsia => false,
  };
  if (!supported) {
    throw AgentFailure(
      AgentErrorCode.unsupportedProfile,
      '${defaultTargetPlatform.name} is not a supported platform for the native offline voice pipeline.',
      fatal: false,
    );
  }
}

final class _NativeSessionBackend implements VoiceSessionBackend {
  _NativeSessionBackend(this._native, this._outputRate);

  final NativeVoicePlatform _native;
  final int _outputRate;

  @override
  Future<int> ensureCreated() async => _outputRate;

  @override
  Future<void> start() => _native.start();

  @override
  Future<void> stop() => _native.stop();

  @override
  Future<void> interrupt() => _native.interrupt();

  @override
  Future<void> dispose() => _native.dispose();

  @override
  Future<List<Map<String, Object?>>> poll() => _native.poll();

  @override
  Future<void> reply({required int generation, required String text}) =>
      _native.reply(generation: generation, text: text);

  @override
  Future<void> setSpeakerId(int speakerId) => _native.setSpeakerId(speakerId);
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

void _validateLogicReply(String reply) {
  if (reply.isEmpty) {
    throw const AgentFailure(
      AgentErrorCode.inferenceFailed,
      'Reply is empty.',
      fatal: false,
    );
  }
  for (var index = 0; index < reply.length; index++) {
    final codeUnit = reply.codeUnitAt(index);
    if (codeUnit == 0) {
      throw const AgentFailure(
        AgentErrorCode.inferenceFailed,
        'Reply contains an embedded NUL.',
        fatal: false,
      );
    }
    if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
      if (index + 1 >= reply.length) {
        throw const AgentFailure(
          AgentErrorCode.inferenceFailed,
          'Reply contains an unpaired UTF-16 surrogate.',
          fatal: false,
        );
      }
      final next = reply.codeUnitAt(index + 1);
      if (next < 0xDC00 || next > 0xDFFF) {
        throw const AgentFailure(
          AgentErrorCode.inferenceFailed,
          'Reply contains an unpaired UTF-16 surrogate.',
          fatal: false,
        );
      }
      index++;
    } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
      throw const AgentFailure(
        AgentErrorCode.inferenceFailed,
        'Reply contains an unpaired UTF-16 surrogate.',
        fatal: false,
      );
    }
  }
  if (reply.runes.length > 240 || utf8.encode(reply).length > 960) {
    throw const AgentFailure(
      AgentErrorCode.capacityExceeded,
      'Reply exceeds bounds.',
      fatal: false,
    );
  }
}

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
    required int speakerId,
  }) async {
    final rate = objectMap(
      await _channel.invokeMethod<Object?>('create', {
        'paths': paths,
        'mode': mode,
        'speakerId': speakerId,
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
  @override
  Future<void> setSpeakerId(int speakerId) =>
      _channel.invokeMethod<void>('setSpeakerId', {'speakerId': speakerId});
}
