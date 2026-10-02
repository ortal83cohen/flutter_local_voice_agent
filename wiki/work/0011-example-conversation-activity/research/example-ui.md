# Example UI and tests

## Question

How does the example currently present conversation status and controls, and which widget or controller tests lock that presentation?

## Answer

The example shows one shared status line (`Key('status')`) that carries both setup messages and, once a session emits events, a machine-style string of the form `<lifecycle> · <activity>`. Conversation controls are three separate buttons (`start-button`, `interrupt-button`, `stop-button`) whose enabled state depends on the controller, never on `TurnActivity`. Tests lock only the Start button being disabled before setup, a few setup and background status substrings, and the controller getters `canStart` and `hasSession`. No test emits an `AgentEvent`, and no test asserts the `<lifecycle> · <activity>` format or the Interrupt and Stop buttons.

## Findings

### Single status line, shared by setup and conversation

- Claim: The UI renders exactly one status widget, `Text(controller.status, key: const Key('status'))`, wrapped in a live-region `Semantics`. It is the only place that shows the status string.
- Evidence: `Semantics(liveRegion: true, child: Text(controller.status, key: const Key('status')))` at `example/lib/main.dart:176-177`.
- Source: `example/lib/main.dart`

### Status is a plain mutable `String` on the controller

- Claim: `status` is a public `String` field, initialised to `'Checking saved model setup…'`, and is assigned directly in many setup, error, background and resume branches.
- Evidence: field declaration at `example/lib/voice_screen_controller.dart:144`. Assignments include `'Starting the on-device speech engine…'` (`:319`), `'Ready. Tap Start and allow microphone access.'` (`:349`), `'Cancelling model preparation…'` (`:442`), `'Stopped while the app is in the background.'` (`:540`) and `'Ready. Tap Start when you want to continue.'` (`:552`).
- Source: `example/lib/voice_screen_controller.dart`

### Agent events overwrite status with a raw enum-name string

- Claim: Every agent event sets `status` to `'${event.lifecycle.name} · ${event.activity.name}'`. This is the only place the example reads `TurnActivity`, and it shows the raw enum name (for example `running · listening`). Transcript and reply text go to separate `heard` and `reply` fields. A fault event replaces status with a fixed failure sentence.
- Evidence: `_handleAgentEvent` at `example/lib/voice_screen_controller.dart:579-595`. The status format is at `:584`. `heard` is set for partial and final transcripts at `:585-588`. `reply` is set at `:589`. The failure branch sets phase `failed` and the status `'The on-device speech engine reported a problem. Stop and retry.'` at `:590-593`. A debug print at `:581-583` logs `kind`, `activity` and text length.
- Evidence (enum values available): `TurnActivity` has `idle`, `listening`, `recognizing`, `thinking`, `speaking` at `lib/src/models.dart:37-51`. `AgentLifecycle` has `initializing`, `ready`, `running`, `suspended`, `stopping` at `lib/src/models.dart:13-27`. `AgentEventKind` is declared at `lib/src/models.dart:58`. It includes `state`, `partialTranscript`, `finalTranscript`, `replyText` and `fault`.
- Source: `example/lib/voice_screen_controller.dart`, `lib/src/models.dart` (read only to list the enum values the controller consumes)

### Start, Interrupt and Stop: three buttons gated by session presence

- Claim: Controls are three independent buttons in a `Wrap`, titled `Start`, `Interrupt` and `Stop`. None of them reads `TurnActivity`. Start is enabled when `canStart && !operationBusy`. Interrupt and Stop are each enabled when `hasSession && !operationBusy`. So Interrupt and Stop are enabled as soon as a session exists, before Start has been pressed.
- Evidence: `start-button` at `example/lib/main.dart:245-249`, with the enabling condition at `:246`. `interrupt-button` at `:252-256`, with the condition at `:253`. `stop-button` at `:259-263`, with the condition at `:260`. `hasSession` is `_session != null` at `example/lib/voice_screen_controller.dart:180`. `canStart` requires phase `ready`, a non-null session, a selected option and a speaker id in range, starting at `:160`.
- Source: `example/lib/main.dart`, `example/lib/voice_screen_controller.dart`

### Control actions write their own status text, and the order interacts with event-driven status

- Claim: `start()`, `interrupt()` and `stop()` all go through `_runSession`. `start()` passes `overwriteStatus: false`, so it does not write its success text. `interrupt()` and `stop()` write fixed success sentences after the native call completes, which could replace an activity string that arrived during the call. The race is inferred from the code, not observed. A failed action writes a single fixed error sentence.
- Evidence: `start` at `example/lib/voice_screen_controller.dart:476-481`. Its success text `'Listening. Say “hello”, “what is your name?”, or “thank you”.'` is at `:478` and is never shown because of `overwriteStatus: false` at `:480`. `interrupt` at `:483-486` with `'Interrupted. The microphone will listen for the next turn.'`. `stop` at `:488-491` with `'Stopped. Tap Start when you want to continue.'`. `_runSession` at `:493-521`. The status write on success is at `:511-512`. The failure text `'The local speech action failed. Check microphone access and try again.'` is at `:516`. `stopAfterStaleCompletion: true` for Start is at `:479`, and the stale-completion stop is at `:505-510`.
- Source: `example/lib/voice_screen_controller.dart`

### Background and resume paths also write status and stop the session

- Claim: `onBackground()` bumps the epoch, cancels preparation, calls `session.stop()` and sets `'Stopped while the app is in the background.'`. `onResume()` with a ready session sets `'Ready. Tap Start when you want to continue.'`. The widget maps `paused`, `hidden` and `detached` to `onBackground()`, `resumed` to `onResume()`, and ignores `inactive`.
- Evidence: `onBackground` at `example/lib/voice_screen_controller.dart:523-543`, with the session stop at `:537-540`. `onResume` at `:545-562`, with the status set at `:552`. Lifecycle mapping at `example/lib/main.dart:54-65`, including the comment that `inactive` must not invalidate Start.
- Source: `example/lib/voice_screen_controller.dart`, `example/lib/main.dart`

### Static copy around the conversation controls

- Claim: Static English copy that references behavior sits next to the controls. It includes `'Listening pauses while a reply plays.'`, a `Conversation` heading, `'Replies are fixed demo rules, not an LLM. Try “hello”, “what is your name?”, or “thank you”.'`, and `You said` and `Local reply` transcript cards with placeholder text.
- Evidence: `example/lib/main.dart:93` (intro paragraph containing `Three English options`, `VCTK is a speaker choice` and `Listening pauses while a reply plays.`). `:234` (`Conversation` heading). `:237` (fixed-demo-rules sentence). `:269` (`You said`) and `:275` (`Local reply`), with placeholders in the `_TranscriptCard` calls at `:268-278`. `Installed and verified` chip at `:166`.
- Source: `example/lib/main.dart`

### The only widget test locks setup-time presentation

- Claim: There is one widget test, `catalog UI has no path input and Start waits for native setup`. It pumps `VoiceScreen` with a controller whose storage returns no selection, and whose preparation and session factories throw if called. It asserts static text, the absence of a text field and speaker dropdown, and that the `start-button` `FilledButton` has `onPressed == null`. It never finds `Key('status')`, `interrupt-button` or `stop-button`.
- Evidence: `example/test/voice_screen_test.dart:9-41`. The dropdown type and label asserts are at `:22-26`. `find.text('Speaker')` is `findsNothing` at `:27`. `Three English options` is at `:28`. `VCTK is a speaker choice` is at `:29`. `find.byType(TextField)` is `findsNothing` at `:30`. The scroll is at `:31`. `fixed demo rules` is at `:33`. `Files, sources, and licenses` is at `:34`. The Start button check is at `:35-38`. The fake storage is at `:44-47`.
- Source: `example/test/voice_screen_test.dart`

### Controller tests lock `canStart`, `hasSession` and a few status substrings

- Claim: Controller tests assert `canStart` and `hasSession` in many setup scenarios. They assert only three status substrings: `Not enough free space`, `background`, and `Ready`. They do not assert `interrupt()` or `stop()` outcomes, and they do not assert any event-driven status.
- Evidence: status asserts at `example/test/voice_screen_controller_test.dart:34` (`contains('Not enough free space')`, which comes from the controller at `example/lib/voice_screen_controller.dart:270-271`), `:189` (`contains('background')`) and `:218` (`contains('Ready')`). `canStart` asserts at `:17`, `:35`, `:55`, `:78`, `:101`, `:124`, `:146`, `:217`, `:312`, `:348` and `:376`. `hasSession` is asserted `isTrue` at `:346`.
- Source: `example/test/voice_screen_controller_test.dart`

### Start, background and resume behavior is locked by two controller tests

- Claim: Two tests lock the interaction of a pending Start with background and resume. `background prevents a late start result from replacing stopped status` expects `session.stopCalls == 1` after `onBackground()`, then after the late start completion expects the status to contain `background` and `operationBusy` to be false. `pending Start remains reusable across background and resume` expects `stopCalls == 1`, then `2` after resume and start completion (the stale-completion stop), then phase `ready`, `canStart == true` and status containing `Ready`.
- Evidence: `example/test/voice_screen_controller_test.dart:171-194` and `:196-221`. Stop-count asserts are at `:185`, `:209` and `:215`.
- Source: `example/test/voice_screen_controller_test.dart`

### VCTK out-of-range speaker locks Start off while the session exists

- Claim: A restored VCTK speaker id of 109 leaves phase `ready` with `hasSession == true` but `canStart == false`. Combined with the widget gating, Interrupt and Stop would be enabled while Start is disabled in that state. The widget-level result is inferred, because no widget test covers it.
- Evidence: `example/test/voice_screen_controller_test.dart:336-351` (asserts at `:345-348`). Widget conditions at `example/lib/main.dart:246`, `:253` and `:260`.
- Source: `example/test/voice_screen_controller_test.dart`, `example/lib/main.dart`

### The fake session never emits events

- Claim: `_FakeSession` owns a `StreamController<AgentEvent>` and exposes its stream, but nothing in the test file adds to it. `interrupt()` is a no-op and `stop()` only increments `stopCalls`. So the event-handling branch (`_handleAgentEvent`) has no test coverage.
- Evidence: `example/test/voice_screen_controller_test.dart:549-580`, with the controller at `:550`, the stream getter at `:557`, `interrupt` at `:563` and `stop` at `:566-568`. A search of `example/test/voice_screen_controller_test.dart` for `activity|lifecycle|AgentEvent|_events` returned only `:550`, `:557` and `:573` (close). A search of `example/test/voice_screen_controller_test.dart` for `.add(` returned only `preparations.add` (`:405`), `sessions.add` (`:410`), `createdSpeakerIds.add` (`:411`), `deletedIds.add` (`:473`) and `setSpeakerIds.add` (`:578`).
- Source: `example/test/voice_screen_controller_test.dart`

### No other example test touches this presentation

- Claim: `example/test/model_storage_test.dart` has no references to status, activity, button keys or `AgentEvent`. The only Dart files that reference `start-button`, `interrupt-button`, `stop-button`, `Key('status')`, `VoiceScreen` or `_handleAgentEvent` are `example/lib/main.dart`, `example/lib/voice_screen_controller.dart`, `example/test/voice_screen_test.dart` and `example/test/voice_screen_controller_test.dart`.
- Evidence: a search of `example/test/model_storage_test.dart` for `status|activity|Key\(|AgentEvent` returned no matches. A repository-wide `*.dart` search for `start-button|interrupt-button|stop-button|Key\('status'\)|VoiceScreen|_handleAgentEvent` returned only those four files. `example/test/` contains exactly three files.
- Source: `example/test/model_storage_test.dart`, plus a search of the repository

## Constraints discovered

- Test-locked UI: `Key('start-button')` must exist and be a `FilledButton` whose `onPressed` is null when setup is not ready (`example/test/voice_screen_test.dart:35-38`). The widget test casts it with `tester.widget<FilledButton>`, so changing its widget type breaks the test.
- Test-locked static text (exact `find.text`): `English voice model` (`example/test/voice_screen_test.dart:26`) and `Files, sources, and licenses` (`:34`). `Speaker` must be absent for the default LJS catalog entry (`:27`).
- Test-locked static text (substring `find.textContaining`): `Three English options` (`:28`), `VCTK is a speaker choice` (`:29`) and `fixed demo rules` (`:33`). The first two come from the intro paragraph at `example/lib/main.dart:93`, and the third from `:237`.
- Test-locked controller status substrings: `Not enough free space` (`example/test/voice_screen_controller_test.dart:34`), `background` (`:189`) and `Ready` (`:218`). The last is produced by the resume path, `'Ready. Tap Start when you want to continue.'` at `example/lib/voice_screen_controller.dart:552`.
- Test-locked controller API: `canStart`, `hasSession`, `phase`, `operationBusy`, `status`, `speakerIds`, `showsSpeakerControl`, `selected`, `speakerId` and `canPrepare`. The controller tests read these at `example/test/voice_screen_controller_test.dart:15-17`, `:117-118`, `:308-310` and `:345-348`.
- Test-locked session interface: `ExampleVoiceSession` is implemented by `_FakeSession` with `events`, `start`, `interrupt`, `stop`, `dispose` and `setSpeakerId` (`example/test/voice_screen_controller_test.dart:549-580`). Adding a member to `ExampleVoiceSession` (`example/lib/voice_screen_controller.dart:22-30`) breaks the fake unless the fake is updated.
- Test-locked behavior: `start()` must not let a stale completion leave the session running after `onBackground()`. Stop counts of `1` and then `2` are asserted (`example/test/voice_screen_controller_test.dart:185`, `:209`, `:215`). This depends on `stopAfterStaleCompletion: true` (`example/lib/voice_screen_controller.dart:479`).
- Not locked by any test (free to change, subject to the parent's design choices): the `<lifecycle> · <activity>` string, the Interrupt and Stop button keys and enabling, the `Key('status')` widget, the `Listening.`, `Interrupted.` and `Stopped.` success strings, the `You said` and `Local reply` cards and the fault status sentence. Their sources are listed in the findings above.
- Interrupt and Stop are enabled whenever a session exists, with no dependence on whether Start has run or on `TurnActivity` (`example/lib/main.dart:253`, `:260`). A single mic control that reflects `TurnActivity` would change this behavior. No existing test asserts that behavior, so no test makes a single control incompatible. [UNVERIFIED: any external integration or device test outside `example/test/` that taps these keys. A repository-wide `*.dart` search found none.]
## Unresolved

- [UNRESOLVED: Whether `AgentEvent` for the `ready` lifecycle with `idle` activity is emitted after `start()` or `interrupt()`, which determines what a TurnActivity-driven control would show between turns. This needs the native or library event stream, which is outside this stream's boundary.]
- [UNRESOLVED: Whether the `interrupt()` and `stop()` success strings (`example/lib/voice_screen_controller.dart:485`, `:490`) racing against later events is a real issue. The inference comes from `_runSession` at `:511-512` and `_handleAgentEvent` at `:584`, and neither was exercised by a test or a run.]
