---
id: example-catalog-00-research
title: "Example catalog: 00-research"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "doc/**"]
summary: Deliver selectable verified model downloads and offline reuse in the example.
---

# Research: selectable downloadable example models

## Current behavior and reusable core

The supplied screenshot agrees with example/lib/main.dart: a required Local model folder field is passed directly to LocalModelBundle. No catalog or download UI exists. The current LocalVoiceAgent.create validates local files and creates the native engine; its logic callback uses fixed local demo replies (lib/src/agent.dart and example/lib/main.dart). The existing ModelPreparationManager verifies metadata, streams downloads and atomically activates per-descriptor bundles, but rejects all redirects (lib/src/model_preparation.dart). Static trusted descriptors can reuse that core without inference networking.

The native smoke test accepts nine real asset/WAV paths and requires real recognition, a reply, synthesized audio and playback completion (native/tests/real_engine_smoke.cpp). Existing local runtime and fixtures are identified in /private/tmp/flva-real-repair.log; these are useful comparison material, not catalog provenance or evidence of a newly downloaded pack.

## Upstream candidates

The official sherpa documentation lists the English streaming Zipformer transducer used by this checkout: https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html . Its upstream model repository is https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26 . The existing native smoke uses VITS LJS with lexicon/tokens and Silero VAD. Catalog research must establish pinned revisions, available precision variants, sizes/digests and notices before shipping entries. Mutable main URLs and invented hashes are unacceptable.

## Storage and lifecycle

The example Android MainActivity currently subclasses FlutterActivity without a storage channel; its main manifest lacks INTERNET. The iOS application uses FlutterImplicitEngineDelegate and registers plugins in didInitializeImplicitFlutterEngine (example/ios/Runner/AppDelegate.swift). Platform-specific no-backup private storage can be supplied by this example bridge without changing core inference APIs. The exact storage APIs and available device route are being checked in delegated research.

## Decisions

Use complete compatible English speech packs with clear purpose and size, and expose no unsupported languages or LLM promise. Prefer compact/full precision variants if both are verified. Keep redirect support explicitly opt-in; follow only validated HTTPS hops with a bounded count and unchanged expected hashes. Store separate catalog-id roots to isolate inactive corrupt-cache repair. Persist only known catalog ids. Offline restoration must use a network-disabled client factory; no first-launch download occurs without a button press.

## Unresolved before catalog implementation

Exact catalog asset pins and notices, remote byte verification and platform capacity API evidence remain pending delegated source reports. Physical-device acoustic/thermal qualification and consumer native distribution remain separate existing gates, not reasons to leave the requested example UI manual.

## Catalog and transport findings

The completed machine-readable asset inventory is /private/tmp/flva-catalog-data.json. It selects English compact (INT8), 114,444,636 payload bytes, and English standard (full precision), 383,741,867 bytes. Both use Zipformer revision 672fbf1b30579d6585301139bb363f42a0ad4a24 and VITS LJS revision 7ac337c834f318e45a34037cb3371cc3929187ff, with common Silero VAD SHA-256 9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6. The Silero rolling release URL is pinned by expected content digest and GitHub asset provenance, not an immutable URL; changed bytes must fail integrity rather than silently update. Source model cards declare Apache-2.0 and are installed alongside its full text; Silero's pinned MIT notice is included. This records upstream declarations, not a new redistribution grant.

HTTPS source redirects observed by the asset researcher reach https://us.aws.cdn.hf.co and https://release-assets.githubusercontent.com. Only these explicitly recorded extra origins and the original source origin will be allowed by the catalog flow. Signed temporary targets will not be stored in catalog data. The redirect source audit at /private/tmp/flva-download-research.md cites the pinned Dart SDK and https://api.dart.dev/dart-io/HttpClientRequest/followRedirects.html: manual GETs with followRedirects disabled permit per-hop validation without copying credentials. Redirect responses must be discarded with bounded consumption or cancelled, never aggregated as model bytes.

The platform source audit at /private/tmp/flva-example-research.md identifies Android noBackupFilesDir with StatFs.availableBytes and iOS Application Support with isExcludedFromBackup and volumeAvailableCapacityForImportantUsage. The example storage bridge will return only its own directory/capacity. Coordinator adb device inspection with sandbox elevation returned emulator-5554, sdk_gphone64_arm64; no physical device was present. The selected private per-id subroots and explicit repair prevent deletion of other catalog installations. The capacity check is advisory; write failures still require typed handling.

The earlier unresolved metadata/platform points above are superseded by these concrete choices. Exact downloaded-byte and real engine evidence from the catalog researcher is retained in its report, with coordinator reproduction required for acceptance. Physical-device qualification remains unresolved and outside this example demonstration.
