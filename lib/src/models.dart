import 'dart:convert';

/// The only supported conversation mode in this release.
enum ConversationMode {
  /// Capture and playback do not overlap.
  halfDuplex,

  /// Requires simultaneous capture and playback support.
  fullDuplexRequired,
}

/// The lifetime state of a [LocalVoiceAgent].
enum AgentLifecycle {
  /// Assets are loading.
  initializing,

  /// Ready to capture.
  ready,

  /// Capture or playback is active.
  running,

  /// The OS paused audio.
  suspended,

  /// Shutdown is underway.
  stopping,

  /// The session cannot continue.
  failed,

  /// Resources were released.
  disposed,
}

/// The activity of the current turn.
enum TurnActivity {
  /// No active turn.
  idle,

  /// Awaiting speech.
  listening,

  /// Decoding speech.
  recognizing,

  /// Computing a reply.
  thinking,

  /// Rendering a reply.
  speaking,

  /// Cancelling work.
  interrupting,
}

/// The type of notification emitted by an agent.
enum AgentEventKind {
  /// State snapshot.
  state,

  /// Revisable speech text.
  partialTranscript,

  /// Final speech text.
  finalTranscript,

  /// Native reply text.
  replyText,

  /// Typed failure.
  fault,
}

/// Stable failures returned by the local voice agent contract.
enum AgentErrorCode {
  /// Required local asset absent.
  missingAsset,

  /// Asset or event malformed.
  invalidAsset,

  /// Profile unavailable.
  unsupportedProfile,

  /// Microphone denied.
  permissionDenied,

  /// Audio route unavailable.
  audioUnavailable,

  /// Lifecycle call invalid.
  invalidState,

  /// Bounded capacity exceeded.
  capacityExceeded,

  /// Speech too long.
  utteranceTooLong,

  /// Inference failed.
  inferenceFailed,

  /// Shutdown timed out.
  shutdownTimeout,
}

/// A local manifest and its containing model root.
final class LocalModelBundle {
  /// Creates a model bundle reference.
  const LocalModelBundle({required this.directory, required this.manifestPath});

  /// Root directory containing all listed model files.
  final String directory;

  /// JSON manifest path, normally within [directory].
  final String manifestPath;
}

/// A checked file entry in a local model manifest.
final class ModelFileEntry {
  /// Creates a checked model entry.
  const ModelFileEntry({
    required this.role,
    required this.path,
    required this.bytes,
    required this.sha256,
    required this.source,
    required this.license,
  });

  /// Semantic role consumed by the native session.
  final String role;

  /// Path relative to the bundle root.
  final String path;

  /// Expected byte count.
  final int bytes;

  /// Expected lowercase SHA-256 digest.
  final String sha256;

  /// Non-empty provenance source.
  final String source;

  /// Relative path to a listed license entry.
  final String license;
}

/// Checked local assets accepted by [LocalVoiceAgent.create].
final class ValidatedModelBundle {
  /// Creates a checked local asset bundle.
  const ValidatedModelBundle({required this.bundle, required this.files});

  /// Original bundle reference.
  final LocalModelBundle bundle;

  /// Every manifest file after validation.
  final List<ModelFileEntry> files;
}

/// A typed command or event failure.
final class AgentFailure implements Exception {
  /// Creates a failure with a stable code.
  const AgentFailure(this.code, this.message, {required this.fatal});

  /// Stable machine-readable failure code.
  final AgentErrorCode code;

  /// Human-readable detail safe for application logs.
  final String message;

  /// Whether the session cannot continue.
  final bool fatal;

  @override
  String toString() => 'AgentFailure($code): $message';
}

/// A state or text notification from the native session.
final class AgentEvent {
  /// Creates an immutable event snapshot.
  const AgentEvent({
    required this.sequence,
    required this.generation,
    required this.kind,
    required this.lifecycle,
    required this.activity,
    this.text,
    this.failure,
  });

  /// Native monotonic event sequence.
  final int sequence;

  /// Native output generation.
  final int generation;

  /// Event type.
  final AgentEventKind kind;

  /// Lifecycle after applying the event.
  final AgentLifecycle lifecycle;

  /// Turn activity after applying the event.
  final TurnActivity activity;

  /// Optional transcript or reply text.
  final String? text;

  /// Optional typed native failure.
  final AgentFailure? failure;
}

/// Converts an arbitrary JSON value into an object map.
Map<String, Object?> objectMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw const FormatException('Expected a JSON object.');
}

/// Converts decoded JSON into a manifest object map.
Map<String, Object?> decodeObjectJson(String source) =>
    objectMap(jsonDecode(source));

/// Capabilities of the initial native speech profile.
final class AgentCapabilities {
  /// Describes the shipped adapter's source-level capabilities.
  const AgentCapabilities();

  /// Streaming ASR provides revisable partial transcript snapshots.
  bool get partialTranscripts => true;

  /// VITS callbacks arrive after whole-sentence generation.
  bool get incrementalPcm => false;

  /// TTS accepts a complete bounded reply, not text deltas.
  bool get streamingTextInput => false;

  /// No speaker/route has completed acoustic AEC qualification.
  bool get qualifiedSpeechInterruption => false;
}
