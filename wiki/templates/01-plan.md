<!-- Copy to wiki/work/NNNN-slug/01-plan.md.

     PROSE ONLY. This file must contain zero fenced code blocks, zero snippets and zero
     pseudo-code. tools/lint_wiki.py fails the build if it finds any. Name the file, the
     function and the change in words; do not write the change out.

     Delete the guidance comments as you fill each section. -->

# Plan: <work item title>

## Goal

<!-- One paragraph. What will be true after this change that is not true now. Stated as an
     outcome a user or another system can observe, not as an activity. -->

## Approach

<!-- Two to four paragraphs describing the approach in words. Name the components, the files
     and the interfaces involved. Explain the shape of the solution, not its syntax. -->

## Why this approach

<!-- Name the alternatives considered and say why each was rejected. Reference the research
     artifact. A plan with no rejected alternatives has not chosen anything. -->

## Steps

<!-- Numbered, in execution order. Each step names what it touches and what is true when it
     is complete. A step that cannot be described without code is too large — split it. -->

1.
2.
3.

## Interfaces and shared decisions

<!-- The decisions every step must build against: naming, data shapes, error handling,
     configuration. Decide them here. Once implementation fans out, these cannot be
     renegotiated without a new validation round. -->

## Risks

<!-- One row per risk. A risk with no mitigation and no trigger is a wish. -->

| Risk | Likelihood | Impact | Mitigation | Trigger that means it happened |
|---|---|---|---|---|

## Rollback

<!-- How this change is undone if it turns out to be wrong. A plan with no rollback is a
     one-way door and must be escalated before implementation. -->

## Out of scope

<!-- What this work item deliberately does not do. Every item here is a defence against
     scope creep during implementation. -->

## Verification approach

<!-- In words: how the acceptance criteria in 02-criteria.md will be checked. Which commands,
     which fixtures, which negative cases. -->
