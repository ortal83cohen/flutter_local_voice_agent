# Plan review — round 02

- Work item: 0009-english-vits-voice-selection
- Reviewed artifact: wiki/work/0009-english-vits-voice-selection/01-plan.md
- Reviewer: independent plan validator
- Date: 2026-09-20

## Verdict

**PASS**

Every stated criterion is covered by the current plan text, including the previous AC-006 gap, and no blocker remains on plan coverage.

## Verification performed

This is a plan confirmation review. No implementation suite was run.

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
print('plan_has_html_pre:', '<pre' in plan.lower())
print('plan_has_code_tag:', '<code' in plan.lower())
PY
```

```
plan_fenced_triple_backtick: 0
plan_fenced_tilde: 0
plan_lines: 102
plan_has_html_pre: False
plan_has_code_tag: False
```

Inspected:

- wiki/conventions/validation-rubrics.md
- wiki/templates/validation-report.md
- wiki/work/0009-english-vits-voice-selection/01-plan.md
- wiki/work/0009-english-vits-voice-selection/02-criteria.md
- wiki/work/0009-english-vits-voice-selection/03-tasks.md, only to test whether every criterion has an owning task
- wiki/work/0009-english-vits-voice-selection/00-research.md, only where the plan relies on a named research claim
- wiki/work/0009-english-vits-voice-selection/validation/plan-review-01.md, only for the Recurrence check
- Files the plan names or depends on: lib/src/model_catalog.dart; lib/src/contracts.dart; lib/src/models.dart; native/include/flva.h; native/src/flva.cpp; example/lib/model_storage.dart; example/lib/voice_screen_controller.dart; README.md; doc/model-catalog.md; doc/models.md; doc/capabilities.md; doc/model-preparation.md; doc/testing.md; wiki/product/example-model-catalog.md; wiki/adr/0003-example-model-catalog.md; wiki/INDEX.md

Grounding checks:

- 01-plan.md contains zero fenced code blocks (triple-backtick count 0, tilde-fence count 0). `python3 tool/lint_wiki.py` reported clean with 0 warnings.
- 02-criteria.md lists AC-001 through AC-012. Frozen at / Frozen by remain “not yet”.
- 03-tasks.md assigns every criterion to at least one task: AC-001 to 1.2; AC-002 to 1.1, 1.2 and 5.1; AC-003 to 2.1–2.3; AC-004 to 2.1–2.3; AC-005 to 2.1–2.3 and 3.2; AC-006 to 2.1 and 2.2; AC-007 to 3.1 and 3.2; AC-008 to 3.1 and 3.2; AC-009 to 3.2; AC-010 to 4.1; AC-011 to 4.2; AC-012 to 4.1, 4.2 and 5.1.
- Named research claims used by the plan (two official English lexicon VITS voices; VCTK 109 speakers 0–108; Lessac as Piper data-directory) are the claims at 00-research.md:39 and 00-research.md:43. Inventory bytes and hashes remain unresolved there and are treated as an implementation measurement step in the plan, not as assumed numbers.
- VoiceModelOption has no speaker-count field today (lib/src/model_catalog.dart:6–13). FlvaConfig has no speaker field (native/include/flva.h:11–16). Native generate currently hard-codes speaker id 0 (native/src/flva.cpp:332–333). NativeVoicePlatform.create returns an inactive session; start, not create, takes microphone ownership (lib/src/contracts.dart:18–24). AgentErrorCode.unsupportedProfile already exists (lib/src/models.dart:84). Example selection JSON stores catalogId only (example/lib/model_storage.dart:119). Pack change already disposes the previous session (example/lib/voice_screen_controller.dart:176).
- Consumer and wiki wording still describes two LJS precision packs: README.md:108–118, doc/model-catalog.md:16 and :40, doc/capabilities.md:7, doc/model-preparation.md:7, wiki/product/example-model-catalog.md:13. wiki/adr/0003-example-model-catalog.md exists and remains reachable from wiki/INDEX.md:145. wiki/adr/0004-english-vits-voice-selection.md does not exist yet.
- Rollback is present at 01-plan.md:78 and names catalog, speaker fields, native generate, selection JSON, documentation wording, LJS installs, extra-field readability after rollback, and wiki supersession rather than deletion.

Plan-coverage map (not implementation results):

| Criterion | Covered by plan? | Evidence |
|---|---|---|
| AC-001 | covered | 01-plan.md:5, 11, 27 |
| AC-002 | covered | 01-plan.md:11, 25, 102 |
| AC-003 | covered | 01-plan.md:13, 29, 51, 99, 101 |
| AC-004 | covered | 01-plan.md:13, 29, 31, 51, 59 |
| AC-005 | covered | 01-plan.md:5, 13, 15, 35, 53 |
| AC-006 | covered | 01-plan.md:13, 31, 51, 59, 99 |
| AC-007 | covered | 01-plan.md:15, 35, 37 |
| AC-008 | covered | 01-plan.md:15, 35, 37 |
| AC-009 | covered | 01-plan.md:15, 35, 55 |
| AC-010 | covered | 01-plan.md:5, 17, 39, 61 |
| AC-011 | covered | 01-plan.md:17, 41, 78 |
| AC-012 | covered | 01-plan.md:43, 102 |

## Per-criterion results

Not applicable. This is a plan review, not an implementation review. Coverage is in Verification performed.

## Findings

None.

## Recurrence check

- Previous round: wiki/work/0009-english-vits-voice-selection/validation/plan-review-01.md
- Recurring findings: none
- Oscillating: no

Previous-round items as they appear in the current plan, for the main agent’s recurrence record only:

- Prior F-001 (AC-006, failed setter must keep the previous id and the session): present at 01-plan.md:13, 31, 51, 99

## Routing

| Finding | Belongs to phase |
|---|---|
| None | Not applicable |
