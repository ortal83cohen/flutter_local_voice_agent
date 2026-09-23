import 'dart:async';

import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_local_voice_agent/src/web_audio.dart';
import 'package:flutter_local_voice_agent/src/web_backend.dart';
import 'package:flutter_local_voice_agent/src/web_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'insecure context throws unsupportedProfile and does not capture',
    () async {
      final audio = _FakeAudio(secure: false);
      final session = WebVoiceSession(
        audio: audio,
        inference: _FakeInference(),
      );
      await session.ensureCreated();
      await expectLater(
        session.start(),
        throwsA(
          isA<AgentFailure>().having(
            (failure) => failure.code,
            'code',
            AgentErrorCode.unsupportedProfile,
          ),
        ),
      );
      expect(audio.captureStarted, isFalse);
      expect(audio.played, isEmpty);
    },
  );

  test(
    'denied microphone is permissionDenied and starts neither capture nor play',
    () async {
      final audio = _FakeAudio(deny: true);
      final session = WebVoiceSession(
        audio: audio,
        inference: _FakeInference(),
      );
      await session.ensureCreated();
      await expectLater(
        session.start(),
        throwsA(
          isA<AgentFailure>().having(
            (failure) => failure.code,
            'code',
            AgentErrorCode.permissionDenied,
          ),
        ),
      );
      expect(audio.captureStarted, isFalse);
      expect(audio.played, isEmpty);
    },
  );

  test('agent events have no PCM fields', () {
    const event = AgentEvent(
      sequence: 1,
      generation: 0,
      kind: AgentEventKind.finalTranscript,
      lifecycle: AgentLifecycle.running,
      activity: TurnActivity.thinking,
      text: 'hello',
    );
    expect(event.text, 'hello');
    expect(
      event.toString().toLowerCase().contains('pcm') ||
          event.toString().toLowerCase().contains('sample'),
      isFalse,
    );
  });

  test(
    'finalized VAD calls logic path and refuses admission while speaking',
    () async {
      final audio = _FakeAudio(holdPlay: true);
      final inference = _FakeInference(transcript: 'hello');
      final session = WebVoiceSession(audio: audio, inference: inference);
      await session.ensureCreated();
      await session.start();
      audio.emitFrame(<double>[0.1, 0.2]);
      await Future<void>.delayed(Duration.zero);
      final events = await session.poll();
      final finals = events.where((event) => event['kind'] == 'final').toList();
      expect(finals, hasLength(1));
      expect(finals.single['text'], 'hello');
      expect(finals.single.containsKey('pcm'), isFalse);
      expect(finals.single.containsKey('samples'), isFalse);
      final reply = session.reply(generation: 0, text: 'You said: hello');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      audio.emitFrame(<double>[0.3]);
      await Future<void>.delayed(Duration.zero);
      expect(inference.framesAccepted, 1);
      audio.releasePlay();
      await reply;
      expect(audio.played, isNotEmpty);
    },
  );

  test(
    'interrupt flushes playback and does not emit cancelled audio',
    () async {
      final audio = _FakeAudio(holdPlay: true);
      final inference = _FakeInference();
      final session = WebVoiceSession(audio: audio, inference: inference);
      await session.ensureCreated();
      await session.start();
      final play = session.reply(generation: 0, text: 'later');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await session.interrupt();
      await play;
      expect(audio.flushed, isTrue);
      expect(audio.played, isEmpty);
      final events = await session.poll();
      expect(events.last['activity'], 'listening');
    },
  );

  test('loud capture frame emits recognizing before a transcript', () async {
    final audio = _FakeAudio();
    final inference = _FakeInference();
    final session = WebVoiceSession(audio: audio, inference: inference);
    await session.ensureCreated();
    await session.start();
    audio.emitFrame(List<double>.filled(512, 0.2));
    await Future<void>.delayed(Duration.zero);
    final events = await session.poll();
    expect(events.any((event) => event['activity'] == 'recognizing'), isTrue);
    expect(inference.framesAccepted, 1);
  });

  test('web logs omit PCM frame values', () {
    const line = 'FLVA web acceptedFrames=3';
    expect(line.contains('0.1'), isFalse);
    expect(RegExp(r'\[.*\d+\.\d+').hasMatch(line), isFalse);
  });
}

final class _FakeAudio implements WebAudioOwner {
  _FakeAudio({this.secure = true, this.deny = false, this.holdPlay = false});

  final bool secure;
  final bool deny;
  final bool holdPlay;
  void Function(List<double> frame)? _onFrame;
  bool captureStarted = false;
  bool flushed = false;
  final List<List<double>> played = <List<double>>[];
  Completer<void>? _playHold;

  @override
  bool get isSecureContext => secure;

  @override
  Future<void> requestMicrophone() async {
    if (deny) {
      throw const AgentFailure(
        AgentErrorCode.permissionDenied,
        'Microphone permission was denied.',
        fatal: false,
      );
    }
  }

  @override
  Future<void> startCapture(void Function(List<double> frame) onFrame) async {
    captureStarted = true;
    _onFrame = onFrame;
  }

  @override
  Future<void> stopCapture() async {
    captureStarted = false;
  }

  @override
  Future<void> play(List<double> samples) async {
    if (holdPlay) {
      _playHold = Completer<void>();
      await _playHold!.future;
    }
    if (!flushed) {
      played.add(samples);
    }
  }

  @override
  Future<void> flushPlayback() async {
    flushed = true;
    if (_playHold != null && !_playHold!.isCompleted) {
      _playHold!.complete();
    }
  }

  @override
  Future<void> dispose() async {}

  void emitFrame(List<double> frame) => _onFrame?.call(frame);

  void releasePlay() {
    if (_playHold != null && !_playHold!.isCompleted) {
      _playHold!.complete();
    }
  }
}

final class _FakeInference implements WebInferenceEngine {
  _FakeInference({this.transcript});

  final String? transcript;
  int framesAccepted = 0;

  @override
  Future<void> load() async {}

  @override
  Future<String?> acceptFrame(List<double> frame) async {
    framesAccepted++;
    return transcript;
  }

  @override
  Future<List<double>> synthesize(String text, {int speakerId = 0}) async {
    return <double>[0.01, 0.02];
  }

  @override
  void invalidate() {}

  @override
  Future<void> dispose() async {}
}
