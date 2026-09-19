# Plan: offline Flutter voice agent research and specification

## Goal

Deliver an English technical PRD and implementation architecture for flutter_local_voice_agent. The deliverable gives developers a justified engine shortlist, explicit offline contract, bounded audio pipeline, proposed SDK interface, resource lifecycle and phased implementation/test strategy. It does not claim that the SDK already exists.

## Approach

Three independent researchers examine speech recognition, intelligence and speech synthesis, and mobile systems integration. Each owns a separate report and uses current primary sources. The coordinator synthesizes these findings without conducting the technology research itself. Recommendations remain conditional on language, device, model license and measured performance rather than a universal fastest-engine claim.

The final specification lives in wiki/product/local-voice-agent-prd.md. It contains the requested five chapters, diagrams and proposed Dart examples. This prose-only plan describes the documentation work; code examples belong only in the specification. The research consolidation lives in 00-research.md, and raw reports remain linked so evidence and uncertainty are inspectable.

## Why this approach

Independent parallel research separates engine capabilities from platform constraints. A single architecture author prevents conflicting audio formats and cancellation semantics. A blind research validator checks evidence, while a separate blind plan validator checks this plan against the criteria. A final independent reviewer checks the completed specification. Choosing an engine first or inferring phone performance from desktop demonstrations would not satisfy the request.

## Steps

1. Produce the three scoped research reports under this work item's research folder and record current sources and open questions.
2. Consolidate the evidence into 00-research.md and record justified provisional choices. Keep unknown measurements explicitly unverified.
3. Review the research and this plan in independent fresh contexts against 02-criteria.md; record each finding and disposition in STATE.yaml.
4. Freeze the criteria, then write the five-chapter PRD, including the proposed interface, data-flow diagram, state machine, resource contracts, benchmark gates and implementation roadmap. Add a draft architecture decision record describing conditional backend selection.
5. Update the wiki index and run repository documentation checks. Attempt the specified Dart formatting and analysis checks and retain outputs without claiming mobile runtime verification.
6. Have a fresh independent reviewer inspect the deliverable against each criterion, including negative scenarios. Resolve findings at the phase where they belong, record evidence and document the final delivery status.

## Interfaces and shared decisions

Android and iOS are the first delivery targets. Desktop is an extension and web is outside the first release. Offline means no required network during setup or inference when the host provides bundled or locally imported assets; missing models fail explicitly. Deterministic local business logic is a first-class alternative to a local language model. All API names in the PRD are proposals, not assertions about existing exports.

The architecture author alone decides final SDK naming, audio buffer contracts, state transitions and backend selection after research arrives. Shared research assumptions use mono floating-point audio with explicit sample rates as a candidate transport, never a claim that every model accepts the same rate. Hardware measurements and model redistribution approval are deferred gates, not fabricated evidence.

## Risks

| Risk | Likelihood | Impact | Mitigation | Trigger that means it happened |
|---|---|---|---|---|
| Source describes desktop capability only | Material | Invalid mobile recommendation | Require mobile-specific evidence or an explicit qualification gate | Backend lacks verified Android/iOS route |
| Model license differs from runtime | Material | Distribution cannot proceed | Separate engine and model manifests and require release review | Selected weights have incompatible or unclear terms |
| Proposed API examples diverge | Material | Implementer ambiguity | Single-author interface and independent cross-check | Example uses an undeclared member |
| Target performance is unmeasured | Certain at planning stage | Unrealistic promise | Label targets and define reproducible device benchmark | Any target is presented as achieved |
| Toolchain unavailable | Possible | Cannot execute Dart checks | Paste actual output and distinguish documentation checks | Required command cannot start |

## Rollback

No runtime files or package dependencies are changed. If the specification is replaced, mark the product document and ADR superseded and link their replacement. Keep historical work artifacts and review reports. Unaccepted backend choices are reversed through a superseding architecture decision before implementation, not by deleting the research trail.

## Out of scope

No application or native SDK implementation, dependency installation, model downloads, commercial licensing decision, commit, publication or deployment is part of this work. There is no promise of exhaustive coverage of every engine or a universal multilingual/latency winner.

## Verification approach

Review the deliverable using the eight criteria, exercising their negative scenarios as document inspections. Run the wiki linter and link/structure checks; attempt the repository's Dart formatting and fatal analysis commands. Record exact commands and output in an evidence artifact. Distinguish specification consistency from SDK compilation and real-device validation. The final reviewer receives criteria, artifacts and rubric, never the authoring conversation.
