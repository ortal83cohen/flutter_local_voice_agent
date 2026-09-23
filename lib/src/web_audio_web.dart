import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'models.dart';
import 'web_audio.dart';

/// Browser audio owner using getUserMedia and Web Audio.
WebAudioOwner createPlatformWebAudioOwner() => WebBrowserAudioOwner();

/// Production getUserMedia and Web Audio owner. PCM stays in this class.
final class WebBrowserAudioOwner implements WebAudioOwner {
  web.MediaStream? _stream;
  web.AudioContext? _context;
  web.MediaStreamAudioSourceNode? _source;
  web.ScriptProcessorNode? _processor;
  web.GainNode? _keepAliveGain;
  web.OscillatorNode? _keepAliveOsc;
  web.AudioBufferSourceNode? _playing;
  Completer<void>? _playHold;
  JSFunction? _processAudio;
  var _loggedFrames = 0;
  final List<double> _pending = <double>[];

  static const _targetRate = 16000;
  static const _frameSize = 512;
  static const _processorBuffer = 4096;

  @override
  bool get isSecureContext => web.window.isSecureContext;

  @override
  Future<void> requestMicrophone() async {
    if (!isSecureContext) {
      throw const AgentFailure(
        AgentErrorCode.unsupportedProfile,
        'A secure context is required for microphone capture.',
        fatal: false,
      );
    }
    _stopTracks();
    try {
      _stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: web.MediaTrackConstraints(
                channelCount: 1.toJS,
                // AEC/NS can gate the mic to silence once any audio graph
                // is connected to destination to keep ScriptProcessor alive.
                echoCancellation: false.toJS,
                noiseSuppression: false.toJS,
                autoGainControl: true.toJS,
              ),
              video: false.toJS,
            ),
          )
          .toDart;
    } catch (_) {
      _stream = null;
      throw const AgentFailure(
        AgentErrorCode.permissionDenied,
        'Microphone permission was denied.',
        fatal: false,
      );
    }
    final tracks = _stream?.getAudioTracks();
    if (tracks != null && tracks.length > 0) {
      final track = tracks.toDart.first;
      final settings = track.getSettings();
      debugPrint(
        'FLVA web mic track muted=${track.muted} enabled=${track.enabled} '
        'ready=${track.readyState} rate=${settings.sampleRate} '
        'channels=${settings.channelCount} echo=${settings.echoCancellation}',
      );
    }
  }

  @override
  Future<void> startCapture(void Function(List<double> frame) onFrame) async {
    final stream = _stream;
    if (stream == null) {
      throw const AgentFailure(
        AgentErrorCode.permissionDenied,
        'Microphone permission was denied.',
        fatal: false,
      );
    }
    _teardownGraph();
    _pending.clear();
    _loggedFrames = 0;
    // Use the hardware rate. Forcing 16 kHz makes Chrome resample the
    // 48 kHz track into a nearly silent ScriptProcessor buffer.
    final context = web.AudioContext();
    await context.resume().toDart;
    _context = context;
    debugPrint(
      'FLVA web capture rate=${context.sampleRate} state=${context.state}',
    );
    final source = context.createMediaStreamSource(stream);
    final processor = context.createScriptProcessor(_processorBuffer, 1, 1);
    final keepAlive = context.createGain();
    keepAlive.gain.value = 0.0001;
    final oscillator = context.createOscillator();
    oscillator.frequency.value = 1;
    // Keep the Dart callback alive; Chrome skips a fully muted graph.
    _processAudio = ((web.Event raw) {
      try {
        final event = raw as web.AudioProcessingEvent;
        final input = event.inputBuffer.getChannelData(0).toDart;
        final output = event.outputBuffer.getChannelData(0).toDart;
        for (var i = 0; i < output.length; i++) {
          output[i] = 0;
        }
        final captured = List<double>.generate(
          input.length,
          (index) => input[index],
        );
        var energy = 0.0;
        for (final sample in captured) {
          energy += sample * sample;
        }
        _loggedFrames++;
        if (_loggedFrames <= 3 || _loggedFrames % 50 == 0) {
          final rms = captured.isEmpty ? 0.0 : energy / captured.length;
          debugPrint(
            'FLVA web micFrame=$_loggedFrames length=${captured.length} '
            'rms=${rms.toStringAsFixed(6)}',
          );
        }
        final resampled = _resample(captured, context.sampleRate.round());
        _pending.addAll(resampled);
        while (_pending.length >= _frameSize) {
          final frame = _pending.sublist(0, _frameSize);
          _pending.removeRange(0, _frameSize);
          onFrame(frame);
        }
      } catch (error) {
        debugPrint('FLVA web micFrame error=$error');
      }
    }).toJS;
    processor.onaudioprocess = _processAudio;
    source.connect(processor);
    processor.connect(keepAlive);
    oscillator.connect(keepAlive);
    keepAlive.connect(context.destination);
    oscillator.start();
    _source = source;
    _processor = processor;
    _keepAliveGain = keepAlive;
    _keepAliveOsc = oscillator;
  }

  @override
  Future<void> stopCapture() async {
    _pending.clear();
    _teardownGraph();
    _loggedFrames = 0;
    _stopTracks();
    _stream = null;
  }

  void _teardownGraph() {
    try {
      _keepAliveOsc?.stop();
    } catch (_) {}
    _processor?.disconnect();
    _source?.disconnect();
    _keepAliveOsc?.disconnect();
    _keepAliveGain?.disconnect();
    _processor = null;
    _source = null;
    _keepAliveOsc = null;
    _keepAliveGain = null;
    _processAudio = null;
  }

  void _stopTracks() {
    final tracks = _stream?.getTracks();
    if (tracks == null) {
      return;
    }
    for (var i = 0; i < tracks.length; i++) {
      tracks[i].stop();
    }
  }

  @override
  Future<void> play(List<double> samples) async {
    final context =
        _context ??
        web.AudioContext(web.AudioContextOptions(sampleRate: _targetRate));
    _context = context;
    await context.resume().toDart;
    if (samples.isEmpty) return;
    final rate = context.sampleRate.round();
    final playback = rate == _targetRate
        ? samples
        : _resampleTo(samples, _targetRate, rate);
    final buffer = context.createBuffer(1, playback.length, rate);
    final channel = buffer.getChannelData(0).toDart;
    for (var i = 0; i < playback.length; i++) {
      channel[i] = playback[i];
    }
    final source = context.createBufferSource();
    source.buffer = buffer;
    source.connect(context.destination);
    final done = Completer<void>();
    _playHold = done;
    _playing = source;
    source.onended = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    source.start();
    await done.future;
    if (identical(_playing, source)) {
      _playing = null;
    }
  }

  @override
  Future<void> flushPlayback() async {
    try {
      _playing?.stop();
    } catch (_) {}
    _playing = null;
    final hold = _playHold;
    _playHold = null;
    if (hold != null && !hold.isCompleted) {
      hold.complete();
    }
  }

  @override
  Future<void> dispose() async {
    await flushPlayback();
    await stopCapture();
    try {
      await _context?.close().toDart;
    } catch (_) {}
    _context = null;
  }

  List<double> _resample(List<double> input, int fromRate) {
    if (fromRate == _targetRate || fromRate <= 0) return input;
    return _resampleTo(input, fromRate, _targetRate);
  }

  List<double> _resampleTo(List<double> input, int fromRate, int toRate) {
    if (fromRate == toRate || input.isEmpty) return input;
    final outLength = (input.length * toRate / fromRate).round();
    if (outLength <= 0) return const <double>[];
    final output = List<double>.filled(outLength, 0);
    for (var i = 0; i < outLength; i++) {
      final source = i * fromRate / toRate;
      final index = source.floor();
      final next = index + 1 >= input.length ? input.length - 1 : index + 1;
      final mix = source - index;
      output[i] = input[index] * (1 - mix) + input[next] * mix;
    }
    return output;
  }
}
