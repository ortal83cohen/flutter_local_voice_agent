# Implementation review — round 01

- Work item: 0008-reasonable-platform-coverage
- Reviewed artifact: current working tree — `lib/src/agent.dart`, `lib/src/models.dart`, `test/platform_refusal_test.dart`, `test/agent_test.dart`, `pubspec.yaml`, `tool/provision_runtime.py`, `tool/test_provision_runtime.py`, `macos/Classes/FlutterLocalVoiceAgentPlugin.mm`, `macos/Classes/NativeCore.mm`, `macos/flutter_local_voice_agent.podspec`, `windows/flutter_local_voice_agent_plugin.cpp`, `windows/CMakeLists.txt`, `linux/flutter_local_voice_agent_plugin.cc`, `linux/CMakeLists.txt`, `android/` and `ios/` plugin trees, `wiki/work/0002-native-offline-pipeline/STATE.yaml` (blockers only), `doc/capabilities.md`, `README.md`, `wiki/product/reasonable-platform-coverage.md`, `wiki/INDEX.md`
- Reviewer: impl-review-0008
- Date: 2026-09-21

## Verdict

**FAIL**

AC-007 is unmet: the macOS denial path returns `permissionDenied` before `startAudio` in source, but no unit or bridge test asserts that denied access returns that code and does not start capture.

## Verification performed

Working directory: `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent`.
`PATH` placed Flutter 3.47.0 first: `/Users/ortalcohen/fvm/versions/3.47.0/bin`.
Toolchain after that export: Flutter 3.47.0, Dart 3.13.0.

### 1. `python3 tool/lint_wiki.py`

```
lint_wiki: clean (0 warning(s)).
```

Exit 0. This run was taken before this report file existed.

### 2. `dart format --set-exit-if-changed lib example/lib test example/test`

```
Formatted 26 files (0 changed) in 0.13 seconds.
FORMAT_EXIT=0
```

### 3. `dart analyze --fatal-infos --fatal-warnings`

```
Analyzing flutter_local_voice_agent...
No issues found!
ROOT_ANALYZE_EXIT=0
```

### 4. `dart analyze --fatal-infos --fatal-warnings` (cwd `example`)

```
Analyzing example...
No issues found!
EXAMPLE_ANALYZE_EXIT=0
```

### 5. `flutter test`

```
00:05 +72: All tests passed!
FLUTTER_TEST_EXIT=0
```

Full trailing result: 72 tests passed. Suite included `test/platform_refusal_test.dart` (`excluded target is refused before native create` and siblings). No test name or assertion in `test/` or `example/test/` mentioned `permissionDenied`.

### 6. `python3 tool/test_provision_runtime.py`

```
test_matching_digest_installs_expected_library_names (__main__.ProvisionRuntimeTest.test_matching_digest_installs_expected_library_names) ... ok
test_mismatch_copies_nothing_and_cli_exits_nonzero (__main__.ProvisionRuntimeTest.test_mismatch_copies_nothing_and_cli_exits_nonzero) ... ok

----------------------------------------------------------------------
Ran 2 tests in 0.364s

OK
pubspec platforms and web key are checked by the parent work item.
macos: verified SHA-256 b506e3ceb18a8dc0b46283cfedee1ef93641e02966b9ce7a5b24379dbc5edcde
Provisioned build inputs. Distribution notice review remains required.
macos match dest listing: ['libonnxruntime.1.17.1.dylib', 'libonnxruntime.dylib', 'libsherpa-onnx-c-api.dylib']
windows: verified SHA-256 ea72033efce46b0562b45190b79fe4c78ef36c5a3a206f50d4e64361ac65dca9
Provisioned build inputs. Distribution notice review remains required.
windows match dest listing: ['onnxruntime.dll', 'onnxruntime_providers_shared.dll', 'sherpa-onnx-c-api.dll', 'sherpa-onnx-c-api.lib']
linux: verified SHA-256 dca992d07131a13219010e19410365f43adf9c3f73f00722d54a9e7138e77e0d
Provisioned build inputs. Distribution notice review remains required.
linux match dest listing: ['libonnxruntime.so', 'libsherpa-onnx-c-api.so']
macos mismatch dest listing: ['keep-me.txt']
macos mismatch CLI exit: 1
macos mismatch CLI stderr: Traceback (most recent call last):
  File "/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py", line 130, in <module>
    provision(args.platform, args.archive, args.root)
    ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py", line 111, in provision
    raise ValueError('Runtime archive SHA-256 mismatch')
ValueError: Runtime archive SHA-256 mismatch
windows mismatch dest listing: ['keep-me.txt']
windows mismatch CLI exit: 1
windows mismatch CLI stderr: Traceback (most recent call last):
  File "/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py", line 130, in <module>
    provision(args.platform, args.archive, args.root)
    ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py", line 111, in provision
    raise ValueError('Runtime archive SHA-256 mismatch')
ValueError: Runtime archive SHA-256 mismatch
linux mismatch dest listing: ['keep-me.txt']
linux mismatch CLI exit: 1
linux mismatch CLI stderr: Traceback (most recent call last):
  File "/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py", line 130, in <module>
    provision(args.platform, args.archive, args.root)
    ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py", line 111, in provision
    raise ValueError('Runtime archive SHA-256 mismatch')
ValueError: Runtime archive SHA-256 mismatch
PROVISION_TEST_EXIT=0
```

### 7. `flutter devices`

```
Found 2 connected devices:
  macOS (desktop) • macos  • darwin-arm64   • macOS 26.6.2 25G83 darwin-arm64
  Chrome (web)    • chrome • web-javascript • Google Chrome 153.0.8010.52

Checking for wireless devices...

No wireless devices were found.
DEVICES_EXIT=0
```

### 8. `flutter build macos --debug` (cwd `example`)

```
Running pod install...                                           1,901ms
Building macOS application...
...
3 warnings generated.
✓ Built build/macos/Build/Products/Debug/flutter_local_voice_agent_example.app
MACOS_BUILD_EXIT=0
```

Warnings were documentation comments in vendored `c-api.h` (`parameter 'p' not found`). Build process also printed that the plugin lacks Swift Package Manager support for macOS; extra SPM is outside this item. Exit 0.

Independent source checks (not author claims):

- `rg permissionDenied` over `test/` and `example/test/` returned no matches.
- `example/macos/RunnerTests/RunnerTests.swift` is an empty placeholder `testExample`.
- Method-channel argument search on `macos/` found no PCM lists, `Uint8List`, `Float32List`, or byte-array audio payloads.
- Desktop log sites print rates, frame counts, RMS, and push results, not raw sample arrays.
- `pubspec.yaml` plugin platforms list android, ios, macos, windows, linux and have no `web:` key.
- `macos/libs` on this checkout contains `libsherpa-onnx-c-api.dylib`, `libonnxruntime.1.17.1.dylib`, and symlink `libonnxruntime.dylib`.
- Android `FlutterLocalVoiceAgentPlugin.kt` still owns `AudioRecord` / `AudioTrack` and JNI `nativePush` / `nativeRender`; `android/src/main/cpp/bridge.cpp` still calls `flva_push` / `flva_render`.
- iOS `FlutterLocalVoiceAgentPlugin.mm` still calls `flva_push` / `flva_render` on the audio callbacks.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | `lib/src/agent.dart:49`, `lib/src/agent.dart:547`, `test/platform_refusal_test.dart:14` | yes |
| AC-002 | pass | `pubspec.yaml:38` | yes |
| AC-003 | pass | `tool/provision_runtime.py:110`, `tool/test_provision_runtime.py:93` | yes |
| AC-004 | pass | `tool/provision_runtime.py:23`, `tool/test_provision_runtime.py:128` | yes |
| AC-005 | pass | `macos/Classes/FlutterLocalVoiceAgentPlugin.mm:206`, `macos/Classes/FlutterLocalVoiceAgentPlugin.mm:220` | yes |
| AC-006 | pass | `flutter build macos --debug` cwd `example`, exit 0 (command 8) | yes |
| AC-007 | fail | `macos/Classes/FlutterLocalVoiceAgentPlugin.mm:123`, `example/macos/RunnerTests/RunnerTests.swift:7` | no |
| AC-008 | pass | `windows/flutter_local_voice_agent_plugin.cpp:268`, `windows/flutter_local_voice_agent_plugin.cpp:816`, `windows/flutter_local_voice_agent_plugin.cpp:874` | yes |
| AC-009 | pass | `linux/flutter_local_voice_agent_plugin.cc:306`, `linux/flutter_local_voice_agent_plugin.cc:801`, `linux/flutter_local_voice_agent_plugin.cc:829` | yes |
| AC-010 | pass | `android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt:140`, `ios/Classes/FlutterLocalVoiceAgentPlugin.mm:120`, `wiki/work/0002-native-offline-pipeline/STATE.yaml:10` | yes |
| AC-011 | pass | `macos/Classes/FlutterLocalVoiceAgentPlugin.mm:208`, `windows/flutter_local_voice_agent_plugin.cpp:819`, `linux/flutter_local_voice_agent_plugin.cc:804` | yes |
| AC-012 | pass | `macos/flutter_local_voice_agent.podspec:34`, `windows/CMakeLists.txt:59`, `linux/CMakeLists.txt:74` | yes |

AC-001: `_refuseUnsupportedHost` runs before `native.create`. `kIsWeb` and a closed `defaultTargetPlatform` switch refuse web and fuchsia. `test/platform_refusal_test.dart` injects `TargetPlatform.fuchsia`, expects `AgentErrorCode.unsupportedProfile`, and asserts `_FakePlatform.created` stays false. A supported-macOS control reaches create. Flutter web implementation is explicitly not required; the specified injected-target test exists and passed in command 5.

AC-002: Plugin platforms declare android, ios, macos, windows, linux. No `web:` plugin entry. A missing desktop key or a web plugin key would fail this inspection.

AC-003: Digest compare happens before `tar.extractall` and before any desktop `_copy_library`. Command 6 mismatch cases for macos, windows, and linux raised `ValueError: Runtime archive SHA-256 mismatch`, CLI exit 1, destination listing `['keep-me.txt']`, and zero sherpa-named files.

AC-004: `DESKTOP_INSTALL` names the official v1.12.14 shared-library files. Command 6 matching-digest fixtures installed those names for all three desktop keys. This checkout already has the macOS expected dylibs under `macos/libs` after prior provisioning. The Python test remaps the pinned digest onto a tiny fixture rather than re-downloading official bytes; the criterion allows a local matching archive or a recorded provisioned checkout. A successful exit with missing expected names would fail command 6.

AC-005: Capture tap calls `flva_push`; render block calls `flva_render`. `handleMethodCall` / `execute` arguments are paths, mode, speakerId, generation, and text. Poll returns event maps. Search of the macOS codec path found no PCM lists or byte arrays on the channel.

AC-006: Command 8 exited 0 and produced `build/macos/Build/Products/Debug/flutter_local_voice_agent_example.app`. A non-zero build would fail this row. Windows and Linux Flutter desktop builds were not required.

AC-007: Denied or restricted `AVAuthorizationStatus` returns `FlutterError` code `permissionDenied` on the platform thread and returns before the control-queue dispatch that can reach `startAudio` (which is the only `AVAudioEngine` allocation). `AVAuthorizationStatusNotDetermined` plus `granted=0` does the same. No Dart, XCTest, or other bridge test asserts that denial. `rg permissionDenied` over `test/` and `example/test/` is empty. `RunnerTests.swift` is a no-op. The frozen check requires a unit or bridge test that denied access returns `permissionDenied`. That negative case was not exercised. A device deny-prompt run was not performed; physical microphone-to-speaker qualification is explicitly not required, and that absence is not the defect.

AC-008: Windows registers `create`, `start`, `stop`, `interrupt`, `reply`, `poll`, `dispose`, `setSpeakerId`. Capture and render use WASAPI (`IAudioClient`, `IAudioCaptureClient`, `IAudioRenderClient`). Audio threads call `flva_push` and `flva_render`. `AUDCLNT_E_DEVICE_INVALIDATED` suspends with `audioUnavailable`. Default-device change suspends with `routeChanged`. No PCM is placed on the method channel. No Windows Flutter build was required on this macOS checkout.

AC-009: Linux handles the same method names. Record and playback are PulseAudio streams (`pa_stream_connect_record`, `pa_stream_connect_playback`). CMake requires `libpulse` (`PULSE REQUIRED`); ALSA-only is not the implementation path. Callbacks call `flva_push` and `flva_render`. Context or stream loss suspends with `audioUnavailable`. Default source/sink change or endpoint removal suspends with `routeChanged`. No PCM is sent through Dart. No Linux Flutter build was required.

AC-010: Android and iOS plugin bridges still exist and still own the native audio path (`nativePush`/`flva_push`, `nativeRender`/`flva_render`). Parent 0002 `STATE.yaml` blockers remain the VITS allocation gate, physical mobile qualification, and clean consumer-install. `doc/capabilities.md`, `README.md`, and `wiki/product/reasonable-platform-coverage.md` record those gates as OPEN. No inspected 0008 artifact states they are closed. Missing Windows/Linux Flutter builds and missing 0002 closure are not defects under Explicitly not required.

AC-011: Desktop callback logs emit `callbacks`, `frames` (count), `rms`, and `push`. No inspected desktop log site prints raw PCM samples or a waveform.

AC-012: Optional LLM stays behind `FLVA_ENABLE_LOCAL_LLM`. macOS podspec defines `FLVA_ENABLE_LLM=1` only when that env is `1` and does not enable Metal, CUDA, or BLAS. Windows and Linux CMake default the option OFF and force `GGML_CUDA`, `GGML_METAL`, `GGML_BLAS`, and the other listed GPU backends OFF before adding `native/llm`.

## Findings

### F-001 — No macOS permission-denied unit or bridge test

- Severity: BLOCKER
- Location: `example/macos/RunnerTests/RunnerTests.swift:7`
- Criterion affected: AC-007
- Observation: AC-007 requires a unit or bridge test that denied microphone access returns `permissionDenied` and does not start capture. The only macOS XCTest file is an empty `testExample`. `test/` and `example/test/` contain no `permissionDenied` case. Command 5 passed 72 tests without exercising denial. Source at `macos/Classes/FlutterLocalVoiceAgentPlugin.mm:123` returns `permissionDenied` before `startAudio`, but that path is untested.
- Why it matters: The frozen check and the validation rubric both require a negative test for this criterion. Source review alone does not establish AC-007.

### F-002 — Index still describes 0008 as not yet implemented

- Severity: NIT
- Location: `wiki/INDEX.md:170`
- Criterion affected: none
- Observation: The index line for `05-implement-ready.md` still says criteria are frozen and no task has begun, while desktop plugin sources, tests, and a macOS debug build are present in this tree.
- Why it matters: Router text can send a later reader to the wrong phase. It does not change any acceptance criterion.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | implement |
| F-002 | document |
