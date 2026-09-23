# Acceptance criteria: Flutter web offline voice profile

## Frozen

- Frozen at: 2026-09-22
- Frozen by: coordinating agent (root)

## Criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-001 | When LocalVoiceAgent.create runs on Flutter web with the web backend available and a validated compact model pack, the system shall create a session without calling native method-channel create. | Dart test with a fake web backend and a stub native platform; assert the web create count is one and the native create count is zero. | A test that expects method-channel create or unsupportedProfile on a valid web setup fails. |
| AC-002 | When LocalVoiceAgent.create runs on fuchsia or another non-native non-web target, the system shall throw AgentFailure with AgentErrorCode.unsupportedProfile before any session backend create. | Keep and extend test/platform_refusal_test.dart for fuchsia. | Native or web create is invoked, or inferenceFailed is thrown. |
| AC-003 | When the library is analyzed for web, agent, model store and model preparation shall not import dart:io on the web library graph. | flutter analyze on a web target; search the web-conditional libraries. | A web-imported file contains a dart:io import. |
| AC-004 | When pubspec.yaml is read, the package shall not depend on sherpa_onnx, sherpa_onnx_web or record, and native plugin platform keys shall remain android, ios, macos, windows and linux plus a web registration that points at this package's own web implementation. | Inspect pubspec.yaml dependencies and flutter.plugin.platforms. | A third-party speech or record plugin appears, or a native platform key disappears. |
| AC-005 | When the vendored WASM asset digest does not match the pin, web create shall fail with AgentErrorCode.invalidAsset or unsupportedProfile and shall not request the microphone. | Unit or fixture test with a wrong digest file. | getUserMedia is invoked, or create succeeds. |
| AC-006 | When the compact model pack is missing or a file hash fails, web create shall fail with missingAsset or invalidAsset and shall not request the microphone. | Test against an empty store and a tampered hash. | Create opens the microphone or throws inferenceFailed. |
| AC-007 | When useLocalLlm is true on web, create shall throw AgentFailure with AgentErrorCode.unsupportedProfile. | Dart test. | A web LLM session is constructed or native create is called. |
| AC-008 | When ConversationMode.fullDuplexRequired is requested on web, create shall throw AgentFailure with AgentErrorCode.unsupportedProfile. | Dart test. | A full-duplex web session starts. |
| AC-009 | When web start runs without a secure context, the system shall throw AgentFailure with AgentErrorCode.unsupportedProfile and shall not open capture. | Test or documented fake insecure context; source review of the secure-context guard. | Capture starts on a non-secure context. |
| AC-010 | When web microphone permission is denied, start shall fail with AgentErrorCode.permissionDenied and shall not start capture or playback. | Unit or bridge test of the denial path. | Capture or TTS playback starts after denial. |
| AC-011 | When a web session is listening, the web backend shall feed 16 kHz mono frames to Silero VAD only inside that backend, and LocalVoiceAgent events shall contain no sample arrays. | Review the web backend and event types; test that AgentEvent payloads have no PCM fields. | A public event or method-channel argument carries samples. |
| AC-012 | When VAD finalizes an utterance on web, the system shall emit a finalized transcript, call LocalReplyLogic, synthesize the reply with VITS, and play audio, while refusing new speech admission until speaking ends or interrupt runs. | Fake VAD finalization test plus source review of the half-duplex gate. | A second listen is admitted during speaking, or logic is skipped. |
| AC-013 | When interrupt runs during web speaking, the system shall flush playback, invalidate the current generation, and return to a listening or idle state without emitting the cancelled audio. | Dart test with a fake player. | Playback continues after interrupt, or a cancelled generation is spoken. |
| AC-014 | When the example web host is built, flutter build web shall exit 0 after the compact pack path is present or stubbed as the documented example setup requires. | Run the documented example web build and paste the exit code. | A non-zero build, or a success claim without command output. |
| AC-015 | When this work item is verified, Android, iOS, macOS, Windows and Linux plugin sources shall still own native audio through flva, and work 0002 VITS allocation, physical mobile qualification and clean consumer-install shall remain recorded as open. | Diff review of native plugin folders; read 0002 STATE.yaml blockers. | A 0010 document states those parent gates are closed, or native plugins start sending PCM through Dart. |

## Non-functional criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-016 | When the web backend logs, those logs shall not contain raw PCM samples or waveforms. | Search new web log sites. | A log line prints frame values or a waveform. |
| AC-017 | When the plugin package is inspected, catalog model weights shall not be shipped inside the plugin package; only pinned WASM runtime assets and notices may be added. | Search the package layout and pubspec assets. | Compact or full LJS or VCTK weights appear under the plugin package assets. |
| AC-018 | When third-party WASM is vendored, an Apache-2.0 notice and a pinned SHA-256 shall be present, and a digest mismatch shall copy or load nothing. | Inspect the notice and pin; reuse the AC-005 mismatch test. | Unattributed WASM, or a mismatch that still loads. |

## Explicitly not required

- Streaming Zipformer or OnlineRecognizer on Flutter web.
- Full-precision LJS or a required VCTK speaker picker on the first web example.
- Optional llama.cpp or wllama.
- A dependency on sherpa_onnx or record.
- Physical microphone-to-speaker qualification on Android or iPhone.
- Closing parent 0002 AC-004, AC-005, AC-007 or AC-008.
- Safari evidence if only a Chrome or headless web build is available. Record the gap.
- Full duplex, AEC, barge-in, background capture or wake word.
- Model redistribution, commit or publication.
- Changing native sample rates, Android ABIs or iOS session mode.
- Compiling flva.cpp to WASM.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
| research-01 | 2026-09-22 | PASS | validation/research-review-01.md |
| plan-01 | 2026-09-22 | FAIL | validation/plan-review-01.md |
| plan-02 | 2026-09-22 | PASS | validation/plan-review-02.md |
