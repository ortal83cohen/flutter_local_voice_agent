---
id: offline-voice-architecture
title: Adapter-based offline voice pipeline with native audio ownership
status: draft
owner: unassigned
last_verified: 2026-09-19
applies_to: ["lib/**", "android/**", "ios/**"]
summary: Proposes native bounded audio, interchangeable speech adapters and optional local intelligence, subject to model and device qualification.
---

# ADR 0001: Adapter-based offline voice architecture

## Status

Proposed. This records a design choice for the future SDK, not a claim of implemented behavior, device qualification or model redistribution approval.

## Context

The requested package must perform microphone capture, VAD, STT, local intelligence, TTS and playback without network dependence. Engine support, weight licenses, Flutter bindings, audio processing and platform lifecycle are separate constraints. See the [delegated research](../work/0001-local-voice-agent-architecture/00-research.md) and [technical specification](../product/local-voice-agent-prd.md).

## Decision

Use a Dart developer facade, OS lifecycle control through native platform integration, and a native audio/inference data path with bounded ownership. Hide engines behind versioned adapters and explicit capabilities. Start qualification with Silero/sherpa streaming ASR, deterministic logic and a sherpa TTS adapter. Make llama.cpp an optional LLM adapter rather than imposing its footprint on all users.

Model/voice choices are conditional. No pack ships without pinned assets, source provenance, full runtime/phonemizer/model license inventory, quality results and physical-device verification. Keep offline provisioning local and fail on missing assets instead of downloading or falling back to a server.

Begin with foreground half-duplex plus manual interruption. Promote full duplex only for routes with demonstrated AEC and barge-in quality. Native output generation gates silence stale work before eventual worker cleanup; disposal must wait for safe ownership release.

## Alternatives considered

A channel-only PCM pipeline simplifies early Dart prototyping but makes the hardware path depend on message transport and scheduling. A single mandatory LLM runtime excludes small deterministic use cases. OS-only speech does not provide a portable app-controlled model inventory. whisper.cpp, Moonshine, Vosk and LiteRT-LM remain credible alternatives when model/language/device measurements justify replacing an adapter. Oboe remains an Android optimization candidate after its echo-processing path is qualified.

## Consequences

The project owns native lifetime and packaging complexity, but gains explicit buffer bounds, cancellation semantics and replaceable models. Separate optional backend distribution avoids shipping every runtime. TTS transitive licensing and real-device performance are release gates; the initial architecture does not resolve them by assumption.

## Reconsideration and rollback

Reconsider an adapter when its model rights, binding support, cancellation or measured quality/resource profile fails the Phase 0 gates. Preserve the public contract while replacing the adapter through a superseding ADR. Supersede this document rather than deleting it if the whole architecture changes.
