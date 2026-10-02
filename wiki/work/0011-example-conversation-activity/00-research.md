# Research: Example conversation activity

## Question

How can the example show the current conversation activity in plain English without changing the library API, the three explicit controls, or the product's honesty limits?

## Answer

The example already receives lifecycle and activity on each agent event, then prints the raw enum names into the single live status line. Start, Interrupt and Stop stay three separate buttons. The activity display should be English sentences plus a visual cue beside those buttons. A single microphone button would hide the explicit interrupt control and collapse two different enablement rules.

## Findings

### The Dart enums include interrupting, failed and disposed

- Claim: `TurnActivity` is idle, listening, recognizing, thinking, speaking and interrupting. `AgentLifecycle` is initializing, ready, running, suspended, stopping, failed and disposed. An earlier UI stream listed only the first values in each enum. The synthesis uses the full lists.
- Evidence: `lib/src/models.dart` enum declarations. The event stream states seven lifecycle values and six activity values.
- Source: `wiki/work/0011-example-conversation-activity/research/agent-events.md`, `lib/src/models.dart`

### The status line shows raw enum names

- Claim: Every agent event sets the status string to the lifecycle name, a separator, and the activity name. A fault replaces that with one fixed failure sentence.
- Evidence: `example/lib/voice_screen_controller.dart` assigns the raw string in `_handleAgentEvent`. The failure branch follows it.
- Source: `wiki/work/0011-example-conversation-activity/research/example-ui.md`, `wiki/work/0011-example-conversation-activity/research/agent-events.md`

### Start already has a listening sentence that the UI never shows

- Claim: `start()` carries the success text beginning with "Listening." and passes a flag that skips writing it. Interrupt and stop do write their success sentences after the call returns.
- Evidence: `example/lib/voice_screen_controller.dart` start, interrupt and stop wrappers, and the shared session runner.
- Source: `wiki/work/0011-example-conversation-activity/research/example-ui.md`

### The agent does not emit an event for its own start and interrupt field updates

- Claim: Dart sets activity to listening inside start and to interrupting inside interrupt without adding an event. Events that do arrive carry the agent's current lifecycle and a parsed activity. Native code's exact activity sequence was not read.
- Evidence: assignments in `lib/src/agent.dart`. Native emission is marked unverified in the event stream.
- Source: `wiki/work/0011-example-conversation-activity/research/agent-events.md`

### Tests lock the Start button and three status substrings, not the enum format

- Claim: The widget test requires `start-button` to be a filled button that is disabled before setup, and it requires specific static copy. Controller tests require status to contain "Not enough free space", "background" and "Ready" on named paths. No test emits an agent event. The fake session interface is events, start, interrupt, stop, dispose and setSpeakerId.
- Evidence: `example/test/voice_screen_test.dart` and `example/test/voice_screen_controller_test.dart`.
- Source: `wiki/work/0011-example-conversation-activity/research/example-ui.md`

### Product copy must stay half-duplex and unqualified

- Claim: The example must keep saying that listening pauses while a reply plays, that replies are fixed demo rules, and that preparation uses the network while conversation does not. It must not claim full duplex, barge-in, wake word, background listening, measured quality, or production qualification. The status line is a live region. Speaker ids stay integers.
- Evidence: `example/lib/main.dart`, `README.md`, `doc/capabilities.md`, `doc/model-catalog.md`, `wiki/product/example-model-catalog.md`.
- Source: `wiki/work/0011-example-conversation-activity/research/product-constraints.md`

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| English sentences and a visual cue, three buttons kept | Map each existing activity, and suspended, to a fixed sentence. Show an icon with the same meaning. After a successful in-epoch start, show the listening sentence without waiting for a native event. Ignore later activity events once stop or background has ended capture. | Example controller, example screen, and example tests. | Chosen. Uses data the example already has. |
| One microphone button that reflects activity | Replace Start, Interrupt and Stop with one control whose action depends on activity. | Breaks the filled Start button test and hides explicit interrupt. | Rejected. Interrupt is a documented manual control, and Start's enablement is stricter than Interrupt and Stop. |
| Change the library so start emits an event | Make `LocalVoiceAgent.start` publish listening before the example paints. | Public behavior change and native uncertainty. | Rejected. The example can write the listening sentence when its own start call succeeds. |
| Leave the enum string | No code change. | Users keep seeing `running · listening`. | Rejected. That is the defect. |
| Drive the sentence from event kind | Use partial transcript, final transcript, reply text and fault, which the example already handles. | Does not say whether the user is being heard or the reply is playing. Native activity order is still unverified. | Rejected. Kind already routes transcript and reply text. Activity is the field that distinguishes hearing, thinking and speaking. If a host never sends recognizing, thinking or speaking, those sentences stay unused and the start path still shows the listening sentence. |

## Constraints discovered

- Do not add a member to the example session interface. The test fake implements it exactly.
- Do not change `lib/`.
- Keep `start-button` as a filled button, disabled before setup.
- Keep the substrings "Not enough free space", "background" and "Ready" on the paths that already produce them.
- Keep the static sentences that mention three English options, VCTK as a speaker choice, fixed demo rules, and listening pausing while a reply plays.
- A speaking sentence must say that listening is paused.
- A suspended sentence must tell the user to tap Start again. It must not say the microphone is still listening.
- Status text stays inside the existing live region.
- Copy is English only.

## Unresolved

- [UNRESOLVED: Which activity values each native host and the web backend actually send, and in which order. The UI will map every value the Dart event type already allows, and will not probe native code in this item.]
- [UNRESOLVED: Whether a fault event can arrive with lifecycle stopping or ready. Faults keep the existing failure sentence regardless of those values.]
- [UNRESOLVED: Whether any native host sends a state event immediately after start. The example writes the listening sentence when its own start call succeeds, so that gap does not depend on the event.]
- [UNRESOLVED: Whether interrupt changes native playback when nothing is playing. The example still enables Interrupt whenever a session exists. A successful interrupt call shows the listening sentence. This item does not change native interrupt behavior.]

## Sources

- `wiki/work/0011-example-conversation-activity/research/example-ui.md`, consulted 2026-10-02.
- `wiki/work/0011-example-conversation-activity/research/agent-events.md`, consulted 2026-10-02.
- `wiki/work/0011-example-conversation-activity/research/product-constraints.md`, consulted 2026-10-02.
- `example/lib/main.dart`, `example/lib/voice_screen_controller.dart`, `example/test/voice_screen_test.dart`, `example/test/voice_screen_controller_test.dart`, `lib/src/agent.dart`, `lib/src/models.dart`, `README.md`, `doc/capabilities.md`, `doc/model-catalog.md`, `wiki/product/example-model-catalog.md`, consulted 2026-10-02 via those streams.
