---
id: definition-of-done
title: Definition of done
status: active
owner: unassigned
last_verified: 2026-09-04
applies_to: ["**"]
summary: The checklist that closes a phase and the checklist that closes a work item.
---

# Definition of done

## Per phase

A phase is done when its gate in `workflow.md` passes and `STATE.yaml` records the new phase, round and verdict. Not before. A phase reported done with a failing check is the single most expensive lie available in this pipeline, because every later phase builds on it.

## Per work item

Tick every line. A line that cannot be ticked is either a task or an escalation, never a rounding error.

**Code**

- [ ] Every acceptance criterion has an explicit pass verdict with file-and-line evidence.
- [ ] Every criterion has at least one negative test that fails when the behaviour is wrong.
- [ ] The full check suite ran and its output is pasted into the implementation review.
- [ ] No mock or test relaxation was added to make a failing test pass.
- [ ] No `TODO`, no commented-out code, no debug output left behind.

**Validation**

- [ ] Latest plan review is `PASS`, or `CONDITIONAL` with every blocker closed and recorded.
- [ ] Latest implementation review is `PASS`.
- [ ] Every `IMPORTANT` finding is either closed or recorded as a follow-up with an owner.
- [ ] `PRE_EXISTING` findings are recorded, not silently absorbed into this work item.

**Documentation**

- [ ] `wiki/product/` reflects the behaviour that now exists.
- [ ] An ADR exists for every decision that was genuinely a choice between viable options.
- [ ] `last_verified` refreshed on every wiki document whose content was re-checked — and only on those.
- [ ] Every new wiki document has a line in `wiki/INDEX.md`.
- [ ] `python3 tools/lint_wiki.py` exits clean.

**Record**

- [ ] `STATE.yaml` phase is `done`.
- [ ] Documentation is in the same commit as the code, not a follow-up.

## What "done" does not mean

Done does not mean the agent believes the work is correct. It means the evidence is on disk and someone else can check it without asking the author anything.
