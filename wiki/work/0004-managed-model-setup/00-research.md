---
id: managed-model-00-research
title: "Managed model setup research"
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "android/**", "ios/**", "doc/**"]
summary: Planned managed model setup; no runtime implementation is delivered by this record.
---

# Research: managed model setup

## Question

How can the library own model preparation so developers and example users do not manage device paths or model manifests?

## Answer

Propose one recommended, versioned speech bundle with explicit first-download preparation and subsequent offline reuse. Preserve local imports and the existing offline creation path. A curated catalog can grow later after each bundle is qualified; a general model browser is not the initial deliverable.

## Findings

- The example asks for a device directory and constructs a manifest path before creating the agent. Its reply function is deterministic; it does not enable the optional LLM. Sources: `example/lib/main.dart`, `lib/src/agent.dart`.
- `FileModelStore` checks sizes, hashes, roles, paths and license references, and stages a copy from a local source. It has no downloader, catalog or application-storage discovery. Its profile is currently restricted to `en-US-sherpa-vits` and runtime `1.12.14`. Sources: `lib/src/model_store.dart`, `lib/src/contracts.dart`.
- Speech requires compatible VAD, recognition and synthesis assets. A GGUF is optional and cannot substitute for the speech bundle. Native configuration is an online transducer plus lexicon-based VITS, not a generic loader for every sherpa model. Sources: `native/src/flva.cpp`, `doc/models.md`, `doc/llm.md`.
- Native dependencies are separately provisioned before building; optional LLM support requires a separately included engine. Downloaded weights cannot add an omitted native engine. Sources: `README.md`, `tool/provision_runtime.py`, `android/src/main/cpp/CMakeLists.txt`, `ios/flutter_local_voice_agent.podspec`.
- App-private Android storage can avoid manual paths and broad storage permissions. Background iOS downloads need an explicit background URLSession design; a foreground downloader must not promise that behavior. Sources: official platform references below.
- Current product documentation excludes SDK downloads. The proposed managed preparation path changes that policy explicitly while preserving offline inference and local creation. Source: `wiki/product/local-voice-agent-prd.md`, section Offline contract.
- Model distribution and physical-device qualification remain unresolved in the existing pipeline. Its open VITS allocation issue is separate from installation UX and is not closed by this proposal. Sources: `wiki/work/0002-native-offline-pipeline/STATE.yaml`, `doc/models.md`.

## Options considered

| Option | Cost and tradeoff | Decision |
|---|---|---|
| Manual local pack only | Small SDK surface; substantial first-use setup | Retain for advanced/offline use, remove from primary example journey |
| One fixed bundle with no future metadata model | Simple start; hard to extend for languages and voices | Use one default initially, but give it a versioned descriptor |
| Recommended bundle backed by a curated catalog | Library owns compatibility and installation | Recommended; initially publish only a qualified default |
| Large model picker | More support, qualification and UX complexity | Defer until concrete compatible alternatives exist |
| Bundle all weights with every app | Offline first launch; larger app download | Optional developer distribution path, not mandatory default |

## Constraints discovered

No claim of universal language support, production readiness, device speed or download size follows from choosing this UX. Runtime libraries remain build-time dependencies. An integrity hash is only trusted when its expected value comes from a trusted source; an untrusted downloaded manifest is insufficient.

## Unresolved

- [UNRESOLVED: exact default files, pinned revisions, distribution rights and notices, and download host.]
- [UNRESOLVED: measured download/installed/peak installation sizes and supported physical-device resource limits.]
- [UNRESOLVED: final public API names and native dependency packaging mechanism.]
- [UNRESOLVED: required languages beyond the initial English candidate; Hebrew support is UNVERIFIED.]

## Sources

Repository sources above inspected on 2026-09-20. Official sources consulted on 2026-09-20 during the preceding assessment:

- https://developer.android.com/training/data-storage/app-specific
- https://developer.apple.com/documentation/foundation/downloading-files-in-the-background
- https://k2-fsa.github.io/sherpa/onnx/pretrained_models/index.html
