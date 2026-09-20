---
id: preparation-core-01-plan
title: "Plan: explicit model preparation core"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "test/**", "doc/**"]
summary: Explicit verified model preparation infrastructure; default catalog and mobile qualification remain separate.
---

# Plan: explicit model preparation core

## Goal

Provide a working, additive preparation service that downloads an explicitly selected, host-trusted model descriptor into a host-supplied private directory and returns the existing LocalModelBundle. Support observable progress, cancellation, verified offline reuse and safe concurrent activation. This is an infrastructure dependency of draft work item 0004, not completion or relaxation of its default-catalog, path-free UX, device, storage-policy or native-packaging criteria. Work item 0002 remains open and receives no third implementation review.

## Approach

Add preparation contracts in lib/src/model_preparation_models.dart and the implementation in lib/src/model_preparation.dart. Keep FileModelStore and LocalVoiceAgent.create network-free and unchanged. The host must choose a persistent application-private directory and provide immutable trusted metadata; the service does not download a manifest and then trust its hashes. Descriptor validation rejects unsupported roles, profile inconsistencies, unsafe or colliding paths, absent license references, invalid sizes/digests and non-HTTPS URLs before any filesystem or network operation.

Each operation owns its HttpClient and unique staging directory. Stream files sequentially through bounded writes and incremental hashing, enforce expected byte counts before admitting excess data, and validate the complete staged manifest using FileModelStore before activation. Compare cached manifests to the canonical descriptor manifest before revalidating every file so offline reuse cannot accept a self-consistently rewritten manifest. Installed version paths derive from a SHA-256 of the canonical trusted descriptor. Never replace or delete a nonmatching active directory; preserve prior versions.

Concurrent operations use isolated staging and atomic rename to one content-addressed directory. If another operation wins activation, revalidate its complete installation against the descriptor and return it; never remove another operation's files. Duplicate concurrent downloads are permitted and explicitly documented. This design avoids process-scoped POSIX advisory locks and stale lock deletion. Cancel only the owning transfer. Crash-abandoned staging is never reused or treated as active; automatic orphan reclamation is deferred, because a different process may still own it.

## Why this approach

Implementing the complete first-run experience now would require an unqualified default bundle and unresolved native distribution decisions. Extending LocalModelStore with network requirements would break existing implementers and obscure offline inference. A separate explicit preparation API provides useful tested functionality without either shortcut. Immutable fingerprinted activation avoids a mutable current-version index and deletion races. Snapshot progress avoids unbounded queued events for paused listeners. Reject redirects rather than carrying implicit cross-host trust; callers supply the final HTTPS endpoint.

## Steps

1. Consolidate current source, Dart SDK transport and filesystem evidence in research and validate it independently alongside this plan and its criteria.
2. Freeze the public contracts and criteria. Implement descriptor validation, canonical identities, typed failures and preparation progress in the new contracts module, with negative tests.
3. Implement isolated staging, trusted cached verification, sequential HTTPS delivery, cancellation, timeouts and atomic activation in the new manager module. Write real temporary-filesystem and controlled loopback HTTPS tests together with the implementation. Do not modify existing engine, facade or model-store contracts.
4. Export the new API from lib/flutter_local_voice_agent.dart. Run the full Dart checks, the existing offline regression suite and native support tests. Independently verify the implementation against the frozen criteria.
5. Document the consumer API, trust boundary, polling progress, explicit network behavior and all deferred 0004 gates in README, doc/model-preparation.md, capabilities, changelog and a product record. Record full command output and outstanding check limitations.

## Interfaces and shared decisions

ModelDownload pairs an existing immutable ModelFileEntry with a Uri. ModelPackDescriptor carries a stable id, version and an unmodifiable copied list of downloads; the only accepted speech manifest profile/runtime/input rate remain the existing en-US-sherpa-vits, 1.12.14 and 16000. All current required speech roles and listed license files are required; optional llmModel is allowed only when explicitly included. The descriptor contains no automatic default selection, executable code or remote catalog refresh.

ModelPreparationManager is constructed with rootDirectory, an optional HttpClient factory for controlled host trust/proxy configuration, and a positive request/body idle timeout. prepare starts an operation and returns ModelPreparation. That handle exposes result, an immutable latest progress snapshot, and idempotent cancel. Progress reports checking, downloading, verifying, ready, cancelled or failed, plus downloaded and expected total bytes; it is a snapshot, not a buffered stream. Result is the existing LocalModelBundle. The manager owns and closes factory-returned clients, does not construct a client for a valid offline cache hit, and never invokes inference or microphone APIs.

Use a separate ModelPreparationFailure and ModelPreparationErrorCode with invalidDescriptor, network, integrity, storage and cancelled. Malformed metadata fails before side effects. HTTP status other than 200, redirects, transfer errors and timeouts map to network; unexpected lengths/digests and cached metadata/content mismatches map to integrity; filesystem failures map to storage. Cancellation is terminal, reports cancelled and cleans only owned staging before the result settles. A cancellation racing the final atomic rename may leave a fully verified reusable installation, but must never expose partial files or delete a winning installation. Cancellation after a terminal result is a no-op.

URLs must have HTTPS, a host, no user information and no fragment. Disable automatic redirects and decompression; reject content encodings other than identity. Neither diagnostics nor progress include URLs or response bodies. Use a per-operation client and close it forcefully on cancellation to unblock header/body waits; check cancellation before and after disk/hash/verification waits and activation. Network phases have finite positive deadlines. Streaming writes await completion before consuming the next bounded chunk; no readAsBytes, whole-body buffering or queued progress events. Total file count and file/pack bytes cannot exceed FileModelStore limits; manifest serialization must fit its manifest limit. Empty license files follow existing local-store size semantics. Use ASCII relative path components, reject manifest.json case-insensitively, backslashes, empty/dot/traversal segments, absolute paths, case-folded duplicate paths and file/directory prefix collisions. This prevents case-insensitive filesystem aliases and Unicode normalization aliases. Reject links at managed active entries and paths; the host must prevent external mutation of its private storage during operations and active sessions.

## Risks

| Risk | Mitigation | Trigger |
|---|---|---|
| Malicious remote response | Trusted descriptor, HTTPS, no redirects, incremental hash and strict length | Corrupt/truncated/oversized or redirected response |
| Cancellation while waiting | Owned client force-close, raced cancellation checks, terminal cleanup | Delayed headers/body and cancel near activation |
| Concurrent preparation | Unique stages, immutable complete final directory, winner verification | Two managers or isolates preparing the same descriptor |
| Invalid cached data | Canonical manifest comparison and per-file revalidation; fail closed | Tampered manifest or asset, symlink destination |
| Disk exhaustion | Stream writes, report storage failure, remove owned partials, retain installed versions | Failed write or unavailable target root |
| Abandoned staging growth | Never activate partials; document cleanup only when all writers are quiescent | Process termination during staging |
| Host mistakes trust configuration | API documentation explicitly assigns descriptor provenance and private storage to the host | Untrusted metadata or permissive custom client |

## Rollback

Consumers retain the existing fully offline model-store and agent APIs. Stop using the preparation manager without changing stored active bundles. Remove only new source/API exports and documentation if reverting code. Never remove installed versions or unrelated checkout changes as part of rollback. No publication, native/model redistribution or Git mutation is required.

## Out of scope

Default or recommended model selection, model redistribution, path-free app-private directory discovery and backup exclusion, proactive free-space reservation, background or byte-range resume, reuse of partially downloaded files, automatic abandoned-stage deletion, installation removal/updates/active leases, model quality and physical-device qualification, example UI replacement, native dependency distribution and closing VITS allocation limits. These remain explicit work0004/work0002 gates.

## Verification approach

Use real loopback TLS HTTP responses and temporary files for preparation behavior; generate the local test certificate/key at runtime and trust only that certificate in the test client. Synthetic payloads exercise installation mechanics and are never described as speech-model qualification. Test descriptor failures before side effects, valid install and offline zero-request reuse, length/hash/HTTP/redirect/encoding failure, delayed-header/body cancellation and timeout, filesystem error, tampered cache, isolated concurrent callers and retained old versions. Inspect bounded stream handling and execute a multi-chunk response; retain existing offline creation tests. Run formatting, strict analysis, all Flutter tests, native support checks, wiki lint and package dry-run, reporting dirty-tree warnings separately. A fresh strongest-tier implementation validator receives only criteria, artifact and rubric.
