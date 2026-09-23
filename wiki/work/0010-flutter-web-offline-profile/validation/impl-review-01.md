# Implementation review — round 01

- Work item: 0010-flutter-web-offline-profile
- Reviewed artifact: working tree implementation under `lib/`, `example/`, `pubspec.yaml`, `test/`, `doc/capabilities.md`, `README.md`, `wiki/product/`, `wiki/adr/0005-flutter-web-offline-profile.md`, and `wiki/work/0010-flutter-web-offline-profile/04-verification.md`
- Reviewer: blind implementation validator
- Date: 2026-09-22

## Verdict

**PASS**

AC-001 through AC-018 are met by the inspected code, the tests re-run here, and `04-verification.md`. Live browser microphone capture and a compact-catalog WASM load were not run and are not counted as passes. Parent 0002 blockers stay open.

## Verification performed

Working directory: `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent`. Commands were run by this reviewer. Author claims in `04-verification.md` were not treated as evidence.

### 1. `python3 tool/lint_wiki.py`

```text
lint_wiki: clean (0 warning(s)).
LINT_EXIT:0
```

### 2. `dart format --output=none --set-exit-if-changed lib example/lib`

```text
Formatted 37 files (0 changed) in 0.10 seconds.
FORMAT_EXIT:0
```

### 3. `dart analyze --fatal-infos --fatal-warnings`

```text
Analyzing flutter_local_voice_agent...
No issues found!
ANALYZE_EXIT:0
```

### 4. `flutter test`

```text
00:05 +98: All tests passed!
ROOT_TEST_EXIT:0
```

### 5. `flutter test` (cwd `example`)

```text
00:00 +26: All tests passed!
EXAMPLE_TEST_EXIT:0
```

### 6. `dart analyze --fatal-infos --fatal-warnings` (cwd `example`)

```text
Analyzing example...
No issues found!
EXAMPLE_ANALYZE_EXIT:0
```

### 7. `flutter build web` (cwd `example`)

```text
Compiling lib/main.dart for the Web...                             19.1s
✓ Built build/web
BUILD_WEB_EXIT:0
```

The build also printed a Wasm dry-run hint and a Cupertino icon-font note. The process still exited 0.

### 8. Pin, package layout, web import graph, native diff

```text
NOTICE True
LICENSE True
onnx_files none
sherpa-onnx-wasm-web.wasm match e0d84744c39a28121f7738a161a21612788f4e8f07879a7224e74919e9831573 bytes 15133855
sherpa-onnx-wasm-web.js match 28f909145d93018c90c181035a008880ceaa94a72b66603dc7bb7c619714c23c bytes 93039
sherpa-onnx-asr.js match d51ae8e8b756ee5e53423ffada0c9702973f154f561aca7984fe0b12f4060178 bytes 53867
sherpa-onnx-tts.js match b9cb4782010b22d64be31298a3e407170d2b8f5def471ea6011c42a921577e8f bytes 33227
sherpa-onnx-vad.js match 893f01168d529add8318c0a6055cf725e788585fda9b81722564a8c3c3f60e34 bytes 7772
web_graph_files 30
web_graph_dart_io none
```

`git diff --stat -- android ios macos windows linux` printed no paths. Exit 0.

`wiki/work/0002-native-offline-pipeline/STATE.yaml` blockers, read by this reviewer, are still:

- F3 / AC-004: VITS allocates an entire sentence before callback; hard synthesis allocation bound not established.
- AC-005 / AC-008: physical mobile offline, audio, lifecycle and performance qualification unavailable.
- AC-007: native binaries and provisioning tools are excluded from the pub payload; clean consumer installation remains unqualified. Final dirty-checkout dry run exits 65 with one warning.

This review does not close those blockers.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | Web create takes `_createWeb` and does not call method-channel create (`lib/src/agent.dart:55`). `test/web_profile_test.dart:13` asserts web `createCount` is 1 and the stub native `created` flag stays false (`test/web_profile_test.dart:27`). | yes — native create stays false on a valid web setup |
| AC-002 | pass | Fuchsia is refused in `_refuseUnsupportedNativeHost` with `unsupportedProfile` before native create (`lib/src/agent.dart:611`). `test/platform_refusal_test.dart:15` expects that code and both create counts stay 0 (`test/platform_refusal_test.dart:38`). | yes — fuchsia does not call native or web create and does not throw `inferenceFailed` |
| AC-003 | pass | Agent, model store, and model preparation select io implementations only when `dart.library.io` is present (`lib/src/agent.dart:11`, `lib/src/model_store.dart:1`, `lib/src/model_preparation.dart:1`). `dart:io` imports in `lib/` are only `lib/src/native_paths_io.dart:1`, `lib/src/model_store_io.dart:2`, and `lib/src/model_preparation_io.dart:3`. The web-resolved import walk reported `web_graph_dart_io none`. `flutter build web` exited 0. | yes — a web-imported `dart:io` file was searched for and not found |
| AC-004 | pass | Dependencies are `flutter`, `flutter_web_plugins`, `crypto`, and `web` (`pubspec.yaml:26`). Platforms remain android, ios, macos, windows, linux, plus web `pluginClass: FlutterLocalVoiceAgentWeb` and `fileName: flutter_local_voice_agent_web.dart` (`pubspec.yaml:41`). `test/wasm_pin_test.dart:26` rejects `sherpa_onnx`, `sherpa_onnx_web`, and `record`. | yes — the dependency scan fails if those plugins appear |
| AC-005 | pass | A digest mismatch throws `invalidAsset` before any return (`lib/src/wasm_pin.dart:33`). Web create runs that guard before `ensureCreated` (`lib/src/agent.dart:125`). Microphone request is in `start`, not create (`lib/src/web_backend.dart:47`). `test/wasm_pin_test.dart:79` uses a wrong digest, expects `invalidAsset`, and asserts backend `createCount` is 0 (`test/wasm_pin_test.dart:103`). | yes — create fails and the session backend, which is what would call `getUserMedia`, is not opened |
| AC-006 | pass | A missing manifest throws `missingAsset` (`lib/src/web_model_store.dart:52`). A hash mismatch throws `invalidAsset` (`lib/src/web_model_store.dart:136`). `test/web_model_store_test.dart:14` covers an empty reader, `:33` a tampered digest, and `:82` and `:110` fail create before backend `ensureCreated`. | yes — empty and tampered packs fail with `missingAsset` or `invalidAsset` and `createCount` stays 0 |
| AC-007 | pass | `useLocalLlm` throws `unsupportedProfile` inside `_createWeb` before store validation and backend create (`lib/src/agent.dart:113`). `test/web_profile_test.dart:32` asserts that code, web `createCount` 0, and native `created` false (`test/web_profile_test.dart:56`). | yes — no web LLM session and no native create |
| AC-008 | pass | `fullDuplexRequired` throws `unsupportedProfile` before the web branch (`lib/src/agent.dart:41`). `test/web_profile_test.dart:60` asserts that code and both create counts stay 0 (`test/web_profile_test.dart:84`). | yes — a full-duplex web session does not start |
| AC-009 | pass | `start` throws `unsupportedProfile` when `isSecureContext` is false, before `requestMicrophone` and `startCapture` (`lib/src/web_backend.dart:40`). Production capture also refuses a non-secure context (`lib/src/web_audio_web.dart:29`). `test/web_backend_test.dart:10` expects that code and `captureStarted` false (`test/web_backend_test.dart:29`). | yes — capture does not start |
| AC-010 | pass | `getUserMedia` failure throws `permissionDenied` and clears the stream (`lib/src/web_audio_web.dart:43`). `start` calls `requestMicrophone` before `startCapture` (`lib/src/web_backend.dart:47`). `test/web_backend_test.dart:34` expects `permissionDenied`, `captureStarted` false, and `played` empty (`test/web_backend_test.dart:53`). | yes — denial starts neither capture nor playback |
| AC-011 | pass | Capture builds 16 kHz mono frames of 512 samples (`lib/src/web_audio_web.dart:22`) and the worker feeds them to Silero via `vad.acceptWaveform` (`lib/src/web_wasm_runtime_web.dart:302`). Session events carry sequence, generation, kind, activity, and optional text only (`lib/src/web_backend.dart:140`). `AgentEvent` has no sample field (`lib/src/models.dart:182`). `test/web_backend_test.dart:58` and `:89` reject PCM keys on the public event and the polled map. Method-channel create arguments are paths, mode, and speaker id (`lib/src/agent.dart:742`). | yes — polled web events omit `pcm` and `samples` |
| AC-012 | pass | A finalized transcript is queued as `final` (`lib/src/web_backend.dart:137`). The agent calls `LocalReplyLogic` on that kind (`lib/src/agent.dart:497`) and then `reply`. Reply synthesizes and plays (`lib/src/web_backend.dart:103`). Production synthesis is VITS `tts.generate` (`lib/src/web_wasm_runtime_web.dart:325`). Admission is closed while speaking (`lib/src/web_backend.dart:126`). `test/web_backend_test.dart:75` emits one final, holds playback, and keeps `framesAccepted` at 1 after a second frame (`test/web_backend_test.dart:95`). | yes — a second frame during speaking is not admitted |
| AC-013 | pass | Interrupt increments generation, invalidates inference, flushes playback, and emits listening or idle (`lib/src/web_backend.dart:66`). Playback `stop` drops the current source (`lib/src/web_audio_web.dart:142`). A generation mismatch returns before or after play without keeping the audio (`lib/src/web_backend.dart:104`). `test/web_backend_test.dart:102` expects `flushed`, empty `played`, and last activity `listening` (`test/web_backend_test.dart:115`). | yes — cancelled audio is not recorded after interrupt |
| AC-014 | pass | `flutter build web` from `example/` printed `✓ Built build/web` and `BUILD_WEB_EXIT:0`. Start stays off until setup is `ready` and a session exists (`example/lib/voice_screen_controller.dart:160`). | yes — success was accepted only with this reviewer's exit code |
| AC-015 | pass | Native plugin diff is empty. Audio on those hosts remains in the native plugins (`android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt:141`, `native/src/flva.cpp:256`). 0002 blockers remain the three OPEN entries in `wiki/work/0002-native-offline-pipeline/STATE.yaml:10`. 0010 records them OPEN (`doc/capabilities.md:92`, `README.md:66`, `wiki/product/reasonable-platform-coverage.md:49`, `04-verification.md:98`). | yes — no 0010 document reviewed here says those gates are closed, and the native diff does not add a Dart PCM path |
| AC-016 | pass | Web session logs are frame counters (`lib/src/web_backend.dart:128`, `lib/src/web_backend.dart:132`). Agent poll logs kind names and text length (`lib/src/agent.dart:394`, `lib/src/agent.dart:490`). The example UI log is kind, activity, and text length (`example/lib/voice_screen_controller.dart:548`). The worker source does not print frame arrays. | yes — those log sites were searched and do not print sample values or a waveform |
| AC-017 | pass | Plugin assets are the five pinned WASM and JS files (`pubspec.yaml:56`). Package search found no `.onnx` files. `test/wasm_pin_test.dart:44` asserts the assets tree has no `.onnx`. Notices live under `third_party/sherpa_onnx_web/`. | yes — an `.onnx` weight under plugin assets would fail the layout search |
| AC-018 | pass | Apache-2.0 `LICENSE` and `NOTICE` name the five assets and the upstream archive (`third_party/sherpa_onnx_web/NOTICE:1`). Pins are in `lib/src/wasm_pin.dart:7`. This reviewer hashed the five files and each digest matched the pin. Mismatch throws before the bytes are returned (`lib/src/wasm_pin.dart:33`, `lib/src/web_wasm_assets.dart:19`) and create does not open the backend (`test/wasm_pin_test.dart:103`). | yes — a wrong digest does not return bytes and does not boot the session |

## Findings

None.

## Residual risks

- A browser microphone-to-speaker session was not run. `04-verification.md:111` marks it `[UNVERIFIED]`. This review does not treat that gap as a pass.
- A compact-catalog Zipformer plus VITS load in sherpa-onnx 1.13.8 WASM was not run. `04-verification.md:110` marks it `[UNVERIFIED]`. Wrapper call shapes in the vendored JS match the worker source, and that is not a load of catalog weights.
- `flutter build web` is a compile. Safari was not launched. The frozen criteria allow that gap to stay recorded.
- Parent 0002 VITS allocation, physical mobile qualification, and clean consumer-install remain OPEN in `wiki/work/0002-native-offline-pipeline/STATE.yaml:10`. This review does not close them.

## Open questions

- Whether `createVad`, `OfflineRecognizer`, and `createOfflineTts` accept this repository's compact catalog bytes inside sherpa-onnx 1.13.8 WASM is unanswered here, because that load was not run.
- Whether a secure-context browser grants the microphone, plays VITS audio, and returns to listening after interrupt is unanswered here, because that session was not run.

## Recurrence check

- Previous round: none — first implementation review
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| None |  |
