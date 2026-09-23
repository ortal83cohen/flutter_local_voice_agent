import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_local_voice_agent/src/web_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugOverrideIsWeb = null;
    webModelStoreDefault = null;
  });

  test(
    'empty reader validate throws missingAsset and reads only the manifest',
    () async {
      final reader = _MemoryWebAssetReader();
      final store = WebModelStore(reader: reader);
      await expectLater(
        store.validate(_compactBundle()),
        throwsA(
          isA<AgentFailure>().having(
            (failure) => failure.code,
            'code',
            AgentErrorCode.missingAsset,
          ),
        ),
      );
      expect(reader.requested, <String>[_compactManifestKey]);
    },
  );

  test('tampered sha256 is invalidAsset', () async {
    final fixture = _compactFixture(tamperSha256: true);
    await expectLater(
      WebModelStore(reader: fixture.reader).validate(fixture.bundle),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });

  test('tampered bytes are invalidAsset', () async {
    final fixture = _compactFixture(tamperBytes: true);
    await expectLater(
      WebModelStore(reader: fixture.reader).validate(fixture.bundle),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });

  test('valid in-memory compact fixture validates', () async {
    final fixture = _compactFixture();
    final checked = await WebModelStore(reader: fixture.reader)
        .validate(fixture.bundle);
    expect(checked.files, hasLength(9));
    expect(
      checked.files.map((entry) => entry.role),
      containsAll(<String>[
        'vad',
        'encoder',
        'decoder',
        'joiner',
        'asrTokens',
        'ttsModel',
        'ttsTokens',
        'ttsLexicon',
        'license',
      ]),
    );
  });

  test('omitted web create uses this store and a missing pack fails before backend', () async {
    debugOverrideIsWeb = true;
    final fixture = _compactFixture();
    registerWebModelStore(fixture.reader);
    final backend = _FakeWebBackend();
    await expectLater(
      LocalVoiceAgent.create(
        models: const LocalModelBundle(
          directory: 'missing-compact-pack',
          manifestPath: 'missing-compact-pack/manifest.json',
        ),
        sessionBackend: backend,
      ),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.missingAsset,
        ),
      ),
    );
    expect(backend.createCount, 0);
    expect(
      fixture.reader.requested,
      contains('missing-compact-pack/manifest.json'),
    );
  });

  test('omitted web create uses this store and a tampered pack fails before backend', () async {
    debugOverrideIsWeb = true;
    final fixture = _compactFixture(tamperSha256: true);
    registerWebModelStore(fixture.reader);
    final backend = _FakeWebBackend();
    await expectLater(
      LocalVoiceAgent.create(models: fixture.bundle, sessionBackend: backend),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
    expect(backend.createCount, 0);
  });

  test('omitted web create default accepts a valid compact fixture', () async {
    debugOverrideIsWeb = true;
    final fixture = _compactFixture();
    registerWebModelStore(fixture.reader);
    final backend = _FakeWebBackend();
    final agent = await LocalVoiceAgent.create(
      models: fixture.bundle,
      sessionBackend: backend,
    );
    expect(backend.createCount, 1);
    await agent.dispose();
  });
}

const _compactPrefix = 'en-us-ljs-zipformer-int8';
const _compactManifestKey = '$_compactPrefix/manifest.json';

LocalModelBundle _compactBundle() => const LocalModelBundle(
  directory: _compactPrefix,
  manifestPath: _compactManifestKey,
);

({_MemoryWebAssetReader reader, LocalModelBundle bundle}) _compactFixture({
  bool tamperSha256 = false,
  bool tamperBytes = false,
}) {
  const files = <({String role, String path})>[
    (role: 'vad', path: 'vad/silero_vad.onnx'),
    (role: 'encoder', path: 'asr/encoder.int8.onnx'),
    (role: 'decoder', path: 'asr/decoder.int8.onnx'),
    (role: 'joiner', path: 'asr/joiner.int8.onnx'),
    (role: 'asrTokens', path: 'asr/tokens.txt'),
    (role: 'ttsModel', path: 'tts/vits-ljs.int8.onnx'),
    (role: 'ttsTokens', path: 'tts/tokens.txt'),
    (role: 'ttsLexicon', path: 'tts/lexicon.txt'),
    (role: 'license', path: 'licenses/apache-2.0.txt'),
  ];
  final assets = <String, List<int>>{};
  final entries = <Map<String, Object?>>[];
  for (final file in files) {
    final bytes = utf8.encode(file.role);
    assets['$_compactPrefix/${file.path}'] = bytes;
    var digest = sha256.convert(bytes).toString();
    if (tamperSha256 && file.role == 'vad') {
      digest = 'a' * 64;
    }
    entries.add(<String, Object?>{
      'role': file.role,
      'path': file.path,
      'bytes': bytes.length,
      'sha256': digest,
      'source': 'fixture',
      'license': 'licenses/apache-2.0.txt',
    });
  }
  if (tamperBytes) {
    assets['$_compactPrefix/vad/silero_vad.onnx'] = utf8.encode('tampered');
  }
  assets[_compactManifestKey] = utf8.encode(
    jsonEncode(<String, Object?>{
      'schema': 1,
      'profile': 'en-US-sherpa-vits',
      'runtime': '1.12.14',
      'inputRate': 16000,
      'files': entries,
    }),
  );
  return (reader: _MemoryWebAssetReader(assets), bundle: _compactBundle());
}

final class _MemoryWebAssetReader implements WebAssetReader {
  _MemoryWebAssetReader([Map<String, List<int>>? assets])
    : _assets = assets ?? <String, List<int>>{};

  final Map<String, List<int>> _assets;
  final List<String> requested = <String>[];

  @override
  Future<List<int>?> read(String key) async {
    requested.add(key);
    final value = _assets[key];
    return value == null ? null : List<int>.from(value);
  }
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
