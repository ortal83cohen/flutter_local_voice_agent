---
id: example-catalog-02-criteria
title: "Example catalog: 02-criteria"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "doc/**"]
summary: Deliver selectable verified model downloads and offline reuse in the example.
---

# Acceptance criteria: selectable example catalog

## Freeze

Frozen 2026-09-20 by coordinator after research PASS, plan PASS and recorded stricter pre-freeze constraints.

| ID | Requirement | Verification and negative case |
|---|---|---|
| AC-001 | A static exported catalog provides at least two real compatible English speech configurations with pinned URLs, exact hashes/sizes, source and license records, clear purpose and total payload size. | Verify downloaded bytes against entries and real native initialization/recognition/synthesis; reject placeholder or unsupported advertised configurations. |
| AC-002 | Default downloader still rejects redirects; explicit bounded opt-in follows only valid HTTPS endpoints at original or explicitly allowed exact origins and retains integrity, timeouts and cancellation. | Real TLS redirect success, relative destination, loop/hop limit, unknown origin, HTTP downgrade, malformed/credential destination and delayed-header cancellation tests. |
| AC-003 | Example first launch offers catalog selection and explicit download, progress, cancel and retry with no path/manifest input; Start is unavailable until native initialization succeeds. | Widget/controller tests plus emulator walkthrough; failed download/native creation and cancellation never enable Start. |
| AC-004 | Model data and saved selection use persistent private no-backup Android/iOS storage; subsequent launch restores installed selection without network. | Inspect platform bridge and build; relaunch offline and validate real cache; missing/corrupt saved state remains actionable without hidden download. |
| AC-005 | Switching, backgrounding and disposal safely coordinate active preparation/voice sessions; retries preserve other installed packs and avoid deleting active content. | Negative lifecycle, busy-operation, cancellation, corrupt-cache and late-completion tests. |
| AC-006 | Real catalog preparation feeds unchanged LocalVoiceAgent, and a real speech fixture produces recognition and synthesis with selected configurations; Android example builds and installed emulator reaches ready/start without manual model copying. | Execute real catalog download/native smoke and emulator first-run/relaunch; record iOS build and physical-device evidence separately, never substitute synthetic models. |
| AC-007 | User-facing and developer docs match the delivered choice/download/offline demo and distinguish fixed local reply logic, English support, build prerequisites and remaining device/VITS gates. | Strict format/analyze, root and example tests, wiki lint, package check and independent review; no manual-path requirement or broad model-quality claim remains in example guidance. |
