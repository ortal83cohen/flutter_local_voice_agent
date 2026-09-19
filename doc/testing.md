# Verification and physical qualification

## Dart

```sh
flutter pub get
flutter test
dart format lib example/lib
dart analyze --fatal-infos --fatal-warnings
python3 tool/lint_wiki.py
```

These tests use actual temporary files for manifest integrity and injected
platform schedulers for lifecycle fault cases. They do not count as speech-engine
or microphone tests. Flutter 3.47.0 / Dart 3.13.0 is the validation toolchain.

## Native

```sh
python3 tool/test_native.py --ubsan
```

This runs bounded-ring and stateful resampler tests. Add `--runtime` pointing to
the local sherpa `lib` directory and `--assets` with these nine absolute paths,
in order: Silero, encoder, decoder, joiner, ASR tokens, VITS model, VITS tokens,
VITS lexicon, and mono 16 kHz PCM16 test WAV. The script compiles and runs real
speech smoke and failure tests. It has no fake-engine mode. It checks repeated
real turns, stale replies, overflow, invalid assets/rates, interruption, silence
after cancellation and stop/dispose.

`--sanitize` additionally requests ASan. The local host's ASan runtime stalled
before `main` even for an empty probe; that run is not counted as passed. UBSan
and ordinary tests execute separately. Upstream prebuilt inference libraries
are not sanitizer-instrumented, so a sanitized bridge is not proof about their
internal memory behavior.

## Mobile builds

```sh
python3 tool/provision_runtime.py android --archive /local/pinned-android.tar.bz2
python3 tool/provision_runtime.py ios --archive /local/pinned-ios.tar.bz2
cd example
flutter build apk --debug --target-platform android-arm64
flutter build ios --simulator --debug --no-codesign
flutter build ios --release --no-codesign
```

Builds prove source compilation and linkage for that variant. A simulator does
not qualify iPhone microphones, audio focus, routes, thermals or memory. Debug
and unsigned artifacts are not release/store approval. Optional LLM builds are
described in [the LLM guide](llm.md).

## Local model installation for the example

Create and validate a trusted pack as described in [models](models.md). For an
installed Android debug example, explicitly copy into its private storage:

```sh
adb shell run-as dev.localvoice.flutter_local_voice_agent_example mkdir -p files/models
tar -C /local/trusted-pack -cf - . | adb shell run-as dev.localvoice.flutter_local_voice_agent_example tar -xf - -C files/models
```

Enter `/data/user/0/dev.localvoice.flutter_local_voice_agent_example/files/models`
in the example. This example command is an operator instruction; it was not run
against a physical device during development. On a booted iOS simulator, obtain
the data container with `xcrun simctl get_app_container booted
 dev.localvoice.flutterLocalVoiceAgentExample data`, copy the pack into its
Documents directory, and enter the resulting absolute path. A real iPhone
requires a host-owned import/bundled-asset flow.

## Required device protocol (still open)

Use at least two Android tiers and two iPhone generations for release decisions.
Record app revision, exact models and hashes, compiler/runtime versions, OS,
route, thermal state, thread counts, context, output rate and power conditions.
Run 100 warm utterances, 20 independent cold starts and a 30-minute sustained
session; include failed and cancelled trials. Measure p50/p95 speech-end to first
audible output, externally measured interruption tail, WER/CER, command success,
process/native memory, battery/thermal trajectory, dropped capture and render
underflow. Do not substitute Dart timestamps for audible speaker timing.

Test clean local installation and restart with network denied. Cover permission
deny/revoke, phone interruption, focus loss, backgrounding, headphones removed,
Bluetooth/USB changes, silence/noise, maximum-duration speech, cancellation during
load/ASR/logic/TTS/playback, repeated stop/dispose, slow event consumers, invalid
models and low storage. Capture evidence of microphone release after stop.

Full duplex remains unavailable until self-echo and double-talk tests meet
ratified false/missed-interruption limits on each supported route. Simultaneous
capture/playback is not AEC evidence. No physical device was connected during
this implementation; no physical performance or acoustic numbers are claimed.
