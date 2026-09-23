import 'model_preparation_models.dart';
import 'models.dart';

export 'model_preparation_models.dart';

/// Unused on web. The manager is a compile stub.
typedef ModelPreparationHttpClientFactory = Object Function();

/// Compile-only web stand-in. Preparation stays a native and VM path.
final class ModelPreparationManager {
  /// Creates a manager that cannot run on web.
  ModelPreparationManager({
    required this.rootDirectory,
    ModelPreparationHttpClientFactory? httpClientFactory,
    this.timeout = const Duration(seconds: 30),
    this.maxRedirects = 0,
    List<Uri> allowedRedirectOrigins = const [],
  }) : httpClientFactory = httpClientFactory ?? _unusedFactory,
       allowedRedirectOrigins = List<Uri>.unmodifiable(allowedRedirectOrigins);

  /// Host-selected persistent storage root. Unused on this stub.
  final String rootDirectory;

  /// Factory retained for signature compatibility. Unused on this stub.
  final ModelPreparationHttpClientFactory httpClientFactory;

  /// Positive deadline retained for signature compatibility.
  final Duration timeout;

  /// Redirect cap retained for signature compatibility.
  final int maxRedirects;

  /// Extra origins retained for signature compatibility.
  final List<Uri> allowedRedirectOrigins;

  /// Always fails. Web hosts do not prepare through this manager.
  ModelPreparation prepare(ModelPackDescriptor descriptor) {
    throw const AgentFailure(
      AgentErrorCode.unsupportedProfile,
      'Model preparation is not available on Flutter web.',
      fatal: false,
    );
  }
}

Object _unusedFactory() {
  throw const AgentFailure(
    AgentErrorCode.unsupportedProfile,
    'Model preparation is not available on Flutter web.',
    fatal: false,
  );
}
