# Plan: Android audio and ASR instrumentation

## Goal

Make one Android test run sufficient to show whether audio is captured, admitted to the native queue, recognized by VAD, decoded by ASR, surfaced through Dart polling, and rendered in the example UI.

## Approach

Add opt-in diagnostic logging at the Dart event boundary, Android lifecycle and capture boundary, JNI bridge, and native VAD/ASR/event boundary. Logs will use a stable tag and include counters, frame counts, finite-value checks, RMS ranges, return values, event kinds, text lengths, and bounded transcript previews. Raw samples and full model paths remain excluded.

The instrumentation will be rate-limited for repetitive audio operations while preserving the first frame, periodic summaries, failures, and every recognition event. This keeps logs useful on a real device without changing the audio scheduling contract.

Add focused tests for the pure diagnostic calculations and retain the existing native/Dart tests. Device execution remains a separate verification gate because this checkout has no connected-device evidence.

## Why this approach

Logging only Dart events cannot identify a silent or rejected capture buffer. Logging raw samples would create unnecessary privacy exposure. Boundary summaries provide the required diagnosis with lower operational and privacy cost.

## Steps

1. Create the work item artifacts and freeze acceptance criteria.
2. Add shared Android and native diagnostic helpers and log lifecycle, capture, JNI, queue, VAD, ASR, and event transitions.
3. Add Dart/controller event logs that correlate poll batches and UI transcript updates.
4. Run formatting, analysis, unit tests, native tests where available, and inspect the diff while preserving unrelated changes.
5. Record verification limits and device-run instructions in the work item.

## Interfaces and shared decisions

- Diagnostic tag: `FLVA`.
- All repetitive logs are summary logs; no raw PCM is emitted.
- Transcript logs report length and a bounded escaped preview only.
- Logging is diagnostic-only and does not alter event ordering, buffering, or recognition thresholds.

## Risks

| Risk | Likelihood | Impact | Mitigation | Trigger that means it happened |
|---|---|---|---|---|
| Audio-thread logging affects timing | Medium | High | Log only periodic summaries and failures | Recognition changes only when logging is enabled |
| Logs expose speech content | Low | High | Length plus short bounded preview; document device-log sensitivity | Full transcript or PCM appears in log output |
| Platform builds reject logging APIs | Low | Medium | Use existing Android and C++ logging facilities and run checks | Build or analysis failure |

## Rollback

Revert only the instrumentation files from this work item; do not revert unrelated working-tree changes.

## Out of scope

- Changing the ASR model, VAD thresholds, audio format, or recognition algorithm.
- Claiming Android device qualification without a real device run.
- Adding remote telemetry or persistent log storage.

## Verification approach

Run the repository format, analysis, and test commands. Review log calls for rate limiting and privacy. On Android, capture one run from app start through a spoken English phrase and inspect the `FLVA` sequence from audio frames through transcript events.
