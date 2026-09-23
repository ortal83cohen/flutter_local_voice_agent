/// Capture and playback owned by the web backend. PCM stays inside this owner.
abstract interface class WebAudioOwner {
  /// Whether the current browsing context is secure.
  bool get isSecureContext;

  /// Requests the microphone. Throws permissionDenied on denial.
  Future<void> requestMicrophone();

  /// Starts delivering 16 kHz mono frames to [onFrame]. Frames never leave here.
  Future<void> startCapture(void Function(List<double> frame) onFrame);

  /// Stops capture. Does not start playback.
  Future<void> stopCapture();

  /// Plays generated TTS. Must not be called after a permission denial.
  Future<void> play(List<double> samples);

  /// Drops any queued or playing audio so cancelled generations stay silent.
  Future<void> flushPlayback();

  /// Releases devices.
  Future<void> dispose();
}
