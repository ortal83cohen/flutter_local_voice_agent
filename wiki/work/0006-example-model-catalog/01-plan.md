---
id: example-catalog-01-plan
title: "Example catalog: 01-plan"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "doc/**"]
summary: Deliver selectable verified model downloads and offline reuse in the example.
---

# Plan: selectable downloadable example models

## Goal and approach

Replace the required local-folder field with a real catalog picker, explicit download action, progress/cancel/retry and existing conversation controls. Select compatible English speech configurations from pinned upstream assets with exact lengths, hashes and license provenance. Show honest language, purpose and sizes rather than unsupported quality rankings. A catalog entry is a complete speech bundle, not a cloud model or an LLM.

Retain the existing preparation service and offline voice engine. Add opt-in bounded HTTPS redirects for stable upstream/CDN URLs while retaining rejection by default. Allow only the initial origin or catalog-declared exact HTTPS CDN origins. Validate every redirect destination, reject HTTP downgrade, credentials, fragments and invalid ports, cap hops, never forward custom authorization/cookie headers, and discard redirect bodies without buffering. Preserve cancellation, timeouts and integrity checks.

Expose the static catalog from the package. Use manager maxRedirects with default zero and an immutable allowedRedirectOrigins list; the catalog supplies verified CDN origins for an explicit download. Store model payloads and the last selection in a persistent application-private directory: Android noBackupFilesDir and iOS Application Support with backup exclusion, exposed to the example through its own method channel. Do not add path-provider or a preferences dependency solely for this example. Restoration validates trusted catalog content with a network-disabled client factory; only an explicit download action enables network. A missing or damaged installation remains unavailable and gives an actionable retry/redownload path confined to inactive example-owned bundles.

The example controller serializes setup, model switching and voice lifecycle. It disposes an old voice session before switching models; disables Start until verified preparation and native creation succeed; cancels preparation on backgrounding or disposal; and prevents late asynchronous completions from reviving a disposed screen. Use one subdirectory per catalog id and keep selection.json at the private root. Before explicit transfer, query platform availableBytes and require payload size plus a 10 MiB margin; this is an advisory check, not a reservation. Persist selection safely, present errors without raw URLs, and keep recognizer transcripts and replies visible. The local response logic is explicitly presented as a demo rather than a general-purpose AI model.

## Sequence and ownership

First verify upstream catalog metadata and exact bytes, platform storage APIs, and the current emulator/build route. Record sources and unresolved physical qualification boundaries. Review the research and this plan against acceptance criteria before freezing them.

The coordinator owns catalog data/API, downloader redirect support and associated core tests, shared export, documentation, workflow and final device verification. One implementation worker owns example Dart UI/controller/tests, example platform storage bridges and manifest permissions, and example dependency declarations. These modules can progress independently after the shared controller/catalog contract is fixed. No worker changes native inference contracts or shared core files.

Run real network preparation using the checked-in catalog and real native-engine smoke tests using those prepared files. Run example widget/controller negative tests, all repository checks, Android builds and an emulator walkthrough of selection, preparation, readiness, restart and offline reuse. Run iOS build verification where available; do not substitute it for physical audio evidence. Register final independent review and keep any genuine remaining errors explicit.

## Risks and alternatives

Large model downloads need explicit consent and disk space. Show payload size, leave sufficient space for the full staged payload, preserve already installed versions, and report storage errors clearly. The example can delete only the currently selected inactive corrupt installation for explicit retry, never a bundle in use. Background download/resume, global cleanup and power-loss guarantees remain outside this change.

A static pinned catalog is preferable to trusting a mutable remote manifest. Downloaded model bytes must still match independently recorded hashes. CDN redirects are needed for stable hosted files; signed expiring URLs must not be embedded in the catalog. Compact and full-precision variants are legitimate choices without inventing voice or language support. Exact alternatives depend on verified upstream availability.

## Explicit boundaries

Deliver the runnable provisioned-checkout example with real models. Native binary distribution for a fresh published consumer, physical Android/iOS acoustic/thermal qualification, Hebrew support, arbitrary model architectures, general-purpose LLM chat and the existing VITS whole-sentence allocation gate are separate. None prevents exercising and delivering the requested picker/download/start flow in the current example.
