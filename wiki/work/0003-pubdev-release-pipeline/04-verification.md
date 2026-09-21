# Verification: Pub.dev release pipeline

Commands ran on 2026-09-21. Flutter and Dart are `/Users/ortalcohen/fvm/versions/3.47.0`. A dirty working tree can make `dart pub publish --dry-run` exit 65. AC-006 was proven on a Git-free snapshot, not on that dirty checkout.

## Git-free snapshot

Snapshot `/private/tmp/flva-verify-snapshot-0003` was copied from `git ls-files --cached --others --exclude-standard` with no `.git` metadata. File count 389. `SNAP_NO_GIT:1`.

```text
$ sh tool/check.sh
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Stage 3 passed: format
Stage 4 passed: analysis
00:05 +73: All tests passed!
Stage 5 passed: tests
Package has 0 warnings and 1 hint.
Stage 6 passed: package dry run
PASS bump patch positive case
PASS missing pubspec
PASS missing changelog
PASS malformed package version
PASS malformed occupied version
PASS duplicate changelog version
PASS occupied candidate skipped
PASS occupied pub.dev versions positive and malformed-response negative cases
Stage 7 passed: release helper tests
CHECK_EXIT:0
```

The dry-run hint is that published 0.1.2 is newer than this checkout's 0.1.1. Stage 6 still passed.

The dry-run payload listing included plugin and example sources. It did not list `wiki/`, `tool/`, `.github/`, package `test/`, or `native/tests/`. `.pubignore` excludes those repository-only paths.

## Per-criterion results

| ID | Result | Evidence | Negative case |
|---|---|---|---|
| AC-001 | met on snapshot | `tool/check.sh` stages 1–7 exited 0. | A formatting error would fail stage 3. |
| AC-002 | met | Stage 7 passed the patch helper positive case and missing-pubspec, missing-changelog, malformed-version, and duplicate-changelog negatives. | Those fixture failures are in the paste above. |
| AC-003 | met | Stage 7 passed occupied-candidate skip and malformed-response negatives. | Occupancy fixture failures are in the paste above. |
| AC-004 | met by source review | `.github/workflows` release path requires `RELEASE_GITHUB_TOKEN`, runs checks before mutation, and pushes an annotated `vMAJOR.MINOR.PATCH` tag. Hosted GitHub execution remains [UNVERIFIED]. | Explicitly not required before push. |
| AC-005 | met by source review | Publish workflow requests OIDC, resolves public dependencies before token setup, dry-runs, and publishes on a matching semantic tag. Hosted publication remains [UNVERIFIED]. | A non-semantic tag is not the publish trigger. |
| AC-006 | met on snapshot | Snapshot dry-run passed. Payload omitted wiki, tests, tools, CI, caches, lockfiles and native test assets. | Those repository-only paths are in `.pubignore`. |
| AC-007 | met by review | Workflows and helpers do not store or print credentials, model assets, or personal data. | Token literals were not found in the reviewed pipeline files. |

## Explicitly not claimed

- Successful GitHub Actions execution before a push.
- Successful pub.dev publication.
- Dirty-checkout dry-run exit 0.

## Next

One implementation review at `validation/impl-review-01.md`.
