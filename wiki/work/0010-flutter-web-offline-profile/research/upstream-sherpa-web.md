# Research: Upstream sherpa-onnx and Flutter web evidence

## Question

Does sherpa-onnx already provide an offline browser path for Silero VAD, speech recognition and VITS-family TTS that a Flutter host can call without a speech server?

## Answer

Yes. sherpa-onnx ships Emscripten WebAssembly builds and a Flutter web plugin that loads those builds. Official Flutter web demos cover VAD from microphone, VAD plus non-streaming ASR from microphone, and TTS. Official Flutter streaming ASR examples omit web. Separate HTML WASM pages do run streaming Zipformer in the browser.

## Findings

### Official WASM engine

- Claim: sherpa-onnx documents local in-browser ASR after an Emscripten SIMD build, served over HTTP, with no recognition server.
- Evidence: The 1.3 documentation build page walks through downloading a streaming Zipformer model, running build-wasm-simd-asr.sh, and speaking into a local HTTP page. The produced tree includes a WASM binary, JS glue and a model data file. One documented bilingual Zipformer tree listed about 10 MB of WASM and about 199 MB of model data.
- Source: https://k2-fsa.github.io/sherpa/onnx/wasm/build.html — consulted 2026-09-22

### Browser capabilities listed by upstream

- Claim: Upstream WASM wrappers exist for online and offline recognizers, offline TTS including VITS, and VAD, with microphone audio flowing through the browser MediaDevices API and AudioContext into a circular buffer.
- Evidence: The project README states WebAssembly support and lists Hugging Face WASM spaces for Silero VAD, streaming Zipformer and Paraformer, VAD plus ASR, and TTS. A secondary DeepWiki summary of the same tree names OnlineRecognizer, OfflineRecognizer, OfflineTts and CircularBuffer.
- Source: https://github.com/k2-fsa/sherpa-onnx — consulted 2026-09-22; https://deepwiki.com/k2-fsa/sherpa-onnx/4.1-webassembly-(browser-and-node.js) — consulted 2026-09-22. Treat DeepWiki wording as a secondary index, not a primary API contract.

### Flutter package and web plugin

- Claim: pub.dev publishes sherpa_onnx 1.13.8 with a sherpa_onnx_web 1.13.8 implementation that loads WASM from Flutter assets.
- Evidence: sherpa_onnx_web.pubspec.yaml registers a web plugin class and ships sherpa-onnx-wasm-web.js, sherpa-onnx-wasm-web.wasm, and JS wrappers for ASR, TTS, VAD, keyword spotting, punctuation, diarization and speech enhancement. The Dart loader evaluates the glue, instantiates the Emscripten factory with wasmBinary, and exposes Module on the global object. Callers are told to enter through sherpa_onnx, not to import sherpa_onnx_web directly.
- Source: https://pub.dev/packages/sherpa_onnx — consulted 2026-09-22; https://pub.dev/packages/sherpa_onnx_web — consulted 2026-09-22; https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/flutter/sherpa_onnx_web/pubspec.yaml — consulted 2026-09-22; https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/flutter/sherpa_onnx_web/lib/sherpa_onnx_web.dart — consulted 2026-09-22

### Official Flutter web demos

- Claim: Prebuilt Flutter web archives exist for VAD from file, VAD from microphone, VAD plus non-streaming ASR from file, VAD plus non-streaming ASR from microphone, and punctuation. Source-table support for TTS includes Web. The streaming speech-recognition Flutter example lists Android, iOS, Linux, macOS and Windows only.
- Evidence: The sherpa_onnx example page lists those web zip names and a functions table where Streaming speech recognition omits Web while VAD plus ASR from microphone includes Web. The streaming_asr README repeats the five native hosts and does not mention web.
- Source: https://pub.dev/packages/sherpa_onnx/example — consulted 2026-09-22; https://github.com/k2-fsa/sherpa-onnx/blob/master/flutter-examples/streaming_asr/README.md — consulted 2026-09-22

### Flutter web microphone streaming

- Claim: The record package can stream PCM16 on Flutter web in Chrome, Firefox and Safari. Official sherpa Flutter microphone demos use that package on native hosts.
- Evidence: The record encoder table marks pcm16bits and startStream as supported on web. This is evidence that Flutter web can obtain raw microphone frames. It is not a mandate to take that package as a dependency of this repository.
- Source: https://pub.dev/packages/record — consulted 2026-09-22

### License

- Claim: sherpa-onnx and sherpa_onnx_web are Apache-2.0.
- Evidence: pub.dev license field for both packages.
- Source: https://pub.dev/packages/sherpa_onnx — consulted 2026-09-22; https://pub.dev/packages/sherpa_onnx_web — consulted 2026-09-22

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Call official sherpa WASM from a Flutter web backend | Load pinned WASM assets and run VAD, offline ASR and TTS in the page | Integration and model packaging | Chosen as the engine source |
| Use the sherpa_onnx pub plugin as a library dependency | Import their Dart API and federated native packages | Low integration, high collision risk | Rejected in the local-gap stream |
| Ignore official Flutter web demos and only use HTML WASM pages | Reimplement Flutter bindings from JS demos | Higher binding cost | Rejected as the primary evidence path; HTML pages remain supporting evidence for streaming |

## Constraints discovered

- Official Flutter streaming ASR is not a web-supported example. A first slice that requires streaming Zipformer on Flutter web is not backed by that table.
- WASM and model bytes are large. One documented ASR tree was about 10 MB WASM plus about 199 MB model data.
- sherpa_onnx_web says not to import it as a standalone application dependency.
- Apache-2.0 attribution is required if WASM assets are vendored.

## Unresolved

- [UNRESOLVED: Whether this repository's compact Zipformer, Silero and VITS files load unchanged in sherpa-onnx 1.13.8 WASM.]
- [UNRESOLVED: Whether OfflineRecognizer plus Silero VAD on Flutter web can meet the product's turn timing on Chrome and Safari. No measurement was taken in this research.]
- [UNRESOLVED: Whether OnlineRecognizer can be wired through the Flutter web WASM module even though the official streaming example omits web.]
- [UNRESOLVED: Exact WASM binary size and thread or COOP/COEP requirements of sherpa-onnx-wasm-web.wasm 1.13.8 were not re-downloaded and hashed in this run.]

## Sources

- https://k2-fsa.github.io/sherpa/onnx/wasm/build.html — 2026-09-22
- https://github.com/k2-fsa/sherpa-onnx — 2026-09-22
- https://pub.dev/packages/sherpa_onnx — 2026-09-22
- https://pub.dev/packages/sherpa_onnx_web — 2026-09-22
- https://pub.dev/packages/sherpa_onnx/example — 2026-09-22
- https://github.com/k2-fsa/sherpa-onnx/blob/master/flutter-examples/streaming_asr/README.md — 2026-09-22
- https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/flutter/sherpa_onnx_web/lib/sherpa_onnx_web.dart — 2026-09-22
- https://pub.dev/packages/record — 2026-09-22
