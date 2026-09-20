# flutter_local_voice_agent

An offline Flutter voice pipeline using on-device speech models. The package
connects native microphone audio to Silero VAD, streaming Zipformer speech
recognition, local response logic, VITS synthesis and native playback. Audio
never travels through Dart platform messages. Creation and inference remain
offline. Hosts can explicitly prepare trusted models over HTTPS using the
separate [preparation API](doc/model-preparation.md).

**Development preview.** Physical Android/iPhone qualification, voice quality,
resource budgets and binary/model redistribution review remain open. The VITS
backend generates complete sentences before its PCM callback; the render queue
is bounded, but upstream synthesis allocation is not yet proven to satisfy the
specification's hard duration/memory budget. Do not treat this preview as a
production-qualified SDK.

## Setup

Use Flutter 3.47.0 / Dart 3.13.0. Android targets API 26+ and arm64-v8a; the
reference application uses the generated Flutter toolchain. iOS uses
CocoaPods and AVAudioEngine. Build verification and physical qualification are
separate; see [capabilities](doc/capabilities.md).

This preview currently requires a repository checkout and a local Flutter path
dependency pointing to that checkout. Run the following commands from its root.
The pub archive excludes native runtime binaries and provisioning tools; a
zero-warning package dry run does not establish a standalone consumer install.
Native dependency packaging remains unfinished.

Provision native dependencies explicitly during development:

```sh
python3 tool/provision_runtime.py android
python3 tool/provision_runtime.py ios
flutter pub get
```

These commands download SHA-256 pinned sherpa-onnx 1.12.14 build artifacts.
For a network-free build input step, pass `--archive /path/to/the/archive`.
They are never invoked by the running application. No model weights ship here.
The example downloads a selected verified model pack on first use; see the
[model catalog](doc/model-catalog.md). Advanced hosts can still construct
[local packs](doc/models.md).

## Explicit model preparation

`ModelPreparationManager` can prepare a host-supplied trusted descriptor into a
host-chosen private directory, with integrity checks, cancellation and verified
offline reuse. It returns `LocalModelBundle` for the existing agent API. See the
[preparation guide](doc/model-preparation.md) for the complete contract and limits.
`VoiceModelCatalog.entries` supplies compact and full-precision English speech
packs with pinned hashes and source notices. The example handles private storage,
selection and download. Native build inputs above are still required; published
consumer native dependency packaging remains unfinished.

## Use

```dart
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';

final agent = await LocalVoiceAgent.create(
  models: LocalModelBundle(
    directory: '/app-private/models/english',
    manifestPath: '/app-private/models/english/manifest.json',
  ),
  logic: (transcript) async => 'Hello. How are you?',
);
final subscription = agent.events.listen((event) {
  // Display typed state, transcript, reply, or failure events.
});
await agent.start();
// At a user interruption:
await agent.interrupt();
// Before leaving the foreground conversation:
await agent.stop();
await subscription.cancel();
await agent.dispose();
```

Manifest validation and model loading precede microphone activation. Start asks
for microphone permission. A missing/corrupt asset or refused permission is an
explicit `AgentFailure`; there is no cloud fallback. iOS applications must add
`NSMicrophoneUsageDescription`. Android declares `RECORD_AUDIO` through the
plugin and requests it from the foreground Activity.

Logic replies must be nonempty, contain valid Unicode scalars without NUL, and
fit within 240 scalars and 960 UTF-8 bytes. Invalid replies emit a typed fault
and interrupt the turn before native synthesis; the next turn can proceed.
These input checks do not remove the upstream VITS allocation limitation.

The host supplies trusted local assets and must not mutate them while a session
is alive. `FileModelStore.install` copies into staging, validates again and
renames to a fresh directory; it does not remove older active packs. An integrity
manifest is not an authenticity signature. Do not load untrusted ONNX/GGUF files.

Use one agent per Flutter engine. Stop on backgrounding. OS focus loss,
interruption, route removal or severe thermal pressure suspends operation;
resuming requires an explicit Start. Recreate the agent when iOS reports a
changed input format. Audio-session ownership must be coordinated with any other
audio plugins in the host app.

## Example and checks

```sh
cd example
flutter run
```

Choose **English compact (INT8)** or **English standard (full precision)**,
review the download size, then tap **Download**. Preparation reports progress
and can be cancelled or retried. After the engine is ready, tap **Start**, allow
the microphone, and try “hello”, “what is your name”, or “thank you”. These are
fixed local demo replies, not a general-purpose LLM conversation. Interrupt and
Stop are explicit controls. Later launches restore the selected installed pack
without networking. No model directory or manifest entry is required.

The packs use the same English voice at different precision levels. No Hebrew,
other language, physical-device performance or voice-quality guarantee is implied.
See [catalog, storage and troubleshooting](doc/model-catalog.md).

```sh
flutter test
dart format lib example/lib
dart analyze --fatal-infos --fatal-warnings
python3 tool/lint_wiki.py
```

[Optional LLM](doc/llm.md) documents the separate CPU build.

[Native testing](doc/testing.md) describes genuine engine smoke tests and the
remaining device/offline/performance matrix. Scheduler test fixtures are not
substitutes for real engines. [Dependency notices](third_party/README.md) cover
the vendored header and locally provisioned binary/model boundary. No publish,
commit, push or deployment step is part of these instructions.
