/// Silero VAD plus one offline recognizer and VITS, owned by the web backend.
abstract interface class WebInferenceEngine {
  /// Loads pinned WASM off the UI thread. Does not request the microphone.
  Future<void> load();

  /// Accepts one 16 kHz mono frame. Returns a finalized transcript or null.
  Future<String?> acceptFrame(List<double> frame);

  /// Synthesizes [text] to 16 kHz mono samples. Samples stay inside the backend.
  Future<List<double>> synthesize(String text, {int speakerId = 0});

  /// Drops in-flight recognition and synthesis for the current generation.
  void invalidate();

  /// Releases WASM resources.
  Future<void> dispose();
}
