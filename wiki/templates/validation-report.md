<!-- Copy to wiki/work/NNNN-slug/validation/<phase>-review-NN.md where <phase> is research,
     plan or impl, and NN starts at 01. NEVER overwrite an earlier round.

     Delete the guidance comments as you fill each section. -->

# <Phase> review — round NN

- Work item: <NNNN-slug>
- Reviewed artifact: <path, and git revision if reviewing a diff>
- Reviewer: <agent name>
- Date: <YYYY-MM-DD>

## Verdict

<!-- PASS | CONDITIONAL | FAIL -->

**<VERDICT>**

<!-- One sentence justifying the verdict. Not a summary of the artifact — a justification of
     the verdict. -->

## Verification performed

<!-- The commands you ran and their pasted output. You must run them yourself. You may not
     rely on the author's statement that they were run, and you may not rely on the author's
     statement that a previous finding was fixed. Re-run the check, not the claim. -->

## Per-criterion results

<!-- Implementation reviews only. Every criterion gets a row. Silence on a criterion is a
     failure of the review, not a pass for the code. -->

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass / fail | | yes / no |

## Findings

<!-- One subsection per finding, numbered F-001 upward within this report. Every finding names
     a file and a line. Do not propose the fix — naming the defect and its location is the
     whole job. Flag as BLOCKER or IMPORTANT only what affects correctness or a stated
     criterion; everything else is a NIT. -->

### F-001 — <one-line summary>

- Severity: BLOCKER | IMPORTANT | NIT | PRE_EXISTING
- Location: `<file>:<line>`
- Criterion affected: AC-NNN, or none
- Observation:
- Why it matters:

## Recurrence check

<!-- Compare this round's findings to the previous round's. Name any finding that is materially
     identical to one already reported. This is evidence for the main agent, not a verdict:
     it decides whether recurrence means the loop is oscillating and escalation is warranted. -->

- Previous round: <path, or "none — first round">
- Recurring findings: <IDs, or "none">
- Oscillating: yes / no

## Routing

<!-- Which phase each blocker belongs to. A plan defect goes back to the plan phase; an
     implementation defect to the implement phase. Never patch code to close a plan-level
     finding. -->

| Finding | Belongs to phase |
|---|---|
