---
id: pipeline-01-plan
title: "Plan: Native offline voice pipeline"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation work artifact and evidence boundaries.
---

# Plan: Native offline voice pipeline

## Goal

Provide an Android/iOS Flutter plugin that runs locally supplied Silero VAD, streaming transducer ASR and VITS TTS through pinned sherpa-onnx, deterministic Dart logic, and an optional bounded llama.cpp adapter. Deliver executable tests, a usable example, reproducible build instructions and honest qualification records. Physical device gates remain open until executed.

## Approach

A native C++ session owns engine objects and a persistent inference worker. A narrow C ABI carries fixed-size events, input frames, generated audio and commands. Kotlin and Objective-C++ own permissions and OS audio. Dart validates locally supplied manifests before native loading, polls bounded native events, invokes local response logic and exposes typed events. Audio stays native. Platform lifecycle operations gate and stop audio before waiting for worker quiescence off the UI thread.

Local assets are host-trusted manifests with exact runtime, model role, relative paths, byte lengths, SHA-256 and license files. Preflight rejects escapes and missing or corrupt files. Installation stages and validates before atomic activation; no runtime network dependencies exist. Engine binaries are build-time inputs with documented provenance and exact version. No model redistribution is implied.

## Why this approach

The existing ADR selects native ownership. Routing PCM through Dart would couple microphone progress to UI scheduling. OS recognition and voices cannot guarantee an app-controlled offline model inventory. A mandatory LLM would impose unnecessary model and memory costs. Native output callbacks support PCM backpressure but are not incremental text conditioning. Unqualified full duplex remains explicitly unavailable.

## Steps

1. Record exact environment, upstream APIs, dependencies and local model availability in research; choose concrete pins and retain unresolved device and license gates.
2. Freeze public Dart configuration, event/error shapes and the C ABI. Establish build files and test harnesses centrally. Validate research and plan independently before implementation.
3. Implement the native rings, generation gate, worker, sherpa adapters, bounded events and optional LLM. Exercise positive and failure paths with native tests and real models when obtainable.
4. Implement Dart manifest validation and transactional import, bounded event delivery, lifecycle commands and deterministic response handling with failure tests.
5. Implement Android and iOS bridges serially against the shared ABI. Handle permission, focus, interruption, route changes and thermal suspension; generate reference app platform projects and build both available targets.
6. Integrate the foreground example, installation guide, model/license inventory, capability matrix and qualification commands. Run format, analysis, tests, native sanitizers, real engine smoke and mobile builds where possible.
7. Obtain an independent implementation verdict and resolve findings by defect class. Record all unexecuted gates, add documentation and package dry-run evidence without publishing.

## Interfaces and shared decisions

Only the coordinator edits shared contracts and configuration. Native model input is mono float32 at 16 kHz with 512-sample VAD windows. Hardware input may be mono float32 at its declared rate and is converted by a stateful native worker resampler. Output is mono float32 at the configured model rate; platform playback uses that rate. Capture capacity is 250 ms at a declared rate no greater than 192 kHz, pre-roll 300 ms, utterances 20 seconds, replies at most 240 Unicode scalars, TTS output at most 10 seconds, render capacity 500 ms and event capacity 32. Reject unsupported limits; never silently grow buffers.

One native worker owns inference and destruction. Audio producers and consumers perform bounded copies only; overflow sets a discontinuity latch and invalidates the turn. Stop and interruption advance an atomic generation immediately; render admits only matching-generation samples. Cancellation may be cooperative but stale output cannot regain admission. Dispose joins the worker before freeing session memory; no timeout frees live handles. Platform owners quiesce callbacks before native destroy. Commands are serialized; double stop and dispose are idempotent. A slow Dart listener has an explicit bounded queue policy and cannot accumulate unbounded events.

Only finalized transcripts call deterministic logic, and its response is admitted with the originating generation. An optional local LLM has capped prompt/context/output and checks cancellation between evaluations. No arbitrary model text executes tools. Full duplex, background continuation and incremental text TTS report unsupported. PCM streaming is reported separately from text streaming and physical qualification.

## Risks

| Risk | Likelihood | Impact | Mitigation | Trigger |
|---|---|---|---|---|
| Assets or binaries unavailable | Medium | Real engine proof blocked | Build adapters against pinned headers and retain explicit missing-input evidence | Download/build or local file failure |
| Device unavailable | High | Acoustic/lifecycle proof blocked | Continue simulator/build/native/Dart verification and publish pending matrix | Device enumeration lacks physical target |
| Non-cooperative inference | Medium | Slow stop | Gate output immediately; wait off UI; never free live memory | Cancellation test delay |
| TTS license obligations | High | Reference pack cannot ship | No bundled weights; inventory exact supplied files | Missing model/license provenance |
| OS audio format differs | High | Invalid inference or playback | Validate negotiated rates and resample outside callbacks | Route changes or unsupported rate |

## Rollback

Keep the original specification and unrelated changes. The implementation adds a new package entry point and platform files; rollback removes only this work item's changes and restores package metadata from the recorded baseline. Imported packs are activated only after validation and older versions remain available. No git, deployment or publication operation is part of rollback or implementation.

## Out of scope

Cloud services, automatic model downloads, model redistribution approval, publication and unqualified claims of acoustic full duplex are excluded. Physical measurements cannot be substituted by host tests. Remaining qualification failures keep this work item open.

## Verification approach

Run the installed Flutter 3.47.0/Dart 3.13.0 toolchain, the wiki linter, native compiler and sanitizer harnesses, plugin builds, and package dry run. Tests exercise missing/corrupt assets, traversal, bounded queue overflow, stale generations, cancellation, late logic, duplicate lifecycle commands and native ownership. Execute real sherpa model fixtures separately from scheduler tests. Preserve command output on disk and distinguish host, simulator, physical and offline evidence. Every acceptance criterion includes a negative case.

## Qualification supplement before freeze

The pinned VITS implementation generates and allocates a sentence before its PCM callback and also accumulates output. Thus the adapter can bound admitted PCM and reply input but cannot claim a hard bound on upstream intermediate synthesis allocations. Record this as a qualification defect, keep incrementalPcm false for this profile, and keep AC-004 open until a measured/model-enforced bound or qualified replacement exists. Implement and test the real adapter without disguising this limitation. Source: v1.12.14 sherpa-onnx/csrc/offline-tts-vits-impl.h, Generate and Process.

The optional llama.cpp source pin resolves through the GitHub tag API to 987498f4592a76897863cf53711dce38380c082b. Native API version is one. Model roles are vad, encoder, decoder, joiner, asrTokens, ttsModel, ttsTokens, ttsLexicon and optional llmModel; manifest also lists license files. Profile is en-US-sherpa-vits, runtime is 1.12.14. First build supports Android API 26 arm64-v8a and iOS 13 arm64, with simulator builds separately identified.
