# Plan: Reasonable platform coverage for the existing offline pipeline

## Goal

A host using the existing Dart facade can create the same offline native session on Android, iOS, macOS, Windows and Linux. A host on Flutter web or another excluded target receives a typed unsupported-profile failure before native loading. Parent allocation, physical-device and consumer-packaging gates remain open and are not claimed closed.

## Approach

Keep the C ABI, native worker, method-channel control names and Dart public types unchanged. Treat platform work as OS audio ownership plus build-time linking of the already pinned sherpa-onnx v1.12.14 CPU runtime. Do not send microphone or playback samples through Dart.

Android and iOS stay as they are. This item does not retune mobile sample rates, add Android ABIs, enable iOS Swift Package Manager, or change the iOS session mode. Those remain parent work.

Add three desktop plugin registrations. macOS uses AVAudioEngine for capture and render, AVCaptureDevice for microphone permission, and CoreAudio default-device listeners for route loss. If microphone permission is denied, start fails with permissionDenied and capture is not started. Windows uses WASAPI shared-mode capture and render clients, treats device invalidation as an audio or route failure, and maps capture-open denial to permissionDenied. Linux uses PulseAudio client record and playback streams, which also cover PipeWire hosts that expose Pulse compatibility, and maps portal or server record denial to permissionDenied. All three call the existing create, start, push, render, poll, reply, interrupt, stop and destroy entry points. Desktop audio-callback logs may emit counters, return codes and bounded text. They must not emit raw PCM samples or waveforms.

Extend the build-time provisioning script with one pinned archive per new platform. Fail closed on digest mismatch, the same way Android and iOS already fail. macOS uses the official sherpa-onnx v1.12.14 osx-universal2-shared archive already measured in work 0002 provisioning research, digest 7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413. The macOS plugin is a CocoaPods target that compiles the shared native sources and vendors the extracted libsherpa-onnx-c-api and onnxruntime dylibs. The macos xcframework static bundle is not used. Windows and Linux use CMake imported targets against the official v1.12.14 win-x64-shared and linux-x64-shared archives. Those two archive digests are measured during implementation and then pinned.

Generate example desktop hosts so the existing catalog example can be built on macOS here. Windows and Linux example folders are required source, but a successful Flutter desktop build on those operating systems is not claimed from this macOS checkout.

On any target that cannot load the native session, including Flutter web, fail at factory time with the existing unsupported-profile error. Map a missing plugin exception to that same code rather than an inference failure.

## Why this approach

Keeping Android and iOS only would ignore both the request and the desktop evidence that the same ABI and official sherpa archives already exist. Adding macOS alone would be the cheapest desktop slice, and it remains the first implementation slice because this host can compile it, but it would leave two reasonable platforms unimplemented. A WASM or cloud rewrite is rejected because it replaces the session instead of reusing it. Sending PCM through Dart is rejected by the existing architecture decision.

## Steps

1. Freeze this plan and the acceptance criteria after independent research and plan reviews. Record that parent work 0002, 0004, 0006 and 0007 criteria stay frozen.

2. Add a Dart default-target guard so LocalVoiceAgent create refuses Flutter web and any other non-supported target with unsupported-profile before filesystem-native create is attempted. Add tests that prove the refusal and prove that a supported-looking create still reaches validation on Android, iOS or desktop default targets.

3. Register macos, windows and linux in the plugin manifest without adding web. Extend the provisioning script with three new platform keys, official archive names, measured SHA-256 digests and install layouts under the new plugin folders. A digest mismatch must copy nothing.

4. Implement the macOS plugin folder as a CocoaPods target that compiles the shared native sources and vendors the provisioned universal2 dylibs. Own AVAudioEngine callbacks. On start, request microphone permission through AVCaptureDevice. If permission is denied, return permissionDenied and do not start capture or install the input tap. Suspend on deactivate and default-device change. Add an example macOS host with microphone usage text. Build that example on this host after provisioning.

5. Implement the Windows plugin folder with CMake imported sherpa linkage and WASAPI capture and render threads that call the same ABI. Generate the example Windows host. If the Flutter runner has a packaging manifest, declare microphone access there using the Win32 or MSIX path that Flutter generates, not a UWP-only contract. On start, a WASAPI capture-open denial returns permissionDenied and does not start render. Device invalidation after start suspends with audioUnavailable or routeChanged. Do not treat absence of a Windows runner as implementation success or as a reason to omit the sources.

6. Implement the Linux plugin folder with CMake imported sherpa linkage and PulseAudio record and playback streams that call the same ABI. Generate the example Linux host. On start, a portal or Pulse record denial returns permissionDenied and does not start playback. Server or default-device loss after start maps to audioUnavailable or routeChanged.

7. Keep optional llama.cpp behind the existing CPU-only compile gate on every new platform. Do not enable GPU backends.

8. Update capability and setup documentation to list the five supported platforms, the excluded targets, the provisioning commands, and the evidence boundary between source, macOS compile, and unexecuted Windows or Linux builds. Refresh the wiki index.

9. Run format, analysis and existing tests. Add focused tests for the Dart guard, provisioning digest failure, and any extractable desktop permission or format helpers. Record verification limits honestly.

## Interfaces and shared decisions

Supported platforms are Android, iOS, macOS, Windows and Linux. Excluded targets are Flutter web, watchOS, tvOS, Wear OS, Android TV, WASM, cloud speech and PCM-through-Dart.

The C ABI remains the only inference contract. Method names stay create, start, stop, interrupt, reply, poll and dispose on channel flutter_local_voice_agent. PCM never crosses that channel.

Desktop capture must be mono float32, or converted to mono float32 before push, at a constant session rate between 8000 and 192000 Hz. The native worker remains the resampler to 16 kHz inference. Playback consumes render at the session output rate.

Permission denial on start uses permissionDenied and leaves capture closed on every desktop platform. Missing native registration or an excluded target uses unsupportedProfile. Default-device or stream loss after start uses audioUnavailable or the existing routeChanged suspension already used on mobile. Do not invent a second error taxonomy.

Desktop audio-callback logs must not contain raw PCM samples or waveforms.

Provisioning remains an explicit build-time operator command. The plugin must not download runtimes at create or start. The macOS archive and digest are the recorded osx-universal2-shared values above. Windows and Linux archives are the official v1.12.14 shared CPU builds; their digests are measured during implementation and then pinned.

macOS minimum follows current Flutter desktop documentation: Monterey 12. Windows minimum is Windows 10 x64. Linux minimum is the Flutter desktop Debian and Ubuntu floor. Android 26 arm64 and iOS 13 remain unchanged.

Foreground half-duplex remains the only qualified conversation mode. Background capture, full duplex and wake word stay rejected.

Windows and Linux compile evidence is a recorded gate, not a silent pass. If no runner exists, verification lists those builds as unresolved and still requires source review plus shared native and Dart tests.

This item does not close parent VITS allocation, physical mobile qualification or clean pub installation.

## Risks

| Risk | Likelihood | Impact | Mitigation | Trigger that means it happened |
|---|---|---|---|---|
| Desktop sherpa archive layout differs from Android jniLibs or iOS xcframeworks | High | Provisioning copies the wrong files and links fail | Inspect the official archive before pinning; fail the script on missing expected library names | Configure or copy step cannot find the imported library |
| macOS lifecycle copied from iOS uses AVAudioSession | Medium | macOS build fails or ignores route loss | Write a macOS-specific owner; reuse only AVAudioEngine PCM and the C ABI | Compile error on AVAudioSession or missing route suspension |
| WASAPI or Pulse format is not mono float32 | High | Native worker receives invalid frames | Convert or reject at the platform boundary; never silently change the ABI | Push returns overflow or recognition sees non-finite audio |
| Windows capture-open denial or missing runner microphone declaration | Medium | Start succeeds then records silence, or fails with an untyped error | Map open denial to permissionDenied; declare microphone on the generated Flutter Windows host manifest when that file exists | Start opens WASAPI after access denial, or the example has no microphone declaration and no typed failure |
| Linux portal or Pulse record denial | Medium | Start succeeds without a record stream | Map record-connect denial to permissionDenied and skip playback start | Start proceeds after Pulse or portal refusal |
| Desktop logs dump callback PCM | Medium | Speech content leaves the device through logs | Log counters, RMS ranges and failures only; search new log sites in verification | A log line prints frame values or a waveform |
| Windows or Linux sources ship uncompiled | High | Reviewers treat missing builds as success | Record the compile gap; do not mark those criteria as device-proven | Verification claims a Windows or Linux runtime pass without a runner |
| Desktop work is mistaken for closing mobile qualification | Medium | Parent FAIL is laundered into a desktop PASS | State the parent gates as out of scope in criteria and delivery | A 0008 document says physical Android or iPhone speech is now qualified |
| Provisioning download is called from the plugin | Low | Offline contract breaks | Keep the script operator-only; plugin create stays local | Network traffic during create or start |
| Example desktop generation overwrites unrelated dirty files | Medium | Parallel work is lost | Add only new desktop host folders; do not revert unrelated tracked changes | Git status loses existing unrelated edits |

## Rollback

Remove the new desktop plugin folders, example desktop hosts, provisioning keys, Dart guard, and the tests and documentation this item adds for those surfaces. Restore the plugin manifest and capability documents to Android and iOS only. Leave Android, iOS, native worker, catalog and unrelated working-tree changes untouched. No git publish or package publication is part of rollback.

## Out of scope

Flutter web, watchOS, tvOS, Wear OS, Android TV, CarPlay, Android Auto and app extensions. WASM or browser engine ports. Cloud or OS-only speech adapters. PCM through Dart. Extra Android ABIs. iOS Swift Package Manager. Changing the current iOS session mode. Closing parent VITS allocation, physical mobile qualification or consumer native packaging. Model redistribution. Commit, push or pub.dev publication. Acoustic full duplex, background microphone continuation and wake word. Claiming Windows or Linux compile from a macOS-only checkout.

## Verification approach

Run the repository format, analysis and test commands. Add a Dart test that create on an excluded target fails with unsupportedProfile and does not call native create. Add a provisioning test or dry invocation that a wrong digest fails and writes no library files. Review each new plugin for flva_push and flva_render on audio callbacks, for the absence of PCM method-channel arguments, and for the absence of raw PCM in log sites. Add a macOS start-denial test or bridge check that permissionDenied is returned and capture is not started.

On this host, provision macOS and run the macOS example build. Record the exact command and exit code. If a Windows or Linux runner is available, run those Flutter desktop builds and paste the output. If not, write the missing builds into verification as unresolved rather than passing them.

Inspect the diff so unrelated dirty files stay untouched. Re-read parent 0002 blockers and confirm no 0008 artifact claims them closed.
