---
id: preparation-core-02-criteria
title: "Criteria: explicit model preparation core"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "test/**", "doc/**"]
summary: Explicit verified model preparation infrastructure; default catalog and mobile qualification remain separate.
---

# Acceptance criteria: explicit model preparation core

## Frozen

- Frozen at: 2026-09-20
- Frozen by: root after research/plan review round 01

## Criteria

| ID | Criterion | How checked | Negative case |
|---|---|---|---|
| AC-001 | Host-supplied descriptor is immutable and validates all required/allowed roles, licenses, sizes, hashes, safe unique noncolliding paths and HTTPS URLs before any disk/network side effects; manifest limits match FileModelStore. | Descriptor and side-effect tests | Invalid roles, missing license, traversal/backslash/prefix collision, invalid URI/digest/limits |
| AC-002 | Explicit preparation downloads and returns an ordinary LocalModelBundle accepted by unchanged FileModelStore; valid cached content is rehashed against trusted descriptor metadata and reused without constructing a network client. | Real TLS install and offline cache tests; existing offline tests | Tampered stored manifest or asset fails integrity, no remote metadata trusted |
| AC-003 | Delivery streams sequentially through bounded writes/hashing, enforces exact expected byte lengths and digests, rejects non-200 responses, redirects and nonidentity encodings, and has finite header/body deadlines. | Multi-chunk TLS tests and source inspection | Truncated, oversized, wrong digest, redirect, status failure, stalled response |
| AC-004 | Cancellation is idempotent, interrupts delayed network headers/body, resolves as typed cancelled, and removes only owned staging; progress snapshots have bounded storage and stable terminal states. | Controlled stalled transfer tests, snapshot checks | Cancellation before transfer, during body, repeated cancel and cancel after completion |
| AC-005 | Complete verified staging is atomically activated at a descriptor-fingerprint directory; concurrent callers safely converge on valid installed content, cancellation cannot delete another caller's installation, and prior versions survive failures. | Two-manager and cross-isolate filesystem/TLS cases | Failed update, one caller cancelled, abandoned staging and occupied invalid/symlink destination |
| AC-006 | Public failures distinguish invalidDescriptor, network, integrity, storage and cancelled without logging response bodies or source URLs; cleanup preserves original outcome and existing offline public contracts remain source-compatible. | Compile/API tests and filesystem/transport negatives | Unwritable or file-valued storage root, client failure, corrupt response and no microphone/network work on old paths |
| AC-007 | Exports, API documentation, README, changelog and wiki accurately explain explicit networking, host trust/private storage, progress/cancellation and deferred model/native/device gates. | Analysis, docs review, wiki lint, full regression suite and package dry run | No recommended bundle, physical quality, native consumer packaging or finished0004 claims |

## Non-functional criteria

Per-operation limits are FileModelStore's manifest size, file count and per-file/total bytes. One active file download per operation; no full-response buffer or progress event backlog. Multiple callers may duplicate transfer bytes but may not corrupt or replace installed content. Controlled transport tests do not qualify inference models.

## Explicitly not required

The out-of-scope items in the plan remain unimplemented requirements of the parent initiatives. This work does not revise their frozen criteria or close their FAIL/qualification gates.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
