# Mobile audio systems research

Consulted: 2026-09-19. Scope: Flutter on Android and iOS, strictly local inference and local model provisioning. This is research and proposed constraints, not implemented behavior or a final engine selection. All measured latency, battery, memory, route compatibility, and cancellation performance for this project are **[UNVERIFIED]**. No device experiments were performed for this report. Work-item artifacts omit frontmatter under the repository naming convention.

## Evidence and recommendation boundary

The proposed architecture is a native audio data path, native inference workers, and a Dart control/event layer. Keep hardware callbacks independent of Dart scheduling. This is a design recommendation based on the callback restrictions in [Android low-latency guidance](https://developer.android.com/games/sdk/oboe/low-latency-audio), rather than evidence of any particular performance gain. Android's game-specific usage recommendation must not be copied into a voice application: configure a communication use case appropriate to the chosen backend.

Full duplex means simultaneous capture and playback; it does not establish successful acoustic echo cancellation or reliable user interruption. Treat these as separate capabilities and qualification tests.

## Flutter boundary and concurrency

Verified: Flutter supports C APIs through `dart:ffi`. Current documentation recommends the `package_ffi` template and build hooks since Flutter 3.38, while documenting reasons to retain a platform plugin, including Flutter Plugin API access and some static-linking use cases. Pin and test the actual build mechanism against the project's eventual Flutter version. [Flutter FFI packaging](https://docs.flutter.dev/platform-integration/legacy-ffi-plugin).

Verified: platform channels transport asynchronous messages; native calls destined for Flutter must respect platform main-thread requirements. Platform handlers can use Task Queues. Registered background isolates can issue platform calls, but cannot receive unsolicited host messages. Therefore an EventChannel listener in a background isolate is not a valid assumed topology. [Channels](https://docs.flutter.dev/platform-integration/platform-channels), [isolate restrictions](https://docs.flutter.dev/perf/isolates).

Proposed boundaries:

- Keep permissions, Activity/service lifecycle, Android focus/routing, iOS session configuration, and platform notifications in Kotlin/Swift or Objective-C++. Send bounded control/status messages through a platform plugin.
- Expose engine adapters through a narrow, versioned C ABI: opaque handles, explicit status values, lengths, capabilities, and matching allocation/release operations. Never expose C++ exceptions, STL containers, or engine-specific structs to Dart.
- Keep capture, sample conversion, VAD/ASR feeding, generated-audio buffering, and rendering native. Forward transcripts, state transitions, errors, and sampled metrics to Dart. Optional audio export must have an explicit bounded ownership protocol; a Dart stream must not become the authoritative hardware buffer.
- Choose a single native session coordinator for lifecycle transitions. It owns workers and handles; UI commands only enqueue work or flip bounded cancellation state. Heavy FFI calls run on a persistent worker isolate or, preferably for an already native pipeline, native worker threads. A Future wrapper alone does not make synchronous inference nonblocking.
- Bound inference thread counts across ASR, language inference, and TTS together; independent defaults may oversubscribe a mobile CPU. Thread-count policy and scheduler performance remain [UNVERIFIED] until profiling.

Verified: `NativeCallable.listener` accepts calls from native threads but dispatches asynchronously to its creating isolate, supports only void return values, and requires pointer arguments to stay valid through callback completion. Invoking its function pointer after `close` is undefined behavior. [Dart callback contract](https://api.dart.dev/dart-ffi/NativeCallable/NativeCallable.listener.html).

Proposed callback rule: audio callbacks never allocate, lock, wait, log, load models, invoke Dart, or perform network/file I/O. Native workers may publish notifications after leaving the real-time path. Use owned event records with acknowledgment/release, or copy into a bounded queue before posting. A borrowed audio callback buffer must never be passed to an asynchronous Dart callback.

## Audio formats, clocks, and pressure

Verified: Android recommends natural device sample rates and warns that requested rates may change the audio path. It also recommends short nonblocking callbacks and exposes underrun information. Its published sample latency table is not a benchmark for this SDK. [Android low-latency guidance](https://developer.android.com/games/sdk/oboe/low-latency-audio).

Proposed data contract:

- Use mono float32 as the internal logical audio representation, with an explicit sample rate, frame count, sequence number, monotonic timestamp, route epoch, and discontinuity marker. Retain backend hardware format metadata separately. “Float32” does not imply one universal sample rate.
- Negotiate hardware capture/playback rates. Resample into each engine's declared input rate and from TTS output rate into the renderer's actual rate. A 16 kHz ASR/VAD branch is a candidate only when the selected models require it; hardware must not be forced to 16 kHz merely for convenience.
- Use a stateful resampler, preserve fractional phase between chunks, and account for its delay. Reset it on discontinuities and route epoch changes. Frame-size adaptation must not assume that audio callback size equals model window size.
- Maintain a monotonic capture timeline and a render timeline with explicit clock mapping. Estimate drift from timestamps/frame counts, rather than assuming equal nominal rates mean synchronized clocks. Retain the actual rendered reference for any software AEC.
- Preallocate bounded single-producer/single-consumer audio rings where that ownership topology applies. Any fan-out gets separate ownership or separate rings. Record capacity in frames and milliseconds at the relevant rate.
- On capture overflow, mark a discontinuity and invalidate/reset the affected recognition segment; never concatenate separated speech silently. A nonblocking full-ring policy must be specified and tested. On render underflow, emit silence and record the event. Never block the hardware callback waiting for TTS.
- Apply backpressure upstream of TTS and language generation at bounded high-water marks. Bound tokens, text waiting for synthesis, synthesized frames, and event records independently. If an engine cannot pause, cancel or terminate the turn through a defined error instead of growing memory indefinitely.
- Give stop/cancel/error delivery a reserved path that cannot be starved by token or transcript updates. Coalesce replaceable partial transcripts/metrics. Do not drop terminal events silently.

No numeric queue size, callback deadline, drift tolerance, or latency budget is established by this research. Such values are proposed targets [UNVERIFIED] until the selected devices and engines are benchmarked.

## Echo cancellation and user interruption

Verified: Android `AcousticEchoCanceler` is device-dependent, attaches to an `AudioRecord` session, may already be active depending on capture source, and can be unavailable. The API is not evidence that a chosen Oboe path has effective AEC. [Android AEC](https://developer.android.com/reference/android/media/audiofx/AcousticEchoCanceler).

Verified: Apple documents that `voiceChat` without Voice I/O or an AVAudioEngine configured for voice processing does not apply voice-specific processing such as echo cancellation. Merely selecting the session mode is insufficient. [Apple voiceChat](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat).

Proposed qualification and behavior:

- Make effective echo processing an explicit backend capability with evidence for each supported route/device tier. Avoid stacking platform AEC and software AEC by default.
- Android candidates are an AudioRecord/AudioTrack communication path with session effects, or Oboe/AAudio with a separately verified processing strategy. Do not claim the latter inherits AudioRecord effects. On iOS, evaluate a voice-processing AVAudioEngine or Voice I/O path before choosing generic playback/record nodes.
- For software AEC, provide the reference actually rendered after output resampling/gain and maintain delay alignment. Evaluate double-talk and varying acoustic paths. Selecting or implementing a software AEC library is outside this report.
- Detect barge-in from near-end speech after echo processing, with hysteresis and a small capture pre-roll. VAD alone cannot establish that an observed voice belongs to the user rather than the speaker output; empirical robustness is [UNVERIFIED].
- On confirmed interruption, immediately advance the turn generation, gate stale renderer frames, discard old queued speech, request cancellation of language/TTS work, and preserve near-end audio for the next turn. A stopped Dart stream is not equivalent to silencing already-buffered native output.
- Separate an immediate audible-stop path from eventual engine cancellation acknowledgment. Old workers may finish, but their generation-tagged outputs must be rejected. Measure residual OS/device output buffering; it cannot be assumed zero.
- Offer an explicit half-duplex or push-to-talk mode where full-duplex echo quality is not qualified. Do not advertise successful barge-in on untested routes.

## Platform lifecycle and Bluetooth

### Android

Verified baseline: capture requires runtime `RECORD_AUDIO`; background continuation requires a valid microphone foreground service with the appropriate declared service type and permissions. Android 14 adds type-specific foreground-service permissions. While-in-use rules generally prevent creating a microphone foreground service from the background or boot receiver; documented exceptions are not a default design. A foreground service exposes an ongoing notification. [Service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [foreground service overview](https://developer.android.com/develop/background-work/services/fgs).

Verified audio lifecycle: target API 35+ requires the top app or a foreground service to request audio focus. Android 16 subjects jobs launched from foreground services to their normal job quotas; WorkManager is not a substitute for a live microphone session. [Audio focus](https://developer.android.com/media/optimize/audio-focus), [foreground-service changes](https://developer.android.com/develop/background-work/services/fgs/changes).

**Published Android 17 requirement:** Android 17 documentation restricts background playback, focus, and volume interactions for all apps running that release to a visible Activity or a foreground service other than `SHORT_SERVICE`. Target API 37 adds while-in-use capability requirements for background services, with narrowly described alarm exceptions. Playback can fail silently; a successful-looking write is not proof of audible output. This applies to native audio libraries too. This report cites published rules and does not claim Android 17 device validation, universal device availability, or a verified release/rollout status. [Android 17 audio hardening](https://developer.android.com/about/versions/17/changes/bg-audio).

Proposed default: a user starts a session while the app is visible; background continuation is separately configurable and opt-in. Stop on permission loss, explicit service stop, permanent focus loss, or unrecoverable audio failure. Host applications own user-facing permission text and service disclosure; the SDK must expose denied/revoked/interrupted states, not retry indefinitely. Determine service-type combinations from the actual microphone and playback operation before implementation.

Verified routing: Android recommends `setCommunicationDevice` rather than legacy SCO routing for BLE-audio support, with device callbacks, route confirmation, timeout handling, and clearing the selection at session end. Bluetooth Classic and BLE have different simultaneous microphone/playback characteristics. [Communication routing](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/audio-manager), [BLE audio](https://developer.android.com/develop/connectivity/bluetooth/ble-audio/overview).

Proposed handling: feature-detect routing APIs against the final minimum API; observe actual route and format after requests. Reopen/reconfigure streams on route change through the coordinator, reset resampler/AEC state, mark discontinuities, and pause speech if private headphones disappear. Bluetooth permissions must match the exact APIs used; route availability is not inferred from pairing alone. Route switching latency, AEC quality, and output-tail duration remain [UNVERIFIED].

### iOS

Verified: `playAndRecord` supports simultaneous input/output, requires recording permission, and documents background audio configuration via `UIBackgroundModes` with `audio`. `NSMicrophoneUsageDescription` is required for microphone access. AVAudioSession is app-wide, so several plugins can affect the same configuration. [playAndRecord](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord), [microphone purpose](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription), [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession).

Verified: observe interruption and route notifications; interruption-ended information indicates whether resumption is appropriate. Apple describes pausing when headphones disconnect to avoid unexpectedly moving private audio to speakers. [Interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions), [route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes).

Proposed behavior: negotiate session ownership with the host app; avoid hidden configuration races with other audio plugins. Suspend capture/rendering and invalidate turn output on interruption. Recheck route, permissions, and session activation before resuming; user intent must still permit it. Handle media-services reset through backend reconstruction. Background audio configuration must not be described as a guarantee of unlimited background inference or post-termination listening. Actual continuation and system-termination behavior require device tests [UNVERIFIED].

## Resource ownership, cancellation, and disposal

Verified: Dart NativeFinalizer can release unreachable native resources but does not provide timely application lifecycle cleanup or guarantee callbacks after abrupt termination. Its callback runs outside an isolate and cannot generally re-enter the Dart VM. [NativeFinalizer](https://api.dart.dev/dart-ffi/NativeFinalizer-class.html), [callback restrictions](https://api.dart.dev/dart-ffi/NativeFinalizer/NativeFinalizer.html).

Proposed lifecycle contract:

1. Session construction validates local assets, hashes, formats, and required memory before capturing. Model handles, worker state, audio rings, callback registrations, and OS audio objects have a single documented owner.
2. Turn cancellation is generation-based and idempotent. It mutes/flushes logical output immediately, requests cooperative engine cancellation, and eventually reports worker completion. Cancellation support and acknowledgment latency for each engine remain [UNVERIFIED].
3. Dispose rejects new commands, stops capture/render callbacks through backend lifecycle APIs, waits for in-flight callbacks to quiesce, cancels and joins workers, unregisters producers, drains/reclaims queued event records, releases engines and audio resources, and only then closes Dart callback handles.
4. Callback publication must be disabled before its Dart function pointer is closed. Records already in transit require acknowledgment or lifetime-safe reclamation. Freeing a model or buffer while a worker still references it is never a timeout recovery strategy.
5. If a non-cooperative engine cannot stop, return an explicit failed/timed-out state and retain/quarantine still-referenced resources until safe release. Do not claim successful disposal and free live memory. Engine restartability then becomes a selection gate.
6. Finalizers are leak mitigation, not the mechanism for stopping the microphone. Dispose must be explicit and idempotent; use-after-dispose is a typed error.

## Offline provisioning and observability

Proposed strict-offline profile: use bundled assets or explicitly user-imported local model files; validate a local manifest with hashes, model/runtime versions, expected formats, and licenses. Fail clearly for missing or incompatible assets. Do not silently fetch models, invoke OS cloud speech, or fall back to a network provider. Host-app network behavior is separate from SDK inference behavior and needs its own audit.

Proposed instrumentation: monotonic timestamps for capture arrival, VAD decision, transcript partial/final, first language token, first TTS frame, renderer enqueue, playback progress, cancel request, audible-stop estimate, and worker stop acknowledgment. Include route, actual rates, model IDs, queue high-water marks, discontinuities, underruns, process/native memory, and active worker counts. Store only local aggregate timings by default; raw speech, transcripts, prompts, and device identifiers are excluded unless explicitly enabled for a test.

Verified: Android offers thermal status/headroom monitoring but support varies and excessive headroom polling can return NaN. Apple provides thermal state and change notifications and recommends reducing resource use at higher thermal states. [Android Thermal API](https://developer.android.com/games/optimize/adpf/thermal), [Apple thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property), [Apple thermal notifications](https://developer.apple.com/documentation/foundation/processinfo/thermalstatedidchangenotification).

Proposed resource policy: record cold and sustained performance with temperature/power state; reduce optional work or reject new heavy turns when resource budgets cannot be met. Prefer a bounded text/context history and avoid concurrent duplicate model loads. Memory warnings should stop admission and release idle resources, not free active engines. Battery drain, sustainable throughput, maximum resident memory, and recovery effectiveness are [UNVERIFIED].

## Integration candidates

| Candidate | Evidence | Boundary and caveat |
|---|---|---|
| Oboe | Google's C++ Android audio library; upstream [Apache-2.0 license](https://github.com/google/oboe/blob/main/LICENSE) and [guide](https://github.com/google/oboe/blob/main/docs/FullGuide.md) | Candidate for low-latency Android I/O; effective AEC and chosen Flutter packaging [UNVERIFIED]. |
| Native AudioRecord/AudioTrack plus effects | [Android AEC](https://developer.android.com/reference/android/media/audiofx/AcousticEchoCanceler) documents AudioRecord session attachment | Platform SDK integration; availability/effectiveness vary. No claim of open-source licensing for platform binaries. |
| AVAudioEngine/Voice I/O with AVAudioSession | [voiceChat processing requirements](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/voicechat) | Apple platform framework candidate. Minimum supported OS, build integration, and full route matrix remain [UNVERIFIED]. |
| Dart FFI plus a platform plugin | [Flutter packaging](https://docs.flutter.dev/platform-integration/legacy-ffi-plugin) and [channels](https://docs.flutter.dev/platform-integration/platform-channels) | Candidate bridge arrangement; benchmark comparisons with pure-channel orchestration remain [UNVERIFIED]. |

The Oboe license is a source-file observation, not a complete transitive dependency or distribution review. Pin exact releases and inspect bundled notices before adopting any candidate. No external integration package or inference engine is selected here.

## Proposed tests and unresolved questions

These are recommended future tests, not executed checks:

- Native unit/stress tests: ring wraparound, overflow/underflow, frame accounting, sample conversion, long-run clock drift, discontinuity resets, producer starvation, and reserved terminal-event delivery. Include malformed lengths, invalid rates, unsupported channels, and non-finite sample input.
- Ownership tests: rapid start/stop, cancellation in every stage, double dispose, stale generation output, callback racing shutdown, engine load failure, out-of-memory injection, and slow/non-cooperative worker shutdown. Use native sanitizers where supported and test actual binaries on devices.
- Offline tests: fresh install and cold start without connectivity using locally available assets; no-assets failure; corrupted-asset failure; verify no fallback network requests during capture, inference, synthesis, or errors.
- Acoustic tests: prerecorded synthetic/safely licensed speech, noise, self-echo, double-talk, room changes, speaker-volume sweep, headset changes, and user speech during TTS. Measure false interruption, missed interruption, ASR quality, and residual audible speech.
- Lifecycle tests: denied/revoked microphone permission, focus loss, incoming call, screen lock, app background/foreground, OS service stop, Bluetooth disconnect, USB removal, and media-services reset where available. Exercise supported Android target/runtime combinations including Android 17 hardening; test iOS background behavior on physical devices.
- Performance tests: cold/warm model load, sustained conversation, low-memory conditions, low-power mode, thermal transitions, and cancellation under peak load. Capture percentiles and failures per device/route/model, rather than extrapolating a desktop benchmark.

[UNRESOLVED: Which minimum Android/iOS and Flutter versions will be supported, and which target SDK/Xcode versions will release builds use?]

[UNRESOLVED: Which Android backend and AEC strategy provide qualified speakerphone barge-in on the intended device tiers?]

[UNRESOLVED: Does product scope include user-initiated background continuation, or only foreground use? Always-on wake-word behavior requires a separate platform feasibility review.]

[UNRESOLVED: What rates/windows do selected engines require, and can their workers stop or pause within the eventual budgets?]

[UNRESOLVED: What device-tier limits will govern model memory, concurrency, latency, battery, thermal behavior, queue capacities, and maximum turn duration?]

[UNRESOLVED: Which routes are guaranteed, best-effort, or unsupported, and what exact fallback is user-visible?]

Every linked source above was consulted on 2026-09-19. Source documentation establishes available mechanisms and restrictions; it does not establish this project's implementation, performance, or store acceptance.
