/// Official-wrapper commands that run off the UI thread.
abstract interface class WebWasmRuntime {
  /// Instantiates the pinned sherpa-onnx Module. Does not request the microphone.
  Future<void> boot({
    required List<int> wasm,
    required String glueJs,
    required String asrJs,
    required String vadJs,
    required String ttsJs,
  });

  /// Writes model files into the Module filesystem.
  Future<void> mount(Map<String, List<int>> files);

  /// Constructs Silero VAD, one offline recognizer and VITS.
  ///
  /// A rejected catalog file is [AgentErrorCode.invalidAsset].
  Future<void> construct(Map<String, String> paths);

  /// Feeds one 16 kHz mono frame. Returns a finalized transcript or null.
  Future<String?> acceptFrame(List<double> frame);

  /// Synthesizes [text] with [speakerId]. Samples stay inside the backend.
  Future<List<double>> synthesize(String text, {int speakerId = 0});

  /// Drops in-flight recognition and synthesis.
  void invalidate();

  /// Releases the worker and Module.
  Future<void> dispose();
}
