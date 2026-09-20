---
id: pipeline-managed-setup-continuation
title: Managed setup continuation audit
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["**"]
summary: Source inspection and explicitly unresolved continuation gates.
---

# Managed model setup implementation audit

## Existing

- The public runtime is still local and offline. `LocalVoiceAgent.create` accepts a `LocalModelBundle`, validates it through the existing `LocalModelStore`, resolves real paths, and creates the native half-duplex session; it rejects the unqualified full-duplex mode before setup (`lib/src/agent.dart:19-59`). This is the correct boundary to preserve.
- `LocalModelBundle` is only a directory plus manifest path, and `ValidatedModelBundle` contains checked manifest entries (`lib/src/models.dart:108-160`). The public barrel exports the current agent, contracts, store, and models without any managed-preparation API (`lib/flutter_local_voice_agent.dart:1-7`).
- `FileModelStore.validate` already enforces a 64 KiB manifest cap, entry and aggregate size limits, a fixed `en-US-sherpa-vits` / runtime `1.12.14` profile, required roles, safe relative paths, listed license references, regular files, exact lengths, and SHA-256 hashes (`lib/src/model_store.dart:9-145`, `lib/src/model_store.dart:202-237`). This should remain the final compatibility/integrity validator for a prepared bundle.
- `FileModelStore.install` already validates a local source, copies it to a same-root staging directory, validates again, atomically renames the stage to a fresh directory, and deletes the stage on failure (`lib/src/model_store.dart:147-191`). Its tests prove atomic local copying, corrupt-source rejection, and retention of earlier installs (`test/model_install_test.dart:8-68`, `test/model_install_test.dart:137-157`).
- The example deliberately exposes a target-device directory field, constructs `manifest.json`, creates the agent, and only then enables Start/Interrupt/Stop (`example/lib/main.dart:30-100`, `example/lib/main.dart:123-183`). Its reply logic is deterministic and does not require an LLM (`example/lib/main.dart:69-75`).
- Repository documentation accurately labels managed setup as planned, preserves explicit user initiation, offline reuse/inference, optional LLM separation, and the current local-pack route (`wiki/product/managed-model-setup.md:13-43`; `README.md:35-40`; `doc/models.md:7-12`).

## Missing

- No managed-preparation symbols, descriptor/catalog types, preparation state stream, cancellation abstraction, transport, installation index, removal API, or managed tests exist under `lib/`, `test/`, or `example/lib/`. The root package has only `flutter` and `crypto` runtime dependencies; it has neither an HTTP client package nor an application-directory provider (`pubspec.yaml:10-14`).
- The current local installer cannot download, expose byte progress, cancel between chunks, reuse a catalog version by identity, serialize duplicate callers, recover a durable active-version pointer after process restart, check free/peak disk space, or remove versions. Its timestamp directory names carry no stable bundle identity/version (`lib/src/model_store.dart:147-191`).
- The manifest is validated only after it is read from local storage. A managed implementation therefore needs a separately trusted, package-shipped descriptor containing expected file roles, lengths, hashes, provenance, notices, profile/runtime compatibility, and URLs; accepting equivalent metadata from the downloaded manifest would not establish authenticity. The work item explicitly leaves exact assets, revisions, rights, notices, host, sizes, API names, and packaging unresolved (`wiki/work/0004-managed-model-setup/00-research.md:41-50`).
- Agent lifetime is not connected to installation lifetime. `LocalVoiceAgent.create` receives only paths and `dispose` releases native resources without notifying a model manager (`lib/src/agent.dart:19-83`, `lib/src/agent.dart:226-230`). Safe removal cannot be implemented by inference from paths. The initial slice should retain immutable installed versions and provide no deletion, rather than introduce an unreviewed lease interface.
- Stable failures cover local assets, profile, audio, lifecycle, capacity, inference, and shutdown, but there are no distinct preparation cancellation, network, storage, or installation-recovery codes (`lib/src/models.dart:75-106`). Typed preparation failures require an explicit interface decision instead of mapping every failure to `invalidAsset` or `inferenceFailed`.
- Persistent app-private root selection and backup policy are missing. Tests use `Directory.systemTemp`, while production code requires callers to provide `targetRoot` (`test/model_install_test.dart:13-21`; `lib/src/contracts.dart:8-12`). Large re-downloadable assets also need a reviewed Android no-backup / iOS backup-exclusion policy, which the plan already flags (`wiki/work/0004-managed-model-setup/01-plan.md:31-34`).
- Release networking is not configured in the example's main Android manifest; INTERNET appears only in debug/profile manifests for Flutter tooling (`example/android/app/src/main/AndroidManifest.xml:1-45`; `example/android/app/src/debug/AndroidManifest.xml:1-7`; `example/android/app/src/profile/AndroidManifest.xml:1-7`). Whether the package or host declares release permission must be decided and documented.
- Native engine packaging remains a separate blocker: Android aborts configuration unless pinned libraries were manually provisioned, and iOS references vendored frameworks (`android/src/main/cpp/CMakeLists.txt:3-15`; `ios/flutter_local_voice_agent.podspec:16-26`). Managed weights cannot repair missing native engines.
- The existing implementation work remains FAIL because VITS whole-sentence allocation and physical-device/mobile qualification are open (`wiki/work/0002-native-offline-pipeline/STATE.yaml:4-17`). Managed installation must not imply those gates are closed.

## Dependencies/decisions

1. **Workflow gate:** work item 0004 is still `phase: plan`, `verdict: CONDITIONAL`; its criteria say they are not frozen and may freeze only after asset, distribution, API-name, and native-packaging decisions (`wiki/work/0004-managed-model-setup/STATE.yaml:1-15`; `wiki/work/0004-managed-model-setup/02-criteria.md:13-18`). Record and review those decisions before source implementation.
2. **Exact trusted descriptor:** select one speech-only bundle compatible with the fixed `en-US-sherpa-vits` / sherpa 1.12.14 loader. Record immutable URLs/revisions, per-file hashes and lengths, notices and redistribution permission, exact compressed/download and installed totals, and vocabulary limits. Do not include or require GGUF. Do not redistribute weights until permission is verified.
3. **Public contract:** settle names and ownership for the descriptor, preparation service, progress snapshot, cancellation, result, and failure codes. Keep `LocalModelStore` unchanged so current implementers compile. Managed preparation returns the existing `LocalModelBundle`; `LocalVoiceAgent.create` remains network-free.
4. **Storage boundary:** choose either a small platform storage bridge or a reviewed directory-provider dependency. It must return persistent app-private storage, apply the backup policy, and support atomic rename within one filesystem. Do not make an evictable cache the only installed copy.
5. **Transport boundary:** prefer an internal/injectable foreground streaming transport with HTTPS-only production URLs, response status/content-length handling, bounded chunks, cancellation between writes, and deterministic test doubles. Decide whether to use `dart:io` `HttpClient` or add a package dependency. No background session and no byte-range resume belong in version one.
6. **Installation record:** define a versioned on-disk index and crash-recovery rules before coding. The authoritative ready state must be reconstructed from the trusted descriptor plus a fully validated immutable directory, never solely from a mutable index flag.
7. **Concurrency:** serialize preparation by stable bundle ID/version in-process. Cross-process locking is unnecessary unless multiple Flutter engines/processes are declared supported; the current README says to use one agent per Flutter engine (`README.md:77-81`).
8. **Network declaration:** decide whether Android INTERNET is merged from the plugin or declared by consumers using managed preparation. Keep network access explicit in UI even if the permission itself is install-time. iOS should remain HTTPS/ATS compliant without broad exceptions.
9. **Native packaging:** track clean consumer engine packaging separately from the model preparation slice. It is required for final AC-008 and the simple first-use promise, but it should not be coupled into download/storage code (`wiki/work/0004-managed-model-setup/01-plan.md:36-37`).

## Recommended implementation slice

After the decisions above are reviewed and draft criteria are frozen, implement one bounded, additive slice: **explicit foreground preparation and offline reuse of one compile-time trusted speech descriptor, without update or removal**.

The slice should add a preparation service and immutable descriptor/state/failure types in new `lib/src/` modules, export them additively, and leave `LocalModelStore`, `LocalVoiceAgent.create`, native inference, and conversation mode unchanged. The production constructor should obtain an app-private persistent root through the chosen storage boundary; tests should inject a temporary root and controlled streaming transport. A caller explicitly starts preparation and can cancel it. Progress reports checking, downloading with known/unknown totals, verifying, ready, cancelled, and failed. A verified installed version returns immediately with zero transport calls.

Installation should download each descriptor-listed file directly into a version-specific hidden stage using bounded writes, verify its length and hash against the package-shipped descriptor, write a manifest derived from that descriptor, run `FileModelStore.validate`, and atomically rename within the same root. Duplicate concurrent calls for the same ID/version share one operation. Cancellation, truncation, hash mismatch, HTTP failure, and process-left staging never publish ready state; a later call removes stale staging and retries. The prior immutable ready directory is never changed. This avoids the current `FileModelStore.install` double-copy and peak-disk penalty while reusing its validator.

Do not include automatic catalog refresh, implicit update, deletion, active-bundle leasing, background transfer, partial-file resume, device ranking, LLM setup, example replacement, or native-engine packaging in this first code slice. Keeping all successful versions avoids unsafe removal until a separately reviewed agent lease contract exists. Keeping the example unchanged until the real descriptor is qualified avoids presenting synthetic fixtures or unauthorized weights as the recommended user journey.

Minimum focused verification for the slice:

- Descriptor rejection: missing notices/roles, duplicate or unsafe paths, wrong profile/runtime, invalid URL scheme, invalid lengths/hashes.
- First prepare and second-launch reuse with an assertion of zero transport calls on reuse.
- Bounded streamed write with exact progress, cancellation, retry, truncated/corrupt response, unknown content length, and storage-write failure.
- Two concurrent callers receive one result from one transfer.
- Crash artifacts/stale staging do not become ready; a valid prior version survives every failure.
- Existing local validation, local install, agent, lifecycle, strict analysis, formatting, and wiki checks continue to pass.

Once the exact descriptor has redistribution approval and real-device evidence, a second slice can replace the example's path field with the recommended bundle card and add release networking. A later reviewed slice can add updates/removal plus explicit leases. Native build packaging and physical qualification remain independent exit gates.

## Evidence

- Planning truth: `wiki/work/0004-managed-model-setup/STATE.yaml:1-28`; `wiki/work/0004-managed-model-setup/02-criteria.md:13-41`; `wiki/work/0004-managed-model-setup/03-tasks.md:13-32`.
- Proposed boundaries: `wiki/work/0004-managed-model-setup/01-plan.md:15-43`, `wiki/work/0004-managed-model-setup/01-plan.md:56-66`; `wiki/product/managed-model-setup.md:21-47`.
- Current API and validator: `lib/src/contracts.dart:3-13`; `lib/src/models.dart:75-179`; `lib/src/model_store.dart:9-191`; `lib/src/agent.dart:15-83`.
- Current example: `example/lib/main.dart:30-102`, `example/lib/main.dart:123-183`.
- Existing negative/local-install tests: `test/model_store_test.dart:9-111`; `test/model_install_test.dart:8-157`.
- Native and qualification boundaries: `android/src/main/cpp/CMakeLists.txt:3-23`; `ios/flutter_local_voice_agent.podspec:12-26`; `wiki/work/0002-native-offline-pipeline/STATE.yaml:4-17`.
- Dependency and platform configuration: `pubspec.yaml:6-18`; `example/android/app/src/main/AndroidManifest.xml:1-45`; `example/android/app/src/debug/AndroidManifest.xml:1-7`; `example/ios/Runner/Info.plist:4-70`.

No validation suite was run because this was a read-only source audit and made no repository changes. The only workspace-state check was `git status --short`; exact output:

```text
 M .github/workflows/release.yml
```

That pre-existing unrelated modification was not touched.
