# Acceptance criteria: local voice agent specification

## Frozen

- Frozen at: 2026-09-19; before documentation implementation.
- Frozen by: root.

## Criteria

| ID | Criterion | How it is checked | Negative case |
|---|---|---|---|
| AC-001 | When reading the research, a developer can compare representative open and native VAD, STT, intelligence/runtime and TTS alternatives using dated primary sources, explicit selection reasoning, license distinctions and unresolved questions. | Independent research review and source spot checks. | Reject universal coverage or numerical superiority claims without evidence. |
| AC-002 | When following the architecture, an implementer can identify data formats, buffer ownership and bounds, resampling boundaries, threading, backpressure and end-to-end timing measurement. | Trace one turn and queue saturation through the specification. | Reject an unbounded queue or real-time callback that waits on Dart or inference. |
| AC-003 | When interruption, cancellation, route loss or shutdown occurs, the specification identifies state transitions and prevention of stale audio and native use-after-free. | Trace failure scenarios and ownership lifecycle. | Reject completion events from a cancelled turn changing the current turn or freeing an active callback's memory. |
| AC-004 | When using the proposed Dart API, a reader finds mutually consistent declarations and examples for local asset setup, configuration, lifecycle, event subscriptions, interruption, errors and cleanup, explicitly labeled as unimplemented. | Compare example symbols with the proposed interface and behavior contract. | Reject invented existing package exports or a cleanup path that leaks an owned subscription. |
| AC-005 | When planning Android/iOS delivery, a reader can identify permission, foreground/background, audio focus/session, route and thermal constraints, with primary-source references. | Independent platform constraint review. | Reject unconditional background microphone or cloud fallback guarantees. |
| AC-006 | When executing the roadmap, a team has MVP, streaming/optimization and release phases with deliverables, exit gates, unit/integration/device tests and benchmark methodology. | Check each phase and proposed performance gate. | Reject targets represented as observed benchmark results or desktop-only proof of mobile functionality. |
| AC-007 | When applying the offline contract, the specification covers asset provisioning, absent models, integrity/license manifests, network prohibition, local data retention and deterministic logic without requiring an LLM. | Trace fresh-install and airplane-mode scenarios. | Reject hidden model download, implicit cloud fallback or mandatory LLM usage. |
| AC-008 | When navigating the repository, a reader can reach the final English PRD and supporting research, plan, review and evidence artifacts from the wiki index; the prose-only plan and wiki checks comply with repository conventions. | Run wiki lint and inspect index links and evidence. | Reject fenced code in 01-plan.md, missing document links or claims of a working SDK. |

## Explicitly not required

This work delivers research and a technical specification, not implementation of the SDK. Device benchmark numbers, a published package, legal approval to redistribute any model, compiled production SDK examples and actual background/audio behavior are not asserted. Proposed product validation gates remain future development work. Repository format/analyzer checks will be attempted and their actual outputs recorded; absent toolchains are reported separately from document quality.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
| 01 | 2026-09-19 | PASS (documentation) | validation/impl-review-01.md |
