# Plan review — round 01

- Work item: 0003-pubdev-release-pipeline
- Reviewed artifact: wiki/work/0003-pubdev-release-pipeline/01-plan.md
- Reviewer: plan-review-0003
- Date: 2026-09-21

## Verdict

**FAIL**

The written plan does not cover AC-006's package-payload exclusions and leaves required AC-001 entrypoint stages, AC-002's dated changelog prepend, and AC-003's fail-on-bad-occupancy behavior unspecified.

## Verification performed

Reviewed only `wiki/work/0003-pubdev-release-pipeline/01-plan.md` against `wiki/work/0003-pubdev-release-pipeline/02-criteria.md`. Did not inspect source, workflows, tasks, or verification artifacts.

Checked the plan for fenced code (workflow plan rule: prose only) and for the words needed by each frozen criterion:

```
plan_lines=58
fenced_code_openers=none
contains[wiki]=True
contains[dependenc]=True
contains[format]=False
contains[analy]=False
contains[example]=True
contains[native]=True
contains[dry-run]=True
contains[dry run]=True
contains[dated]=False
contains[prepend]=False
contains[occup]=True
contains[malformed]=False
contains[unavailable]=True
contains[RELEASE_GITHUB_TOKEN]=True
contains[annotated]=True
contains[OIDC]=True
contains[id-token]=True
contains[pubignore]=False
contains[lockfile]=False
contains[cache]=False
contains[personal data]=False
contains[credential]=True
```

`dependenc` is present only as publish-job public-dependency resolution (`01-plan.md:11`), not as AC-001 package and example resolution. `unavailable` is present only as post-push external-gate reporting (`01-plan.md:58`), not as occupancy-data failure. `tool/lint_wiki.py` does not accept path arguments; it was not used as evidence.

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | fail | `01-plan.md:9` defines the check entrypoint as AGENTS.md commands plus native tests and dry-run; wiki lint, package/example dependency resolution, formatting, analysis, and package/example tests are not named as entrypoint stages. `01-plan.md:58` lists the wiki linter beside the entrypoint, not inside it. | n/a |
| AC-002 | fail | `01-plan.md:9` and `01-plan.md:22` add version helpers with rejected-input fixtures. `01-plan.md:11` and `01-plan.md:31` say the release writes version and changelog. The plan never requires incrementing the patch and prepending a dated changelog entry. | n/a |
| AC-003 | fail | `01-plan.md:5` and `01-plan.md:11` say create the next unoccupied patch and skip versions pub.dev already reports. The plan never requires the release logic to fail on malformed or unavailable occupancy data. | n/a |
| AC-004 | pass | `01-plan.md:5` scopes the release path to a push to main. `01-plan.md:11`, `01-plan.md:30`, `01-plan.md:32`, and `01-plan.md:40` require `RELEASE_GITHUB_TOKEN`, validation or checks before mutation or tagging, a version and changelog commit, and an annotated `vX.Y.Z` tag. | n/a |
| AC-005 | pass | `01-plan.md:11` and `01-plan.md:33` require public-dependency resolution before the OIDC token, then dry-run and publication on matching tags, using GitHub OIDC with `id-token: write`. | n/a |
| AC-006 | fail | `01-plan.md:9` and `01-plan.md:58` require running a package dry-run. The plan never requires excluding wiki, tests, tools, CI, caches, lockfiles, or native test assets from the package payload. | n/a |
| AC-007 | pass | `01-plan.md:13` forbids adding credentials, model assets, or hosted configuration. `01-plan.md:32` forbids logging or storing `RELEASE_GITHUB_TOKEN`. `01-plan.md:33` forbids storing a pub.dev secret. Personal data is not named; see F-005. | n/a |

## Findings

### F-001 — Package-payload exclusions are absent

- Severity: BLOCKER
- Location: `wiki/work/0003-pubdev-release-pipeline/01-plan.md:58`
- Criterion affected: AC-006
- Observation: The plan treats dry-run as a check to execute. It never states that repository-only wiki, tests, tools, CI, caches, lockfiles, and native test assets must stay out of the published payload.
- Why it matters: AC-006 is a frozen publication-content rule. A plan that only says "run dry-run" does not tell an implementer what the dry-run must prove.

### F-002 — Check entrypoint stages are incomplete

- Severity: BLOCKER
- Location: `wiki/work/0003-pubdev-release-pipeline/01-plan.md:9`
- Criterion affected: AC-001
- Observation: The entrypoint is specified as the AGENTS.md commands plus deterministic native tests and package dry-run. AC-001 also requires wiki lint, package and example dependency resolution, formatting, analysis, and package and example tests as stages of that same entrypoint. Formatting and analysis are never named. Wiki lint appears later as a separate verification command (`01-plan.md:58`), not as an entrypoint stage. "Dependenc" in the plan is the publish-job public-dependency step (`01-plan.md:11`), not package and example resolution inside the check entrypoint.
- Why it matters: An implementer following the entrypoint sentence can omit required AC-001 stages and still match the written plan.

### F-003 — Dated changelog prepend is unspecified

- Severity: BLOCKER
- Location: `wiki/work/0003-pubdev-release-pipeline/01-plan.md:11`
- Criterion affected: AC-002
- Observation: The plan says helpers select a patch version and that release commits the package version and changelog. It never says the helper increments the patch and prepends a dated changelog entry.
- Why it matters: AC-002's check is the dated prepend plus the patch increment. Writing CHANGELOG.md without that shape does not satisfy the criterion.

### F-004 — Occupancy failure behavior is unspecified

- Severity: BLOCKER
- Location: `wiki/work/0003-pubdev-release-pipeline/01-plan.md:11`
- Criterion affected: AC-003
- Observation: The plan says skip versions already reported by pub.dev and create the next unoccupied patch. It does not say release logic fails when occupancy data is malformed or unavailable. `01-plan.md:42` only mitigates an independently advanced hosted version. `01-plan.md:58` uses "unavailable" for post-push GitHub and pub.dev inspection, not occupancy input.
- Why it matters: AC-003 requires a hard fail on bad or missing occupancy data. Skipping occupied versions alone allows proceeding, guessing, or treating a fetch failure as empty occupancy.

### F-005 — Personal data is omitted from the secrecy rule

- Severity: NIT
- Location: `wiki/work/0003-pubdev-release-pipeline/01-plan.md:13`
- Criterion affected: AC-007
- Observation: The plan names credentials, model assets, hosted configuration, and the release token. It does not name personal data.
- Why it matters: AC-007 lists personal data with credentials and model assets. The omission is a wording gap, not a competing approach.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | plan |
| F-002 | plan |
| F-003 | plan |
| F-004 | plan |
| F-005 | plan |
