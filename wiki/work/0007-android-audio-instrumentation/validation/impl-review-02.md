# Implementation review — round 02

- Work item: 0007-android-audio-instrumentation
- Reviewed artifact: current working tree
- Reviewer: impl-review-0007-02
- Date: 2026-09-21

## Verdict

**PASS**

Every frozen criterion AC-001 through AC-005 and NFR-001 is met. The two round-01 blockers are closed in source: capture logs now report finite and non-finite counts, and native `publish` logs kind, sequence, generation, activity, and bounded `textLength` for `partial`, `final`, `error`, and state events.

## Verification performed

Blind confirmation review. Criteria, listed implementation files, related tests, `native/include/flva.h`, `example/lib/voice_screen_controller.dart`, and `pubspec.yaml` were read. `STATE.yaml`, `01-plan.md`, `03-tasks.md`, `00-research.md`, and `04-verification.md` were not read. Author claims were not trusted. Commands were run from `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent` after `export PATH="/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH"`.

Source searches covered `FLVA` logs, `debugPrint`, PCM dump sites, file sinks, and network or telemetry additions in `android/`, `native/src/`, `lib/`, `example/lib/`, and `pubspec.yaml`. Capture logs now include `finite=` and `nonFinite=`. Native `publish` now emits one `FLVA_NATIVE_LOG` line with kind, sequence, generation, activity, and `textLength`. Plugin `pubspec.yaml` dependencies remain `flutter` (SDK) and `crypto: ^3.0.6`. No new HTTP, analytics, or telemetry package. Capture and recognition logs write to `Log.i("FLVA")`, `__android_log_print(..., "FLVA", ...)`, or `debugPrint`; no audio file sink was found on those paths.

This `lint_wiki.py` run was taken before this report file existed.

### 1. `python3 tool/lint_wiki.py`

Exit 0.

```
lint_wiki: clean (0 warning(s)).
```

### 2. `dart format --set-exit-if-changed lib example/lib test example/test`

Exit 0.

```
Formatted 27 files (0 changed) in 0.15 seconds.
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
00:00 +1: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_catalog_test.dart: catalog exposes three English options with distinct speaker counts
00:00 +2: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_catalog_test.dart: catalog choices and trusted metadata cannot be mutated
00:00 +3: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +4: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +5: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +6: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +7: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +8: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +9: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +10: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +11: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:00 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:00 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: embedded NUL logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
00:00 +14: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +14: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: embedded NUL logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:01 +15: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +16: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +17: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +18: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +19: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +20: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +21: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +21: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
00:01 +22: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +23: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +24: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +25: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +25: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
00:01 +26: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +26: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:01 +27: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +28: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +29: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +30: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +31: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +32: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +33: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +33: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired low surrogate logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=12
00:01 +33: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
FLVA poll events=1 kinds=error
FLVA event kind=error sequence=1 generation=0 activity=idle textLength=0
00:01 +34: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +34: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired low surrogate logic reply faults and permits the next turn
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:01 +35: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +36: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +36: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=14
00:01 +37: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +37: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=5
00:01 +37: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=9
00:01 +38: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +39: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: 240 supplementary Unicode scalars and 960 UTF-8 bytes are accepted
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=13
00:01 +41: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +42: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +43: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +43: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=5
00:01 +44: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: default rejects; opt-in follows all supported redirects and relative targets
00:01 +45: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:01 +46: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:01 +47: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:01 +47: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: suspension ignores a late logic reply
FLVA poll events=2 kinds=final,suspended
FLVA event kind=final sequence=1 generation=0 activity=thinking textLength=5
00:02 +48: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +48: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: interrupt keeps polling and admits the next current final
FLVA poll events=1 kinds=final
FLVA event kind=final sequence=2 generation=1 activity=thinking textLength=4
00:02 +49: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +49: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: late poll response after dispose is ignored
FLVA poll events=1 kinds=final
00:02 +50: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +51: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +52: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +53: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +54: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +55: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +56: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +57: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +58: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +59: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +60: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: cancel interrupts redirected header wait; timeout stays bounded
00:02 +61: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: cancel interrupts redirected header wait; timeout stays bounded
00:02 +62: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: cancel interrupts redirected header wait; timeout stays bounded
00:03 +63: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_redirect_test.dart: cancel interrupts redirected header wait; timeout stays bounded
00:03 +64: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety tampered manifest, file, and symlink cache fail integrity offline
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
```

Environment blocker for Android device execution: recorded above. Explicitly not required: this work does not prove a physical Android device produces a transcript.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | `FlutterLocalVoiceAgentPlugin.kt:90` start log; `:136` format log; `:164` capture-progress log without `pcm` contents. `bridge.cpp:55` logs pointer, frame count, and result only. | yes |
| AC-002 | pass | `FlutterLocalVoiceAgentPlugin.kt:145-155` counts `finite` and `nonFinite`; `:161-164` logs `frames`, `finite`, `nonFinite`, `meanAbs`, `peak`, and `pushResult` on a first-read or 1000 ms gate. `bridge.cpp:55` logs rejected `nativePush`. | yes |
| AC-003 | pass | `flva.cpp:217-245` `publish` logs `kind`, `sequence`, `generation`, `activity`, and `textLength` for every queued event, including the coalesce path at `:224-228`. `publish("error", ...)` sites at `:276`, `:325`, `:339`, `:362`, `:379`, `:380` now take that path. Text is truncated by `copy_text` into `FlvaEvent.text[2048]` (`flva.h:23`) and measured with `strnlen(..., sizeof(event.text))`. | yes |
| AC-004 | pass | `lib/src/agent.dart:330-333` logs poll batch size and kinds only when `values.isNotEmpty`. `agent.dart:427-429` logs transcript delivery as kind plus `textLength`, not text. `example/lib/voice_screen_controller.dart:520-522` logs UI delivery as kind, activity, and `textLength`. `flutter test` showed empty-poll silence, `textLength=0` on error, and dispose-late poll without an event-delivery line. | yes |
| AC-005 | pass | Commands 1–4 exited 0. Command 5 recorded no Android device. No device qualification is claimed. | yes |
| NFR-001 | pass | `pubspec.yaml:26-29` lists only `flutter` and `crypto`. Capture buffers stay in memory (`FlutterLocalVoiceAgentPlugin.kt:141-164`). Logs go to logcat or `debugPrint`, not a file sink. No new network or telemetry package or sink was found on the inspected instrumentation paths. | yes |

AC-001 negative case: every `log(` / `FLVA_LOG` / `FLVA_NATIVE_LOG` / `debugPrint('FLVA` site was read; none interpolates a PCM array or full audio buffer.

AC-002 negative case: the capture loop logs only when `captureReads==1L` or `now-lastCaptureLog>=1000L` (`FlutterLocalVoiceAgentPlugin.kt:161`). Non-finite samples increment `nonFinite` and are excluded from `meanAbs` and `peak`.

AC-003 negative case: empty text logs `textLength=0`. Oversized text is truncated into `event.text` before the log line; the length argument is bounded by `sizeof(event.text)`. `FLVA_NATIVE_LOG` remains a no-op off Android (`flva.cpp:25`), so host native tests cannot observe these lines; the bound is established by source review of `copy_text` and `strnlen`.

AC-004 negative case: empty polls do not print `FLVA poll`. A dispose-late poll printed a batch line and did not print `FLVA event kind=...`.

AC-005 negative case: `flutter devices` listed only `macos` and `chrome`. This report does not treat that as Android qualification.

NFR-001 negative case: plugin `pubspec.yaml` adds no HTTP, analytics, or telemetry dependency; no fopen/File write of capture PCM was found on the Android or native log paths.

## Findings

None.

## Recurrence check

- Previous round: `wiki/work/0007-android-audio-instrumentation/validation/impl-review-01.md`
- Recurring findings: none
- Oscillating: no

Previous F-001 (capture logs omitted finite or non-finite status) did not recur. `FlutterLocalVoiceAgentPlugin.kt:145-164` now counts and logs `finite` and `nonFinite`.

Previous F-002 (native recognition logs omitted error, sequence, and activity) did not recur. `flva.cpp:241-245` logs kind, sequence, generation, activity, and `textLength` on every `publish`, including `error`.

## Routing

| Finding | Belongs to phase |
|---|---|
| none | — |
