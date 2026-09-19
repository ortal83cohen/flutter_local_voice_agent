---
id: index
title: Wiki index
status: active
owner: unassigned
last_verified: 2026-09-19
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

## Offline voice agent research and specification

| Document | Read it when |
|---|---|
| [Research consolidation](work/0001-local-voice-agent-architecture/00-research.md) | Reviewing delegated evidence, provisional selections and unresolved questions. |
| [Documentation plan](work/0001-local-voice-agent-architecture/01-plan.md) | Understanding the scope and workflow for this specification. |
| [Acceptance criteria](work/0001-local-voice-agent-architecture/02-criteria.md) | Evaluating the research and specification deliverable. |
| [Tasks](work/0001-local-voice-agent-architecture/03-tasks.md) | Checking ownership and dependency order. |
| [Speech research](work/0001-local-voice-agent-architecture/research/speech.md) | Comparing VAD, STT and native recognition alternatives. |
| [Intelligence and TTS research](work/0001-local-voice-agent-architecture/research/intelligence-tts.md) | Comparing local runtimes, voices, streaming and licenses; read supplementary updates too. |
| [Mobile systems research](work/0001-local-voice-agent-architecture/research/mobile-systems.md) | Checking audio, threading, lifecycle and operating-system evidence. |
| [Plan review](work/0001-local-voice-agent-architecture/validation/plan-review-01.md) | Inspecting the independent plan verdict. |
| [Verification evidence](work/0001-local-voice-agent-architecture/04-verification.md) | Distinguishing executed documentation checks from toolchain and device verification gaps. |
| [Work state](work/0001-local-voice-agent-architecture/STATE.yaml) | Checking phase, decisions and unresolved gates. |
| [Technical PRD and architecture](product/local-voice-agent-prd.md) | Implementing the proposed offline SDK; contains all five chapters and proposed Dart examples. |
| [Architecture decision](adr/0001-offline-voice-architecture.md) | Reviewing adapter selection, native ownership and conditional qualification. |
| [Research review round 1](work/0001-local-voice-agent-architecture/validation/research-review-01.md) | Inspecting the original license finding. |
| [Research review round 2](work/0001-local-voice-agent-architecture/validation/research-review-02.md) | Inspecting the independent source-confirmation verdict. |
| [Specification review](work/0001-local-voice-agent-architecture/validation/impl-review-01.md) | Inspecting per-criterion evidence and the independent documentation verdict. |
| [Delivery record](work/0001-local-voice-agent-architecture/05-delivery.md) | Understanding delivered scope, review outcomes and remaining verification gates. |
