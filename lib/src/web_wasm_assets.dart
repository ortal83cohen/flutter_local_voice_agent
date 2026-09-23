import 'package:flutter/services.dart';

import 'models.dart';
import 'wasm_pin.dart';
import 'web_defaults.dart';

/// Flutter asset keys for the pinned sherpa-onnx 1.13.8 web runtime.
const List<String> wasmAssetPrefixes = <String>[
  'packages/flutter_local_voice_agent/assets/sherpa_onnx_web/',
  'assets/sherpa_onnx_web/',
];

/// Loads one pinned WASM asset and verifies its digest before any copy is used.
Future<List<int>> loadPinnedWasmAsset(String name) async {
  for (final prefix in wasmAssetPrefixes) {
    try {
      final data = await rootBundle.load('$prefix$name');
      final bytes = data.buffer.asUint8List();
      verifyWasmAssetBytes(name, bytes);
      return bytes;
    } on AgentFailure {
      rethrow;
    } catch (_) {}
  }
  throw AgentFailure(
    AgentErrorCode.unsupportedProfile,
    'Missing WASM asset $name.',
    fatal: false,
  );
}

/// Verifies every pinned WASM asset from Flutter assets before microphone use.
void registerProductionWebWasmGuard() {
  webWasmGuard = () async {
    for (final name in wasmAssetPins.keys) {
      await loadPinnedWasmAsset(name);
    }
  };
}
