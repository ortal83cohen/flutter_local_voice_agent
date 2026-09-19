# Plan: Pub.dev release pipeline

## Goal

After this change, a push to `main` can run the repository's checks, create the next unoccupied patch release and annotated semantic tag, and hand that tag to a separate OIDC-authenticated pub.dev workflow. Pull requests and non-main branches will receive the same local quality checks without mutating versions or publishing anything.

## Approach

Add a repository check entrypoint that mirrors the existing commands documented in `AGENTS.md` and includes the deterministic native test suite and package dry-run. Add focused shell and Python helpers for patch version selection and hosted-version occupancy, with fixture tests covering successful and rejected inputs. Add three GitHub workflows: checks, release, and publish.

The release job will use a repository-scoped `RELEASE_GITHUB_TOKEN`, validate the package before changing files, skip versions already reported by pub.dev, commit only the package version and changelog, and push an annotated `vX.Y.Z` tag. The publish job will resolve public dependencies before requesting the temporary OIDC token, then run a dry run and publication on matching tags.

Update the changelog and wiki index with the release-pipeline contract and its external operator gates. No credentials, model assets, or hosted configuration will be added to the repository.

## Why this approach

The direct three-workflow design is selected because it is the established shape in `flutter_webmcp` and gives GitHub an auditable release boundary. Publishing on every main push was rejected because it conflates development and release state. Local-only publication was rejected because it does not satisfy the requested GitHub trigger or provide hosted workflow evidence.

## Steps

1. Record the repository and reference-pipeline findings, freeze independently checkable acceptance criteria, and define the task ownership.
2. Add deterministic version and pub.dev occupancy helpers with negative fixture coverage.
3. Add the package check entrypoint and three GitHub workflows adapted to this plugin's package, example, wiki, and native checks.
4. Update release-facing documentation and the changelog, then run the local checks and package dry run.
5. Review the diff and validation evidence, then push the authorized changes to GitHub and inspect the resulting workflow state if authentication permits.

## Interfaces and shared decisions

- The package version is the top-level numeric `version` in `pubspec.yaml`.
- Release tags use `vMAJOR.MINOR.PATCH` and are created only after checks pass.
- The release workflow writes `pubspec.yaml` and `CHANGELOG.md` only.
- `RELEASE_GITHUB_TOKEN` is required for the release commit and tag; its value is never logged or stored.
- pub.dev publication uses GitHub OIDC with `id-token: write`; no pub.dev secret is stored in GitHub.
- Deterministic native tests are required; model-dependent tests remain optional and are not silently represented as CI coverage.

## Risks

| Risk | Likelihood | Impact | Mitigation | Trigger that means it happened |
|---|---|---|---|---|
| Missing release token | Medium | High | Fail before checkout mutation with an actionable message | Release job reports missing `RELEASE_GITHUB_TOKEN` |
| OIDC package configuration is absent | Medium | High | Keep publication isolated to the tag workflow and document the exact external gate | Publish job cannot obtain or exchange the token |
| Hosted package version has advanced independently | Low | Medium | Query pub.dev and skip occupied versions before tagging | Occupancy response contains the candidate version |
| Local native assets are mistaken for CI qualification | Medium | Medium | Run only deterministic tests and state the asset boundary | A review treats local model smoke as required hosted proof |

## Rollback

Disable the release and publish workflows or revert the pipeline commit. A release tag already pushed is immutable; it can be left unpublished or the corresponding workflow can be disabled. Do not move or overwrite an existing tag.

## Out of scope

- Creating or rotating GitHub secrets.
- Configuring pub.dev OIDC in the pub.dev account.
- Provisioning or redistributing speech and language model assets.
- Claiming a successful hosted publication before GitHub Actions and pub.dev show it.

## Verification approach

Run the package check entrypoint, the helper fixture tests, the wiki linter, and `dart pub publish --dry-run`. Inspect the exact diff and both staged and unstaged state. Verify workflow YAML structure locally. After the user-authorized push, inspect the GitHub workflow runs and pub.dev version only if credentials and connectivity permit; report unavailable external gates as unverified.
