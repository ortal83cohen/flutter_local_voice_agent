---
id: adr-0004-english-vits-voice-selection
title: VCTK plus integer speaker id as the English lexicon voice
status: active
owner: root
last_verified: 2026-09-21
applies_to: ["lib/src/model_catalog.dart", "lib/src/agent.dart", "lib/src/contracts.dart", "native/**", "example/**"]
summary: Keep both LJS precision packs and add one compact VCTK bundle whose speakers are selected by integer id.
---

# VCTK plus integer speaker id as the English lexicon voice

## Context

The shipped catalog already offered two complete English LJS packs that differ by precision, not by speaker. The native VITS lexicon loader hard-coded speaker id 0. Official sherpa English lexicon voices are LJS and VCTK. Piper Lessac and other English data-directory voices leave that contract. The question was which English voice the catalog and example should add without replacing the verified LJS fixture or changing the complete-bundle preparation model.

## Decision

Keep both existing LJS precision packs at speaker count 1. Add one compact VCTK complete English bundle at speaker count 109. Expose speaker choice as an integer id that defaults to 0 on create. After the synthesizer exists, the native session asks sherpa for the speaker count and rejects an id outside 0 inclusive through count minus one. A live setter updates the stored id for the next generated reply without downloading, disposing the session, or interrupting an utterance already in flight. A rejected setter leaves the previous id and the session in place.

The example shows integer labels 0 through 108 only when the selected option has more than one speaker. It persists catalog id and speaker id together. LJS hides the speaker control and treats a missing saved speaker field as 0. VCTK refuses Start while the saved id is out of range.

This choice does not rank quality, name speakers, add a language, or close the open VITS allocation and physical-device gates. The earlier catalog decision in [ADR 0003](0003-example-model-catalog.md) remains the record of trusted pins, bounded CDN redirects and example-owned storage.

## Alternatives rejected

Replacing LJS with VCTK would discard the already verified LJS fixture and the precision pair that hosts already download.

Adding Piper English voices would require an eSpeak data directory, reopen the GPL inventory, and leave the VITS lexicon loader. That path stays deferred.

Shipping both VCTK INT8 and full-precision packs would duplicate the large Zipformer recognizer download a second time. One compact VCTK pack is enough to offer speakers.

A TTS-only overlay that shares one recognizer install across catalog ids would break the complete-bundle catalog contract from work item 0006. Each catalog id remains a full speech bundle.

## Consequences

Hosts see three English options and can change VCTK speaker without another download. The example control is an integer list, not a named-voice picker. Adding VCTK still repeats Silero and Zipformer bytes under a new id. Piper, Hebrew and other languages stay out of this catalog. A later reversal supersedes this decision and leaves ADR 0003 in place.

## Confirmation

Catalog tests assert three English options with speaker counts 1, 1 and 109. Native create and setter tests reject an out-of-range id without writing it or destroying the session. Example storage and controller tests persist both fields, hide speakers for LJS, and refuse an illegal VCTK restore. Wiki lint requires this file to stay reachable from the index.
