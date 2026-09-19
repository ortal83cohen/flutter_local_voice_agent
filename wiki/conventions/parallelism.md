---
id: parallelism
title: Parallelism and delegation
status: active
owner: unassigned
last_verified: 2026-09-04
applies_to: ["**"]
summary: When to fan out to multiple subagents, when not to, and how to merge what comes back.
---

# Parallelism and delegation

## The delegation contract

Every subagent prompt states five things. A prompt missing any of them produces duplicated work, gaps, or two subagents that each assumed the other handled something:

1. **Objective** — the single question or deliverable, stated as an outcome.
2. **Output format** — the exact shape expected back, including required sections.
3. **Tools and sources** — which tools to use, which sources to trust, which to avoid.
4. **Boundary** — what is explicitly not this subagent's job.
5. **Output path** — the file this subagent owns and writes to. No two subagents share a path.

## Parallelise

- Read-only research: one subagent per question, running concurrently.
- Independent modules or files with no shared surface.
- Competing hypotheses when debugging: each subagent pursues one, they do not coordinate.
- Best-of-N generation with a separate judge.

Target three concurrent subagents. Five is the ceiling. Beyond that, coordination cost exceeds the parallelism gain and failure modes multiply.

## Never parallelise

- **Writing the plan.** The plan is where shared assumptions get decided. Two authors decide them differently.
- **A shared hotspot file** — routing tables, configuration, registries, schemas, lockfiles. These serialise by nature; parallel edits produce merges that compile and disagree at runtime.
- **A cross-cutting interface decision.** One agent decides, then everyone builds against it.
- **The validation verdict.** One verdict, one validator, one record.

## Before fanning out

Decide the shared design choices yourself and state them in every delegation prompt: the interface shape, the naming, the error handling convention, the data format. Assumption collisions cannot be repaired by sharing context afterwards — by then each branch has built on its own assumption.

## Merging what comes back

Four mechanisms, in order of preference:

1. **Summary only.** The subagent writes its full work to its own file and returns a short summary. Aim for a report an order of magnitude smaller than the work behind it.
2. **Artifact plus reference.** The subagent writes a file; the parent receives the path and reads only what it needs.
3. **Schema-constrained output.** The subagent returns a fixed structure the parent can merge mechanically.
4. **Synthesiser agent.** A dedicated agent ranks and deduplicates several parallel outputs into one. Use when the branches genuinely overlap.

Integrate code changes sequentially — one branch at a time, each through the full check suite. Never merge two parallel code branches simultaneously.

## Known failure modes

Watch for these in a parallel run; each has a specific fix:

| Symptom | Cause | Fix |
|---|---|---|
| Two subagents did the same work | Boundary not stated in the prompt | Restate the boundary; do not deduplicate after the fact |
| Branches built against different interfaces | Assumption collision | Decide the interface before fan-out |
| Merge conflicts in one file every time | Shared hotspot | Serialise that file; give it a single owner |
| A subagent repeated the same step | Loop with no completion condition | State the completion condition in the prompt |
| A subagent reported success without evidence | No output-format requirement | Require pasted command output in the output format |

## Isolation

For a parallel run that writes code, give each subagent an isolated copy of the repository — a git worktree — and merge the branches sequentially. Shared working directories with concurrent writers are a reliable source of unexplainable state.
