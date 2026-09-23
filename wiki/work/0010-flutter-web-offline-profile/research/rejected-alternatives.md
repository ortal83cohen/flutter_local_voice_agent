# Research: Rejected Flutter web speech alternatives

## Question

Which other in-browser speech stacks exist, and do any of them satisfy this product's offline, app-owned-model and sherpa-family contracts better than official sherpa-onnx WASM?

## Answer

No. Cloud or browser SpeechRecognition APIs break the offline and app-owned-model contract. whisper.cpp, transformers.js and Kyutai WASM are local but change the engine family. flutter_gemma_speech stubs web. Compiling flva.cpp to WASM keeps the coordinator but repeats work sherpa already ships and still needs a JS audio owner. Optional llama.cpp on web has a later path through wllama and is not required for deterministic replies.

## Findings

### Web Speech and speech_to_text

- Claim: Flutter speech_to_text on web uses the browser SpeechRecognition API. Availability and offline behavior are browser-dependent and not an app-owned model inventory.
- Evidence: The package documents web support through the browser recognizer and points to caniuse variability. The product PRD says native OS services cannot satisfy the default app-controlled asset contract.
- Source: https://pub.dev/documentation/speech_to_text_continuous/latest/ — consulted 2026-09-22. Mark the continuous-fork page as a related speech_to_text document, not this repository's dependency. wiki/product/local-voice-agent-prd.md Offline contract — consulted 2026-09-22

### whisper.cpp / transformers.js / browser-whisper

- Claim: Browser Whisper stacks can run locally after the first model download, often with WebGPU and OPFS cache, but they are a different ASR family and are typically windowed or file-oriented rather than this product's sherpa streaming transducer.
- Evidence: browser-whisper documents WebGPU with WASM fallback and OPFS caching, and says the first run needs network for weights. The PRD already placed whisper.cpp as an alternate adapter, not the default.
- Source: https://www.npmjs.com/package/browser-whisper — consulted 2026-09-22; wiki/product/local-voice-agent-prd.md STT comparison — consulted 2026-09-22

### Kyutai WASM streaming

- Claim: A Rust WASM demo runs a roughly 950 MB streaming model entirely in the browser after download and does not support mobile.
- Evidence: lucky-bai/wasm-speech-streaming README states the model size, offline-after-download behavior and no mobile support.
- Source: https://github.com/lucky-bai/wasm-speech-streaming — consulted 2026-09-22

### flutter_gemma_speech

- Claim: The package provides on-device STT and TTS through LiteRT on native hosts and currently throws UnsupportedError on web.
- Evidence: pub.dev platform table lists Web as a stub.
- Source: https://pub.dev/packages/flutter_gemma_speech — consulted 2026-09-22

### supertonic_flutter TTS

- Claim: A local Flutter TTS package supports web through ONNX Runtime Web with about 400 MB models and a CDN script in index.html.
- Evidence: pub.dev page. This is TTS only, a different voice family, and the documented web setup loads onnxruntime-web from a public CDN at page start, which conflicts with a strict bundled-engine offline boot unless the host vendors that script.
- Source: https://pub.dev/packages/supertonic_flutter — consulted 2026-09-22

### Emscripten of flva.cpp

- Claim: Compiling the existing C coordinator to WASM would still replace OS audio with getUserMedia and would duplicate sherpa's already-split WASM builds.
- Evidence: native/include/flva.h and native/src/flva.cpp are the current ABI. sherpa publishes separate WASM build scripts for ASR, TTS and VAD. The cited build page documents the ASR script. Separate TTS and VAD scripts exist at tag v1.13.8. The claim that a combined browser binary is a packaging problem is [UNVERIFIED] against that page. ADR 0001 requires native worker ownership on qualified hosts, not a second incomplete port of the same coordinator.
- Source: native/include/flva.h; wiki/adr/0001-offline-voice-architecture.md; https://k2-fsa.github.io/sherpa/onnx/wasm/build.html — consulted 2026-09-22

### Optional web LLM

- Claim: llama_cpp_flutter can run wllama WASM on Flutter web. Multithreading needs cross-origin isolation headers. This is optional and not needed for deterministic Dart replies.
- Evidence: llama_cpp_flutter 0.8.0 documents web via wllama, COOP and COEP, and single-thread fallback.
- Source: https://pub.dev/packages/llama_cpp_flutter — consulted 2026-09-22; https://github.com/ngxson/wllama — consulted 2026-09-22

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| sherpa-onnx WASM | Same engine family, official Flutter web demos | Integration | Chosen |
| Web Speech API | Browser recognizer | Low | Rejected: not app-owned, not reliably offline |
| whisper / transformers.js | Local after download | New adapter family | Rejected for the default web profile |
| Kyutai WASM | Local streaming | About 950 MB, no mobile | Rejected |
| flutter_gemma_speech | LiteRT | Web stub | Rejected |
| flva.cpp to WASM | Keep coordinator | Highest | Rejected for the first slice |
| wllama in the first slice | Optional LLM | Extra isolation headers and memory | Rejected for the first slice; keep as a later adapter |

## Constraints discovered

- The PRD offline contract forbids network for initialization, inference, fallback, telemetry or error recovery. A first-run model download is allowed only as an explicit host preparation path, already used by the example catalog.
- Loading ONNX Runtime from a public CDN at page boot is not an acceptable default for this product.
- Changing the default ASR family on web would split quality, packaging and license review from the native catalog.

## Unresolved

- [UNRESOLVED: Whether a later web LLM adapter should be wllama, WebLLM, or unsupported permanently.]
- [UNRESOLVED: Whether Safari autoplay and getUserMedia permission text need a product-specific string beyond the existing iOS usage description.]

## Sources

- https://pub.dev/documentation/speech_to_text_continuous/latest/ — 2026-09-22
- https://www.npmjs.com/package/browser-whisper — 2026-09-22
- https://github.com/lucky-bai/wasm-speech-streaming — 2026-09-22
- https://pub.dev/packages/flutter_gemma_speech — 2026-09-22
- https://pub.dev/packages/supertonic_flutter — 2026-09-22
- https://pub.dev/packages/llama_cpp_flutter — 2026-09-22
- https://github.com/ngxson/wllama — 2026-09-22
- wiki/product/local-voice-agent-prd.md — 2026-09-22
- native/include/flva.h — 2026-09-22
