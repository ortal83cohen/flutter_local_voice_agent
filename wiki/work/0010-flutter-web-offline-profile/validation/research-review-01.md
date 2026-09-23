# Research review — round 01

- Work item: 0010-flutter-web-offline-profile
- Reviewed artifact: wiki/work/0010-flutter-web-offline-profile/00-research.md plus wiki/work/0010-flutter-web-offline-profile/research/upstream-sherpa-web.md, wiki/work/0010-flutter-web-offline-profile/research/local-gap.md, and wiki/work/0010-flutter-web-offline-profile/research/rejected-alternatives.md
- Reviewer: blind research validator
- Date: 2026-09-22

## Verdict

**PASS**

The checked local guards, catalog sizes, and sherpa-onnx 1.13.8 web assets support a second web backend, and every AC-001 through AC-018 has a research basis.

## Verification performed

`python3 tool/lint_wiki.py`

```
lint_wiki: clean (0 warning(s)).
```

Local files read or searched: `lib/src/agent.dart`, `lib/src/model_store.dart`, `lib/src/model_preparation.dart`, `lib/src/contracts.dart`, `lib/src/models.dart`, `pubspec.yaml`, `tool/provision_runtime.py`, `test/platform_refusal_test.dart`, `example/lib/model_storage.dart`, `example/web/index.html`, `doc/capabilities.md`, `native/include/flva.h`, `tool/model_catalog_inventory.json`, `wiki/product/local-voice-agent-prd.md`, `wiki/product/reasonable-platform-coverage.md`, `wiki/product/example-model-catalog.md`, `wiki/adr/0001-offline-voice-architecture.md`, `wiki/work/0008-reasonable-platform-coverage/research/exclusions.md`, `wiki/work/0002-native-offline-pipeline/STATE.yaml`.

`lib/src/agent.dart` imports `dart:io` and `_refuseUnsupportedHost` throws `AgentErrorCode.unsupportedProfile` when `kIsWeb` is true, before `native.create`. `pubspec.yaml` registers android, ios, macos, windows, and linux only. `tool/provision_runtime.py` pins sherpa-onnx v1.12.14 archives. `lib/src/model_store.dart` resolves symbolic links, confines paths to the model root, and requires manifest `runtime` `1.12.14` and `inputRate` 16000. `tool/model_catalog_inventory.json` records `"runtime": "1.12.14"`. `wiki/product/example-model-catalog.md` records compact LJS 114,444,636 bytes, full-precision LJS 383,741,867 bytes, and compact VCTK 116,261,194 bytes. `wiki/product/reasonable-platform-coverage.md` and `wiki/work/0002-native-offline-pipeline/STATE.yaml` still list VITS allocation, physical mobile qualification, and clean consumer-install as open. `lib/src/contracts.dart` states that no audio crosses `NativeVoicePlatform`. `AgentEvent` has sequence, generation, kind, lifecycle, activity, optional text, and optional failure, and no sample field.

`python3` against `https://pub.dev/api/packages/sherpa_onnx` on 2026-09-22:

```
latest version 1.13.8
published 2026-09-11T06:22:32.007890Z
sherpa_onnx_android_arm64 1.13.8
sherpa_onnx_android_armeabi 1.13.8
sherpa_onnx_android_x86 1.13.8
sherpa_onnx_android_x86_64 1.13.8
sherpa_onnx_ios 1.13.8
sherpa_onnx_linux 1.13.8
sherpa_onnx_macos 1.13.8
sherpa_onnx_web 1.13.8
sherpa_onnx_windows 1.13.8
platforms android, ios, linux, macos, web, windows
```

Published `sherpa_onnx_web` 1.13.8 archive `https://pub.dev/api/archives/sherpa_onnx_web-1.13.8.tar.gz` (sha256 `e25a3813eb080636280b23dd4b0098252902675158b66dceda1efba061adf5d7`) contains `assets/sherpa-onnx-wasm-web.wasm` at 15,133,855 bytes plus ASR, TTS, and VAD JavaScript wrappers. Tag `v1.13.8` `flutter/sherpa_onnx_web/pubspec.yaml` matches that asset list. `flutter/sherpa_onnx_web/README.md` at that tag says the package is not expected to be used directly. pub.dev shows Apache-2.0 for `sherpa_onnx` and `sherpa_onnx_web`. The v1.13.8 `LICENSE` file is Apache License 2.0.

`https://pub.dev/packages/sherpa_onnx/example` functions table: streaming speech recognition lists Android, iOS, Linux, macOS, and Windows; text to speech, VAD from microphone, and VAD plus ASR from microphone include Web. Prebuilt web archives on that page include `flutter-vad-from-microphone-web.zip` and `flutter-vad-non-streaming-asr-from-microphone-*-web.zip`. The page section titled Web demos lists VAD and punctuation URLs and does not list a TTS URL. `flutter-examples/tts/README.md` at v1.13.8 says the example works on Web and walks through a `vits-piper` model. `flutter-examples/streaming_asr/README.md` lists Windows, macOS, Linux, Android, and iOS. `https://k2-fsa.github.io/sherpa/onnx/wasm/build.html` is the sherpa 1.3 documentation build page; its `ls -lh` listing shows `sherpa-onnx-wasm-asr-main.wasm` as `10M` and `sherpa-onnx-wasm-asr-main.data` as `199M`, then `python3 -m http.server`. The v1.13.8 README lists Hugging Face WASM spaces for Silero VAD, streaming Zipformer, VAD plus ASR, and TTS labeled Piper and Matcha. `build-wasm-simd-asr.sh`, `build-wasm-simd-tts.sh`, and `build-wasm-simd-vad.sh` at tag v1.13.8 each returned HTTP 200. Microphone Flutter examples `vad-from-microphone` and `vad-non-streaming-asr-from-microphone` depend on `record`.

`https://pub.dev/packages/record` latest 7.1.1 is a federated plugin with android, ios, web, windows, macos, and linux implementations. Its tables mark `pcm16bits` on Firefox, Chrome-based browsers, and Safari, and mark `pcm16bits` streaming across the six platform columns. `https://pub.dev/api/packages/llama_cpp_flutter` latest is 0.8.0, published 2026-07-31; 0.7.0 was published 2026-07-26. The 0.8.0 page still documents wllama, `Cross-Origin-Opener-Policy`, `Cross-Origin-Embedder-Policy`, and single-thread fallback. `browser-whisper` 1.1.0 README documents WebGPU with WASM fallback, OPFS cache, Transformers.js, and a first run that needs network. `lucky-bai/wasm-speech-streaming` README states a ~950MB model and that mobile devices are not supported. `flutter_gemma_speech` marks Web as a stub that throws `UnsupportedError`. `supertonic_flutter` documents about 400 MB models and an `onnxruntime-web` script from `cdn.jsdelivr.net` in `web/index.html`. `speech_to_text_continuous` documentation describes browser `SpeechRecognition` and links to caniuse. MDN `MediaDevices.getUserMedia` states the feature is available only in secure contexts. DeepWiki's sherpa-onnx WebAssembly page contains the strings MediaDevices, AudioContext, CircularBuffer, OfflineTts, and OnlineRecognizer; the research already labels that page as a secondary index.

## Per-criterion results

Not applicable for a research review. This is not an implementation review, so there is no pass or fail row and no negative test.

Coverage of whether the research can support each criterion:

| Criterion | Research can support it | Basis |
|---|---|---|
| AC-001 | yes | Web create is refused before native create, and the chosen path is a second backend over sherpa WASM. See F-001 for the unstated manifest runtime lock. |
| AC-002 | yes | `unsupportedProfile` on fuchsia is in `lib/src/agent.dart` and `test/platform_refusal_test.dart`. |
| AC-003 | yes | `agent.dart`, `model_store.dart`, and `model_preparation.dart` import `dart:io`. |
| AC-004 | yes | This package has no web plugin key and no `sherpa_onnx` or `record` dependency. Both upstream packages are federated onto the native hosts. |
| AC-005 | yes | Apache-2.0 and a pin are required. The exact 1.13.8 SHA-256 is explicitly unresolved. |
| AC-006 | yes | The cited store fails missing files and hash mismatches with `missingAsset` or `invalidAsset`, before microphone use in the product offline contract. |
| AC-007 | yes | A web LLM is deferred. Deterministic replies are the first slice. |
| AC-008 | yes | Full duplex already throws `unsupportedProfile`, and half-duplex is a retained contract. |
| AC-009 | yes | Secure context is stated in the research. The citation gap is F-002. |
| AC-010 | yes | `AgentErrorCode.permissionDenied` exists on the facade the research says must stay. The research does not restate the web denial mapping. |
| AC-011 | yes | Events carry no sample field, and the cited store requires 16000 Hz mono input. PCM must stay off the method channel and out of logs. |
| AC-012 | yes | Official Flutter web evidence covers VAD, non-streaming ASR, and TTS, including a VITS Piper sample. Whether this catalog's files load in 1.13.8 WASM is unresolved. |
| AC-013 | yes | The retained facade already has interrupt and generation identity. |
| AC-014 | yes | `example/web/index.html` is a generic bootstrap, not a voice host. The criterion is a later build check. |
| AC-015 | yes | Five native hosts stay on flva, and the 0002 gates are still recorded open. |
| AC-016 | yes | The product PRD disables content logging by default, and the research forbids PCM in logs. |
| AC-017 | yes | Models stay app-owned. Catalog byte sizes are the reason not to start from the largest pack. |
| AC-018 | yes | Both packages are Apache-2.0. The SHA-256 pin is a stated requirement whose value is unresolved until download. |

## Findings

### F-001 — Manifest runtime lock is omitted beside the 1.13.8 web engine

- Severity: IMPORTANT
- Location: `wiki/work/0010-flutter-web-offline-profile/research/local-gap.md:22`
- Criterion affected: AC-001
- Observation: The evidence says `FileModelStore` uses `Directory`, `File`, and symbolic-link confinement. Those uses are present. The same `validate` method rejects a manifest unless `runtime` is the string `1.12.14` and `inputRate` is 16000 (`lib/src/model_store.dart:49` and `lib/src/model_store.dart:53`). `tool/model_catalog_inventory.json` labels the catalog runtime `1.12.14`. The merged research chooses sherpa-onnx 1.13.8 WASM (`wiki/work/0010-flutter-web-offline-profile/00-research.md:21`) and leaves file loading unresolved (`wiki/work/0010-flutter-web-offline-profile/00-research.md:72`). It does not record this Dart equality check.
- Why it matters: A compact pack labeled `1.12.14` passes the current validator while the proposed web binary is 1.13.8. A manifest labeled `1.13.8` fails validation before any WASM load. AC-001's "validated compact model pack" depends on that gate.

### F-002 — Secure-context constraint has no source marker

- Severity: NIT
- Location: `wiki/work/0010-flutter-web-offline-profile/00-research.md:65`
- Criterion affected: AC-009
- Observation: The constraints list states that `getUserMedia` requires a secure context and that TTS playback may need a user gesture. That sentence has no source in the document's source list and is not marked `[UNVERIFIED]`. MDN documents `getUserMedia` as secure-context only. The user-gesture half stays hedged, and `wiki/work/0010-flutter-web-offline-profile/research/rejected-alternatives.md:76` still leaves Safari autoplay unresolved.
- Why it matters: AC-009 uses the secure-context premise. The premise is not tied to a cited source inside the research artifact.

### F-003 — llama_cpp_flutter version is stale

- Severity: NIT
- Location: `wiki/work/0010-flutter-web-offline-profile/research/rejected-alternatives.md:52`
- Criterion affected: none
- Observation: The evidence names llama_cpp_flutter 0.7.0. On 2026-09-22 the pub.dev latest version is 0.8.0, published 2026-07-31. The 0.8.0 page still documents wllama, COOP, COEP, and single-thread fallback.
- Why it matters: The version pin is stale. The optional-LLM conclusion does not depend on 0.7.0, and no acceptance criterion requires wllama.

### F-004 — Combined-binary reason is not in the cited build page

- Severity: NIT
- Location: `wiki/work/0010-flutter-web-offline-profile/research/rejected-alternatives.md:46`
- Criterion affected: none
- Observation: The evidence says sherpa publishes separate WASM build scripts for ASR, TTS, and VAD because a combined browser binary is a packaging problem. The cited page `https://k2-fsa.github.io/sherpa/onnx/wasm/build.html` documents `build-wasm-simd-asr.sh` and does not state that reason. Separate `build-wasm-simd-tts.sh` and `build-wasm-simd-vad.sh` files exist at tag v1.13.8.
- Why it matters: The split-script fact is real, but the causal clause is not supported by the source named on the next line.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | research |
| F-002 | research |
| F-003 | research |
| F-004 | research |
