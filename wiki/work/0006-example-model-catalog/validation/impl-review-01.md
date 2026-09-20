---
id: example-catalog-impl-review-01
title: Example model catalog implementation review 01
status: active
owner: catalog-impl-review
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "doc/**", "tool/**"]
summary: Independent implementation verification of the selectable model catalog and offline example.
---

# Implementation review: selectable example catalog

## Verdict

PASS. AC-001 through AC-007 are met within their explicit scope. No implementation blocker was established. This does not close native binary distribution, physical-device acoustic/performance qualification, iOS runtime qualification, or the upstream VITS allocation gate.

## Verification performed

Review boundary: read the frozen acceptance criteria, implementation, tests, public documentation and verification artifacts. No author plan, research, work-item state, previous verdicts or handoff reasoning was consulted. No product source, Git index or device state was changed. Temporary independent probes were written only under build/ and /private/tmp/. The coordinator retained exclusive emulator control.

### Required repository checks

Ran from the repository root:

```sh
PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH sh tool/check.sh
```

Exact relevant output from /private/tmp/catalog-review-check.log:

```text
lint_wiki: clean (0 warning(s)).
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Formatted 25 files (0 changed) in 0.13 seconds.
Stage 3 passed: format
No issues found!
No issues found!
Stage 4 passed: analysis
00:05 +63: All tests passed!
00:00 +16: All tests passed!
PASS ring wrap/overflow/underflow/concurrency
PASS resampler partition DC attenuation upsample reset invalid capacity
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
Stage 5 passed: tests
```

The command exited 65 at package validation because the shared checkout contains user changes; it was not a complete seven-stage success:

```text
Package validation found the following potential issue:
* 28 checked-in files are modified in git.
Package has 1 warning.
```

No commit, reset, cleanup or index mutation was used. Independently copied the current repository file set returned by git ls-files --cached --others --exclude-standard to /private/tmp/flva-catalog-review-package, compared every copied file by SHA-256, and excluded Git metadata and ignored generated/native binary inputs. The snapshot command emitted:

```text
Byte-identical snapshot verified: 261 repository files; no Git metadata, generated build caches or native binary inputs copied.
```

Ran in that snapshot:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart pub publish --dry-run
```

Exit 0, exact ending from /private/tmp/catalog-review-package.log:

```text
Total compressed archive size: 118 KB.
Validating package...
The server may enforce additional checks.

Package has 0 warnings.
```

Separately ran the seventh-stage commands against the working checkout:

```sh
sh tool/test_bump_patch_version.sh
sh tool/test_occupied_pubdev_versions.sh
```

Both exited 0:

```text
PASS bump patch positive case
PASS occupied pub.dev versions positive and malformed-response negative cases
```

Also ran both suites independently before the aggregate check:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test --reporter expanded
cd example
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test --reporter expanded
```

The respective exact final lines, both exit 0:

```text
00:04 +63: All tests passed!
00:00 +16: All tests passed!
```

Initial sandboxed Flutter invocations encountered engine.stamp/engine.realm cache permissions; authorized escalated invocations above completed. These are environment restrictions, not source failures. Logs: /private/tmp/catalog-review-root-tests.log and /private/tmp/catalog-review-example-tests.log.

### Independent controller negatives

Created a temporary test file importing the actual example controller and storage API, with independently constructed preparation/native/storage doubles. Ran from example/:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test build/catalog-review/independent_controller_test.dart --reporter expanded
```

Exit 0, exact output from /private/tmp/catalog-review-independent.log:

```text
00:00 +0: loading /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/build/catalog-review/independent_controller_test.dart
00:00 +0: independent: native creation failure cannot enable Start or save selection
00:00 +1: independent: network failure does not create a session
00:00 +2: independent: background and close dispose late native completion
00:00 +3: independent: selection persistence failure disposes ready native session
00:00 +4: independent: unknown saved id and busy switching never start hidden download
00:00 +5: All tests passed!
```

Probe setup initially used a wrong temporary test path and then a single-listener fake stream whose never-listened close future could not complete. Both were reviewer-harness errors; the corrected double uses a broadcast stream. No implementation was changed to obtain the result.

### Actual catalog bytes and offline integrity

Independently reran the real catalog verifier against the supplied already-downloaded installations:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart run tool/verify_catalog.dart /private/tmp/flva-catalog-installed
```

Exit 0, exact output from /private/tmp/catalog-review-cache.log:

```text
Prepare en-us-ljs-zipformer-int8: 114444636 bytes
PASS en-us-ljs-zipformer-int8: verified payload, manifest and zero-client offline reuse
Prepare en-us-ljs-zipformer-standard: 383741867 bytes
PASS en-us-ljs-zipformer-standard: verified payload, manifest and zero-client offline reuse
```

This reviewer run verifies existing real installations and zero-client reuse; it does not claim a second fresh network download. The supplied download artifact records the original actual publisher transfers. The catalog inventory comparison tests establish that the exported entries match the sizes, hashes, URLs, role metadata and notices.

An additional Python SHA-256/length pass read every installed file and independently invoked build/native/real_engine_smoke with each installed pack's vad, encoder, decoder, joiner, asrTokens, ttsModel, ttsTokens, ttsLexicon role paths and /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/test_wavs/0.wav. The command used these arguments in that exact order; paths came from /private/tmp/flva-catalog-installed/verification.json. Actual output:

```text
HASH PASS en-us-ljs-zipformer-int8 files=12 bytes=114444636
final   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
reply  hello world
SMOKE EXIT 0
HASH PASS en-us-ljs-zipformer-standard files=12 bytes=383741867
final   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
reply  hello world
SMOKE EXIT 0
```

The executable source requires recognition, an accepted reply, synthesis and rendered playback completion for exit 0. Full native output is retained in /private/tmp/catalog-review-en-us-ljs-zipformer-int8-smoke.log and /private/tmp/catalog-review-en-us-ljs-zipformer-standard-smoke.log. Known upstream VITS lexicon warnings remain qualification limits.

Created a separate actual-cache fixture under /private/tmp/flva-catalog-review-corrupt. Unchanged files were linked read-only by convention; only an independent copy of asr/tokens.txt was changed by one byte. Original installed bytes were not modified. Ran:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart run build/catalog-review-cache-negative.dart
```

The probe calls the real preparation manager with the real compact catalog descriptor and a client factory that throws if invoked. Exit 0:

```text
PASS actual catalog cache with changed byte rejected as integrity; network clients=0
```

### Real native failure cases

Ran build/native/real_engine_failures with the same compact pack role argument ordering and actual WAV fixture used above. Exit 0; exact selected output from /private/tmp/catalog-review-native-negative.log:

```text
PASS missing path rejected
PASS invalid input rate rejected
PASS actual engine create
PASS double start idempotent
PASS interrupt resumes capture while started
PASS old generation reply refused
PASS first real final
PASS 241 scalars refused on awaited generation
PASS malformed UTF-8 refused on awaited generation
PASS empty reply refused on awaited generation
PASS wrong generation refused while awaiting reply
PASS first real reply admitted
PASS first playback drained
PASS second real final after reset
PASS second real reply admitted
PASS second playback drained
PASS capture overflow surfaces error
PASS cancelled generation renders silence
PASS double stop and destroy after active worker
PASSED 19 checks
```

### Mobile artifact inspection

Inspected the settled build logs directly with:

```sh
cat /private/tmp/flva-catalog-android-accepted.log /private/tmp/flva-catalog-ios-accepted.log
```

The coordinator's recorded commands were flutter build apk --debug and flutter build ios --simulator --debug with the pinned SDK. The actual log output includes:

```text
Running Gradle task 'assembleDebug'...                              8.2s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Xcode build done.                                           19.6s
✓ Built build/ios/iphonesimulator/Runner.app
```

The iOS log separately warns about absent Swift Package Manager support; CocoaPods compilation succeeded. This reviewer inspected build evidence rather than independently issuing a second mobile build.

Read the completed mobile verification artifact at ../04-verification.md, parsed the XML evidence listed there using Python xml.etree.ElementTree, and visually inspected /private/tmp/flva-example-catalog-final.png. Extracted state text was:

```text
compact-before-download:
  This model is not installed yet. Download it when ready.
download-progress:
  Downloading verified model files…
  0.6 MB of 114.4 MB
cancelled:
  Model preparation was cancelled. Tap Download and prepare to retry.
retry:
  Downloading verified model files…
  0.6 MB of 114.4 MB
download-status:
  Installed and verified
  Ready. Tap Start and allow microphone access.
started:
  Installed and verified
  running · listening
offline-ready:
  Installed and verified
  Ready. Tap Start and allow microphone access.
offline-listening:
  Installed and verified
  running · listening
```

Each state is backed by /private/tmp/flva-final-STATE.xml, except the first is named /private/tmp/flva-final-compact-before-download.xml. The artifact records explicit compact download, cancel/retry, no manual model copying, disabled Wi-Fi/mobile data, force-stop/relaunch, offline ready/start, and restored network settings. The final screenshot shows the compact selection, 114.4 MB payload, installed verification, fixed-rule disclosure and enabled Start. An earlier /private/tmp/flva-catalog-current.png is visibly from an intermediate UI and was excluded from final acceptance.

This is independent inspection of coordinator-produced emulator evidence, not a claim that the reviewer controlled the emulator. Host WAV inference and the emulator listening state remain separate evidence; neither establishes real microphone/speaker quality.

The final doc/testing.md catalog instructions were also read after the coordinator's documentation-only update. A SHA-256 comparison between the reviewed snapshot and current lib/, example/lib/ and example/test/ Dart files emitted:

```text
Reviewed Dart source/test changes since snapshot: []
```

## Per-criterion results

| Criterion | Verdict | Positive evidence | Negative evidence |
|---|---|---|---|
| AC-001 | PASS | Exported immutable catalog matches the inventory; both actual 12-file packs rehashed to 114444636/383741867 bytes and execute real native recognition/synthesis. Source and license records accompany every model. | Catalog mutation attempts reject; malformed/unsupported descriptor tests reject; a changed actual catalog token byte fails integrity rather than becoming an accepted pack. |
| AC-002 | PASS | Real TLS tests cover explicit relative redirects and 301/302/303/307/308, exact cross-origin opt-in and final integrity. | Default rejection, loops/hop exhaustion, unknown origin, HTTP downgrade, credentials, malformed/invalid-port/fragment targets, corrupt final bytes, delayed-header cancellation and timeout all execute in the 63-test suite. |
| AC-003 | PASS | Widget/controller tests plus inspected final emulator XML show selection, explicit transfer/progress/cancel/retry, native-ready gating and Start. | Independent native creation and network failures never enable Start or save a selection; existing cancellation/low-space tests and actual emulator cancellation remain actionable. No manual path field is present. |
| AC-004 | PASS | Android bridge uses noBackupFilesDir; iOS uses Application Support, sets and verifies backup exclusion; both settled builds succeed. Real pack offline reuse constructs zero clients. Inspected emulator offline restart restores compact and reaches ready/listening. | Corrupt selection, unknown saved id and actual one-byte corrupt-cache tests remain actionable without network. Failed selection persistence disposes the native session and leaves Start disabled. |
| AC-005 | PASS | Controller disposes prior sessions before switching, serializes UI actions with busy state, cancels preparation on background, and confines explicit removal to the chosen id. | Existing switch/cancel/late Start/background tests and independent late native completion after background/close, busy switching and selection-write failure probes pass; other pack retention is checked by real temporary-file storage tests. |
| AC-006 | PASS | Actual catalog bundle outputs feed the existing agent/session API. Independent real host smoke succeeds for both choices; settled Android build and inspected genuine compact first-download/restart evidence reach ready and listening without copying models. iOS simulator build is separately recorded. | Real native failure executable rejects missing models and invalid input rate, rejects stale/malformed/oversized replies and verifies overflow/cancellation. Independent native-creation failure cannot expose Start. |
| AC-007 | PASS | README, catalog/preparation/models/capabilities/testing guidance describe choice/download/offline reuse, English speech, deterministic replies, prerequisites and remaining device/VITS/distribution gates. Required checks succeeded within the declared dirty-checkout/package-snapshot boundary. | UI test excludes manual path input; catalog test excludes an advertised LLM role; malformed-response release helper negatives and strict analysis/lint checks pass. Documentation does not claim physical performance or unrestricted model quality. |

## Findings

None. The dirty-Git package warning is an expected state constraint and is isolated by the byte-identical package snapshot; it is not a product defect. The report does not claim the original dirty-checkout aggregate command completed stages 6–7.

## Recurrence check

No earlier phase verdicts were used. Existing regressions independently exercised descriptor immutability/admission, file collisions, tampered manifests and content, symlink destinations, concurrent activation and cancelled losers, malformed Unicode replies, and lifecycle generations. Additional independent probes covered setup/native/storage failure and late completion. No recurrence was established in this round.

## Routing

No defect routing is required. The main agent owns the workflow transition and any follow-up recording. Pre-existing physical-device, distribution and VITS qualification gates remain outside this work item's accepted scope.
