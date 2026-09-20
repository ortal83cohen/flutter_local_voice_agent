# Verification: explicit model preparation core

## Scope and environment

Coordinator checks use Flutter 3.47.0 and its Dart 3.13 SDK at /Users/ortalcohen/fvm/versions/3.47.0. Tests exercise real temporary storage and loopback HTTPS with temporary certificates. Synthetic payloads verify preparation behavior, not inference model quality, physical devices or native consumer packaging.

## Initial implementation checks

Command: `PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH sh tool/check.sh` in the working repository. Exit 65. Output excerpts:

```text
lint_wiki: clean (0 warning(s)).
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Formatted 17 files (0 changed) in 0.07 seconds.
Stage 3 passed: format
No issues found!
No issues found!
Stage 4 passed: analysis
00:04 +55: All tests passed!
PASS ring wrap/overflow/underflow/concurrency
PASS resampler partition DC attenuation upsample reset invalid capacity
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
Stage 5 passed: tests
Package has 1 warning.
```

The package warning is the modified checked-in Git files. Stage 7 was not reached in this root invocation. Existing staged and unstaged changes were preserved. Log: /private/tmp/flva-preparation-full-check.log.

## Initial complete source-snapshot check

Copied the actual current bytes of tracked and nonignored untracked files into /private/tmp/flva-preparation-snapshot-dfarvomj without Git metadata, ignored build output or engine assets. SHA-256 hashes were captured for the copied files. Ran the same seven-stage command there, exit 0. Log: /private/tmp/flva-preparation-snapshot-check.log. Output excerpts:

```text
Package has 0 warnings.
Stage 6 passed: package dry run
PASS bump patch positive case
PASS occupied pub.dev versions positive and malformed-response negative cases
Stage 7 passed: release helper tests
```

All 55 tests also passed in this snapshot. The subsequent source/test/tool byte comparison printed:

```text
Source/test/tool snapshot matches current worktree: 27 files; mismatches=0
```

This isolates package-content validation from the root Git warning. It is not a clean-consumer native build, publication, hosted CI run or physical-device qualification. This initial snapshot precedes independent-review repairs; final repair evidence must be appended below before acceptance.

## Consumer and coordinator smoke evidence

The consumer example was extracted from doc/model-preparation.md into ignored build/preparation_consumer.dart. Command: `/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart analyze build/preparation_consumer.dart lib/flutter_local_voice_agent.dart`, exit 0:

```text
No issues found!
```

A separate real-TLS coordinator script was run with `/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart run build/preparation_smoke.dart`, exit 0:

```text
PASS real TLS installation, FileModelStore validation, ready state, zero-client offline reuse and terminal cancel
```

Logs: /private/tmp/flva-preparation-consumer-check.log and /private/tmp/flva-preparation-coordinator-smoke.log. Scripts and temporary logs are local evidence; the maintained regression suite is test/model_preparation_test.dart.

## Independent review and coordinator repair verification

[Implementation review 01](validation/impl-review-01.md) returned FAIL with two implementation defects. The coordinator accepted both, retained the frozen criteria and routed them to implementation. Out-of-range explicit HTTPS ports now fail admission before root/client effects. The cached FileModelStore filesystem wrapper now maps to preparation storage errors; unchanged metadata/hash failures still map to integrity. A real POSIX unreadable-cache regression protects this internal classification bridge.

The coordinator reran the review's original independent reproduction scripts against repaired source, not just the implementer's tests. Commands:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json /private/tmp/flva_descriptor_review.dart
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json /private/tmp/flva_cache_storage_review.dart
```

Both exited 0. Exact output:

```text
Digest trailing newline accepted: false
port=65536 category=invalidDescriptor rootExists=false clients=0
port=999999999999999999 category=invalidDescriptor rootExists=false clients=0
chmod exit=0
direct read error=13
cache permission failure category=storage clients=0
```

The implementation owner's focused suite now reports `00:04 +23: All tests passed!`; its format and fatal analysis checks are recorded in /private/tmp/flva-preparation-repair.md. The coordinator does not count author verification as an independent verdict.

## Final complete source-snapshot check after repairs

The snapshot procedure was repeated after source stabilization, copying 238 files to /private/tmp/flva-preparation-snapshot-la_kgbh0. Command: `PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH sh tool/check.sh` from that snapshot. Exit 0. Log: /private/tmp/flva-preparation-final-check.log. Actual output excerpts:

```text
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Formatted 17 files (0 changed) in 0.06 seconds.
Stage 3 passed: format
No issues found!
No issues found!
Stage 4 passed: analysis
00:04 +56: All tests passed!
PASS ring wrap/overflow/underflow/concurrency
PASS resampler partition DC attenuation upsample reset invalid capacity
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
Stage 5 passed: tests
Package has 0 warnings.
Stage 6 passed: package dry run
PASS bump patch positive case
PASS occupied pub.dev versions positive and malformed-response negative cases
Stage 7 passed: release helper tests
```

A SHA-256 comparison against the current root source/test/tool files then printed, exit 0:

```text
Final source/test/tool snapshot matches current worktree: 27 files; mismatches=0
```

This final run supersedes the initial run for source validation. It contains 56 total Flutter tests, including 23 preparation tests. Root Git state was not changed to obtain this result. The original root dirty-worktree package warning remains a separate known condition. Native test output here covers support primitives and UTF-8, not real-engine or device reruns.

## Final independent verdict

[Implementation review02](validation/impl-review-02.md) returned PASS for all seven frozen criteria with no findings. The fresh reviewer independently ran the full regression suite, real additional TLS/filesystem negatives, byte-identical snapshot package validation and release helpers. The coordinator accepts that scoped verdict; work0002 and work0004 gates are unchanged. Original FAIL evidence is retained, not overwritten.

## Documentation integration checks

After registering the final review and updating state/product/delivery records, `python3 tool/lint_wiki.py` exited 0:

```text
lint_wiki: clean (0 warning(s)).
```

`git diff HEAD --check` exited 0 with no output. A coordinator local-link/index/SHA-256 check exited 0:

```text
PASS documentation links, work-item index coverage and final source/test/tool snapshot identity
```
