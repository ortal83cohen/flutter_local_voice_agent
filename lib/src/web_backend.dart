import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'contracts.dart';
import 'models.dart';
import 'web_audio.dart';
import 'web_audio_stub.dart' if (dart.library.js_interop) 'web_audio_web.dart';
import 'web_defaults.dart';
import 'web_inference.dart';
import 'web_model_store.dart';
import 'web_sherpa_inference.dart';
import 'web_wasm_assets.dart';

/// Web session backend. PCM exists only inside [audio] and [inference].
final class WebVoiceSession implements VoiceSessionBackend {
  /// Creates a web session. Tests inject [audio] and [inference].
  WebVoiceSession({WebAudioOwner? audio, WebInferenceEngine? inference})
    : _audio = audio ?? createPlatformWebAudioOwner(),
      _inference = inference ?? SherpaWebInferenceEngine();

  final WebAudioOwner _audio;
  final WebInferenceEngine _inference;
  final List<Map<String, Object?>> _queue = <Map<String, Object?>>[];
  bool _started = false;
  bool _speaking = false;
  bool _admitting = true;
  int _sequence = 0;
  int _generation = 0;
  int _acceptedFrames = 0;
  int _droppedFrames = 0;
  int _speakerId = 0;
  bool _heardSpeech = false;
  bool _draining = false;
  final List<List<double>> _frameQueue = <List<double>>[];

  @override
  Future<int> ensureCreated() async {
    await _inference.load();
    return 16000;
  }

  @override
  Future<void> start() async {
    if (!_audio.isSecureContext) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'A secure context is required for microphone capture.',
        fatal: false,
      );
    }
    await _audio.requestMicrophone();
    _started = true;
    _admitting = true;
    _speaking = false;
    _heardSpeech = false;
    _acceptedFrames = 0;
    _droppedFrames = 0;
    _frameQueue.clear();
    _emit(kind: 'state', activity: 'listening');
    await _audio.startCapture(_enqueueFrame);
  }

  @override
  Future<void> stop() async {
    _started = false;
    _admitting = false;
    _speaking = false;
    await _audio.stopCapture();
    await _audio.flushPlayback();
    _emit(kind: 'state', activity: 'idle');
  }

  @override
  Future<void> interrupt() async {
    _generation++;
    _inference.invalidate();
    await _audio.flushPlayback();
    _speaking = false;
    if (_started) {
      _admitting = true;
      _heardSpeech = false;
      _emit(kind: 'state', activity: 'listening');
    } else {
      _admitting = false;
      _emit(kind: 'state', activity: 'idle');
    }
  }

  @override
  Future<void> dispose() async {
    _started = false;
    await _audio.dispose();
    await _inference.dispose();
  }

  @override
  Future<List<Map<String, Object?>>> poll() async {
    if (_queue.isEmpty) return const <Map<String, Object?>>[];
    final batch = List<Map<String, Object?>>.from(_queue.take(32));
    _queue.removeRange(0, batch.length);
    return batch;
  }

  @override
  Future<void> reply({required int generation, required String text}) async {
    if (generation != _generation) {
      return;
    }
    _speaking = true;
    _admitting = false;
    _emit(kind: 'reply', activity: 'speaking', text: text);
    final samples = await _inference.synthesize(text, speakerId: _speakerId);
    if (generation != _generation) {
      return;
    }
    await _audio.play(samples);
    if (generation != _generation) {
      return;
    }
    _speaking = false;
    if (_started) {
      _admitting = true;
      _heardSpeech = false;
      _emit(kind: 'state', activity: 'listening');
    } else {
      _emit(kind: 'state', activity: 'idle');
    }
  }

  @override
  Future<void> setSpeakerId(int speakerId) async {
    _speakerId = speakerId;
  }

  void _enqueueFrame(List<double> frame) {
    if (!_started || !_admitting || _speaking) {
      _droppedFrames++;
      return;
    }
    var energy = 0.0;
    for (final sample in frame) {
      energy += sample * sample;
    }
    final meanSquare = frame.isEmpty ? 0.0 : energy / frame.length;
    final rms = math.sqrt(meanSquare);
    _acceptedFrames++;
    if (_acceptedFrames <= 3 || _acceptedFrames % 50 == 0) {
      debugPrint(
        'FLVA web acceptedFrames=$_acceptedFrames '
        'dropped=$_droppedFrames rms=${rms.toStringAsFixed(6)}',
      );
    }
    if (rms > 0.01 && !_heardSpeech) {
      _heardSpeech = true;
      _emit(kind: 'state', activity: 'recognizing');
    }
    _frameQueue.add(frame);
    unawaited(_drainFrames());
  }

  Future<void> _drainFrames() async {
    if (_draining) {
      return;
    }
    _draining = true;
    try {
      while (_frameQueue.isNotEmpty && _started && _admitting && !_speaking) {
        final frame = _frameQueue.removeAt(0);
        try {
          final transcript = await _inference.acceptFrame(frame);
          if (transcript == null || transcript.isEmpty) {
            continue;
          }
          _heardSpeech = false;
          _emit(kind: 'final', activity: 'thinking', text: transcript);
          break;
        } catch (error) {
          debugPrint('FLVA web acceptFrame error=$error');
        }
      }
    } finally {
      _draining = false;
    }
  }

  void _emit({required String kind, required String activity, String? text}) {
    _queue.add(<String, Object?>{
      'sequence': ++_sequence,
      'generation': _generation,
      'kind': kind,
      'activity': activity,
      'text': ?text,
    });
  }
}

/// Assigns the production web session as the omitted create default.
void registerWebSessionBackend({
  WebAudioOwner? audio,
  WebInferenceEngine? inference,
}) {
  webSessionBackendDefault = () => WebVoiceSession(
    audio: audio,
    inference: inference ?? SherpaWebInferenceEngine(models: webCreateBundle),
  );
}

/// Imports the production store so hosts can register both hooks together.
void registerWebProfileDefaults({required WebAssetReader reader}) {
  registerWebModelStore(reader);
  registerProductionWebWasmGuard();
  registerWebSessionBackend();
}
