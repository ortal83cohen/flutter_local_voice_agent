# Tasks: Example conversation activity

## Start conditions

Criteria AC-001 through AC-021 are frozen before task 1.1 begins. Preserve unrelated dirty files. Do not commit or publish. Do not touch `lib/`, `README.md`, `doc/`, `wiki/INDEX.md` or any work item `STATE.yaml` from these tasks.

## Legend

- `[P]` — may run in a parallel subagent. Only mark a task `[P]` if no other `[P]` task in the same group touches any of the same files.
- Every task cites the criteria it satisfies. A task satisfying no criterion does not belong here.
- Owned files are exclusive. Two tasks never list the same file.
- There is one implementation group. The controller change and the screen change read the same fields and share the same copy, and their tests sit beside the behaviour they cover, so one implementer runs the group in order. No task in this work item is parallel.

## Groups

### Group 1 — Example activity copy, capture gate and indicator

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | Add the public `displayedActivity` field of type `TurnActivity` defaulting to idle, the public `activityPaused` boolean defaulting to false, and the private capture flag to `VoiceScreenController`. Add the exhaustive activity-to-sentence mapping and the suspended sentence. Reshape the shared session runner so each of Start, Interrupt and Stop owns its success behaviour, keeping the stale-completion branch first and keeping its early return before any status assignment. Implement the Start, Interrupt and Stop success and failure behaviour, the capture flag's single set site and all its clear sites including background, session teardown, close and the subscription error path. Replace the raw lifecycle-and-activity status assignment in the event handler with the capture-gated rules: suspended writes the paused sentence and clears capture, any other non-fault event writes the sentence for its activity, and a non-fault event while capture is false changes nothing. Keep the fault branch unconditional with its existing sentence. Keep transcript and reply updates as they are. Write the controller tests for every criterion listed against this task, including both required negative cases. | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-019 | example/lib/voice_screen_controller.dart, example/test/voice_screen_controller_test.dart | | No assignment in the controller concatenates an enum name into the status; every activity value has a sentence with no default branch; the existing assertions on the "Not enough free space", "background" and "Ready" substrings still pass; the event-before-start test and the lifecycle-dot-activity test both pass; the `ExampleVoiceSession` member list is unchanged and `lib/` has no diff. |
| 1.2 | Add the activity indicator to the conversation controls in `example/lib/main.dart` as a fourth child of the existing wrap that holds Start, Interrupt and Stop, keyed `activity-indicator`, rendering an icon plus the short label for the controller's `activityPaused` and `displayedActivity` fields, inside a semantics node carrying the same words. Change nothing about the three buttons, their keys, their widget types or their enablement expressions. Leave the status text in its live region and leave every static sentence in place. Extend the widget test with the indicator assertions, the live-region assertion and the finds for the preserved static copy. | AC-009, AC-010, AC-011, AC-018, AC-020 | example/lib/main.dart, example/test/voice_screen_test.dart | | The indicator renders beside three unchanged buttons; the label is "Paused" when `activityPaused` is true and otherwise the short label for `displayedActivity`; the existing disabled filled Start button assertion still passes; every named static sentence is still findable. |
| 1.3 | Run the repository checks and record the output for the verify phase: formatting over `lib` and `example/lib`, analysis with fatal infos and fatal warnings, the example test suite, and the wiki linter. Search both changed example source files for the forbidden phrases. This task writes no file; it returns the pasted output to the parent. | AC-019, AC-021 | none | | All four commands have been run with their output captured, each exits 0 or reports no change, and the forbidden-phrase search returns nothing. |

## Serialised files

| File | Owning task |
|---|---|
| example/lib/voice_screen_controller.dart | 1.1 |
| example/test/voice_screen_controller_test.dart | 1.1 |
| example/lib/main.dart | 1.2 |
| example/test/voice_screen_test.dart | 1.2 |

## Test tasks

| # | Covers | Positive case | Negative case |
|---|---|---|---|
| T1 | AC-001 | A successful in-epoch start sets the listening sentence, displayedActivity listening and activityPaused false | Status is asserted unchanged after a successful in-epoch start |
| T2 | AC-002 | A speaking event while capture is true sets the speaking sentence and displayedActivity speaking | The same speaking event before start succeeds leaves status and displayedActivity untouched |
| T3 | AC-003 | Recognizing, thinking, interrupting and idle events each set their exact sentence and displayedActivity | A status equal to the bare activity enum name fails the exact-string assertion |
| T4 | AC-004 | A suspended lifecycle sets the paused sentence, displayedActivity idle and activityPaused true | A listening event after the suspended event replaces the paused sentence |
| T5 | AC-005 | A listening event after stop leaves the stopped sentence and displayedActivity idle | An event after stop moves status or displayedActivity |
| T6 | AC-006 | A fault event sets the exact fault sentence, phase failed, displayedActivity idle and activityPaused false | A listening event after the fault replaces the fault sentence |
| T7 | AC-007 | An event delivered after setup and before start succeeds leaves the setup status containing "Ready" | The status becomes an activity sentence before any start succeeded |
| T8 | AC-008 | A listening event yields a status containing the listening sentence | The status contains a lifecycle name, a middle dot and an activity name |
| T9 | AC-009, AC-020 | The widget keyed activity-indicator shows an Icon and the text "Speaking" with a matching semantics label | No widget keyed activity-indicator is found, or the enum name is rendered, or only a coloured dot with no text is rendered |
| T10 | AC-010 | The indicator shows "Paused" when activityPaused is true and "Idle" when displayedActivity is idle and activityPaused is false | The indicator shows "Idle" while activityPaused is true |
| T11 | AC-011 | start-button is a FilledButton with a null onPressed before setup, and interrupt-button and stop-button are present | start-button is no longer a FilledButton, or is enabled before setup |
| T12 | AC-012 | A late start result after a background event leaves status containing "background" and sets no capture flag | An activity sentence appears after the stale start completes |
| T13 | AC-013 | Resume with a ready session leaves status containing "Ready" and displayedActivity idle | The resume status no longer contains "Ready" |
| T14 | AC-014 | The insufficient-space path still produces a status containing "Not enough free space" | That substring is removed or weakened |
| T15 | AC-015 | A successful in-epoch interrupt sets the listening sentence and displayedActivity listening | A speaking event after interrupt fails to change status, showing capture was cleared |
| T16 | AC-016 | A successful in-epoch stop sets the stopped sentence, displayedActivity idle and activityPaused false | The stopped status reports an active activity |
| T17 | AC-017 | The ExampleVoiceSession member list is unchanged and lib/ has no diff | A new interface member appears, or a diff hunk lands under lib/ |
| T18 | AC-018 | The status text sits in a live region and every named static sentence is findable | A static sentence is removed or reworded, or the status leaves the live region |
| T19 | AC-019 | A search of the two example source files finds none of the forbidden phrases | A forbidden phrase or a new quality claim is present |
| T20 | AC-021 | Format, analyze, the example test suite and the wiki linter all pass with pasted output | A pass is claimed without pasted output |
