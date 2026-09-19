---
id: pipeline-03-tasks
title: "Tasks: Native offline voice pipeline"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation work artifact and evidence boundaries.
---

# Tasks: Native offline voice pipeline

## Groups

| Order | Task | Criteria | Exclusive ownership | Done when |
|---|---|---|---|---|
| 1 | Read-only feasibility fan-out | AC-004, AC-005, AC-006 | Separate research files | Exact evidence and unresolved list written |
| 2 | Plan, criteria and contracts | All | Coordinator: public contract/config/index/build files | Independent verdicts recorded |
| 3 | Native worker and speech adapter | AC-003, AC-004 | Isolated native implementation copy | Host tests and real API compilation |
| 4 | Dart facade and asset store | AC-001, AC-002 | Isolated Dart implementation copy | Dart positive/negative tests |
| 5 | Optional local LLM | AC-006 | Isolated adapter files | Pinned API build and limits tests |
| 6 | Platform bridges | AC-005 | Coordinator: Android and iOS | Builds and device evidence recorded |
| 7 | Example and documentation | AC-007 | Coordinator | Guide and package verification |
| 8 | Independent final verification | All | Validator report only | Per-criterion verdict and raw evidence |

## Serialization

Coordinator owns all shared interfaces, pubspecs, build configuration and wiki index. Code implementers use isolated temporary copies; results integrate sequentially. No commits or pushes.

## Test tasks

Every implementation task includes its positive and negative cases from the frozen criteria. Physical qualification AC-008 stays open until actual devices are available and measurements execute.
