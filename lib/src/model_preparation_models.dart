import 'dart:async';

import 'models.dart';

/// Stable failure categories produced while preparing a model bundle.
enum ModelPreparationErrorCode {
  /// Host-supplied trusted metadata is malformed or unsupported.
  invalidDescriptor,

  /// An HTTPS request failed, timed out, or returned an unsupported response.
  network,

  /// Downloaded or cached content does not match the trusted descriptor.
  integrity,

  /// The private model directory could not be read or written safely.
  storage,

  /// The caller cancelled this preparation operation.
  cancelled,
}

/// The current phase of one model preparation operation.
enum ModelPreparationPhase {
  /// Trusted metadata and any existing installation are being checked.
  checking,

  /// Model files are being downloaded sequentially.
  downloading,

  /// The complete staged or cached bundle is being verified.
  verifying,

  /// A verified local bundle is ready.
  ready,

  /// The caller cancelled the operation.
  cancelled,

  /// Preparation failed.
  failed,
}

/// A model file and its host-trusted HTTPS source.
final class ModelDownload {
  /// Creates one trusted download record.
  const ModelDownload({required this.entry, required this.uri});

  /// Manifest metadata used to verify the downloaded bytes.
  final ModelFileEntry entry;

  /// HTTPS source for the file bytes; redirects require explicit manager policy.
  final Uri uri;
}

/// Immutable host-selected metadata for one complete model pack.
final class ModelPackDescriptor {
  /// Copies [files] into an unmodifiable descriptor snapshot.
  ModelPackDescriptor({
    required this.id,
    required this.version,
    required List<ModelDownload> files,
  }) : files = List<ModelDownload>.unmodifiable(
         files.map(
           (download) => ModelDownload(
             entry: ModelFileEntry(
               role: download.entry.role,
               path: download.entry.path,
               bytes: download.entry.bytes,
               sha256: download.entry.sha256,
               source: download.entry.source,
               license: download.entry.license,
             ),
             uri: Uri.parse(download.uri.toString()),
           ),
         ),
       );

  /// Stable host-defined model-pack identifier.
  final String id;

  /// Stable host-defined model-pack version.
  final String version;

  /// Every required and optional file in the supplied manifest order.
  final List<ModelDownload> files;
}

/// A safe typed failure from a model preparation operation.
final class ModelPreparationFailure implements Exception {
  /// Creates a preparation failure with a stable machine-readable [code].
  const ModelPreparationFailure(this.code, this.message);

  /// Stable failure category.
  final ModelPreparationErrorCode code;

  /// Human-readable detail that excludes source URLs and response bodies.
  final String message;

  @override
  String toString() => 'ModelPreparationFailure($code): $message';
}

/// Immutable latest-state snapshot for one preparation operation.
final class ModelPreparationProgress {
  /// Creates a progress snapshot.
  const ModelPreparationProgress({
    required this.phase,
    required this.receivedBytes,
    required this.totalBytes,
    this.currentPath,
    this.failure,
  });

  /// Current preparation phase.
  final ModelPreparationPhase phase;

  /// Response bytes written to owned staging during this operation.
  final int receivedBytes;

  /// Total trusted payload bytes expected for the descriptor.
  final int totalBytes;

  /// Relative manifest path currently being downloaded, when applicable.
  final String? currentPath;

  /// Terminal typed failure for [ModelPreparationPhase.failed] or cancellation.
  final ModelPreparationFailure? failure;
}

/// Handle for one independently cancellable preparation operation.
abstract interface class ModelPreparation {
  /// Resolves with a verified local bundle or a [ModelPreparationFailure].
  Future<LocalModelBundle> get result;

  /// Returns the latest immutable progress snapshot without queueing events.
  ModelPreparationProgress get progress;

  /// Requests idempotent cancellation of this operation only.
  void cancel();
}
