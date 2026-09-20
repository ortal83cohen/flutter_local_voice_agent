# Verification: Android audio and ASR instrumentation

## Commands

- `git diff --check` — passed with no output.
- `dart format lib example/lib` — blocked by the Flutter SDK cache permission error: `/Users/ortalcohen/flutter/bin/cache/engine.stamp: Operation not permitted`.
- `dart analyze --fatal-infos --fatal-warnings` — blocked by the same Flutter SDK cache permission error.

## Source evidence

- Android logs now cover session creation/start, audio format, capture reads, frame counts, mean absolute amplitude, peak amplitude, push results, polling event kinds, and stop totals.
- JNI logs rejected buffers and push results.
- Native Android logs VAD speech onset and ASR partial/final text lengths.
- Dart logs poll batches, event kinds, activity, and text lengths; the example logs UI delivery.
- `git diff --check` found no whitespace errors.
- The follow-up tuning changes use an 8,000-sample pre-roll, a 0.38 VAD onset threshold, Android `VOICE_COMMUNICATION`, and bounded suffix preservation for runtimes that expose only the newest ASR span.

## Remaining device gate

No physical Android run was performed after the tuning changes. The following remains [UNVERIFIED]: whether the device produces non-zero Float32 microphone frames, whether `nativePush` accepts them continuously, whether the first syllable is retained, and whether the native ASR produces complete English text. Use the Android log filter `FLVA` during one spoken English phrase and compare the capture, push, VAD, ASR, poll, and UI lines in that order.

## Scope boundary

This change adds diagnostics only. It does not claim that Android recognition is fixed or qualified, and it does not alter model files, VAD thresholds, audio formats, or recognition behavior.
