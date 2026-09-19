<!-- Copy to wiki/work/NNNN-slug/03-tasks.md. Delete the guidance comments as you fill each section. -->

# Tasks: <work item title>

## Legend

- `[P]` — may run in a parallel subagent. Only mark a task `[P]` if no other `[P]` task in the
  same group touches any of the same files.
- Every task cites the criteria it satisfies. A task satisfying no criterion does not belong here.
- Owned files are exclusive. Two tasks never list the same file.

## Groups

<!-- Groups run in sequence. Tasks within a group run in the order listed, except that
     consecutive [P] tasks may run concurrently. -->

### Group 1 — <name>

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | | AC-001 | | | |
| 1.2 | | AC-002 | | `[P]` | |

### Group 2 — <name>

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|

## Serialised files

<!-- Files that more than one task must touch. Each gets a single owning task; every other task
     that needs a change there requests it from the owner. These are the files that produce
     merges which compile and disagree at runtime. -->

| File | Owning task |
|---|---|

## Test tasks

<!-- Tests are written by the same agent that writes the code they cover — splitting them
     costs more in coordination than it buys. List them here so coverage is planned, not
     discovered at the end. Each criterion needs a positive and a negative case. -->

| # | Covers | Positive case | Negative case |
|---|---|---|---|
