import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'denied start returns permissionDenied and does not start capture',
    () async {
      final root = await _fixture();
      addTearDown(() => root.delete(recursive: true));
      final native = _DeniedStartPlatform();
      final agent = await LocalVoiceAgent.create(
        models: LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
        nativePlatform: native,
      );
      await expectLater(
        agent.start(),
        throwsA(
          isA<AgentFailure>().having(
            (failure) => failure.code,
            'code',
            AgentErrorCode.permissionDenied,
          ),
        ),
      );
      expect(native.captureStarts, 0);
      expect(agent.lifecycle, isNot(AgentLifecycle.running));
    },
  );
}

final class _DeniedStartPlatform implements NativeVoicePlatform {
  int captureStarts = 0;

  @override
  Future<int> create({
    required Map<String, String> paths,
    required String mode,
    required int speakerId,
  }) async => 24000;

  @override
  Future<void> start() async {
    throw PlatformException(
      code: 'permissionDenied',
      message: 'Microphone permission denied',
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> interrupt() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> reply({required int generation, required String text}) async {}

  @override
  Future<void> setSpeakerId(int speakerId) async {}

  @override
  Future<List<Map<String, Object?>>> poll() async => <Map<String, Object?>>[];
}

Future<Directory> _fixture() async {
  final root = await Directory.systemTemp.createTemp('flva-permission-');
  const roles = <String>[
    'vad',
    'encoder',
    'decoder',
    'joiner',
    'asrTokens',
    'ttsModel',
    'ttsTokens',
    'ttsLexicon',
    'license',
  ];
  final files = <Map<String, Object?>>[];
  for (final role in roles) {
    final file = role == 'license' ? 'LICENSE' : role;
    await File('${root.path}/$file').writeAsString(role);
    final bytes = await File('${root.path}/$file').readAsBytes();
    files.add(<String, Object?>{
      'role': role,
      'path': file,
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'source': 'fixture',
      'license': 'LICENSE',
    });
  }
  await File('${root.path}/manifest.json').writeAsString(
    '{"schema":1,"profile":"en-US-sherpa-vits","runtime":"1.12.14","inputRate":16000,"files":${jsonEncode(files)}}',
  );
  return root;
}
