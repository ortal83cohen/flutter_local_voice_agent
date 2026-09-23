import 'models.dart';
import 'web_wasm_runtime.dart';

/// VM stand-in. Production web uses a dedicated worker.
WebWasmRuntime createPlatformWebWasmRuntime() =>
    const _UnavailableWasmRuntime();

final class _UnavailableWasmRuntime implements WebWasmRuntime {
  const _UnavailableWasmRuntime();

  @override
  Future<void> boot({
    required List<int> wasm,
    required String glueJs,
    required String asrJs,
    required String vadJs,
    required String ttsJs,
  }) async {
    throw const AgentFailure(
      AgentErrorCode.unsupportedProfile,
      'The sherpa-onnx WASM worker is not available on this host.',
      fatal: false,
    );
  }

  @override
  Future<void> mount(Map<String, List<int>> files) async {}

  @override
  Future<void> construct(Map<String, String> paths) async {}

  @override
  Future<String?> acceptFrame(List<double> frame) async => null;

  @override
  Future<List<double>> synthesize(String text, {int speakerId = 0}) async =>
      const <double>[];

  @override
  void invalidate() {}

  @override
  Future<void> dispose() async {}
}
