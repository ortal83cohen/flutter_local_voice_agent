---
id: managed-model-01-plan
title: "Managed model setup implementation plan"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "android/**", "ios/**", "doc/**"]
summary: Planned managed model setup; no runtime implementation is delivered by this record.
---

# Plan: managed model setup

## Goal

A developer can prepare the recommended speech bundle without constructing filesystem paths or manifests, then create a voice agent using the existing local-bundle interface. The example exposes a first-run download action and conversation controls. This is a future implementation plan; the current request delivers documentation only.

## Approach

Add a separate model preparation service that returns the existing LocalModelBundle. Keep LocalVoiceAgent.create and LocalModelStore network-free and compatible with current callers. Preparation owns app-private persistent storage, a versioned installation index, downloads, integrity checks, staged activation and cleanup. Its operation is idempotent: a usable installation is returned without a network request. Failed preparation must never open the microphone.

Ship a trusted, version-pinned descriptor for one recommended speech bundle, initially an English candidate subject to qualification. Metadata includes stable identity, version, language, purpose, engine/profile compatibility, source provenance, expected file hashes and lengths, notices, download size and installed size. Memory guidance must cite measurements on named devices. An advanced catalog may later expose qualified alternatives; there is no arbitrary model discovery or inference of language support from the device locale.

Keep model preparation explicit and observable. The host initiates the first network download and owns presentation; the service exposes checking, downloading, verifying, ready, cancelled and failed states with byte progress when totals are known. Version one supports foreground preparation, cancellation, safe retry and reuse of fully verified completed files. Resuming partial files by byte range and background continuation are deferred. An interruption can restart an incomplete file; it must not corrupt an installed bundle.

## Why this approach

The research compares manual-only provisioning, a permanently fixed bundle, a curated catalog, a general browser and bundling all weights. A single recommended entry removes a choice from the first-run journey while retaining a path to more languages. A separate preparation service preserves existing offline contracts and custom LocalModelStore implementations. Optional generative LLM setup stays separate because the basic example already demonstrates app-owned response logic.

## Steps

1. Qualify the initial speech bundle and its distribution source. Record exact revisions, hashes, notices, sizes, English vocabulary limitations and device results. Resolve the default selection before freezing implementation criteria; do not label today's fixture production-ready.
2. Finalize the preparation API, typed failure mapping and descriptor shape in lib. Preserve the existing create and local-store contracts. Return a LocalModelBundle and expose progress and cancellation without requiring a UI framework. Keep new public names explicitly proposed until this step is reviewed.
3. Implement application-private storage and installation management. Serialize preparation of the same bundle across callers, stream downloads without whole-file buffering, validate against the trusted descriptor, and atomically activate a staged version. Check peak storage requirements, clean failed staging, preserve installed versions on failure and provide explicit removal that rejects bundles currently in use. App-private installation data must not use an evictable cache as its only copy; review platform backup exclusion.
4. Add foreground network delivery and release-mode platform configuration. Use HTTPS sources pinned by the trusted catalog. Report offline first launch, interruption, cancellation, insufficient storage, corrupt files and incompatible engines as actionable typed failures. Do not silently select another model or cloud inference. Coordinate cleanup and active-reader protection with agent disposal.
5. Replace the default example's directory field with one recommended bundle card, language, short purpose, exact download size, preparation progress, cancellation and retry. Reuse installed data on launch. Keep the small reply callback and existing start, interrupt, stop and transcript behavior. Explain first-download connectivity separately from offline speech processing.
6. Simplify native dependency distribution as a separate developer setup track. Evaluate package/build integration for pinned Android and iOS artifacts, validate redistribution notices, and document offline build inputs. Do not download executable engines through the model installer. Until clean consumer builds work without manual provisioning scripts, retain that limitation in quick-start documentation and leave the developer-experience criterion open.
7. Update README, model documentation, example instructions, capabilities, changelog and the product specification only to match behavior actually delivered. Retain advanced local import guidance. Execute acceptance tests, independent implementation review and physical-device qualification before closing implementation.

## Interfaces and shared decisions

Two primary operations are preparation and agent creation. Preparation produces LocalModelBundle; creation and inference remain offline. The host controls whether a download may start; a ready bundle is reused without checking a remote catalog. The first catalog is shipped with the package, with no remote executable configuration. Future catalog updates require a separate trust design.

Version one has one recommended speech entry and no required LLM. Preserve LocalModelStore rather than adding required downloader methods to existing implementers. Reuse AgentFailure where suitable; additions to public error codes require interface review. No silent model upgrades occur during a session. An explicit update stages a separate version; activation changes future sessions only, with the previous known-good version retained until safe removal.

## Risks

| Risk | Mitigation | Trigger |
|---|---|---|
| Incompatible or unlicensed default | Qualify exact pinned assets before shipping the descriptor | Missing notices, failed engine load or unavailable distribution permission |
| Partial or concurrent installation | Per-bundle coordination, staged verification, atomic activation | Cancellation, duplicate callers or process termination |
| Disk exhaustion or excessive buffering | Check peak disk demand and stream files with bounded buffers | Low-space tests or memory growth proportional to full file size |
| Example hides an unfinished build prerequisite | Clean consumer Android/iOS builds remain a separate exit gate | Manual runtime script still required |
| English fixture presented as universal | Display supported language and qualify response vocabulary | Unsupported-language selection or omitted spoken words |
| Update disrupts active use | Retain active versions and reject their removal | Update/removal during a live session |

## Rollback

The existing local preparation and creation path remains usable throughout. Disable the managed entry point in the example if qualification fails, retain the last verified bundle and its immutable files, and document manual setup explicitly. Do not delete active installations or change old work-item criteria to make this proposal appear complete.

## Out of scope

Background/resumable byte-range downloads, automatic remote catalog refresh, automatic device-based model ranking, a large model marketplace, additional languages, required LLM download, cloud fallback and full duplex. Existing native pipeline blockers remain owned by work item 0002.

## Verification approach

Use the criteria's positive and negative cases for catalog validation, deterministic delivery failures, interrupted staging, concurrency, offline reuse and active-version retention. Test managed installation against controlled transport fixtures, and separately prove selected real weights load through the actual native engines on physical Android and iOS devices. Run the repository's applicable full checks and clean consumer builds during implementation; record commands and outputs. Documentation-only delivery runs wiki lint, link checks and diff whitespace checks and makes no runtime qualification claim.
