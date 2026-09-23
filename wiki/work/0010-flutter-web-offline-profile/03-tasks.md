# Tasks: Flutter web offline voice profile

## Start conditions

Criteria AC-001 through AC-018 are frozen. Group 1 may begin. Preserve unrelated dirty files. Do not commit or publish.

## Legend

- `[P]` — may run in a parallel subagent. Only mark a task `[P]` if no other `[P]` task in the same group touches any of the same files.
- Every task cites the criteria it satisfies. A task satisfying no criterion does not belong here.
- Owned files are exclusive. Two tasks never list the same file.

## Groups

### Group 1 — Compile seam and host selection

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | Split dart:io out of the agent, model store and model preparation with conditional imports. Keep FileModelStore on native. Add compile-only web stubs and import barrels so analyze accepts a web target. Those stubs do not implement compact-pack hash policy. Add an internal session-backend choice so web does not call method-channel create. Keep fuchsia refusal. Add tests for web-allowed create against a fake backend, fuchsia refusal, full-duplex refusal and useLocalLlm refusal. | AC-001, AC-002, AC-003, AC-007, AC-008 | lib/src/agent.dart, lib/src/contracts.dart, lib/src/model_store.dart, lib/src/model_preparation.dart, conditional import barrels and io implementations plus web compile stubs those modules require, test/platform_refusal_test.dart, new web-profile tests owned by this task | | Analyze accepts a web target; fuchsia still refuses; a fake web create does not call native create; format and analyze pass. Status: done 2026-09-22. |

### Group 2 — WASM pin and web model store

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 2.1 | Vendor and pin sherpa-onnx 1.13.8 web WASM runtime assets with SHA-256 verification and an Apache-2.0 notice. Add package web as the only new library dependency. Register this package's own web implementation in the plugin manifest without adding sherpa_onnx, sherpa_onnx_web or record. Fail create with invalidAsset on digest mismatch before microphone use. | AC-004, AC-005, AC-017, AC-018 | pubspec.yaml, vendored WASM asset paths and notice file this task adds, any pin helper next to those assets | | pubspec.yaml has package web and no third-party speech plugin; the web platform key points at this package; mismatch test loads nothing; catalog weights are absent from the plugin package. Status: done 2026-09-22. |
| 2.2 | Implement the production web model store that hash-checks compact-pack files from bundled example assets or a private origin store, accepts manifest runtime 1.12.14, maps missing and bad hashes to missingAsset and invalidAsset, and never requests the microphone. Assign that store to the Group 1 omitted-default hook from this library. This library is not the Group 1 compile stub. | AC-006 | the new production web model-store library this task adds, tests for empty and tampered packs | `[P]` | Empty and tampered packs fail before getUserMedia. The omitted web create default uses this store, not the compile stub. Status: done 2026-09-22. |

### Group 3 — Web backend

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 3.1 | Implement the web session backend: load pinned WASM off the UI thread, run Silero VAD, one offline recognizer and VITS, own getUserMedia and Web Audio, enforce secure context, map permission denial, keep half-duplex admission, honor interrupt, emit existing agent events without PCM, and log no samples. Import the Group 2 production web model store so the omitted create default is that store. | AC-009, AC-010, AC-011, AC-012, AC-013, AC-016 | new web backend, audio owner, WASM binding libraries, their tests | | Denial and insecure-context paths fail typed; events have no sample fields; interrupt stops playback; logs have no PCM. Status: done 2026-09-22. Compact-catalog WASM load and a live browser microphone session remain [UNVERIFIED]. |

### Group 4 — Example web host

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 4.1 | Add the example web storage and UI path for the compact catalog pack only. Keep native example storage on dart:io. Do not enable Start until validation succeeds. Build the example for web. | AC-014 | example/lib/model_storage.dart, example/lib/voice_screen_controller.dart, example/lib/main.dart, example/web files this task must add, example/pubspec.yaml | | flutter build web exits 0 with pasted output; Start stays disabled without a validated compact pack. Status: done 2026-09-22. |

### Group 5 — Native honesty and documentation

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 5.1 | Update capabilities, README, analysis inclusions, the platform-coverage product note and the wiki index. Accept the web architecture decision. Confirm native plugins still own flva audio and that 0002 blockers remain open. | AC-015 | doc/capabilities.md, README.md, analysis_options.yaml, example/analysis_options.yaml, wiki/INDEX.md, wiki/product/reasonable-platform-coverage.md, wiki/product/flutter-web-offline-profile.md, wiki/adr/0005-flutter-web-offline-profile.md | | Docs name web as a separate WASM profile; native hosts stay on flva; 0002 blockers remain open. Status: done 2026-09-22. |

## Serialised files

| File | Owning task |
|---|---|
| lib/src/agent.dart | 1.1 |
| lib/src/contracts.dart | 1.1 |
| lib/src/model_store.dart | 1.1 |
| lib/src/model_preparation.dart | 1.1 |
| pubspec.yaml | 2.1 |
| example/lib/model_storage.dart | 4.1 |
| wiki/INDEX.md | 5.1 |
| doc/capabilities.md | 5.1 |

## Test tasks

| # | Covers | Positive case | Negative case |
|---|---|---|---|
| T1 | AC-001 | Web create uses the web backend | Native method-channel create is called |
| T2 | AC-002 | fuchsia throws unsupportedProfile | Session create runs |
| T3 | AC-003 | Web analyze has no dart:io on the web graph | A web-imported file imports dart:io |
| T4 | AC-004 | pubspec.yaml has this package's web implementation only | sherpa_onnx, sherpa_onnx_web or record is a library dependency |
| T5 | AC-005 | Bad WASM digest fails create | Microphone is requested |
| T6 | AC-006 | Missing or bad model hash fails create | Microphone is requested |
| T7 | AC-007 | useLocalLlm on web throws unsupportedProfile | A web LLM session starts |
| T8 | AC-008 | Full duplex on web throws unsupportedProfile | A full-duplex session starts |
| T9 | AC-009 | Insecure context throws unsupportedProfile | Capture starts |
| T10 | AC-010 | Denied microphone returns permissionDenied | Capture or playback starts |
| T11 | AC-011 | Agent events have no PCM fields | A public event carries samples |
| T12 | AC-012 | Finalized VAD turn calls logic and speaks | Listen is admitted during speaking |
| T13 | AC-013 | Interrupt flushes playback and returns to listening or idle | Cancelled audio is played |
| T14 | AC-014 | Example flutter build web exits 0 | Success claimed without output |
| T15 | AC-015 | 0002 blockers still open; native plugins unchanged in audio ownership | A 0010 document closes those gates |
| T16 | AC-016 | Web logs omit PCM | Frame values printed |
| T17 | AC-017 / AC-018 | Plugin ships pinned WASM plus notice only | Catalog weights or unattributed WASM appear |
