---
id: product-model-preparation-core
title: Explicit model preparation core
status: active
owner: root
last_verified: 2026-09-20
applies_to: ["lib/src/model_preparation*.dart", "doc/model-preparation.md"]
summary: Host-configured preparation prerequisite with explicit networking and separate parent qualification gates.
---

# Explicit model preparation core

Work item 0005 implements a separate preparation service: a host supplies an immutable trusted descriptor and private root, explicitly starts HTTPS preparation, observes a latest progress snapshot and receives the existing LocalModelBundle. FileModelStore and LocalVoiceAgent.create remain offline. Source implementation and acceptance evidence are recorded in the work item; this record does not certify physical model quality. Work0006 adds a separate pinned English catalog and example integration.

The service validates trusted metadata before side effects, hashes streamed downloads, revalidates staged files and activates an immutable descriptor-fingerprint directory. A verified installation is reusable without constructing a network client. Each caller owns its transfer and stage, so concurrent preparation may duplicate bytes but cannot delete another caller's installation. Invalid existing content fails closed. Automatic stage sweeping, removal and updates are absent.

The [consumer guide](../../doc/model-preparation.md) defines API, trust, cancellation, errors and storage obligations. The [architecture decision](../adr/0002-explicit-model-preparation.md) records the chosen boundaries.

## Parent gates retained

Work0004 remains a broader draft: a general library private-storage API, native consumer dependency resolution and real physical mobile first-run/offline quality tests. Work0006 implements the narrower example catalog/private-storage/download journey with an advisory capacity check. No parent criterion is closed merely because synthetic HTTPS installer tests pass. Work0002's VITS upstream allocation and physical qualification gates remain unchanged.
