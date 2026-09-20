---
id: adr-0002-explicit-model-preparation
title: Separate explicit preparation from offline inference
status: active
owner: root
last_verified: 2026-09-20
applies_to: ["lib/src/model_preparation*.dart", "lib/src/contracts.dart"]
summary: Host-trusted descriptors and immutable staged installation preserve existing offline contracts.
---

# Separate explicit preparation from offline inference

## Context

The local store validates files but does not retrieve them. The planned managed first-run product also requires a recommended qualified bundle, native distribution and platform storage policies that remain unresolved. Extending LocalModelStore with networking would break existing implementers and obscure the existing offline create contract.

## Decision

Add a separate explicit service that accepts a host-trusted descriptor and host-private root and returns LocalModelBundle. Keep existing offline contracts unchanged. Downloads are sequential HTTPS with exact hash/length verification, independent cancellation and latest-snapshot progress. Validate cached metadata against the trusted descriptor before rehashing. Never trust a downloaded manifest as its own integrity authority.

Activate a complete validated stage through an atomic same-filesystem rename into a content-addressed directory. Each caller owns a unique stage. Concurrent callers may duplicate downloads; validate any winning complete installation instead of replacing it. Never sweep another caller's stage or remove installed versions. This avoids process-scoped advisory-lock semantics and stale lock deletion. Do not claim global disk limits, power-loss durability or active-version cleanup.

## Alternatives

- A required downloader method on LocalModelStore would break existing stores and couple inference to delivery.
- A default fixture bundle would conflate transport correctness with unresolved model/license/device qualification.
- A mutable current-version index would introduce update and lifetime coordination not needed to return an immutable bundle.
- Advisory locks do not enforce exclusivity across Dart isolates on POSIX. Persistent claims need a separate safe stale-owner protocol.
- Queued progress streams can grow under a paused listener; a snapshot has constant retained state.

## Consequences

The core is directly usable by configured hosts but is not the path-free managed setup product. Root selection and backup policy remain the host's responsibility. Old versions and crash stages can consume disk until a quiescent host maintenance phase reclaims them. Default model selection, example integration, native distribution and physical qualification remain separate work.
