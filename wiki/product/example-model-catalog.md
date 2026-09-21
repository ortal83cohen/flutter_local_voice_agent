---
id: example-model-catalog
title: Selectable speech models in the example
status: active
owner: root
last_verified: 2026-09-21
applies_to: ["lib/src/model_catalog.dart", "example/**", "doc/model-catalog.md"]
summary: Three pinned English speech bundles, VCTK integer speaker ids, explicit first download and private offline reuse in the example.
---

# Selectable speech models

The example offers three complete English speech bundles: compact LJS INT8 (114,444,636 bytes), full-precision LJS (383,741,867 bytes), and compact VCTK INT8 (116,261,194 bytes). The two LJS packs share one speaker, the Zipformer recognizer and the Silero detector; that pair is a precision choice, not a speaker or language selector. The VCTK pack reuses those compact recognizer and detector files and substitutes a 109-speaker VITS lexicon voice. Speaker labels are integer ids 0 through 108. The example shows the speaker control only for VCTK and hides it for LJS. This is a speaker choice, not a quality ranking. `VoiceModelCatalog.entries` exports exact content metadata, publisher notices, speaker counts and observed CDN origins. The source inventory is tool/model_catalog_inventory.json.

Users select, explicitly download and then start conversation without paths or manual copies. The example stores separate per-id installations in platform-private persistent no-backup storage, retains the catalog id and speaker id, and restores both with networking disabled. A missing speaker field falls back to 0 for every pack. Start is refused when a saved VCTK speaker id is outside 0 through 108. Changing speaker on a ready VCTK session updates the live id without another download. Changing catalog pack disposes the previous session first. Backgrounding cancels preparation and stops listening. Failed setup cannot enable Start. Responses are fixed local demonstration logic; no general LLM model is advertised.

The [consumer guide](../../doc/model-catalog.md) documents sources, API, storage, recovery and actual limits. The [catalog architecture decision](../adr/0003-example-model-catalog.md) records the trusted catalog and example storage. The [voice-selection architecture decision](../adr/0004-english-vits-voice-selection.md) records VCTK plus speaker id. The [catalog work item](../work/0006-example-model-catalog/STATE.yaml) records the original catalog verification state. The [voice-selection work item](../work/0009-english-vits-voice-selection/STATE.yaml) records the speaker-control work. Real downloaded-file host inference, Android emulator behavior, iOS compilation and physical-device qualification are separate evidence categories. Full native consumer distribution and the VITS allocation blocker remain open. Piper, other languages and named speaker metadata remain outside this catalog.
