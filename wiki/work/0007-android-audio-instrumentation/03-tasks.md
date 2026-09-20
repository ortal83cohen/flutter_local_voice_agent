# Tasks: Android audio and ASR instrumentation

## Legend

- `[P]` — may run in a parallel subagent.
- Every task cites the criteria it satisfies.

## Groups

### Group 1 — Instrumentation

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | Add rate-limited Android lifecycle, capture, and JNI diagnostics. | AC-001, AC-002, NFR-001 | `android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt`, `android/src/main/cpp/bridge.cpp` | | Capture boundaries are observable without raw PCM |
| 1.2 | Add native queue, VAD, ASR, and event diagnostics. | AC-002, AC-003, NFR-001 | `native/src/flva.cpp` | | Native event flow is observable and bounded |
| 1.3 | Add Dart polling and UI event diagnostics. | AC-004, NFR-001 | `lib/src/agent.dart`, `example/lib/voice_screen_controller.dart` | | Dart delivery is observable |

### Group 2 — Verification

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 2.1 | Run repository checks and record evidence and device boundary. | AC-005 | `wiki/work/0007-android-audio-instrumentation/04-verification.md` | | Commands and limitations are recorded |

## Serialised files

| File | Owning task |
|---|---|
| `native/src/flva.cpp` | 1.2 |
| `android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt` | 1.1 |

## Test tasks

| # | Covers | Positive case | Negative case |
|---|---|---|---|
| T1 | AC-001–AC-004 | Source/build checks show required diagnostic fields | Source review confirms no raw PCM/unbounded transcript logging |
