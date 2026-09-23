import 'contracts.dart';
import 'models.dart';

/// Compile-only web stand-in. It does not hash-check a compact pack.
final class FileModelStore implements LocalModelStore {
  /// Largest accepted manifest, in bytes.
  static const maxManifestBytes = 64 * 1024;

  /// Largest accepted manifest file count.
  static const maxEntries = 128;

  /// Largest individual model file, in bytes.
  static const maxFileBytes = 2 * 1024 * 1024 * 1024;

  /// Largest sum of model files, in bytes.
  static const maxTotalBytes = 4 * 1024 * 1024 * 1024;

  /// Creates the compile stub.
  const FileModelStore();

  @override
  Future<ValidatedModelBundle> validate(LocalModelBundle bundle) async {
    throw const AgentFailure(
      AgentErrorCode.missingAsset,
      'The web model store is not registered.',
      fatal: false,
    );
  }

  @override
  Future<LocalModelBundle> install({
    required LocalModelBundle source,
    required String targetRoot,
  }) async {
    throw const AgentFailure(
      AgentErrorCode.missingAsset,
      'The web model store is not registered.',
      fatal: false,
    );
  }
}
