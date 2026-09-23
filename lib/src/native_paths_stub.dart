import 'models.dart';

/// Web compile stand-in. Native path maps are never built on web.
Future<Map<String, String>> nativeModelPathMap(
  ValidatedModelBundle checked,
  LocalModelBundle models,
) async {
  throw const AgentFailure(
    AgentErrorCode.unsupportedProfile,
    'Filesystem model paths are not available on Flutter web.',
    fatal: false,
  );
}
