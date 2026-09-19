# Tasks: Pub.dev release pipeline

## Legend

- `[P]` — may run in a parallel subagent. Only mark a task `[P]` if no other `[P]` task in the same group touches any of the same files.
- Every task cites the criteria it satisfies.
- Files owned by a task are exclusive.

## Groups

### Group 1 — Release helpers

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | Add patch bump and hosted-version occupancy helpers with isolated fixture tests. | AC-002, AC-003 | `tool/bump_patch_version.sh`, `tool/occupied_pubdev_versions.py`, `tool/test_bump_patch_version.sh`, `tool/test_occupied_pubdev_versions.sh`, fixtures |  | All positive and negative cases pass. |

### Group 2 — CI and publication

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 2.1 | Add the local check entrypoint for this package and example. | AC-001, AC-006 | `tool/check.sh` |  | The script reports named stages and exits nonzero on failures. |
| 2.2 | Add checks, release, and OIDC publish workflows adapted to this package. | AC-004, AC-005, AC-007 | `.github/workflows/checks.yml`, `.github/workflows/release.yml`, `.github/workflows/publish.yml` |  | Static workflow assertions pass and no secret values are present. |

### Group 3 — Documentation

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 3.1 | Document the release contract and external gates in the wiki and changelog. | AC-004, AC-005, AC-007 | `wiki/INDEX.md`, `wiki/product/pubdev-release-pipeline.md`, `CHANGELOG.md` |  | Wiki lint and package dry run pass. |

## Serialised files

| File | Owning task |
|---|---|
| `wiki/INDEX.md` | 3.1 |
| `CHANGELOG.md` | 3.1 |

## Test tasks

| # | Covers | Positive case | Negative case |
|---|---|---|---|
| T-001 | AC-001 | Full local check suite completes. | Missing tool or failing fixture stops the named stage. |
| T-002 | AC-002, AC-003 | Valid fixture bumps to next free patch. | Invalid version, changelog, JSON, and occupancy response fail. |
| T-003 | AC-004, AC-005 | Workflow structure matches intended trigger and permissions. | Wrong branch/tag or missing secret/configuration is rejected. |
| T-004 | AC-006 | Dry-run payload excludes repository-only paths. | A prohibited path appears in the payload check. |
