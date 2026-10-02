# Implementation review — round 01

- Work item: 0011-example-conversation-activity
- Reviewed artifact: working-tree diff of `example/lib/voice_screen_controller.dart`, `example/lib/main.dart`, `example/test/voice_screen_controller_test.dart`, `example/test/voice_screen_test.dart` against `HEAD` (`git diff`, 735 insertions, 13 deletions); `git diff -- lib` confirmed empty
- Reviewer: independent implementation validator
- Date: 2026-10-02

## Verdict

**PASS**

Every criterion AC-001 through AC-021 is met with a located assertion and an exercised negative case, all four repository checks exit 0, and no blocker was found; the one IMPORTANT finding concerns a reachable state that no frozen criterion covers.

## Verification performed

All commands run by the reviewer from the repository root (or `example/` where stated).

### `git diff -- lib`

```
$ cd /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent && git diff -- lib
$ git status --porcelain -- lib
```

Both produced no output. `git diff --stat -- lib example/lib example/test` reports only the four reviewed files:

```
 example/lib/main.dart                          |  44 +++
 example/lib/voice_screen_controller.dart       | 100 +++++-
 example/test/voice_screen_controller_test.dart | 429 +++++++++++++++++++++++++
 example/test/voice_screen_test.dart            | 175 ++++++++++
 4 files changed, 735 insertions(+), 13 deletions(-)
```

### `dart format lib example/lib`

```
$ dart format lib example/lib
Formatted 37 files (0 changed) in 0.10 seconds.
format exit: 0
```

### `dart analyze --fatal-infos --fatal-warnings`

```
$ dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
analyze exit: 0
```

### `flutter test` (repository root)

Trailing lines, with the `FLVA ...` debug lines filtered out for length:

```
$ flutter test
00:05 +98: .../test/model_preparation_test.dart: concurrent callers two managers converge and one cancelled caller cannot delete winner
00:05 +99: .../test/model_preparation_test.dart: concurrent callers cross-isolate callers atomically converge on one valid directory
00:05 +99: All tests passed!
root test exit: 0
```

### `flutter test` (inside `example/`)

```
$ cd example && flutter test
00:00 +40: .../example/test/voice_screen_controller_test.dart: conversation activity background clears capture and the displayed activity
00:00 +41: .../example/test/voice_screen_controller_test.dart: conversation activity failed action clears the paused flag
00:00 +42: .../example/test/voice_screen_controller_test.dart: conversation activity activity labels are plain words
00:00 +44: .../example/test/voice_screen_test.dart: static copy and the live-region status stay in place
00:00 +45: .../example/test/voice_screen_test.dart: indicator shows an icon, a word and a matching semantics label
00:00 +46: .../example/test/voice_screen_test.dart: indicator shows Paused when paused and Idle otherwise
00:00 +47: .../example/test/voice_screen_test.dart: indicator labels every activity with plain words
00:01 +48: All tests passed!
example test exit: 0
```

48 tests, all passing; 20 of them are the new or extended activity cases.

### `python3 tool/lint_wiki.py`

```
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
lint exit: 0
```

### Source searches

```
$ rg -in "full.?duplex|barge.?in|wake.?word" example/lib/main.dart example/lib/voice_screen_controller.dart
NO MATCHES (good)
```

```
$ rg -n "abstract interface class ExampleVoiceSession" -A 6 example/lib/voice_screen_controller.dart
22:abstract interface class ExampleVoiceSession {
23:  Stream<AgentEvent> get events;
24:  Future<void> start();
25:  Future<void> interrupt();
26:  Future<void> stop();
27:  Future<void> dispose();
28:  Future<void> setSpeakerId(int speakerId);
```

## Per-criterion results

File shorthand: `ctrl` = `example/lib/voice_screen_controller.dart`, `main` = `example/lib/main.dart`, `ctest` = `example/test/voice_screen_controller_test.dart`, `wtest` = `example/test/voice_screen_test.dart`.

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | `ctrl:491-499` sets `_capturing` then `_showActivity(listening)` only on the in-epoch same-session branch (`ctrl:533-537`); sentence at `ctrl:755-756`. Test `ctest:398-417` reads status, `displayedActivity`, `activityPaused` after completing the start completer. | yes — `ctest:406-408` asserts nothing is written while the call is in flight, and `ctest:412` asserts `isNot(statusBeforeStart)`, so an unchanged status fails. |
| AC-002 | pass | `ctrl:634-641` capture gate then `_showActivity`; sentence at `ctrl:759`. Test `ctest:419-436` asserts the exact string and `TurnActivity.speaking`. | yes — `ctest:438-450` delivers the same speaking event before start succeeds and asserts status and `displayedActivity` are untouched. |
| AC-003 | pass | `ctrl:753-761` maps recognizing/thinking/interrupting/idle to the four exact sentences; `ctrl:640` writes them. Test `ctest:452-473` loops all four, asserting the sentence and the matching `displayedActivity`. | yes — `ctest:470` asserts `isNot(entry.key.name)`, so a bare enum name as the whole message fails. |
| AC-004 | pass | `ctrl:635-638` resets activity (clearing `_capturing` at `ctrl:556`), sets `activityPaused = true` and the sentence at `ctrl:748-749`. Test `ctest:475-498`. | yes — `ctest:494-497` adds a listening event after the suspended event and asserts the paused sentence and `activityPaused` survive. |
| AC-005 | pass | `ctrl:511` clears `_capturing` on stop, so `ctrl:634` ignores the later event. Test `ctest:517-530` asserts the stopped sentence and idle activity after a post-stop listening event. | yes — the post-stop event at `ctest:522` is the case that must not move status; `ctest:527-529` fails if it does. |
| AC-006 | pass | `ctrl:628-633` is unconditional, resets activity and sets phase `failed` plus the fault sentence. Test `ctest:557-579`. | yes — `ctest:574-577` adds a listening event after the fault and asserts the fault sentence is still in place; `ctest:581-592` also proves the fault path ignores the capture gate. |
| AC-007 | pass | `ctrl:634` gates every non-fault write on `_capturing`, which is set only at `ctrl:496`. Test `ctest:594-607` asserts `contains('Ready')`, idle activity and `activityPaused` false. | yes — `ctest:604` asserts `isNot(contains('Listening'))`, so an activity sentence appearing fails; `ctest:609-637` additionally shows transcripts still flow while capture is off. |
| AC-008 | pass | The `'${event.lifecycle.name} · ${event.activity.name}'` assignment is deleted from `_onEvent` (diff removes it at the former `ctrl:~623`); no middle-dot status remains. Test `ctest:639-658`. | yes — `ctest:647` asserts `isNot(contains('·'))` and `ctest:648-655` walks the full `AgentLifecycle` × `TurnActivity` cross product. |
| AC-009 | pass | `main:265-271` inserts the keyed `_ActivityIndicator`; `main:293-316` renders `Icon` + `Text(label)` inside `Semantics(label: label)`. Test `wtest:88-131` finds the key, the descendant `Icon`, the text `Speaking`, and asserts `getSemantics(indicator).label` contains `Speaking`. | yes — `wtest:115-116` assert `find.text('speaking')` and `find.textContaining('TurnActivity')` find nothing, so rendering the enum name fails. |
| AC-010 | pass | `ctrl:157-158` returns `'Paused'` when `activityPaused`, else the mapped label (`ctrl:763-770`). Test `wtest:133-174` pumps the idle state then the paused state. | yes — each half asserts `findsNothing` for the other label (`wtest:145-148`, `wtest:170-173`), so `Idle` while paused or `Paused` before start fails. |
| AC-011 | pass | `main:244-264` keeps `FilledButton` keyed `start-button` with `onPressed` null unless `canStart`, and the two `OutlinedButton`s. Test `wtest:35-50` keeps the typed `FilledButton` read and adds the two key finds plus type assertions. | yes — `wtest:38` asserts `start.onPressed` is null before setup, and `tester.widget<FilledButton>` fails on a type change. |
| AC-012 | pass | `ctrl:533-536` returns from the stale branch before `onSuccess()`, so `_capturing` stays false. Test `ctest:171-200`, extended at `ctest:192-196`. | yes — `ctest:193-196` adds a listening event after the stale start resolves and asserts `contains('background')` and idle activity. |
| AC-013 | pass | `ctrl:565` resets activity on background and the resume path leaves the ready status. Test `ctest:202-228` with the new `ctest:225` assertion on `displayedActivity`. | yes — `ctest:224-225` are themselves the failing assertions if the status loses `Ready` or the activity is not idle. |
| AC-014 | pass | `ctrl:285` produces the message; test `ctest:23-38` with the substring assertion at `ctest:34` is untouched by this diff. | yes — `ctest:34` fails if the substring is removed or weakened. |
| AC-015 | pass | `ctrl:502-506` runs only `_showActivity(listening)` and never touches `_capturing`. Test `ctest:660-683` asserts the same listening sentence, listening activity and `activityPaused` false after interrupt. | yes — `ctest:676-682` adds a speaking event after interrupt and asserts the speaking sentence appears, which fails if interrupt had cleared capture. |
| AC-016 | pass | `ctrl:508-516` clears capture, sets idle, clears paused, writes `_stoppedStatus` (`ctrl:747`). Tests `ctest:685-697` and `ctest:532-555`. | yes — `ctest:532-555` first drives `activityPaused` true via a suspended event and then asserts stop clears it to idle/false, so a stop that leaves an active or paused activity fails. |
| AC-017 | pass | Interface at `ctrl:22-29` still declares exactly `events`, `start`, `interrupt`, `stop`, `dispose`, `setSpeakerId` and is outside the diff. | yes — `git diff -- lib` and `git status --porcelain -- lib` both returned empty output (pasted above), which is the check that fails on any hunk under `lib/`. |
| AC-018 | pass | `main:175-178` keeps `Text(..., key: Key('status'))` inside `Semantics(liveRegion: true)`; copy at `main:93` (`Three English options`, `VCTK is a speaker choice`, `Listening pauses while a reply plays`), `main:101` (`English voice model`), `main:237` (`fixed demo rules`), `main:337` (`Files, sources, and licenses`). Test `wtest:55-86` finds all six sentences and walks the status node's `Semantics` ancestors for `liveRegion == true` (`wtest:78-84`). | yes — each `findsOneWidget`/`isNotEmpty` fails on a reworded sentence or a status text moved outside the live region. |
| AC-019 | pass | Case-insensitive `rg` over both files returns no match for the three phrases (output pasted above). New user-facing copy is confined to the six activity sentences (`ctrl:753-761`), the stopped and suspended sentences (`ctrl:747-749`) and the six indicator labels (`ctrl:763-770`); none claims accuracy, measured quality or production readiness. | yes — the search is the failing check, and `wtest:115-116` plus `ctest:470` reject enum-name leakage into the new copy. |
| AC-020 | pass | `main:293-316` builds the state from `Icon(icon, size: 20)` plus `Text(label)` under `Semantics(label: label, container: true)`; the icon is chosen by the exhaustive map at `main:319-326` with no colour-only channel. Test `wtest:101-113` asserts the descendant `Icon`, the descendant label text and the semantics label. | yes — `wtest:101-112` fail for a coloured dot with no text, and `wtest:113` fails for a node with no semantics label. |
| AC-021 | pass | All four commands run by the reviewer with output pasted under "Verification performed": format `0 changed`, analyze `No issues found!`, root suite `+99 All tests passed!`, example suite `+48 All tests passed!`, lint `clean (0 warning(s))`; every exit code 0. | yes — the pasted non-zero-exit check is the failing condition, and each command was re-run rather than taken on assertion. |

## Findings

### F-001 — Interrupt before any successful Start writes the listening sentence while the capture flag stays false

- Severity: IMPORTANT
- Location: `example/lib/voice_screen_controller.dart:502-506`, reachable through `example/lib/main.dart:251-257`
- Criterion affected: none
- Observation: `interrupt()` passes `onSuccess: () => _showActivity(TurnActivity.listening)`, and `_showActivity` (`ctrl:548-552`) sets `displayedActivity = listening` and the "Listening. Say …" status without consulting `_capturing`. The Interrupt button is enabled whenever `controller.hasSession && !controller.operationBusy` (`main:251-253`), which is true as soon as setup produces a session and before any Start has succeeded. In that state the screen shows the indicator label `Listening` and the listening status sentence while `_capturing` is still false, so the capture gate at `ctrl:634` discards every subsequent non-fault event and the indicator stays on `Listening` until Stop, background or a fault. No test covers interrupt on a ready-but-never-started session: `ctest:660-683` reaches interrupt only through `_startedSession` (`ctest:769-776`).
- Why it matters: it is the one path in the new design where the indicator and the status assert an active listening turn that the controller itself does not believe is happening, and because the gate then freezes the indicator, the wrong label persists rather than self-correcting on the next event. The frozen criteria do not cover interrupt-before-start, and AC-015 is scoped to interrupt after a successful start, so this violates no stated criterion.

### F-002 — The failed-action branch clears `activityPaused` but leaves `displayedActivity` and the capture flag as they were

- Severity: NIT
- Location: `example/lib/voice_screen_controller.dart:538-542`
- Criterion affected: none
- Observation: on a thrown session command the in-epoch branch sets `activityPaused = false` and writes "The local speech action failed. …" but does not touch `displayedActivity` or `_capturing`. A failed Stop taken while `displayedActivity` is `speaking` leaves the indicator reading `Speaking` beside a status sentence saying the action failed. `ctest:714-731` covers only the suspended-then-failed-stop case, where `_resetActivity` had already moved the activity to idle, so the mixed pair is not exercised.
- Why it matters: cosmetic inconsistency between the status line and the indicator in a failure state; the stale activity is arguably still accurate after a failed Stop, and no criterion addresses the failed-action branch.

### F-003 — `_activitySentence(TurnActivity.idle)` is reachable from two unrelated situations

- Severity: NIT
- Location: `example/lib/voice_screen_controller.dart:754`
- Criterion affected: none
- Observation: "Waiting for speech." is produced both by an idle activity event while capturing (required by AC-003) and, as the indicator label, by the never-started default `displayedActivity = TurnActivity.idle` (`ctrl:151`), which renders as `Idle`. The status sentence and the indicator label therefore diverge in wording for the same enum value by design, matching AC-003 and the "Explicitly not required" note about the word "Waiting".
- Why it matters: naming only; `wtest:201` asserts `find.text('Waiting')` finds nothing, confirming the split is intentional and tested.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | not routed — no blocker; violates no frozen criterion |
| F-002 | not routed — NIT |
| F-003 | not routed — NIT |
