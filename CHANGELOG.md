# Changelog

## 0.1.0 - 2026-09-20

- Document the planned managed model setup: one recommended speech bundle,
  explicit installation, offline reuse, a simpler API/example and native build
  packaging requirements. Runtime behavior is unchanged.

- Replace the generic library skeleton with `flutter_local_voice_agent`.
- Add local model integrity validation and staged installation, typed events,
  lifecycle controls, and bounded Dart event delivery.
- Add native sherpa-onnx 1.12.14 VAD, streaming transducer recognition and VITS
  synthesis integration with generation-based output cancellation.
- Add Android/iOS foreground microphone, playback and interruption bridges.
- Add a local-model example, reproducible native provisioning and test tools.
- Keep physical-device, acoustic, thermal, voice quality and redistribution gates
  explicit. This is not a production-qualified or published release.
- Add optional bounded local llama.cpp integration and regression coverage for
  typed lifecycle failures, manifest roles and UTF-8 cancellation handling.
- Add GitHub Actions checks, patch-release tagging, and OIDC publication workflow.
