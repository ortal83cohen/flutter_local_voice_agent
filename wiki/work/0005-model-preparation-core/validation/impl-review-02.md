---
id: preparation-core-impl-review-02
title: "Implementation review round 02: explicit model preparation core"
status: active
owner: preparation-confirmation-validator
last_verified: 2026-09-20
applies_to: ["lib/src/model_preparation*.dart", "test/model_preparation_test.dart", "doc/model-preparation.md"]
summary: Independent blind verification of all seven frozen core criteria with real TLS and filesystem negatives.
---

# Implementation review — round 02

- Work item: 0005-model-preparation-core.
- Reviewed artifact: current working-tree implementation, tests, public export, consumer documentation, product record, ADR0002 and check script.
- Reviewer: independent preparation_confirmation validator.
- Date: 2026-09-20.
- Contract: frozen `02-criteria.md`; repository validation rubric. Author plans, research, state, coordinator reports and previous validation findings were not read.

## Verdict

**PASS**

All seven frozen criteria are met for explicit trusted-descriptor preparation inside a host-protected private root. No implementation blocker was established. The full regression suite, analysis, format, wiki lint and native host checks passed. The package dry run returned zero warnings on byte-identical source files in a snapshot without Git metadata; the original dirty checkout's dry run retained its single Git-state warning. This is not a claim that `tool/check.sh` returned zero in the original checkout.

The result does not qualify a recommended model, native consumer packaging, mobile preparation, microphone behavior, physical speech quality, upstream VITS allocations or the broader managed first-run product. No source, tests, existing wiki artifact or Git state was edited by this reviewer; only this report and temporary verification files were written.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | PASS | `lib/src/model_preparation_models.dart:57` copies records and freezes the list; `lib/src/model_preparation.dart:115` validates before root/client creation; `lib/src/model_preparation.dart:187` validates roles, counts, byte limits, source, digests, URLs and licenses; `lib/src/model_preparation.dart:228` reserves manifest paths and rejects case-folded duplicates; `lib/src/model_preparation.dart:253` rejects prefix collisions; `lib/src/model_preparation.dart:276` enforces canonical manifest limit. | Yes. Suite rejects malformed roles, missing license, unsafe/colliding paths, HTTP/credential/fragment/out-of-range-port URIs and oversized entries. Independent probes additionally reject blank id/source, aggregate manifest overflow and `manifest.json/vad`, with absent storage root and zero constructed clients. |
| AC-002 | PASS | `lib/src/model_preparation.dart:129` verifies cache without entering the downloader; `lib/src/model_preparation.dart:523` checks the exact trusted manifest; `lib/src/model_preparation.dart:541` invokes unchanged `FileModelStore`; `test/model_preparation_test.dart:217` installs over TLS and reuses rehashed cache without a client. | Yes. Cached manifest, asset and symlink tampering fail integrity. Independent equal-length manifest and asset corruption also fail offline, excluding mere length checking as the explanation. |
| AC-003 | PASS | `lib/src/model_preparation.dart:331` awaits each download; `lib/src/model_preparation.dart:388` bounds connection/header waits and rejects redirects/status/encoding; `lib/src/model_preparation.dart:437` incrementally hashes and awaits writes of at most 64 KiB; `lib/src/model_preparation.dart:444` applies body inactivity timeout; `lib/src/model_preparation.dart:491` checks final length and digest. | Yes. Real TLS tests exercise declared-length mismatch, truncated/oversized/wrong-digest bodies, broken transfer, non-200, redirect, gzip and stalled headers/body. Multi-chunk payloads and optional LLM install successfully. No full-body accumulator exists. |
| AC-004 | PASS | `lib/src/model_preparation.dart:105` makes cancellation idempotent and closes the owned client; `lib/src/model_preparation.dart:163` cleans owned staging; `lib/src/model_preparation_models.dart:104` exposes one immutable snapshot; `lib/src/model_preparation.dart:177` settles stable terminal outcomes; `test/model_preparation_test.dart:433` covers timeouts/cancellation. | Yes. Cancellation before requests and during delayed headers/body resolves cancelled; repeated cancel and post-ready/post-cancel calls preserve snapshots. Independent failed-operation cancellation also leaves terminal snapshot identity unchanged. |
| AC-005 | PASS | `lib/src/model_preparation.dart:279` fingerprints descriptor metadata and URLs; `lib/src/model_preparation.dart:316` creates unique staging; `lib/src/model_preparation.dart:347` verifies before atomic rename; `lib/src/model_preparation.dart:351` checks or validates an existing winner; `test/model_preparation_test.dart:832` exercises two managers and cross-isolate concurrency. | Yes. One cancelled caller leaves the survivor valid; isolates converge on one valid directory; occupied file and symlink destinations remain unchanged; failed update preserves prior version and abandoned stage. Cancellation cannot remove activated installation because `_stage` is cleared after rename. |
| AC-006 | PASS | `lib/src/model_preparation_models.dart:6` separates five failure codes; `lib/src/model_preparation.dart:139` maps transport/storage failures without source details; `lib/src/model_preparation.dart:545` retains cached read failure classification; `lib/src/model_preparation.dart:169` preserves the original error when cleanup fails; `lib/src/contracts.dart:4` remains unchanged. | Yes. File-valued root, cached permission failure, throwing client factory, bad response and cancellation are typed. Independent real unwritable-root failure has no client side effect. A real chmod-induced stage cleanup failure preserves the original integrity error. Existing offline contract/model-store regression tests pass and the three old contract files have no diff against HEAD. |
| AC-007 | PASS | `lib/flutter_local_voice_agent.dart:7` exports the API; `doc/model-preparation.md:1` documents explicit host trust and private root; `doc/model-preparation.md:89` documents progress, cancellation, typed errors and inactivity deadlines; `doc/model-preparation.md:154` states private-root obligations and qualification limits; `README.md:43`, `CHANGELOG.md:5`, `doc/testing.md:13`, `doc/capabilities.md:7`, `wiki/product/model-preparation-core.md:21`, and `wiki/adr/0002-explicit-model-preparation.md:15` retain appropriate scope. | Yes. Documentation was checked against prohibited claims: no default/recommended pack, finished0004, physical qualification or complete native consumer installation is asserted. Root/example analysis, all 56 root tests, native host checks, pre-report wiki lint and isolated package dry run passed; original checkout Git warning is disclosed below. |

## Verification performed

### Pinned tools and unchanged contracts

Commands:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --version
git diff --exit-code HEAD -- lib/src/model_store.dart lib/src/models.dart lib/src/contracts.dart
```

Actual output (the diff command printed nothing; its exit code was printed by the wrapper):

```text
Dart SDK version: 3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "macos_arm64"
Existing contract diff exit code: 0
```

### Full repository pipeline

Command, executed with permission for the pinned SDK cache and local TLS listeners:

```sh
env PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin:$PATH sh tool/check.sh
```

Actual output through stage 5:

```text
lint_wiki: clean (0 warning(s)).
Stage 1 passed: wiki lint
Resolving dependencies...
Downloading packages...
  material_color_utilities 0.13.0 (0.13.1 available)
  test_api 0.7.12 (0.7.14 available)
Got dependencies!
2 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Resolving dependencies in `./example`...
Downloading packages...
Got dependencies in `./example`.
Resolving dependencies...
Downloading packages...
  material_color_utilities 0.13.0 (0.13.1 available)
Got dependencies!
1 package has newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Stage 2 passed: dependencies
Formatted 17 files (0 changed) in 0.07 seconds.
Stage 3 passed: format
Analyzing flutter_local_voice_agent...
No issues found!
Analyzing example...
No issues found!
Stage 4 passed: analysis
Resolving dependencies...
Downloading packages...
  material_color_utilities 0.13.0 (0.13.1 available)
  test_api 0.7.12 (0.7.14 available)
Got dependencies!
2 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Resolving dependencies in `./example`...
Downloading packages...
Got dependencies in `./example`.
00:00 +0: loading /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart
00:00 +0: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: descriptor validation copies descriptor records and exposes an unmodifiable list
00:00 +1: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: descriptor validation rejects malformed descriptors before disk or network effects
00:00 +2: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: descriptor validation rejects unsafe URL forms and invalid manager timeout
00:00 +3: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: installs over real TLS then reuses a fully rehashed offline cache
00:00 +4: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: installs over real TLS then reuses a fully rehashed offline cache
00:00 +5: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +6: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +7: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +8: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +9: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +10: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +11: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +14: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: accepts an explicitly listed empty license file
00:00 +15: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_install_test.dart: installs a validated bundle atomically with unchanged hashes
00:00 +16: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_install_test.dart: installs a validated bundle atomically with unchanged hashes
00:00 +17: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_install_test.dart: installs a validated bundle atomically with unchanged hashes
00:00 +18: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_install_test.dart: installs a validated bundle atomically with unchanged hashes
00:00 +19: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +20: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +21: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +22: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +23: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +24: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +25: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +26: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +27: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +28: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +29: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +30: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +31: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +32: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:01 +33: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:01 +34: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:01 +35: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
00:01 +36: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: interrupt keeps polling and admits the next current final
00:01 +37: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +38: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +39: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +41: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport maps a broken response transfer to network
00:01 +42: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport maps a throwing client factory to network without leaking details
00:01 +43: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +44: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation cancel interrupts delayed headers and is idempotent
00:02 +45: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation cancel interrupts a delayed response body
00:02 +46: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation cancel before transfer prevents requests and cancel after ready is a no-op
00:02 +47: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety tampered manifest, file, and symlink cache fail integrity offline
00:03 +48: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety does not replace an occupied invalid final destination
00:03 +49: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety rejects and preserves a symlink at the final destination
00:03 +50: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety retains old versions and abandoned stages after a failed update
00:03 +51: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety exact URL and version metadata participate in the fingerprint
00:04 +52: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety file-valued storage root produces typed storage failure
00:04 +53: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety cached asset read permission failure remains typed storage
00:04 +54: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: concurrent callers two managers converge and one cancelled caller cannot delete winner
00:04 +55: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: concurrent callers cross-isolate callers atomically converge on one valid directory
00:04 +56: All tests passed!
No example/test directory; skipping example tests
$ clang++ -std=c++17 -g -pthread -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/include -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/tests/spsc_ring_test.cpp -o /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/build/native/ring
exit=0
$ /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/build/native/ring
exit=0
PASS ring wrap/overflow/underflow/concurrency
$ clang++ -std=c++17 -g -pthread -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/include -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/tests/resampler_test.cpp -o /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/build/native/resampler
exit=0
$ /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/build/native/resampler
high-frequency rms=0.000070
PASS resampler partition DC attenuation upsample reset invalid capacity
exit=0
$ clang++ -std=c++17 -g -pthread -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/include -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/tests/utf8_test.cpp -o /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/build/native/utf8
exit=0
$ /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/build/native/utf8
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
exit=0
Stage 5 passed: tests
```

The original command exited 65 at the package dry run. Its only validation warning was the dirty checkout; stage 7 was therefore run separately. Actual package warning output:

```text
Package validation found the following potential issue:
* 15 checked-in files are modified in git.
  
  Usually you want to publish from a clean git state.
  
  Consider committing these files or reverting the changes.
  
  Modified files:
  
  CHANGELOG.md
  LICENSE
  README.md
  doc/capabilities.md
  doc/model-preparation.md
  doc/testing.md
  example/android/settings.gradle.kts
  example/ios/Runner.xcodeproj/project.pbxproj
  example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme
  lib/flutter_local_voice_agent.dart
  ...
  
  Run `git status` for more information.
  
The server may enforce additional checks.

Package has 1 warning.
```

### Independent negative probes

Reviewer-authored temporary Dart programs imported the current preparation implementation, unchanged model store and existing real TLS server fixture. They used real temporary directories, chmod permissions, generated loopback certificates and actual streamed HTTP responses. They did not alter repository tests or substitute a mocked transport.

Commands:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json build/review02/independent.dart
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json build/review02/cleanup.dart
```

Both commands exited 0. Actual output:

```text
PASS blank id: invalidDescriptor; no disk/network side effects
PASS blank source: invalidDescriptor; no disk/network side effects
PASS aggregate manifest size: invalidDescriptor; no disk/network side effects
PASS reserved manifest directory: invalidDescriptor; no disk/network side effects
PASS unwritable root: storage; no network client
PASS independent TLS installation accepted by unchanged FileModelStore
PASS equal-length manifest tamper: integrity; no network client
PASS equal-length asset tamper: integrity; no network client
PASS failed terminal snapshots remain stable after cancel
PASS real cleanup permission failure preserves original integrity outcome
```

The cleanup probe deliberately removed write permission from its temporary root after the TLS request arrived, returned a same-length corrupt response, verified the integrity outcome and retained stage, then restored permission and removed its temporary data. This establishes original-outcome preservation when stage deletion actually fails.

### Isolated package dry run and remaining helper stage

A temporary source snapshot was produced from `git ls-files --cached --others --exclude-standard -z`, copying each existing file without Git metadata and comparing SHA-256 for every source/target pair. Actual copy output:

```text
Copied and SHA-256 compared 238 source files; all byte-identical.
Snapshot: /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review02-package-e1cho5kp
Git metadata exists: False
```

The snapshot excluded untracked empty directories present in the live package inventory (`swiftpm/configuration` and `native/third_party`); these contain no source-file bytes. The package file contents are the same inspected sources. No commit, staging, Git cleanup or source repair was performed to obtain this result.

Command from that snapshot directory:

```sh
env PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin:$PATH dart pub publish --dry-run
```

Exit code 0. Actual final output:

```text
Total compressed archive size: 103 KB.
Validating package...
The server may enforce additional checks.

Package has 0 warnings.
```

Commands from the original repository:

```sh
sh tool/test_bump_patch_version.sh
sh tool/test_occupied_pubdev_versions.sh
```

Exit code 0 for both. Actual output:

```text
PASS bump patch positive case
PASS occupied pub.dev versions positive and malformed-response negative cases
```

## Findings

None within the frozen scope. The original package warning describes the concurrent dirty working tree and is recorded as a verification boundary, not an implementation defect or a clean-checkout claim.

## Recurrence check

- Previous round exists at `validation/impl-review-01.md`, but its contents were deliberately excluded to preserve blind review.
- Recurrence and oscillation comparison: not assessed by this validator; no current finding was established.

## Routing

No findings to route. This report makes no disposition of parent-work-item gates or authorization to commit/publish. The main agent owns registration of this new report in the wiki index and subsequent workflow state updates. Wiki lint above ran before this report was created.
