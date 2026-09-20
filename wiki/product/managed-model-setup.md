---
id: managed-model-setup
title: "Managed model setup proposal"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "android/**", "ios/**", "doc/**"]
summary: Proposed default bundle, managed installation, simple API and example, and separate build-time packaging requirements.
---

# Managed model setup

**The example first-run implementation is tracked in work0006.** Work0005 delivered the [explicit preparation core](model-preparation-core.md); work0006 adds a pinned English compact/full-precision catalog, example private storage and selection/download/offline controls. The broader library-owned storage API, native consumer packaging and physical-device qualification in this proposal remain open. Neither scoped item completes all parent criteria.

## Product direction

The library should own finding, downloading, validating and storing a compatible speech bundle. Start with one recommended bundle instead of requiring users to select technical model components or type a device path. Maintain a versioned descriptor so a small curated catalog can be introduced when qualified alternatives exist.

The initial candidate is English. Exact example weights and payload sizes are now pinned in the catalog. Memory guidance, redistribution rights and physical-device qualification remain unresolved. Hebrew and other additional languages are not established. Every eventual catalog entry must explain language, purpose, download/installed size and engine compatibility; performance comparisons need measured evidence.

## User journey

On first launch, show the recommended bundle, language, purpose and download size, with a Download and prepare action. Show progress, cancellation and retry. Once ready, enable the conversation controls. On later launches, reuse the installed version offline without a remote catalog check. Do not ask users for folders, manifests, hashes or separate speech components.

Version one supports foreground download and safe retry. Fully verified completed files may be reused; interrupted files may restart. Background continuation and byte-range resume are deferred. No microphone activation occurs until preparation succeeds and the user starts the conversation.

## Library and example boundary

The proposed API has two steps: prepare the recommended bundle, then create the agent with the returned existing LocalModelBundle and the app's reply function. Exact new names remain undecided. Preserve the existing network-free LocalVoiceAgent.create and LocalModelStore contracts. Keep local/bundled assets available for advanced users and first launches that must be fully offline.

The library owns application-private persistent storage, catalog validation, trusted hashes, streaming download, disk checks, staging, activation, concurrent-call coordination, failure recovery and active-version retention. The host UI owns the download action and presentation; progress and errors come from the library. The example remains small and demonstrates the integration rather than implementing an installer itself.

Speech recognition and synthesis are separate from generating a reply. The main example keeps its short deterministic reply function. Optional local LLM setup must be separate and offered only when the corresponding native engine is already included in the app.

## Network and compatibility policy

This proposal changes the original product specification's exclusion of SDK-managed downloads **only for an explicit preparation/update path**. Local creation, installed reuse and inference remain offline, with no uploads, cloud fallback or implicit updates. The explicit core implements preparation only; updates and the broader library-owned storage/packaging proposal remain unimplemented. Retain the original specification as historical rationale; do not silently rewrite work item 0002's frozen criteria.

The first catalog is pinned and shipped with the library; arbitrary remote catalog configuration is not part of this design. Verify expected hashes from this trusted catalog rather than trusting a manifest supplied by the same untrusted download. Failed updates retain the previous usable version. Active bundles cannot be deleted or replaced while a session reads them.

## Developer setup is a separate requirement

Model data installation alone does not deliver an effortless developer experience. Current native dependencies require manual development-time provisioning. Plan a pinned build-time packaging mechanism for Android/iOS and prove clean consumer builds without those scripts. The app must never download native executable engines through its model installer. Until packaging and qualification are demonstrated, documentation must state the remaining setup steps.

## Delivery and remaining decisions

Implementation order: qualify the default bundle; finalize the preparation API; implement installation and recovery; simplify native build setup; simplify the example; validate real devices and update consumer documentation. Runtime and model distribution decisions require evidence before release. Existing VITS allocation and device qualification gates remain open in their original work item.

See the [research](../work/0004-managed-model-setup/00-research.md), [implementation plan](../work/0004-managed-model-setup/01-plan.md), [acceptance criteria](../work/0004-managed-model-setup/02-criteria.md), [ordered tasks](../work/0004-managed-model-setup/03-tasks.md) and [state](../work/0004-managed-model-setup/STATE.yaml).
