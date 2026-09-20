---
id: managed-model-02-criteria
title: "Managed model setup acceptance criteria"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "android/**", "ios/**", "doc/**"]
summary: Planned managed model setup; no runtime implementation is delivered by this record.
---

# Acceptance criteria: managed model setup

## Frozen

- Frozen at: not yet
- Frozen by: not yet
- Scope: future runtime implementation. Documentation review checks that the plan covers these criteria; it does not certify their implementation.
- Freeze only after default asset selection, distribution source, API names and native packaging decisions are recorded and reviewed.

## Criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-001 | Preparation offers one recommended compatible speech bundle with pinned provenance, notices, language, purpose and exact download/installed sizes; no LLM is required. | Inspect selected assets and trusted catalog; compare byte totals. | Reject missing notices, unknown roles and incompatible engine/profile. |
| AC-002 | A developer prepares models without supplying paths or manifests and passes the returned LocalModelBundle to the existing agent API; existing offline callers and LocalModelStore implementations remain supported. | Compile minimal managed and existing local consumers. | Offline local creation with missing files fails without networking. |
| AC-003 | Explicit initial preparation reports progress, cancellation and actionable errors; an installed verified version is reusable without network requests. | Count transport calls across first and later launches. | First launch offline fails clearly; cancelled preparation never becomes ready. |
| AC-004 | Installation verifies trusted expected hashes and lengths before atomic activation, coordinates concurrent callers and retains a prior usable version after failure. | Exercise two callers, retry and process-restart recovery. | Corrupt/truncated content, path escape and interrupted activation never replace a usable bundle. |
| AC-005 | Installation streams data, accounts for peak disk demand, stores persistent app-private data and prevents removal of active bundles. | Measure buffering; inspect storage/backup policy; exercise removal and updates. | Low disk, removal while active and failed update preserve current sessions and bundles. |
| AC-006 | The main example has no path/manifest input; it shows language, purpose, download size, progress/cancel/retry and existing conversation controls using library preparation. | Walk through fresh and installed launches; inspect example source. | Failed setup leaves start unavailable; retry requires no file manipulation. |
| AC-007 | The SDK performs no inference uploads, cloud fallback or hidden model updates; network access is limited to explicitly initiated managed preparation/update. | Observe networking during setup and disconnected inference. | Deny network after installation; speech still works and no fallback request occurs. |
| AC-008 | A clean consumer can build Android and iOS with documented standard Flutter setup without manual native provisioning scripts; native engines are resolved at build time, not fetched by the running app. | Run clean consumer builds and document offline build inputs and dependency notices. | Missing build dependency fails actionably; selecting an unsupported LLM capability never starts a weight download. |
| AC-009 | The selected real speech bundle is verified on supported physical Android/iOS devices for first setup, offline reuse, speech vocabulary and interruption; limitations and measurements name devices and versions. | Record physical-device evidence with real models and audio. | Unsupported language/device and unqualified results are not advertised as supported. |
| AC-010 | README, models guide, example and capability documentation distinguish first-download networking, offline inference, optional LLM and unresolved pre-existing gates. | Review documentation against actual delivered behavior. | Proposed symbols and unverified performance are never presented as available guarantees. |

## Explicitly not required

A broad catalog, Hebrew support, automatic ranking, background downloads, partial-file byte-range resume, cloud inference or closing the existing VITS allocation blocker through this setup change.

## Verdict log

No implementation review has occurred. Research/plan review results are recorded separately in STATE.yaml.
