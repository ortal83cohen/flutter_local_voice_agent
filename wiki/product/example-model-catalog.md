---
id: example-model-catalog
title: Selectable speech models in the example
status: active
owner: root
last_verified: 2026-09-20
applies_to: ["lib/src/model_catalog.dart", "example/**", "doc/model-catalog.md"]
summary: Real pinned English model choices, explicit first download and private offline reuse in the example.
---

# Selectable speech models

The example offers complete English speech bundles: compact INT8 (114,444,636 bytes) and full precision (383,741,867 bytes). They use the same LJS voice, Zipformer recognizer and Silero detector; this is a precision choice, not a speaker or language selector. `VoiceModelCatalog.entries` exports exact content metadata, publisher notices and observed CDN origins. The source inventory is tool/model_catalog_inventory.json.

Users select, explicitly download and then start conversation without paths or manual copies. The example stores separate per-id installations in platform-private persistent no-backup storage, retains the selection and restores it with networking disabled. Backgrounding cancels preparation and stops listening. Failed setup cannot enable Start. Responses are fixed local demonstration logic; no general LLM model is advertised.

The [consumer guide](../../doc/model-catalog.md) documents sources, API, storage, recovery and actual limits. The [work item](../work/0006-example-model-catalog/STATE.yaml) records verification state. Real downloaded-file host inference, Android emulator behavior, iOS compilation and physical-device qualification are separate evidence categories. Full native consumer distribution and the VITS allocation blocker remain open.
