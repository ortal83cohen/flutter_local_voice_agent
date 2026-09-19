# Research: Pub.dev release pipeline

## Question

What repository-owned release pipeline should publish `flutter_local_voice_agent` to pub.dev after a push to GitHub, while preserving the repository's existing workflow and native checks?

## Answer

The repository needs a three-workflow pipeline matching the proven `flutter_webmcp` shape: continuous checks, a main-branch patch-release workflow, and a semantic-tag OIDC publication workflow. The local package is a Flutter plugin at version 0.1.0 with an existing native test tool and no GitHub workflows, so the checks must add package, example, wiki, format, analysis, Flutter tests, native tests, and package dry-run coverage without assuming downloadable model assets.

## Findings

### Existing repository state

- Claim: The package is named `flutter_local_voice_agent`, currently declares version `0.1.0`, supports Flutter 3.47.0 or newer, and has Android and iOS plugin platforms.
- Evidence: `pubspec.yaml` at the repository root.
- Source: `pubspec.yaml`

### Existing local verification

- Claim: The repository already provides `tool/lint_wiki.py` and `tool/test_native.py`; the native test tool runs deterministic ring-buffer and resampler tests without requiring model assets.
- Evidence: The tool compiles and executes the deterministic tests before its optional real-engine branch.
- Source: `tool/test_native.py`

### Reference release design

- Claim: The reference `flutter_webmcp` project separates checks, release version/tag creation, and pub.dev publication.
- Evidence: The reference repository contains `.github/workflows/checks.yml`, `.github/workflows/release.yml`, and `.github/workflows/publish.yml`.
- Source: `/Users/ortalcohen/Documents/GitHub/flutter_webmcp/.github/workflows/checks.yml`, `/Users/ortalcohen/Documents/GitHub/flutter_webmcp/.github/workflows/release.yml`, `/Users/ortalcohen/Documents/GitHub/flutter_webmcp/.github/workflows/publish.yml`

### Authentication and external gates

- Claim: The reference release workflow requires a repository secret with contents write permission to create the release commit and tag, while publication requires GitHub OIDC configured for the package and repository on pub.dev.
- Evidence: The reference workflow comments and permission blocks specify `RELEASE_GITHUB_TOKEN`, `contents: write` through the checkout token, and `id-token: write` for the publish job.
- Source: `/Users/ortalcohen/Documents/GitHub/flutter_webmcp/.github/workflows/release.yml`, `/Users/ortalcohen/Documents/GitHub/flutter_webmcp/.github/workflows/publish.yml`

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Three-stage GitHub Actions pipeline | Checks run on pushes and pull requests; main creates a patch commit and tag; tags publish through OIDC | Requires two external repository configuration gates | Chosen because it matches the requested reference and keeps credentials out of the repository |
| Publish on every main push | Runs pub.dev publication directly after checks | Couples versioning and publication to every push and needs a long-lived credential or fragile version policy | Rejected because it lacks an explicit immutable tag boundary |
| Manual local publication only | Operators run `dart pub publish` locally | No reproducible GitHub release trigger or hosted audit trail | Rejected because the request explicitly asks for GitHub-triggered deployment |

## Constraints discovered

- The package must not publish local tests, wiki records, CI configuration, caches, lockfiles, or native test assets; `.pubignore` is the package boundary.
- Model-dependent native smoke tests cannot be a required CI step unless the repository provisions and redistributes compatible model assets; deterministic native tests can run without them.
- The release workflow must not use the default `GITHUB_TOKEN` to push a tag that is expected to trigger another workflow.
- No external secret, pub.dev configuration, push, or hosted workflow result is verified by local files alone.

## Unresolved

- [UNRESOLVED: Whether the GitHub repository secret `RELEASE_GITHUB_TOKEN` exists and is permitted to push to `main`]
- [UNRESOLVED: Whether pub.dev has GitHub Actions OIDC enabled for `ortal83cohen/flutter_local_voice_agent` with tag pattern `v{{version}}`]
- [UNRESOLVED: Whether the current GitHub branch protection permits the release token to push directly to `main`]

## Sources

- Repository files listed above, consulted 2026-09-19.
