# Plan: Flutter web offline voice profile

## Goal

A Flutter web host can create LocalVoiceAgent, grant microphone access, speak, receive a local deterministic reply, hear VITS playback, interrupt or stop, and dispose, with no speech server and no change to the native flva session on Android, iOS, macOS, Windows or Linux. A web host that lacks the web backend, the compact model pack, or a secure microphone context fails with a typed error before inference starts.

## Approach

Keep the public Dart facade. Split every dart:io import behind conditional libraries so the package compiles for web. Introduce a session-backend seam inside the agent. Native hosts continue to use the existing method-channel platform and filesystem model store. Web hosts use a new web backend that loads pinned sherpa-onnx WASM assets, runs Silero VAD, a non-streaming offline recognizer and VITS TTS, and owns microphone capture and speaker playback through package web. The current library manifest does not depend on package web. This item adds that package as a direct library dependency in the same Group 2 manifest change that vendors WASM. It is not an assumed existing import.

Do not add the pub.dev sherpa_onnx plugin, do not add sherpa_onnx_web, and do not add the record plugin. Those packages register native or third-party web implementations that would sit beside libflva or replace this package as the web registrant. Vendor the official 1.13.8 WASM glue and binary as Flutter assets of this package, pin their digests, and keep Apache-2.0 notices. Capture through getUserMedia and playback through Web Audio using package web. Convert PCM only inside the web backend. The agent still receives transcripts, state, replies and errors, never sample arrays.

The plugin manifest keeps the existing android, ios, macos, windows and linux keys and adds a web key that points at this package's own web implementation.

Create on web validates a web model store instead of Directory paths. The first example pack is the compact English catalog entry already measured at 114,444,636 bytes. Models arrive either as example assets or through an explicit preparation write into a private origin store that reuses the existing hash and cancellation policy. Create does not download. useLocalLlm true on web fails with unsupportedProfile. Full duplex remains rejected.

Native plugin folders, provision_runtime.py, flva.h and the five-host refusal for fuchsia stay unchanged. Work 0008 remains correct that web cannot load the native session. This item adds a different session, then updates capabilities so web is a qualified profile with its own limits rather than a silent native claim.

## Why this approach

Reusing flva.h is impossible in a browser. Work 0008 already recorded that. Adding sherpa_onnx as a dependency would be the shortest Flutter wiring and is rejected because it pulls native sherpa plugins into consumer mobile and desktop builds. Compiling flva.cpp with Emscripten keeps our coordinator but duplicates official WASM packaging and still needs JS audio. Web Speech and cloud speech break the offline contract. whisper.cpp and similar stacks change the engine family and the catalog.

VAD plus non-streaming ASR is the first recognizer because that is the official Flutter web demo path. Streaming Zipformer works in HTML WASM pages but is omitted from the official Flutter streaming example, so it is a follow-up, not a hidden first-slice requirement. Compact LJS is the first pack because the full-precision archive is more than three times larger. Deterministic Dart logic needs no extra runtime. Optional wllama is later work.

The research artifact is wiki/work/0010-flutter-web-offline-profile/00-research.md.

## Steps

1. Freeze this plan and the acceptance criteria only after independent research and plan reviews and an explicit implement request. Do not start Group 1 before that. Parent work 0002, 0008 and 0009 criteria stay frozen and stay in force for native hosts.

2. Split dart:io out of agent, model store and model preparation with conditional imports so flutter analyze can include web. Keep FileModelStore as the native implementation. Group 1 adds only the conditional import barrels, the io implementations, and web compile stubs that do not implement compact-pack hash policy. Group 2 later adds a separate production web model-store library that hash-checks bundled or origin-private files and never uses Directory or File. Existing VM tests that create temporary directories stay on the VM. Web create keeps the existing optional model store argument. Tests inject a fake. When that argument is omitted on web, create uses an internal default hook that Group 1 owns. Group 1's fail-closed stub default returns missingAsset and is not the omitted default after Group 2. Task 2.2 assigns the production hash-checking store to that hook from the library it owns. Task 3.1 imports that library so the assignment is live before a host calls create.

3. Add a session-backend interface used only inside the library. Native create continues to call MethodChannelVoicePlatform with filesystem path maps. Web create constructs the web backend and does not open a method channel. LocalVoiceAgent.create still runs full-duplex refusal, speaker-id validation and then the host choice.

4. Vendor and pin sherpa-onnx 1.13.8 web WASM assets under this package, with SHA-256 verification in the same style as provision_runtime.py. Add package web as a direct library dependency in that same manifest change. Add a third-party notice. A digest mismatch fails web create with invalidAsset, loads or copies nothing, and does not request the microphone.

5. Implement narrow Dart bindings over the vendored Module for Silero VAD, one offline recognizer and OfflineTts. Do not wrap unused diarization or enhancement APIs. Load WASM once per isolate. Run inference off the UI thread with a worker or equivalent web isolate so start and poll stay responsive.

6. Implement the web audio owner. Request microphone permission through getUserMedia in a secure context. Stream 16 kHz mono float frames into the VAD. Play generated TTS through Web Audio. If permission is denied, start returns permissionDenied, does not open capture, and does not start playback. If the context is not secure, create or start returns unsupportedProfile. Log counters and errors only. Never log PCM.

7. Wire half-duplex turn ownership in the web backend to the existing agent events: listening, recognizing, thinking, speaking, interrupting, idle, and the existing error codes. VAD endpointing produces one finalized transcript. That transcript calls the same LocalReplyLogic used on native hosts. The reply text is segmented with the existing length limits and synthesized by VITS. Interrupt during speaking flushes playback, invalidates the current generation, does not emit the cancelled audio, and returns the session to listening while start remains active, or to idle if the session is not started. Speech is not admitted while speaking. Native interrupt behavior stays unchanged.

8. Point the example web host at the compact catalog pack. Keep native example storage on dart:io. Add a web storage path that installs the compact pack into the origin-private store or loads it from example assets after an explicit user action. On web, LocalModelBundle.directory is the origin-private store prefix or the bundled-asset prefix, never a dart:io directory path. LocalModelBundle.manifestPath is the store-relative or asset-relative manifest key that uses the same manifest file name as the native pack. The compact English pack uses the existing catalog identifier as that prefix. Do not enable Start until validation succeeds. Do not download during LocalVoiceAgent.create.

9. Replace the web-is-always-refused behavior with profile selection. Web with a working backend is allowed. fuchsia and other non-native non-web targets still throw unsupportedProfile. MissingPluginException on native hosts still maps to unsupportedProfile.

10. Update capabilities, README, analysis inclusions, the platform-coverage product note, and a new architecture decision that records the web-only PCM exception. Refresh the wiki index. Record that native PCM still never crosses the method channel.

11. Run format, analyze including web, VM tests, and a Flutter web build of the example. Add focused tests listed in 03-tasks.md. Record browser microphone-to-speaker evidence only if a browser run is executed. Do not invent that evidence.

## Interfaces and shared decisions

The public types LocalVoiceAgent, LocalModelBundle, LocalReplyLogic, AgentEvent and AgentErrorCode stay. No new required constructor arguments for native hosts.

Session backends are an internal seam. NativeVoicePlatform remains the native channel contract and still forbids audio on that channel. The web backend is not a method-channel implementation that smuggles PCM lists. It owns devices itself.

Supported native hosts remain Android, iOS, macOS, Windows and Linux on flva.h and sherpa-onnx v1.12.14. Flutter web is a separate profile on vendored sherpa-onnx 1.13.8 WASM. watchOS, tvOS, Wear OS, Android TV, fuchsia, cloud speech and OS speech stay unsupported.

The web model store accepts the existing compact catalog manifest runtime string 1.12.14. It does not require the manifest to say 1.13.8. The 1.13.8 pin applies only to the vendored WASM engine digest. Native FileModelStore keeps requiring runtime 1.12.14.

The plugin manifest keeps android, ios, macos, windows and linux, and adds a web key that registers this package's own web implementation. sherpa_onnx, sherpa_onnx_web and record stay absent from library dependencies. Package web is the only new library dependency this item adds for browser capture and playback.

First-slice recognizer is Silero VAD plus a non-streaming offline recognizer. First-slice voice is the compact English VITS already in the catalog. Speaker id stays an integer and remains zero for LJS.

useLocalLlm true on web is unsupportedProfile. Full duplex is unsupportedProfile. Background capture and wake word stay unsupported.

Web model keys are confined to bundled assets or a private origin store. Hash mismatch is invalidAsset. Missing pack is missingAsset. Create does not fetch.

Secure-context failure and missing WASM are unsupportedProfile. A WASM digest mismatch is invalidAsset. Microphone denial is permissionDenied and starts neither capture nor playback. Inference faults stay inferenceFailed or capacityExceeded using the existing codes.

PCM exists only inside the web backend. The facade, polls and logs do not carry samples.

No GPU or CDN ONNX Runtime is introduced. No pub.dev publication and no git push are part of this item.

Windows and Linux native compile gaps from work 0008 stay recorded. This item does not close them. Parent 0002 VITS allocation, physical mobile qualification and clean consumer-install stay open.

## Risks

| Risk | Likelihood | Impact | Mitigation | Trigger that means it happened |
|---|---|---|---|---|
| Compact catalog ONNX files are incompatible with WASM 1.13.8 | Medium | Web create fails after packaging | Spike load of the compact pack before example wiring; fail with invalidAsset rather than a generic inference error | WASM load or recognizer construct rejects the files |
| Vendoring WASM plus compact models explodes example download size | High | Hosts refuse the demo | Keep models out of the plugin package; example uses explicit preparation or documented assets | Plugin package contains catalog weights |
| Dual audio devices or echo on web | High | TTS is recaptured as user speech | Keep half duplex; pause capture admission while speaking; do not claim AEC | Transcript contains the spoken reply |
| Browser autoplay blocks TTS | High | Reply is silent | Start playback from the user start gesture or a documented unlock; surface audioUnavailable if play is refused | generate succeeds and no sound is heard after start |
| UI thread jank from WASM | Medium | Page freezes during decode | Run WASM in a worker; keep poll and events on the facade | Main isolate is blocked for a visible stall during listen |
| Conditional imports break VM tests | Medium | CI analyze or tests fail | Keep FileModelStore tests on dart:io; add web-only tests that do not import dart:io | flutter test fails after the split |
| Implementers add sherpa_onnx to pubspec.yaml | Medium | Native collision | Criteria forbid those dependencies; review pubspec.yaml | sherpa_onnx, sherpa_onnx_web or record appears in library dependencies |
| Web work is described as closing native qualification | Medium | Parent FAIL is laundered | Criteria and docs keep 0002 blockers open | A 0010 document says physical Android or iPhone speech is now qualified |
| Logs print PCM | Medium | Speech leaves the device | Same log rule as desktop; search new web log sites | A log line prints frame values |
| Safari getUserMedia or WASM SIMD missing | Medium | Create or start fails on a listed browser | Document Chrome as the first evidence browser; Safari is a recorded gate if not run | Verification claims Safari without output |

## Rollback

Remove the web backend, vendored WASM assets, web model store, web example storage path, web plugin registration, the package web dependency if this item added it, web tests, and the documentation sentences that list web as supported. If this item accepted the web architecture decision, supersede that document. Do not delete it. Restore the host guard so Flutter web again throws unsupportedProfile before any session create. Leave native plugins, flva, catalog inventory, provision_runtime.py and unrelated working-tree files untouched. No publication is required to roll back.

## Out of scope

Streaming Zipformer on Flutter web. Full-precision LJS and treating VCTK as required for the first web example. Optional llama.cpp or wllama. Compiling flva.cpp to WASM. Depending on sherpa_onnx, sherpa_onnx_web or record. Cloud speech. Web Speech API. OS speech. Full duplex, AEC, barge-in, background capture and wake word. watchOS, tvOS, Wear OS and Android TV. Closing parent 0002 gates. Model redistribution. Commit, push or pub.dev publication. Claiming measured Chrome or Safari latency without pasted command or session evidence. Changing native sample rates, Android ABIs or iOS session mode.

## Verification approach

Run dart format on lib and example/lib. Run dart analyze with fatal infos and fatal warnings on the package and example, including web as an analysis target. Run the existing VM test suite and the new web-profile tests. Add a Dart test that web create with a fake web backend reaches session create, and a test that fuchsia still refuses. Add a test that useLocalLlm on web throws unsupportedProfile. Add a test that a digest mismatch of the WASM asset or a missing compact model file throws before getUserMedia. Add a test that the web backend API does not accept or emit PCM through LocalVoiceAgent events.

Inspect pubspec.yaml so sherpa_onnx, sherpa_onnx_web and record are absent from library dependencies, package web is present, and the web platform key points at this package. Inspect native plugin folders so they are not rewritten except for unavoidable shared-manifest fallout.

Run flutter build web for the example and paste the exit code. If a browser session is run, record the browser name, that microphone permission was granted, that a finalized transcript appeared, and that playback was heard or explicitly failed. If no browser session is run, write that gap into verification instead of a pass.

Re-read 0002 blockers and confirm no 0010 artifact claims them closed.
