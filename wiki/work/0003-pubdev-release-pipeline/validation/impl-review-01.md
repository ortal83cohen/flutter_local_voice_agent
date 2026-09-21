# Implementation review — round 01

- Work item: 0003-pubdev-release-pipeline
- Reviewed artifact: current working tree — `tool/check.sh`, `tool/bump_patch_version.sh`, `tool/occupied_pubdev_versions.py`, `tool/test_bump_patch_version.sh`, `tool/test_occupied_pubdev_versions.sh`, `.pubignore`, `.github/workflows/checks.yml`, `.github/workflows/release.yml`, `.github/workflows/publish.yml`, `pubspec.yaml`, `CHANGELOG.md`
- Reviewer: impl-review-0003
- Date: 2026-09-21

## Verdict

**PASS**

Every frozen criterion AC-001 through AC-007 is met on the inspected tree and on checks re-run in the Git-free snapshot; remaining notes are NITs and do not block.

## Verification performed

Working directory: `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent`.
`PATH` placed Flutter 3.47.0 first: `/Users/ortalcohen/fvm/versions/3.47.0/bin`.

Did not read `STATE.yaml`, `01-plan.md`, `03-tasks.md`, `00-research.md`, or `04-verification.md` as evidence. Did not git checkout. Pipeline files in `/private/tmp/flva-verify-snapshot-0003` compared equal to the working tree (`cmp` SAME for `tool/check.sh`, bump and occupancy helpers and their tests, `.pubignore`, the three workflow YAML files, `pubspec.yaml`, and `CHANGELOG.md`). Snapshot has no `.git`.

### 1. `python3 tool/lint_wiki.py`

```
lint_wiki: clean (0 warning(s)).
EXIT:0
```

This run was taken before this report file existed.

### 2. Inspect `.pubignore` and workflow YAML

`.pubignore` excludes `/tool/`, `/wiki/`, `/.github/`, `/pubspec.lock`, `/example/pubspec.lock`, generated caches, `/native/tests/`, `/test/`, `/android/src/main/jniLibs/`, and `/ios/Frameworks/`.

`ruby -ryaml` loaded all three workflows:

```
.github/workflows/checks.yml OK keys=["name", true, "jobs"] on={"push"=>{"branches"=>["**"]}, "pull_request"=>nil}
.github/workflows/release.yml OK keys=["name", true, "permissions", "concurrency", "jobs"] on={"push"=>{"branches"=>["main"]}}
.github/workflows/publish.yml OK keys=["name", true, "jobs"] on={"push"=>{"tags"=>["v[0-9]+.[0-9]+.[0-9]+"]}}
```

`release.yml` requires `secrets.RELEASE_GITHUB_TOKEN` before checkout, runs `bash tool/check.sh` before `bump_patch_version.sh`, rejects an existing `vMAJOR.MINOR.PATCH` tag via `git ls-remote` before commit, then commits `pubspec.yaml` and `CHANGELOG.md` and pushes `git tag -a`. `publish.yml` sets `id-token: write`, runs `flutter pub get` before `dart-lang/setup-dart@v1`, then dry-run then `flutter pub publish --force`. `flutter-actions/setup-flutter@v4` resolves to branch `v4` (exact tag `v4` is absent; branch `v4` exists). Action inputs `version` and `channel` match that action's `action.yml`.

### 3. `sh tool/check.sh` in `/private/tmp/flva-verify-snapshot-0003`

```
FLUTTER=alias flutter='fvm flutter'
Flutter 3.47.3 • channel stable • https://github.com/flutter/flutter.git
...
Tools • Dart 3.13.3 • DevTools 2.60.0
----- START check.sh -----
lint_wiki: clean (0 warning(s)).
Stage 1 passed: wiki lint
...
Stage 2 passed: dependencies
Formatted 27 files (0 changed) in 0.13 seconds.
Stage 3 passed: format
Analyzing flva-verify-snapshot-0003...
No issues found!
Analyzing example...
No issues found!
Stage 4 passed: analysis
```

The harness truncated the mid-log (package and example `flutter test` lines were in progress). The same process then printed:

```
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
EXIT:0
```

`set -eu` in `tool/check.sh` means Stage 5 (`flutter test`, example tests, `python3 tool/test_native.py`) ran before Stage 6. Re-ran native tests in the same snapshot:

```
PASS ring wrap/overflow/underflow/concurrency
PASS resampler partition DC attenuation upsample reset invalid capacity
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
NATIVE_EXIT:0
```

### 4. Helper tests re-run in the working tree

```
===== test_bump_patch_version.sh =====
PASS bump patch positive case
PASS missing pubspec
PASS missing changelog
PASS malformed package version
PASS malformed occupied version
PASS duplicate changelog version
PASS occupied candidate skipped
BUMP_EXIT:0
===== test_occupied_pubdev_versions.sh =====
PASS occupied pub.dev versions positive and malformed-response negative cases
OCC_EXIT:0
```

Independent fixture (not the bundled script): bump `1.2.3` → `1.2.4` and prepends `## 1.2.4 - 2026-09-21`. Missing changelog exits 1 (`Error: CHANGELOG.md not found`). Occupied `1.2.4 1.2.5` skipped by the bundled occupied-candidate case. Occupancy helper:

```
OCC_NONNUM exit=0 stdout=1.2.x 0.2.0
OCC_BAD_JSON exit=1 ... JSONDecodeError: Expecting value: line 1 column 1 (char 0)
OCC_NO_VERSIONS exit=1 stderr=Error: pub.dev response has no versions list
OCC_MISSING_FILE exit=1 ... FileNotFoundError
BUMP_WITH_NONNUM_OCC exit=1 stderr=Error: malformed occupied version: 1.2.x
WF_404_PAYLOAD {'versions': []}
WF_500_RAISED 500
WF_URLERROR_PROPAGATES URLError timed out
```

The HTTP 404/500/URLError cases executed a copy of the occupancy `try`/`except` in `release.yml` (lines 46–52), not a hosted Actions job.

### 5. Package dry-run payload

`dart pub publish --dry-run` in the Git-free snapshot, exit 0:

```
Publishing flutter_local_voice_agent 0.1.1 to https://pub.dev:
├── CHANGELOG.md (2 KB)
├── LICENSE (1 KB)
├── README.md (9 KB)
├── android
├── doc
├── example
├── image.png (207 KB)
├── ios
├── lib
├── linux
├── macos
├── native
├── pubspec.yaml (1 KB)
├── third_party
└── windows
...
Package has 0 warnings and 1 hint.
```

Hint only: published version on pub.dev is `0.1.2`; local snapshot is `0.1.1`. Zero warnings.

Needles absent from that listing: `wiki/`, `tool/`, `.github/`, `pubspec.lock` (the real lockfile), `native/tests`, `jniLibs`, `Frameworks`, `.dart_tool`, `AGENTS.md`, `CLAUDE.md`, `agent_test.dart`, `spsc_ring_test.cpp`. Present: `example/` including `example/test/*.dart`, two `Podfile.lock` files under example iOS/macOS, and `native/llm/utf8_test.cpp` plus `native/llm/smoke.cpp`.

Repository-only fixtures added only under the snapshot (`wiki/impl-review-fixture.md`, `tool/impl-review-fixture.sh`, `test/impl-review-fixture.dart`, `native/tests/impl-review-fixture.bin`, `.github/workflows/impl-review-fixture.yml`) did not appear (`impl-review-fixture: 0`). Dry-run exit 0.

A `dart pub publish --dry-run` in the dirty live checkout exited 65. That is the documented dirty-tree case; the snapshot result is the one used.

### 6. Negative cases for other criteria

Missing required tool (snapshot, `PATH` without Flutter):

```
Preflight failed: missing flutter
MISSING_FLUTTER_EXIT:1
```

Format stage command on a broken fixture:

```
Changed /tmp/flva-bad-format.dart
Formatted 1 file (1 changed) in 0.00 seconds.
FORMAT_NEG_EXIT:1
```

Omit release secret:

```
Missing repository secret RELEASE_GITHUB_TOKEN.
OMIT_SECRET_FAILS
```

Occupied-tag assertion (`test -z` on a non-empty ref) exits 1; empty ref exits 0.

Non-semantic tag filter samples against the publish trigger string `v[0-9]+.[0-9]+.[0-9]+` interpreted as a full-string digit pattern: `v1.2.3-beta`, `v1.2`, `release-1.0.0`, and `1.2.3` do not match. Hosted GitHub Actions was not executed (explicitly not required).

### 7. Credential and payload-secret search

Searched `tool/check.sh`, bump and occupancy helpers and their tests, `.pubignore`, the three workflow YAML files, `pubspec.yaml`, and `CHANGELOG.md` for `ghp_`, `github_pat_`, `ghs_`, `AKIA`, `-----BEGIN`, `PUB_TOKEN`, `password=`, `api_key=`. Result: `NO_LITERAL_CREDENTIALS`.

The only token-adjacent workflow lines are secret *references*:

```
.github/workflows/release.yml:22:          RELEASE_GITHUB_TOKEN: ${{ secrets.RELEASE_GITHUB_TOKEN }}
.github/workflows/release.yml:23:        run: test -n "$RELEASE_GITHUB_TOKEN" || (echo 'Missing repository secret RELEASE_GITHUB_TOKEN.' >&2; exit 1)
.github/workflows/release.yml:26:          token: ${{ secrets.RELEASE_GITHUB_TOKEN }}
.github/workflows/publish.yml:12:      id-token: write
```

No command output from `check.sh`, the helpers, or the dry-run printed a credential, model binary, or personal data. `jniLibs` and `Frameworks` were absent from the dry-run payload.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | `tool/check.sh:5` wiki lint; `:6` package and example `flutter pub get`; `:10` format; `:11` analysis; `:12`–`:14` package, example, and deterministic native tests; `:15` dry-run. Snapshot `check.sh` exit 0 with Stages 1–4, 6–7 printed; native re-run exit 0. | yes — missing `flutter` exits 1 at preflight (`tool/check.sh:4`); `dart format --set-exit-if-changed` on a broken fixture exits 1 |
| AC-002 | pass | `tool/bump_patch_version.sh:9` increments patch; `:20` prepends `## VERSION - DATE` after `# Changelog`. Isolated fixture: `1.2.3` → `1.2.4` and `## 1.2.4 - 2026-09-21`. | yes — missing pubspec, missing changelog, malformed version, duplicate changelog version (`tool/test_bump_patch_version.sh:11`–`:37`; independent missing-changelog exit 1) |
| AC-003 | pass | `tool/bump_patch_version.sh:11`–`:15` skips occupied candidates; `tool/occupied_pubdev_versions.py:9`–`:11` rejects a response with no `versions` list; `release.yml:48`–`:50` re-raises non-404 HTTP errors. Occupied `1.2.4` yields `1.2.5`. | yes — malformed JSON exit 1; non-numeric occupied `1.2.x` rejected by the bump helper; copied workflow loader raises on HTTP 500 and propagates `URLError` |
| AC-004 | pass | `release.yml:5` push to `main`; `:20`–`:23` require `RELEASE_GITHUB_TOKEN`; `:35`–`:36` checks before `:57`–`:59` bump; `:60`–`:63` reject existing tag before `:64`–`:74` commit and `git tag -a`. Ruby YAML load succeeded. | yes — empty secret fails the `test -n` guard; non-empty tag ref fails `test -z` before the push steps |
| AC-005 | pass | `publish.yml:5` semantic tag trigger; `:12` `id-token: write`; `:20`–`:22` `flutter pub get` before `dart-lang/setup-dart@v1`; `:23`–`:26` dry-run then publish. Package name `flutter_local_voice_agent` in `pubspec.yaml:1`. | yes — trigger is only `v[0-9]+.[0-9]+.[0-9]+`; `v1.2.3-beta`, `v1.2`, `release-1.0.0`, and `1.2.3` do not match that pattern. Hosted run not required. |
| AC-006 | pass | `.pubignore:2`–`:3` tool and wiki; `:10` CI; `:35`–`:38` lockfiles and caches; `:63`–`:64` native tests and package tests. Snapshot dry-run top-level listing omits those trees. | yes — snapshot fixtures under `wiki/`, `tool/`, `test/`, `native/tests/`, and `.github/workflows/` produced `impl-review-fixture: 0` |
| AC-007 | pass | Workflows store `${{ secrets.RELEASE_GITHUB_TOKEN }}` references only (`release.yml:22`, `:26`). Dry-run omitted `jniLibs` and `Frameworks`. Check and helper output printed no secrets. | yes — literal credential search over the listed pipeline files returned no `ghp_` / `github_pat_` / PEM / `PUB_TOKEN` values |

## Findings

### F-001 — Example tests and CocoaPods lockfiles are in the dry-run payload

- Severity: NIT
- Location: `.pubignore:64` (`/test/` only); dry-run listing also includes two `Podfile.lock` files under `example/`
- Criterion affected: none
- Observation: `dart pub publish --dry-run` in the Git-free snapshot listed `example/test/model_storage_test.dart`, `example/test/voice_screen_controller_test.dart`, `example/test/voice_screen_test.dart`, and two `example/**/Podfile.lock` files. Package `/test/`, `/native/tests/`, and `pubspec.lock` were absent. AC-006 names repository-only tests and lockfiles; the published example tree is not that set.
- Why it matters: A later reader who treats every `*test*` path or every lockfile name as in-scope for AC-006 will disagree with this verdict. The named repository-only trees required by AC-006 are excluded.

### F-002 — Occupancy helper prints non-numeric version strings

- Severity: NIT
- Location: `tool/occupied_pubdev_versions.py:12`
- Criterion affected: none
- Observation: `{"versions":[{"version":"1.2.x"},{"version":"0.2.0"}]}` exits 0 and prints `1.2.x 0.2.0`. The bump helper then exits 1 (`Error: malformed occupied version: 1.2.x`). Release logic still fails on malformed occupancy, which is what AC-003 requires.
- Why it matters: Failure is at the bump step, not at occupancy parse. That is sufficient for the criterion; it is a sharper split than a single helper that rejects non-numeric versions itself.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | none — NIT |
| F-002 | none — NIT |
