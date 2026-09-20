---
id: managed-model-03-tasks
title: "Managed model setup ordered tasks"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "android/**", "ios/**", "doc/**"]
summary: Planned managed model setup; no runtime implementation is delivered by this record.
---

# Tasks: managed model setup

All runtime tasks below are pending. Current delivery documents the intended change only.

| Order | Task and exclusive responsibility | Satisfies | Done when |
|---|---|---|---|
| 1 | Finalize exact bundle inventory, catalog metadata and qualification record; proposed new catalog files remain to be named in the next plan revision. | AC-001, AC-009 | Sources, notices, sizes and compatibility are verified. |
| 2 | Finalize preparation API, compatibility and error contracts; own public exports and shared lib contracts. | AC-002, AC-003 | Interface review is recorded before criteria freeze. |
| 3 | Implement model manager, transport, storage and their tests; own proposed new manager modules and existing model-store integration. | AC-003, AC-004, AC-005, AC-007 | Positive and failure/recovery cases pass with output. |
| 4 | Integrate agent lifetime with managed bundle retention; own lib/src/agent.dart and lifecycle integration tests. | AC-002, AC-005 | Active removal/update cases preserve session files. |
| 5 | Resolve native dependency packaging and networking configuration; own Android/iOS build files, manifests and dependency declarations. | AC-008 | Clean consumer builds and offline build-input path are demonstrated. |
| 6 | Simplify example and its tests; own example/lib/main.dart and example UI tests. | AC-006 | First-run, retry and installed flows are demonstrated. |
| 7 | Run real-device qualification with final pinned bundle; append evidence without changing old work items. | AC-001, AC-007, AC-009 | Device and network evidence is captured; unresolved failures remain open. |
| 8 | Update consumer/product documentation and changelog; own README.md, doc/, wiki/product/ and index links. | AC-010 | Documentation matches implemented behavior and independent review is recorded. |

## Serialised files

Public contracts/exports are owned by task 2; build configuration and dependency files by task 5; example source by task 6. Implementation does not fan out until exact new file ownership and API decisions are settled in a reviewed plan revision. Tests stay with each implementation owner. Task 7 executes qualification but does not rewrite implementation tests.

## Test tasks

Each implementation owner executes both columns of the checks in 02-criteria.md for its assigned criteria. Controlled transport tests prove failure handling; they do not substitute for the real-model and physical-device evidence in task 7.
