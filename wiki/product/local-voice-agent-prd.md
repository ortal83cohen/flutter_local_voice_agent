---
id: local-voice-agent-prd
title: Flutter Local Voice Agent - Technical PRD and Implementation Architecture
status: draft
owner: unassigned
last_verified: 2026-09-21
applies_to: ["lib/**", "example/**", "android/**", "ios/**"]
summary: Researched, proposed architecture and implementation roadmap for a strictly offline Flutter voice agent.
---

# Flutter Local Voice Agent: Technical PRD and Implementation Architecture

**Status: proposed specification, not an implemented SDK.** Research date: 19 September 2026. This document originally named Android and iOS as the primary targets. Current plugin registration also includes macOS, Windows and Linux; see [reasonable platform coverage](reasonable-platform-coverage.md). All API declarations, numerical budgets and project layouts below are proposals. Target-device performance, runtime behavior and compatibility remain **[UNVERIFIED]** until the specified experiments pass. Parent 0002 VITS allocation, physical mobile qualification and clean consumer-install gates remain OPEN.

At the original research date, this specification described a generic skeleton. The current native implementation and remaining qualification gates are tracked in [work item 0002](../work/0002-native-offline-pipeline/STATE.yaml); the [public facade](../../lib/flutter_local_voice_agent.dart) now exists. The declarations below remain specification proposals unless verified against current source.

## Planned setup policy amendment

The [managed model setup proposal](managed-model-setup.md) records a later,
unimplemented direction: library-owned explicit model preparation, one
recommended speech bundle and a simplified example. It proposes narrowing the
network prohibition below to local creation and inference while allowing an
explicit preparation path. This original specification and its acceptance
records remain historical; the amendment does not claim runtime delivery.

## Product decision and scope

Build an offline conversation coordinator with replaceable speech and intelligence adapters, rather than binding the entire public API to one model family. The initial engineering choice is **Silero VAD + a sherpa-onnx streaming ASR model + deterministic local logic + a sherpa-onnx TTS adapter**, connected by native audio buffers. Offer **llama.cpp as an optional local LLM adapter**. The TTS voice and all model versions remain subject to language evaluation, distribution rights and device qualification; there is no approved redistributable model pack yet.

This is the best-supported initial integration path in the delegated evidence, not a demonstrated latency or accuracy winner. The native audio path uses Android AudioRecord/AudioTrack communication audio first and iOS voice-processing AVAudioEngine first. Oboe is an Android optimization candidate after AEC and route behavior are proven. Public API consumers receive transcripts, state, replies and errors, not a mandatory stream of microphone byte arrays.

The principal user is a Flutter developer building private voice commands or short local conversations. The principal journey is: provide local model assets, start an explicitly authorized microphone session, speak, receive a local response, interrupt or stop, then release resources. Deterministic tasks must work without an LLM. The initial profile is foreground-only; background continuation is a separate opt-in capability. Wake-word detection, arbitrary agent tools, voice cloning and web support are outside the first release.

### Offline contract

- The SDK must make no network request for initialization, inference, fallback, telemetry or error recovery. No API key, server or hosted entitlement is required for the bundled-engine profile.
- A first installation must work without a network when the host application bundles its model pack or the user imports a complete local pack. Bundled assets are extracted locally when a native runtime requires real paths.
- An absent, corrupt, incompatible or unlicensed/unapproved pack fails preflight with a typed error before opening the microphone. There is no automatic download or cloud fallback.
- A host application may offer a separate explicit download workflow, but this is outside the SDK's strict offline path and outside the reference acceptance test. Audit host networking separately.
- Native OS services are optional adapters; they cannot satisfy the default app-controlled asset contract merely because a vendor calls them on-device.
- Audio, transcripts, prompts and history stay in memory by default. Local aggregate performance statistics exclude content. Persistence requires explicit host policy; deleting a Dart string is not a guarantee of secure physical memory erasure.

### Assumptions and release decisions

Use one English model pack as the proposed first qualification profile. This is a planning assumption, not a requirement that other languages are unsupported. Hebrew is not presumed from the language of this request. Before implementation freezes, choose product languages, minimum devices and accuracy thresholds. Candidate deployment floors are Android API 26/arm64 and iOS 16/arm64, **[UNVERIFIED]** against the eventual pinned backends. Raise floors or exclude adapters if the integration spike requires it. Native Apple AI adapters may have substantially higher availability requirements.

The research was delegated to two GPT-5.6 Terra researchers for engine breadth and one GPT-6 Astra researcher for mobile concurrency/lifecycle. Independent GPT-6 Astra reviewers assessed the research and plan. See [research consolidation](../work/0001-local-voice-agent-architecture/00-research.md), [speech report](../work/0001-local-voice-agent-architecture/research/speech.md), [intelligence/TTS report](../work/0001-local-voice-agent-architecture/research/intelligence-tts.md), and [mobile report](../work/0001-local-voice-agent-architecture/research/mobile-systems.md). Their source registers, supplements and uncertainty statements are part of this specification's evidence trail.

# Chapter 1 — Open technology research and engine selection

## Comparison method

The research covers the major practical open-runtime and native families, including newer alternatives. It does not claim to enumerate every project in existence. A runtime, a model architecture, a particular weight archive and a Flutter binding are separate objects; qualifying one does not qualify the others.

| Dimension | Measurement or evidence required | Selection rule |
|---|---|---|
| Offline determinism | Cold install with locally present assets; network denied and observed | Hard gate; missing assets produce an error |
| Streaming semantics | Timestamp partial text, finalized text, first PCM and final PCM; inspect actual adapter API | Distinguish online ASR, repeated batch windows, text-token streaming and waveform callbacks |
| Latency | Cold/warm p50/p95, speech-end to first audible output, stage timing, cancellation tail | Compare identical device/corpus/route conditions; no desktop extrapolation |
| Quality | WER/CER, clipped phonemes, false endpoints, task success, intelligibility and human voice preference | Select per language/domain; do not infer from parameter count |
| Memory | Native/process peak and steady memory, model mappings, KV cache, audio queues | Reject unbounded growth and unsafe coexistence; weights-on-disk are not RAM |
| Distribution size | App binary delta per ABI, compressed delivery, installed assets, temporary extraction space | Report runtime and models separately |
| Mobile portability | Android/iOS release builds, physical devices, cancellation, lifecycle, routes | A server example or language binding is insufficient |
| License and supply chain | Runtime, weights, tokenizer, phonemizer, notices, transitive libraries, immutable versions/hashes | No pack ships without a complete bill of materials |
| Maintenance | Release/source provenance, CI targets, binding ownership, API churn | Pin versions; hide upstream types behind adapters |
| Sustained operation | CPU, battery, thermal state, throughput, dropouts during repeated turns | Evaluate over long sessions and record failures as well as successful timings |

No comparable target-phone benchmark exists in this work. Upstream examples of scale include whisper.cpp's documented `tiny` weights at 75 MiB with about 273 MB memory and `base` at 142 MiB/about 388 MB; these are upstream figures, not project measurements, and quantization/build/device choices change them. The cited Kokoro source checkpoint is approximately 327 MB, not an ONNX/mobile install or RSS measurement. [whisper.cpp table](https://github.com/ggml-org/whisper.cpp/blob/master/README.md), [pinned Kokoro source artifact](https://huggingface.co/hexgrad/Kokoro-82M/tree/ea4fcc6f4ccf6cdea832cafa5083cf4d40ea66db).

## VAD comparison

| Candidate | Capability and contract | Costs and limits | Decision |
|---|---|---|---|
| Silero | Neural VAD; documented 8/16 kHz path; ONNX wrapper uses 512 samples at 16 kHz and carries recurrent state | Requires model/runtime; thresholds and noisy/double-talk quality must be measured | **Initial choice through sherpa-onnx**: direct Flutter/mobile integration evidence and explicit framing |
| WebRTC VAD | Classical binary decision; PCM16 mono, 10/20/30 ms frames at supported rates | No probability in the cited wrapper; bridge and quality calibration required | Mandatory small classical comparator; potentially suitable low-resource profile |
| TEN VAD | Streaming frame-level detector; native Android/iOS artifacts listed upstream | Platform caveats and additional license conditions; no proven Dart path here | Quality/CPU challenger in spike, not automatic replacement |
| whisper.cpp VAD integration | VAD feature within a mobile-capable ASR project | Selected binding and segmentation contract require validation | Useful when whisper.cpp already ships; avoid adding a second runtime just for VAD |

Sources: [Silero](https://github.com/snakers4/silero-vad), [frame/state implementation](https://github.com/snakers4/silero-vad/blob/master/src/silero_vad/utils_vad.py), [WebRTC source](https://webrtc.googlesource.com/src/+/refs/heads/main/common_audio/vad/vad_core.h), [wrapper framing](https://github.com/wiseman/py-webrtcvad/blob/master/README.rst), [TEN VAD](https://github.com/TEN-framework/ten-vad), [TEN license](https://github.com/TEN-framework/ten-vad/blob/main/LICENSE). Silero's MIT, WebRTC's BSD terms and TEN's additional conditions still require exact-version asset review.

## STT comparison

| Candidate | Streaming and platform evidence | Principal tradeoff | Decision |
|---|---|---|---|
| sherpa-onnx online transducer/Zipformer profiles | Upstream Flutter real-time recognition example on Android/iOS; online decoder consumes frames and produces partials | Exact model controls language, size, accuracy and license | **Initial choice**, subject to frozen-model device qualification |
| whisper.cpp / Whisper | Offline Android/iOS, C/C++ API and quantization; window/chunk transcription | Repeated windows are not stable native online decoding; final latency and memory may dominate | First alternate for language/quality wins; expose `finalOnly` when appropriate |
| Vosk | Offline streaming API and mobile support; upstream advertises small models around 50 MB | No upstream Dart binding in consulted evidence; model-specific quality and packaging | Credible comparator, optional adapter if it wins a target domain |
| Moonshine Voice | Current native Android/iOS and streaming-oriented path | Project bridge needed; qualify exact model and partial semantics | Serious streaming challenger. Current streaming STT models are MIT across languages; named legacy non-streaming models have different terms |
| sherpa non-streaming families | Whisper/Moonshine variants, SenseVoice, FunASR Nano and Parakeet examples broaden model choice | A real-time demo does not establish an online decoder for every model or Flutter/iOS support for every variant | VAD-segmented alternatives; declare capabilities per model |
| Apple Speech APIs | Legacy `requiresOnDeviceRecognition`; newer SpeechAnalyzer/SpeechTranscriber with managed assets | Apple-only availability/locales/assets; exact support must be preflighted | Optional native adapter, not default cross-platform foundation |
| Android SpeechRecognizer | Dedicated on-device API with availability check; generic API may send audio remotely | Device/service/model dependent | Strictly optional on-device adapter; prohibit generic cloud-capable fallback |

Sources: [sherpa Flutter streaming](https://github.com/k2-fsa/sherpa-onnx/blob/master/flutter-examples/streaming_asr/README.md), [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [Vosk](https://github.com/alphacep/vosk-api), [Moonshine](https://github.com/moonshine-ai/moonshine), [Moonshine license](https://github.com/moonshine-ai/moonshine/blob/main/LICENSE), [SenseVoice](https://github.com/k2-fsa/sherpa/blob/master/docs/source/onnx/sense-voice/index.rst), [sherpa model catalog](https://k2-fsa.github.io/sherpa/onnx/android/prebuilt-apk.html), [Apple SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer), [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer).

## Local intelligence comparison

| Candidate | Evidence-backed fit | Tradeoff | Decision |
|---|---|---|---|
| Deterministic Dart rules/state | No model or inference runtime needed; product-owned logic | Cannot provide open-ended generation | **Default baseline**, especially commands, confirmations and recovery |
| llama.cpp | GGUF-oriented C/C++ runtime, Android/iOS build artifacts, MIT code | Project-owned adapter, model licensing, context/KV memory and device tuning | **First optional LLM adapter**, for a narrowly qualified small model |
| LiteRT-LM | Current Google Android/iOS runtime route; asynchronous response generation; community Flutter route | Supported model/export and device acceleration must be qualified | Primary alternative in LLM bake-off; do not start new work on maintenance-only MediaPipe LLM API |
| MLC LLM | Android/iPhone deployment and separately compiled model libraries | More model-specific compilation/distribution machinery | Choose when a demonstrated GPU benefit justifies build ownership |
| ExecuTorch | Mobile C++/Java/Swift model deployment and LLM paths | Export/backend complexity; cited Android LLM API marked experimental | Choose for a PyTorch-centered, tested model pipeline |
| ONNX Runtime / GenAI | ORT Mobile has Android/iOS packages and execution providers | General ORT support does not prove a specific GenAI mobile package | Strong shared-runtime candidate; GenAI requires its own spike |
| Core ML / MLX Swift | App-provisioned Apple inference; MLX Swift upstream includes iOS examples | Apple-only route, separate Android solution | Optional Apple optimization; not a unified default |
| Apple Foundation Models | System on-device model with availability checks | Supported Apple Intelligence hardware/settings/regions; cannot serve Android | Optional local system adapter; Private Cloud Compute excluded |

Sources: [llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases), [LiteRT-LM](https://developers.google.com/edge/litert-lm), [MediaPipe migration](https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference), [MLC compilation](https://llm.mlc.ai/docs/compilation/compile_models.html), [ExecuTorch LLM](https://docs.pytorch.org/executorch/stable/llm/getting-started.html), [ORT Mobile](https://onnxruntime.ai/docs/tutorials/mobile/), [Core ML](https://developer.apple.com/documentation/coreml), [MLX Swift examples](https://github.com/ml-explore/mlx-swift-examples), [Foundation Models](https://developer.apple.com/documentation/FoundationModels/).

LLM model selection remains an explicit Phase 0 output. Evaluate a small quantized model supported by the chosen runtime on the required languages and intents. Pin the model card, quantization method, tokenizer, prompt template, context size and license. Do not declare a generative model necessary just to answer a fixed command. Keep tool execution outside the model: any future actions require an allowlisted typed dispatcher and host policy; recognized or generated text is data, not executable authority.

## TTS comparison

| Candidate | Capability | Tradeoff and license boundary | Decision |
|---|---|---|---|
| sherpa-onnx TTS with a qualified VITS-family voice | Local mobile engine; multiple model families and generated-audio callback evidence | Per-voice quality/language; selected binding callback availability; transitive phonemizer/data terms | **Initial adapter choice**, conditional voice selection; sentence-segment path required |
| Kokoro through sherpa or another qualified runtime | Current sherpa Kokoro examples; source weights labeled Apache-2.0 | Source size is not phone size; voice/data/phonemizer dependencies remain separate | Quality-oriented candidate, compare against a smaller voice |
| Current Piper (`piper1-gpl`) | Local speech synthesis, eSpeak NG phonemization | Current engine GPL-3.0; model voices separately licensed | Not the default embedded profile without a distribution decision |
| Native Android/iOS TTS | OS voices; Apple can deliver synthesized audio buffers | Installed voices and offline behavior differ; not app-owned model inventory | Optional verified-local profile; fail if no local voice exists |
| Flite / eSpeak NG | Traditional compact synthesis candidates | Voice quality tradeoff; Flite release/voice terms separate, eSpeak GPL | Useful footprint/intelligibility baselines; do not imply neural quality |
| MeloTTS / OpenVoice / XTTS | Neural synthesis or cloning families | Mobile-native distribution not established in this research; XTTS model terms distinct from code; cloning outside scope | Do not place on critical mobile path without a new feasibility/licensing result |

Sources: [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx), [Kokoro example](https://github.com/k2-fsa/sherpa-onnx/blob/master/cxx-api-examples/kokoro-tts-en-cxx-api.cc), [TTS callback code](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/jni/offline-tts.cc), [Piper](https://github.com/OHF-Voice/piper1-gpl), [eSpeak NG](https://github.com/espeak-ng/espeak-ng), [Flite](https://github.com/festvox/flite), [MeloTTS](https://github.com/myshell-ai/MeloTTS), [OpenVoice](https://github.com/myshell-ai/OpenVoice), [XTTS model terms](https://github.com/coqui-ai/TTS/blob/dev/docs/source/models/xtts.md), [Apple buffer synthesis](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write%28_%3Atobuffercallback%3A%29).

**License gate:** sherpa's Apache-2.0 license does not make every shipped TTS bundle permissive. Some configurations require eSpeak data; inspect the actual native linkage, phonemizer implementation, archive contents, licenses and notices. No architecture decision here authorizes redistribution. If no acceptable pack passes, ship the adapter without weights and document locally supplied assets; do not silently substitute a network voice. This preserves an implementable SDK while keeping the bundled reference app's release gated.

## Flutter integration choice

Use a hybrid platform plugin and C ABI. Platform channels handle microphone permission, OS audio lifecycle, route changes and bounded state/control messages. A versioned C ABI hides C++ engine internals, reports capabilities and uses opaque handles, explicit sizes and matching destroy functions. Keep streaming PCM in native preallocated buffers, so moving every frame through Flutter codecs is unnecessary.

Dart owns developer-facing configuration, observable state and business logic. Native worker threads own inference scheduling and engine handles. A persistent worker isolate is appropriate for Dart-heavy logic or synchronous FFI work, but wrapping synchronous FFI in a Future does not move it off the UI isolate. Do not combine independently oversubscribed engine thread pools. A platform EventChannel should not be presumed to work as an unsolicited event listener in a background isolate. [Flutter FFI](https://docs.flutter.dev/platform-integration/legacy-ffi-plugin), [platform channels](https://docs.flutter.dev/platform-integration/platform-channels), [isolates](https://docs.flutter.dev/perf/isolates).

Prefer existing upstream sherpa bindings where their ownership and streaming APIs meet the contract. Extend a narrow native bridge for missing callback/cancellation behavior instead of forking the entire engine. Pin builds, expose capability discovery and test a shared ABI on Android and iOS. Whether build hooks, federated platform packages or a plugin wrapper best package the pinned runtime is a Phase 0 build result, not an assumption from a package name.

# Chapter 2 — Data flow and architecture

## End-to-end flow

```text
Flutter UI / host application
    | configuration, start/stop/interrupt                 ^ typed events
    v                                                     |
Dart facade + bounded local-logic request/reply boundary ---+
    | control                                             ^ transcripts
    v                                                     |
Native session coordinator (single lifecycle owner; session/turn/route IDs)
    |
    +-- OS permission/session/focus/route controller
    |
Microphone callback -> bounded capture ring -> audio worker
                                              | native conversion/resampler
                                              | optional qualified echo processing
                                              v
                                 frame adapter + VAD + pre-roll
                                              |
                              bounded streaming ASR input/state
                                              |
                                final transcript / partial events
                                              v
                               deterministic logic OR local LLM
                                              | bounded text deltas
                                              v
                               text segmenter -> bounded TTS queue
                                              | generated PCM at voice rate
                                              v
                              output resampler -> bounded render ring
                                                        |
                                  generation gate -> output callback -> speaker
                                                        |
                                actual rendered reference -> software AEC, if used

Cancellation/lifecycle lane -> generation gate + worker cancellation + state events
```

The graph describes logical ownership. It does not require one thread per box. Begin with one audio preparation worker and a bounded inference scheduler; profile separate ASR/TTS/LLM workers only where overlap helps. Audio callbacks are never inference workers.

## Frame and buffer contracts

Every internal frame descriptor carries sample rate, frame count, channel count, sequence number, monotonic capture timestamp, route epoch, discontinuity flag and pool-slot ownership. Turn-generated output additionally carries session and output-generation IDs. Hardware formats are negotiated separately. Internal model audio is mono float32; adapters explicitly convert for PCM16-only consumers. Downmixing and conversion occur outside real-time callbacks.

The proposed baseline uses a 16 kHz branch only for models declaring 16 kHz input. A stateful resampler converts from the actual hardware rate, maintains fractional phase and accounts for delay. Silero's selected 512-sample window is 32 ms at this rate; 10 ms hardware callbacks are accumulated, not padded and classified independently. Models with another rate get an explicit conversion branch. TTS emits its declared voice rate and is resampled once to the active output rate.

The following are **proposed bounded defaults, not measured optima**. Configurations validate capacities before starting; arithmetic uses checked native sizes. Report capacities in both frames and milliseconds at the actual rate.

| Queue/state | Proposed bound | Ownership and saturation behavior |
|---|---|---|
| Capture ring | 250 ms of negotiated hardware PCM | Hardware producer/audio-worker consumer, preallocated SPSC. If full, drop incoming frames, increment a discontinuity counter; worker invalidates the affected ASR turn and resets at the next safe boundary |
| VAD pre-roll | 300 ms at model rate | Audio worker circular history; preserve initial phonemes and interruption onset; copy into a new turn once |
| Utterance guard | Maximum 20 s per turn | Online ASR retains bounded decoder state; batch fallback buffers at most this duration. At limit, emit explicit `utteranceTooLong` and reset, never silently lose words |
| Partial-event lane | Latest partial per active turn; telemetry at most 10 Hz | Replaceable events coalesced; consumers do not control native capture progress |
| Reply text | 2 pending segments, each at most 240 Unicode scalar values | Segmenter pauses pull-based logic/LLM input at high water. Oversized single deltas fail with `capacityExceeded`; no arbitrary unlimited token accumulation |
| TTS in-flight result | One segment; maximum 10 s PCM | Adapter must reject/cancel before exceeding output cap. A backend that allocates unbounded whole output before callbacks cannot qualify for this profile |
| Render ring | 500 ms at output rate; initial prefill 60 ms | Inference worker may wait off the audio thread; render callback never waits and outputs silence on underflow |
| Control/terminal events | Reserved 32-record queue, plus atomic stop/error latch | Stop bypasses normal queues. Reject new turn admission when terminal capacity is exhausted; preserve an explicit terminal fault and stop session instead of dropping it |
| Conversation context | Last 8 finalized turns, at most 2,048 tokenizer tokens for initial LLM profile | Evict oldest complete turns; preserve system policy. Reject an over-limit current request; no automatic extra summarizer/model load |

At 48 kHz mono float32, a 250 ms capture ring holds 12,000 samples and 48,000 bytes; a 500 ms render ring holds 96,000 bytes. At 16 kHz, 300 ms pre-roll holds 19,200 bytes and 20 s raw float audio holds 1,280,000 bytes. These are arithmetic storage examples, exclude descriptors/alignment/copies, and are not total memory claims.

Never let the producer advance a consumer-owned ring cursor in an unsafe attempt to “drop oldest.” Publish discontinuity via an atomic sequence counter; the consumer handles its own reset. Model state must not concatenate speech across dropped frames. A multi-consumer fan-out requires separate ownership/rings, not two readers of an SPSC ring.

## Streaming and response scheduling

Streaming ASR may produce revisable partial text. Only a finalized utterance triggers the default intelligence request; speculative actions on partials are outside scope. VAD onset/hangover and recognizer endpointing feed one turn coordinator so they cannot independently finalize the same turn twice. Proposed endpoint hangover is 400 ms, tunable per profile; measure clipped speech against response delay. VAD recurrent state resets on discontinuities/session resets, not every callback.

A reply segmenter converts text deltas into bounded speakable segments. Prefer sentence boundaries; after a proposed 250 ms wait, emit a stable clause/word boundary if available. Keep an incomplete word until completed, and fail on the explicit segment cap rather than cutting inside a Unicode scalar or buffering forever. Do not interpret punctuation splitting as a guarantee of ideal prosody. Flush remaining text on normal end; discard it on cancellation.

Three capabilities are distinct: streaming text input to a TTS model, generated PCM callbacks for one complete text input, and playback of completed sentence segments. The initial contract requires the third, optionally uses the second, and does not assume the first. An adapter reports `incrementalPcm` only after tests establish that PCM arrives before full-segment completion on that exact build/model. [sherpa callback evidence](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/jni/offline-tts.cc).

Backpressure is cooperative between native inference workers and the Dart logic stream. Pausing a subscription alone does not guarantee that an arbitrary Stream producer stops allocating; the adapter boundary counts buffered characters/deltas, rejects oversized production, cancels the request and reports `capacityExceeded`. Non-cooperative engines are disqualified or quarantined after cancellation; their output is never admitted to an expired generation.

## Latency accounting

Measure speech-end to first audible output as the elapsed interval across endpoint confirmation, ASR finalization, logic first speakable segment, TTS first PCM, output prefill and device output buffering. Stages can overlap; record timestamps rather than adding unrelated averages. Separately measure first partial from speech onset, cold model load, UI dispatch delay and end-to-end turn completion.

Proposed initial aspirations are p95 at most 1.5 s from speech end to first audible response for deterministic short replies, at most 2.5 s with the optional LLM, and at most 150 ms from accepted interruption to audible stop. These are **[UNVERIFIED] targets requiring Phase 0 ratification**, not contractual performance promises. If a backend misses, report the measured decomposition and change the profile or documented target before release. Do not claim speaker silence from a Dart cancel timestamp: use loopback/external acoustic measurement or a separately qualified device presentation estimate.

## State machine

Use two coordinated state dimensions: lifecycle (`initializing`, `ready`, `running`, `suspended`, `stopping`, `failed`, `disposed`) and turn activity (`idle`, `listening`, `recognizing`, `thinking`, `speaking`, `interrupting`). Capture activity is a separate flag because listening can continue while speaking in full-duplex mode. A single flat enum would falsely imply these cannot overlap.

| Trigger and guard | Transition | Required effects |
|---|---|---|
| Assets validated, engines loaded | initializing -> ready/idle | Publish capabilities; microphone remains closed |
| start, permission/focus/session granted | ready -> running/listening | Create fresh route epoch; start capture; acknowledge only after backend starts |
| speech onset | listening -> recognizing | Allocate turn ID, prepend pre-roll once, stream audio |
| endpoint or explicit end-of-utterance | recognizing -> thinking | Finalize exactly once; emit final transcript; dispatch logic |
| first PCM actually admitted to renderer | thinking -> speaking | Publish speaking activity; track playout, not just TTS invocation |
| valid near-end onset or explicit interrupt | thinking/speaking -> interrupting -> listening/recognizing | Advance generation, gate stale PCM, flush old text/audio, cancel old work, preserve new speech |
| renderer drained and logic/TTS completed | speaking -> listening | Commit completed assistant reply/history; do not confuse synthesis complete with playback complete |
| transient OS interruption or route loss | running -> suspended/idle | Invalidate output, stop capture/render, preserve only bounded text history |
| explicit resume via start after checks | suspended -> running/listening | Rebuild route state and require continuing user intent; no blind auto-resume |
| stop | running/suspended/ready -> stopping -> ready/idle | Stop microphone/output, invalidate turns, acknowledge worker quiescence; keep models warm |
| unrecoverable fault | any live state -> failed/idle | Gate output, stop admission, expose typed fault; dispose required before recreation |
| dispose after safe shutdown | any live state -> disposed/idle | Release handles, close event stream once; subsequent calls fail except repeat dispose |

Commands are serialized. Repeated `start` while running is idempotent; start during stopping returns `invalidState`. Repeated stop/dispose share the in-progress result. Every event has a monotonic sequence; stale session/turn/route generations cannot update current state. A recoverable utterance error returns to listening; a session-fatal error enters failed.

## Barge-in and acoustic echo

Reliable barge-in requires a qualified echo-processing path. VAD on microphone audio alone may recognize the agent's own loudspeaker output. Android's AcousticEchoCanceler attaches to an AudioRecord session and is device-dependent; it must not be assumed to cover Oboe. On iOS, `voiceChat` mode alone does not enable voice processing. [Android AEC](https://developer.android.com/reference/android/media/audiofx/AcousticEchoCanceler), [Apple voiceChat](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat).

The baseline supports half-duplex continuous turns and explicit user interruption on every qualified device. During half-duplex playback, suppress ASR admission; an explicit interrupt first gates output, then starts/reenables capture, with a measured route-specific tail guard. Full-duplex speech interruption is enabled only when the route profile passes self-echo and double-talk tests. A mode requiring full duplex must fail preflight if unavailable; it must not silently degrade.

On confirmed near-end speech, the native coordinator atomically advances output generation and the renderer rejects old-generation frames before its next buffer submission. Drain stale rings off the real-time path, cancel LLM/TTS/logic, preserve near-end pre-roll and start a new recognition turn. Old inference may take longer to stop, but cannot resume speech. OS/hardware buffers may leave a residual audible tail; measure and disclose it. For software AEC, use the reference actually rendered after resampling/gain with clock/delay alignment, and avoid stacking it with platform AEC without evidence.

# Chapter 3 — Proposed Dart API and developer experience

## API status and design

Everything in this chapter is a **proposed SDK interface**, not a claim about available package exports. The declarations below form the vocabulary for the example; a future backend implements `VoiceAgentFactory`. Examples are specification material, not compiled against the current skeleton. Engine-specific native handles and raw PCM are deliberately absent from the normal app interface.

```dart
import 'dart:async';

enum ConversationMode { halfDuplex, fullDuplexRequired }
enum AgentLifecycle {
  initializing, ready, running, suspended, stopping, failed, disposed
}
enum TurnActivity { idle, listening, recognizing, thinking, speaking, interrupting }
enum AgentEventKind { state, partialTranscript, finalTranscript, replyText, interrupted, fault }
enum AgentErrorCode {
  missingAsset, invalidAsset, unsupportedProfile, permissionDenied,
  audioUnavailable, invalidState, capacityExceeded, utteranceTooLong,
  inferenceFailed, shutdownTimeout
}

final class LocalModelBundle {
  const LocalModelBundle({required this.directory, required this.manifestPath});
  final String directory;
  final String manifestPath;
}

final class AgentConfig {
  const AgentConfig({
    required this.models,
    required this.profileId,
    this.locale = 'en-US',
    this.mode = ConversationMode.halfDuplex,
    this.endpointSilence = const Duration(milliseconds: 400),
    this.maxUtterance = const Duration(seconds: 20),
  });
  final LocalModelBundle models;
  final String profileId;
  final String locale;
  final ConversationMode mode;
  final Duration endpointSilence;
  final Duration maxUtterance;
}

final class AgentCapabilities {
  const AgentCapabilities({
    required this.partialTranscripts,
    required this.incrementalPcm,
    required this.qualifiedSpeechInterruption,
  });
  final bool partialTranscripts;
  final bool incrementalPcm;
  final bool qualifiedSpeechInterruption;
}

final class AgentFailure implements Exception {
  const AgentFailure(this.code, this.message, {required this.fatal});
  final AgentErrorCode code;
  final String message;
  final bool fatal;
  @override
  String toString() => 'AgentFailure($code): $message';
}

final class AgentEvent {
  const AgentEvent({
    required this.sequence,
    required this.sessionId,
    required this.kind,
    required this.lifecycle,
    required this.activity,
    required this.captureActive,
    this.turnId,
    this.text,
    this.failure,
  });
  final int sequence;
  final int sessionId;
  final int? turnId;
  final AgentEventKind kind;
  final AgentLifecycle lifecycle;
  final TurnActivity activity;
  final bool captureActive;
  final String? text;
  final AgentFailure? failure;
}

final class AgentRequest {
  const AgentRequest({required this.turnId, required this.text, required this.locale});
  final int turnId;
  final String text;
  final String locale;
}

abstract interface class CancellationSignal {
  bool get isCancelled;
  Future<void> get whenCancelled;
}

abstract interface class LocalIntelligence {
  Stream<String> respond(AgentRequest request, CancellationSignal cancellation);
}

abstract interface class LocalVoiceAgent {
  AgentCapabilities get capabilities;
  AgentLifecycle get lifecycle;
  Stream<AgentEvent> get events;
  Future<void> start();
  Future<void> interrupt();
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class VoiceAgentFactory {
  Future<LocalModelBundle> prepareBundledModels(String manifestAsset);
  Future<LocalVoiceAgent> create({
    required AgentConfig config,
    required LocalIntelligence intelligence,
  });
}
```

`profileId` resolves to a local manifest entry containing concrete engine/model versions, locale support, memory/queue limits and threading settings. There are no guessed runtime model names in the example. Configuration rejects zero/negative timing, unsupported locale, unknown profiles and incompatible rates before capture. Applications should not have to choose native pointer layouts or scheduling priorities.

Event invariants: transcript/reply events require `text` and a `turnId`; `fault` requires `failure`; state snapshots always carry both state dimensions. Events contain no raw audio. Sequence IDs establish delivery order; the stream is single-subscription with bounded implementation-side delivery and coalescing of partials. Terminal delivery uses the reserved lane described in Chapter 2; a paused subscriber cannot create an unbounded Dart buffer. A second listener throws; UI state management should subscribe once and distribute lightweight view state.

`create` validates assets and loads engines without activating the microphone. If it fails, it must unwind all allocations it acquired. `start` may request microphone permission through the host platform integration and acknowledges actual capture start. Permission denial is a typed failure and never starts capture. `capabilities` reflects the validated current route; it is re-evaluated after route changes, and route loss suspends a session requiring full duplex.

`interrupt` acknowledges that the generation gate and cancellation request are installed, not that all native work has exited or acoustic silence is already proven. It keeps an active session listening. `stop` closes capture/playout and waits for safe worker quiescence but keeps reusable model handles; `dispose` additionally releases them. Both are explicit, asynchronous and idempotent. Session faults use typed `fault` events; command/initialization failures reject their Futures with `AgentFailure`. The event stream does not also emit the same error through `addError`.

The optional native LLM adapter implements `LocalIntelligence`; each instance belongs to one agent and its context is bounded by the profile. A host-supplied logic object is not disposed by the SDK, but all its active stream subscriptions are cancelled and its cancellation signal is set before agent shutdown acknowledges. No fallback network provider is accepted by a strict reference profile; arbitrary host code remains the host's responsibility.

## Initialization, configuration, streams and cleanup

This example is complete at the proposed abstraction boundary: the application supplies a future factory implementation, an actual bundled manifest path and a real profile ID from that manifest. The bundled manifest is an application asset the implementer must create; it does not exist in the current repository.

```dart
final class CommandLogic implements LocalIntelligence {
  @override
  Stream<String> respond(
    AgentRequest request,
    CancellationSignal cancellation,
  ) async* {
    if (cancellation.isCancelled) return;
    final command = request.text.trim().toLowerCase();
    yield command.contains('help')
        ? 'You can ask for help or stop this session.'
        : 'I heard you. This reply was generated locally.';
  }
}

Future<void> runVoiceSession({
  required VoiceAgentFactory factory,
  required String manifestAsset,
  required String profileId,
  required Future<void> stopRequested,
  required Stream<void> interruptRequests,
  required void Function(AgentEvent) onEvent,
  required void Function(AgentFailure) onFailure,
}) async {
  LocalVoiceAgent? agent;
  StreamSubscription<AgentEvent>? eventSubscription;
  StreamSubscription<void>? interruptSubscription;
  final terminal = Completer<void>();
  try {
    final models = await factory.prepareBundledModels(manifestAsset);
    final created = await factory.create(
      config: AgentConfig(
        models: models,
        profileId: profileId,
        locale: 'en-US',
        mode: ConversationMode.halfDuplex,
        endpointSilence: const Duration(milliseconds: 400),
      ),
      intelligence: CommandLogic(),
    );
    agent = created;
    eventSubscription = created.events.listen((event) {
      onEvent(event); // UI can switch on kind and replace partial transcript text.
      if (event.kind == AgentEventKind.fault) {
        onFailure(event.failure!);
        if (event.failure!.fatal && !terminal.isCompleted) terminal.complete();
      }
    });
    await created.start();
    interruptSubscription = interruptRequests.listen((_) {
      unawaited(created.interrupt().catchError((Object error) {
        if (error is AgentFailure) {
          onFailure(error);
        } else {
          onFailure(AgentFailure(
            AgentErrorCode.inferenceFailed, '$error', fatal: true,
          ));
        }
      }));
    });
    await Future.any<void>([stopRequested, terminal.future]);
  } on AgentFailure catch (failure) {
    onFailure(failure);
  } finally {
    // Nested cleanup ensures subscription release even when disposal reports failure.
    try {
      await interruptSubscription?.cancel();
    } finally {
      try {
        await agent?.dispose(); // Includes stop; safe when start failed.
      } finally {
        await eventSubscription?.cancel();
      }
    }
  }
}
```

A real widget stores its session owner and awaits shutdown through application lifecycle coordination; Flutter's synchronous widget `dispose` is not proof that asynchronous native cleanup finished. Subscribe before `start` to receive initial transitions, keep UI callbacks inexpensive, and route heavy Dart business logic to a long-lived isolate. The session owner must decide what to display on shutdown failure; the example lets disposal failure propagate after all subscriptions are released.

For manual button control, the same interface supports `await agent.interrupt()` while speaking, `await agent.stop()` to release microphone/focus while retaining loaded models, and `await agent.start()` to resume after fresh platform checks. Full-duplex speech interruption uses `ConversationMode.fullDuplexRequired`; initialization/start must reject it if the active route cannot meet that capability.

## Native adapter contract

The ABI is versioned independently of Dart semver. It uses session handles, explicit byte/frame counts, error/status codes and immutable capability records. Every buffer crossing ownership boundaries specifies who releases it and how long it remains valid. No C++ exception, `std::string`, or engine-specific struct crosses the boundary. Operations that may block enqueue work and return a request ID; completion is delivered outside the real-time thread.

FFI listeners may notify Dart asynchronously from worker threads, but a borrowed callback buffer must not outlive its native storage. Copy compact records or use a bounded acknowledged event pool. `NativeCallable.listener` requires pointer lifetimes through callback completion and must not be called after close. Close publication first, then quiesce producers, drain/release pending records and only then close the callback handle. [Dart callback contract](https://api.dart.dev/dart-ffi/NativeCallable/NativeCallable.listener.html).

# Chapter 4 — Memory, mobile constraints and resource management

## Ownership and failure containment

| Resource | Owner | Release condition |
|---|---|---|
| OS capture/render/session/focus | Native session coordinator | Backend callbacks stopped and focus/session released |
| Native engine and model handles | One adapter instance per agent | All its requests have completed/cancelled and worker references are gone |
| Audio rings/resampler/AEC state | Native audio subsystem | Input/output callbacks and workers quiescent |
| Turn context/KV cache | Intelligence adapter | Cancel acknowledged or turn evicted; capped context policy |
| Event records/callback registration | Native event bridge | All posted records acknowledged/reclaimed, producer publication disabled |
| Dart subscriptions and host listeners | Session owner/SDK boundary | Cancelled during dispose; no new delivery after terminal close |
| Local asset installation | Manifest store | Transaction complete; no active mapped readers before version removal |

Dispose order is normative: reject new work; advance output generation and gate audio; stop capture/render callbacks; signal cancellation; join workers and establish callback quiescence; drain bridge records; release inference/audio objects; close native-to-Dart callback handles; close the Dart event stream. Model handles must never be freed simply because a shutdown deadline elapsed.

A non-cooperative worker produces `shutdownTimeout`; resources it may still reference stay quarantined until safe release. Mark the instance failed, reject restart and expose the retained-resource condition. This is an exception path with a visible resource cost, not a successful disposal or an accepted permanent zombie. Backends that repeatedly require this path fail qualification. Abrupt process termination is not covered by graceful-cleanup guarantees.

Use a NativeFinalizer only as a fallback for abandoned non-active handles with a safe destructor, not to stop microphone sessions or join live workers. Finalization is not timely and cannot substitute for explicit disposal. [NativeFinalizer](https://api.dart.dev/dart-ffi/NativeFinalizer-class.html).

Resident memory includes mapped weights, inference workspaces, thread stacks, allocator caches, tokenizers, KV caches, double-buffering and generated audio. Measure OS process/native memory as well as Dart heap. Keep optional LLM libraries/model assets out of a speech-only application; do not bundle every backend. Avoid parallel duplicate loads, cap context/output, warm one selected profile and release idle adapters under memory pressure. Loading and unloading entire models every utterance is not the default strategy.

## Asset and dependency manifest

The proposed local manifest contains pack/profile IDs, schema version, supported locales, adapter/runtime version, model architecture, relative file paths, byte lengths, SHA-256 digests, input/output rates, tokenizer/voice IDs, upstream immutable revision, license text paths, notices, phonemizer/native dependency inventory and supported capabilities. It also contains qualification-profile IDs and limits; configuration cannot silently exceed the qualified profile.

Reject absolute paths, traversal, symlink escapes and size overflows in imported packs. Import into a staging directory, verify completeness and hashes, and atomically activate a version only after preflight. A hash establishes integrity relative to the manifest, not authenticity of an untrusted manifest; trust bundled manifests or require a host-trusted signature for externally supplied packs. Keep the previous validated version for rollback and do not remove files still mapped by an active engine. Never download or verify against a network service during the strict offline path.

Model licenses, transitive native obligations and corpus rights must be checked before distribution. Backend spikes can use locally provided files; that is not approval to publish those files with the open-source package. Proposed core licensing should be chosen independently from model-pack licensing and reviewed before release.

## Android

The default session begins from a visible Activity after microphone permission. Declare/request `RECORD_AUDIO`. Background continuation is off by default; an opt-in implementation must use the appropriate microphone foreground-service type, permissions and notification, obey while-in-use restrictions and handle user/OS service stop. Android 14's type-specific permissions and microphone service start restrictions are part of the platform matrix. WorkManager is not a continuous microphone substitute. [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types).

For target API 35+, requesting focus requires the top app or a foreground service. Handle transient focus loss by suspension, permanent loss by stop, and gain only after permission/route/user-intent revalidation. Published Android 17 rules additionally restrict background audio and target-37 while-in-use operation; track those rules when choosing compile/target SDKs. This is documentation-based planning, not Android 17 device validation or a release-availability claim. [Audio focus](https://developer.android.com/media/optimize/audio-focus), [Android 17 audio changes](https://developer.android.com/about/versions/17/changes/bg-audio).

AudioRecord/AudioTrack is the initial communication path because the Android AEC API explicitly binds to an AudioRecord session. It still needs per-device proof. Evaluate Oboe when its latency benefits can be measured with an explicitly qualified processing strategy. Native callbacks do bounded buffer work only: no waiting on Dart, allocations, locks, logs, model loading or disk I/O. [Android low-latency guidance](https://developer.android.com/games/sdk/oboe/low-latency-audio).

Use current communication-device routing where available, feature-detect for older supported APIs and confirm the actual route/rates after a request. Bluetooth microphone and playback behavior differs by route; permission needs depend on the chosen APIs. Disconnect, USB removal or headset loss suspends private speech rather than unexpectedly moving it to the loudspeaker. [Android communication routing](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/audio-manager).

## iOS

Declare a meaningful `NSMicrophoneUsageDescription`, obtain permission and coordinate the app-wide AVAudioSession with the host. Use `playAndRecord` and a voice-processing engine for the qualified duplex profile; choosing `voiceChat` alone is insufficient. An unrelated Flutter audio plugin must not silently reconfigure the session. Native Apple speech adapters may introduce additional Speech-framework permission/asset requirements and must document those separately. [Microphone usage](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription), [audio session](https://developer.apple.com/documentation/avfaudio/avaudiosession).

Handle interruption began/ended, route changes and media-services reset. Invalidate output on interruption, rebuild route-dependent DSP state, and resume only when OS guidance and continuing user intent permit. Headphone removal pauses private output. A background audio declaration can enable a legitimate continuing audio use case, but is not a promise of unlimited inference, restart after termination or always-on listening. Background behavior and store acceptance remain release gates. [Interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), [route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes), [playAndRecord](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord).

## Thermal, battery and observability

Observe available platform thermal signals without aggressive polling. On rising thermal pressure, reduce optional model concurrency and generation length within the qualified profile; if required quality/latency cannot be sustained, refuse a new heavy turn or suspend with a visible reason. Do not change to a different language/model silently. On critical pressure or memory warning, stop admission and release idle resources safely. [Android thermal API](https://developer.android.com/games/optimize/adpf/thermal), [Apple thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property).

Local diagnostics record stage timestamps, model/build IDs, route/rates, queue high-water marks, underruns/discontinuities, cancellation acknowledgments, active worker count and coarse thermal state. Content logging is disabled by default. Raw audio export is an explicit bounded debug feature, outside normal events and disabled in the reference privacy profile. No implicit remote telemetry is allowed.

# Chapter 5 — Phased implementation roadmap and validation

This chapter schedules future product development. None of these runtime deliverables is claimed complete by the present documentation work. Each phase gets its own repository work item and frozen acceptance criteria.

## Phase 0 — Qualification and reproducible baseline

**Deliverables:** a pinned engine/model/dependency manifest; one English ASR/TTS pack with documented rights; Android and iOS release-build integration spikes; reproducible benchmark fixtures; selected device/OS/route matrix; measured footprint and memory; a decision on minimum platform versions and build packaging.

Compare Silero with WebRTC and TEN on the same speech/noise corpus. Compare sherpa streaming with Moonshine and a whisper.cpp final-only profile on identical utterances. Compare a small qualified sherpa voice with Kokoro and a traditional baseline. When generative behavior is required, compare llama.cpp with LiteRT-LM using compatible, fully identified models and explicitly acknowledge when the model itself differs. Do not attribute model differences solely to runtime speed.

**Exit gates:** release builds run offline on at least one physical Android and iPhone; no model is silently downloaded; missing/corrupt assets fail before microphone activation; a written quality/resource budget is ratified; exact TTS distribution rights resolved for any bundled reference pack. If no voice pack is approved, adapter-only development may proceed but bundled reference-app release remains blocked. No universal engine winner is declared from one device.

## Phase 1 — Foreground MVP

**Deliverables:** Dart facade and error/event contract; hybrid native bridge; local manifest installer; VAD + online ASR; deterministic logic; bounded sentence TTS and native playback; manual interruption; safe stop/dispose; foreground example app showing status/partial/final text and explicit permission outcomes.

Start with half-duplex continuous turns to prove the whole offline loop. Keep native audio callbacks independent from UI scheduling. Make optional LLM integration a separate adapter milestone so it cannot block basic voice commands. Proposed file layout: public facade under `lib/`, domain contracts under `lib/src/`, native coordinator/adapters under a dedicated native source directory, OS lifecycle code under Android/iOS plugin directories, and tests beside their owning modules. Final folder names follow the actual plugin packaging spike rather than the current skeleton's generic names.

**Exit gates:** repeated local command-response sessions pass on both physical platforms; bounded buffers, cancellation generations and lifecycle cases pass; absent permissions/models produce typed errors; no retained active microphone after stop; no unbounded memory growth over repeated sessions. Publish measured cold/warm latency and memory even when aspirational targets are missed. Document current streaming capabilities honestly.

## Phase 2 — Streaming optimization and qualified full duplex

**Deliverables:** callback-based TTS PCM where supported; optimized text segmentation/backpressure; local LLM adapter with capped context; AEC-qualified speech interruption; route-aware resampling/drift handling; measured worker/thread policy; optional user-initiated background profile after platform proof.

Tune endpoint delay against clipping, and TTS prefill against underflow. Preserve cancellation priority under token/PCM saturation. Measure whether Oboe, alternate ASR/runtime or hardware acceleration actually improves the selected profile; retain simpler implementations when not justified. Each acceleration path has a tested CPU fallback only if that fallback fits the same offline/resource contract.

**Exit gates:** acoustic self-echo and double-talk tests meet ratified false/missed-interruption thresholds per route; interrupt-to-audible-stop is measured; sustained tests meet approved thermal/resource limits; unsupported full duplex fails explicitly; optional background continuation passes supported platform scenarios. Do not label a route full-duplex qualified merely because simultaneous recording and playback work.

## Phase 3 — Hardening, documentation and open-source release

**Deliverables:** device/OS/ABI CI matrix, native sanitizer tests where supported, benchmark report, supply-chain/model bill of materials, installation and offline-pack guide, example app, migration/versioning policy, capability matrix, changelog and package dry-run artifacts. Review platform store policies and binary requirements current at release; this document does not freeze them indefinitely.

**Exit gates:** all supported profiles pass the unit/integration/device matrix; no unresolved critical correctness/lifetime defects; model/archive redistribution decisions recorded; licenses/notices included; package analysis/build checks pass on the pinned Flutter toolchain; assets and native binaries included as intended. A dry-run is not publication, and a host build is not proof of Android/iOS runtime behavior. Actual publishing, signing, store submission and deployment require their own authorized release work.

## Test strategy

| Layer | Positive coverage | Required negative/adversarial coverage |
|---|---|---|
| Dart unit | State transitions, event invariants, segmenter, configuration, profile parsing | Unknown profile, wrong rate/locale, zero limits, oversized delta, paused listener, double start/stop/dispose |
| Native unit | Ring wraparound, resampling continuity, frame counts, generation gates, request lifecycle | Overflow, underflow, NaN samples, invalid lengths, stale generation, callback racing destruction, worker hang |
| Asset/security | Atomic local install, version rollback, valid hash/model | Missing/corrupt file, traversal/symlink escape, dishonest length, untrusted manifest, incompatible adapter |
| Engine integration | Fixed corpus through pinned real engines, expected transcript/reply/audio shape | Cancellation during load/ASR/LLM/TTS, inference error, no-speech input, maximum-duration utterance |
| Offline integration | Cold install and restart with locally bundled assets and network denied | No assets, no system voice, error paths; assert no hidden network/fallback request |
| Acoustic/device | Speaker/headset/Bluetooth, accents/noise, normal response, near-end interruption | Self-echo, double-talk, loud volume, route drift/disconnect, clipped onset, residual output after cancel |
| OS lifecycle | Permission grant, foreground start, valid opt-in continuation | Permission revoke/deny, incoming call, lock/background, focus loss, service stop, media reset, private headset loss |
| Resource endurance | Warm/cold starts, repeated turns, idle stop, memory pressure handling | Growing native memory/threads, low storage during import, critical thermal state, non-cooperative shutdown |
| Flutter/UI | Scrolling/animation while inference runs, event consumption | Slow/paused UI listener cannot stall audio or grow queues indefinitely |
| Distribution | Exact ABI builds, notices, pack manifest, sample-app offline install | Missing native library/model, wrong runtime version, simulator-only success, omitted notice/license |

Use synthetic or explicitly licensed/consented audio fixtures. Unit fakes are useful for scheduler fault injection but cannot replace real-engine and physical-device proof. Record all failures, timeouts and dropped trials; never compute an attractive latency percentile only from successful easy turns.

## Benchmark protocol and proposed budgets

Pin app commit, Flutter/Dart, native compilers, runtime build flags, model hashes, quantization, thread counts, context limits, voice/rates, OS build, power/thermal state and audio route. Use at least two Android device tiers and two iPhone generations for release qualification; the concrete inventory is a Phase 0 output. Run at least 100 warm utterance trials per profile and 20 independent cold starts as an initial protocol, plus a 30-minute sustained session. These counts are proposed minimums, not a claim of statistical certainty.

Report p50/p95 and sample counts, WER/CER and corpus size, command success, VAD false cuts, acoustic barge-in false/missed rates, TTS intelligibility, app/runtime/model bytes, peak native/process memory, battery change, thermal trajectory and underruns. Use repeatable external/loopback timing for audibility where available; report instrumentation uncertainty.

Proposed budget candidates for ratification are at most 512 MiB peak process memory for the speech-only profile, at most 2 GiB for an optional LLM profile on qualified devices, and at most 250 MB model assets for the first speech-only pack. These are **[UNVERIFIED] planning ceilings**, not expected measurements or guarantees for an arbitrary Flutter host. Measure incremental SDK cost and whole reference-app memory separately. If no acceptable voice/model fits, record the measured tradeoff and revise the profile before release rather than mislabeling it compliant.

## Decisions still required before product implementation

1. Freeze the first product languages, domain corpus, voice quality/accuracy thresholds and accessibility expectations.
2. Choose concrete device/OS floors and routes; validate provisional Android/iOS minimums against every selected dependency.
3. Select model versions and resolve the full TTS phonemizer/voice distribution bill of materials.
4. Ratify measured latency, memory, storage and thermal budgets, including whether an LLM is needed at all.
5. Decide whether background continuation belongs in the first public release; always-on wake-word operation needs a separate feasibility/design work item.

These open decisions do not prevent building the adapter interfaces and qualification harness. They prevent claims of a universally deployable model pack, a measured optimal engine combination or a finished mobile SDK.
