# Verification: Reasonable platform coverage

Commands ran on 2026-09-21 from `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent` unless a directory is named. Flutter and Dart are `/Users/ortalcohen/fvm/versions/3.47.0`. This record pastes command output. It does not close work item 0002.

## Host

```text
$ flutter --version
Flutter 3.47.3 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 68c3e597a2 (6 days ago) • 2026-09-15 18:13:12 -0700
Engine • hash 14500179362846c01134680b37c7c64c17652a17 (revision 1436d132c6) (6 days ago) • 2026-09-15 21:28:00.000Z
Tools • Dart 3.13.3 • DevTools 2.50.2

$ flutter devices
Found 2 connected devices:
  macOS (desktop) • macos  • darwin-arm64  • macOS 26.3 25D125 darwin-arm64
  Chrome (web)    • chrome • web-javascript • Google Chrome 143.0.7499.193

No wireless devices were found.

Device macos is not supported for Flutter web.
If you would prefer that this device was supported, run: flutter config --enable-web

Run "flutter emulators" to list and start any available device emulators.

If you expected another device to be detected, please run "flutter doctor" to diagnose potential issues. You may also try increasing the time to wait for connected devices with the "--device-timeout" flag. Visit https://flutter.dev/setup/ for troubleshooting tips.
```

No Android emulator or iPhone is attached. Windows and Linux Flutter builds are not claimed on this Mac.

## Wiki lint

```text
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
WIKI_EXIT:0
```

## Format and analyzer

`dart format --set-exit-if-changed lib example/lib test example/test` first exited 1 because `test/agent_test.dart` needed a format pass. After `dart format test/agent_test.dart`:

```text
$ dart format --set-exit-if-changed lib example/lib test example/test
Formatted 20 files (0 changed) in 0.21 seconds.
FORMAT_RECHECK:0

$ dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
ANALYZE_PKG_EXIT:0

$ dart analyze --fatal-infos --fatal-warnings
Analyzing example...
No issues found!
ANALYZE_EX_EXIT:0
```

The example analyze command ran with working directory `example/`.

## Tests

```text
$ flutter test
00:03 +72: All tests passed!
TEST_PKG_EXIT:0

$ flutter test
00:01 +26: All tests passed!
TEST_EX_EXIT:0
```

The example test command ran with working directory `example/`. Package coverage includes `test/platform_refusal_test.dart` (web and fuchsia refuse with `unsupportedProfile` and native create stays at zero).

Native deterministic helpers:

```text
$ c++ -std=c++17 -I native/src native/tests/test_spsc_ring.cpp -o /tmp/flva-spsc-ring && /tmp/flva-spsc-ring
spsc_ring ok

$ c++ -std=c++17 -I native/src native/tests/test_resampler.cpp -o /tmp/flva-resampler && /tmp/flva-resampler
resampler ok

$ c++ -std=c++17 -I native/llm native/llm/utf8_test.cpp -o /tmp/flva-utf8 && /tmp/flva-utf8
utf8 tests passed
HELPER_EXIT:0
```

## Provisioning

Pinned official macOS archive remains at `/private/tmp/flva-qualification/downloads/sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2`. Unit tests use in-process digest overrides, not those official archive hashes:

```text
$ python3 tool/test_provision_runtime.py
PASS dest-for macos
PASS dest-for windows
PASS dest-for linux
PASS digest override copies matching fixture and skips a mismatch
PASS CLI mismatch copies nothing and exits 1
test_provision_runtime: ok
PROVISION_TEST_EXIT:0
```

`tool/provision_runtime.py` dest folders are `macos/libs`, `windows/libs`, `linux/libs`. A digest mismatch exits non-zero and copies nothing.

## macOS example build

```text
$ flutter build macos --debug
Building macOS application...
✓ Built build/macos/Build/Products/Debug/flutter_local_voice_agent_example.app
MACOS_BUILD_EXIT:0
```

The build printed an SPM warning and completed with exit 0. An earlier example run produced macOS plugin logs with counters, RMS and permission lines only. Those logs did not print raw PCM frame values.

## Git-free snapshot check

Snapshot `/private/tmp/flva-verify-snapshot-0008-0009` was copied from `git ls-files --cached --others --exclude-standard` with no `.git` metadata. `PATH` used Flutter 3.47.0.

```text
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Stage 3 passed: format
Stage 4 passed: analysis
00:06 +72: All tests passed!
00:01 +26: All tests passed!
Stage 5 passed: tests
Package has 0 warnings and 1 hint.
Stage 6 passed: package dry run
PASS bump patch positive case
PASS missing pubspec
PASS missing changelog
PASS malformed package version
PASS malformed occupied version
PASS duplicate changelog version
PASS occupied candidate skipped
PASS occupied pub.dev versions positive and malformed-response negative cases
Stage 7 passed: release helper tests
CHECK_EXIT:0
```

The dry-run hint is that published 0.1.2 is newer than this checkout's 0.1.1. Stage 6 still passed.

## pubspec platforms

`pubspec.yaml` declares `android`, `ios`, `macos`, `windows` and `linux`. It does not declare a web plugin.

## Per-criterion results

| ID | Result | Evidence | Negative case |
|---|---|---|---|
| AC-001 | met | `test/platform_refusal_test.dart` and `lib/src/agent.dart` `_refuseUnsupportedHost`. Web and fuchsia throw `unsupportedProfile` with native create count 0. MissingPluginException maps to the same code. | A create that reached the channel would fail those tests. |
| AC-002 | met | `pubspec.yaml` plugin platforms: android, ios, macos, windows, linux. No web key. | A missing desktop key or a web plugin key is absent. |
| AC-003 | met | `tool/test_provision_runtime.py` mismatch copies nothing and CLI exits 1. | A mismatched archive that still copied a library would fail that test. |
| AC-004 | met | Script dests are `macos/libs`, `windows/libs`, `linux/libs`. Official macOS archive is present at the path above. Unit tests prove matching-fixture copy. | A success with missing expected library names is not observed in the unit tests. |
| AC-005 | met by source review | `macos/Classes/FlutterLocalVoiceAgentPlugin.mm` calls `flva_push` and `flva_render` on audio callbacks. Channel name is `flutter_local_voice_agent`. Method arguments are paths, speaker id and control calls, not PCM lists. | Forwarding PCM through the channel was not found. |
| AC-006 | met | `flutter build macos --debug` from `example/` exited 0. See paste above. | A non-zero build is not recorded. |
| AC-007 | source met; live deny [UNVERIFIED] | `macos/Classes/FlutterLocalVoiceAgentPlugin.mm` returns `permissionDenied` and does not start capture when permission is not granted. No Dart unit test in `test/` asserts that mapping. Interactive deny on a device was not re-run. | Start that opens AVAudioEngine after denial is not proven on a device in this session. |
| AC-008 | source met; Windows Flutter build [UNVERIFIED] | `windows/flutter_local_voice_agent_plugin.cpp` registers the shared method names, owns WASAPI capture and render, calls `flva_push` / `flva_render`, and maps endpoint invalidation. No Windows runner on this host. | PCM-through-Dart was not found in the Windows plugin. |
| AC-009 | source met; Linux Flutter build [UNVERIFIED] | `linux/flutter_local_voice_agent_plugin.cc` owns Pulse record and playback, calls the flva ABI, and maps server or default-device loss. No Linux runner on this host. | An ALSA-only-only path or PCM-through-Dart was not found. |
| AC-010 | met | `android/` and `ios/` plugin bridges still exist. Work item 0009 added speaker-id arguments to those bridges; it did not rewrite the 0002 audio path. `wiki/work/0002-native-offline-pipeline/STATE.yaml` still records F3/AC-004, AC-005/AC-008 and AC-007 as open. This record does not close those gates. | A claim that those parent gates are closed is not made. |
| AC-011 | met by search | Desktop log sites print counters, RMS and permission text. They do not dump frame values or a full waveform. | A log line printing raw samples was not found. |
| AC-012 | met by source review | Desktop CMake and pod files keep the existing `FLVA_ENABLE_LOCAL_LLM` CPU-only llama.cpp gate. Metal, CUDA and BLAS are not enabled by default. | A desktop target that turns a GPU backend on by default was not found. |

## Explicitly not claimed

- Physical microphone-to-speaker qualification on any platform.
- Closure of 0002 AC-004, AC-005, AC-007 or AC-008.
- Flutter web, watchOS, tvOS, Wear OS or Android TV implementations.
- A Windows or Linux Flutter desktop build on this macOS checkout.
- Android or iOS compile in this session. `flutter devices` listed only macos and chrome.

## Repair after impl-review-01

impl-review-01 failed AC-007 because no unit or bridge test asserted `permissionDenied`. The macOS start path now uses `flva_mic_start_decision`. Added `native/tests/mic_permission_test.cpp` and `test/permission_denied_test.dart`.

```text
$ c++ -std=c++17 -I native/src native/tests/mic_permission_test.cpp -o /tmp/flva-mic-permission && /tmp/flva-mic-permission
MIC_PERM_EXIT:0

$ dart format --set-exit-if-changed lib example/lib test example/test
Formatted 27 files (0 changed) in 0.14 seconds.
FORMAT_EXIT:0

$ dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
ANALYZE_PKG_EXIT:0

$ flutter test test/permission_denied_test.dart
00:00 +1: All tests passed!
PERM_TEST_EXIT:0
```

Live interactive deny on a device remains [UNVERIFIED].

## Next

Confirmation implementation review at `validation/impl-review-02.md`. Do not write a third implementation review.
