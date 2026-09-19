---
id: pipeline-00-research
title: "Research: native offline pipeline"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation work artifact and evidence boundaries.
---

# Research: native offline pipeline

## Question

Can the specification be implemented using exact native APIs and the installed mobile toolchain?

## Answer

The v1.12.14 sherpa C API provides worker-owned VAD, streaming ASR and callback TTS. The llama.cpp b10976 API provides bounded CPU decoding and cooperative abort. These are source-level findings, not integration proof. Flutter 3.47.0 with Dart 3.13.0 executes when the SDK cache is writable. No models were present at baseline.

## Findings

See [speech](research/speech.md), [mobile](research/mobile.md), and [LLM](research/llm.md) for primary sources, exact API signatures, command output and unresolved claims. Source/header downloads work with approved network access; the initial sandbox DNS failure is not an absolute network blocker. The pinned Flutter version command returned Flutter 3.47.0 and Dart 3.13.0 after approved cache access.

## Options considered

| Option | Decision |
|---|---|
| Native sherpa C API | Selected to keep inference and PCM native and expose callback cancellation |
| Dart PCM relay | Rejected because audio transport would depend on Flutter message delivery |
| Mandatory LLM | Rejected; deterministic commands require no generative weights |
| Native OS speech | Not the default because app-owned offline model inventory is required |

## Constraints discovered

Inference cancellation is cooperative; generation gates must independently suppress output. TTS callbacks do not accept streaming text. No model pack is approved for redistribution. Exact native binaries and model hashes must be captured during qualification; source API evidence is insufficient.

## Unresolved

- [UNRESOLVED: Actual Android/iPhone availability and acoustic qualification.]
- [UNRESOLVED: Exact release binary/model hashes, complete license inventory and real inference proof.]
- [UNRESOLVED: Ratified quality/latency/thermal budgets and comparison corpus.]

## Sources

The three delegated reports above were consulted on 2026-09-19. Existing PRD and ADR remain the requirements; this work does not claim that their earlier documentation verdict proves implementation.
