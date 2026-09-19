# flutter_local_voice_agent

An offline Flutter voice pipeline using locally supplied models. The package
connects native microphone audio to Silero VAD, streaming Zipformer speech
recognition, local response logic, VITS synthesis and native playback. Audio
never travels through Dart platform messages. No model is downloaded at runtime.

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

Provision native dependencies explicitly during development:

```sh
python3 tool/provision_runtime.py android
python3 tool/provision_runtime.py ios
flutter pub get
```

These commands download SHA-256 pinned sherpa-onnx 1.12.14 build artifacts.
For a network-free build input step, pass `--archive /path/to/the/archive`.
They are never invoked by the running application. No model weights ship here.
Follow [local model installation](doc/models.md) to construct a trusted pack.

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
flutter run --dart-define=MODEL_DIRECTORY=/device/private/model-pack
```

The model directory is a path **on the target**, not your development machine.
The screen also accepts a path manually. Load models, tap Start, and try
“hello”, “what is your name”, or “thank you”. Interrupt and Stop are explicit
controls. See the model guide for Android/iOS provisioning paths.

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
