# Research: Android audio and ASR instrumentation

## Question

Which observable boundaries must be logged to identify why Android reaches speech recognition without producing English partial or final transcripts?

## Answer

The current flow spans the example controller, Dart polling, the Kotlin capture thread, JNI, and the native VAD/ASR worker. Existing host evidence does not establish physical Android microphone or ASR behavior; the instrumentation must therefore expose each boundary without logging raw audio.

## Findings

### Existing event flow

- Claim: The Dart agent polls native events every 50 milliseconds and maps `partial` and `final` events to typed transcript events.
- Evidence: `lib/src/agent.dart:157-171`, `lib/src/agent.dart:276-293`, `lib/src/agent.dart:330-376`.
- Source: Repository source.

### Android capture boundary

- Claim: Android reads mono 16 kHz Float32 frames in a dedicated thread, writes them to a direct buffer, and calls JNI `nativePush`.
- Evidence: `android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt:108-132`.
- Source: Repository source.

### Native recognition boundary

- Claim: Native VAD emits `recognizing`; ASR emits partial text only after online decoding produces a changed non-empty result, and emits final text after endpointing.
- Evidence: `native/src/flva.cpp:220-268`.
- Source: Repository source.

### Qualification boundary

- Claim: Physical Android capture, partial/final ASR, and device lifecycle behavior remain explicitly unresolved.
- Evidence: `wiki/work/0002-native-offline-pipeline/research/speech.md:161`.
- Source: Repository source.

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Log only Dart events | Shows whether native events reach the UI | Low | Rejected: cannot distinguish missing microphone frames from native ASR failure |
| Log every raw sample | Dumps all audio values | High and privacy-sensitive | Rejected: unnecessary sensitive data |
| Log counters, RMS, return codes, states and bounded text metadata at each boundary | Traces the full flow without raw audio | Moderate | Chosen |

## Constraints discovered

- Logs must not contain raw microphone samples or model paths containing user data.
- Native and Android logs must be rate-limited because audio callbacks run continuously.
- Existing dirty changes in `CHANGELOG.md` and `test/model_redirect_test.dart` are unrelated and must be preserved.

## Unresolved

- [UNRESOLVED: Whether the connected Android device currently returns valid non-zero Float32 samples.]
- [UNRESOLVED: Whether the installed Android native library matches the current source checkout.]

## Sources

- Repository source, inspected 2026-09-20.
- `wiki/work/0002-native-offline-pipeline/research/speech.md`, inspected 2026-09-20.
