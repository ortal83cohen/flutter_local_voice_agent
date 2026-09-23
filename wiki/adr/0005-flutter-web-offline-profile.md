---
id: adr-0005-flutter-web-offline-profile
title: "ADR 0005: Separate WASM session for Flutter web"
status: active
owner: root
last_verified: 2026-09-22
applies_to: ["lib/**", "pubspec.yaml", "example/web/**"]
summary: Accepted decision to add a web-only sherpa WASM backend instead of reusing flva.h or depending on sherpa_onnx.
---

# ADR 0005: Separate WASM session for Flutter web

- Status: accepted
- Date: 2026-09-22
- Deciders: coordinating agent for work item 0010 after implementation of the web backend

## Context and problem statement

Can this strictly offline voice agent run on Flutter web without replacing the native flva session on Android, iOS, macOS, Windows and Linux, and without using cloud or browser speech APIs?

## Decision drivers

1. Offline inference with app-owned models.
2. Same Silero and sherpa family as the native catalog.
3. No collision with libflva or a second native microphone plugin.
4. Public LocalVoiceAgent facade stays stable for native hosts.
5. Honest limits: first slice is VAD plus non-streaming ASR and compact VITS.

## Considered options

1. Keep excluding Flutter web.
2. Load flva.h in the browser.
3. Depend on the pub.dev sherpa_onnx plugin and record.
4. Compile flva.cpp with Emscripten.
5. Use Web Speech or another engine family.
6. Add an internal web session backend that vendors official sherpa-onnx WASM and owns audio through package web.

## Decision outcome

Choose option 6. Work item 0010 implemented that backend.

Option 1 ignored the product request. Option 2 is not possible. Option 3 pulls native sherpa plugins and a second microphone plugin into consumer apps. Option 4 duplicates official WASM packaging and still needs JS audio. Option 5 breaks the offline or engine-family contract.

PCM may exist inside the web backend. That is a recorded exception to ADR 0001, limited to Flutter web. Native hosts still forbid PCM on the method channel and still own audio in OS callbacks. ADR 0001 is not superseded.

## Consequences

The package compiles without dart:io on the web library graph. WASM assets are pinned and attributed. The plugin package does not ship catalog weights. Native provisioning and flva stay on v1.12.14. Web WASM is pinned to 1.13.8. Streaming Zipformer, full-precision LJS and local LLM stay out of the first slice.

Browser microphone-to-speaker evidence and compact-catalog ONNX load in 1.13.8 WASM remain [UNVERIFIED].

## Validation and follow-through

Implementation is measured against wiki/work/0010-flutter-web-offline-profile/02-criteria.md.

## Rollback

Remove the web backend and restore the unsupportedProfile guard for Flutter web. If this decision is rolled back, supersede this ADR. Do not delete it. Native behavior remains the ADR 0001 path.

## Supersession

This document does not supersede ADR 0001, ADR 0002, ADR 0003 or ADR 0004.
