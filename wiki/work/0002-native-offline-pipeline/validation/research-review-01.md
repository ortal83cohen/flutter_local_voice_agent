---
id: pipeline-validation-research-review-01
title: "Research review 01"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation evidence and remaining qualification gates.
---

# Research review 01

Date: 2026-09-19

Verdict: CONDITIONAL

## Scope

Blind review of `00-research.md`, the three `research/*.md` reports, and `02-criteria.md` under the validation rubric. This is a research verdict, not an implementation or physical qualification verdict. No implementation acceptance criterion is certified by this report.

The pinned headers support the central feasibility claims: caller-scheduled online recognition, callback-based speech synthesis, and CPU cooperative llama.cpp abort. Model availability, native builds, immutable supply-chain hashes, licenses, acoustic behavior, and performance remain explicitly unverified. These boundaries are appropriate for research; they remain later acceptance gates.

## Findings

### F-001 — IMPORTANT — Returned TTS audio ownership is missing from the execution contract

Location: `research/speech.md:49`, `research/speech.md:62`.

The table and worker topology describe copying ephemeral callback samples but omit the separately returned `SherpaOnnxGeneratedAudio` object and its destructor. The pinned API returns that object even for callback generation and exposes `SherpaOnnxDestroyOfflineTtsGeneratedAudio`. A worker implemented only from this description can retain a generated result after each request, affecting AC-003 resource ownership and AC-004 bounded PCM. This is an incomplete research contract, not evidence of an existing implementation leak. The selected callback interface also does not by itself establish a bound on the engine's internal generated-audio allocation before a callback occurs.

Primary evidence: [pinned sherpa C header](https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/v1.12.14/sherpa-onnx/c-api/c-api.h), independently inspected via the web tool and the supplied local header. Its callback generation return type is `const SherpaOnnxGeneratedAudio *`; its generated-audio destructor is declared immediately after the callback generation declarations.

### F-002 — NIT — Simulator availability is internally contradictory

Location: `research/mobile.md:36`, `research/mobile.md:86`.

These passages say an available simulator is not established or imply availability is still future, while line 32 records available shutdown simulators. Simulator availability and an executed simulator build are separate facts. This wording does not undermine the correctly retained physical-device qualification boundary.

## Independent checks and output

Command:

```text
xcodebuild -version
```

Output:

```text
Xcode 26.3
Build version 17C529
```

Command:

```text
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --version
```

Output:

```text
Dart SDK version: 3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "macos_arm64"
```

Command:

```python
from pathlib import Path
r=Path('.')
print('Native host directories:', [str(p) for p in [r/'android',r/'ios',r/'example/android',r/'example/ios'] if p.exists()])
print('Model files:', [str(p) for p in r.rglob('*') if p.is_file() and p.suffix.lower() in {'.onnx','.gguf'}])
p=Path('/private/tmp/flva-sherpa-c-api.h')
s=p.read_text()
for name in ['SherpaOnnxOfflineTtsGenerateWithCallbackWithArg','SherpaOnnxDestroyOfflineTtsGeneratedAudio','SherpaOnnxOnlineStreamInputFinished','SherpaOnnxVoiceActivityDetectorFront']:
 print(name, 'present' if name in s else 'absent')
```

Executed with `python3` from repository root. Output:

```text
Native host directories: []
Model files: []
SherpaOnnxOfflineTtsGenerateWithCallbackWithArg present
SherpaOnnxDestroyOfflineTtsGeneratedAudio present
SherpaOnnxOnlineStreamInputFinished present
SherpaOnnxVoiceActivityDetectorFront present
```

Negative evidence check:

```python
from pathlib import Path
p=Path('wiki/work/0002-native-offline-pipeline/research/speech.md')
s=p.read_text()
print('Speech research names generated-audio destructor:', 'SherpaOnnxDestroyOfflineTtsGeneratedAudio' in s)
```

Executed with `python3`. Output:

```text
Speech research names generated-audio destructor: False
```

The [pinned llama header](https://raw.githubusercontent.com/ggml-org/llama.cpp/b10976/include/llama.h) was independently opened through the web tool. Its context fields include `n_ctx`, `n_batch`, and CPU-only `abort_callback`, consistent with the research. The [official release](https://github.com/ggml-org/llama.cpp/releases/tag/b10976) independently showed commit prefix `987498f` and a verified signature. This verifies source-level API and release identity only; no native build, model inference, mobile audio, or negative implementation test was executed in this research review.

## Retained acceptance boundaries

- AC-001 and AC-002: filesystem security and lifecycle delivery require implementation tests; no current proof.
- AC-003 and AC-004: queue/resource ownership and real speech inference require native tests, models, and measurements; F-001 applies to the research contract.
- AC-005: source-level audio feasibility is distinct from platform build and physical audio evidence.
- AC-006: pinned API supports the proposed optional CPU adapter; integration and cancellation remain unproved.
- AC-007: exact artifacts, notices, instructions, and package checks remain deliverables.
- AC-008: physical offline trials and performance evidence remain open; installed SDKs and simulators cannot satisfy them.

The main agent owns disposition of the findings and the retained gates. No repair or subsequent-phase decision is made by this reviewer.

## Verification performed

The executed commands and pasted outputs are preserved in the evidence section above. This metadata supplement does not change the independent verdict.

## Recurrence check

First round; no prior findings to recheck.
