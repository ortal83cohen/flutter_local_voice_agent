# Acceptance criteria: Reasonable platform coverage

## Frozen

- Frozen at: 2026-09-20
- Frozen by: root after plan-review-02 PASS and user authorization to freeze without starting implementation

## Criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-001 | When LocalVoiceAgent.create runs on Flutter web or another target that cannot load the native session, the system shall throw AgentFailure with AgentErrorCode.unsupportedProfile before invoking native create. | Run a Dart test that injects or simulates an excluded target and assert the error code and that the fake native create call count stays zero. | A test that expects create to reach the method channel or to throw inferenceFailed fails. |
| AC-002 | When pubspec.yaml is read, the plugin shall declare android, ios, macos, windows and linux platform entries and shall not declare a web plugin entry. | Inspect pubspec.yaml plugin platforms. | A missing desktop key or a web plugin key fails the check. |
| AC-003 | When tool/provision_runtime.py is invoked for macos, windows or linux with an archive whose SHA-256 does not match the pinned digest, the command shall exit non-zero and shall not copy a sherpa library into the platform plugin folder. | Run the script against a small file with a wrong digest and inspect the destination folder. | A mismatched archive that still copies a library fails the check. |
| AC-004 | When tool/provision_runtime.py is invoked for macos, windows or linux with the matching official v1.12.14 archive, the command shall verify the pinned digest and install the expected shared library files used by that platform's build. | Run the script with a local matching archive or record the measured digest install on a provisioned checkout. | A successful exit with missing expected library names fails the check. |
| AC-005 | When the macOS plugin is active after microphone permission is granted, capture callbacks shall call flva_push and render callbacks shall call flva_render, and neither microphone nor playback PCM shall appear as method-channel arguments. | Review macos plugin sources and any helper tests; search the method-channel codec path for audio payloads. | A plugin that forwards PCM lists or byte arrays through the channel fails the check. |
| AC-006 | When the macOS example is built on this host after macOS runtime provisioning, the Flutter macOS build shall exit 0. | Run the documented macOS example build and paste the exit code. | A non-zero build or a claim of success without command output fails the check. |
| AC-007 | When macOS microphone permission is denied, start shall fail with AgentErrorCode.permissionDenied and shall not start capture. | Review the macOS permission path and add a unit or bridge test that denied access returns permissionDenied; on a device run, deny the prompt and confirm no capture start. | Start that opens AVAudioEngine after denial fails the check. |
| AC-008 | When the Windows plugin sources are present, they shall register the same method names, own WASAPI capture and render, call the flva ABI, and map endpoint invalidation to audioUnavailable or routeChanged suspension. | Source review plus any extractable conversion tests. A Windows Flutter build is recorded only if a Windows runner exists. | Sources that send PCM through Dart or omit flva_push and flva_render fail the check. |
| AC-009 | When the Linux plugin sources are present, they shall register the same method names, own PulseAudio record and playback streams, call the flva ABI, and map server or default-device loss to audioUnavailable or routeChanged suspension. | Source review plus any extractable conversion tests. A Linux Flutter build is recorded only if a Linux runner exists. | Sources that require a non-Pulse ALSA-only rewrite as the only path, or that send PCM through Dart, fail the check. |
| AC-010 | When this work item is verified, Android and iOS plugin bridges shall still exist and parent 0002 VITS allocation, physical mobile qualification and clean consumer-installation gates shall remain recorded as open. | Diff review of android and ios plugin files; read 0002 STATE.yaml blockers. | A 0008 artifact that states those parent gates are closed fails the check. |

## Non-functional criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-011 | When desktop audio callbacks run, logs shall not contain raw PCM samples. | Search new plugin and native log sites for sample dumps. | A log line that prints frame values or a full waveform fails the check. |
| AC-012 | When optional local LLM is enabled on a new desktop platform, the build shall keep the existing CPU-only llama.cpp gate and shall not enable GPU backends. | Review new CMake or pod linkage for the existing FLVA_ENABLE_LOCAL_LLM and GGML off flags. | A desktop target that turns Metal, CUDA or BLAS on by default fails the check. |

## Explicitly not required

- Physical microphone-to-speaker qualification on any platform.
- Closing parent 0002 AC-004, AC-005, AC-007 or AC-008.
- Flutter web, watchOS, tvOS, Wear OS or Android TV implementations.
- A Windows or Linux Flutter desktop build on a macOS-only checkout. On 2026-09-20 the user accepted source-complete Windows and Linux plugins without that compile proof.
- Extra Android ABIs or iOS Swift Package Manager.
- Changing the current iOS AVAudioSession mode.
- Model redistribution, commit or publication.
- Full duplex, background capture or wake word.
- Identical hardware input rates across Android, iOS and desktop.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
