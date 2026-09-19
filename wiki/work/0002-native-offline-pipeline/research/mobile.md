---
id: pipeline-research-mobile
title: "Mobile feasibility research"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation work artifact and evidence boundaries.
---

# Mobile feasibility research

## Question

Can this package implement the proposed foreground, half-duplex offline audio path with native Android and iOS workers, and does this checkout presently have enough local tooling and targets to build and exercise it?

## Answer

The proposed bridge is technically feasible as a native-owned audio and inference pipeline: Android can use a communication `AudioRecord`/`AudioTrack` pair, and iOS can use a voice-processing `AVAudioEngine` configured by `AVAudioSession`. Both paths can capture hardware audio, convert it to the shared mono float32, 16 kHz inference contract, and render TTS at its native output rate without sending PCM through Dart.

This checkout does not yet contain Android or iOS host projects. Xcode 26.3, a populated Android SDK, Flutter 3.47.0/Dart 3.13.0, and iOS Simulator runtimes are installed; no physical Android or iOS device was enumerated. Native compilation and device behavior remain **[UNVERIFIED]** until a generated example app is built and run on targets that can exercise its native audio path.

## Findings

### Observed local toolchain and targets

The following read-only commands were run from the repository on 2026-09-19. Outputs are copied verbatim where they establish the result.

| Command | Output and conclusion |
|---|---|
| `xcodebuild -version` | `Xcode 26.3` and `Build version 17C529`. |
| `xcrun --sdk iphoneos --show-sdk-version` | `26.2`. The command also emitted sandbox-related FSEvents/cache warnings, but returned the SDK version. |
| `swift --version` | `Apple Swift version 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)` targeting `arm64-apple-macosx26.0`. |
| `pod --version` | `1.16.2`. |
| `java -version` | `openjdk version "21.0.11" 2026-04-21`; `OpenJDK Runtime Environment JBR-21.0.11+10-1163.116`. |
| `adb version` | `Android Debug Bridge version 1.0.41`, `Version 37.0.1-15733141`, installed at `/Users/ortalcohen/Library/Android/sdk/platform-tools/adb`. |
| Android-SDK directory inventory | Installed build tools include 30.0.3, 33.0.1, 34.0.0, 35.0.0, 36.0.0 and 36.1.0; platforms include 28, 31, 33, 34, 35, 36, 36.1 and 37.0; installed NDKs include 25.1.8937393, 26.3.11579264, 27.0.11718014, 27.0.12077973 and 28.2.13676358. |
| `/Users/ortalcohen/fvm/versions/3.47.0` Git metadata | `3.47.0`; commit `4cf24164269a5ebf0c16a028a00727d0e77bbb05`; dated `2026-08-11`; engine stamp `5f77625673248ee5846fbcaf5d3e1a3878386fd7`. This matches the package lower Flutter bound in `pubspec.yaml` (`>=3.47.0`). |
| `/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter --version` | `Flutter 3.47.0 • channel [user-branch]`; framework revision `4cf2416426`; engine revision `59d54a2b2896a6bbf356c94b7fac7b9e235bdacd`; `Tools • Dart 3.13.0 • DevTools 2.60.0`. |
| `/Users/ortalcohen/fvm/versions/3.47.0/bin/dart --version` | `Dart SDK version: 3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "macos_arm64"`. |
| `adb devices -l` | Exact output: `List of devices attached` followed by no device rows. No Android device or emulator is attached. |
| `xcrun simctl list devices available` | Available, shutdown iOS simulators were returned for iOS 17.2, 18.2 and 26.3. Representative exact rows: `iPhone 15 Pro (5F81B3CD-1A5A-4819-8740-32E7D8E67E42) (Shutdown)` on iOS 17.2; `iPhone 16 Pro (FAC0F49A-F1C0-4504-B063-C6CDEA2ABB05) (Shutdown)` on iOS 18.2; `iPhone 17 Pro (27C93D77-4D20-4F1E-BF66-92C77FF9FE05) (Shutdown)` on iOS 26.3. |
| `xcrun devicectl list devices` | Exact output: `No devices found.` No physical Apple device is connected. |
| Host-project inventory | `No android/ or ios/ directories are present in this package skeleton.` No native Gradle, Podfile, manifest, or Info.plist configuration currently exists to inspect. |

There is therefore evidence of installed compilers and SDKs, but not a successful package build, attached Android device, available iOS simulator, microphone permission prompt, native audio route, or real-device audio behavior.

### Minimal Android bridge

Kotlin owns permissions, audio focus, routing and the lifecycle of one `AudioRecord`, one `AudioTrack`, preallocated rings, and the native engine handle. Use `AudioRecord.Builder` with `MediaRecorder.AudioSource.VOICE_COMMUNICATION`, mono input and an explicitly recorded hardware format; use `AudioTrack.Builder` with `AudioAttributes.USAGE_VOICE_COMMUNICATION`, speech content and streaming transfer mode. Obtain and retain the actual configured rate/channel/encoding after construction; convert capture on a dedicated native worker to mono float32 at 16 kHz, preserving resampler phase and marking discontinuities. Feed bounded input blocks to VAD/ASR only from that worker.

The renderer consumes the TTS engine's native-rate float32 blocks from a separate bounded queue and writes them to `AudioTrack` from its renderer worker. It must not resample TTS to 16 kHz merely to satisfy the recognition contract. The capture and renderer path contains no Dart invocation, allocation, lock acquisition, model loading, synchronous logging, or unbounded wait. Platform channels carry only session controls and bounded status: permission result, route epoch, focus/interruption state, native error, transcript/state and sampled metrics. A versioned C ABI provides opaque session handles and matching destroy calls for inference workers; it does not expose an unbounded PCM channel to Dart.

Android requires `RECORD_AUDIO` runtime permission. The MVP remains foreground-only. A future microphone continuation service needs the required foreground-service type, permissions and an ongoing notification; it must observe while-in-use restrictions. Request audio focus only while the visible activity or a valid foreground service meets the platform rules, and use `setCommunicationDevice` plus device callbacks for communication routing where supported. `AcousticEchoCanceler` is a capability probe tied to the `AudioRecord` session; do not report effective AEC solely because the API is present. [Android AudioRecord](https://developer.android.com/reference/android/media/AudioRecord), [Android AudioTrack](https://developer.android.com/reference/android/media/AudioTrack), [Android AEC](https://developer.android.com/reference/android/media/audiofx/AcousticEchoCanceler), [audio focus](https://developer.android.com/media/optimize/audio-focus), [microphone foreground service](https://developer.android.com/develop/background-work/services/fgs/service-types).

### Minimal iOS bridge

Swift owns an app-wide `AVAudioSession` and one `AVAudioEngine` session. On explicit user start, request recording permission, set the session category to `playAndRecord`, set mode to `voiceChat`, activate it, enable voice processing on the engine input node, then start the engine. Install the input tap only to copy callback samples into a preallocated bounded capture ring. A native worker converts the hardware stream to the common mono float32 16 kHz blocks and supplies VAD/ASR. The capture callback does not invoke Dart or inference directly.

Attach an `AVAudioPlayerNode` to the engine and schedule `AVAudioPCMBuffer` blocks matching the TTS engine's native rate and channel format. A renderer worker owns buffer preparation and schedules only the current generation. This preserves a separate recognition rate and playback rate. `voiceChat` alone is insufficient for voice-specific processing; Apple documents Voice I/O or `AVAudioEngine` voice processing as the path that enables features such as echo cancellation and automatic gain control.

The iOS host needs `NSMicrophoneUsageDescription`. `AVAudioSession` is app-wide, so the plugin must coordinate session ownership with the host and other audio plugins rather than repeatedly resetting a shared session. Background audio entitlement/configuration is outside this foreground MVP and is not evidence that inference or listening can continue after suspension or termination. [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession), [voiceChat](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat), [microphone usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription).

### Lifetime, half-duplex, and system-event contract

Half-duplex is a deliberate MVP control rule, not an assumption that hardware cannot record and play simultaneously. On user stop, final recognition, interruption, focus loss, route change, thermal admission refusal, or barge-in policy action: advance the turn generation first; the renderer rejects the older generation immediately and drops queued playback; then request cancellation of TTS/language/ASR work; then stop producers and join workers; only after callbacks are quiescent may native queues, engine handles and Dart callback handles be freed. A failed or timed-out worker keeps its referenced resources quarantined and produces an explicit failed-disposal state; a timeout is never permission to free live memory.

| Event | Required bridge behavior |
|---|---|
| Android permission denied/revoked | Do not open or immediately stop `AudioRecord`; invalidate generation, stop native producers, expose typed status. |
| Android transient/permanent focus loss | Suspend or stop according to focus result; gate playback immediately; do not auto-resume after permanent loss without explicit user intent. |
| Android communication-device change | Increment route epoch; stop/reopen affected native streams; reset resampler and AEC state; validate actual format; discard old-ring data. |
| iOS interruption begins | Deactivate logical turn immediately, gate scheduled/queued speech, pause capture/rendering, request worker cancellation. |
| iOS interruption ends | Recheck user intent, permission, route and session activation; resume only when the interruption options and app state make it appropriate. |
| iOS route disconnect/change | Increment route epoch; pause private speech when a headset disappears; rebuild format-dependent nodes before a new turn. |
| iOS media-services loss/reset | Treat current resources as invalid; gate output and rebuild session/engine only after workers have stopped. |
| Thermal/low-resource state | Do not free active resources. Reject or defer new heavy turns, reduce optional work, and record the reason; recovery and thresholds remain **[UNVERIFIED]** until device tests. |

Apple documents interruption and route notifications, including the route-change reason and the `shouldResume` signal; it also documents that the system can suspend an app. [Handling interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), [route-change notification](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification), [thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property). The earlier mobile systems research supplies the corresponding Android lifecycle, Bluetooth and disposal evidence in `wiki/work/0001-local-voice-agent-architecture/research/mobile-systems.md`.

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Native `AudioRecord`/`AudioTrack` and voice-processing `AVAudioEngine` | Platform audio objects feed native worker queues; Dart receives control/status only. | Project-owned Kotlin/Swift lifecycle work and a real-device qualification matrix. | **Chosen for the first spike.** It directly accommodates route events, focus/session ownership, separate capture/playback rates and bounded PCM ownership. |
| PCM over Flutter EventChannel | Native callbacks send microphone blocks to Dart, which returns playback. | Isolate scheduling, copied/borrowed-buffer lifetime, callback pressure and unbounded listener-risk. | Rejected as the authoritative audio path; it conflicts with the shared native-worker and bounded-queue design. |
| Oboe on Android | C++ low-latency stream abstraction. | Extra packaging and an AEC/routing strategy separate from `AudioRecord` session effects. | Deferred until the baseline communication path has real-device AEC and route evidence. |
| Full-duplex barge-in | Capture and playback run together, with echo qualification and user-interruption policy. | Highest acoustic, cancellation and device/route test burden. | Out of the MVP shared design; revisit only with qualification evidence. |

## Constraints discovered

- The package is currently a library skeleton. A future example/host project must add Android manifest permissions, iOS microphone purpose text, Gradle/Pod build configuration and platform lifecycle code before native compilation is meaningful.
- The repository declares Dart `^3.13.0` and Flutter `>=3.47.0`; the selected local FVM toolchain successfully reports Flutter 3.47.0 and Dart 3.13.0. A real package build remains **[UNVERIFIED]** because the package has no native host project yet and no build was requested in this research task.
- Candidate deployment floors are Android API 26 on arm64 and iOS 16 on arm64 in the PRD, both **[UNVERIFIED]** against selected runtimes and native build flags. Android platform 28 is locally installed, which is sufficient to compile an app whose `minSdk` is 26; the final compile and target SDK still require an explicit project decision. This is a local tool-inventory fact, not a decision to change the floor.
- No native inference runtime, model pack, or model-license bill of materials is present. This research establishes bridge feasibility only; it does not approve an engine, model, voice, redistribution, latency, quality, memory, power, route, AEC or store-compliance claim.
- A simulator is insufficient for microphone/AEC/Bluetooth/thermal/foreground-service qualification even when it becomes available; require physical Android and iOS devices for those gates.

## Unresolved

- [UNRESOLVED: Which generated host/example will own the Android manifest, iOS Info.plist, Gradle/Pod targets, and native sources?]
- [UNRESOLVED: Which exact Android compile/target SDK, NDK, AGP, Kotlin, Xcode and CocoaPods compatibility matrix will be pinned?]
- [UNRESOLVED: Which physical Android device tiers, iPhone generations, OS versions and headset/Bluetooth routes form the release qualification matrix?]
- [UNRESOLVED: Do selected ASR/TTS engines accept and cancel the proposed float32 framing on both targets within the future latency and memory budgets?]
- [UNRESOLVED: Does the AudioRecord communication path deliver acceptable speakerphone AEC for every supported route/device, and what is the fallback when it does not?]
- [UNRESOLVED: What bounded queue capacities, overflow policies and join-timeout/quarantine policy meet the eventual device measurements?]

## Sources

- Local commands listed in “Observed local toolchain and targets”, consulted 2026-09-19.
- `pubspec.yaml`, consulted 2026-09-19.
- `wiki/product/local-voice-agent-prd.md`, consulted 2026-09-19.
- `wiki/work/0001-local-voice-agent-architecture/research/mobile-systems.md`, consulted 2026-09-19.
- [Android AudioRecord](https://developer.android.com/reference/android/media/AudioRecord), [Android AudioTrack](https://developer.android.com/reference/android/media/AudioTrack), [Android audio focus](https://developer.android.com/media/optimize/audio-focus), and [Android microphone foreground services](https://developer.android.com/develop/background-work/services/fgs/service-types), consulted 2026-09-19.
- [Apple AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession), [voiceChat](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat), [handling interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), and [route changes](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification), consulted 2026-09-19.

## Availability clarification

Research F-002: The approved enumeration establishes shutdown simulators are installed and available. Earlier sandbox-only passages describe that initial invocation, not final simulator availability. No simulator build or physical run was performed by this research report.
