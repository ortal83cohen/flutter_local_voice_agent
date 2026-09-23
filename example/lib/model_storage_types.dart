/// Thrown when example storage cannot complete a host-owned file action.
final class ExampleStorageException implements Exception {
  /// Creates a storage failure with a user-visible [message].
  const ExampleStorageException(this.message);

  /// Human-readable detail without file bytes.
  final String message;

  @override
  String toString() => message;
}

/// Persisted catalog choice plus the integer speaker id for that pack.
final class ExampleSelection {
  /// Creates a saved catalog selection.
  const ExampleSelection({required this.catalogId, required this.speakerId});

  /// Catalog identifier last prepared by the host.
  final String catalogId;

  /// Integer speaker id for that pack.
  final int speakerId;
}
