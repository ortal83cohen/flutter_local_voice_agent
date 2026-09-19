# Research: Local intelligence runtime and text-to-speech

## Dated scope

Research date: 2026-09-19. This stream compares local-inference choices for a Flutter voice agent whose priorities are Android and iOS, with desktop optional. The stated boundary is strict offline inference after assets have been provisioned locally. “Open source” below describes runtime source licensing only; it does not imply that a model's weights, training data, redistribution, or commercial use are licensed.

## Answer

Keep deterministic dialogue/state logic as a first-class no-model baseline. If a local generative model is required, shortlist `llama.cpp` and MediaPipe/LiteRT first for a narrow, evaluated model set; retain MLC LLM, ExecuTorch, and ONNX Runtime as conditional alternatives where their export and hardware paths are proven on target devices. For custom offline neural TTS, sherpa-onnx is the broadest cross-platform candidate; system TTS is only a conditional option because an installed voice and its offline availability are device-controlled.

## Runtime comparison

| Option | Verified platform/distribution evidence | License and model boundary | Assessment for this scope |
|---|---|---|---|
| Deterministic logic | Application code can run without an inference runtime or model. | The project owns its code; no third-party model license is introduced. | Baseline for commands, safety gates, state transitions, templates, and error recovery. It has no generative capability. |
| llama.cpp | The project publishes iOS XCFramework and Android arm64 CPU release assets; its source supports model loading through GGUF. [llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases) | Runtime is [MIT](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE). GGUF model weights carry their own licences. | Strong conditional shortlist for C/C++ Flutter bridging and quantized GGUF models. Confirm exact Android acceleration and packaging in a device spike; the cited release evidence only establishes Android CPU binaries and an iOS XCFramework. |
| LiteRT / MediaPipe LLM Inference | Google's documentation says MediaPipe LLM Inference is available on Android and iOS for on-device Gemma text generation. [Google mobile deployment](https://ai.google.dev/gemma/docs/integrations/mobile) | MediaPipe source is [Apache-2.0](https://github.com/google-ai-edge/mediapipe/blob/master/setup.py). Gemma and other model terms are separate and may require acceptance. | Strong conditional shortlist when the selected model has a supported `.task` conversion/distribution path. It couples the solution to the supported model/task-bundle surface. |
| MLC LLM | Official documentation compiles model libraries separately for Android and iPhone; the project lists Metal on iOS and OpenCL on Android. [MLC compilation](https://llm.mlc.ai/docs/compilation/compile_models.html), [MLC README](https://github.com/mlc-ai/mlc-llm) | Runtime/compiler is Apache-2.0; each input model remains separately licensed. | Candidate where per-model compilation and a GPU-specific artifact pipeline are acceptable. Its compilation and device-specific library step add operational complexity. |
| ONNX Runtime / ONNX Runtime GenAI | ONNX Runtime Mobile documents Android Java/C/C++ and iOS C/C++/Objective-C packages, plus Android NNAPI and iOS CoreML/XNNPACK execution providers. [ORT mobile](https://onnxruntime.ai/docs/tutorials/mobile/) | Runtime is MIT; ONNX and GenAI model assets require independent licence review. | Good general inference runtime, especially for non-generative models. Treat GenAI mobile packaging as a spike, not a presumed choice: current official mobile documentation is for ONNX Runtime generally, while a recent Android GenAI report documents a packaging failure in a MAUI combination. [reported issue](https://github.com/microsoft/onnxruntime-genai/issues/2243) |
| ExecuTorch | Official documentation supports Android and iOS LLM deployment through C++ plus Java/Swift bindings, with Core ML, MPS, XNNPACK and Qualcomm paths. Its Android LLM Java API is explicitly experimental. [LLM guide](https://docs.pytorch.org/executorch/stable/llm/getting-started.html), [Android API](https://docs.pytorch.org/executorch/stable/llm/run-on-android.html) | ExecuTorch source is BSD-3-Clause; exported model and tokenizer terms remain separate. | Credible custom-PyTorch/export alternative. Do not select before export reproducibility and the experimental Android LLM surface are validated. |
| Apple native | Apple provides Core ML for model inference and `AVSpeechSynthesizer` for system speech synthesis on Apple platforms. [AVSpeechSynthesizer buffer API](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write%28_%3Atobuffercallback%3A%29) | Apple frameworks are platform SDK terms, not open-source runtimes. Model and voice availability are governed separately. | iOS-specific optimization path, not a cross-platform intelligence runtime. |

No source in this research establishes a Flutter plugin that covers any listed intelligence runtime end-to-end. Each choice therefore needs a native bridge and a device integration proof.

## TTS comparison

| Option | Verified evidence | Engine versus model licence | Assessment |
|---|---|---|---|
| sherpa-onnx TTS families | sherpa-onnx documents local TTS, Android/iOS/desktop support, and Dart/Swift/Java/Kotlin/C++ APIs. Its documentation names VITS and Piper-compatible examples. [README](https://github.com/k2-fsa/sherpa-onnx), [TTS index](https://k2-fsa.github.io/sherpa/onnx/index.html) | Engine is Apache-2.0. Every selected voice/model needs its own explicit licence; the project itself advises model-specific review in current licence discussions. [licence issue](https://github.com/k2-fsa/sherpa-onnx/issues/3760) | Primary custom-TTS shortlist. Select a voice only after verifying language, quality, file size, sample rate, and redistribution rights from that voice's own model card/archive. |
| Piper, current project | The original `rhasspy/piper` repository is archived. The active OHF rewrite is `piper1-gpl`, describes itself as local and embeds espeak-ng; its stated licence is GPL-3.0. [archived upstream](https://github.com/rhasspy/piper/releases), [OHF Piper](https://github.com/OHF-Voice/piper1-gpl), [maintainer explanation](https://github.com/OHF-Voice/piper1-gpl/discussions/53) | Current engine is GPL-3.0; voice files have separate terms. | Reject as a default embedded mobile engine until GPL obligations and every voice licence are reviewed. Do not rely on old MIT claims for the current rewrite. |
| Kokoro | The published Kokoro-82M repository labels the weights Apache-2.0 and lists a 363 MB repository / 327 MB `kokoro-v1_0.pth` file at the cited revision. [model repository](https://huggingface.co/hexgrad/Kokoro-82M/tree/ea4fcc6f4ccf6cdea832cafa5083cf4d40ea66db) | Repository/model card says Apache-2.0; any mobile inference wrapper and constituent assets must be reviewed separately. | Viable quality-oriented candidate, but the cited source shows a large source-weight artifact and not a ready Android+iOS Flutter deployment. Require a mobile conversion/package and device-memory proof. |
| Native OS TTS | Apple's API can generate audio buffers for an utterance. [Apple documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write%28_%3Atobuffercallback%3A%29) | Proprietary OS service; installed voices, languages, quality and download state are not app-controlled. | Candidate only with preflight that confirms the requested local voice is installed and speaks with network disabled. It cannot supply a cross-device offline guarantee on its own. |
| Other viable engines | ExecuTorch documents TTS among supported model types on Android/iOS, but this establishes runtime category support rather than a selected deployable voice. [ExecuTorch overview](https://docs.pytorch.org/executorch/stable/) | Engine and model licences remain separate. | Conditional only for a PyTorch-native voice with a reproducible mobile export; no candidate voice is selected by this stream. |

## Streaming distinction and audio contract proposal

“Token streaming” means the intelligence runtime emits text tokens. It does not demonstrate that the TTS engine has begun waveform production. “Sentence streaming” means an application waits for punctuation or a segmentation policy, then submits complete text segments to TTS; it can reduce time to first spoken segment but adds segmentation latency. “True incremental acoustic output” means the synthesizer returns or plays audio buffers while it is still producing an utterance. Apple documents buffer callbacks for a single utterance, but this is not evidence that it accepts partial text for that utterance. [Apple buffer API](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write%28_%3Atobuffercallback%3A%29) The cited sherpa-onnx material establishes local TTS, not true incremental acoustic output for a selected voice; mark that capability [UNVERIFIED] until an engine/voice experiment proves it.

Proposed testable bridge contract, not an engine claim: use mono PCM float32 at 16,000 Hz for microphone/ASR ingress; require each TTS adapter to declare its native output rate; resample its mono float32 output once at the platform boundary to the active playback rate. No cited source here establishes a universal TTS sample rate or the best playback rate, so the output-rate choice remains [UNVERIFIED] until selected voices are inspected.

## Distribution, footprint and RAM

All strict-offline options require model/voice/tokenizer assets to be included in the application package or downloaded and integrity-checked before entering offline mode. This is an operational requirement, not evidence that a framework performs provisioning. MLC explicitly distinguishes compiled model library from converted weights and supports bundling weights. [MLC compilation](https://llm.mlc.ai/docs/compilation/compile_models.html) ExecuTorch requires a serialized `.pte` model and tokenizer paths. [ExecuTorch guide](https://docs.pytorch.org/executorch/stable/llm/getting-started.html)

Quantified evidence found: Kokoro's cited revision reports 363 MB repository size and a 327 MB PyTorch weight file. No trustworthy cross-runtime RAM figure, installed app size, quantized model footprint, token-per-second number, or battery number was found in the sources above; all are [UNVERIFIED] and must be measured on representative devices after model selection. Runtime source licences do not grant model redistribution rights.

## Recommended conditional shortlist

1. Begin with deterministic orchestration plus offline ASR/VAD/TTS wiring; add a local LLM only when evaluated conversation requirements exceed deterministic capabilities.
2. For the first LLM spike, compare llama.cpp with one small GGUF model against MediaPipe/LiteRT with one properly licensed supported task model on the same Android and iOS devices. Measure startup, first-token, cancellation, RAM, thermal behavior, package size, and offline-with-network-disabled behavior.
3. For custom TTS, spike sherpa-onnx with one explicitly licensed voice per target language; prove sentence-segment playback first. Promote to true incremental acoustic output only if the selected engine and voice prove it.
4. Keep MLC LLM, ExecuTorch, and ONNX Runtime as alternatives when the chosen model/export or target hardware specifically benefits from them. Use native OS TTS only behind an offline-voice preflight and a fallback policy.

## Rejected alternatives for the initial default

- Cloud LLM/TTS APIs: violate strict offline inference.
- Piper1-GPL: not a default because the current maintained rewrite is GPL-3.0 and voice terms are independent.
- Treating platform-native TTS as an unconditional offline provider: unsupported because voice installation/availability is outside the app's control.
- Choosing a runtime solely because its source is open source: rejected because model weights and distribution rights remain independent.

## Unresolved

- [UNRESOLVED: Which languages, voices, voice licences, quality floor, and accessibility requirements are required?]
- [UNRESOLVED: Which Android API/device classes and iOS deployment target define the performance and acceleration floor?]
- [UNRESOLVED: What model family, context length, response-quality target, and commercial redistribution terms are acceptable?]
- [UNRESOLVED: Which selected TTS engine/voice can accept partial text and emit audio before a complete utterance?]
- [UNRESOLVED: What measured package, persistent-storage, peak-RAM, latency, thermal and battery budgets will govern acceptance?]
- [UNRESOLVED: Whether Flutter FFI/platform-channel maintenance is acceptable for each native runtime, and whether desktop must use the same engine.] 

## Sources

All links were consulted on 2026-09-19. Primary sources are official project repositories, vendor documentation, or the named model publisher. Issue links are used only to identify an unresolved support/licence risk, never as proof of a successful capability.

## Supplementary update: current runtime and TTS dependency gaps

Sources in this supplementary section were also consulted on 2026-09-19. It adds evidence and limits; it does not select an engine.

### Apple Foundation Models, Core ML, and MLX are different choices

| Technology | What official evidence establishes | Offline and availability limit |
|---|---|---|
| Foundation Models framework | Apple describes a native Swift API for Apple Foundation Models, with on-device and Private Cloud Compute options. Its on-device system model is documented as offline-capable. [Framework overview](https://developer.apple.com/documentation/FoundationModels/), [PCC comparison](https://developer.apple.com/documentation/FoundationModels/adding-server-side-intelligence-with-private-cloud-compute/) | It is iOS-family-specific, requires an Apple-Intelligence-capable device, and requires Apple Intelligence to be enabled. Apple documents device and region availability checks. [Availability tutorial](https://developer.apple.com/tutorials/develop-in-swift/generate-structured-content), [PCC availability](https://developer.apple.com/documentation/FoundationModels/adding-server-side-intelligence-with-private-cloud-compute/) It cannot be the sole Android solution. PCC is explicitly network-dependent and therefore outside strict offline inference. |
| Core ML | Apple presents Core ML as the framework for integrating a developer-selected trained model into an app. [Core ML overview](https://developer.apple.com/documentation/coreml) | It is an iOS/macOS runtime for app-provisioned models; it is not an entitlement-gated Apple system LLM. Model conversion, licence, package footprint, and iOS bridge remain separate work. |
| MLX | MLX is an Apple open-source array/ML framework for Apple silicon. Apple's MLX Swift examples include LLM evaluation and a chat application that run on both iOS and macOS. [MLX repository](https://github.com/ml-explore/mlx), [MLX Swift examples](https://github.com/ml-explore/mlx-swift-examples) | This is a credible Apple-only deployment path, distinct from Foundation Models and not a cross-platform runtime. The cited project does not establish Android support; retain an Android-specific runtime for this product. |

### LiteRT-LM supersedes the earlier MediaPipe LLM path

Google now labels MediaPipe LLM Inference for Android, iOS, and Web “maintenance-only” and recommends migration to LiteRT-LM. [MediaPipe LLM update](https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference) LiteRT-LM is Google's current production-oriented orchestration layer; its overview documents Android, iOS, Web and desktop targets and a Flutter route through the community-maintained `flutter_gemma` package. [LiteRT-LM overview](https://developers.google.com/edge/litert-lm) The Android guide documents a Kotlin API, Gradle artifact, `.litertlm` model path, explicit GPU/NPU setup, and asynchronous response streaming. [LiteRT-LM Android](https://developers.google.com/edge/litert-lm/android)

This changes the earlier shortlist wording: MediaPipe LLM Inference remains evidence of a legacy supported path but is not the current default for a new integration. LiteRT-LM has current Android/iOS claims; the Flutter package is community-maintained, so its API, release cadence, offline provisioning, and iOS behavior must be verified in a spike rather than attributed to Google as a first-party Flutter SDK.

### Sherpa-onnx TTS: Kokoro and phonemizer dependency boundary

Current sherpa-onnx examples configure Kokoro with an ONNX model, voices, tokens, and `espeak-ng-data`; the repository also contains a Kokoro C++ example. [Kokoro example](https://github.com/k2-fsa/sherpa-onnx/blob/master/cxx-api-examples/kokoro-tts-en-cxx-api.cc), [Python configuration](https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/offline-tts.py) This establishes current Kokoro support in the engine.

The Android JNI implementation exposes `generateWithCallback` and passes float sample chunks to the callback while invoking `OfflineTts::Generate`; the project also supplies an ALSA player described as playing while generation occurs. [Android JNI callback](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/jni/offline-tts.cc), [play-while-generating example](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/csrc/sherpa-onnx-offline-tts-play-alsa.cc) This is evidence of incremental generated-audio callbacks for a complete `Generate(text, ...)` request. It is not evidence that the engine accepts token-by-token partial text, preserves a single acoustic utterance across independently submitted text segments, or offers the callback on every Flutter/platform binding.

The sherpa-onnx wrapper/repository being Apache-2.0 does not settle the licence of everything shipped with a TTS model. Its VITS/Kokoro configuration explicitly references `espeak-ng-data`, and the current eSpeak NG project is GPL-3.0. [sherpa-onnx configuration](https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/offline-tts.py), [eSpeak NG project](https://github.com/espeak-ng/espeak-ng) The cited configuration proves a dependency on eSpeak data, but does not by itself prove the exact source, licence file, modification status, linkage, or distribution method of a particular sherpa model archive. Before shipping, inventory each selected archive and native library, retain its notices, and obtain legal review of the specific eSpeak/data integration; do not infer that the Apache engine licence alone permits that bundle.

### Additional local TTS families

| Family | Source-backed capability | Mobile practicality / licence limit |
|---|---|---|
| eSpeak NG | The project describes an open-source synthesizer supporting more than 100 languages and accents; its repository reports GPL-3.0. [eSpeak NG](https://github.com/espeak-ng) | Small traditional synthesizer candidate where synthetic voice quality is acceptable. GPL-3.0 requires a distribution/legal review before embedding; no Flutter Android+iOS bridge is established here. |
| Flite | CMU Flite describes itself as a “small fast portable speech synthesis system” and documents generated 8 kHz WAV output in its own README. [Flite repository](https://github.com/festvox/flite) | Useful low-footprint baseline to evaluate for simple speech, but its included voice quality is explicitly described by the project as an old 8 kHz diphone voice. The exact engine and voice licence must be read from the selected release's `COPYING` and voice assets before shipping; this report does not treat it as a neural-quality candidate. |
| MeloTTS | The official MyShell repository describes multilingual TTS, CPU real-time inference, and an MIT-licensed library. [MeloTTS README](https://github.com/myshell-ai/MeloTTS/blob/main/README.md), [official licence](https://github.com/myshell-ai/MeloTTS/blob/main/LICENSE) | No official Android/iOS runtime, native package, or Flutter distribution evidence was found in this pass. Treat mobile deployment, model terms, and footprint as [UNVERIFIED]. |
| OpenVoice | The repository describes voice cloning and states V1/V2 are MIT licensed. [OpenVoice repository](https://github.com/myshell-ai/OpenVoice) | The official project advises regular users toward its hosted service when encountering local platform installation problems. [maintainer response](https://github.com/myshell-ai/OpenVoice/issues/116) No supported mobile-native package was found here; voice-cloning safety, consent, model assets, and mobile packaging require separate scope and review. |
| Coqui XTTS | XTTS documentation says the model is under the Coqui Public Model License, and a maintainer states that model terms are distinct from code terms and do not allow commercial use. [XTTS model documentation](https://github.com/coqui-ai/TTS/blob/dev/docs/source/models/xtts.md), [maintainer licence statement](https://github.com/idiap/coqui-ai-TTS/discussions/216) | Reject for a commercial default absent an appropriate model right. No mobile-native package evidence was found in this pass. |

## Supplementary unresolved

- [UNRESOLVED: For each shortlisted sherpa TTS archive, what exact eSpeak data/binary files and licences are present, and what distribution obligations apply?]
- [UNRESOLVED: Does the selected sherpa Flutter/native binding expose generated-audio callbacks with cancellation on both Android and iOS?]
- [UNRESOLVED: Which devices, OS versions, regions, and Apple Intelligence enabled states must be supported before Foundation Models can be offered as an optional iOS acceleration?]
- [UNRESOLVED: Does the community-maintained LiteRT-LM Flutter route meet the selected model, provisioning, and lifecycle requirements on both mobile platforms?]

## Supplementary correction: MLX iOS evidence and official MeloTTS source

Apple's `ml-explore/mlx-swift-examples` repository is primary evidence that MLX Swift can run local language models on iOS: `LLMEval` downloads an LLM and tokenizer and generates text on iOS/macOS, while `MLXChatExample` is an iOS/macOS LLM/VLM chat app. [MLX Swift examples](https://github.com/ml-explore/mlx-swift-examples) MLX is therefore a credible optional Apple-only local-runtime path, rather than an unverified mobile possibility. It remains unsuitable as the single runtime for an Android+iOS product because this Apple-maintained source establishes iOS/macOS examples only, not Android support. It is still separate from both Core ML and the Apple-managed Foundation Models framework.

The MeloTTS licence source is corrected to the official `myshell-ai/MeloTTS` repository. Its README declares the library MIT-licensed for commercial and non-commercial use, and its `LICENSE` is the MIT text. [official README](https://github.com/myshell-ai/MeloTTS/blob/main/README.md), [official licence](https://github.com/myshell-ai/MeloTTS/blob/main/LICENSE) This covers the repository code as published; selected pretrained-model assets and an Android/iOS deployment route still require separate verification.
