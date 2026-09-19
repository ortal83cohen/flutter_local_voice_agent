# Research: offline mobile VAD and speech-to-text options

## Scope and date

This is a representative, current upstream-source comparison for an Android- and iOS-first Flutter voice agent. It covers local inference and model provisioning that can occur before offline operation. It does not select an engine or define the product architecture. Sources were consulted on 2026-09-19. "Offline" here means audio inference does not require a network after required models are present; it does not mean that a platform service is guaranteed to be installed.

## Question

Which practical VAD and STT families can support strict local inference in a Flutter mobile product, and what constraints must a later design and benchmark resolve?

## Answer

There are two credible local-inference routes to carry forward: a small neural VAD (Silero, independently or through sherpa-onnx) paired either with a streaming sherpa-onnx transducer/Zipformer model for live partial text, or with whisper.cpp for chunk/final transcription. Vosk is a viable streaming, Apache-2.0 alternative but has no upstream Dart/Flutter binding; native Apple/Android recognizers are not a portable strict-offline foundation because availability, languages, model installation, and implementation are controlled by the OS/device.

The source material establishes compatibility and some model-size facts, but not a device-specific latency, RAM, battery, final-word accuracy, binary-size, or Flutter-bridge result. Those quantities remain [UNVERIFIED] until measured on the supported Android/iOS matrix with pinned models and release builds.

## Findings

### Voice activity detection

| Family | Source-backed capability and audio contract | Mobile / Flutter integration | License and evidence limits |
|---|---|---|---|
| Silero VAD | Neural VAD; the project documents streaming support, about 260K parameters, and 8 kHz/16 kHz support. Its ONNX wrapper accepts fixed 512-sample 16 kHz or 256-sample 8 kHz frames and carries recurrent state between calls. The upstream README states a 30+ ms chunk takes under 1 ms on one CPU thread; this is upstream-provided, not a result for the target devices. | ONNX is explicitly described as suitable for mobile/edge/ARM; sherpa-onnx publishes Flutter VAD examples for Android and iOS. Direct integration still needs a supported native/FFI or ONNX runtime packaging path. | Silero package metadata declares MIT. VAD is language-independent for product purposes; the training-language count is not a recognition-language guarantee. Model/runtime binary size, target-device latency/RAM, and threshold quality are [UNVERIFIED]. |
| WebRTC VAD | Classical binary speech/no-speech detector. The maintained wrapper documentation accepts only mono 16-bit PCM at 8/16/32/48 kHz in 10/20/30 ms frames. It exposes aggressiveness modes but no speech probabilities in that API. | The cited repository is a Python wrapper, not a Flutter integration. A Flutter implementation would require a native bridge or a separate maintained package and license/dependency review. | The wrapper notes inclusion of a WebRTC license. Exact Flutter package selection, native binary impact, device performance, and endpoint behavior are [UNVERIFIED]. |
| sherpa-onnx VAD | sherpa-onnx’s Flutter examples package microphone VAD using Silero VAD and list Android/iOS support; its own docs state inference runs locally without Internet. | The `sherpa_onnx` Dart package and Flutter examples cover both VAD and VAD+ASR examples. This is the most directly evidenced single-runtime Flutter route. | sherpa-onnx is Apache-2.0. The Silero model has separate provenance/license obligations; validate every shipped model asset. |
| whisper.cpp VAD | whisper.cpp lists VAD among its features alongside ASR. The README does not establish a Flutter-ready VAD API contract in the material consulted. | iOS and Android are listed as supported platforms for whisper.cpp, but a Flutter FFI/plugin bridge would still be owned by this project or a separately reviewed dependency. | whisper.cpp is MIT. Treat its VAD as a candidate to benchmark, not as the selected segmentation contract. |

### Speech-to-text

| Family | Streaming versus chunked behavior | Platform/language/model facts | License and integration implications |
|---|---|---|---|
| sherpa-onnx online ASR (transducer / Zipformer and other supplied online models) | The upstream Flutter example calls this “real-time speech recognition,” supports Android/iOS, and says “Streaming” and “Online” are equivalent. sherpa-onnx documents both streaming and non-streaming ASR examples. This is the strongest source-backed option for partial hypotheses while audio is arriving. | sherpa-onnx says recognition is local and documents Android/iOS builds; its Flutter examples list Android, iOS, Linux, macOS and Windows. Available model languages vary by exact downloaded model, rather than by engine. | Apache-2.0 engine. Model license, tokenizer, language coverage, downloadable asset integrity, and Apple/Android ABI/package sizes require per-model validation. Partial stability, endpoint latency, RAM, battery, WER, and model download size are [UNVERIFIED]. |
| whisper.cpp (OpenAI Whisper models) | Whisper is encoder-decoder transcription commonly run on bounded audio windows; whisper.cpp exposes its own examples and supports VAD. Its upstream README demonstrates fully offline on-device iPhone use and lists iOS and Android. It should therefore be evaluated for VAD-delimited chunks/final text, and only considered for live partial text after a dedicated streaming UX test. | Model family is multilingual except `.en` models. The current README lists unquantized `tiny` 75 MiB/~273 MB, `base` 142 MiB/~388 MB, `small` 466 MiB/~852 MB, `medium` 1.5 GiB/~2.1 GB, and `large` 2.9 GiB/~3.9 GB disk/memory. Quantization can reduce disk/memory, but exact target results differ. | MIT engine. OpenAI model terms/provenance must be checked separately before distribution. A Flutter bridge, audio handoff, model lifecycle, cancellation and background/thermal behavior need explicit ownership. Release binary increment, mobile RAM, accuracy, latency and partial-result quality are [UNVERIFIED]. |
| Vosk / Kaldi-derived models | Upstream describes continuous large-vocabulary transcription with a streaming API and “zero-latency response”; treat that phrase as a product claim, not an observed target metric. | Vosk is explicitly offline and lists Android and iOS. It provides bindings for several languages but the cited upstream list does not include Dart. It states small models are about 50 MB; exact model and language determine coverage/quality. | Apache-2.0 API. Flutter requires an FFI/platform wrapper or a reviewed community binding. Current repository activity, model license, iOS distribution viability, target latency/RAM and language-specific quality are [UNVERIFIED]. |
| sherpa-onnx non-streaming ASR (including Whisper/Moonshine/CTC model families) | The Dart and Flutter examples include non-streaming ASR and VAD+non-streaming-ASR. This is a viable finalization route when VAD supplies an utterance rather than a live partial-text route. | Exact languages vary: upstream examples include English Whisper/Moonshine, Chinese Zipformer, multilingual SenseVoice, and other models. No engine-level “all languages” claim is valid. | Apache-2.0 engine; each model’s license must be accepted independently. Compare models using the same utterance boundaries as streaming candidates. All device metrics are [UNVERIFIED]. |
| Native Apple Speech | Apple exposes `requiresOnDeviceRecognition`, allowing a request to require on-device processing when supported. Availability depends on recognizer locale/device/OS and is not established as a provisionable, cross-platform inventory by the consulted documentation. | Apple-only, exposed through Swift/Objective-C; Flutter needs a platform channel/plugin. The exact supported offline locales and their device/model prerequisites are [UNVERIFIED] in this research. | OS framework, not a redistributable model runtime controlled by this project. Reject as the sole strict-offline cross-platform engine; retain only as an optional acceleration/fallback subject to an explicit no-network test. |
| Native Android `SpeechRecognizer` | Generic `SpeechRecognizer` documentation warns that the implementation is likely to stream audio to remote servers. API 31 added `createOnDeviceSpeechRecognizer`; it throws if `isOnDeviceRecognitionAvailable` is false. | Android-only and availability is device-service dependent. It supplies partial-result callbacks, but the sources do not prove a given language/device will work offline after app provisioning. Flutter requires a platform channel/plugin. | OS service, not a bundled deterministic model. Reject as the sole strict-offline route. Any optional use must check availability and exercise airplane-mode testing; supported locales, model provisioning, latency/RAM and behavior across OEMs are [UNVERIFIED]. |

### Audio and segmentation implications

- **Proposal, not a decision:** make the engine boundary accept mono `float32` PCM with an explicit sample rate and monotonic capture timestamp; resample once per selected engine/model. This can represent microphone capture independently of the 16-bit PCM framing required by WebRTC VAD and the 8/16 kHz fixed frames documented for Silero.
- **Proposal, not a decision:** retain VAD pre-roll, utterance start/end timestamps, and sample counts with each emitted segment. A streaming recognizer can receive continuous frames while VAD controls UX/endpoints; a chunked recognizer can receive only finalized VAD segments. Benchmark both because VAD cutoffs can delete initial/final phonemes.
- The documented Silero contract makes 16 kHz a practical common evaluation rate: 512 samples is 32 ms. This is not proof that every chosen STT model wants 16 kHz, so the model manifest must declare its actual input rate and conversion.
- Do not promise “zero latency.” Separate capture/frame duration, VAD decision delay, utterance hangover, first partial, final result, and UI dispatch in measurements.

## Options considered

| Option | How it works | Cost | Why shortlisted or rejected for the next phase |
|---|---|---|---|
| Silero VAD + sherpa-onnx streaming ASR | Local neural VAD plus online transducer/Zipformer-compatible ASR, with Dart/Flutter examples. | Native runtime/model asset management and per-model evaluation. | **Shortlist.** It has direct Flutter Android/iOS evidence and true streaming support. |
| Silero VAD + whisper.cpp | Segment locally, then transcribe bounded utterances with a quantized Whisper model. | FFI ownership and potentially substantial model/RAM use. | **Shortlist.** Strong offline iOS/Android C/C++ evidence and clear model-size trade-offs; partial-text experience is not yet proven. |
| sherpa-onnx VAD + non-streaming model | One local runtime for segmentation and final ASR. | No live partial text from the non-streaming decoder. | **Shortlist for comparison.** Simplifies runtime ownership, subject to actual model quality/footprint. |
| Vosk streaming | Local Kaldi-derived streaming recognizer through a Flutter bridge. | No upstream Dart binding; model quality/coverage must be measured. | **Keep as comparator.** Credible mature mobile/offline/streaming family, but integration evidence is weaker for Flutter. |
| WebRTC VAD + selected STT | Fixed short PCM VAD frames drive a separate engine. | Native binding plus binary endpoint/no probability behavior. | **Keep as low-cost VAD benchmark**, not the default without measured false cuts and UX results. |
| Native Apple/Android recognizers | Delegate recognition to platform-owned service. | Device, OS, locale and service availability variability. | **Rejected as foundation.** Cannot establish deterministic cross-platform strict offline behavior from the supplied APIs. |

## Benchmark gates before a selection

All following targets are proposals and have no measured value yet.

| Gate | Required evidence | Status |
|---|---|---|
| Offline proof | Fresh install with models provisioned, then airplane-mode transcription and process/network observation on at least one supported Android and iOS device. | [UNVERIFIED] |
| Latency | Per-device p50/p95 for capture-to-first-partial, end-of-speech-to-final, and cancellation; include input durations and thermal state. | [UNVERIFIED] |
| Resource use | Release-build APK/IPA incremental size, model download size, peak RSS, CPU, battery/thermal observations. | [UNVERIFIED] |
| Recognition quality | Frozen, consented/reproducible multilingual noisy/clean corpus; WER/CER plus command success and VAD clipped-speech rate. | [UNVERIFIED] |
| UX correctness | Interrupted speech, long silence, speech during playback, route change, permission denial, model absent/corrupt, cancellation and lifecycle tests. | [UNVERIFIED] |
| Supply chain | Engine and every model/tokenizer license, source URL, version/hash, redistribution terms, offline integrity check, upgrade/rollback behavior. | [UNVERIFIED] |

## Constraints discovered

- A strict-offline product must bundle or deliberately provision its own VAD/STT assets; generic Android speech recognition is explicitly likely to stream audio remotely.
- “Engine supports Android/iOS” does not prove a Flutter bridge, all target ABIs, release packaging, offline model installation, or language availability.
- Engine license is not model license. sherpa-onnx, whisper.cpp and Vosk runtime licenses do not settle rights for a chosen pretrained model, tokenizer, or any audio corpus used for evaluation.
- Upstream performance figures are not substitutes for benchmark evidence on supported device classes and release builds.

## Unresolved

- [UNRESOLVED: Which product languages, accents, domain vocabulary, punctuation and translation behavior are required?]
- [UNRESOLVED: Which Android API levels/ABIs and iPhone/iPad generations form the supported-device performance floor?]
- [UNRESOLVED: Are partial hypotheses required, and what stability/latency threshold is acceptable?]
- [UNRESOLVED: What maximum first-install and downloadable model size is acceptable, and is Wi-Fi-only provisioning required?]
- [UNRESOLVED: Which precise pretrained models have redistribution-compatible licenses and acceptable evaluation quality?]
- [UNRESOLVED: What microphone capture plugin/native layer can reliably deliver the proposed PCM transport across route, interruption and background transitions?]

## Supplement: newer native, VAD, and ASR candidates

This supplement broadens the representative catalog only; it does not claim an exhaustive inventory and does not revise the shortlist above.

### Apple SpeechAnalyzer and SpeechTranscriber

Apple’s newer `SpeechAnalyzer` is an actor that accepts an application-provided asynchronous input sequence and emits module output through asynchronous sequences. Apple documents `SpeechTranscriber` as the module used for speech-to-text, and requires the relevant assets to be installed or present through `AssetInventory`. That asset step makes it a materially different integration model from the older `SFSpeechRecognizer` request API, including its `requiresOnDeviceRecognition` flag.

The newer API is therefore an **Apple-native optional candidate** for streamed microphone input and locally present assets, not a portable Flutter engine. The consulted API material does not establish the exact OS-version floor, device matrix, locale coverage, asset-size behavior, all-offline guarantee, or distribution/provisioning control needed for the product; each is [UNVERIFIED]. It still cannot replace a bundled Android route for strict cross-platform offline behavior.

### TEN VAD versus Silero and WebRTC VAD

TEN VAD describes itself as a real-time, frame-level streaming VAD. Its upstream prebuilt-library table lists Android arm64-v8a/armeabi-v7a C/Java support and iOS arm64 C-framework support, with explicit limits of no iOS simulator and no iPad. This permits a project-owned Flutter FFI bridge on phone targets but is not direct Dart/Flutter support. Its repository claims better precision/lower complexity than Silero and comparison material against WebRTC/Silero; treat those as supplier claims until reproduced against the project corpus and target hardware.

TEN VAD uses Apache-2.0 **with additional conditions**, and its `pitch_est.cc` notice includes BSD-2-Clause/BSD-3-Clause-derived material. A legal review must read the exact root `LICENSE` and `NOTICES` before shipment. By contrast, the canonical WebRTC source identifies its VAD code as BSD-style and the root source tree as BSD-3-Clause, with a separate patent grant. Neither license fact establishes an approved Flutter package or device performance.

| Candidate | Directly evidenced mobile surface | Decision-relevant constraint |
|---|---|---|
| TEN VAD | Android native library for arm64-v8a/armeabi-v7a; iOS arm64 framework, phone-only per upstream table. | FFI ownership; no upstream Dart API; license has additional conditions; target-device quality/latency/RAM [UNVERIFIED]. |
| Silero VAD | ONNX/mobile evidence and sherpa-onnx Flutter examples. | Better direct Flutter runtime evidence; compare its endpoint quality against TEN under identical thresholds/corpus. |
| WebRTC VAD | Canonical C/C++ source, BSD-3-Clause, fixed PCM frame contract documented above. | Lightweight binary decision path; Flutter bridge and target behavior [UNVERIFIED]. |

### Moonshine and newer sherpa-onnx model families

Moonshine Voice’s upstream project now describes on-device, live-streaming-oriented transcription, Android and iOS examples, and model languages including English, Spanish, Mandarin, Japanese, Korean, Vietnamese, Ukrainian, and Arabic. Its Android package is Maven-distributed and iOS package is Swift Package Manager-distributed; no upstream Flutter package is evidenced. Current licensing distinguishes model generation rather than language alone: code and all streaming STT models are MIT by default across languages and sizes; only an exhaustive named set of legacy non-streaming non-English models uses the Moonshine Community License. Select a precise model/version and verify its license before distribution.

Within sherpa-onnx, SenseVoice is directly documented as a **non-streaming** model family with Dart/Flutter support on Android and iOS and languages Mandarin, Cantonese, English, Japanese and Korean. FunASR Nano is documented as Chinese, English and Japanese and has a real-time Android APK reference; the consulted source does not establish that its Flutter model path supplies an online decoder or stable partial hypotheses, so classify it as a non-streaming/VAD-segmented candidate until verified. sherpa-onnx’s Android examples list Whisper, Moonshine, SenseVoice, and NVIDIA Parakeet TDT among models usable for “real-time speech recognition,” but that page does not by itself prove an online transducer interface, partial-result semantics, or Flutter/iOS availability for each model. Parakeet must therefore remain a model-specific benchmark candidate, not a streaming promise.

| Family | Evidence-backed scope | Streaming/mobile constraint |
|---|---|---|
| Moonshine Voice | On-device live-streaming product claim; Android/iOS native package paths; multiple languages listed. | Flutter requires a project bridge; all streaming STT models are MIT, while named legacy non-streaming non-English models are Community-licensed; target metrics and exact model/ABI footprint [UNVERIFIED]. |
| SenseVoice through sherpa-onnx | Android/iOS plus Dart/Flutter; Mandarin/Cantonese/English/Japanese/Korean. | Documented non-streaming; use VAD-delimited final-text evaluation rather than assuming partials. |
| FunASR Nano through sherpa-onnx | Chinese/English/Japanese model and Android real-time APK reference. | Do not infer a Flutter online-decoder contract from the APK; iOS/partial-result/package evidence [UNVERIFIED]. |
| NVIDIA Parakeet through sherpa-onnx | Listed in sherpa Android “real-time” example catalog. | Exact Parakeet variant, license, Android/iOS Flutter path, online-vs-batch API, and metrics [UNVERIFIED]. |

### Supplement sources

- [Apple SpeechAnalyzer reference](https://developer.apple.com/documentation/speech/speechanalyzer), consulted 2026-09-19.
- [TEN VAD README and prebuilt-platform table](https://github.com/TEN-framework/ten-vad/blob/main/README.md), consulted 2026-09-19.
- [WebRTC canonical VAD source header](https://webrtc.googlesource.com/src/+/refs/heads/main/common_audio/vad/vad_core.h), consulted 2026-09-19.
- [WebRTC root license](https://webrtc.googlesource.com/src/+/c421db9dbe3194542c14f5bcdf72eb6063184790/LICENSE), consulted 2026-09-19.
- [WebRTC license and patent FAQ](https://webrtc.googlesource.com/src/+/f2431a97d57a48510db9827a672d8835ef3fa537/docs/faq.md), consulted 2026-09-19.
- [Moonshine Voice README](https://github.com/moonshine-ai/moonshine), consulted 2026-09-19.
- [Moonshine license](https://github.com/moonshine-ai/moonshine/blob/main/LICENSE), consulted 2026-09-19.
- [sherpa-onnx SenseVoice documentation](https://github.com/k2-fsa/sherpa/blob/master/docs/source/onnx/sense-voice/index.rst), consulted 2026-09-19.
- [sherpa-onnx FunASR Nano model documentation](https://k2-fsa.github.io/sherpa/onnx/funasr-nano/pretrained.html), consulted 2026-09-19.
- [sherpa-onnx Android model example catalog](https://k2-fsa.github.io/sherpa/onnx/android/prebuilt-apk.html), consulted 2026-09-19.

### Moonshine license correction evidence

On 2026-09-19, the current [Moonshine README](https://github.com/moonshine-ai/moonshine) states that models are MIT by default across languages and sizes, with only legacy non-streaming non-English exceptions. The current [root LICENSE](https://github.com/moonshine-ai/moonshine/blob/main/LICENSE) specifies that this includes “all streaming speech-to-text models” and enumerates the only non-MIT legacy models. The prior supplement’s broader non-English license statement was corrected in place.

## Sources

- [Silero VAD README](https://github.com/snakers4/silero-vad/blob/master/README.md), consulted 2026-09-19.
- [Silero VAD FAQ](https://github.com/snakers4/silero-vad/wiki/FAQ), consulted 2026-09-19.
- [Silero VAD ONNX wrapper contract](https://github.com/snakers4/silero-vad/blob/master/src/silero_vad/utils_vad.py), consulted 2026-09-19.
- [Silero VAD license metadata](https://github.com/snakers4/silero-vad/blob/master/pyproject.toml), consulted 2026-09-19.
- [WebRTC VAD wrapper audio-frame contract](https://github.com/wiseman/py-webrtcvad/blob/master/README.rst), consulted 2026-09-19.
- [sherpa-onnx local-inference and platform documentation](https://github.com/k2-fsa/sherpa/blob/master/docs/source/onnx/index.rst), consulted 2026-09-19.
- [sherpa-onnx Flutter streaming example](https://github.com/k2-fsa/sherpa-onnx/blob/master/flutter-examples/streaming_asr/README.md), consulted 2026-09-19.
- [sherpa-onnx Flutter/Dart examples](https://github.com/k2-fsa/sherpa-onnx/blob/master/flutter/sherpa_onnx/example/example.md), consulted 2026-09-19.
- [sherpa-onnx Apache-2.0 license](https://github.com/k2-fsa/sherpa-onnx/blob/master/LICENSE), consulted 2026-09-19.
- [whisper.cpp README and model memory table](https://github.com/ggml-org/whisper.cpp/blob/master/README.md), consulted 2026-09-19.
- [whisper.cpp model list and language notes](https://github.com/ggml-org/whisper.cpp/blob/master/models/README.md), consulted 2026-09-19.
- [whisper.cpp MIT license](https://github.com/ggml-org/whisper.cpp/blob/master/LICENSE), consulted 2026-09-19.
- [Vosk API README](https://github.com/alphacep/vosk-api), consulted 2026-09-19.
- [Vosk Apache-2.0 license](https://github.com/alphacep/vosk-api/blob/master/COPYING), consulted 2026-09-19.
- [Android SpeechRecognizer reference](https://developer.android.com/reference/android/speech/SpeechRecognizer), consulted 2026-09-19.
- [Apple `requiresOnDeviceRecognition` reference](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition), consulted 2026-09-19.
