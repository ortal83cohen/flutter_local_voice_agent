# Delivery: explicit model preparation core

## Implemented scope

The public library exports ModelPreparationManager, ModelPackDescriptor, ModelDownload, ModelPreparation, immutable progress snapshots and preparation-specific failure categories. A host explicitly supplies trusted metadata and a private root, then downloads and verifies a complete LocalModelBundle over direct HTTPS. Cached content is checked against the original trusted descriptor and reused without constructing a network client.

The implementation uses per-operation stages, incremental hashing and bounded writes, exact byte/digest validation, finite transport deadlines, cancellation and immutable atomic installation. Concurrent callers can duplicate transfers but preserve complete installations and one another's staging. Existing offline LocalVoiceAgent and LocalModelStore contracts are unchanged.

The [consumer guide](../../../doc/model-preparation.md), [product record](../../product/model-preparation-core.md), [ADR](../../adr/0002-explicit-model-preparation.md), README, capabilities, test prerequisites and changelog accompany the implementation. The [verification record](04-verification.md) contains actual command output, source snapshot boundaries and independent reproduction results.

## Remaining implementation and qualification

| Area | Current state | Next concrete work |
|---|---|---|
| Explicit preparation infrastructure | Implemented and coordinator-tested; final independent verdict is recorded in STATE and the numbered review | Retain real TLS, malformed metadata, permission, cancellation and concurrency regressions |
| Work0004 default model pack | Unresolved asset selection/distribution and device evidence | Pin exact source assets and metadata, establish redistribution notices, then qualify real models |
| Work0004 private storage and first-run UX | Unimplemented | Choose platform storage/backup policy and capacity handling, then integrate a path-free host/example flow |
| Native consumer packaging | Checkout provisioning still required | Supply a reproducible native dependency resolution route and prove fresh Android/iOS consumer builds |
| Work0002 VITS allocation (F3/AC-004) | Open upstream complete-sentence allocation blocker | Implement and measure a genuinely bounded backend; callback cancellation alone cannot satisfy the bound |
| Physical qualification | Open | Run route-specific microphone/playback, interruption, offline, memory and thermal acceptance on physical devices |
| Updates/removal/background resume | Outside this core | Separate policy/design, including active-use protection and aggregate disk handling |

No default pack, native binary distribution, physical-device qualification, release publication or whole-project completion is implied. Existing staged and unstaged work was preserved; the coordinator did not stage, commit or push these changes. Code and accompanying documentation should be included together in a later authorized commit.

## Final acceptance

[Independent review02](validation/impl-review-02.md) reports PASS for AC-001 through AC-007 with no findings. The local scope is delivered and documented; the remaining-work table above still applies.
