---
id: preparation-core-research-review-01
title: "Preparation core research review, round 01"
status: active
owner: preparation-research-review
last_verified: 2026-09-20
applies_to: ["wiki/work/0005-model-preparation-core/00-research.md"]
summary: Independent source verification of preparation research; no implementation or physical qualification verdict.
---

# Research review — round 01

- Work item: 0005-model-preparation-core
- Reviewed artifact: wiki/work/0005-model-preparation-core/00-research.md
- Reviewer: preparation-research-review
- Date: 2026-09-20
- Inputs: research, acceptance criteria, validation rubric, report template, repository instructions and cited primary sources. The work0005 plan, state, author transcript and prior verdicts were not inputs.

## Verdict

**PASS**

The existing offline contracts, manifest trust boundary and SDK primitives support the proposed separate preparation service, while model selection, native packaging, storage policy and device qualification remain explicitly unresolved. This verdict certifies research accuracy and feasibility only; AC-001 through AC-007 still require implementation evidence.

## Verification performed

The reviewer inspected the full existing validator, bundle representation and offline creation path, and the cited SDK documentation. Selected commands and their exact output follow.

```text
$ rg -n 'maxManifestBytes|maxEntries|maxFileBytes|maxTotalBytes|schema.*==|profile.*==|runtime.*==|inputRate.*==|roles.containsAll|licensePaths.isNotEmpty|stat.size ==|digest.toString' lib/src/model_store.dart
12:  static const maxManifestBytes = 64 * 1024;
15:  static const maxEntries = 128;
18:  static const maxFileBytes = 2 * 1024 * 1024 * 1024;
21:  static const maxTotalBytes = 4 * 1024 * 1024 * 1024;
40:      if (await manifest.length() > maxManifestBytes) {
44:      _require(document['schema'] == 1, 'Manifest schema must be 1.');
46:        document['profile'] == 'en-US-sherpa-vits',
50:        document['runtime'] == '1.12.14',
53:      _require(document['inputRate'] == 16000, 'Input rate must be 16000.');
58:            rawFiles.length <= maxEntries,
70:          bytes: _positiveInt(value, 'bytes', maxFileBytes),
81:        _require(total <= maxTotalBytes, 'Total model size exceeds 4 GiB.');
100:        roles.containsAll(required),
107:      _require(licensePaths.isNotEmpty, 'Manifest has no license file entry.');
125:          stat.size == entry.bytes,
130:          digest.toString() == entry.sha256,

$ rg -n 'Future<ValidatedModelBundle> validate|Future<LocalModelBundle> install' lib/src/contracts.dart
6:  Future<ValidatedModelBundle> validate(LocalModelBundle bundle);
9:  Future<LocalModelBundle> install({

$ rg -n 'modelStore.*FileModelStore|native.create' lib/src/agent.dart
35:    final checked = await (modelStore ?? const FileModelStore()).validate(
58:        await native.create(paths: paths, mode: 'halfDuplex'),

$ /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --version
Dart SDK version: 3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "macos_arm64"

$ rg -n 'class HttpClientResponse|connectionTimeout|autoUncompress|followRedirects|void abort|void close\(' /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/lib/_http/http.dart
1301:  Duration? connectionTimeout;
1337:  bool autoUncompress = true;
1722:  void close({bool force = false});
1800:  /// request.followRedirects = false;
1809:  ///     request.followRedirects = false;
1815:  bool followRedirects = true;
1818:  /// when [followRedirects] is `true`. If this number is exceeded
1895:  void abort([Object? exception, StackTrace? stackTrace]);
1915:abstract interface class HttpClientResponse implements Stream<List<int>> {
2029:  /// the [HttpClient.autoUncompress] configuration option, it has been

$ sed -n '230,245p;925,945p' /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/lib/io/file.dart
  /// non-existing parent paths are created first.
  ///
  /// If [exclusive] is `true` and to-be-created file already exists, this
  /// operation completes the future with a [PathExistsException].
  ///
  /// If [exclusive] is `false`, existing files are left untouched by [create].
  /// Calling [create] on an existing file still might fail if there are
  /// restrictive permissions on the file.
  ///
  /// Completes the future with a [FileSystemException] if the operation fails.
  Future<File> create({bool recursive = false, bool exclusive = false});

  /// Synchronously creates the file.
  ///
  /// If [recursive] is `false`, the default, the file is created
  /// only if all directories in its path already exist.
  /// To obtain an exclusive lock on a file, it must be opened for writing.
  ///
  /// If [mode] is [FileLock.exclusive] or [FileLock.shared], an error is
  /// signaled if the lock cannot be obtained. If [mode] is
  /// [FileLock.blockingExclusive] or [FileLock.blockingShared], the
  /// returned [Future] is resolved only when the lock has been obtained.
  ///
  /// *NOTE* file locking does have slight differences in behavior across
  /// platforms:
  ///
  /// On Linux and OS X this uses advisory locks, which have the
  /// surprising semantics that all locks associated with a given file
  /// are removed when *any* file descriptor for that file is closed by
  /// the process. Note that this does not actually lock the file for
  /// access. Also note that advisory locks are on a process
  /// level. This means that several isolates in the same process can
  /// obtain an exclusive lock on the same file.
  ///
  /// On Windows the regions used for lock and unlock needs to match. If that
  /// is not the case unlocking will result in the OS error "The segment is
  /// already unlocked".

$ sed -n '243,259p' /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/lib/io/directory.dart

  String resolveSymbolicLinksSync();

  /// Renames this directory.
  ///
  /// Returns a `Future<Directory>` that completes
  /// with a [Directory] for the renamed directory.
  ///
  /// If [newPath] identifies an existing directory, then the behavior is
  /// platform-specific. On all platforms, the future completes with a
  /// [FileSystemException] if the existing directory is not empty. On POSIX
  /// systems, if [newPath] identifies an existing empty directory then that
  /// directory is deleted before this directory is renamed.
  ///
  /// If [newPath] identifies an existing file or link, the operation
  /// fails and the future completes with a [FileSystemException].
  Future<Directory> rename(String newPath);

$ rg -n 'allocation|physical|AC-004|FAIL' wiki/work/0002-native-offline-pipeline/02-criteria.md
25:| AC-004 | Real pinned Silero, streaming STT and VITS TTS run off UI with bounded response and PCM, deterministic local logic and no runtime network. | Real model smoke and source/build inspection | Missing engine/model, overlong utterance/reply/output, cancelled synthesis |
26:| AC-005 | Android and iOS native bridges provide microphone, playback, permission and foreground lifecycle controls without callbacks waiting on Dart/inference. | Platform builds and physical test matrix | Denial, focus/interruption, route loss, thermal suspension, background |
29:| AC-008 | Offline physical Android and iPhone trials and performance methodology retain raw evidence and all open gates. | Physical qualification report | Network denied, repeated lifecycle/cancel, adverse routes/thermal |
37:Publication, bundled model redistribution, background operation and AEC-qualified full duplex are not claimed. Missing physical resources keep AC-008 open rather than allowing simulated evidence to count.
```

No runtime tests were run: the reviewed artifact is research, and implementation acceptance is not claimed. SDK documentation corroborates that a nonempty competing installation cannot be replaced by ordinary directory rename. Empty destinations have different semantics, and the research's same-filesystem/private-root/no-active-mutation assumptions do not establish power-loss durability or hostile shared-directory safety. Cancellation after headers also needs more than request abort: SDK documentation says abort has no effect after the request's done future completes. The artifact accurately labels these APIs as primitives rather than implemented guarantees.

The reviewer inspected the cited work0004 criteria and state solely as primary evidence of the parent boundary; no parent verdict was used as validation evidence. Work0004 AC-001/002/005/008/009 retain recommended-bundle, path-free setup, storage, packaging and physical requirements beyond this slice. Work0002 inference allocation and physical criteria are unaffected by preparation infrastructure.

## Per-criterion results

Not applicable to this research review. AC-001 through AC-007 were used to assess relevant research coverage, not to certify implementation.

## Findings

### F-001 — Freeze prerequisite wording exceeds the cited criteria

- Severity: NIT
- Location: `wiki/work/0005-model-preparation-core/00-research.md:51`
- Criterion affected: none
- Observation: The research says device evidence is required before work0004 criteria freeze. Work0004 criteria line 18 names asset selection, distribution source, API names and native packaging decisions as freeze prerequisites; physical evidence is an implementation acceptance requirement at AC-009. The cited state retains device qualification as a follow-up, without expressly making the evidence itself a freeze prerequisite.
- Why it matters: This slightly overstates the parent's sequencing; it does not weaken the retained physical gate or invalidate this separate infrastructure slice.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | Research; nonblocking wording accuracy |

No blocker or implementation finding is reported. Disposition remains with the main agent.
