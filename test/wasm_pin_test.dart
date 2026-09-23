import 'dart:io';

import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_local_voice_agent/src/wasm_pin.dart';
import 'package:flutter_local_voice_agent/src/web_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugOverrideIsWeb = null;
    webWasmGuard = null;
    webModelStoreDefault = null;
    webSessionBackendDefault = null;
  });

  test('vendored WASM assets match the pinned digests', () {
    for (final name in wasmAssetPins.keys) {
      verifyWasmAssetBytes(
        name,
        File('assets/sherpa_onnx_web/$name').readAsBytesSync(),
      );
    }
  });

  test(
    'plugin package does not depend on sherpa or record and has no ONNX',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = pubspec.split('dev_dependencies:').first;
      expect(dependencies.contains('sherpa_onnx:'), isFalse);
      expect(dependencies.contains('sherpa_onnx_web:'), isFalse);
      expect(
        RegExp(r'^  record:', multiLine: true).hasMatch(dependencies),
        isFalse,
      );
      expect(
        pubspec.contains('pluginClass: FlutterLocalVoiceAgentWeb'),
        isTrue,
      );
      expect(
        pubspec.contains('package: web') || pubspec.contains('\n  web:'),
        isTrue,
      );
      expect(
        Directory('assets')
            .listSync(recursive: true)
            .where((entity) => entity.path.endsWith('.onnx')),
        isEmpty,
      );
    },
  );

  test('digest mismatch throws invalidAsset and loads nothing', () {
    expect(
      () => verifyWasmAssetBytes('sherpa-onnx-wasm-web.wasm', <int>[1, 2, 3]),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });

  test('unknown asset name is unsupportedProfile', () {
    expect(
      () => verifyWasmAssetBytes('not-an-asset.wasm', <int>[1]),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.unsupportedProfile,
        ),
      ),
    );
  });

  test('web create with a bad WASM digest does not open the backend', () async {
    debugOverrideIsWeb = true;
    registerWebWasmGuard(<String, List<int>>{
      for (final name in wasmAssetPins.keys) name: <int>[0],
    });
    final store = _AcceptingStore();
    final backend = _CountingWebBackend();
    await expectLater(
      LocalVoiceAgent.create(
        models: const LocalModelBundle(
          directory: 'en-us-ljs-zipformer-int8',
          manifestPath: 'en-us-ljs-zipformer-int8/manifest.json',
        ),
        modelStore: store,
        sessionBackend: backend,
      ),
      throwsA(
        isA<AgentFailure>().having(
          (failure) => failure.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
    expect(backend.createCount, 0);
    expect(store.validated, isTrue);
  });
}

final class _AcceptingStore implements LocalModelStore {
  bool validated = false;

  @override
  Future<ValidatedModelBundle> validate(LocalModelBundle bundle) async {
    validated = true;
    return ValidatedModelBundle(bundle: bundle, files: const []);
  }

  @override
  Future<LocalModelBundle> install({
    required LocalModelBundle source,
    required String targetRoot,
  }) async => source;
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
