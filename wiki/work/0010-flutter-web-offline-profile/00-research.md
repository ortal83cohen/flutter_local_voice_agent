# Research: Flutter web offline voice profile

## Question

Is there a product-fit way to run this offline Flutter voice agent on Flutter web, even if the work is more complex than adding another native plugin host?

## Answer

Yes, as a second session backend, not as reuse of flva.h. Official sherpa-onnx WebAssembly already runs Silero VAD, recognition and VITS-family TTS in the browser. This repository must split dart:io, keep native hosts on the existing C ABI, and own microphone and speaker inside a web backend. The first slice is VAD plus non-streaming ASR, compact-catalog TTS, and deterministic Dart replies. Streaming Zipformer, full-precision LJS and local LLM stay out of the first slice.

## Findings

### Product contract that web must still meet

- Claim: The SDK must not use the network for initialization, inference, fallback, telemetry or error recovery. Models are app-owned. OS speech APIs do not satisfy that contract. Deterministic logic must work without an LLM. Web was outside the first release and later excluded by work 0008 because it cannot load flva.h.
- Evidence: wiki/product/local-voice-agent-prd.md Offline contract and Product decision and scope. wiki/work/0008-reasonable-platform-coverage/research/exclusions.md. wiki/product/reasonable-platform-coverage.md.
- Source: those documents — consulted 2026-09-22

### Upstream engine already exists

- Claim: sherpa-onnx 1.13.8 ships Flutter web WASM assets and official web demos for VAD from microphone, VAD plus non-streaming ASR from microphone, and TTS. Streaming Flutter ASR examples omit web. HTML WASM pages do run streaming Zipformer.
- Evidence: Merged from research/upstream-sherpa-web.md.
- Source: https://pub.dev/packages/sherpa_onnx/example ; https://k2-fsa.github.io/sherpa/onnx/wasm/build.html — consulted 2026-09-22

### This repository cannot compile for web today

- Claim: Create refuses web with unsupportedProfile. agent, model_store and model_preparation import dart:io. The plugin manifest has no web key. Native sherpa stays pinned at v1.12.14. FileModelStore.validate also requires manifest runtime 1.12.14 and inputRate 16000. A web store that required runtime 1.13.8 would reject the existing compact catalog.
- Evidence: Merged from research/local-gap.md.
- Source: lib/src/agent.dart; lib/src/model_store.dart; pubspec.yaml — consulted 2026-09-22

### Why a pub.dev sherpa_onnx dependency is unsafe here

- Claim: sherpa_onnx transitively registers native sherpa plugins for Android, iOS and desktop. This package already ships libflva against sherpa-onnx v1.12.14. Two runtimes in one consumer app are a collision and size risk. package record would likewise register a second microphone plugin on native hosts.
- Evidence: Merged from research/local-gap.md.
- Source: https://pub.dev/packages/sherpa_onnx — consulted 2026-09-22

### Rejected stacks

- Claim: Web Speech, whisper/transformers.js, Kyutai WASM, flutter_gemma_speech and an Emscripten port of flva.cpp do not beat official sherpa WASM on this product's constraints. wllama is a later optional LLM path, not a first-slice requirement.
- Evidence: Merged from research/rejected-alternatives.md.
- Source: that stream — consulted 2026-09-22

### Catalog weight on web

- Claim: Compact LJS is 114,444,636 bytes and compact VCTK is 116,261,194 bytes. Full-precision LJS is 383,741,867 bytes. A first web example should not start with the largest pack.
- Evidence: wiki/product/example-model-catalog.md.
- Source: wiki/product/example-model-catalog.md — consulted 2026-09-22

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Web session backend over official sherpa WASM, no sherpa_onnx or record dependency | Conditional dart:io, vendored WASM, package web audio, same LocalVoiceAgent facade | Medium-high | Chosen |
| Add sherpa_onnx and record as plugin dependencies | Fastest Flutter wiring | Dual native sherpa and a second mic plugin | Rejected |
| Compile flva.cpp to WASM | Keep C coordinator | Highest, still needs JS audio | Rejected for the first slice |
| Web Speech or cloud speech | Browser or server recognizer | Low | Rejected: breaks offline and app-owned models |
| Keep excluding web | Current 0008 behavior | Zero | Rejected by the product request |
| First slice includes streaming Zipformer, all catalog packs and wllama | Full native parity | Unverified Flutter streaming web path plus memory risk | Rejected for the first slice |

## Constraints discovered

- Native hosts must keep OS-owned PCM and flva.h. Work 0008 exclusion of web as a native host remains true.
- PCM may live inside a web backend. It must not become a method-channel payload and must not appear in logs.
- Apache-2.0 notices are required for vendored sherpa WASM.
- getUserMedia requires a secure context. Source: https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia — consulted 2026-09-22. TTS playback may need a user gesture. That gesture half is [UNVERIFIED] in this artifact; Safari autoplay remains unresolved in research/rejected-alternatives.md.
- Parent 0002 VITS allocation, physical mobile qualification and clean consumer-install stay open.
- Explicit model download remains a host or example path, not silent SDK fetch at create.
- No commit, push or publication is in scope for this research.

## Unresolved

- [UNRESOLVED: Whether this repository's compact Zipformer plus VITS files load in sherpa-onnx 1.13.8 WASM.]
- [UNRESOLVED: Chrome and Safari microphone-to-speaker latency and memory for the compact pack.]
- [UNRESOLVED: Whether OnlineRecognizer can be added later through the same WASM module.]
- [UNRESOLVED: Exact SHA-256 of the 1.13.8 sherpa-onnx-wasm-web.wasm asset until implementation downloads and pins it.]
- [UNRESOLVED: Whether example catalog preparation on web uses bundled assets only or Origin Private File System with the existing hash policy.]
- [UNRESOLVED: Whether a later web LLM adapter should exist.]

## Sources

- wiki/work/0010-flutter-web-offline-profile/research/upstream-sherpa-web.md — 2026-09-22
- wiki/work/0010-flutter-web-offline-profile/research/local-gap.md — 2026-09-22
- wiki/work/0010-flutter-web-offline-profile/research/rejected-alternatives.md — 2026-09-22
- wiki/product/local-voice-agent-prd.md — 2026-09-22
- wiki/product/reasonable-platform-coverage.md — 2026-09-22
- wiki/product/example-model-catalog.md — 2026-09-22
- wiki/adr/0001-offline-voice-architecture.md — 2026-09-22
- https://pub.dev/packages/sherpa_onnx — 2026-09-22
- https://k2-fsa.github.io/sherpa/onnx/wasm/build.html — 2026-09-22
- https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia — 2026-09-22
