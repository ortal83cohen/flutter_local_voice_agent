---
id: pipeline-06-continuation
title: Native pipeline continuation and input validation repair
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["native/**", "tool/test_native.py", "lib/**", "test/**"]
summary: Continuation under frozen criteria with reproduced reply validation gaps and current verification evidence.
---

# Continuation

Resume implementation under the existing reviewed plan and unchanged frozen criteria. The checkout was initially clean. A concurrent change to .github/workflows/release.yml appeared during baseline checks and is outside this work; preserve it.

## Research and implementation decision

The native validator at native/src/flva.cpp accepts overlong encodings, surrogate code points and values beyond U+10FFFF. A direct executable using the production function returned the following output for five malformed sequences (overlong two-byte, overlong three-byte, surrogate, above Unicode maximum and illegal four-byte lead):

```text
$ /private/tmp/flva-utf8-before
malformed UTF-8 admitted=1
malformed UTF-8 admitted=1
malformed UTF-8 admitted=1
malformed UTF-8 admitted=1
malformed UTF-8 admitted=1
exit=0
```

The native negative reply tests currently invoke replies after interruption with no awaited reply. They can return zero because of state mismatch regardless of input validation. This is an implementation/test defect within AC-003, AC-004 and AC-006, not a criterion change. Repair the Unicode scalar validator and test malformed and over-limit input during an actual final-transcript generation, followed by a valid reply on that same generation. Add engine-independent exhaustive scalar/boundary regression coverage to the native harness so these checks run in the ordinary suite. Keep the C ABI and limits unchanged.

## Baseline verification

Executed the pinned Flutter 3.47.0 check suite with SDK-cache access after the restricted attempt failed writing engine.stamp and engine.realm. Full baseline output is retained in /private/tmp/flva-baseline-check.log. Selected exact output:

```text
$ PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH sh tool/check.sh
lint_wiki: clean (0 warning(s)).
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Formatted 12 files (0 changed) in 0.03 seconds.
Stage 3 passed: format
Package has 0 warnings.
Stage 6 passed: package dry run
PASS bump patch positive case
PASS occupied pub.dev versions positive and malformed-response negative cases
Stage 7 passed: release helper tests
```

These are excerpts; final integrated evidence is recorded separately. Baseline package warnings from the historical handoff did not recur. This does not establish clean consumer native dependency provisioning or physical device qualification.

## Open scope

VITS upstream allocation, physical mobile qualification, optional LLM quality and clean consumer native provisioning remain open pending direct evidence. Managed setup work item 0004 remains a draft until its asset and distribution prerequisites are resolved. No model redistribution, commit, publication or criterion relaxation is performed.

## Mobile build repair

The current Android example build failed before compilation:

```text
Included build '/Users/ortalcohen/fvm/versions/3.47.0/packages/flutter_tool/gradle' does not exist.
BUILD FAILED in 6s
Gradle task assembleDebug failed with exit code 1
```

Source inspection also found the same singular Flutter SDK directory in both iOS Xcode script references. Restore the actual SDK-owned `packages/flutter_tools` paths in Android settings and the iOS project/scheme. The repository-owned `tool/` directory remains unchanged. This repairs the existing build implementation under AC-005/007; no dependency or API changes are needed. Fresh builds must confirm it.
