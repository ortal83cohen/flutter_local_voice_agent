import 'package:crypto/crypto.dart';

import 'models.dart';
import 'web_defaults.dart';

/// Official sherpa-onnx 1.13.8 web asset file names and SHA-256 digests.
const Map<String, String> wasmAssetPins = {
  'sherpa-onnx-wasm-web.wasm':
      'e0d84744c39a28121f7738a161a21612788f4e8f07879a7224e74919e9831573',
  'sherpa-onnx-wasm-web.js':
      '28f909145d93018c90c181035a008880ceaa94a72b66603dc7bb7c619714c23c',
  'sherpa-onnx-asr.js':
      'd51ae8e8b756ee5e53423ffada0c9702973f154f561aca7984fe0b12f4060178',
  'sherpa-onnx-tts.js':
      'b9cb4782010b22d64be31298a3e407170d2b8f5def471ea6011c42a921577e8f',
  'sherpa-onnx-vad.js':
      '893f01168d529add8318c0a6055cf725e788585fda9b81722564a8c3c3f60e34',
};

/// Verifies [bytes] against the pinned digest for [name].
///
/// A digest mismatch throws [AgentErrorCode.invalidAsset] and loads nothing.
/// An unknown or missing name throws [AgentErrorCode.unsupportedProfile].
void verifyWasmAssetBytes(String name, List<int> bytes) {
  final expected = wasmAssetPins[name];
  if (expected == null) {
    throw AgentFailure(
      AgentErrorCode.unsupportedProfile,
      'Unknown WASM asset $name.',
      fatal: false,
    );
  }
  if (sha256.convert(bytes).toString() != expected) {
    throw AgentFailure(
      AgentErrorCode.invalidAsset,
      'WASM digest mismatch for $name.',
      fatal: false,
    );
  }
}

/// Assigns a create-time guard that verifies every pinned asset in [files].
///
/// Missing names are unsupportedProfile. A mismatch is invalidAsset.
/// The guard does not request the microphone.
void registerWebWasmGuard(Map<String, List<int>> files) {
  webWasmGuard = () async {
    for (final name in wasmAssetPins.keys) {
      final bytes = files[name];
      if (bytes == null) {
        throw AgentFailure(
          AgentErrorCode.unsupportedProfile,
          'Missing WASM asset $name.',
          fatal: false,
        );
      }
      verifyWasmAssetBytes(name, bytes);
    }
  };
}
