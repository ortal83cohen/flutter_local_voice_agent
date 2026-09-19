# Acceptance criteria: Pub.dev release pipeline

## Frozen

- Frozen at: 2026-09-19
- Frozen by: Codex

## Criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-001 | When the check entrypoint runs in a checkout with the required SDKs, it shall lint the wiki, resolve package and example dependencies, enforce formatting and analysis, run package/example tests, run deterministic native tests, and validate the package dry run. | Execute `bash tools/check.sh` and inspect each named stage. | Remove a required tool or introduce a formatting error in a fixture and confirm a named stage fails. |
| AC-002 | When the patch helper runs against a valid package and changelog, it shall increment the patch version and prepend a dated changelog entry. | Run the helper in an isolated fixture and inspect both files. | Reject missing pubspec, malformed version, missing changelog, duplicate version, and malformed occupancy input. |
| AC-003 | When pub.dev reports an occupied candidate version, the release logic shall choose the next unoccupied patch version and fail on malformed or unavailable occupancy data. | Run occupancy and bump helper fixture tests. | Supply malformed JSON, non-numeric versions, and a response error. |
| AC-004 | When a push targets `main`, the release workflow shall require `RELEASE_GITHUB_TOKEN`, run checks before mutation, commit the version/changelog bump, and push an annotated `vMAJOR.MINOR.PATCH` tag. | Inspect workflow assertions and run YAML/static checks. | Omit the secret or use an occupied tag and confirm the job fails before pushing. |
| AC-005 | When a matching semantic tag is pushed, the publish workflow shall request GitHub OIDC, resolve public dependencies before token setup, run a dry run, and publish the package. | Inspect workflow permissions, ordering, trigger and package name. | A non-semantic tag shall not trigger the publication workflow. |
| AC-006 | When the package dry run is evaluated, repository-only wiki, tests, tools, CI, caches, lockfiles, and native test assets shall remain excluded from the package payload. | Execute `dart pub publish --dry-run` and inspect the listed payload. | Add a repository-only fixture and confirm it is not included. |

## Non-functional criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-007 | The pipeline shall not store or print credentials, model assets, or personal data. | Review the workflow diff and command output. | Search the changed files for token values or credential literals. |

## Explicitly not required

- Successful GitHub Actions execution before the changes are pushed.
- Successful pub.dev publication before external OIDC configuration and repository secrets are present.
- Physical-device, acoustic, thermal, voice-quality, or real-model qualification.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
