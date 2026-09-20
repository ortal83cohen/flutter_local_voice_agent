# Research: Reasonable platform coverage for the existing offline pipeline

## Question

Which Flutter platforms can host the existing native offline voice session with a reasonable implementation, and which platforms must stay unsupported?

## Answer

Android and iOS already implement the shared flva.h session. macOS, Windows and Linux can be added as compile-capable plugin platforms by reusing that C ABI, adding OS-owned audio, and extending build-time runtime provisioning. Flutter web, watchOS, tvOS, Wear OS, Android TV, WASM rewrites, cloud speech and PCM-through-Dart are not reasonable for this item. Parent work 0002 allocation, physical-device and consumer-packaging gates stay open.

## Findings

### Current declared coverage

- Claim: The package registers only Android and iOS plugin platforms. No macos, windows, linux or web plugin folders exist at the package root.
- Evidence: pubspec.yaml flutter.plugin.platforms lists android and ios only. Delegated current-gap research found Android Kotlin plus JNI and iOS Objective-C++ bridges that both call flva.h and keep PCM off Dart.
- Source: wiki/work/0008-reasonable-platform-coverage/research/current-gap.md; pubspec.yaml; native/include/flva.h.

### Shared contract that new platforms must reuse

- Claim: The inference contract is the versioned C ABI. Capture enters through flva_push as mono float32 at a declared rate. Playback leaves through flva_render. Control stays on the existing method channel named flutter_local_voice_agent.
- Evidence: native/include/flva.h documents create, start, push, render, poll, reply, interrupt, stop and destroy. lib/src/contracts.dart states that no audio crosses NativeVoicePlatform.
- Source: native/include/flva.h; lib/src/contracts.dart; wiki/adr/0001-offline-voice-architecture.md.

### Android and iOS remain first-class and unfinished as qualification targets

- Claim: Mobile bridges exist and compile, but they are not a qualified same-session proof and this item must not close parent gates.
- Evidence: Android captures at a hardcoded 16000 Hz on arm64-v8a only. iOS prefers 48000 Hz from AVAudioSession and lets the native worker resample. Prebuilt sherpa archives are gitignored and provisioned by tool/provision_runtime.py. Work 0002 remains FAIL for VITS allocation, physical audio and clean consumer installation.
- Source: wiki/work/0008-reasonable-platform-coverage/research/current-gap.md; wiki/work/0002-native-offline-pipeline/STATE.yaml; doc/capabilities.md.

### Desktop is reasonable as plugin work, not as a new engine

- Claim: sherpa-onnx v1.12.14 publishes shared CPU archives for macOS universal2, Windows x64 and Linux x64. Flutter documents macos, windows and linux plugin registration. Standard OS audio APIs can feed the existing ABI.
- Evidence: Delegated desktop research cited the v1.12.14 GitHub release, Flutter developing-packages documentation, AVAudioEngine on macOS 10.10+, WASAPI capture and render clients, and PulseAudio record/playback streams with PipeWire compatibility on current Flutter Linux distributions.
- Source: wiki/work/0008-reasonable-platform-coverage/research/desktop.md; https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.14 consulted 2026-09-20; https://docs.flutter.dev/packages-and-plugins/developing-packages consulted 2026-09-20.

### macOS cannot copy the iOS plugin file

- Claim: macOS can reuse AVAudioEngine tap and source-node PCM plumbing, but AVAudioSession, UIKit foreground checks and iOS interruption notifications are unavailable on native macOS.
- Evidence: Apple documents AVAudioSession as unavailable on native macOS. Microphone permission uses AVCaptureDevice requestAccess and NSMicrophoneUsageDescription. Route changes need CoreAudio default-device listeners.
- Source: wiki/work/0008-reasonable-platform-coverage/research/desktop.md.

### Windows and Linux compile cannot be proven on this macOS checkout

- Claim: Windows and Linux source bridges are reasonable. Linking those plugins has not been executed in this repository, and this host cannot substitute a Windows or Linux Flutter desktop build.
- Evidence: Desktop research lists missing windows and linux folders, missing provisioning keys, and no Windows or Linux link evidence. Flutter supported-platforms documents Windows 10/11 and Debian 10+ / Ubuntu 20.04+ as the desktop floors.
- Source: wiki/work/0008-reasonable-platform-coverage/research/desktop.md; https://docs.flutter.dev/reference/supported-platforms consulted 2026-09-20.

### Exclusions that are not reasonable

- Claim: Flutter web cannot load flva.h. Core library files import dart:io. The PRD already places web outside the first release. watchOS, tvOS, Wear OS, Android TV, WASM ports, cloud speech and PCM-through-Dart each require a different runtime, audio contract or transport.
- Evidence: lib/src/agent.dart, lib/src/model_store.dart and lib/src/model_preparation.dart import dart:io. AgentErrorCode.unsupportedProfile already exists and is used for unqualified full duplex. Delegated exclusions research names that code as the failure for unsupported hosts.
- Source: wiki/work/0008-reasonable-platform-coverage/research/exclusions.md; wiki/product/local-voice-agent-prd.md; lib/src/models.dart.

### Windows permission evidence and Pulse citations

- Claim: Windows microphone permission is not established by the UWP DeviceCapability schema. A Flutter Windows runner is a Win32 host. Start must treat capture-open denial as permissionDenied or audioUnavailable. Linux record denial through a desktop portal remains a typed failure even though the exact portal API is unresolved.
- Evidence: Independent research review opened the cited UWP schema and the Flutter Windows building page. The latter describes a Win32 host and MSIX packaging and does not document that UWP element as the plugin permission path. PulseAudio doxygen for named stream functions was not independently retrievable on 2026-09-20.
- Source: wiki/work/0008-reasonable-platform-coverage/validation/research-review-01.md; https://docs.flutter.dev/platform-integration/windows/building consulted 2026-09-20.

### Parent decision on the meaning of supported platforms

- Claim: For this work item, supported platforms are Android, iOS, macOS, Windows and Linux. The exclusions stream recommended Android and iOS only until desktop evidence existed. The desktop stream then supplied that evidence. The user requested every platform that can be delivered with a reasonable implementation, so the parent includes the three desktop targets and keeps mobile first-class.
- Evidence: User request recorded in STATE.yaml; sibling streams in research/exclusions.md and research/desktop.md.
- Source: wiki/work/0008-reasonable-platform-coverage/STATE.yaml; the two sibling research files.

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Keep Android and iOS only | Match current pubspec and PRD applies_to | Lowest, but ignores desktop evidence and the request for every reasonable platform | Rejected as the work-item definition of supported |
| Add macOS only | Lowest desktop increment on this host | Leaves Windows and Linux unimplemented despite the same ABI and official sherpa archives | Rejected as the sole deliverable; retained as the first desktop implementation slice |
| Add macOS, Windows and Linux, exclude web and appliance targets | Reuse flva.h; add OS audio and provisioning; fail unsupported hosts with unsupportedProfile | Three new plugin folders and pinned archives; Windows/Linux compile remains host-dependent | Chosen |
| Port sherpa and flva to Flutter web or WASM | New runtime and audio stack | Replaces the existing session instead of reusing it | Rejected |

## Constraints discovered

- The C ABI, method-channel control surface and native PCM ownership are frozen. Desktop work may add bridges and linking only.
- tool/provision_runtime.py currently pins only android and ios archives. The macOS official v1.12.14 universal2 shared archive digest is already recorded in work 0002 provisioning research as 7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413. Windows x64 and Linux x64 shared archive digests are still unmeasured in this repository.
- Desktop audio-callback logs must not contain raw PCM samples or waveforms. Boundary counters and bounded text remain allowed.
- iOS plugin sources are not a drop-in macOS implementation.
- Optional llama.cpp stays CPU-only behind the existing CMake gate.
- This item must not mark work 0002 VITS allocation, physical mobile qualification or clean pub installation as complete.
- No commit, publication or model redistribution is authorized.
- Flutter desktop floors consulted on 2026-09-20 are macOS Monterey 12, Windows 10 and Debian 10 / Ubuntu 20.04 LTS. Android minSdk 26 and iOS 13 remain the existing mobile floors.

## Unresolved

- [UNRESOLVED: Exact SHA-256 digests and on-disk layouts for the official sherpa-onnx v1.12.14 Windows x64 and Linux x64 shared archives. The macOS universal2 shared archive digest is already recorded in work 0002 provisioning research.]
- [UNRESOLVED: CoreAudio default-device mapping to the existing routeChanged suspension code.]
- [UNRESOLVED: WASAPI mix-format negotiation for mono float32 on real Windows endpoints.]
- [UNRESOLVED: Linux xdg-desktop-portal or PipeWire session-manager prompts when opening a record stream.]
- [UNRESOLVED: Whether a Windows or Linux Flutter desktop build can be executed before this item closes.]
- [UNRESOLVED: Whether Android 16 kHz capture and iOS dynamic capture count as the same qualified session.]
- [UNRESOLVED: Parent 0002 F3/AC-004 VITS allocation, physical Android/iPhone qualification and AC-007 consumer packaging.]

## Sources

- wiki/work/0008-reasonable-platform-coverage/research/current-gap.md — merged 2026-09-20
- wiki/work/0008-reasonable-platform-coverage/research/desktop.md — merged 2026-09-20
- wiki/work/0008-reasonable-platform-coverage/research/exclusions.md — merged 2026-09-20
- pubspec.yaml, native/include/flva.h, tool/provision_runtime.py, lib/src/agent.dart, lib/src/models.dart, doc/capabilities.md — consulted 2026-09-20
- wiki/work/0002-native-offline-pipeline/STATE.yaml — consulted 2026-09-20
- wiki/work/0002-native-offline-pipeline/research/provisioning.md — consulted 2026-09-20 for the recorded macOS universal2 archive digest
- wiki/product/local-voice-agent-prd.md and wiki/adr/0001-offline-voice-architecture.md — consulted 2026-09-20
