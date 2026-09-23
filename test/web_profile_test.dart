import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugOverrideIsWeb = null;
  });

  test('web create uses the web backend and not native create', () async {
    debugOverrideIsWeb = true;
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativePlatform();
    final web = _FakeWebBackend();
    final agent = await LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: root.path,
        manifestPath: '${root.path}/manifest.json',
      ),
      nativePlatform: native,
      sessionBackend: web,
    );
    expect(web.createCount, 1);
    expect(native.created, isFalse);
    await agent.dispose();
  });

  test('useLocalLlm on web throws unsupportedProfile', () async {
    debugOverrideIsWeb = true;
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativePlatform();
    final web = _FakeWebBackend();
    await expectLater(
      LocalVoiceAgent.create(
        models: LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
        nativePlatform: native,
        sessionBackend: web,
        useLocalLlm: true,
      ),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.unsupportedProfile,
        ),
      ),
    );
    expect(web.createCount, 0);
    expect(native.created, isFalse);
  });

  test('full duplex on web throws unsupportedProfile', () async {
    debugOverrideIsWeb = true;
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakeNativePlatform();
    final web = _FakeWebBackend();
    await expectLater(
      LocalVoiceAgent.create(
        models: LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
        nativePlatform: native,
        sessionBackend: web,
        mode: ConversationMode.fullDuplexRequired,
      ),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.unsupportedProfile,
        ),
      ),
    );
    expect(web.createCount, 0);
    expect(native.created, isFalse);
  });

  test('web-conditional libraries do not import dart:io', () {
    const paths = <String>[
      'lib/src/agent.dart',
      'lib/src/model_store.dart',
      'lib/src/model_preparation.dart',
      'lib/src/model_store_stub.dart',
      'lib/src/model_preparation_stub.dart',
      'lib/src/native_paths_stub.dart',
      'lib/src/web_defaults.dart',
      'lib/src/contracts.dart',
    ];
    for (final path in paths) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains("import 'dart:io'")),
        reason: path,
      );
    }
  });
}

Future<Directory> fixtureFixture() async {
  final root = await Directory.systemTemp.createTemp('flva-web-');
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

final class _FakeNativePlatform implements NativeVoicePlatform {
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

final class _FakeWebBackend implements VoiceSessionBackend {
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
