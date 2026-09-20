# Research: Reasonable platform coverage for the existing offline pipeline

## Question

What platform coverage already exists in this Flutter offline voice plugin, and what is missing before Android, iOS and any later desktop host can run the same native session?

## Answer

The package declares and implements only Android and iOS. Both platforms share the flva.h C ABI and the same Dart method-channel control surface while keeping PCM on native audio threads; the example app ships Android and iOS host folders only. Before Android and iOS can be treated as running the same qualified native session, the repository still lacks checked-in prebuilt runtimes, physical microphone-to-speaker evidence, clean consumer packaging, and several parent gates from work 0002 that this item must not close. No macOS, Windows, Linux, or web plugin registration exists today; desktop parity is out of scope for this stream.

## Findings

### Declared plugin platforms

- Claim: The published Flutter plugin registers Android and iOS only; no desktop or web platform entry appears in the package manifest.
- Evidence: pubspec.yaml flutter.plugin.platforms lists android with package dev.localvoice.flutter_local_voice_agent and pluginClass FlutterLocalVoiceAgentPlugin, and ios with the same pluginClass. No macos, linux, windows, or web keys are present. The PRD applies_to frontmatter scopes lib, example, android, and ios only.
- Source: pubspec.yaml; wiki/product/local-voice-agent-prd.md (frontmatter applies_to, product-decision section).

### Android bridge and native link

- Claim: Android exposes a Kotlin method-channel plugin that loads a native flva shared library, forwards control calls through JNI bridge.cpp into flva.h, and owns AudioRecord/AudioTrack capture and playback at 16 kHz mono float32 input without passing PCM to Dart.
- Evidence: FlutterLocalVoiceAgentPlugin.kt registers MethodChannel name flutter_local_voice_agent, loads System.loadLibrary("flva"), implements create/start/stop/interrupt/reply/poll/dispose, runs capture and render threads calling nativePush and nativeRender, and requires a foreground Activity plus RECORD_AUDIO permission. bridge.cpp maps JNI nativeCreate through nativePoll to flva_create, flva_start, flva_push, flva_render, flva_poll, and related C ABI entry points; nativeCreate sets FlvaConfig input_rate to 16000. CMakeLists.txt builds add_library(flva SHARED bridge.cpp plus all native/src/*.cpp), links an imported libsherpa-onnx-c-api.so from android/src/main/jniLibs/${ANDROID_ABI}/, and fails the configure step when that .so is absent, directing provision via tool/provision_runtime.py. android/build.gradle sets minSdk 26, ndk abiFilters arm64-v8a only, compileSdk 35, NDK 28.2.13676358, and optional FLVA_ENABLE_LOCAL_LLM CMake argument. android/src/main/AndroidManifest.xml declares RECORD_AUDIO. android/src/main/jniLibs/ is listed in .gitignore and .pubignore, so prebuilt sherpa binaries are not part of the tracked or published package payload.
- Source: android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt; android/src/main/cpp/bridge.cpp; android/src/main/cpp/CMakeLists.txt; android/build.gradle; android/src/main/AndroidManifest.xml; .gitignore; .pubignore; native/include/flva.h.

### iOS bridge and native link

- Claim: iOS exposes an Objective-C++ method-channel plugin that calls flva.h directly, compiles the shared native core through NativeCore.mm, links vendored sherpa and onnxruntime xcframeworks via CocoaPods, and owns AVAudioEngine input tap and AVAudioSourceNode render without passing PCM to Dart.
- Evidence: FlutterLocalVoiceAgentPlugin.mm registers the same channel name flutter_local_voice_agent, serializes control on a dispatch queue, builds FlvaConfig from Dart path map keys vad/encoder/decoder/joiner/asrTokens/ttsModel/ttsTokens/ttsLexicon/llmModel, sets input_rate from AVAudioSession sample rate after requesting playAndRecord with AVAudioSessionModeDefault and preferred 48000 Hz, and on start installs an input tap calling flva_push and a render block calling flva_render. Route or format mismatch during an active session returns an audioUnavailable error instructing recreate. NativeCore.mm includes native/src/flva.cpp so the inference worker is shared with Android. flutter_local_voice_agent.podspec sets platform :ios, '13.0', vendored_frameworks Frameworks/sherpa-onnx.xcframework and Frameworks/onnxruntime.xcframework with optional flva-llm.xcframework when FLVA_ENABLE_LOCAL_LLM=1, and excludes i386 from simulator builds. ios/Frameworks/ is gitignored and pubignored. doc/capabilities.md states Swift Package Manager support is not implemented.
- Source: ios/Classes/FlutterLocalVoiceAgentPlugin.mm; ios/Classes/NativeCore.mm; ios/flutter_local_voice_agent.podspec; native/include/flva.h; .gitignore; .pubignore; doc/capabilities.md.

### Dart and example host coverage

- Claim: The Dart public facade stays platform-agnostic; production code reaches native sessions only through MethodChannelVoicePlatform on channel flutter_local_voice_agent, and the example application targets Android and iOS hosts with a catalog-driven download flow rather than manual model paths.
- Evidence: lib/flutter_local_voice_agent.dart exports agent.dart and related modules. lib/src/contracts.dart documents NativeVoicePlatform with explicit note that no audio crosses the interface. lib/src/agent.dart defaults nativePlatform to MethodChannelVoicePlatform, which invokes create/start/stop/interrupt/reply/poll/dispose and never transports PCM. example/pubspec.yaml depends on the path package only; example/lib/main.dart and voice_screen_controller.dart drive LocalVoiceAgent through VoiceScreenController with model preparation and session lifecycle. Repository glob shows example/android and example/ios platform trees; example/web/index.html is a generic Flutter bootstrap page with no plugin wiring or voice UI. example/ios/Runner/Info.plist declares NSMicrophoneUsageDescription; example/android/app/src/main/AndroidManifest.xml does not declare RECORD_AUDIO because the plugin manifest merge supplies it.
- Source: lib/flutter_local_voice_agent.dart; lib/src/contracts.dart; lib/src/agent.dart; example/pubspec.yaml; example/lib/main.dart; example/lib/voice_screen_controller.dart; example/ios/Runner/Info.plist; example/android/app/src/main/AndroidManifest.xml; example/web/index.html.

### Existing qualification evidence and open parent gates this item must not silently close

- Claim: Source, build, emulator, and host-test evidence exist for both mobile platforms, but physical speech/audio qualification, clean pub.dev-style installation, VITS internal allocation bounds, and several packaging gates from parent work items remain open and must not be treated as closed by platform-coverage research alone.
- Evidence: doc/capabilities.md records emulator verification for Android catalog download, cancel/retry, native listening state, and offline restart; states no physical Android or iPhone qualification; Android sample arm64 only; iOS simulator/device slices through CocoaPods; consumer installation requires a provisioned repository checkout; native package distribution remains unfinished; and native render bounds do not prove sherpa VITS internal whole-sentence allocation fits the intended output budget. wiki/work/0002-native-offline-pipeline/STATE.yaml remains phase implement with verdict FAIL and blockers for F3/AC-004 VITS allocation before callback, AC-005/AC-008 physical mobile offline/audio/lifecycle/performance qualification unavailable, and AC-007 clean consumer installation unqualified with native binaries excluded from pub payload. wiki/work/0002-native-offline-pipeline/05-handoff.md lists implemented Kotlin and ObjC++ bridges but states physical operating-system behavior is unqualified, no physical device was available, no simulator runtime was executed in that session, and iOS device application build or execution is not proven by simulator framework compilation alone. wiki/work/0006-example-model-catalog/STATE.yaml is document/PASS with followups explicitly preserving parent release gates including native dependency distribution, physical Android/iPhone qualification, iOS runtime verification, and VITS output allocation bound.
- Source: doc/capabilities.md; wiki/work/0002-native-offline-pipeline/STATE.yaml; wiki/work/0002-native-offline-pipeline/05-handoff.md; wiki/work/0006-example-model-catalog/STATE.yaml.

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Android plus iOS only via shared flva.h and method channel | Two platform plugin folders compile the same native/src core, each with OS audio ownership and provisioned sherpa prebuilts | Requires per-platform runtime provisioning, ABI-specific Android prebuilts, and CocoaPods xcframeworks; arm64-only Android filter | Chosen: this is the existing repository shape declared in pubspec.yaml and implemented in android/ and ios/ |
| Federated or additional Flutter plugin platforms for desktop or web | Separate plugin implementations would need new audio stacks, linking, and registration entries | High: no macos/linux/windows/web folders or pubspec entries exist today | Not present; desktop host decision deferred to another stream per work 0008 scope |
| Dart FFI direct to flva.h instead of method channel | Dart would call C ABI directly while still keeping PCM native-side | Would duplicate or replace existing MethodChannelVoicePlatform without changing the frozen Dart facade contract | Rejected for this research scope: current production path is MethodChannelVoicePlatform in agent.dart |
| Identical input sample rate on both mobile hosts | Would require resampling or forcing the same hardware rate on Android and iOS | Android bridge hardcodes 16000 Hz capture; iOS adopts AVAudioSession rate (48000 preferred) with native resampling inside flva | Not achieved today; platforms already diverge on input_rate while sharing the same C session API |

## Constraints discovered

- The flva.h C ABI is the fixed inference contract; both bridges must continue to call flva_create, flva_start, flva_push, flva_render, flva_poll, flva_reply, flva_interrupt, flva_stop, and flva_destroy without changing PCM transport through Dart.
- Prebuilt sherpa-onnx v1.12.14 runtimes are mandatory for mobile builds and are deliberately excluded from git and pub packages; builds fail or remain unqualified without tool/provision_runtime.py and host-side archives under ignored android/src/main/jniLibs/ and ios/Frameworks/.
- Android release configuration filters to arm64-v8a only; broader Android ABI or x86 emulator coverage is not implemented in build.gradle.
- Parent work 0002, 0004, 0006, and 0007 acceptance criteria remain frozen; this research must not reinterpret PASS on scoped example catalog work as closing native pipeline physical, allocation, or packaging gates.
- No commit, publication, or model redistribution is authorized; qualification claims must distinguish compile/link evidence from physical microphone-to-speaker behavior.
- iOS integration depends on CocoaPods vendored frameworks; SPM is documented as unsupported. PRD qualified duplex guidance references voice-processing AVAudioEngine, while the current iOS plugin uses AVAudioSessionModeDefault with playAndRecord.
- Half-duplex is the implemented baseline; fullDuplexRequired is rejected at both native bridges and in LocalVoiceAgent.create.

## Unresolved

- [UNRESOLVED: Whether Android and iOS currently constitute the same native session in a qualification sense given fixed 16 kHz Android capture versus dynamic iOS AVAudioSession input_rate and different OS audio stacks, even though both call the shared flva.h worker.]
- [UNRESOLVED: What exact provisioning and packaging steps are required for a fresh consumer to obtain ignored jniLibs and Frameworks artifacts and reach a running session without a maintainer checkout.]
- [UNRESOLVED: Whether iOS simulator or device runtime execution has been observed end-to-end with microphone capture and speaker output beyond compilation evidence recorded in parent work items.]
- [UNRESOLVED: Whether physical Android and iPhone sessions satisfy parent AC-005, AC-008, and related lifecycle, route-change, thermal, and cancellation gates from work 0002.]
- [UNRESOLVED: Whether F3 / AC-004 VITS whole-sentence allocation can be bounded or replaced without weakening frozen criteria.]
- [UNRESOLVED: Whether clean consumer installation (parent AC-007) can pass while native binaries remain outside the pub payload.]
- [UNRESOLVED: Whether additional Android ABIs or iOS distribution via Swift Package Manager are needed for reasonable mobile coverage; not decided in this stream.]
- [UNRESOLVED: What platform additions, if any, a later desktop host would require beyond copying the Android/iOS pattern; explicitly deferred.]

## Sources

- pubspec.yaml — consulted 2026-09-20
- lib/flutter_local_voice_agent.dart — consulted 2026-09-20
- lib/src/agent.dart — consulted 2026-09-20
- lib/src/contracts.dart — consulted 2026-09-20
- native/include/flva.h — consulted 2026-09-20
- android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt — consulted 2026-09-20
- android/src/main/cpp/bridge.cpp — consulted 2026-09-20
- android/src/main/cpp/CMakeLists.txt — consulted 2026-09-20
- android/build.gradle — consulted 2026-09-20
- android/src/main/AndroidManifest.xml — consulted 2026-09-20
- ios/Classes/FlutterLocalVoiceAgentPlugin.mm — consulted 2026-09-20
- ios/Classes/NativeCore.mm — consulted 2026-09-20
- ios/flutter_local_voice_agent.podspec — consulted 2026-09-20
- example/pubspec.yaml — consulted 2026-09-20
- example/lib/main.dart — consulted 2026-09-20
- example/lib/voice_screen_controller.dart — consulted 2026-09-20
- example/android/app/src/main/AndroidManifest.xml — consulted 2026-09-20
- example/ios/Runner/Info.plist — consulted 2026-09-20
- example/web/index.html — consulted 2026-09-20
- doc/capabilities.md — consulted 2026-09-20
- wiki/product/local-voice-agent-prd.md — consulted 2026-09-20
- wiki/work/0002-native-offline-pipeline/STATE.yaml — consulted 2026-09-20
- wiki/work/0002-native-offline-pipeline/05-handoff.md — consulted 2026-09-20
- wiki/work/0006-example-model-catalog/STATE.yaml — consulted 2026-09-20
- .gitignore — consulted 2026-09-20
- .pubignore — consulted 2026-09-20
