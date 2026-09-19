---
id: index
title: Wiki index
status: active
owner: unassigned
last_verified: 2026-09-15
applies_to: ["**"]
summary: Router for the whole wiki. One line per document, stating when to read it.
---

# Wiki index

Every document in this wiki is reachable from here in one hop. If you add a document, add its line here in the same commit or the lint fails.

## Conventions — read before writing anything

| Document | Read it when |
|---|---|
| [workflow.md](conventions/workflow.md) | Starting any change. Defines the six phases and the gates between them. |
| [naming.md](conventions/naming.md) | Creating any file or frontmatter block. Defines IDs, slugs, numbering, required fields. |
| [validation-rubrics.md](conventions/validation-rubrics.md) | Acting as a validator, or reading a validation report. Defines verdicts, severities, evidence rules. |
| [model-routing.md](conventions/model-routing.md) | Choosing which model runs a phase or a subagent. |
| [parallelism.md](conventions/parallelism.md) | Deciding whether to fan out to multiple subagents, and how to merge their output. |
| [definition-of-done.md](conventions/definition-of-done.md) | Closing a work item. The checklist that must pass before a phase or item is done. |

## Templates — copy, do not improvise

| Document | Read it when |
|---|---|
| [templates/00-research.md](templates/00-research.md) | Writing the research artifact. |
| [templates/01-plan.md](templates/01-plan.md) | Writing the plan. Prose only, no code blocks. |
| [templates/02-criteria.md](templates/02-criteria.md) | Writing acceptance criteria before implementation. |
| [templates/03-tasks.md](templates/03-tasks.md) | Breaking the plan into ordered tasks. |
| [templates/validation-report.md](templates/validation-report.md) | Producing any validation verdict. |
| [templates/STATE.yaml](templates/STATE.yaml) | Creating a new work item folder. |
| [templates/adr.md](templates/adr.md) | Recording an architecture decision. |

## Project records

Project-specific architecture decisions, product notes, release records, and
work items belong in a fork after the project has a name and a domain. Add them
to this index when they are created.
