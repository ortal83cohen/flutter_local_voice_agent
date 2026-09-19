---
id: pipeline-02-criteria
title: "Acceptance criteria: Native offline voice pipeline"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation work artifact and evidence boundaries.
---

# Acceptance criteria: Native offline voice pipeline

## Frozen

- Frozen at: 2026-09-19
- Frozen by: root

## Criteria

| ID | Criterion | How checked | Negative case |
|---|---|---|---|
| AC-001 | Local manifest preflight verifies exact roles, versions, sizes and SHA-256 before native load or microphone activation; staged import never activates invalid assets. | Dart filesystem tests | Missing, corrupt, traversal, symlink escape, wrong role/version |
| AC-002 | Public typed lifecycle/events/errors support start, stop, interrupt and safe idempotent disposal with bounded event and logic delivery. | Dart tests and platform integration | Double commands, paused listener, late reply, native failure |
| AC-003 | Native input/output/event buffers have explicit limits and reject stale generations; worker ownership prevents release during inference. | Native tests and sanitizers | Overflow, underflow, cancel, stop during work, double close at facade |
| AC-004 | Real pinned Silero, streaming STT and VITS TTS run off UI with bounded response and PCM, deterministic local logic and no runtime network. | Real model smoke and source/build inspection | Missing engine/model, overlong utterance/reply/output, cancelled synthesis |
| AC-005 | Android and iOS native bridges provide microphone, playback, permission and foreground lifecycle controls without callbacks waiting on Dart/inference. | Platform builds and physical test matrix | Denial, focus/interruption, route loss, thermal suspension, background |
| AC-006 | Optional llama.cpp consumes only a local model with bounded context and output, and invalidates cancelled work. | Pinned API compilation and real GGUF integration | Missing model, excessive prompt, cancellation |
| AC-007 | Example, capability table, exact build/model instructions, notices, changelog and package checks reflect actual verified behavior. | Wiki lint, analysis, package dry run, guide walkthrough | Missing model and unsupported full duplex remain explicit |
| AC-008 | Offline physical Android and iPhone trials and performance methodology retain raw evidence and all open gates. | Physical qualification report | Network denied, repeated lifecycle/cancel, adverse routes/thermal |

## Non-functional criteria

No inference on UI/audio callback threads; no hidden network fallback; no unlimited queue; no model distribution claim without evidence. AC-003 through AC-008 cover these properties.

## Explicitly not required

Publication, bundled model redistribution, background operation and AEC-qualified full duplex are not claimed. Missing physical resources keep AC-008 open rather than allowing simulated evidence to count.

## Verdict log

| Round | Date | Verdict | Report |
|---|---|---|---|
