# Research review — round 01

- Work item: 0008-reasonable-platform-coverage
- Reviewed artifact: wiki/work/0008-reasonable-platform-coverage/00-research.md
- Reviewer: blind-research-validator
- Date: 2026-09-20

## Verdict

**PASS**

The merged research’s platform-reasonableness conclusion is supported by the current repository shape and by independently re-checked sherpa-onnx v1.12.14 assets, Flutter desktop registration and version floors, and Apple AVAudioSession / AVAudioEngine availability. Remaining findings do not invalidate reuse of flva.h with OS-owned audio, nor the exclusion of web and appliance targets. This verdict certifies research accuracy only; AC-001 through AC-012 still require later implementation evidence.

## Verification performed

The reviewer read `00-research.md`, the three cited stream files, the acceptance criteria, the validation rubric and the report template. Work item 0008 plan, task list, work-item state and author transcripts were not inputs. Cited repository files and URLs were re-checked independently.

```text
$ python3 - <<'PY'
from pathlib import Path
text = Path("pubspec.yaml").read_text()
for i,line in enumerate(text.splitlines(),1):
    if any(k in line for k in ("plugin","android","ios","macos","windows","linux","web")):
        print(f"{i}:{line}")
PY
21:  plugin:
23:      android:
25:        pluginClass: FlutterLocalVoiceAgentPlugin
26:      ios:
27:        pluginClass: FlutterLocalVoiceAgentPlugin

$ rg -n "ASSETS|android|ios|macos|windows|linux" tool/provision_runtime.py | head -20
11:ASSETS = {
12:    'android': ('sherpa-onnx-v1.12.14-android.tar.bz2', 'f46e7179ae1e36477da7dfdc8cec35ecb6d558114871a4ec5210a9949f887497'),
13:    'ios': ('sherpa-onnx-v1.12.14-ios.tar.bz2', 'ce886f4d143f66e29606ee28604851247c3333fb0a94209ca248bc235751701f'),
18:    name, digest = ASSETS[platform]
33:        if platform == 'android':
34:            target = root / 'android/src/main/jniLibs/arm64-v8a'
39:            target = root / 'ios/Frameworks'
41:            for file in ('build-ios/sherpa-onnx.xcframework', 'build-ios/ios-onnxruntime/1.17.1/onnxruntime.xcframework'):
49:    parser.add_argument('platform', choices=ASSETS)

$ rg -n "import 'dart:io'|unsupportedProfile|fullDuplexRequired" lib/src/agent.dart lib/src/model_store.dart lib/src/model_preparation.dart lib/src/models.dart
lib/src/models.dart:9:  fullDuplexRequired,
lib/src/models.dart:84:  unsupportedProfile,
lib/src/model_store.dart:2:import 'dart:io';
lib/src/model_preparation.dart:3:import 'dart:io';
lib/src/agent.dart:3:import 'dart:io';
lib/src/agent.dart:29:    if (mode == ConversationMode.fullDuplexRequired) {
lib/src/agent.dart:31:        AgentErrorCode.unsupportedProfile,

$ rg -n "No audio|NativeVoicePlatform" lib/src/contracts.dart
15:/// Boundary for the native method channel. No audio crosses this interface.
16:abstract interface class NativeVoicePlatform {

$ rg -n "flva_create|flva_push|flva_render|input_rate" native/include/flva.h
15:  int32_t input_rate; /* mono float32, 8000..192000, constant per session */
24:FlvaSession *flva_create(const FlvaConfig *, char *error, int32_t error_capacity);
34:int32_t flva_push(FlvaSession *, const float *, int32_t frames);
35:void flva_render(FlvaSession *, float *, int32_t frames);

$ ls -d macos windows linux web
ls: linux: No such file or directory
ls: macos: No such file or directory
ls: web: No such file or directory
ls: windows: No such file or directory

$ ls -d example/android example/ios example/macos example/windows example/linux example/web
ls: example/linux: No such file or directory
ls: example/macos: No such file or directory
ls: example/windows: No such file or directory
example/android
example/ios
example/web

$ rg -n "verdict:|VITS|AC-004|AC-005|AC-007|AC-008" wiki/work/0002-native-offline-pipeline/STATE.yaml | head
6:verdict: FAIL
11:  - "F3 / AC-004: VITS allocates an entire sentence before callback; hard synthesis allocation bound not established."
12:  - "AC-005 / AC-008: physical mobile offline, audio, lifecycle and performance qualification unavailable."
13:  - "AC-007: native binaries and provisioning tools are excluded from the pub payload; clean consumer installation remains unqualified. Final dirty-checkout dry run exits 65 with one warning."

$ rg -n "osx-universal2-shared|7e0f7bec" wiki/work/0002-native-offline-pipeline/research/provisioning.md
35:| Runtime archive | .../sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2 | ... | `7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413` | ...
36:| C shared library | .../libsherpa-onnx-c-api.dylib | ... | `f696c660bcf950aa36a4c1a7f959c37eba9f9e96224c8be3bfb9c0519b88a08a` | Universal `x86_64 arm64` ...

$ rg -n "GGML_|FLVA_ENABLE_LOCAL_LLM" native/llm/CMakeLists.txt
6:option(FLVA_ENABLE_LOCAL_LLM "Build the optional local llama.cpp adapter" OFF)
9:if(NOT FLVA_ENABLE_LOCAL_LLM)
25:set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
26:set(GGML_METAL OFF CACHE BOOL "" FORCE)
27:set(GGML_ACCELERATE OFF CACHE BOOL "" FORCE)
28:set(GGML_BLAS OFF CACHE BOOL "" FORCE)
```

URL re-checks on 2026-09-20 (curl, GitHub API, Apple DocC JSON):

- `https://api.github.com/repos/k2-fsa/sherpa-onnx/releases/tags/v1.12.14` HTTP 200. Confirmed assets include `sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2`, `sherpa-onnx-v1.12.14-macos-xcframework-static.tar.bz2`, `sherpa-onnx-v1.12.14-win-x64-shared.tar.bz2`, `sherpa-onnx-v1.12.14-win-x64-static-no-tts.tar.bz2`, `sherpa-onnx-v1.12.14-win-x64-jni.tar.bz2`, `sherpa-onnx-v1.12.14-linux-x64-shared.tar.bz2` and `sherpa-onnx-v1.12.14-linux-x64-jni.tar.bz2`. No `win-arm64` shared archive was listed among 70 assets.
- `https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/README.md` raw HTTP 200. Supported-platforms table marks Windows/Linux/macOS x64 and arm64.
- `https://docs.flutter.dev/reference/supported-platforms` HTTP 200. macOS supported Monterey (12) to Golden Gate (27); Windows supported 10, 11 (x64, Arm64); Debian 10 to 13; Ubuntu 20.04 LTS to 24.04 LTS.
- `https://docs.flutter.dev/packages-and-plugins/developing-packages` HTTP 200. Documents `pluginClass: HelloPlugin`, `macos/Classes`, Windows `.h+.cpp` / Visual Studio, and Linux plugin steps.
- `https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors` HTTP 200. States Flutter 3.44 or later enables SwiftPM by default; CocoaPods remains discussed.
- `https://docs.flutter.dev/platform-integration/platform-channels` HTTP 200. Contains `RegisterPlugins`, `flutter::MethodChannel`, `fl_method_channel_new` and `fl_register_plugins`.
- Apple DocC JSON `avaudiosession.json` HTTP 200. Primary platforms: iOS, iPadOS, Mac Catalyst, tvOS, visionOS, watchOS. No native macOS row.
- Apple DocC JSON `avaudioengine.json` HTTP 200. macOS introducedAt 10.10.
- Apple DocC JSON `requestaccess(for:completionhandler:).json` HTTP 200. macOS introducedAt 10.14.
- `https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi` HTTP 200. Documents WASAPI, `IAudioCaptureClient`, `IAudioRenderClient` and `AUDCLNT_E_DEVICE_INVALIDATED`.
- `https://learn.microsoft.com/en-us/windows/win32/coreaudio/capturing-a-stream` HTTP 200. Documents `GetBuffer` / `ReleaseBuffer` on `IAudioCaptureClient`.
- `https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-f-devicecapability` HTTP 200. UWP package-manifest schema; page title is Windows UWP applications.
- `https://docs.pipewire.org/page_overview.html` HTTP 200. Mentions accommodation of JACK or Pulseaudio clients, WirePlumber, and external session management.
- `https://www.freedesktop.org/software/pulseaudio/doxygen/stream_8h.html` HTTP 418 bot-challenge HTML. Independent retrieval of `pa_stream_connect_record` / `pa_stream_connect_playback` from that URL failed.
- `https://github.com/ggerganov/llama.cpp/blob/master/README.md` raw HTTP 200. Points to `docs/build.md`. Upstream `ggml` CMake fetched the same day shows `option(GGML_CUDA ... OFF)`.
- `https://docs.flutter.dev/platform-integration/windows/building` HTTP 200. Describes Win32 host customization and MSIX packaging; no microphone `DeviceCapability` text.

PRD `wiki/product/local-voice-agent-prd.md` line 32 still places web support outside the first release. ADR `wiki/adr/0001-offline-voice-architecture.md` line 31 still rejects a channel-only PCM pipeline. `doc/capabilities.md` still records no physical Android/iPhone qualification and unfinished consumer native packaging.

No implementation test, macOS example build, digest install, or physical-device run was executed. Negative cases in AC-001 through AC-012 remain future implementation checks.

## Per-criterion results

Not applicable. This is a research review. AC-001 through AC-012 were used to judge whether the research’s claims, alternatives and sources can support later implementation, not to certify code.

## Findings

### F-001 — Parent research marks the already-recorded macOS v1.12.14 digest as unknown

- Severity: IMPORTANT
- Location: `wiki/work/0008-reasonable-platform-coverage/00-research.md:82`
- Criterion affected: AC-003, AC-004
- Observation: The merged unresolved list and the constraints paragraph at line 73 state that SHA-256 values for the official v1.12.14 macOS universal2, Windows x64 and Linux x64 shared archives are not recorded yet. The desktop stream cites `wiki/work/0002-native-offline-pipeline/research/provisioning.md`, which already records digest `7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413` for `sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2` and an on-disk `libsherpa-onnx-c-api.dylib` layout. Windows and Linux pinned digests remain absent from `tool/provision_runtime.py`.
- Why it matters: Treating a cited, measured macOS digest as unknown is an unsupported gap claim against a source the same research tree already used.

### F-002 — Windows microphone evidence cites a UWP manifest schema

- Severity: IMPORTANT
- Location: `wiki/work/0008-reasonable-platform-coverage/research/desktop.md:87`
- Criterion affected: none
- Observation: The Windows permission claim says desktop analogues include `DeviceCapability Name="microphone"` in the app manifest, evidenced by the UWP `DeviceCapability` schema. Independently opened Flutter Windows building documentation describes a Win32 host and MSIX packaging and does not document that UWP capability element as the Flutter plugin permission path.
- Why it matters: The cited schema is a different Windows application class from the current Flutter desktop runner. The WASAPI capture/render and invalidation claims on the same page were confirmed; this permission analogue was not.

### F-003 — Cited PulseAudio doxygen page was not independently retrievable

- Severity: NIT
- Location: `wiki/work/0008-reasonable-platform-coverage/research/desktop.md:107`
- Criterion affected: AC-009
- Observation: The Linux audio claim names `pa_stream_connect_record` and `pa_stream_connect_playback` and cites `https://www.freedesktop.org/software/pulseaudio/doxygen/stream_8h.html`. A 2026-09-20 fetch returned HTTP 418 bot-challenge HTML. The same sentence also calls these “libpulse simple client streams,” mixing the simple client vocabulary with async stream entry points. PipeWire overview text that was retrievable does mention accommodation of Pulseaudio clients.
- Why it matters: The PulseAudio-first Linux option remains the documented portable path, but the primary API citation could not be re-opened on the review date.

### F-004 — Research never states the no-raw-PCM-in-logs constraint

- Severity: NIT
- Location: `wiki/work/0008-reasonable-platform-coverage/00-research.md:70`
- Criterion affected: AC-011
- Observation: Constraints and exclusions cover the frozen C ABI, native PCM ownership, CPU-only llama.cpp, parent 0002 gates and excluded hosts. No sentence in the merged research or the three streams says desktop audio-callback logs must not contain raw PCM samples or waveforms.
- Why it matters: AC-011 is an explicit non-functional criterion. The research does not record that constraint as a discovered rule.

## Recurrence check

- Previous round: none — first research review
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | research |
| F-002 | research |
| F-003 | research |
| F-004 | research |
