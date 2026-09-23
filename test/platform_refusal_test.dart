import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    debugOverrideIsWeb = null;
  });

  test('excluded target is refused before native create', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakePlatform();
    final web = _CountingWebBackend();
    await expectLater(
      LocalVoiceAgent.create(
        models: LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
        nativePlatform: native,
        sessionBackend: web,
      ),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.unsupportedProfile,
        ),
      ),
    );
    expect(native.created, isFalse);
    expect(web.createCount, 0);
  });

  test('full duplex is rejected before platform create', () async {
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakePlatform();
    await expectLater(
      LocalVoiceAgent.create(
        models: LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
        nativePlatform: native,
        mode: ConversationMode.fullDuplexRequired,
      ),
      throwsA(isA<AgentFailure>()),
    );
    expect(native.created, isFalse);
  });

  test('supported target reaches native create', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakePlatform();
    final agent = await LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: root.path,
        manifestPath: '${root.path}/manifest.json',
      ),
      nativePlatform: native,
    );
    expect(native.created, isTrue);
    await agent.dispose();
  });
}

Future<Directory> fixtureFixture() async {
  final root = await Directory.systemTemp.createTemp('flva-platform-');
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

final class _FakePlatform implements NativeVoicePlatform {
  bool created = false;

  @override
  Future<int> create({
    required Map<String, String> paths,
    required String mode,
    required int speakerId,
  }) async {
    created = true;
    return 24000;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> interrupt() async {}

  @override
  Future<List<Map<String, Object?>>> poll() async => <Map<String, Object?>>[];

  @override
  Future<void> reply({required int generation, required String text}) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSpeakerId(int speakerId) async {}
}

final class _CountingWebBackend implements VoiceSessionBackend {
  int createCount = 0;

  @override
  Future<int> ensureCreated() async {
    createCount++;
    return 16000;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> interrupt() async {}

  @override
  Future<List<Map<String, Object?>>> poll() async => <Map<String, Object?>>[];

  @override
  Future<void> reply({required int generation, required String text}) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSpeakerId(int speakerId) async {}
}
