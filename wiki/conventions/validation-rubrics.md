---
id: validation-rubrics
title: Validation rubrics
status: active
owner: unassigned
last_verified: 2026-09-15
applies_to: ["**"]
summary: Verdicts, severities and evidence requirements that every validator obeys.
---

# Validation rubrics

## The validator's contract

A validator runs in a fresh context and receives exactly three things: the acceptance criteria, the artifact or diff under review, and the rubric for its phase.

It does not receive the author's reasoning, transcript, intermediate notes, or the author's own assessment. If a validator can see how the artifact was argued for, it reviews the argument instead of the artifact.

A validator has read and execute access. It has no write access to source files. It reports; it does not repair.

## Verdicts

| Verdict | Meaning |
|---|---|
| `PASS` | Every criterion is met. No blockers. Proceed. |
| `CONDITIONAL` | Criteria are met but named blockers must close first. The main agent closes them or records why not, on this same round. |
| `FAIL` | At least one criterion is unmet, or a blocker invalidates the approach. The main agent decides: fix directly, or return to the phase the defect belongs to. |

## Severities

| Severity | Meaning |
|---|---|
| `BLOCKER` | Violates a criterion, or is a correctness, security or data-loss defect. Must close before proceeding. |
| `IMPORTANT` | Will cause a real problem soon but violates no stated criterion. Close now or record as follow-up with an owner. |
| `NIT` | Style, naming, phrasing. Never blocks. |
| `PRE_EXISTING` | The defect is real and predates this change. Record it; do not expand this work item to fix it. |

## Evidence rules

- Every finding names a file and a line. A finding without a location is not actionable and does not count.
- Every claim that a check passes or fails includes the command and its pasted output. "Tests pass" without output is not evidence.
- Every criterion in an implementation review gets an explicit per-criterion verdict. Silence on a criterion is a failure of the review, not a pass for the code.
- At least one negative test per criterion: a case that should fail and does. A suite that only exercises the happy path does not establish the criterion.

## Anti-rubber-stamp rules

A validator must run the verification command itself and paste the output. It may not rely on the author's statement that the command was run, and may not rely on the author's statement that a previous finding was fixed — re-run the check, not the claim.

## Anti-over-finding rules

A validator is never instructed to find a minimum number of problems. A reviewer told to find gaps will manufacture them, and manufactured findings train everyone to ignore reviews.

Flag as `BLOCKER` or `IMPORTANT` only what affects correctness or a stated criterion. Everything else is a `NIT`. A review of sound work correctly returns `PASS` with a short `NIT` list or nothing at all.

## After the round

- At most two validation rounds per phase: the first round, then an optional second round to confirm fixes if the findings were significant. Neither round loops or re-checks its own findings, and there is no third round — a repeat `FAIL` on the second round escalates to the user.
- The validator reports; the main agent decides what happens next — fix a finding directly by patching the artifact in place, or accept it as pre-existing or out of scope. Record the decision and the reason.
- If a second round runs, it produces a new numbered report over the patched artifact; it never replaces the first one.
- Route the fix by defect class. A plan defect is patched in the plan. An implementation defect is patched in the code. Patching code to satisfy a plan-level finding buries the defect instead of fixing it. A finding is never an instruction to rewrite the artifact from scratch — that is a decision for the user to make explicitly.

## Reviewer strength

The reviewer is the ceiling on what review can catch. A weaker reviewer reviewing stronger output makes the result worse, not better. Reviewers get the strongest available model — see `model-routing.md`.

Self-review by the authoring agent is not validation. It measures close to zero. It may be used as a cheap pre-filter before the real review; it may never replace it.
