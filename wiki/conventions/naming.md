---
id: naming
title: Naming and frontmatter
status: active
owner: unassigned
last_verified: 2026-09-04
applies_to: ["wiki/**"]
summary: File naming, numbering and the frontmatter every wiki document must carry.
---

# Naming and frontmatter

## Files and folders

- Lowercase kebab-case throughout. No spaces, no underscores, no capitals.
- Work items: `wiki/work/NNNN-kebab-slug/`. Four digits, zero-padded, next unused number, never reused.
- Phase artifacts inside a work item keep their fixed names and numeric prefixes: `00-research.md`, `01-plan.md`, `02-criteria.md`, `03-tasks.md`.
- Validation reports: `validation/<phase>-review-NN.md`, where `<phase>` is `research`, `plan` or `impl`, and `NN` starts at `01` and increments per round. Never overwrite a prior round.
- ADRs: `wiki/adr/NNNN-kebab-title.md`. Four digits, sequential, never reused, never deleted.

## Identifiers

- Acceptance criteria: `AC-001` upward, unique within a work item, never renumbered once frozen.
- Findings in a validation report: `F-001` upward, unique within that report.
- A task in `03-tasks.md` cites the criteria it satisfies by ID. A task satisfying no criterion does not belong in the plan.

## Headings

Headings are link targets. Once a document is referenced, its headings are part of its contract — reword the body, not the heading. If a heading must change, update every reference in the same commit.

## Frontmatter

Every document under `wiki/` except work-item artifacts and `templates/STATE.yaml` carries this YAML frontmatter:

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Stable kebab-case identifier, unique across the wiki. Never changes. |
| `title` | yes | Human-readable title. |
| `status` | yes | `active`, `draft`, or `superseded`. |
| `owner` | yes | Person or team accountable. `unassigned` is allowed but is a known gap. |
| `last_verified` | yes | ISO date the content was last checked against reality. Not the last edit date. |
| `applies_to` | yes | Glob list naming the code this document governs. `["**"]` for project-wide. |
| `summary` | yes | One sentence. This is what a router or an agent reads before deciding to open the file. |
| `supersedes` | no | `id` of the document this one replaces. |
| `superseded_by` | no | `id` of the document that replaced this one. Set alongside `status: superseded`. |

Work-item artifacts carry no frontmatter — their folder and filename already encode everything. `STATE.yaml` is the work item's metadata.

## Superseding

Documents are never deleted. To retire one: set `status: superseded`, set `superseded_by`, and set `supersedes` on the replacement. The old document stays in place and stays reachable from the index. Deleting it destroys the record of why the project once believed something else.

## Staleness

`last_verified` older than 180 days on an `active` document is a lint warning. Older than 365 days is a lint failure. Re-verify the content or mark the document superseded; do not touch the date without re-reading the content.
