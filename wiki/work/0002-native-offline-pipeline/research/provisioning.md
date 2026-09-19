---
id: pipeline-research-provisioning
title: "Research: host qualification provisioning"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation evidence and remaining qualification gates.
---

# Research: host qualification provisioning

## Scope

This report records temporary, host-only qualification inputs placed under
`/private/tmp/flva-qualification`. Nothing below was copied into the repository
or approved for application distribution.

## Result

The pinned macOS universal2 shared `sherpa-onnx` v1.12.14 runtime loaded a
locally provisioned Silero VAD, a streaming English Zipformer ASR set, and a
VITS LJS TTS set. The host smoke test segmented a bundled wave, transcribed it
through the VAD-plus-online-ASR executable, and generated a 22,050 Hz WAV.

This proves only a macOS host fixture using upstream executables and local
files. It does not prove the project bridge, C callback behavior, Android/iOS
packaging, device audio, cancellation latency, performance target, or a
redistribution decision.

## Provisioned inputs

| Input | Local path | Exact source | SHA-256 | Notice / gap |
|---|---|---|---|---|
| Runtime archive | `/private/tmp/flva-qualification/downloads/sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2` | [GitHub release asset](https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.12.14/sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2) | `7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413` | Release metadata gave the same digest. Runtime notice copied to `notices/sherpa-onnx-LICENSE`: Apache-2.0. Still inventory ONNX Runtime and every bundled native dependency before shipment. |
| C shared library | `/private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib/libsherpa-onnx-c-api.dylib` | Extracted from the preceding archive | `f696c660bcf950aa36a4c1a7f959c37eba9f9e96224c8be3bfb9c0519b88a08a` | Universal `x86_64 arm64`; depends on sibling `libonnxruntime.1.17.1.dylib`. |
| Silero VAD | `/private/tmp/flva-qualification/models/silero_vad.onnx` | [sherpa `asr-models` release asset](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx) | `9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6` | The captured [Silero VAD LICENSE](https://github.com/snakers4/silero-vad/blob/master/LICENSE) is MIT. The direct release artifact itself contains no separately captured manifest/revision; retain this digest and obtain the model publisher's asset provenance before distribution. |
| Streaming ASR archive | `/private/tmp/flva-qualification/downloads/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2` | [sherpa `asr-models` release asset](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2) | `639e25b578e9e997131402199419c13a941f8e4e198e2da1ce57dbf5cf401282` | Extracted `README.md` declares `apache-2.0`, names [the upstream torch model](https://huggingface.co/Zengwei/icefall-asr-librispeech-streaming-zipformer-2023-05-17), and cites Icefall PR 1058. A complete model/data/notices review remains required. |
| ASR int8 components | `.../asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/` | Extracted from preceding archive | encoder `5022b2eca5b19d1bc104fcf33e26bc32604b7df553cd2e1f62e31dc7b05e9c87`; decoder `780c63ee94c7fa314211172e5d09b406c0da2beab5c40ea2f54cc95670b76a5`; joiner `abd5e30f3f16fc510605c6029dba33f10e4386bd75c5bdc30cf94076864db10d`; tokens `49e3c2646595fd907228b3c6787069658f67b17377c60aeb8619c4551b2316fb` | The qualified files include `bpe.model`, three test WAVs and `trans.txt`. Only English/LibriSpeech behavior is indicated by its upstream documentation; do not generalize language or quality. |
| Test audio | `.../asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/test_wavs/0.wav` | Extracted from preceding archive | `6bc58a4efdf20daac252b6b1502632601a71efe0308f6757dc1eda34891a7e4f` | The archive transcript says: `AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS`. Its reuse rights have not been independently reviewed. |
| VITS model | `/private/tmp/flva-qualification/models/vits-ljs.onnx` | [Hugging Face direct file](https://huggingface.co/csukuangfj/vits-ljs/resolve/main/vits-ljs.onnx) | `5bbd273797a9ecf8d94bd6ec02ad16cb41cbb85f055ad98d528ced3e44c9b31a` | Captured [model card](https://huggingface.co/csukuangfj/vits-ljs/resolve/main/README.md) declares `apache-2.0` and names third-party upstream inputs. That declaration is evidence to preserve, not legal distribution approval; confirm all upstream data and conversion terms. |
| VITS frontend files | `/private/tmp/flva-qualification/models/lexicon.txt`; `/private/tmp/flva-qualification/models/tokens.txt` | [Hugging Face lexicon](https://huggingface.co/csukuangfj/vits-ljs/resolve/main/lexicon.txt); [tokens](https://huggingface.co/csukuangfj/vits-ljs/resolve/main/tokens.txt) | lexicon `bdccfc6da71c45c48e2e0056fcf0aab760577c5f959f6c1b5eb3e3e916fd5a0e`; tokens `5fee2c6b238d712287f2ecb08f34a8a8b413bcb7390862ef6fb6fd6f0f8d3a17` | This qualification used `--vits-lexicon`, not eSpeak data. Do not infer that a different VITS/Kokoro pack has no phonemizer obligations. |

## Runtime and model inventory

The extracted runtime includes `libsherpa-onnx-c-api.dylib`,
`libonnxruntime.1.17.1.dylib`, C headers, and executable tools including
`sherpa-onnx-vad`, `sherpa-onnx-vad-with-online-asr`, and
`sherpa-onnx-offline-tts`. `lipo -archs` reported `x86_64 arm64` for the C API
library. `otool -L` reports its ONNX Runtime dependency through
`@rpath/libonnxruntime.1.17.1.dylib`; an eventual host app must package and
link that exact dependency for the target platform.

The ASR archive is 296 MiB compressed and contains both int8 and non-int8
component models. The runtime archive is 40 MiB compressed. Those host archive
sizes are not Android/iOS package-size measurements.

## Executed host evidence

All commands below ran on 2026-09-19 using only local files after provisioning.

```text
$ .../bin/sherpa-onnx-version
sherpa-onnx version : 1.12.14
sherpa-onnx Git SHA1: 26aa2fa9
sherpa-onnx Git date: Thu Sep 18 07:09:10 2025
```

```text
$ .../bin/sherpa-onnx-vad --silero-vad-model=.../silero_vad.onnx \
  .../test_wavs/0.wav /private/tmp/flva-qualification/vad-0.wav
VadModelConfig(... sample_rate=16000, num_threads=1, provider="cpu", ... window_size=512)
0.358 -- 6.624
Saved to /private/tmp/flva-qualification/vad-0.wav
```

```text
$ .../bin/sherpa-onnx-vad-with-online-asr --silero-vad-model=... \
  --tokens=.../tokens.txt --encoder=...int8.onnx --decoder=...int8.onnx \
  --joiner=...int8.onnx --provider=cpu --num-threads=2 \
  --decoding-method=greedy_search .../test_wavs/0.wav
Creating recognizer ...
Recognizer created!
vad segment(1:0.358-6.624) results:  AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
Elapsed seconds: 0.328 s
Real time factor (RTF): 0.328 / 6.625 = 0.050
```

This RTF is a single host invocation on one bundled sample, not a device
latency, accuracy, or sustained-performance claim.

```text
$ .../bin/sherpa-onnx-offline-tts --vits-model=.../vits-ljs.onnx \
  --vits-lexicon=.../lexicon.txt --vits-tokens=.../tokens.txt \
  --output-filename=/private/tmp/flva-qualification/tts.wav "Offline qualification."
Number of threads: 1
Elapsed seconds: 0.752 s
Audio duration: 1.115 s
Real-time factor (RTF): 0.752/1.115 = 0.675
The text is: Offline qualification.. Speaker ID: 0
Saved to /private/tmp/flva-qualification/tts.wav successfully!
sample=24576, progress=1.000000
```

`afinfo` confirms `tts.wav` is one-channel 22,050 Hz signed-16-bit PCM,
1.114558 seconds; `vad-0.wav` is one-channel 16,000 Hz signed-16-bit PCM,
6.266 seconds. The TTS run emitted repeated `Unknown token` warnings and
ignored the OOV word `offline`; it still wrote audio. That is a qualification
finding, not a successful text-quality result.

## TTS callback limit found in source

The v1.12.14 source captured at `/private/tmp/flva-vits.h`, corresponding to
[`offline-tts-vits-impl.h`](https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/sherpa-onnx/csrc/offline-tts-vits-impl.h), shows the single-batch path calls
`Process(...)` first, then invokes the callback once with the completed
`ans.samples`; multi-batch processing also appends completed batch audio to
`ans.samples` before/alongside callbacks. It therefore does **not** establish
sub-sentence PCM delivery, a hard bound on an individual sentence's internal
allocation, or streaming text input. `max_num_sentences` only bounds the
number of sentences per batch; it cannot by itself enforce the proposed native
PCM queue or a per-sentence duration bound.

## Remaining gates

- No asset in this temporary directory is approved for redistribution.
- Verify all model/archive and transitive-data licences and notices against an
  approved release manifest before bundling any asset.
- Write and run an application-owned C/FFI smoke that proves handles, callbacks,
  cancellation, ownership and worker joining under the project contract.
- Repeat the same qualification on supported physical Android and iOS devices,
  including no-network, route change, interruption, long input, cancellation,
  and memory/thermal measurements.
