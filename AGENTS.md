# Agent instructions

Single source of truth for every coding agent in this repository.
Claude Code reads it via the `@AGENTS.md` import in `CLAUDE.md`. Cursor reads it natively.

## Language

All files, code, comments, commits and wiki content are written in **English only**.

## Non-negotiables

- Never invent a fact, a benchmark number, an API, a file path or an approval. If you did not verify it, mark it `[UNVERIFIED]`.
- Never claim a check passed without pasting the command output that proves it.
- Never mark a task complete while a test fails, a step is partial or an error is unresolved.
- Never commit secrets, credentials or personal data. Use synthetic or anonymized data in examples and fixtures.
- Never delete a wiki artifact. Supersede it and record the supersession.

## Workflow

Every change goes through the pipeline in `wiki/conventions/workflow.md`. Do not improvise a variant.

Route by change size:

| Change size | Path |
|---|---|
| One file, no new dependency, no interface change, no data model change | `/quick-change` |
| Anything else | `/feature` (full pipeline) |

If you are unsure which applies, use `/feature`.

The pipeline phases are: research -> plan -> validate -> implement -> verify -> document.
Each phase writes one numbered artifact into `wiki/work/NNNN-slug/`.
Phase state lives in that folder's `STATE.yaml`. Read it before doing anything in an existing work item.

## Artifact rules

- `01-plan.md` contains prose instructions only. **Zero fenced code blocks.** No code examples, no snippets, no pseudo-code. A plan says what to do and why, never how to type it.
- `02-criteria.md` is frozen once implementation starts. Adding a criterion after that requires a new validation round, recorded, not a silent edit.
- Validation reports are numbered and append-only. Never overwrite `plan-review-01.md` with round two.
- Every wiki document carries the frontmatter defined in `wiki/conventions/naming.md`.

## Validation

Validation is adversarial and blind. A validator sees the acceptance criteria and the artifact, never the author's reasoning. A validator reports findings; it does not propose or apply fixes, and it does not decide what happens next.

- One validation round per phase. The validator reports its verdict once; it does not loop or re-check its own findings.
- The main agent reads the verdict and decides what to do with each finding: fix it directly, accept it as pre-existing or out of scope, or send the defect back to the phase it belongs to. Record the decision and the reason.
- Do not trust a "fixed it" claim. Re-run the check.
- Route a FAIL by defect class: a plan defect goes back to the plan phase, an implementation defect to the implement phase. Never patch code to satisfy a plan-level finding.

## Delegation

When you delegate to a subagent, the prompt must state: the objective, the exact output format, which tools and sources to use, the task boundary, and the file path the subagent writes to. A delegation missing any of these produces duplicated or missing work.

Parallelise read-only fan-out: research streams, independent modules, competing debugging hypotheses. Target 3 concurrent subagents, never more than 5.

Never parallelise: writing the plan, editing a shared hotspot file (routing, config, registry, schema, lockfile), a cross-cutting interface decision, or the validation verdict.

Before any fan-out, decide the shared design choices yourself and put them in the delegation prompt. Assumption collisions cannot be repaired after the fact.

## Model routing

Match the model to the work. See `wiki/conventions/model-routing.md`. Default: reviewers and planners get the strongest model, implementers get the balanced one, mechanical work gets the fastest one.

## Where to look

`wiki/INDEX.md` is the router. It says which file to read and when. Read it instead of exploring the tree.

Do not ask the repository to explain itself in prose. Prefer running the code and `git log` over reading an architecture summary.

## Checks

- Format: `dart format lib example/lib`
- Analyze: `dart analyze --fatal-infos --fatal-warnings`
