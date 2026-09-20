---
id: preparation-core-impl-review-01
title: "Implementation review: explicit model preparation core, round 01"
status: active
owner: preparation_impl_review
last_verified: 2026-09-20
applies_to: ["lib/src/model_preparation*.dart", "test/model_preparation_test.dart", "doc/model-preparation.md"]
summary: Blind implementation validation finds descriptor port admission and cached filesystem error classification defects.
---

# Implementation review — round 01

- Work item: 0005-model-preparation-core
- Reviewed artifact: current working-tree preparation implementation, tests, exports, OpenSSL preflight, and associated documentation changes.
- Reviewer: preparation_impl_review, independent delegated validator
- Date: 2026-09-20
- Scope: work0005 only. Existing native/Unicode changes and parent0002/0004 acceptance gates were not re-reviewed. Author reasoning, plan, state, and previous verdicts were not read.

## Verdict

**FAIL**

AC-001 and AC-006 are unmet: out-of-range HTTPS ports reach side effects, and cached filesystem access failures are reported as integrity failures. Existing tests pass but do not cover these negatives.

## Verification performed

All commands below were executed independently using the pinned Flutter 3.47.0 toolchain. TLS checks used temporary loopback servers with generated certificates. No source or repository test was modified.

### Focused TLS acceptance tests

Command:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test test/model_preparation_test.dart --reporter expanded
```

Pasted result excerpt (exit 0):

```text
00:00 +0: descriptor validation copies descriptor records and exposes an unmodifiable list
00:00 +1: descriptor validation rejects malformed descriptors before disk or network effects
00:00 +2: descriptor validation rejects unsafe URL forms and invalid manager timeout
00:00 +3: installs over real TLS then reuses a fully rehashed offline cache
00:00 +4: accepts an explicitly listed empty license file
00:00 +5: response integrity and transport rejects status and does not expose URL or body in failure
00:00 +6: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +7: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +8: response integrity and transport maps a broken response transfer to network
00:01 +9: response integrity and transport maps a throwing client factory to network without leaking details
00:01 +10: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +11: timeouts and cancellation cancel interrupts delayed headers and is idempotent
00:02 +12: timeouts and cancellation cancel interrupts a delayed response body
00:02 +13: timeouts and cancellation cancel before transfer prevents requests and cancel after ready is a no-op
00:02 +14: cache and activation safety tampered manifest, file, and symlink cache fail integrity offline
00:03 +15: cache and activation safety does not replace an occupied invalid final destination
00:03 +16: cache and activation safety rejects and preserves a symlink at the final destination
00:03 +17: cache and activation safety retains old versions and abandoned stages after a failed update
00:03 +18: cache and activation safety exact URL and version metadata participate in the fingerprint
00:03 +19: cache and activation safety file-valued storage root produces typed storage failure
00:03 +20: concurrent callers two managers converge and one cancelled caller cannot delete winner
00:04 +21: concurrent callers cross-isolate callers atomically converge on one valid directory
00:04 +22: All tests passed!
```

### Full regression suite

Command:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test --reporter expanded > /private/tmp/flva-preparation-review-full-tests.log 2>&1
```

Pasted output (exit 0):

```text
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
00:00 +9: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +10: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +11: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +14: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +15: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +16: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +17: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +18: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +19: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +20: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +21: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +22: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +23: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects redirects and nonidentity response encoding
00:00 +24: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired low surrogate logic reply faults and permits the next turn
00:00 +25: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +26: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +27: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +28: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +29: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:01 +30: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
00:01 +31: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
00:01 +32: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
00:01 +33: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
00:01 +34: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +35: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +36: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +37: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport rejects declared, truncated, oversized, and wrong-digest bodies
00:01 +38: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: interrupt keeps polling and admits the next current final
00:01 +39: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: response integrity and transport maps a broken response transfer to network
00:01 +40: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: late poll response after dispose is ignored
00:01 +41: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: late poll response after dispose is ignored
00:01 +42: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:01 +43: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation header and body inactivity have finite network timeouts
00:02 +44: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation cancel interrupts delayed headers and is idempotent
00:02 +45: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation cancel interrupts a delayed response body
00:02 +46: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: timeouts and cancellation cancel before transfer prevents requests and cancel after ready is a no-op
00:02 +47: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety tampered manifest, file, and symlink cache fail integrity offline
00:03 +48: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety does not replace an occupied invalid final destination
00:03 +49: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety rejects and preserves a symlink at the final destination
00:03 +50: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety retains old versions and abandoned stages after a failed update
00:03 +51: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety exact URL and version metadata participate in the fingerprint
00:03 +52: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: cache and activation safety file-valued storage root produces typed storage failure
00:04 +53: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: concurrent callers two managers converge and one cancelled caller cannot delete winner
00:04 +54: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_preparation_test.dart: concurrent callers cross-isolate callers atomically converge on one valid directory
00:04 +55: All tests passed!
```

### Static validation

Command and output (exit 0):

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!

$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).

$ /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib example/lib test/model_preparation_test.dart test/support/preparation_https_server.dart
Formatted 11 files (0 changed) in 0.05 seconds.
```

Wiki lint was executed before this report was written. It establishes the reviewed wiki artifacts' validity, not self-validation of this report.

### Package dry run

Command:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter pub publish --dry-run > /private/tmp/flva-preparation-review-publish.log 2>&1
```

Pasted output excerpt (exit 65):

```text
Total compressed archive size: 104 KB.
Validating package...
Package validation found the following potential issue:
* 15 checked-in files are modified in git.

  Usually you want to publish from a clean git state.

  Consider committing these files or reverting the changes.

The server may enforce additional checks.

Package has 1 warning.
Failed to update packages.
```

This is a dirty-working-tree warning, not evidence of a standalone native consumer installation. A zero-warning dry run was not established in this review; no commit, staging, or publication was performed.

### Independent negative reproduction: out-of-range HTTPS port

The following temporary script was executed as `/private/tmp/flva_descriptor_review.dart`:

```dart
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/src/model_preparation.dart';
import 'package:flutter_local_voice_agent/src/models.dart';

Future<void> main() async {
  print('Digest trailing newline accepted: ${RegExp(r"^[a-f0-9]{64}$").hasMatch('${'a' * 64}\n')}');
  for (final port in [65536, 999999999999999999]) {
    final parent = await Directory.systemTemp.createTemp('flva-review-port-');
    final root = Directory('${parent.path}/models');
    var clients = 0;
    final uri = Uri.parse('https://127.0.0.1:$port/file');
    final files = ['vad', 'encoder', 'decoder', 'joiner', 'asrTokens', 'ttsModel', 'ttsTokens', 'ttsLexicon', 'license'].map((role) => ModelDownload(entry: ModelFileEntry(role: role, path: '$role.bin', bytes: 0, sha256: sha256.convert([]).toString(), source: 'synthetic', license: 'license.bin'), uri: uri)).toList();
    final operation = ModelPreparationManager(rootDirectory: root.path, httpClientFactory: () {clients++; throw StateError('factory invoked');}).prepare(ModelPackDescriptor(id: 'test', version: '1', files: files));
    try {await operation.result;} on ModelPreparationFailure catch (error) {print('port=$port category=${error.code.name} rootExists=${await root.exists()} clients=$clients');}
    await parent.delete(recursive: true);
  }
}
```

Command and pasted output (exit 0):

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json /private/tmp/flva_descriptor_review.dart
Digest trailing newline accepted: false
port=65536 category=network rootExists=true clients=1
port=999999999999999999 category=network rootExists=true clients=1
```

The factory deliberately throws after incrementing its counter, avoiding actual network access. Both malformed endpoints pass descriptor admission, create the root, and construct a client. The digest edge case was rejected and is not a finding.

### Independent negative reproduction: unreadable cached asset

The following temporary script was executed as `/private/tmp/flva_cache_storage_review.dart`:

```dart
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/src/model_preparation.dart';
import 'package:flutter_local_voice_agent/src/models.dart';
import '/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/support/preparation_https_server.dart';

Future<void> main() async {
 final root = await Directory.systemTemp.createTemp('flva-review-permissions-');
 final server = await PreparationHttpsServer.start((request) async { request.response.add([1]); await request.response.close(); });
 File? blocked;
 try {
  final files = ['vad', 'encoder', 'decoder', 'joiner', 'asrTokens', 'ttsModel', 'ttsTokens', 'ttsLexicon', 'license'].map((role) => ModelDownload(entry: ModelFileEntry(role: role, path: '$role.bin', bytes: 1, sha256: sha256.convert([1]).toString(), source: 'synthetic', license: 'license.bin'), uri: server.uri('/$role'))).toList();
  final descriptor = ModelPackDescriptor(id: 'test', version: '1', files: files);
  final installed = await ModelPreparationManager(rootDirectory: root.path, httpClientFactory: server.createClient).prepare(descriptor).result;
  blocked = File('${installed.directory}/vad.bin');
  final chmod = await Process.run('/bin/chmod', ['000', blocked.path]);
  print('chmod exit=${chmod.exitCode}');
  try {await blocked.readAsBytes(); print('unexpected readable');} on FileSystemException catch(error) {print('direct read error=${error.osError?.errorCode}');}
  var clients = 0;
  final operation = ModelPreparationManager(rootDirectory: root.path, httpClientFactory: () {clients++; return server.createClient();}).prepare(descriptor);
  try {await operation.result;} on ModelPreparationFailure catch(error) { print('cache permission failure category=${error.code.name} clients=$clients'); }
 } finally {
  if (blocked != null) await Process.run('/bin/chmod', ['600', blocked.path]);
  await server.close();
  await root.delete(recursive:true);
 }
}
```

Command and pasted output (exit 0):

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json /private/tmp/flva_cache_storage_review.dart
chmod exit=0
direct read error=13
cache permission failure category=integrity clients=0
```

All fixture data and permissions changes stayed in temporary storage. The original payload remains intact; only read permission changes. The script restores permission and removes the temporary installation.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | FAIL | `lib/src/model_preparation_models.dart:63`; `lib/src/model_preparation.dart:187`, `:238`; `test/model_preparation_test.dart:47` | Yes: malformed roles, paths, licenses, limits, digest, URL forms reject before side effects. Independent out-of-range port reproduction incorrectly reaches disk/client side effects (F-001). |
| AC-002 | PASS | `lib/src/model_preparation.dart:499`; `test/model_preparation_test.dart:214`, `:563` | Yes: tampered manifest, asset and cached symlink fail integrity without client construction. Real TLS installation validates through unchanged FileModelStore. |
| AC-003 | PASS | `lib/src/model_preparation.dart:330`, `:382`, `:443`; `test/model_preparation_test.dart:270`, `:335`, `:431` | Yes: non-200, redirect, encoding, truncated/oversized/wrong-hash responses and stalled headers/body reject. Source shows sequential transfer, 64 KiB hash/write slices and finite inactivity timeout; no response aggregation. |
| AC-004 | PASS | `lib/src/model_preparation.dart:105`, `:163`, `:615`; `test/model_preparation_test.dart:461`, `:496`, `:526` | Yes: delayed header/body cancellation, repeated cancellation, cancellation before transfer and after terminal readiness. Latest snapshot replaces one object; terminal progress remains stable. |
| AC-005 | PASS | `lib/src/model_preparation.dart:309`, `:350`; `test/model_preparation_test.dart:622`, `:651`, `:682`, `:790`, `:850` | Yes: invalid file/symlink destination preserved; failed new version leaves prior installation and abandoned stage; cancellation of one concurrent caller preserves survivor; two isolates converge and clean their own stages. Same-filesystem rename cannot replace an already populated winning installation. External mutation is explicitly outside the host-private-root contract. |
| AC-006 | FAIL | `lib/src/model_preparation.dart:539`; `test/model_preparation_test.dart:270`, `:401`, `:759` | Yes: response/factory secrets excluded; file-valued root returns storage; cancellation and transport negatives typed. Independent cached permission-denial reproduction returns integrity although the payload is unchanged (F-002). Full 55-test suite establishes existing source-contract regression coverage. |
| AC-007 | CONDITIONAL | `doc/model-preparation.md:1`, `:42`, `:90`, `:154`; `README.md:43`; `wiki/product/model-preparation-core.md:19`; `wiki/adr/0002-explicit-model-preparation.md:17` | Yes: docs explicitly reject default-catalog, automatic private-storage, native consumer packaging, physical-quality and completed-parent claims. Analyzer, format, wiki lint and full suite pass. Package dry run remains warning-bearing because the checkout is dirty. Published error contract discrepancies are covered by F-001/F-002. |

## Findings

### F-001 — Out-of-range HTTPS ports bypass descriptor admission

- Severity: BLOCKER
- Location: `lib/src/model_preparation.dart:238`
- Criterion affected: AC-001
- Observation: URI validation checks scheme, host, credentials, fragment and encoded length, but admits `https://127.0.0.1:65536/file` and larger ports. The independent reproduction returns `network`, creates the model root and calls the HTTP client factory.
- Why it matters: These endpoints cannot identify a valid TCP port. The criterion requires invalid HTTPS metadata to fail as `invalidDescriptor` before filesystem or network side effects. Hosts instead receive a transport failure after storage/client work.

### F-002 — Cached filesystem read failures are collapsed into integrity failures

- Severity: BLOCKER
- Location: `lib/src/model_preparation.dart:539`
- Criterion affected: AC-006
- Observation: `_verifyBundle` converts every `AgentFailure` from FileModelStore into `integrity`. FileModelStore converts filesystem failures into AgentFailure. Removing read permission from an intact cached model yields OS error 13 on a direct read, but preparation returns `integrity` with no network client construction.
- Why it matters: The public failure contract distinguishes filesystem access failures (`storage`) from bytes that differ from trusted metadata (`integrity`). A valid inaccessible cache is falsely diagnosed as corrupt; callers cannot reliably distinguish these outcomes.

## Recurrence check

- Previous round: none — first implementation round for work0005.
- Recurring findings: none assessed; prior parent-work verdicts were outside this blind review.
- Oscillating: no.

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | Implementation defect |
| F-002 | Implementation defect |
