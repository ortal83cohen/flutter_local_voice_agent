---
id: pipeline-research-speech
title: "Research: native offline speech feasibility"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation work artifact and evidence boundaries.
---

# Research: native offline speech feasibility

## Question

Can the proposed foreground, half-duplex speech path use the pinned
`sherpa-onnx` native C API for locally provisioned Silero VAD, streaming STT,
and TTS on Android and iOS without runtime networking?

## Answer

Yes at the API-design level: the verified `sherpa-onnx` v1.12.14 C header has
opaque handles, float PCM streaming input, incremental online-ASR results, and
TTS callbacks whose return value stops generation. It fits native workers that
own inference and PCM, bounded queues, generation invalidation before an
asynchronous stop, and joining those workers before handle release.

This checkout does not contain a `silero_vad.onnx`, a streaming ASR archive, a
TTS archive, or a native sherpa library. Therefore no local model load,
inference, ABI-link, Android, or iOS execution result exists yet. The model
recommendations below are qualification inputs, not redistribution approval.

## Exact pins and source links

| Component | Pin / artifact | Evidence and licence state |
|---|---|---|
| Runtime C ABI | `sherpa-onnx` `v1.12.14`, C header from tag, copied for inspection to `/private/tmp/flva-sherpa-c-api.h` | [Apache-2.0 runtime licence](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/LICENSE). The release must be pinned by tag and release-asset SHA-256 in the eventual model manifest; a tag alone is not an immutable asset digest. |
| VAD | `silero_vad.onnx` from [sherpa-onnx `asr-models` release URL](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx) | The upstream sherpa model catalog names this exact artifact. [Silero VAD declares MIT](https://github.com/snakers4/silero-vad/blob/master/pyproject.toml), and its [model history](https://github.com/snakers4/silero-vad/wiki/Version-history-and-Available-Models) documents an ONNX VAD path. The exact downloaded file's hash, provenance, and licence notice have not been captured here: **[UNVERIFIED]**. No redistribution approval is recorded. |
| Streaming English STT qualification candidate | `sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2`, containing `encoder-epoch-99-avg-1.onnx`, `decoder-epoch-99-avg-1.onnx`, `joiner-epoch-99-avg-1.onnx`, and `tokens.txt` | [Upstream model page and download route](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html) identify it as English, LibriSpeech-trained, and streaming. The archive's licence, notices, checksum, and commercial redistribution terms are **[UNVERIFIED]**; do not bundle it. |
| TTS qualification candidate | `csukuangfj/vits-ljs`: `vits-ljs.onnx`, `lexicon.txt`, `tokens.txt`; optional compatible `espeak-ng-data` only after a separate legal inventory | The [v1.12.14 C example](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/c-api-examples/offline-tts-c-api.c) names that model repository and the required files. The precise model/data licence and the exact eSpeak NG data/binary obligations are **[UNVERIFIED]**; current [eSpeak NG](https://github.com/espeak-ng/espeak-ng) is GPL-3.0. No redistribution approval is recorded. |

The initial device profile should use one 16 kHz mono float32 capture branch
only for VAD and the selected 16 kHz ASR model. TTS must use
`SherpaOnnxOfflineTtsSampleRate()` and be resampled once to the active native
output rate. Do not assume that the TTS voice itself is 16 kHz.

## C signatures verified

The following signatures were read in the locally supplied v1.12.14 header;
all functions use opaque, caller-destroyed objects.

| Purpose | Verified C API | Contract relevant to the worker design |
|---|---|---|
| Online ASR lifetime | `SherpaOnnxCreateOnlineRecognizer(const SherpaOnnxOnlineRecognizerConfig *)`; `SherpaOnnxCreateOnlineStream(const SherpaOnnxOnlineRecognizer *)`; `SherpaOnnxDestroyOnlineStream(const SherpaOnnxOnlineStream *)`; `SherpaOnnxDestroyOnlineRecognizer(const SherpaOnnxOnlineRecognizer *)` | One stream contains decoding state. A stop/restart must reset or replace it only on the owning ASR worker. |
| Online ASR input/decode/result | `SherpaOnnxOnlineStreamAcceptWaveform(const SherpaOnnxOnlineStream *, int32_t sample_rate, const float *samples, int32_t n)`; `SherpaOnnxIsOnlineStreamReady(...)`; `SherpaOnnxDecodeOnlineStream(...)`; `SherpaOnnxGetOnlineStreamResult(...)`; `SherpaOnnxDestroyOnlineRecognizerResult(...)` | Input is normalized mono float PCM; documented header behavior resamples when the supplied rate differs. Decode is explicitly caller-scheduled, so a bounded worker can drain only ready work and emit revisioned partial snapshots. |
| ASR end/reset | `SherpaOnnxOnlineStreamInputFinished(const SherpaOnnxOnlineStream *)`; `SherpaOnnxOnlineStreamIsEndpoint(...)`; `SherpaOnnxOnlineStreamReset(...)` | After `InputFinished`, the header forbids further `AcceptWaveform`; the pipeline must create/reset state only after inference drain. |
| VAD lifetime/input | `SherpaOnnxCreateVoiceActivityDetector(const SherpaOnnxVadModelConfig *, float buffer_size_in_seconds)`; `SherpaOnnxVoiceActivityDetectorAcceptWaveform(const SherpaOnnxVoiceActivityDetector *, const float *, int32_t)`; `SherpaOnnxVoiceActivityDetectorFlush(...)`; `SherpaOnnxDestroyVoiceActivityDetector(...)` | The header receives no timestamp and no per-call sample rate: configure VAD at 16 kHz and feed exactly 512 samples per Silero window. Timestamp/sample-count accounting belongs to the native capture worker. |
| VAD segment ownership | `SherpaOnnxVoiceActivityDetectorEmpty(...)`; `SherpaOnnxVoiceActivityDetectorFront(...)`; `SherpaOnnxDestroySpeechSegment(...)`; `SherpaOnnxVoiceActivityDetectorPop(...)`; `SherpaOnnxVoiceActivityDetectorReset(...)` | `Front` returns an owned segment; destroy it before pop/reset. Cap `buffer_size_in_seconds`, and bound the application queue separately. |
| TTS lifetime/sample rate | `SherpaOnnxCreateOfflineTts(const SherpaOnnxOfflineTtsConfig *)`; `SherpaOnnxOfflineTtsSampleRate(const SherpaOnnxOfflineTts *)`; `SherpaOnnxDestroyOfflineTts(const SherpaOnnxOfflineTts *)` | Query the actual model output rate and retain the handle exclusively on the TTS worker. |
| TTS callback/cancellation | `SherpaOnnxOfflineTtsGenerateWithCallbackWithArg(const SherpaOnnxOfflineTts *, const char *, int32_t, float, SherpaOnnxGeneratedAudioCallbackWithArg, void *)`; callback type `int32_t (*)(const float *, int32_t, void *)` | The header states return `0` stops generation and callback samples are only valid for the callback. The callback must check an atomic generation token before enqueuing/copying PCM, then return `0` when stale or full. |

Primary source for the current ABI shape: [v1.12.14 C header](https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/v1.12.14/sherpa-onnx/c-api/c-api.h). The later [v1.13.8 release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.8) exists, but this work intentionally pins v1.12.14 until an ABI and device spike approves an upgrade.

## Recommended native execution topology

1. The foreground audio worker captures hardware PCM, converts once to mono
   float32 in `[-1, 1]`, maintains a monotonic sample counter, and accumulates
   16 kHz VAD/ASR blocks without copying through Dart.
2. The VAD/ASR worker consumes bounded blocks. It feeds 512-sample Silero
   windows to VAD and continuous 16 kHz blocks to the online ASR stream; it
   calls decode only while `IsOnlineStreamReady` is true. VAD endpoints affect
   UX and finalization, not the validity of ASR's continuous decoding state.
3. The TTS worker owns its engine and output queue. It receives complete,
   bounded reply segments. Its callback copies each ephemeral PCM chunk into a
   bounded native playback queue at the queried model rate.
4. On stop, interruption, route loss, or a newer reply, increment the shared
   generation before requesting asynchronous cancellation. Workers discard
   stale input/output at every dequeue and callback. Stop capture, request
   VAD/ASR reset and TTS callback cancellation, join all workers, then destroy
   native streams/engines and release audio resources.

## Minimal build and link route

### Android

Build or obtain only the pinned `v1.12.14` arm64-v8a `libsherpa-onnx-c-api.so`
and headers, then package them under the plugin's `jniLibs/arm64-v8a/` (or build
the bridge with CMake against the exact `.so`). Link the native bridge to
`sherpa-onnx-c-api`; keep model assets in the app/plugin assets, extract them
to app-private files before C API construction, and validate a manifest with
asset SHA-256 before opening the microphone. The upstream Android guide permits
prebuilt release assets or source builds: [Android build documentation](https://k2-fsa.github.io/sherpa/onnx/android/build-sherpa-onnx.html).

### iOS

Build the same tag's C API for device `arm64` and simulator `arm64`/`x86_64`,
place its header in a module-visible framework/XCFramework, and link the bridge
to that XCFramework. The upstream build script creates a `SherpaOnnxC.framework`
with `sherpa-onnx/c-api/c-api.h`: [reference build script](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/build-ios-shared-sherpa-with-static-onnxruntime.sh).
Embed assets in the application bundle, copy them to application support only if
the pinned implementation requires writable paths, and preflight the copied
manifest without networking. Build success alone does not prove device audio,
inference, cancellation, or App Store compliance.

## Cancellation and streaming limits

- VAD and ASR do not expose a dedicated asynchronous cancellation function in
  the verified v1.12.14 C header. Cancellation therefore means halting input,
  invalidating generations, dropping queued PCM/results, and serializing reset
  or destruction after the owning worker is no longer inside C API code.
- TTS callback return `0` is cooperative cancellation observed at callback
  boundaries, not a preemptive interrupt of arbitrary native work. Measure
  cancellation tail on devices.
- The callback delivers PCM for one complete text request; it does not prove
  token-by-token text input or a seamless acoustic utterance across separately
  submitted text fragments.
- The online-ASR result is a current snapshot. Its text can change between
  decodes, so UI events need stream/generation identifiers and final/partial
  state rather than append-only text.
- The C header does not provide a thread-safety promise for one handle. Treat
  each recognizer stream, VAD handle, and TTS handle as single-worker-affine
  until a tag-specific upstream contract and stress test prove otherwise.

## Executable evidence commands and output

The following read-only commands were run on 2026-09-19 from the repository
root.

```text
$ git ls-tree -r --name-only HEAD | rg -i '(silero|sherpa|onnx|model)' || true
$ find /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent -type f \
  \( -iname '*silero*' -o -iname '*sherpa*' -o -iname '*.onnx' -o -iname '*.tar.bz2' \) -print

# no output
```

```text
$ find /private/tmp -maxdepth 2 -type f \
  \( -iname '*silero*' -o -iname '*sherpa*' -o -iname '*.onnx' -o -iname '*.tar.bz2' \) -print | sort
/private/tmp/flva-sherpa-c-api.h

$ rg -n "SherpaOnnx(CreateOnlineRecognizer|OnlineStreamAcceptWaveform|IsOnlineStreamReady|DecodeOnlineStream|GetOnlineStreamResult|CreateVoiceActivityDetector|VoiceActivityDetectorAcceptWaveform|CreateOfflineTts|OfflineTtsSampleRate)" /private/tmp/flva-sherpa-c-api.h
253:SherpaOnnxCreateOnlineRecognizer(
297:SHERPA_ONNX_API void SherpaOnnxOnlineStreamAcceptWaveform(
307:SherpaOnnxIsOnlineStreamReady(const SherpaOnnxOnlineRecognizer *recognizer,
321:SHERPA_ONNX_API void SherpaOnnxDecodeOnlineStream(
347:SherpaOnnxGetOnlineStreamResult(const SherpaOnnxOnlineRecognizer *recognizer,
966:SherpaOnnxCreateVoiceActivityDetector(const SherpaOnnxVadModelConfig *config,
972:SHERPA_ONNX_API void SherpaOnnxVoiceActivityDetectorAcceptWaveform(
1102:SHERPA_ONNX_API const SherpaOnnxOfflineTts *SherpaOnnxCreateOfflineTts(
1111:SherpaOnnxOfflineTtsSampleRate(const SherpaOnnxOfflineTts *tts);
```

These commands establish absence of a locally provisioned model/runtime and
presence of a header for source inspection. They do not establish an executable
native library, a valid model, or successful inference.

## Unresolved blockers

- [UNRESOLVED: Provision exact v1.12.14 Android and iOS native artifacts with release-asset SHA-256 values, and verify C ABI version at runtime.]
- [UNRESOLVED: Provision `silero_vad.onnx`, one exact online Zipformer archive, and one exact TTS archive locally; record source URL, immutable revision, SHA-256, contents, licence/notices, and approval status.]
- [UNRESOLVED: Run a host smoke test that loads each asset with the pinned library; then run physical Android/iOS foreground half-duplex capture, ASR partial/final, TTS playback, interruption, route change, and network-denied tests.]
- [UNRESOLVED: Select supported languages, device/OS/ABI matrix, memory/latency/cancellation-tail thresholds, and legal distribution decision.]

## Sources

- [sherpa-onnx v1.12.14 C header](https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/v1.12.14/sherpa-onnx/c-api/c-api.h), consulted 2026-09-19.
- [sherpa-onnx v1.12.14 C TTS example](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/c-api-examples/offline-tts-c-api.c), consulted 2026-09-19.
- [sherpa-onnx online Zipformer model documentation](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html), consulted 2026-09-19.
- [sherpa-onnx pre-trained model catalog](https://github.com/k2-fsa/sherpa/blob/master/docs/source/onnx/pretrained_models/index.rst), consulted 2026-09-19.
- [Silero VAD project metadata](https://github.com/snakers4/silero-vad/blob/master/pyproject.toml) and [model history](https://github.com/snakers4/silero-vad/wiki/Version-history-and-Available-Models), consulted 2026-09-19.
- [sherpa-onnx Android build guide](https://k2-fsa.github.io/sherpa/onnx/android/build-sherpa-onnx.html) and [iOS C API framework build script](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/build-ios-shared-sherpa-with-static-onnxruntime.sh), consulted 2026-09-19.

## Review disposition supplement

Research F-001: Every returned SherpaOnnxGeneratedAudio from callback generation is separately owned and must be destroyed with SherpaOnnxDestroyOfflineTtsGeneratedAudio, including cancellation. Callback PCM is borrowed only until return. VITS allocates a complete sentence before callback; input and admitted output limits are not a proven internal inference allocation bound. This remains AC-004 qualification work.
