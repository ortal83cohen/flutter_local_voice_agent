# Changelog

## Unreleased

- Rewrite the package README and pub.dev metadata around a complete on-device
  speech-to-text and text-to-speech agent, with badges, topics, and an example
  page.
- Make the cross-origin TLS redirect regression portable across OpenSSL-backed
  CI runners by explicitly validating its generated loopback certificates.
- Replace the example's required model path with a verified English speech
  catalog, explicit downloads, progress/cancel/retry and private offline reuse.
- Export compact/full-precision model descriptors with pinned hashes and notices;
  add opt-in bounded HTTPS redirects restricted to exact publisher origins.
- Add example storage/backup handling, lifecycle and catalog transport regressions.

- Add explicit host-configured HTTPS model preparation with trusted descriptor
  verification, staged immutable installation, cancellation, progress snapshots
  and offline reuse. Existing local creation and model-store APIs stay offline.
- Add controlled real-TLS installer tests; general library storage discovery,
  automatic cleanup and physical-device setup qualification remain open.

- Reject invalid Unicode and empty/NUL logic replies before synthesis, with
  recoverable typed errors and exhaustive native scalar regression coverage.
- Exercise invalid native replies on an awaited generation before accepting a
  valid reply, preventing state rejection from masking validation defects.
- Restore Flutter SDK build-tool paths in the Android and iOS examples; verify
  speech-only debug/release builds and the emulator missing-model path.
- Clarify provisioned-checkout requirements and unfinished native packaging.

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
