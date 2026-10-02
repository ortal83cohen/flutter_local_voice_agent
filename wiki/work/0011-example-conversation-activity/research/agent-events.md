# Agent events observed by the example

## Question

Which lifecycle and activity values does `LocalVoiceAgent` actually emit, and when does the example overwrite its status string with raw enum names?

## Answer

- The example overwrites `status` with the raw string `<lifecycle.name> · <activity.name>` on every `AgentEvent`, whatever its kind, lifecycle or activity (`example/lib/voice_screen_controller.dart:584`). The only exception is an event that carries a `failure`. That event gets a fixed failure sentence instead (`example/lib/voice_screen_controller.dart:590-594`).
- The only event-level exception to raw names is therefore the failure sentence. No branch maps any `TurnActivity` or `AgentLifecycle` value to human-readable text.
- `AgentEvent.lifecycle` is the agent's own `lifecycle` field at emit time. It is not read from the native payload (`lib/src/agent.dart:484`). In practice it is `running`, `suspended` or `failed`. `ready`, `stopping` and `disposed` are assigned to the field but never delivered in a state event. `initializing` is never assigned anywhere in `lib/`.
- `AgentEvent.activity` comes from the native payload and is parsed for all six `TurnActivity` values (`lib/src/agent.dart:662-670`). The agent synthesizes `idle` itself for suspended and fatal events. Which activities native code actually sends is [UNVERIFIED] because native sources were out of scope.
- `start()` deliberately does not write a success status (`example/lib/voice_screen_controller.dart:480`). After the Start button, `status` keeps its previous text until the first event arrives.
- `interrupt()` and `stop()` write fixed success sentences after the call completes (`example/lib/voice_screen_controller.dart:483-491, 511-513`). Any later event overwrites them with raw names.

## Findings

### Enum values that exist

- Claim: `AgentLifecycle` has 7 values, `TurnActivity` has 6 values, and `AgentEventKind` has 5 values.
- Evidence: `AgentLifecycle` is `initializing, ready, running, suspended, stopping, failed, disposed`. `TurnActivity` is `idle, listening, recognizing, thinking, speaking, interrupting`. `AgentEventKind` is `state, partialTranscript, finalTranscript, replyText, fault`.
- Source: `lib/src/models.dart:13-33` (AgentLifecycle), `lib/src/models.dart:37-54` (TurnActivity), `lib/src/models.dart:58-72` (AgentEventKind).

### AgentEvent carries lifecycle and activity "after applying the event"

- Claim: Every `AgentEvent` has non-null `lifecycle` and `activity` fields, plus nullable `text` and `failure`.
- Evidence: Constructor requires `sequence, generation, kind, lifecycle, activity`. Field docs say "Lifecycle after applying the event" and "Turn activity after applying the event".
- Source: `lib/src/models.dart:182-213`.

### Where the agent assigns lifecycle

- Claim: The agent assigns lifecycle only in these places. `initializing` is never assigned.
- Evidence:
  - Field default is `ready` (`lib/src/agent.dart:204`).
  - `running` is set at the end of `_start` after a successful native start (`lib/src/agent.dart:259`).
  - `suspended` is set when a native `suspended` event arrives (`lib/src/agent.dart:414-419`).
  - `stopping` is set at the start of `_stop` (`lib/src/agent.dart:322`).
  - After `_stop`, lifecycle becomes `ready`, or `disposed` if the agent was disposed (`lib/src/agent.dart:331-333`). On a platform error in `_stop` it becomes `failed` (`lib/src/agent.dart:327`).
  - `disposed` is set in `_dispose` (`lib/src/agent.dart:363`). `failed` is set on a platform error there (`lib/src/agent.dart:367`).
  - `failed` is set in the event-stream overflow handler (`lib/src/agent.dart:164`) and in `_fatal` (`lib/src/agent.dart:566`).
  - A repo-wide grep for `AgentLifecycle.initializing` over `*.dart, *.kt, *.swift, *.cc, *.cpp, *.h, *.js, *.md` found no reference.
- Source: `lib/src/agent.dart:164, 204, 259, 322, 327, 331-333, 363, 367, 419, 566`.

### Where the agent assigns activity

- Claim: The agent sets activity itself only for `listening` (on start), `interrupting` (on interrupt) and `idle` (stop, dispose, suspend, fatal). All other values come from native events.
- Evidence:
  - Field default is `idle` (`lib/src/agent.dart:207`).
  - `listening` is set at the end of `_start` (`lib/src/agent.dart:260`).
  - `interrupting` is set in `interrupt()` (`lib/src/agent.dart:292`).
  - `idle` is set in `_stop` (`lib/src/agent.dart:334`), `_dispose` (`lib/src/agent.dart:364, 368`), the suspended branch (`lib/src/agent.dart:420`) and `_fatal` (`lib/src/agent.dart:567`).
  - For other native events, `activity = eventActivity` (`lib/src/agent.dart:450`), where `eventActivity` is parsed from the native string by `_activity`, which maps all six names (`lib/src/agent.dart:436, 662-670`).
  - An unparseable activity is fatal "Malformed native event." (`lib/src/agent.dart:437-445`).
- Source: `lib/src/agent.dart:207, 260, 292, 334, 364, 367-368, 420, 436-450, 567, 662-670`.

### Which assignments actually produce an event

- Claim: Setting `lifecycle` or `activity` does not by itself emit an event. Events are added in only four places.
- Evidence:
  - Suspended branch of `_accept`, which adds a `state` event with `lifecycle: suspended` and `activity: idle` (`lib/src/agent.dart:414-431`).
  - Normal native events in `_accept`, which add an event whose `kind` is mapped from `state, partial, final, reply, error` (`lib/src/agent.dart:451-489`).
  - `_emit(AgentFailure)`, which adds a `fault` event using the current `lifecycle` and `activity` (`lib/src/agent.dart:555-563`). `_fatal` calls it after setting `failed` and `idle` (`lib/src/agent.dart:565-568`).
  - The terminal value of the bounded stream is a `fault` event with `lifecycle: failed`, `activity: idle` and a capacity failure (`lib/src/agent.dart:154-161`).
  - No event is added in `start()`, `_start`, `interrupt()`, `_stop` or `_dispose` (`lib/src/agent.dart:212-258, 289-298, 321-336, 355-373`). `_dispose` only closes the stream (`lib/src/agent.dart:365`).
- Source: `lib/src/agent.dart:154-161, 414-431, 451-489, 555-568`.

### Consequence: lifecycle values the example can observe in events

- Claim: Inferred from the previous finding, the example can observe `running`, `suspended` and `failed` in normal operation. It cannot observe `initializing`. `ready`, `stopping` and `disposed` are not delivered in state events by the code read.
- Evidence:
  - Polling only runs while `_started` is true and the epoch matches (`lib/src/agent.dart:389, 397`), and `_started` is set together with `running` (`lib/src/agent.dart:258-259`). Native events accepted at `_accept` therefore carry `running`.
  - `suspended` and `failed` come from the suspended branch, `_fatal` and the overflow terminal value (see above).
  - Edge case: `_emit` can run from `_logicError` or `_backgroundStop` while lifecycle is something else, for example after a stop has started (`lib/src/agent.dart:539-553, 588-593`). A `fault` event with `stopping` or `ready` is therefore possible, but I did not verify a concrete path. [UNVERIFIED]
- Source: `lib/src/agent.dart:258-259, 389-402, 414-431, 539-568, 588-593`.

### Which activities native sends

- Claim: [UNVERIFIED] Which of `listening`, `recognizing`, `thinking`, `speaking`, `interrupting` and `idle` the native layer actually puts in payloads.
- Evidence: The Dart side accepts all six (`lib/src/agent.dart:662-670`). Native sources were not read. Test code references `TurnActivity.thinking` in a fake event (`test/web_backend_test.dart:64`), which shows only that the Dart side can represent it. Beyond the enum/parse mapping above, `recognizing`, `thinking` and `speaking` are not referenced in `lib/`.
- Source: `lib/src/agent.dart:662-670`, `test/web_backend_test.dart:64`.

### Example: `_handleAgentEvent` overwrites status unconditionally

- Claim: For every event the example sets `status` to the raw `lifecycle.name · activity.name` string, including values such as `running · listening` or `suspended · idle`.
- Evidence: The method returns early only if the controller is disposed. It then logs and sets `status = '${event.lifecycle.name} · ${event.activity.name}'` with no branching on kind, lifecycle or activity.
- Source: `example/lib/voice_screen_controller.dart:579-584`.

### Example: transcript and reply text routing

- Claim: `partialTranscript` and `finalTranscript` set `heard`. `replyText` sets `reply`. These do not touch `status` beyond the unconditional write above.
- Evidence: `heard = event.text ?? ''` for the two transcript kinds, and `reply = event.text ?? ''` for `replyText`. `heard` and `reply` are never cleared elsewhere in the controller (grep of `heard` and `reply` assignments found only lines 587 and 589 apart from field declarations at 145-146).
- Source: `example/lib/voice_screen_controller.dart:145-146, 585-589`.

### Example: failure events replace the raw string

- Claim: Any event with a non-null `failure` sets `phase = failed` and replaces `status` with a fixed message, even if the failure is non-fatal.
- Evidence: The check is `event.failure != null`. It does not read `failure.fatal`, `failure.code` or `failure.message`. Non-fatal failures such as "Previous logic has not settled" (`lib/src/agent.dart:505-513`) also reach this branch.
- Source: `example/lib/voice_screen_controller.dart:590-594`, `lib/src/agent.dart:471-478, 505-513`.

### Example: start, interrupt and stop status writes

- Claim: `start()` never writes a success status. `interrupt()` and `stop()` write a fixed sentence after the native call finishes, if the session is still current. Any exception in these calls writes a fixed failure sentence.
- Evidence:
  - `start` passes `overwriteStatus: false` and a `success` string that is never used on the success path (`example/lib/voice_screen_controller.dart:476-481, 511-513`).
  - `interrupt` success is "Interrupted. The microphone will listen for the next turn." (`example/lib/voice_screen_controller.dart:483-486`).
  - `stop` success is "Stopped. Tap Start when you want to continue." (`example/lib/voice_screen_controller.dart:488-491`).
  - On any thrown object the status becomes "The local speech action failed. Check microphone access and try again." (`example/lib/voice_screen_controller.dart:514-517`).
  - `_runSession` returns early if `operationBusy` or there is no session (`example/lib/voice_screen_controller.dart:500`).
- Source: `example/lib/voice_screen_controller.dart:476-491, 493-521`.

### Example: other status writers that interact with event-driven status

- Claim: Besides events, these paths write `status` while a session may exist: session event stream error, background, resume.
- Evidence:
  - Stream error sets `phase = failed` and "The local speech session stopped unexpectedly. Prepare the model again." (`example/lib/voice_screen_controller.dart:331-341`).
  - `onBackground` sets "Stopped while the app is in the background." when a session exists and no preparation was active (`example/lib/voice_screen_controller.dart:536-542`).
  - `onResume` sets "Ready. Tap Start when you want to continue." only if a session exists and `phase == ready` (`example/lib/voice_screen_controller.dart:549-555`).
  - Session creation ends with "Ready. Tap Start and allow microphone access." (`example/lib/voice_screen_controller.dart:349`).
- Source: `example/lib/voice_screen_controller.dart:331-341, 349, 523-556`.

### Example: how the UI shows status and enables controls

- Claim: The UI renders `controller.status` verbatim in a `Text` with key `status`. Button enablement depends on `canStart`, `hasSession` and `operationBusy`, not on lifecycle or activity.
- Evidence: `Text(controller.status, key: const Key('status'))`. Start is enabled by `controller.canStart && !controller.operationBusy`. Interrupt and Stop are enabled by `controller.hasSession && !controller.operationBusy`. `canStart` checks `phase == ready`, a non-null session, a selected option and a valid speaker id.
- Source: `example/lib/main.dart:177, 246-261`, `example/lib/voice_screen_controller.dart:160-167`.

### Per-value table: does `_handleAgentEvent` replace status?

All rows share one behavior: `_handleAgentEvent` replaces `status` with the raw string at `example/lib/voice_screen_controller.dart:584`. The exception is an event with `failure != null`, which uses the fixed failure sentence (`example/lib/voice_screen_controller.dart:590-594`).

| Value | Type | Can appear in an event the example receives? | Status behavior in `_handleAgentEvent` | Source |
|---|---|---|---|---|
| `initializing` | lifecycle | No. Never assigned in `lib/`. | Would be raw, but not reachable. | `lib/src/models.dart:15` |
| `ready` | lifecycle | Not in a normal state event. It is the field default and the post-stop value, but no event is emitted for it. A fault event with `ready` is possible but [UNVERIFIED]. | Raw if it appears. | `lib/src/agent.dart:204, 331-333` |
| `running` | lifecycle | Yes. All native events accepted while started carry it. | Raw, for example `running · listening`. | `lib/src/agent.dart:259, 484` |
| `suspended` | lifecycle | Yes. Suspended branch adds a `state` event. | Raw: `suspended · idle`. | `lib/src/agent.dart:419-431` |
| `stopping` | lifecycle | No state event. A fault event during stop is possible but [UNVERIFIED]. | Raw if it appears. | `lib/src/agent.dart:322` |
| `failed` | lifecycle | Yes. Fatal and overflow `fault` events carry it. | Failure sentence, not raw (the failure is non-null). | `lib/src/agent.dart:154-161, 566-568` |
| `disposed` | lifecycle | No. `_dispose` closes the stream without an event. | Not reachable. | `lib/src/agent.dart:363-365` |
| `idle` | activity | Yes, from native (`idle` is parsed) and from suspended and fatal events. | Raw. | `lib/src/agent.dart:420, 567, 663` |
| `listening` | activity | Parsed from native; whether native sends it is [UNVERIFIED]. The agent sets it on its own field at start without an event. | Raw. | `lib/src/agent.dart:260, 664` |
| `recognizing` | activity | Parsed from native; native emission [UNVERIFIED]. | Raw. | `lib/src/agent.dart:665` |
| `thinking` | activity | Parsed from native; native emission [UNVERIFIED]. | Raw. | `lib/src/agent.dart:666` |
| `speaking` | activity | Parsed from native; native emission [UNVERIFIED]. | Raw. | `lib/src/agent.dart:667` |
| `interrupting` | activity | Parsed from native; native emission [UNVERIFIED]. The agent sets it on its own field in `interrupt()` without an event. | Raw. | `lib/src/agent.dart:292, 668` |

## Constraints discovered

- The agent's `lifecycle` field is the source of `AgentEvent.lifecycle`, not the native payload (`lib/src/agent.dart:484`). Any mapping in the example from lifecycle to text must therefore cover only `running`, `suspended` and `failed` as normal event values, with a safe fallback for the rest.
- Event lifecycle and activity are snapshots. The agent changes its fields without emitting (`start`, `interrupt`, `stop`), so the example cannot learn about the `listening` or `interrupting` transitions that the agent makes locally unless native also sends them (`lib/src/agent.dart:260, 292`).
- `start()` sets no status on success (`example/lib/voice_screen_controller.dart:480`), so a gap exists between the tap and the first event.
- The event stream is single-listener and bounded at capacity 32 (`lib/src/agent.dart:152-153, 209-210`). Overflow ends the session with a `failed` fault event (`lib/src/agent.dart:154-170`).
- Failure handling in the example does not distinguish fatal from non-fatal failures (`example/lib/voice_screen_controller.dart:590-594`).
- Scope fences from the parent: no change to the `lib/` public API and no new event kinds. All findings above rely on the existing enums only.
- `AgentEvent` has no field that describes the reason for a state change. The only extra context is `kind`, `text` and `failure` (`lib/src/models.dart:182-213`).

## Unresolved

- [UNVERIFIED] Which `TurnActivity` values the native layers (Android, iOS, macOS, Windows, Linux, web) actually send, and in what order during a turn.
- [UNVERIFIED] Whether the native layer sends a `state` event immediately after `start`. This decides whether the post-Start status gap is brief or long.
- [UNVERIFIED] Whether a `fault` event can be delivered with `lifecycle` `stopping` or `ready`. The agent code allows it, but no concrete path was traced.
- [UNVERIFIED] What the example tests assert about `status` strings. The test directory for the example was not read.
