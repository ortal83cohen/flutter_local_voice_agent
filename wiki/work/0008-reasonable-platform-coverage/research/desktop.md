# Research: desktop platform coverage for the existing offline voice pipeline

## Question

Can macOS, Windows and Linux host the existing offline voice pipeline with a reasonable implementation that reuses native/include/flva.h and the native worker, adding only OS audio, permission or lifecycle handling, and native linking?

## Answer

Yes, conditionally, for all three desktop targets. The pinned sherpa-onnx v1.12.14 release publishes shared CPU libraries for macOS universal2, Linux x64 and Windows x64; the repository already exercises the same C ABI and worker on a macOS host with WAV fixtures. None of the three Flutter desktop plugin folders exist in this checkout yet, and tool/provision_runtime.py provisions only Android and iOS. macOS is the lowest-friction first desktop because the host already qualifies sherpa there and AVAudioEngine is available on macOS, but the current iOS bridge cannot be copied verbatim because AVAudioSession is not available on native macOS.

## Findings

### Repository baseline and shared design boundary

- Claim: The stable integration surface is the C ABI in native/include/flva.h. Capture enters through flva_push with mono float32 PCM at a declared input rate between 8000 and 192000 Hz; playback leaves through flva_render as mono float32 at the session output rate; control and events stay off Dart PCM paths.
- Evidence: native/include/flva.h documents FlvaConfig.input_rate, flva_push, flva_render, and the requirement that audio callbacks be quiescent before flva_destroy. native/src/flva.cpp implements resampling to 16 kHz VAD windows and links sherpa-onnx through the existing worker.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/include/flva.h, /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src/flva.cpp

- Claim: Android and iOS are the only registered Flutter plugin platforms today. There are no macos/, windows/ or linux/ directories under the plugin package root in this checkout.
- Evidence: pubspec.yaml lists only android and ios under flutter.plugin.platforms. Glob searches for macos/**, windows/** and linux/** under the repository root returned zero plugin-package matches.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/pubspec.yaml

- Claim: Runtime provisioning is build-time only and currently limited to Android arm64-v8a and iOS xcframework slices.
- Evidence: tool/provision_runtime.py ASSETS keys are android and ios only; Android CMakeLists.txt imports libsherpa-onnx-c-api.so from jniLibs; ios/flutter_local_voice_agent.podspec vendored_frameworks lists sherpa-onnx.xcframework and onnxruntime.xcframework.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py, /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/android/src/main/cpp/CMakeLists.txt, /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/ios/flutter_local_voice_agent.podspec

- Claim: Optional llama.cpp remains optional and CPU-only, wired through native/llm/CMakeLists.txt with GGML_METAL, GGML_BLAS and GGML_ACCELERATE forced OFF.
- Evidence: native/llm/CMakeLists.txt gates on FLVA_ENABLE_LOCAL_LLM and links a static flva_llm_adapter against llama when LLAMA_CPP_SOURCE_DIR is set. wiki/work/0002-native-offline-pipeline/04-verification.md records a successful macOS host llama smoke build with CPU cancellation evidence.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/llm/CMakeLists.txt, /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/04-verification.md

- Claim: Physical acoustic qualification is out of scope for this compile-capability research; doc/capabilities.md already separates emulator or host WAV evidence from microphone or speaker qualification.
- Evidence: doc/capabilities.md states no physical Android/iPhone qualification and that emulator verification does not include physical speech or audio qualification.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/doc/capabilities.md

### macOS

- Claim: Flutter macOS plugins register through a macos/ platform folder, declared in pubspec.yaml with a macos.pluginClass entry, and built through CocoaPods and/or Swift Package Manager inside the macOS Runner workspace.
- Evidence: Flutter developing-packages documentation shows macos: pluginClass: HelloPlugin in pubspec.yaml, instructs authors to add macos platform code under macos/Classes, and to open hello/example/macos/Runner.xcworkspace after flutter build macos --config-only. Swift Package Manager for plugin authors states macOS plugin folders mirror iOS and that Flutter 3.44+ enables SPM by default while CocoaPods remains supported.
- Source: https://docs.flutter.dev/packages-and-plugins/developing-packages (consulted 2026-09-20), https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors (consulted 2026-09-20)

- Claim: A concrete capture and playback path is AVAudioEngine with an input tap and a render source node feeding mono float32 PCM into flva_push and reading flva_render output, matching the existing iOS pattern in ios/Classes/FlutterLocalVoiceAgentPlugin.mm but without UIKit or AVAudioSession.
- Evidence: Apple documents AVAudioEngine availability on macOS 10.10+. The iOS plugin already uses AVAudioEngine inputNode installTapOnBus with AVAudioPCMFormatFloat32 and an AVAudioSourceNode renderBlock that calls flva_push and flva_render. Apple documents AVAudioSession availability for iOS, iPadOS, macCatalyst, tvOS, visionOS and watchOS only, not native macOS, so a macOS bridge must omit AVAudioSession category, interruption and route notifications used by the iOS file.
- Source: https://developer.apple.com/documentation/avfaudio/avaudioengine (consulted 2026-09-20), /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/ios/Classes/FlutterLocalVoiceAgentPlugin.mm, https://developer.apple.com/documentation/avfaudio/avaudiosession (consulted 2026-09-20)

- Claim: Microphone permission on macOS uses AVCaptureDevice.requestAccess(for:completionHandler:) plus NSMicrophoneUsageDescription in the app Info.plist.
- Evidence: Apple documents requestAccess(for:completionHandler:) availability including macOS 10.14.0+. The iOS bridge already depends on NSMicrophoneUsageDescription for microphone access on Apple platforms.
- Source: https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:) (consulted 2026-09-20), https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription (consulted 2026-09-20), wiki/work/0002-native-offline-pipeline/research/mobile.md

- Claim: sherpa-onnx v1.12.14 links on macOS through the published osx-universal2 shared archive or xcframework static bundle; this repository already loaded the shared macOS runtime in host qualification.
- Evidence: GitHub release v1.12.14 lists sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2, sherpa-onnx-v1.12.14-macos-xcframework-static.tar.bz2 and related osx archives. wiki/work/0002-native-offline-pipeline/research/provisioning.md records successful load of libsherpa-onnx-c-api.dylib from the universal2 shared archive on a macOS host fixture.
- Source: https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.14 (consulted 2026-09-20), /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/research/provisioning.md

- Claim: Optional llama.cpp can follow the same native/llm CMake path already proven on the macOS host in work item 0002 verification.
- Evidence: llama.cpp upstream README points authors to docs/build.md for source builds across platforms. Repository verification built flva_llm_smoke on macOS with FLVA_ENABLE_LOCAL_LLM and a pinned LLAMA_CPP_SOURCE_DIR.
- Source: https://github.com/ggerganov/llama.cpp/blob/master/README.md (consulted 2026-09-20), /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/04-verification.md

- Claim: Permission, focus, route-change and lifecycle analogues on macOS are only partly mappable from the mobile bridge. Foreground gating can use NSApplicationWillResignActiveNotification or equivalent app-active checks; route changes need CoreAudio default-device property listeners rather than AVAudioSessionRouteChangeNotification; interruption semantics have no AVAudioSession counterpart on native macOS.
- Evidence: ios/Classes/FlutterLocalVoiceAgentPlugin.mm suspends on UIApplicationWillResignActiveNotification, AVAudioSessionInterruptionNotification, AVAudioSessionRouteChangeNotification, AVAudioSessionMediaServicesWereResetNotification and NSProcessInfoThermalStateDidChangeNotification. AVAudioSession interruption and route notifications are not documented for native macOS in the availability blocks consulted.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/ios/Classes/FlutterLocalVoiceAgentPlugin.mm, https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification (consulted 2026-09-20)

- Claim: Reasonableness verdict for macOS is yes, conditional. The cheapest blocker is creating the macos plugin scaffold, extending provisioning with a pinned macOS sherpa archive digest, and rewriting the iOS AVAudioSession-centric lifecycle for native macOS while keeping AVAudioEngine PCM plumbing and the existing flva.cpp inclusion pattern used by ios/Classes/NativeCore.mm.
- Evidence: Host sherpa qualification exists; Flutter plugin registration path is documented; iOS audio PCM pattern is present but tied to UIKit and AVAudioSession APIs absent on macOS.
- Source: findings above

- Claim: Minimum macOS version for Flutter desktop support in current Flutter documentation is Monterey (12) through the documented supported range; AVAudioEngine requires macOS 10.10+ per Apple.
- Evidence: Flutter supported-platforms lists macOS supported as Monterey (12) to Golden Gate (27). Apple AVAudioEngine availability begins macOS 10.10.0.
- Source: https://docs.flutter.dev/reference/supported-platforms (consulted 2026-09-20), https://developer.apple.com/documentation/avfaudio/avaudioengine (consulted 2026-09-20)

### Windows

- Claim: Flutter Windows plugins register through a windows/ folder with C++ sources integrated by CMake, a pluginClass entry in pubspec.yaml, and registration through the generated RegisterPlugins path used by the Windows runner.
- Evidence: Flutter developing-packages documentation describes Step 2f Windows platform code with hello/example/build/windows/hello_example.sln and plugin sources under hello_plugin. Flutter platform-channels documentation shows RegisterPlugins and flutter::MethodChannel setup in the Windows runner after flutter build windows.
- Source: https://docs.flutter.dev/packages-and-plugins/developing-packages (consulted 2026-09-20), https://docs.flutter.dev/platform-integration/platform-channels (consulted 2026-09-20)

- Claim: A concrete capture and playback API is WASAPI through IAudioClient initialized in shared mode, with IAudioCaptureClient for microphone input and IAudioRenderClient for speaker output, converting device PCM to mono float32 for flva_push and writing flva_render samples back to the render buffer.
- Evidence: Microsoft documents WASAPI as the Windows Audio Session API for moving audio between applications and endpoint devices, with IAudioCaptureClient reading capture endpoint buffers and IAudioRenderClient writing rendering endpoint buffers. Capturing a Stream documentation describes the GetBuffer and ReleaseBuffer cycle on IAudioCaptureClient.
- Source: https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi (consulted 2026-09-20), https://learn.microsoft.com/en-us/windows/win32/coreaudio/capturing-a-stream (consulted 2026-09-20)

- Claim: sherpa-onnx v1.12.14 publishes Windows x64 shared and static CPU archives suitable for CMake IMPORTED target linking similar to android/src/main/cpp/CMakeLists.txt.
- Evidence: GitHub release v1.12.14 lists sherpa-onnx-v1.12.14-win-x64-shared.tar.bz2, sherpa-onnx-v1.12.14-win-x64-static-no-tts.tar.bz2 and sherpa-onnx-v1.12.14-win-x64-jni.tar.bz2. sherpa-onnx README supported-platforms table marks Windows x64 and arm64 as supported.
- Source: https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.14 (consulted 2026-09-20), https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/README.md (consulted 2026-09-20)

- Claim: Optional llama.cpp can be linked through the existing native/llm CMake adapter on Windows with CPU backends only, following the same FLVA_ENABLE_LOCAL_LLM gate used on Android and the macOS host smoke path.
- Evidence: llama.cpp README documents platform build guidance through docs/build.md. native/llm/CMakeLists.txt disables GPU-oriented GGML backends and builds a static adapter when enabled.
- Source: https://github.com/ggerganov/llama.cpp/blob/master/README.md (consulted 2026-09-20), /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/llm/CMakeLists.txt

- Claim: Windows desktop apps lack Android-style audio focus. WASAPI session disconnect or AUDCLNT_E_DEVICE_INVALIDATED is the documented invalid-device recovery signal. A Flutter Windows runner is a Win32 host, so UWP DeviceCapability is not established as the plugin permission path. Start must map capture-open denial to a typed permission or audio failure.
- Evidence: WASAPI documentation states many methods return AUDCLNT_E_DEVICE_INVALIDATED when the endpoint becomes invalid. The UWP DeviceCapability schema exists but describes a different application class from the Flutter Win32 runner. Flutter Windows building documentation describes Win32 host customization and MSIX packaging and does not document that UWP element as the required microphone declaration.
- Source: https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi (consulted 2026-09-20), https://docs.flutter.dev/platform-integration/windows/building (consulted 2026-09-20). The UWP schema remains a non-authoritative contrast, not a selected contract.

- Claim: Reasonableness verdict for Windows is yes, conditional. The cheapest blocker is absence of any windows/ plugin scaffold, no pinned Windows runtime row in tool/provision_runtime.py, and no repository host verification that the Windows sherpa shared library links cleanly beside flva.cpp in a Flutter plugin CMake graph on a Windows CI or developer machine.
- Evidence: Repository inventory and provisioning scope findings above; no Windows build evidence in wiki/work/0002-native-offline-pipeline verification artifacts consulted.
- Source: findings above

- Claim: Minimum Windows version for current Flutter desktop support is Windows 10 and 11 per Flutter supported-platforms; exact WASAPI float32 mix format support for a chosen endpoint remains device-dependent and was not exercised in this checkout.
- Evidence: Flutter supported-platforms lists Windows supported as 10 and 11 with x64 and Arm64 architectures.
- Source: https://docs.flutter.dev/reference/supported-platforms (consulted 2026-09-20)

### Linux

- Claim: Flutter Linux plugins register through a linux/ folder with C++ sources built by CMake, a pluginClass entry in pubspec.yaml, and FlMethodChannel handlers registered from the plugin registrar generated into the Linux runner build.
- Evidence: Flutter developing-packages Step 2d describes linux platform code located under flutter/ephemeral/.plugin_symlinks/hello/linux after flutter build linux. Platform-channels documentation shows fl_method_channel_new and fl_method_channel_set_method_call_handler in the Linux runner after fl_register_plugins.
- Source: https://docs.flutter.dev/packages-and-plugins/developing-packages (consulted 2026-09-20), https://docs.flutter.dev/platform-integration/platform-channels (consulted 2026-09-20)

- Claim: A concrete capture and playback API is the PulseAudio asynchronous client: connect a record stream and a playback stream, using float32 frames or converting to mono float32 before flva_push and after flva_render. PipeWire exposes PulseAudio-compatible client sockets on current Flutter-supported Debian and Ubuntu releases, so PulseAudio client code remains the most portable first implementation.
- Evidence: PipeWire overview documentation states clients may speak to the server through a PulseAudio-compatible path and that session management is delegated to a separate daemon such as WirePlumber on typical desktops. The previously cited PulseAudio stream header page was not independently retrievable on 2026-09-20 because the host returned a bot challenge. Treat the exact function names as [UNVERIFIED] against that URL until a reachable header or man page is recorded during implementation.
- Source: https://docs.pipewire.org/page_overview.html (consulted 2026-09-20)

- Claim: sherpa-onnx v1.12.14 publishes Linux x64 shared CPU archives and JNI variants suitable for CMake IMPORTED libraries like the Android bridge.
- Evidence: GitHub release v1.12.14 lists sherpa-onnx-v1.12.14-linux-x64-shared.tar.bz2 and sherpa-onnx-v1.12.14-linux-x64-jni.tar.bz2 among many Linux architecture builds. sherpa-onnx README supported-platforms table marks Linux x64 and arm64 as supported.
- Source: https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.14 (consulted 2026-09-20), https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/README.md (consulted 2026-09-20)

- Claim: Optional llama.cpp can reuse native/llm/CMakeLists.txt on Linux with CPU-only settings; no Metal or Accelerate linkage is required.
- Evidence: native/llm/CMakeLists.txt explicitly turns off GGML_METAL, GGML_ACCELERATE and GGML_BLAS before add_subdirectory on llama.cpp.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/llm/CMakeLists.txt, https://github.com/ggerganov/llama.cpp/blob/master/README.md (consulted 2026-09-20)

- Claim: Linux has no Android-style runtime RECORD_AUDIO permission. Lifecycle analogues are desktop session events: PipeWire or PulseAudio stream errors, server disconnect, and default-device changes surfaced through PulseAudio subscription callbacks or PipeWire session-manager events. Mapping these to the existing suspended event codes used by Android and iOS bridges is straightforward in principle but not yet specified in this repository.
- Evidence: doc/capabilities.md and mobile bridge research define suspended codes such as routeChanged, interrupted and background for mobile OS events. No Linux desktop lifecycle table exists in the repository.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/doc/capabilities.md, /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/research/mobile.md

- Claim: Reasonableness verdict for Linux is yes, conditional. The cheapest blocker is desktop audio-stack heterogeneity across PulseAudio-only, PipeWire-with-Pulse-compat and rare ALSA-only setups, combined with missing linux/ plugin scaffold and missing pinned Linux runtime provisioning in tool/provision_runtime.py.
- Evidence: PipeWire overview documents multiple client protocols and external session management. Repository lacks linux/ platform folder and Linux provisioning keys.
- Source: findings above

- Claim: Minimum Linux versions for current Flutter desktop support are Debian 10–13 and Ubuntu 20.04 LTS–24.04 LTS per Flutter supported-platforms.
- Evidence: Flutter supported-platforms lists those distributions as supported deploy targets for Linux x64 and Arm64.
- Source: https://docs.flutter.dev/reference/supported-platforms (consulted 2026-09-20)

### Cross-platform engine and prior architecture research

- Claim: Prior architecture research already treated desktop as optional and noted sherpa-onnx Flutter examples spanning Android, iOS, Linux, macOS and Windows without elevating desktop above mobile delivery priority.
- Evidence: wiki/work/0001-local-voice-agent-architecture/research/speech.md states sherpa-onnx Flutter examples list Android, iOS, Linux, macOS and Windows. wiki/work/0001-local-voice-agent-architecture/research/intelligence-tts.md scopes desktop as optional relative to Android and iOS first-class targets.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0001-local-voice-agent-architecture/research/speech.md, /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0001-local-voice-agent-architecture/research/intelligence-tts.md

- Claim: Host macOS sherpa qualification proves engine load and WAV-based ASR and TTS on macOS only; it does not prove Flutter plugin registration, live microphone capture, or the flva C worker with callback cancellation under desktop audio.
- Evidence: wiki/work/0002-native-offline-pipeline/research/provisioning.md states the macOS host fixture does not prove the project bridge, Android or iOS packaging, device audio, or cancellation latency.
- Source: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/research/provisioning.md

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Add macOS, Windows and Linux together in the first desktop tranche | Extend pubspec.yaml, add three platform folders, extend provisioning for three pinned sherpa archives, implement three audio bridges and one CMake or podspec linking story per OS | Highest implementation and CI surface before any desktop microphone evidence; triples packaging and lifecycle specification work | Rejected for this stream as the first increment because the repository has macOS host engine evidence only and zero desktop plugin scaffolds |
| Add macOS only first | Reuse flva.h and native/src via a macos/ plugin, AVAudioEngine PCM path, CocoaPods or SPM vendored sherpa like iOS, extend tool/provision_runtime.py with the already-qualified osx-universal2-shared digest | Lowest incremental cost on the current macOS host; unblocks desktop dev workflows without Windows or Linux CI matrices | Chosen for this stream because it reuses existing host qualification and closest Darwin audio patterns while keeping Android and iOS first-class |
| Defer all desktop | Stay on Android and iOS until mobile qualification closes | Avoids desktop lifecycle and packaging scope entirely | Rejected because upstream sherpa desktop artifacts, Flutter desktop plugin registration, and the stable flva C ABI make compile-capable desktop delivery reasonable once mobile remains primary |

The parent planner may override this stream’s choice.

## Constraints discovered

- The flva C ABI and native worker are fixed; desktop work may add platform bridges and linking only, not a new inference engine or Dart PCM transport.
- tool/provision_runtime.py must gain explicit pinned SHA-256 rows for any desktop sherpa archive before desktop builds can fail closed the way Android and iOS already do.
- iOS/Classes/FlutterLocalVoiceAgentPlugin.mm is UIKit and AVAudioSession based and is not a drop-in macOS implementation despite shared AVAudioEngine PCM mechanics.
- Optional llama.cpp must remain CPU-only with the same CMake gates as native/llm/CMakeLists.txt; GPU backends are out of scope.
- Physical microphone, speaker, latency and echo behavior remain later evidence categories and must not be treated as compile blockers in this research.
- Consumer pub distribution of native runtimes remains unfinished per README.md; desktop does not remove that packaging gap.
- Flutter desktop minimums consulted: macOS Monterey (12)+, Windows 10+, Debian 10+ / Ubuntu 20.04 LTS+.

## Unresolved

- [UNRESOLVED: Exact pinned SHA-256 digests and on-disk layout for sherpa-onnx-v1.12.14-linux-x64-shared.tar.bz2 and sherpa-onnx-v1.12.14-win-x64-shared.tar.bz2 in tool/provision_runtime.py, analogous to the existing Android and iOS entries.]
- [UNRESOLVED: Whether macOS desktop should use CocoaPods vendored dylibs like iOS, the sherpa-onnx-v1.12.14-macos-xcframework-static.tar.bz2 bundle, or a hybrid shared-library layout matching host qualification.]
- [UNRESOLVED: CoreAudio property-listener mapping for macOS default input and output device changes to the existing routeChanged suspended code, without AVAudioSession.]
- [UNRESOLVED: Windows shared-mode WASAPI mix format negotiation for mono float32 at arbitrary device rates versus resampling inside flva only after format verification on physical hardware.]
- [UNRESOLVED: Linux desktop permission behavior under xdg-desktop-portal or PipeWire session-manager prompts when opening a record stream; no repository or upstream test was run in this stream.]
- [UNRESOLVED: Whether NSProcessInfo thermalState thresholds used on iOS have a supported macOS analogue worth wiring into the same thermalPressure suspended code.]
- [UNRESOLVED: Windows and Linux host builds linking flva.cpp plus optional flva_llm_adapter have not been executed in this repository checkout.]
- [UNRESOLVED: Distribution and ONNX Runtime notice inventory for desktop sherpa packages before any publication decision, matching the open gate noted in provisioning research.]

## Sources

- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/include/flva.h — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src/flva.cpp — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/llm/CMakeLists.txt — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/pubspec.yaml — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/tool/provision_runtime.py — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/android/src/main/cpp/CMakeLists.txt — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/android/src/main/cpp/bridge.cpp — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/ios/flutter_local_voice_agent.podspec — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/ios/Classes/FlutterLocalVoiceAgentPlugin.mm — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/ios/Classes/NativeCore.mm — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/doc/capabilities.md — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/README.md — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0001-local-voice-agent-architecture/research/speech.md — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0001-local-voice-agent-architecture/research/intelligence-tts.md — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/research/speech.md — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/research/mobile.md — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/research/provisioning.md — consulted 2026-09-20
- /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/wiki/work/0002-native-offline-pipeline/04-verification.md — consulted 2026-09-20
- https://docs.flutter.dev/packages-and-plugins/developing-packages — consulted 2026-09-20
- https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors — consulted 2026-09-20
- https://docs.flutter.dev/platform-integration/platform-channels — consulted 2026-09-20
- https://docs.flutter.dev/reference/supported-platforms — consulted 2026-09-20
- https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.12.14 — consulted 2026-09-20
- https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/README.md — consulted 2026-09-20
- https://github.com/ggerganov/llama.cpp/blob/master/README.md — consulted 2026-09-20
- https://developer.apple.com/documentation/avfaudio/avaudioengine — consulted 2026-09-20
- https://developer.apple.com/documentation/avfaudio/avaudiosession — consulted 2026-09-20
- https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification — consulted 2026-09-20
- https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:) — consulted 2026-09-20
- https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription — consulted 2026-09-20
- https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi — consulted 2026-09-20
- https://learn.microsoft.com/en-us/windows/win32/coreaudio/capturing-a-stream — consulted 2026-09-20
- https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-f-devicecapability — consulted 2026-09-20
- https://www.freedesktop.org/software/pulseaudio/doxygen/stream_8h.html — consulted 2026-09-20
- https://docs.pipewire.org/page_overview.html — consulted 2026-09-20
