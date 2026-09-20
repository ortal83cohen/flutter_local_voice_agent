---
id: preparation-core-03-tasks
title: "Tasks: explicit model preparation core"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "test/**", "doc/**"]
summary: Explicit verified model preparation infrastructure; default catalog and mobile qualification remain separate.
---

# Tasks: explicit model preparation core

## Groups

| Order | Task | Criteria | Exclusive files | Done when |
|---|---|---|---|---|
| 1 | Record research and validate plan/research | AC-001 through AC-007 | Work artifacts and STATE owned by coordinator; validator reports separately | Findings dispositioned before implementation |
| 2 | Implement contracts, manager and their regression tests serially | AC-001 through AC-006 | lib/src/model_preparation_models.dart, lib/src/model_preparation.dart, test/model_preparation_test.dart, test/support/preparation_https_server.dart | Real TLS positive/failure/concurrency tests pass |
| 3 | Integrate exports and run full checks | AC-002, AC-006, AC-007 | lib/flutter_local_voice_agent.dart owned by coordinator | Existing consumers compile and checks are recorded |
| 4 | Document and independently validate | AC-007 and all implementation criteria | README.md, doc/model-preparation.md, doc/capabilities.md, CHANGELOG.md, wiki/product/model-preparation-core.md, wiki/INDEX.md owned by coordinator; independent review path owned by validator | Evidence and explicit deferred gates retained |

## Serialised files

Only one source implementer works at a time. The coordinator owns shared exports and documentation and does not edit worker-owned source during execution. No concurrent implementation writers require a worktree. Research fan-out is read-only apart from separate reports.

## Test tasks

Implementation owner writes real temporary filesystem and loopback TLS cases for every positive and negative criteria column. Existing Dart/native tests remain unchanged. Reviewers run their own checks once and do not propose or implement repairs.

## Implementation integration note

The coordinator adds OpenSSL to tool/check.sh preflight because the reviewed real-TLS test design requires its executable for temporary certificate generation. This adds no runtime package dependency or interface change; AC-007 check execution should fail actionably before tests when the prerequisite is missing.

## Local completion record — 2026-09-20

Groups 1–4 are complete within the frozen core scope. Research and plan reviews passed; implementation review01 defects were repaired and independently reproduced; fresh blind review02 passed all seven criteria. Coordinator final source snapshot passed all seven check stages with 56 tests and zero package warnings. The live Git warning remains recorded in 04-verification.md. Code and documentation are locally delivered together; committing or publishing has not been authorized. Parent0002/0004 gates remain open.
