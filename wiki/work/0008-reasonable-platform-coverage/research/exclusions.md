# Research: Platform exclusions for reasonable offline pipeline coverage

## Question

Which Flutter or adjacent platforms should stay out of work item 0008 because they cannot reasonably reuse the existing native offline pipeline built around native/include/flva.h, native worker ownership, and OS-owned audio?

## Answer

Exclude Flutter web, watchOS, tvOS, and every alternative that requires a different inference runtime, a WASM rewrite, cloud speech, or PCM-through-Dart. Keep the first-release supported set at the currently declared Android and iOS plugin targets until a sibling desktop feasibility stream produces equivalent evidence. The PRD still places web outside the first release. Parent work item 0002 VITS allocation and physical-device gates remain open and must not be closed here.

## Findings

### Flutter web

- Claim: Flutter web is not a reasonable target for this work item because the package already depends on dart:io, declares no web plugin implementation, and cannot load the pinned C++ sherpa session behind flva.h.
- Evidence: lib/src/agent.dart, lib/src/model_store.dart, and lib/src/model_preparation.dart import dart:io for filesystem paths and model installation. pubspec.yaml registers the plugin only under android and ios. The PRD states that web support is outside the first release. The PRD and ADR require a hybrid platform plugin with a versioned C ABI and native audio ownership; the current bridge loads libflva through Android System.loadLibrary and iOS native linking, not through a browser runtime.
- Source: lib/src/agent.dart; lib/src/model_store.dart; lib/src/model_preparation.dart; pubspec.yaml; wiki/product/local-voice-agent-prd.md (Product decision and scope); wiki/adr/0001-offline-voice-architecture.md; android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt; native/include/flva.h
- Cheapest reason: No path exists to load the existing native session in a browser target without replacing the entire inference and audio stack.
- Exposed error: AgentErrorCode.unsupportedProfile with a message such as "Flutter web is not a supported platform for the native offline voice pipeline." If a host bypasses an early guard and invokes the method channel anyway, MissingPluginException should be mapped to the same code rather than inferenceFailed.
- Note: Browser-side dart:ffi and WASM native interop limits were not re-fetched on 2026-09-20 because external retrieval was unavailable in this research run. Treat any additional web-runtime detail as [UNVERIFIED] unless confirmed locally.

### watchOS

- Claim: watchOS is not a reasonable target because Flutter exposes no watchOS plugin platform for this package and the existing pipeline assumes phone-class OS audio APIs tied to Android and iOS app targets.
- Evidence: pubspec.yaml lists only android and ios under flutter.plugin.platforms. The iOS plugin uses UIKit foreground checks, AVAudioEngine, and AVAudioSession APIs from ios/Classes/FlutterLocalVoiceAgentPlugin.mm. doc/capabilities.md documents foreground-only half-duplex behavior and suspends on background. There is no watchOS plugin class, pod target, or native build hook in the repository.
- Source: pubspec.yaml; ios/Classes/FlutterLocalVoiceAgentPlugin.mm; doc/capabilities.md; wiki/product/local-voice-agent-prd.md (Product decision and scope)
- Cheapest reason: No declared Flutter watchOS embedding or native bridge exists to call flva_create and own watch-class audio routes.
- Exposed error: AgentErrorCode.unsupportedProfile with a message such as "watchOS is not a supported platform for the native offline voice pipeline."
- Note: Absence of first-class watchOS Flutter plugin targets in upstream Flutter tooling was not independently re-fetched on 2026-09-20. Mark that tooling claim [UNVERIFIED] beyond the local pubspec and plugin absence.

### tvOS

- Claim: tvOS is not a reasonable target for the same structural reasons as watchOS: no plugin registration, no native bridge, and no microphone-first product contract for lean-back devices.
- Evidence: pubspec.yaml declares only android and ios. The PRD primary journey requires an explicitly authorized microphone session on mobile-class targets. The iOS implementation is UIKit- and AVAudioSession-based and assumes a foreground application state before start. No tvOS target, entitlement story, or remote-input audio contract exists in the repository.
- Source: pubspec.yaml; ios/Classes/FlutterLocalVoiceAgentPlugin.mm; wiki/product/local-voice-agent-prd.md (Product decision and scope, Offline contract)
- Cheapest reason: The repository provides no tvOS plugin surface and no qualified OS audio path to load flva.h.
- Exposed error: AgentErrorCode.unsupportedProfile with a message such as "tvOS is not a supported platform for the native offline voice pipeline."
- Note: Upstream Flutter tvOS support status was not re-fetched on 2026-09-20. Mark general tvOS Flutter availability [UNVERIFIED] beyond local plugin absence.

### WASM or browser-native rewrite paths

- Claim: Any target that requires recompiling sherpa-onnx, Silero, optional llama.cpp, and the flva coordinator to WASM or another non-native ABI is out of scope because it replaces the existing inference runtime instead of reusing it.
- Evidence: native/include/flva.h defines a C ABI consumed by native C++ in native/src/flva.cpp and linked into mobile native libraries. wiki/adr/0001-offline-voice-architecture.md rejects a channel-only PCM pipeline and requires native audio/inference ownership. The PRD comparison method treats mobile portability as a hard gate and rejects desktop extrapolation for mobile claims.
- Source: native/include/flva.h; native/src/flva.cpp; wiki/adr/0001-offline-voice-architecture.md; wiki/product/local-voice-agent-prd.md (Comparison method, Flutter integration choice)
- Cheapest reason: Reasonable, for this item, means reusing the existing C++ session, not porting engines to WASM.
- Exposed error: AgentErrorCode.unsupportedProfile with a message such as "This platform requires a WASM/native rewrite and is not supported."

### Cloud speech and OS-only speech adapters

- Claim: Cloud speech APIs and default OS speech adapters are excluded because they violate the offline contract or do not provide app-controlled model inventory behind flva.h.
- Evidence: The PRD offline contract forbids network requests for initialization, inference, fallback, telemetry, or error recovery. The PRD states that native OS services are optional adapters and cannot satisfy the default app-controlled asset contract merely because a vendor calls them on-device. wiki/adr/0001-offline-voice-architecture.md rejects OS-only speech as the portable foundation.
- Source: wiki/product/local-voice-agent-prd.md (Offline contract, STT comparison); wiki/adr/0001-offline-voice-architecture.md (Alternatives considered)
- Cheapest reason: They bypass the pinned local sherpa session and break strict offline provisioning.
- Exposed error: AgentErrorCode.unsupportedProfile when selected as a profile/platform combination; missingAsset or invalidAsset when a host misconfigures local assets instead.

### PCM-through-Dart transport

- Claim: A platform-channel-only pipeline that streams microphone PCM through Dart is excluded because the architecture explicitly rejected it.
- Evidence: wiki/adr/0001-offline-voice-architecture.md lists a channel-only PCM pipeline as a rejected alternative. lib/src/contracts.dart states that no audio crosses the NativeVoicePlatform method-channel boundary. The PRD keeps streaming PCM in native preallocated buffers.
- Source: wiki/adr/0001-offline-voice-architecture.md; lib/src/contracts.dart; wiki/product/local-voice-agent-prd.md (Flutter integration choice, End-to-end flow)
- Cheapest reason: It abandons native worker ownership and bounded native rings required by the current design.
- Exposed error: AgentErrorCode.unsupportedProfile with a message such as "PCM-through-Dart transport is not supported for this profile."

### Adjacent Android and Apple form factors without qualification

- Claim: Wear OS, Android TV, CarPlay/Android Auto surfaces, and iOS app extensions are not reasonable additions in this item even when they share an OS family, because the repository declares and qualifies only standard Android arm64 phone/tablet builds and iOS app targets.
- Evidence: doc/capabilities.md states the Android sample uses arm64 only and records no physical Android or iPhone qualification. pubspec.yaml declares only generic android and ios plugin classes with no wear, TV, or extension variants. The PRD foreground-only initial profile and half-duplex default do not establish watch, TV, or extension lifecycle contracts.
- Source: doc/capabilities.md; pubspec.yaml; wiki/product/local-voice-agent-prd.md (Product decision and scope, State machine)
- Cheapest reason: They would need new OS audio, lifecycle, and distribution evidence beyond the existing Android/iOS phone pattern while still reusing flva.h.
- Exposed error: AgentErrorCode.unsupportedProfile with a message naming the unsupported form factor until a future qualified profile exists.

### Desktop macOS, Windows, and Linux

- Claim: Desktop targets are not excluded on engine grounds alone—sherpa-onnx documents desktop support in prior research—but they are not reasonable inclusions for this item yet because this repository has no desktop plugin registration, no desktop OS audio owner, and no sibling-stream qualification equivalent to mobile.
- Evidence: pubspec.yaml declares only android and ios. example/analysis_options.yaml excludes web, windows, macos, and linux from analyzer scope. wiki/work/0001-local-voice-agent-architecture/01-plan.md states desktop is an extension and web is outside the first release. wiki/work/0002-native-offline-pipeline/research/provisioning.md records a macOS host smoke fixture only; wiki/work/0002-native-offline-pipeline/04-verification.md explicitly says that macOS WAV drain is not mobile microphone/speaker qualification. doc/capabilities.md does not list desktop as supported.
- Source: pubspec.yaml; example/analysis_options.yaml; wiki/work/0001-local-voice-agent-architecture/01-plan.md; wiki/work/0002-native-offline-pipeline/research/provisioning.md; wiki/work/0002-native-offline-pipeline/04-verification.md; doc/capabilities.md
- Cheapest reason for deferral: No desktop Flutter plugin or OS audio lifecycle implementation exists in this repo to reuse flva.h the way Android and iOS already do.
- Exposed error if a host asks before desktop work lands: AgentErrorCode.unsupportedProfile with a message such as "Desktop platforms are not yet supported for this plugin."
- Boundary note: Detailed macOS/Windows/Linux feasibility belongs to the sibling desktop stream and is intentionally not decided here.

### Parent 0002 gates that this item must not close

- Claim: VITS whole-sentence allocation and physical-device qualification remain open blockers in parent 0002 and must stay open regardless of platform coverage decisions in 0008.
- Evidence: wiki/work/0002-native-offline-pipeline/STATE.yaml lists F3/AC-004 VITS allocation as an open blocker and physical Android/iPhone resources as required. doc/capabilities.md repeats that native render bounds do not prove sherpa VITS internal allocation fits the 10-second budget and that no physical Android/iPhone qualification exists.
- Source: wiki/work/0002-native-offline-pipeline/STATE.yaml; doc/capabilities.md; wiki/product/example-model-catalog.md
- Exposed error: No new platform should map these gates away. Continue surfacing inferenceFailed, capacityExceeded, or existing native fault codes when the underlying gate fails.

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Declare supported platforms as Android+iOS only | Match pubspec.yaml, PRD applies_to, ADR scope, and current plugin/native implementations | Low documentation cost; honest about current delivery surface | Chosen for this item |
| Declare supported platforms as every research-reasonable target | Would include desktop and possibly other native-capable embeddings once qualified | Requires sibling desktop evidence, OS audio owners, packaging, and qualification not present here | Rejected for now; desktop remains unresolved |
| Add Flutter web with WASM engines | Rebuild inference in browser runtime | Full engine port, new audio stack, breaks reuse of flva.h | Rejected |
| Add watchOS/tvOS as thin Flutter targets | New Apple embedders without existing plugin classes | New audio contracts, no current bridge | Rejected |
| Expand to Wear OS/TV as Android variants | Reuse Android plugin with new lifecycle/audio rules | Qualification and UX mismatch with phone profile | Rejected for this item |

## Constraints discovered

- Reasonable means reuse native/include/flva.h, native worker ownership, and OS audio; alternatives that swap runtime, move PCM through Dart, or depend on cloud speech are out of scope.
- The package already hard-depends on dart:io in core library paths, which blocks unmodified Flutter web compilation even before native loading is considered.
- pubspec.yaml, the PRD applies_to list, and ADR applies_to list align on android and ios only.
- The PRD still excludes web from the first release as of last_verified 2026-09-20.
- doc/capabilities.md limits verified behavior to emulator-level Android observation and host/native smoke; it does not certify additional form factors.
- No commit, publication, or model redistribution is in scope for this research stream.
- Existing AgentErrorCode.unsupportedProfile is already used for unqualified profiles such as fullDuplexRequired on iOS; platform exclusion should reuse that code for consistency.

## Recommended definition of "supported platforms" for this item

Recommend option (a): supported platforms means the currently declared Android and iOS plugin targets in pubspec.yaml, interpreted as standard phone/tablet app embeddings that load libflva and use the existing MethodChannel bridge.

Do not recommend option (b) yet. Prior research notes sherpa-onnx desktop capability, and 0002 used a macOS host smoke fixture, but this repository lacks desktop plugin registration, desktop OS audio ownership, and desktop qualification equivalent to the mobile pipeline. List desktop macOS, Windows, and Linux as [UNRESOLVED] pending the sibling desktop stream.

## Unresolved

- [UNRESOLVED: Whether macOS, Windows, or Linux can be added with the same flva.h and worker pattern once the sibling desktop stream completes OS audio, packaging, and qualification evidence.]
- [UNRESOLVED: Exact upstream Flutter status of first-class watchOS and tvOS plugin targets on 2026-09-20; local evidence only shows they are undeclared in this package.]
- [UNRESOLVED: Exact Flutter web dart:ffi and WASM native-interop limits on 2026-09-20; local dart:io dependency and absent web plugin are sufficient to exclude web for this item even if finer web-runtime details differ.]
- [UNRESOLVED: Whether Wear OS or Android TV should ever share the android plugin entry or require separately qualified profiles.]
- [UNRESOLVED: Parent 0002 F3/AC-004 VITS whole-sentence allocation bound and physical Android/iPhone qualification remain open and are explicitly not closed by this item.]
- [UNRESOLVED: Whether unsupported hosts should fail at factory/create time in Dart before method-channel invocation, or only at plugin registration time; both should surface AgentErrorCode.unsupportedProfile with a platform-specific message.]

## Sources

- native/include/flva.h — consulted 2026-09-20
- native/src/flva.cpp — consulted 2026-09-20
- pubspec.yaml — consulted 2026-09-20
- lib/src/agent.dart — consulted 2026-09-20
- lib/src/model_store.dart — consulted 2026-09-20
- lib/src/model_preparation.dart — consulted 2026-09-20
- lib/src/contracts.dart — consulted 2026-09-20
- lib/src/models.dart — consulted 2026-09-20
- doc/capabilities.md — consulted 2026-09-20
- wiki/product/local-voice-agent-prd.md — consulted 2026-09-20
- wiki/product/example-model-catalog.md — consulted 2026-09-20
- wiki/adr/0001-offline-voice-architecture.md — consulted 2026-09-20
- wiki/work/0001-local-voice-agent-architecture/01-plan.md — consulted 2026-09-20
- wiki/work/0002-native-offline-pipeline/STATE.yaml — consulted 2026-09-20
- wiki/work/0002-native-offline-pipeline/04-verification.md — consulted 2026-09-20
- wiki/work/0002-native-offline-pipeline/research/provisioning.md — consulted 2026-09-20
- android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt — consulted 2026-09-20
- ios/Classes/FlutterLocalVoiceAgentPlugin.mm — consulted 2026-09-20
- example/analysis_options.yaml — consulted 2026-09-20
