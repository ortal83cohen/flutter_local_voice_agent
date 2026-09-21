# Implementation review — round 01

- Work item: 0007-android-audio-instrumentation
- Reviewed artifact: current working tree
- Reviewer: impl-review-0007
- Date: 2026-09-21

## Verdict

**FAIL**

AC-002 and AC-003 are unmet: the capture log never reports finite or non-finite status, and native recognition logs omit error events plus sequence and activity.

## Verification performed

Blind review. Criteria, listed implementation files, related tests, and `pubspec.yaml` were read. `STATE.yaml`, `01-plan.md`, `03-tasks.md`, `00-research.md`, and `04-verification.md` were not read. Author claims were not trusted. Commands were run from `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent` after `export PATH="/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH"`.

Source searches covered `FLVA` logs, `debugPrint`, PCM dump sites, file sinks, and network or telemetry additions in `android/`, `native/src/`, `lib/`, `example/lib/`, and `pubspec.yaml`. No `isFinite` / `isfinite` / finite-status token exists under `android/` or `lib/`. No native test mentions `FLVA_NATIVE_LOG` or log boundedness. Plugin `pubspec.yaml` dependencies remain `flutter` (SDK) and `crypto: ^3.0.6`. No new HTTP, analytics, or telemetry package. Capture and recognition logs write to `Log.i("FLVA")`, `__android_log_print(..., "FLVA", ...)`, or `debugPrint`; no audio file sink was found on those paths.

This `lint_wiki.py` run was taken before this report file existed.

### 1. `python3 tool/lint_wiki.py`

Exit 0.

```
lint_wiki: clean (0 warning(s)).
```

### 2. `dart format --set-exit-if-changed lib example/lib test example/test`

Exit 0.

```
Formatted 27 files (0 changed) in 0.13 seconds.
```

### 3. `dart analyze --fatal-infos --fatal-warnings`

Exit 0.

```
Analyzing flutter_local_voice_agent...
No issues found!
```

### 4. `flutter test`

Exit 0. Final line: `00:04 +73: All tests passed!`

Observed Dart instrumentation lines from that run include:

```
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=5
FLVA poll events=2 kinds=final,suspended
FLVA poll events=1 kinds=error
FLVA event kind=error sequence=1 generation=0 activity=idle textLength=0
```

The `late poll response after dispose is ignored` case printed `FLVA poll events=1 kinds=final` and did not print a following `FLVA event kind=...` line. Empty-poll ticks during tests did not print `FLVA poll` lines.

Full command output:

```
Resolving dependencies...
Downloading packages...
  material_color_utilities 0.13.0 (0.13.1 available)
  test_api 0.7.12 (0.7.14 available)
Got dependencies!
2 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Resolving dependencies in `./example`...
Downloading packages...
Got dependencies in `./example`.
00:00 +0: loading /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_catalog_test.dart
00:00 +0: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_catalog_test.dart: exported catalog exactly matches reviewed source inventory and notices
00:00 +1: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/review_regression_test.dart: rejects a correctly hashed unsupported manifest role
00:00 +2: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/review_regression_test.dart: rejects a correctly hashed unsupported manifest role
00:00 +3: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/review_regression_test.dart: rejects a correctly hashed unsupported manifest role
00:00 +4: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/review_regression_test.dart: rejects a correctly hashed unsupported manifest role
00:00 +5: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/platform_refusal_test.dart: excluded target is refused before native create
00:00 +6: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +7: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +8: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +9: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +10: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +11: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +14: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +15: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +15: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
00:00 +16: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +17: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +18: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +18: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:00 +19: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +20: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +21: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +22: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +23: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +24: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +25: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +26: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +27: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +28: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +29: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +30: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +30: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: embedded NUL logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
00:00 +31: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +31: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: embedded NUL logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:00 +32: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +32: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
FLVA poll events=1 kinds=error
FLVA event kind=error sequence=1 generation=0 activity=idle textLength=0
00:00 +33: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +34: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +35: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +35: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:01 +36: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +36: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=5
00:01 +36: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired low surrogate logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
00:01 +37: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +37: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired low surrogate logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:01 +38: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +39: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=14
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
FLVA poll events=1 kinds=final
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=5
00:01 +41: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:01 +42: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +43: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +44: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +45: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +46: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +46: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: 240 supplementary Unicode scalars and 960 UTF-8 bytes are accepted
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=13
00:01 +47: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +47: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: suspension ignores a late logic reply
FLVA poll events=2 kinds=final,suspended
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=5
00:01 +48: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +48: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: interrupt keeps polling and admits the next current final
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=4
00:01 +49: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +49: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: late poll response after dispose is ignored
FLVA poll events=1 kinds=final
00:01 +50: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +51: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +52: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +53: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +54: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: rejects unsafe locations, loops and hop exhaustion without visiting targets
00:01 +55: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:01 +56: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:01 +57: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +58: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +59: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +60: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: cancel interrupts redirected header wait; timeout stays bounded
00:02 +61: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: cancel interrupts redirected header wait; timeout stays bounded
00:02 +62: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: cancel interrupts redirected header wait; timeout stays bounded
00:02 +63: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation cancel before transfer prevents requests and cancel after ready is a no-op
00:02 +64: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety tampered manifest, file, and symlink cache fail integrity offline
00:03 +65: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety does not replace an occupied invalid final destination
00:03 +66: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety rejects and preserves a symlink at the final destination
00:03 +67: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety retains old versions and abandoned stages after a failed update
00:03 +68: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety exact URL and version metadata participate in the fingerprint
00:04 +69: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety file-valued storage root produces typed storage failure
00:04 +70: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety cached asset read permission failure remains typed storage
00:04 +71: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: concurrent callers two managers converge and one cancelled caller cannot delete winner
00:04 +72: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: concurrent callers cross-isolate callers atomically converge on one valid directory
00:04 +73: All tests passed!
```

`flutter test` from the package root executed `test/` only. `example/test/` was not part of that command.

### 5. `flutter devices`

Exit 0. No Android device or emulator was connected. This review does not claim physical-device qualification.

```
Found 2 connected devices:
  macOS (desktop) • macos  • darwin-arm64   • macOS 26.6.2 25G83 darwin-arm64
  Chrome (web)    • chrome • web-javascript • Google Chrome 153.0.8010.52

Checking for wireless devices...

No wireless devices were found.

Run "flutter emulators" to list and start any available device emulators.

If you expected another device to be detected, please run "flutter doctor" to diagnose potential issues. You may also try increasing the time to wait for connected devices with the "--device-timeout" flag. Visit https://flutter.dev/setup/ for troubleshooting tips.
```

Environment blocker for Android device execution: recorded above. Explicitly not required: this work does not prove a physical Android device produces a transcript.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | `android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt:90` start log; `:136` format log; `:151` capture-progress log without `pcm` contents. `android/src/main/cpp/bridge.cpp:55` logs pointer, frame count, and result only. | yes |
| AC-002 | fail | `FlutterLocalVoiceAgentPlugin.kt:145-151` logs `frames`, `meanAbs`, `peak`, and `pushResult` on a 1000 ms gate (`:151`). No finite or non-finite field. `android/` and `lib/` contain no `isFinite` / `isfinite`. `bridge.cpp:55` rejection log does not name the reject reason. No capture-log test exists under `test/` or `example/test/`. | no |
| AC-003 | fail | `native/src/flva.cpp:297` and `:308` log `generation` and `length` for partial and final only. `flva.cpp:265`, `:315`, `:329`, `:352`, `:369`, `:370` publish `error` with no `FLVA_NATIVE_LOG`. Sequence and activity are absent from native log lines. `FLVA_NATIVE_LOG` is a no-op off Android (`flva.cpp:25`). Native tests under `native/tests/` contain no log assertions. Dart `lib/src/agent.dart:428` does log kind, sequence, generation, activity, and `textLength`; that is outside the native check path named by this criterion. | no |
| AC-004 | pass | `lib/src/agent.dart:330-333` logs poll batch size and kinds only when `values.isNotEmpty`. `agent.dart:427-429` logs transcript delivery as kind plus `textLength`, not text. `example/lib/voice_screen_controller.dart:520-522` logs UI delivery as kind, activity, and `textLength`. `flutter test` showed empty-poll silence, `textLength=0` on error, and dispose-late poll without an event-delivery line. | yes |
| AC-005 | pass | Commands 1–4 exited 0. Command 5 recorded no Android device. No device qualification is claimed. | yes |
| NFR-001 | pass | `pubspec.yaml:26-29` lists only `flutter` and `crypto`. Capture buffers stay in memory (`FlutterLocalVoiceAgentPlugin.kt:141-151`). Logs go to logcat or `debugPrint`, not a file sink. No new network or telemetry package or sink was found on the inspected instrumentation paths. | yes |

AC-001 negative case: every `log(` / `FLVA_LOG` / `FLVA_NATIVE_LOG` / `debugPrint('FLVA` site was read; none interpolates a PCM array or full audio buffer.

AC-005 negative case: `flutter devices` listed only `macos` and `chrome`. This report does not treat that as Android qualification.

NFR-001 negative case: plugin `pubspec.yaml` adds no HTTP, analytics, or telemetry dependency; no fopen/File write of capture PCM was found on the Android or native log paths.

## Findings

### F-001 — Capture logs omit finite or non-finite status

- Severity: BLOCKER
- Location: `android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt:151`
- Criterion affected: AC-002
- Observation: The rate-limited capture line reports `reads`, `frames`, `pushed`, `lastFrames`, `meanAbs`, `peak`, and `pushResult`. The loop at `:145-146` uses `abs` only. There is no finite count, finite flag, or non-finite flag. A NaN sample does not raise `peak` (`NaN > peak` is false) and can leave `peak` finite while `meanAbs` becomes NaN, so the existing statistics are not a substitute for finite status. `bridge.cpp:55` logs rejected `nativePush` without distinguishing non-finite input from a null pointer, a failed session, or overflow. No test under `test/` or `example/test/` asserts capture log fields or the one-line-per-second cap.
- Why it matters: AC-002 requires frame counts, finite/non-finite status, bounded signal statistics, and `nativePush` outcomes at a rate-limited interval. Finite status is missing, and the named test check was not present.

### F-002 — Native recognition logs omit error, sequence, and activity

- Severity: BLOCKER
- Location: `native/src/flva.cpp:297`
- Criterion affected: AC-003
- Observation: Partial and final native lines are `asr partial generation=%llu length=%zu` and `asr final generation=%llu length=%zu` (`flva.cpp:297`, `:308`). They do not include sequence or activity. VAD onset at `:257` logs generation only. Every `publish("error", ...)` site (`flva.cpp:265`, `:315`, `:329`, `:352`, `:369`, `:370`) has no `FLVA_NATIVE_LOG`. Off Android, `FLVA_NATIVE_LOG` is `((void)0)` (`flva.cpp:25`), so host native tests cannot observe these lines. `native/tests/` has no assertion that empty or oversized text stays bounded in logs. Dart `agent.dart:428` logs the required fields after poll; AC-003 is checked by native source review and native tests, not by that Dart path.
- Why it matters: AC-003 requires logs that identify event kind, generation/sequence, activity, and bounded text metadata when native recognition changes state or emits `partial`, `final`, or `error`. Error is unlogged on the native path, and the native lines that exist omit required fields.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | implement |
| F-002 | implement |
