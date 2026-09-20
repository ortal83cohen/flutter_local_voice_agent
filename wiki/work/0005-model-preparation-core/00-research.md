---
id: preparation-core-00-research
title: "Research: explicit model preparation core"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "test/**"]
summary: Source-grounded additive preparation design and deliberately unresolved parent requirements.
---

# Research: explicit model preparation core

## Question

Can model delivery be implemented and verified without inventing a qualified default catalog or changing offline inference contracts?

## Answer

Yes, as a separate host-configured infrastructure service. LocalModelBundle already describes prepared files, LocalModelStore exposes only offline operations, and FileModelStore validates the current manifest; the new explicit preparer can return that unchanged type. This slice leaves default selection, private-root discovery, native packaging and physical qualification in work0004 rather than silently satisfying them with test data.

## Findings

### Existing offline boundary

- Claim: the local facade and model-store interface do not require networking and can remain untouched.
- Evidence: lib/src/contracts.dart defines validate and local-copy install; lib/src/agent.dart:19-59 validates and resolves files before native creation.
- Source: lib/src/contracts.dart and lib/src/agent.dart, inspected 2026-09-20.

### Trusted manifest validation already exists

- Claim: downloaded files can use the current manifest schema, but a self-authored cached manifest alone is not sufficient to establish the host's trusted expected hashes.
- Evidence: lib/src/model_store.dart validates schema/profile/runtime/input rate, roles, byte limits and hashes read from that manifest. It does not independently know a remote descriptor. The new service must compare the stored manifest to the canonical host descriptor before calling the existing validator.
- Source: lib/src/model_store.dart:11-137 and lib/src/models.dart:108-149.

### Streaming and cancellation primitives exist

- Claim: the pinned Dart SDK has a streaming HttpClientResponse, client connectionTimeout, autoUncompress control, per-request followRedirects control, request abort and force-close client support.
- Evidence: the installed Dart 3.13 SDK declares these in lib/_http/http.dart:1301,1337,1722,1815,1862,1895; lib/async/stream.dart documents timeout. They are primitives, not proof that the new implementation handles every cancellation race.
- Source: /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/lib/_http/http.dart and lib/async/stream.dart, inspected 2026-09-20.

### Process locks are insufficient for isolate coordination

- Claim: Dart explicitly documents POSIX advisory file locks as process-scoped, permitting multiple isolates to acquire exclusive locks; closing any descriptor for that file can remove the process's locks.
- Evidence: installed SDK lib/io/file.dart:931-941. File.create with exclusive true instead creates a persistent claim that needs a safe crash-recovery policy (same file:232-240).
- Source: /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/lib/io/file.dart.

The chosen design uses unique stages and a content-addressed complete-directory rename. A competing winner is validated, never deleted. Concurrent downloads may duplicate data; there is no aggregate cross-caller disk reservation guarantee. No automatic old-stage sweep or age-based lock deletion is performed. This is a design decision, not an existing guarantee of FileModelStore.install.

### Preparation qualification differs from model qualification

- Claim: draft0004 explicitly requires unresolved default asset, distribution source, API and native packaging decisions before its acceptance criteria freeze; physical-device evidence is a separate implementation acceptance requirement.
- Evidence: wiki/work/0004-managed-model-setup/STATE.yaml and 02-criteria.md:13-18. The core accepts host-supplied descriptors and roots rather than claiming path-free recommended setup.
- Source: draft0004 plan, criteria and state; work0002 existing allocation/physical gates remain unchanged.

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Extend LocalModelStore | Add required downloader methods | Breaks custom stores and obscures offline boundary | Rejected |
| Ship fixture as recommended bundle | Fixed automatic model choice | Lacks model/license/device qualification | Rejected |
| Separate explicit preparer | Trusted descriptor and host-private root, existing bundle result | Host still supplies configuration | Chosen: independently testable prerequisite |
| Process-scoped lock / persistent claim | Serialize filesystem writers | Isolate semantics or stale-claim recovery | Rejected for this slice |
| Unique staging plus immutable activation | Validate one complete winner; retain all old versions | May duplicate downloads and leave crash orphans | Chosen: no mutable active index/deletion race |
| Buffered progress stream | Queue every download event | Paused listener can retain unbounded events | Rejected in favor of a latest immutable snapshot |

## Constraints discovered

One current speech profile is accepted; no new model compatibility assertion follows. HTTPS URLs must be direct, credentials and fragments are disallowed, redirects and decompression are disabled, and response data is bounded by trusted sizes. The host owns trusted metadata, TLS policy of any injected client and private-root access. Same-filesystem staging is required for atomic activation. No process may modify active model files during use.

## Unresolved

- [UNRESOLVED: Which licensed exact default bundle should the parent ship, and with what device quality evidence?]
- [UNRESOLVED: How will the parent select persistent Android/iOS storage, exclude backups and reserve peak free space?]
- [UNRESOLVED: How will native libraries be distributed for clean consumer builds?]
- [UNRESOLVED: Physical mobile setup/offline/restart and network observation remain unexecuted.]
- [UNRESOLVED: Automatic crash-orphan cleanup and active-version removal need a separate lifetime/maintenance design.]

## Sources

All repository and installed SDK sources named above were inspected on 2026-09-20. Research recommendations were considered independently; the consolidated choices reject automatic stage sweeping, instance-only locks, fake network success and identity based only on id/version. Exact file metadata and source URLs participate in the descriptor fingerprint. Implementation and acceptance proof are still pending.
