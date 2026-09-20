# Plan review — round 01

- Work item: 0009-english-vits-voice-selection
- Reviewed artifact: wiki/work/0009-english-vits-voice-selection/01-plan.md
- Reviewer: independent plan validator
- Date: 2026-09-20

## Verdict

**FAIL**

AC-006 is not met at plan coverage: the plan requires a setter range check and unsupported-profile, but it never states that a failed set leaves the previous id in use or keeps the session.

## Verification performed

This is a plan review. No implementation suite was run.

Commands run by this reviewer:

```
python3 tool/lint_wiki.py
```

```
lint_wiki: clean (0 warning(s)).
```

```
python3 - <<'PY'
from pathlib import Path
plan = Path('wiki/work/0009-english-vits-voice-selection/01-plan.md').read_text()
print('plan_fenced_triple_backtick:', plan.count('```'))
print('plan_fenced_tilde:', plan.count('~~~'))
print('plan_lines:', len(plan.splitlines()))
PY
```

```
plan_fenced_triple_backtick: 0
plan_fenced_tilde: 0
plan_lines: 102
```

Inspected:

- wiki/conventions/validation-rubrics.md
- wiki/templates/validation-report.md
- wiki/work/0009-english-vits-voice-selection/01-plan.md
- wiki/work/0009-english-vits-voice-selection/02-criteria.md
- wiki/work/0009-english-vits-voice-selection/03-tasks.md, only to test whether every criterion has an owning task
- wiki/work/0009-english-vits-voice-selection/00-research.md, only where the plan relies on a named research claim
- Files the plan names: lib/src/model_catalog.dart; lib/src/agent.dart; lib/src/contracts.dart; lib/src/models.dart; native/include/flva.h; native/src/flva.cpp; example/lib/model_storage.dart; example/lib/voice_screen_controller.dart; example/lib/main.dart; README.md; doc/model-catalog.md; doc/models.md; doc/capabilities.md; doc/model-preparation.md; doc/testing.md; wiki/product/example-model-catalog.md; wiki/adr/0003-example-model-catalog.md; wiki/INDEX.md

Grounding checks:

- 01-plan.md contains zero fenced code blocks (` ``` ` count 0, `~~~` count 0). `python3 tool/lint_wiki.py` reported clean with 0 warnings.
- 02-criteria.md lists AC-001 through AC-012. Frozen at / Frozen by remain “not yet”.
- 03-tasks.md assigns every criterion to at least one task: AC-001 to 1.2; AC-002 to 1.1, 1.2 and 5.1; AC-003 to 2.1–2.3; AC-004 to 2.1–2.3; AC-005 to 2.1–2.3 and 3.2; AC-006 to 2.1 and 2.2; AC-007 to 3.1 and 3.2; AC-008 to 3.1 and 3.2; AC-009 to 3.2; AC-010 to 4.1; AC-011 to 4.2; AC-012 to 4.1, 4.2 and 5.1.
- Documentation updates are planned: steps 8 and 9, plus tasks 4.1 and 4.2, name README.md, the catalog, models, capabilities, preparation and testing guides, the example catalog product record, a new architecture decision, the earlier catalog decision, and the wiki index.
- Rollback is present at 01-plan.md:78 and names catalog, speaker fields, native generate, selection JSON, documentation wording, LJS installs, extra-field readability after rollback, and wiki supersession rather than deletion.
- Named research claims used by the plan (two official English lexicon VITS voices; VCTK 109 speakers 0–108; Lessac as Piper data-directory) are the claims at 00-research.md:39 and 00-research.md:43. Inventory bytes and hashes remain unresolved there and are treated as an implementation measurement step in the plan, not as assumed numbers.
- lib/src/contracts.dart:18–24 creates an inactive native session; start, not create, takes microphone ownership. flva_create at native/src/flva.cpp:418 returns a session or null and does not call flva_start.
- Current example selection JSON stores catalogId only (example/lib/model_storage.dart:119). VoiceModelOption has no speaker-count field today (lib/src/model_catalog.dart:6–13). FlvaConfig has no speaker field (native/include/flva.h:11–16). AgentErrorCode.unsupportedProfile already exists (lib/src/models.dart:84).

Plan-coverage map (not implementation results):

| Criterion | Covered by plan? | Evidence |
|---|---|---|
| AC-001 | covered | 01-plan.md:5, 11, 27 |
| AC-002 | covered | 01-plan.md:11, 25, 102 |
| AC-003 | covered | 01-plan.md:13, 29, 51, 99, 101 |
| AC-004 | covered | 01-plan.md:13, 29, 31, 51, 59 |
| AC-005 | covered | 01-plan.md:5, 13, 15, 35, 53 |
| AC-006 | uncovered | 01-plan.md:31, 33, 59, 101 specify range check and unsupported-profile only |
| AC-007 | covered | 01-plan.md:15, 35, 37 |
| AC-008 | covered | 01-plan.md:15, 35, 37 |
| AC-009 | covered | 01-plan.md:15, 35, 55 |
| AC-010 | covered | 01-plan.md:5, 17, 39, 61 |
| AC-011 | covered | 01-plan.md:17, 41, 78 |
| AC-012 | covered | 01-plan.md:43, 102 |

03-tasks.md T-006 states that a failed setter leaves the previous id. That does not put the obligation into the reviewed plan.

## Per-criterion results

Not applicable. This is a plan review, not an implementation review. Coverage is in Verification performed.

## Findings

### F-001 — Failed speaker setter does not keep the previous id

- Severity: BLOCKER
- Location: `wiki/work/0009-english-vits-voice-selection/01-plan.md:31`
- Criterion affected: AC-006
- Observation: AC-006 requires that an out-of-range setter fail with unsupported-profile and that the previous id remain in use. The negative case is a failed set that replaces the stored id or destroys the session. The plan says the setter repeats the create range check, that public errors use unsupported-profile, and that native tests add setter rejection. No plan sentence says a rejected set leaves the stored id unchanged or leaves the session alive. Verification lists rejected out-of-range ids and setter rejection, not preservation after failure.
- Why it matters: An implementer can write the new id and then reject, or dispose the session on setter failure, and still match every written plan step. The criterion is unmet at plan coverage.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | plan |
