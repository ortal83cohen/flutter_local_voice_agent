# Research: offline Flutter voice agent architecture

## Question

Which source-backed engine families and mobile integration constraints provide a practical foundation for a strictly offline Android/iOS voice agent in Flutter?

## Answer

The recommended engineering starting point is an adapter-based SDK, with Silero VAD and streaming sherpa-onnx ASR as the primary speech spike, deterministic Dart logic as the smallest useful intelligence layer, and an optional llama.cpp adapter for generative behavior. A sherpa-onnx TTS adapter is the preferred integration candidate, but selecting and distributing any voice is conditional on its language quality, model and phonemizer licensing, and measured phone performance. These are architecture recommendations, not a tested combination or a redistribution approval.

The coordinator did not conduct the technology research: three delegated streams produced the source-backed evidence below. Source claims and measured results are deliberately separated. There is no measured end-to-end latency, target-device RAM, incremental binary footprint, accuracy winner or thermal result in this work; all are [UNVERIFIED]. The catalog is broad and representative, not an impossible claim to enumerate every existing engine.

## Findings

### Speech recognition and endpointing

- Claim: sherpa-onnx has directly documented Flutter Android/iOS online-ASR and VAD paths; whisper.cpp has mobile support but window/chunk transcription should not be equated with stable streaming partials.
- Evidence: [speech research](research/speech.md), including its comparative tables and source register.
- Sources: [sherpa Flutter streaming example](https://github.com/k2-fsa/sherpa-onnx/blob/master/flutter-examples/streaming_asr/README.md), [whisper.cpp](https://github.com/ggml-org/whisper.cpp).
- Selection reasoning: start with the direct Flutter streaming route, retain whisper.cpp for languages/accuracy requirements where a final-only path wins a device bake-off. Model family names alone do not establish language coverage.

### Intelligence and TTS

- Claim: llama.cpp offers a mobile C/C++ integration route; LiteRT-LM is the current Google route while the older MediaPipe LLM API is maintenance-only. TTS generated-audio callbacks are distinct from accepting incrementally arriving text.
- Evidence: [intelligence and TTS research](research/intelligence-tts.md), especially the supplementary update, which supersedes its initial MediaPipe shortlist wording.
- Sources: [llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases), [LiteRT-LM](https://developers.google.com/edge/litert-lm), [MediaPipe migration notice](https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference), [sherpa TTS callback implementation](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/jni/offline-tts.cc).
- Selection reasoning: support deterministic logic first; make LLM model/RAM costs opt-in. Start TTS with bounded complete text segments and capability-gated audio callbacks. Do not promise incremental text conditioning or seamless prosody.

### Distribution is part of architecture

- Claim: runtime license, weights, voice assets, tokenizer/phonemizer data, and transitive native dependencies are separate distribution concerns. Current Piper is GPL-3.0; an Apache sherpa wrapper does not settle eSpeak dependency obligations.
- Evidence: [intelligence and TTS licensing analysis](research/intelligence-tts.md).
- Sources: [current Piper](https://github.com/OHF-Voice/piper1-gpl), [sherpa TTS configuration](https://github.com/k2-fsa/sherpa-onnx/blob/master/python-api-examples/offline-tts.py), [eSpeak NG](https://github.com/espeak-ng/espeak-ng).
- Selection reasoning: choose a backend architecture now, gate any shipped model pack on an exact bill of materials and license review. No model pack is approved by this document.

## Options considered

| Layer | Primary engineering candidate | Credible alternatives | Why not selected as universal default |
|---|---|---|---|
| VAD | Silero through sherpa-onnx | WebRTC VAD, TEN VAD, whisper.cpp VAD integration | Quality/device metrics unknown; TEN has extra license/platform conditions; WebRTC requires a different PCM/frame contract |
| STT | sherpa-onnx streaming model | whisper.cpp, Vosk, Moonshine Voice, sherpa non-streaming SenseVoice/FunASR/Parakeet families | Language, partial behavior, footprint and bridge evidence differ; none wins every dimension |
| Native STT | Optional only | Apple SpeechAnalyzer/SpeechTranscriber and SFSpeechRecognizer; Android on-device recognizer | OS assets, locale and device availability do not provide an app-controlled cross-platform model inventory |
| Intelligence | Deterministic logic; optional llama.cpp | LiteRT-LM, MLC, ExecuTorch, ORT/GenAI, Core ML/MLX, Foundation Models | Export paths, platform coverage, availability and integration burden differ; cloud/PCC excluded |
| TTS | sherpa-onnx adapter with qualified voice | Piper, Kokoro family, OS TTS, Flite, eSpeak, MeloTTS/OpenVoice/XTTS | Voice and transitive dependency rights unresolved; native voices not uniformly installed; large/cloning stacks lack demonstrated mobile packaging in this study |

## Constraints discovered

Strict offline must include locally supplied assets and an explicit failure when assets are absent. It must not mean silently downloading during initialization or falling back to a cloud recognizer. Generic Android recognition is unsuitable for the strict default. Native platform APIs remain optional profiles with explicit preflight and device evidence.

A final engine selection needs a frozen language/device matrix, model hashes, native build configuration and measured cold/warm behavior. Upstream speed figures, source checkpoint sizes and online examples are not phone measurements. More runtime families increase native packaging and memory complexity; adapters should permit comparison without shipping all runtimes to every application.

## Unresolved

- [UNRESOLVED: Product languages and minimum acceptable WER/CER, task success and voice intelligibility. Proposed first qualification is one English pack; Hebrew is not presumed from the conversation language.]
- [UNRESOLVED: Minimum phone generations/OS versions and acceptable package, storage, peak-memory and battery budgets.]
- [UNRESOLVED: Exact redistributable TTS archive including phonemizer data, runtime dependencies and notices.]
- [UNRESOLVED: Which chosen model/binding produces incremental PCM on both target platforms, with responsive cancellation.]
- [UNRESOLVED: Real-device echo cancellation and full-duplex barge-in quality across speaker, headset and Bluetooth routes.]
- [UNRESOLVED: Which optional LLM and context limit meet quality and thermal budgets.]

## Sources

All delegated source consultations are dated 2026-09-19. The complete primary-source registers and evidence boundaries are in [speech](research/speech.md), [intelligence and TTS](research/intelligence-tts.md), and [mobile systems](research/mobile-systems.md). Initial findings superseded by supplementary updates must be read with those updates, especially the LiteRT-LM migration and sherpa TTS callbacks.

## Mobile systems synthesis

The [mobile report](research/mobile-systems.md) supports a hybrid integration recommendation: Kotlin/Swift lifecycle and permission control through platform channels, a versioned C ABI for native engine control, and native worker/ring-buffer audio transport. Flutter background isolates cannot receive unsolicited platform messages; therefore raw audio EventChannels in a background isolate are not the assumed architecture. [Flutter isolates](https://docs.flutter.dev/perf/isolates).

Effective AEC and barge-in require device/route qualification. Android AcousticEchoCanceler attaches to an AudioRecord session and does not automatically cover an Oboe path; on iOS, a voiceChat session mode without voice-processing audio does not itself supply echo cancellation. [Android AEC](https://developer.android.com/reference/android/media/audiofx/AcousticEchoCanceler), [Apple voiceChat](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat).

Cancellation needs both an immediate generation gate at the renderer and eventual worker/callback quiescence before freeing memory. An asynchronous Dart native callback cannot use a borrowed buffer that expires before delivery. [Dart NativeCallable listener](https://api.dart.dev/dart-ffi/NativeCallable/NativeCallable.listener.html). These are design constraints, not measured cancellation latency.

Android microphone foreground-service/while-in-use restrictions and iOS app-wide audio-session interruptions make foreground-only the proposed MVP scope. User-initiated background continuation is an explicit later capability. Android 17 documentation adds audio hardening; its publication is not proof of availability or observed device behavior. [Android foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [Android 17 audio](https://developer.android.com/about/versions/17/changes/bg-audio), [iOS interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions).
