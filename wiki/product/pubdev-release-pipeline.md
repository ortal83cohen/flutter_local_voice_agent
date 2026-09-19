---
id: pubdev-release-pipeline
title: Pub.dev release pipeline
status: active
owner: unassigned
last_verified: 2026-09-19
applies_to: [".github/workflows/**", "tool/**", "pubspec.yaml", "CHANGELOG.md"]
summary: GitHub checks, main-branch release tagging, and OIDC publication contract for pub.dev.
---

# Pub.dev release pipeline

The repository uses three GitHub Actions workflows. `checks.yml` runs the local package check suite on pushes and pull requests. `release.yml` runs on `main`, verifies the package, selects the next patch version that is not occupied on pub.dev, updates the package changelog, and pushes an annotated semantic version tag. `publish.yml` runs only for semantic version tags and publishes through GitHub OIDC.

Before the first release, an operator must create the repository secret `RELEASE_GITHUB_TOKEN` with narrowly scoped contents write permission and ensure branch protection allows it to update `main`. The pub.dev package settings must enable GitHub Actions publishing for repository `ortal83cohen/flutter_local_voice_agent` with tag pattern `v{{version}}`. These hosted settings are external gates and are not proved by local checks.

The required local boundary is `bash tool/check.sh`. It includes wiki lint, dependency resolution, formatting, analysis, package and example tests, deterministic native tests, package dry-run validation, and release-helper fixture tests. Real model smoke tests and physical-device qualification remain separate gates because they require local assets and hardware.
