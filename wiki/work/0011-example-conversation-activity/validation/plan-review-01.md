# Plan review — round 01

- Work item: 0011-example-conversation-activity
- Reviewed artifact: wiki/work/0011-example-conversation-activity/01-plan.md
- Reviewer: independent plan validator
- Date: 2026-10-02

## Verdict

**PASS**

All twenty-one criteria are covered by a plan sentence, the plan is prose-only, the rollback is stated and reversible, and the five named risks cover the two defect classes a reviewer would otherwise have to raise; the three findings below are wording and bookkeeping, not gaps.

## Verification performed

Commands were run by this validator from the repository root, not taken from the author.

```
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
exit=0
```

Fenced code blocks in the plan, which `01-plan.md` must not contain:

````
$ grep -c -E "^(```|~~~)" wiki/work/0011-example-conversation-activity/01-plan.md
0
exit=1

$ grep -n -E "(```|~~~)" wiki/work/0011-example-conversation-activity/01-plan.md
exit=1 (1 = no match)
````

Zero fences, anchored or inline. The plan is prose only.

Criterion identifiers present in `02-criteria.md`, to fix the set that must be covered:

```
$ grep -o -E 'AC-0[0-9][0-9]' wiki/work/0011-example-conversation-activity/02-criteria.md | sort -u
AC-001 AC-002 AC-003 AC-004 AC-005 AC-006 AC-007 AC-008 AC-009 AC-010 AC-011 AC-012 AC-013 AC-014 AC-015 AC-016 AC-017 AC-018 AC-019 AC-020 AC-021
```

Grounding checks against the files the plan names, to test whether the plan's factual claims hold.

The plan at `01-plan.md:29` and `01-plan.md:77` requires an exhaustive activity-to-sentence mapping with no default branch, and `01-plan.md:57` fixes one sentence per value. The enum has exactly six values and the plan's mapping names all six:

```
$ sed -n "37,54p" lib/src/models.dart
enum TurnActivity {
  /// No active turn.
  idle,

  /// Awaiting speech.
  listening,

  /// Decoding speech.
  recognizing,

  /// Computing a reply.
  thinking,

  /// Rendering a reply.
  speaking,

  /// Cancelling work.
  interrupting,
```

`AgentLifecycle` in the same file declares `suspended` at `lib/src/models.dart:24`, so the single lifecycle special case at `01-plan.md:55` names a value that exists.

`01-plan.md:9` claims `TurnActivity` is already visible to the example through the import the controller holds today, so no new import is needed. Confirmed:

```
$ grep -n "models.dart" lib/flutter_local_voice_agent.dart
8:export 'src/models.dart';
```

and `example/lib/voice_screen_controller.dart:4` imports `package:flutter_local_voice_agent/flutter_local_voice_agent.dart`.

AC-017 fixes the interface member list that `01-plan.md:49` promises not to change. The declaration matches the six members the criterion names:

```
$ sed -n "22,29p" example/lib/voice_screen_controller.dart
abstract interface class ExampleVoiceSession {
  Stream<AgentEvent> get events;
  Future<void> start();
  Future<void> interrupt();
  Future<void> stop();
  Future<void> dispose();
  Future<void> setSpeakerId(int speakerId);
}
```

The string the work item exists to remove is present once, which is the assignment `01-plan.md:15` and `01-plan.md:37` require to be deleted:

```
$ grep -n "event.lifecycle.name" example/lib/voice_screen_controller.dart
584:    status = '${event.lifecycle.name} · ${event.activity.name}';
```

Read without a command: `example/lib/voice_screen_controller.dart:493` to `:521` for the shared session runner the plan reshapes, `:523` to `:571` for the background, resume and close paths, `:635` to `:641` for the teardown helper, `:331` to `:339` for the subscription error path, and `example/lib/main.dart:176`, `:240` to `:260` for the status live region and the wrap holding the three keyed buttons. Each structural claim the plan makes about those sites holds, including the stale-completion branch returning before any status assignment at `:506` to `:510` and the start wrapper suppressing its own success write at `:480`.

No Dart command was run. This is a plan review; `dart format`, `dart analyze` and the example suite are obligations of AC-021 on the later verify phase, not evidence a plan review can produce.

## Per-criterion results

Plan coverage, not implementation results. Evidence is the plan sentence that binds the criterion.

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | 01-plan.md:13, 52, 57 | yes — 03-tasks.md:37 T1 |
| AC-002 | pass | 01-plan.md:15, 55, 57 | yes — 01-plan.md:95, 03-tasks.md:38 T2 |
| AC-003 | pass | 01-plan.md:15, 55, 57 | yes — 03-tasks.md:39 T3 |
| AC-004 | pass | 01-plan.md:15, 52, 55, 57 | yes — 03-tasks.md:40 T4 |
| AC-005 | pass | 01-plan.md:13, 15, 59 | yes — 03-tasks.md:41 T5 |
| AC-006 | pass | 01-plan.md:15, 61 | yes — 03-tasks.md:42 T6 |
| AC-007 | pass | 01-plan.md:15, 55, 67 | yes — 01-plan.md:95, 03-tasks.md:43 T7 |
| AC-008 | pass | 01-plan.md:15, 37, 77 | yes — 01-plan.md:95, 03-tasks.md:44 T8 |
| AC-009 | pass | 01-plan.md:17, 65 | yes — 03-tasks.md:45 T9 |
| AC-010 | pass | 01-plan.md:65 | yes — 03-tasks.md:46 T10 |
| AC-011 | pass | 01-plan.md:17, 49, 78 | yes — 03-tasks.md:47 T11 |
| AC-012 | pass | 01-plan.md:13, 52, 76 | yes — 03-tasks.md:48 T12 |
| AC-013 | pass | 01-plan.md:35, 59, 67 | yes — 03-tasks.md:49 T13 |
| AC-014 | pass | 01-plan.md:67, 97 | yes — 03-tasks.md:50 T14 |
| AC-015 | pass | 01-plan.md:13, 15, 59 | yes — 03-tasks.md:51 T15 |
| AC-016 | pass | 01-plan.md:13, 59 | yes — 03-tasks.md:52 T16 |
| AC-017 | pass | 01-plan.md:49, 87 | yes — 03-tasks.md:53 T17; see F-002 |
| AC-018 | pass | 01-plan.md:17, 39, 67 | yes — 03-tasks.md:54 T18 |
| AC-019 | pass | 01-plan.md:67, 97 | yes — 03-tasks.md:55 T19 |
| AC-020 | pass | 01-plan.md:65 | yes — 03-tasks.md:56 T20 |
| AC-021 | pass | 01-plan.md:43, 97 | yes — 03-tasks.md:57 T20; see F-001 |

No criterion is unmet. Three criteria were checked with extra care because the plan covers them by constraint rather than by a behavioural sentence: AC-013's idle displayed activity on resume rests on the background reset at `01-plan.md:35` rather than on a resume-path write, AC-007's preserved setup text rests on the substring promise at `01-plan.md:67`, and AC-017 rests on the prohibitions at `01-plan.md:49` and `01-plan.md:87`. Each holds, because the resume path at `example/lib/voice_screen_controller.dart:550` to `:554` writes status without touching any activity field, and the background path that precedes it is the one the plan resets.

The criteria file is not frozen: `02-criteria.md:6` and `02-criteria.md:7` both read "not yet". That is the expected state before implementation begins and is recorded here as the baseline this round reviewed, not as a finding.

## Findings

### F-001 — step 9's completion condition omits the wiki linter that AC-021 requires

- Severity: NIT
- Location: `wiki/work/0011-example-conversation-activity/01-plan.md:43`
- Criterion affected: AC-021
- Observation: AC-021 names four commands: format, analyze, the example suite and `tool/lint_wiki.py`. Step 9 says to run the repository checks and paste their output, but its completion condition lists only formatting, analysis and the example test suite. The verification approach at `01-plan.md:97` does name all four including the wiki linter, and `03-tasks.md:24` task 1.3 names all four, so the obligation exists elsewhere in the plan.
- Why it matters: an implementer who reads the step list as the contract and the completion condition as the gate can declare step 9 complete with three of the four commands run, and the fourth is the command that guards the wiki artifacts this work item is still producing.

### F-002 — the verification approach does not name the lib/ diff or the interface read that AC-017 specifies

- Severity: NIT
- Location: `wiki/work/0011-example-conversation-activity/01-plan.md:97`
- Criterion affected: AC-017
- Observation: AC-017 states its check method as reading the interface declaration and running a diff of `lib/` against the base commit. The verification approach enumerates controller tests, widget tests, preserved substrings, a forbidden-term search and the four repository checks; none of those is a diff of `lib/` or a read of the interface declaration. The substantive constraint is stated twice, at `01-plan.md:49` and in Out of scope at `01-plan.md:87`, and `03-tasks.md:20` carries it as a done-when for task 1.1, so the criterion is covered — the planned verification prose is what omits the action.
- Why it matters: the constraint it proves is the one that distinguishes this work item from the rejected alternative at `01-plan.md:21`, which was to change `lib/`. A prohibition with no planned check is the kind of obligation that is satisfied by assertion at verify time.

### F-003 — the fixed copy is given as unquoted running prose, so exact string boundaries must be inferred

- Severity: NIT
- Location: `wiki/work/0011-example-conversation-activity/01-plan.md:57`
- Criterion affected: none
- Observation: AC-002, AC-003, AC-004 and AC-016 assert exact status strings. The plan supplies those strings in a single unquoted sentence run: "For speaking, Speaking the reply. Listening is paused. For interrupting, Interrupting." Sentence terminators inside a value and the terminators separating one value from the next are the same character, so the reader infers where "Speaking the reply. Listening is paused." ends and the next mapping begins. The same shape appears at `01-plan.md:59` for the stop, background and resume sentences, at `01-plan.md:61` for the fault sentence and at `01-plan.md:65` for the short labels. Every boundary this validator inferred matches the criteria, so no mismatch exists today.
- Why it matters: the strings are asserted character-for-character by tests the same plan requires. A plan carries no fences by rule, but inline quoting is available, and a copy table parsed by inference is one misread terminator away from a failing exact-string assertion whose cause sits in the plan rather than the code.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

No blockers. The three findings are plan-level wording and bookkeeping; none routes to the implement phase.

| Finding | Belongs to phase |
|---|---|
| F-001 | plan |
| F-002 | plan |
| F-003 | plan |
