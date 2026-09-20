# Acceptance criteria: Android audio and ASR instrumentation

## Frozen

- Frozen at: 2026-09-20
- Frozen by: Codex

## Criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-001 | When an Android session starts, logs shall identify lifecycle start, audio format, and capture-thread progress without raw samples. | Source review and Android build checks | No log shall print PCM arrays or full audio buffers |
| AC-002 | When capture runs, logs shall report frame counts, finite/non-finite status, bounded signal statistics, and `nativePush` outcomes at a rate-limited interval. | Source review and tests | Repetitive capture shall not emit one log line per sample or buffer indefinitely |
| AC-003 | When native recognition changes state or emits `partial`, `final`, or `error`, logs shall identify event kind, generation/sequence, activity, and bounded text metadata. | Native source review and native tests | Empty or oversized text shall not cause unbounded logging |
| AC-004 | When Dart polls and updates the screen, logs shall identify poll batch size and transcript event delivery. | Dart tests/source review | A poll with no events shall not falsely report a transcript |
| AC-005 | Existing formatting, analysis, and tests shall pass, or any environment blocker shall be recorded with command output. | Recorded verification commands | No claim of device qualification without a connected-device run |

## Non-functional criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| NFR-001 | Logging shall not persist audio or introduce a new network/telemetry dependency. | Diff and dependency review | No new dependency or file sink is added |

## Explicitly not required

- This work does not prove that a physical Android device produces a transcript.
- This work does not change recognition behavior.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
