import 'models.dart';

/// Validates and installs local model manifests without network access.
abstract interface class LocalModelStore {
  /// Validates every file referenced by [bundle].
  Future<ValidatedModelBundle> validate(LocalModelBundle bundle);

  /// Copies, validates, then atomically activates a local bundle under [targetRoot].
  Future<LocalModelBundle> install({
    required LocalModelBundle source,
    required String targetRoot,
  });
}

/// Internal session operations. The web backend owns devices itself.
///
/// This is not a method-channel contract and must not carry PCM samples.
abstract interface class VoiceSessionBackend {
  /// Completes session construction and returns the output sample rate.
  Future<int> ensureCreated();

  /// Starts capture and output ownership for this session.
  Future<void> start();

  /// Stops capture and output ownership.
  Future<void> stop();

  /// Invalidates current work and flushes in-flight generation.
  Future<void> interrupt();

  /// Releases session resources.
  Future<void> dispose();

  /// Polls at most 32 session events.
  Future<List<Map<String, Object?>>> poll();

  /// Supplies a Dart-computed reply for [generation].
  Future<void> reply({required int generation, required String text});

  /// Updates the speaker id used by the next synthesized reply.
  Future<void> setSpeakerId(int speakerId);
}

/// Boundary for the native method channel. No audio crosses this interface.
abstract interface class NativeVoicePlatform {
  /// Creates an inactive native session and returns its output sample rate.
  Future<int> create({
    required Map<String, String> paths,
    required String mode,
    required int speakerId,
  });

  /// Starts native microphone and output ownership.
  Future<void> start();

  /// Stops microphone and output ownership.
  Future<void> stop();

  /// Invalidates current native work.
  Future<void> interrupt();

  /// Releases native session resources.
  Future<void> dispose();

  /// Polls at most 32 native events.
  Future<List<Map<String, Object?>>> poll();

  /// Supplies a Dart-computed reply for [generation].
  Future<void> reply({required int generation, required String text});

  /// Updates the speaker id used by the next synthesized reply.
  Future<void> setSpeakerId(int speakerId);
}
