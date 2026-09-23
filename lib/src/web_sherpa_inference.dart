// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'contracts.dart';
import 'models.dart';
import 'web_defaults.dart';
import 'web_inference.dart';
import 'web_model_store.dart';
import 'web_wasm_assets.dart';
import 'web_wasm_runtime.dart';
import 'web_wasm_runtime_stub.dart'
    if (dart.library.js_interop) 'web_wasm_runtime_web.dart';

/// Loads one pinned WASM or JS asset by file name.
typedef WebWasmAssetLoader = Future<List<int>> Function(String name);

/// Production Silero VAD, streaming Zipformer and VITS on official 1.13.8 WASM.
final class SherpaWebInferenceEngine implements WebInferenceEngine {
  /// Creates the engine. Tests inject [runtime], [reader] and [store].
  SherpaWebInferenceEngine({
    LocalModelBundle? models,
    WebAssetReader? reader,
    LocalModelStore? store,
    WebWasmRuntime? runtime,
    WebWasmAssetLoader? assetLoader,
  }) : _models = models,
       _reader = reader,
       _store = store,
       _runtime = runtime ?? createPlatformWebWasmRuntime(),
       _assetLoader = assetLoader ?? loadPinnedWasmAsset;

  final LocalModelBundle? _models;
  final WebAssetReader? _reader;
  final LocalModelStore? _store;
  final WebWasmRuntime _runtime;
  final WebWasmAssetLoader _assetLoader;
  bool _loaded = false;

  @override
  Future<void> load() async {
    if (_loaded) return;
    final bundle = _models ?? webCreateBundle;
    if (bundle == null) {
      throw const AgentFailure(
        AgentErrorCode.missingAsset,
        'No compact model pack was supplied to the web backend.',
        fatal: false,
      );
    }
    final reader = _reader;
    final store =
        _store ??
        (reader == null
            ? webModelStoreDefault?.call()
            : WebModelStore(reader: reader));
    if (store == null) {
      throw const AgentFailure(
        AgentErrorCode.missingAsset,
        'The web model store is not registered.',
        fatal: false,
      );
    }
    final checked = await store.validate(bundle);
    final files = <String, List<int>>{};
    final paths = <String, String>{};
    for (final entry in checked.files) {
      if (entry.role == 'license' || entry.role == 'llmModel') continue;
      final bytes = await _readChecked(store, bundle, entry);
      files[entry.path] = bytes;
      paths[entry.role] = '/${entry.path}';
    }
    const required = <String>{
      'vad',
      'encoder',
      'decoder',
      'joiner',
      'asrTokens',
      'ttsModel',
      'ttsTokens',
      'ttsLexicon',
    };
    if (!paths.keys.toSet().containsAll(required)) {
      throw const AgentFailure(
        AgentErrorCode.missingAsset,
        'The compact pack is missing a required speech role.',
        fatal: false,
      );
    }
    final wasm = await _assetLoader('sherpa-onnx-wasm-web.wasm');
    final glue = await _utf8Asset('sherpa-onnx-wasm-web.js');
    final asr = await _utf8Asset('sherpa-onnx-asr.js');
    final vad = await _utf8Asset('sherpa-onnx-vad.js');
    final tts = await _utf8Asset('sherpa-onnx-tts.js');
    await _runtime.boot(
      wasm: wasm,
      glueJs: glue,
      asrJs: asr,
      vadJs: vad,
      ttsJs: tts,
    );
    await _runtime.mount(files);
    await _runtime.construct(paths);
    _loaded = true;
  }

  @override
  Future<String?> acceptFrame(List<double> frame) =>
      _runtime.acceptFrame(frame);

  @override
  Future<List<double>> synthesize(String text, {int speakerId = 0}) =>
      _runtime.synthesize(text, speakerId: speakerId);

  @override
  void invalidate() => _runtime.invalidate();

  @override
  Future<void> dispose() async {
    _loaded = false;
    await _runtime.dispose();
  }

  Future<List<int>> _readChecked(
    LocalModelStore store,
    LocalModelBundle bundle,
    ModelFileEntry entry,
  ) async {
    final reader = _reader;
    if (reader != null) {
      final bytes = await reader.read(
        bundle.directory.isEmpty
            ? entry.path
            : '${bundle.directory}/${entry.path}',
      );
      if (bytes == null) {
        throw AgentFailure(
          AgentErrorCode.missingAsset,
          'Missing model file ${entry.path}.',
          fatal: false,
        );
      }
      return bytes;
    }
    if (store is WebModelStore) {
      final bytes = await store.reader.read(
        bundle.directory.isEmpty
            ? entry.path
            : '${bundle.directory}/${entry.path}',
      );
      if (bytes == null) {
        throw AgentFailure(
          AgentErrorCode.missingAsset,
          'Missing model file ${entry.path}.',
          fatal: false,
        );
      }
      return bytes;
    }
    throw const AgentFailure(
      AgentErrorCode.missingAsset,
      'The web model store cannot read files for WASM.',
      fatal: false,
    );
  }

  Future<String> _utf8Asset(String name) async {
    final bytes = await _assetLoader(name);
    return utf8.decode(bytes);
  }
}
