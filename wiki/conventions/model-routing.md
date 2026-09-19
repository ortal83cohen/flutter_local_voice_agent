---
id: model-routing
title: Model routing
status: active
owner: unassigned
last_verified: 2026-09-04
applies_to: ["**"]
summary: Which model class each phase and subagent gets, and why.
---

# Model routing

Model names change. Capability tiers do not. This document routes by tier; the tier-to-name mapping is the only part that needs updating when a new model ships.

## Tiers

| Tier | Claude Code alias | Cursor equivalent | Character |
|---|---|---|---|
| Frontier | `opus` | strongest available model | Deepest reasoning, slowest, most expensive |
| Balanced | `sonnet` | default agent model | The right default for almost everything |
| Fast | `haiku` | fastest available model | Narrow, mechanical, high-volume work |

`inherit` means "use whatever the session is running". Prefer an explicit tier for any agent whose quality matters independently of the session.

## Routing table

| Role | Tier | Reason |
|---|---|---|
| Planner | Frontier | The plan decides every downstream assumption. This is the highest-leverage token spend in the pipeline. |
| Plan validator | Frontier | The reviewer is the ceiling on what review catches. A weaker reviewer makes strong output worse. |
| Implementation validator | Frontier | Same reason. Verification quality is not a place to economise. |
| Research validator | Frontier | Detecting an unsupported claim is harder than making one. |
| Researcher | Balanced | Breadth and synthesis, run in parallel. Volume matters more than depth per stream. |
| Implementer | Balanced | Well-specified work against frozen criteria. |
| Documentation keeper | Fast | Mechanical: refresh dates, update the index, reformat frontmatter. |
| Quick-change handler | Balanced | Small scope, but still writing code. |

## Effort

Where the tool exposes an effort level independently of the model, raise it for planners and validators and leave it at the default for researchers and documentation work. Effort buys reasoning depth on the same model, which is cheaper than a tier upgrade for reasoning-bound work.

## Cost discipline

A parallel fan-out costs roughly the sum of its branches, and a frontier fan-out costs several times a balanced one. Fan out on the balanced tier; converge on the frontier tier. Three balanced researchers feeding one frontier validator is the shape to aim for.

Before adding a fourth or fifth parallel agent, establish that three did not suffice. Agent count is the last lever to pull, not the first.
