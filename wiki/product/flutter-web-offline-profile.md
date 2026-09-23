---
id: flutter-web-offline-profile
title: Flutter web offline voice profile
status: active
owner: root
last_verified: 2026-09-22
applies_to: ["lib/**", "example/web/**", "example/lib/**", "pubspec.yaml"]
summary: Second session backend for Flutter web using vendored sherpa-onnx 1.13.8 WASM; native flva hosts stay unchanged. Browser microphone session and compact-catalog WASM load remain unverified.
---

# Flutter web offline voice profile

Flutter web uses a second session behind LocalVoiceAgent. It does not reuse
flva.h or libflva. Native Android, iOS, macOS, Windows and Linux stay on
flva.h and official sherpa-onnx v1.12.14.

## Observable behavior

A Flutter web host that has the web backend, a validated compact English pack,
and a secure microphone context can create a half-duplex local conversation.
Recognition uses Silero VAD plus a non-streaming offline recognizer. Replies
use the existing deterministic Dart function. Speech uses the compact VITS
voice. There is no speech server. Create does not download.

The example web host lists only the compact catalog pack. Start stays disabled
until that pack validates. Native example storage remains on dart:io.

## Limits

- No `sherpa_onnx`, `sherpa_onnx_web` or `record` library dependency.
- No catalog weights inside the plugin package. Only pinned WASM runtime
  assets and Apache-2.0 notices ship with the plugin.
- useLocalLlm is unsupported on web in this slice.
- Full duplex, AEC, barge-in, background capture and wake word stay unsupported.
- Streaming Zipformer on Flutter web is a follow-up.
- Full-precision LJS is out of the first example.
- Parent 0002 VITS allocation, physical mobile qualification and clean
  consumer-install stay open.

## Unverified live paths

Whether this repository's compact Zipformer plus VITS files load in
sherpa-onnx 1.13.8 WASM remains [UNVERIFIED]. If construct rejects those
files, create fails with `invalidAsset`. There is no silent model swap.

A browser microphone-to-speaker session has not been run. Record that gap
in verification rather than a pass.

## Related records

- Work item: wiki/work/0010-flutter-web-offline-profile/
- Architecture decision: wiki/adr/0005-flutter-web-offline-profile.md
- Native coverage: wiki/product/reasonable-platform-coverage.md
