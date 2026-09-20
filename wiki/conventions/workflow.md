---
id: workflow
title: Development workflow
status: active
owner: unassigned
last_verified: 2026-09-15
applies_to: ["**"]
summary: The six-phase pipeline every change follows, its artifacts, and the gates between phases.
---

# Development workflow

## Two routes

**Quick route** — one file changed, no new dependency, no public interface change, no data model change, no security or privacy surface. Invoke `/quick-change`. It produces a one-page record and runs the existing checks. No plan, no separate validator.

**Full route** — everything else. Invoke `/feature`. Six phases, described below.

Choosing the quick route for something that is not quick is the most expensive mistake available here. When in doubt, take the full route.

## Work item folder

Each full-route change gets `wiki/work/NNNN-kebab-slug/`, where `NNNN` is the next unused four-digit number. Numbers are never reused, even for abandoned items.

The folder holds:

```
00-research.md
01-plan.md
02-criteria.md
03-tasks.md
validation/plan-review-01.md
validation/impl-review-01.md
STATE.yaml
```

`STATE.yaml` is the only mutable file. Every other artifact is append-or-supersede.

## Subagent output

Subagents do not create temporary documents for their responses. Exploratory findings, test results, diagnostics, reviews, and similar short-lived output are returned directly to the parent agent. A subagent writes a file only when the file is a durable workflow artifact required by a later phase or another agent, such as research, a plan, acceptance criteria, a task list, a validation report, or a verification artifact. The parent agent records any required decision or durable result in the appropriate workflow artifact.

## Phase 1 — Research

Goal: know enough that the plan is not guesswork.

Fan out read-only research subagents in parallel, one per question, each writing to its own path. Merge into `00-research.md`.

Research is done when every open question is either answered with a cited source or explicitly listed as `[UNRESOLVED: question]`. An unresolved question is an acceptable output; a silently skipped one is not.

Gate: the research artifact exists, every claim carries a source or an `[UNVERIFIED]` marker, and the unresolved list is explicit.

## Phase 2 — Plan

Goal: a plan a competent implementer can follow without asking a question.

One agent writes the plan. Never parallelise this phase — the plan is where shared assumptions are decided, and two authors produce two incompatible sets.

The plan is prose. It states, in order: the goal, the approach, the reasoning for the approach over the alternatives considered, the sequence of steps, what each step touches, the risks, and what is explicitly out of scope.

**No code blocks. No snippets. No pseudo-code.** A plan that contains code has stopped being a plan. This is enforced by `tool/lint_wiki.py`.

Alongside the plan, write `02-criteria.md`: numbered acceptance criteria, `AC-001` upward, each independently checkable. Criteria freeze when Phase 4 starts.

Gate: plan exists, criteria exist, lint passes.

## Phase 3 — Validate research and plan

Goal: catch the defect now, when it costs a paragraph instead of a refactor.

Run two validators in parallel, in fresh contexts:

- a research validator, checking the research for unsupported claims, missed alternatives and stale sources;
- a plan validator, checking the plan against the criteria for gaps, unstated assumptions, missing rollback and unaddressed risks.

A validator receives the artifact and the criteria. It does not receive the author's reasoning, transcript or intermediate notes. Blindness is what makes the review independent.

A validator returns a verdict — `PASS`, `CONDITIONAL` or `FAIL` — with findings graded `BLOCKER`, `IMPORTANT`, `NIT` or `PRE_EXISTING`. Every finding cites a file and line. A validator never proposes the fix; proposing it turns the validator into a second author with a stake in its own suggestion. It also never decides what happens next — that call belongs to the main agent.

The main agent reads the verdict and decides, finding by finding: fix it directly by patching the plan or research in place, or accept it as pre-existing or out of scope. There is no "send back for a rewrite" step — a validator finding is a patch to the existing artifact, not a mandate to redo it from scratch. The agent records every such decision in `STATE.yaml`, with the finding, the verdict and the reason.

At most two rounds total for this phase: the first round, then, if fixes were made, one optional confirmation round over the patched artifact. The confirmation round is not required — run it only when the findings were significant enough to warrant a second look. A third round never happens; if the confirmation round still fails, escalate to a human instead of iterating further.

Gate: at least one round has run, every finding it raised has a recorded decision, and if a confirmation round ran, its findings are also recorded.

## Phase 4 — Implement

Goal: working code that satisfies the frozen criteria.

Criteria are frozen from this point. Work through `03-tasks.md` in dependency order. Tasks marked `[P]` may run in parallel subagents; each parallel subagent owns its files exclusively.

The implementer writes the code and its tests together. Splitting them across agents costs more in coordination than it buys in independence — the independence that matters came from freezing the criteria before any code existed.

Do not add a mock to make a test pass. Do not widen a test to accept the current output. Both are recorded failure modes, not shortcuts.

Gate: every task closed, build green.

## Phase 5 — Verify

Goal: evidence, not assertion.

Run the project's full check suite and paste the output. Then run an implementation validator in a fresh context: it sees the frozen criteria and the diff, nothing else, and reports per-criterion pass or fail with file-and-line evidence.

Each criterion needs at least one negative test — a case that should fail and does. A suite that only proves the happy path proves very little.

Verdict handling is identical to Phase 3: one round, and the main agent decides what happens next. A `FAIL` naming a plan defect goes back to Phase 2, not to more code.

Gate: implementation review is `PASS`, full check suite output pasted, `tool/lint_wiki.py` clean.

## Phase 6 — Document

Goal: the wiki describes the code that now exists.

Update the product knowledge under `wiki/product/`, add an ADR if a decision was made, refresh `last_verified` on every document touched, and add any new document to `wiki/INDEX.md`.

Documentation lands in the same commit as the code. A follow-up commit is a documentation debt, and documentation debt compounds silently.

Gate: `tool/lint_wiki.py` clean, every wiki document reachable from the index in one hop.

## Human gates

Escalate to a human at exactly three points: an oscillating validation loop, a decision with legal, financial, privacy or production impact, and a scope change that invalidates the frozen criteria. Escalate as a specific question, never as a raw diff to approve.
