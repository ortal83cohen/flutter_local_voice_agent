---
id: adr-example-model-catalog
title: Static speech catalog and example-owned private storage
status: active
owner: root
last_verified: 2026-09-20
applies_to: ["lib/src/model_catalog.dart", "lib/src/model_preparation.dart", "example/**"]
summary: Expose verified static speech choices and keep platform setup in the example while preserving offline core contracts.
---

# Decision

Use a shipped, content-pinned English speech catalog, with compact and full-precision configurations of the same known-compatible architectures. Do not trust a remotely fetched manifest or expose unsupported arbitrary models. Each file retains exact expected length, SHA-256, source and license reference. Publisher redirects are needed for stable source URLs, so preparation adds an explicit zero-by-default redirect limit and exact extra-origin allowlist. Each GET is independently configured; redirect bodies are cancelled and signed endpoints are never persisted.

The example owns its private no-backup directory, disk-capacity preflight and saved selection through a small platform method channel. This avoids adding storage/preferences dependencies or pretending the broader library-managed storage API is complete. A separate subdirectory for each known catalog id isolates inactive corrupt-pack repair. Restoration disables networking; only a user download action enables a client.

Keep the existing native inference pipeline and local reply callback. A downloadable speech configuration is not a general-purpose LLM. Background, active-session and asynchronous disposal guards are part of the visible workflow. Physical-device quality, arbitrary voices/languages, updates, automatic orphan cleanup and native consumer packaging remain separately tracked work.
