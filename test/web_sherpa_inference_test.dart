import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_local_voice_agent/src/web_sherpa_inference.dart';
import 'package:flutter_local_voice_agent/src/web_wasm_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing bundle is missingAsset and does not boot WASM', () async {
    final runtime = _FakeRuntime();
    final engine = SherpaWebInferenceEngine(
      runtime: runtime,
      assetLoader: (_) async => const <int>[1],
    );
    await expectLater(
      engine.load(),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.missingAsset,
        ),
      ),
    );
    expect(runtime.booted, isFalse);
  });

  test('rejected catalog construct is invalidAsset', () async {
    final files = _compactFiles();
    final runtime = _FakeRuntime(
      constructError: const AgentFailure(
        AgentErrorCode.invalidAsset,
        'The offline recognizer rejected the catalog files.',
        fatal: false,
      ),
    );
    final engine = SherpaWebInferenceEngine(
      models: const LocalModelBundle(
        directory: 'en-us-ljs-zipformer-int8',
        manifestPath: 'en-us-ljs-zipformer-int8/manifest.json',
      ),
      reader: _MapReader(files),
      runtime: runtime,
      assetLoader: (_) async => const <int>[1, 2, 3],
    );
    await expectLater(
      engine.load(),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
    expect(runtime.booted, isTrue);
    expect(runtime.mounted, isTrue);
  });

  test(
    'successful construct then frame and synthesize stay inside runtime',
    () async {
      final files = _compactFiles();
      final runtime = _FakeRuntime(transcript: 'hello');
      final engine = SherpaWebInferenceEngine(
        models: const LocalModelBundle(
          directory: 'en-us-ljs-zipformer-int8',
          manifestPath: 'en-us-ljs-zipformer-int8/manifest.json',
        ),
        reader: _MapReader(files),
        runtime: runtime,
        assetLoader: (_) async => const <int>[1, 2, 3],
      );
      await engine.load();
      expect(await engine.acceptFrame(<double>[0.01]), 'hello');
      expect(await engine.synthesize('reply', speakerId: 0), <double>[0.2]);
      expect(runtime.frameCount, 1);
      expect(runtime.spoken, 'reply');
    },
  );
}

Map<String, List<int>> _compactFiles() {
  final files = <String, List<int>>{};
  final entries = <Map<String, Object>>[];
  void add(String role, String path, List<int> bytes) {
    files['en-us-ljs-zipformer-int8/$path'] = bytes;
    entries.add(<String, Object>{
      'role': role,
      'path': path,
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'source': 'test:$role',
      'license': 'licenses/notice.txt',
    });
  }

  add('vad', 'vad/silero_vad.onnx', <int>[1]);
  add('encoder', 'asr/encoder.int8.onnx', <int>[2]);
  add('decoder', 'asr/decoder.int8.onnx', <int>[3]);
  add('joiner', 'asr/joiner.int8.onnx', <int>[4]);
  add('asrTokens', 'asr/tokens.txt', <int>[5]);
  add('ttsModel', 'tts/vits-ljs.int8.onnx', <int>[6]);
  add('ttsTokens', 'tts/tokens.txt', <int>[7]);
  add('ttsLexicon', 'tts/lexicon.txt', <int>[8]);
  const license = <int>[9];
  files['en-us-ljs-zipformer-int8/licenses/notice.txt'] = license;
  entries.add(<String, Object>{
    'role': 'license',
    'path': 'licenses/notice.txt',
    'bytes': license.length,
    'sha256': sha256.convert(license).toString(),
    'source': 'test:license',
    'license': 'licenses/notice.txt',
  });
  files['en-us-ljs-zipformer-int8/manifest.json'] = utf8.encode(
    jsonEncode(<String, Object?>{
      'schema': 1,
      'profile': 'en-US-sherpa-vits',
      'runtime': '1.12.14',
      'inputRate': 16000,
      'files': entries,
    }),
  );
  return files;
}

final class _MapReader implements WebAssetReader {
  _MapReader(this.files);

  final Map<String, List<int>> files;

  @override
  Future<List<int>?> read(String key) async => files[key];
}

final class _FakeRuntime implements WebWasmRuntime {
  _FakeRuntime({this.constructError, this.transcript});

  final AgentFailure? constructError;
  final String? transcript;
  bool booted = false;
  bool mounted = false;
  int frameCount = 0;
  String? spoken;

  @override
  Future<void> boot({
    required List<int> wasm,
    required String glueJs,
    required String asrJs,
    required String vadJs,
    required String ttsJs,
  }) async {
    booted = true;
  }

  @override
  Future<void> mount(Map<String, List<int>> files) async {
    mounted = true;
  }

  @override
  Future<void> construct(Map<String, String> paths) async {
    final error = constructError;
    if (error != null) throw error;
  }

  @override
  Future<String?> acceptFrame(List<double> frame) async {
    frameCount++;
    return transcript;
  }

  @override
  Future<List<double>> synthesize(String text, {int speakerId = 0}) async {
    spoken = text;
    return <double>[0.2];
  }

  @override
  void invalidate() {}

  @override
  Future<void> dispose() async {}
}
