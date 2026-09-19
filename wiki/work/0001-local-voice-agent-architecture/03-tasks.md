# Tasks: offline Flutter voice agent specification

## Legend

Research streams own distinct output reports. Shared architecture decisions, the final PRD and the index have one owner, root. No implementation code is scheduled in this documentation work item.

## Groups

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | Research VAD/STT | AC-001 | research/speech.md | [P] | Cited report exists |
| 1.2 | Research logic/runtime/TTS | AC-001, AC-007 | research/intelligence-tts.md | [P] | Cited report exists |
| 1.3 | Research mobile integration | AC-002, AC-003, AC-005 | research/mobile-systems.md | [P] | Cited report exists |
| 2.1 | Consolidate and validate research/plan | AC-001, AC-008 | 00-research.md and separate research/plan reviews | Serial after research | Findings have recorded dispositions |
| 3.1 | Write specification and decision record | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 | wiki/product/local-voice-agent-prd.md; wiki/adr/0001-offline-voice-architecture.md | Serial | All five chapters and proposed examples present |
| 4.1 | Index, verify and document | AC-008 | wiki/INDEX.md; 04-verification.md; 05-delivery.md; implementation review | Serial | Evidence retained and independent review complete |

## Test tasks

| # | Covers | Positive case | Negative case |
|---|---|---|---|
| 4.1a | AC-001, AC-006 | Cited capabilities and labeled targets | Reject unsupported performance winner |
| 4.1b | AC-002, AC-003 | Bounded ownership and cancel lifecycle | Trace saturated capture, stale output and shutdown callback |
| 4.1c | AC-004, AC-007 | Consistent local-only setup and cleanup | Trace absent asset and initialization failure |
| 4.1d | AC-005, AC-008 | Platform references and discoverable documents | Reject unrestricted background promise; detect plan fences and broken internal links |
