---
id: example-catalog-delivery
title: Example catalog delivery and qualification boundaries
status: active
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "doc/**"]
summary: The example selects, downloads and restores real speech bundles without manual model paths.
---

# Delivered behavior

The example now offers compact INT8 and standard full-precision English speech bundles, with exact download sizes, progress, cancellation, retry and source/license details. It downloads into app-private persistent no-backup storage, verifies every file, remembers the selected bundle and restores it offline. Start is unavailable until the native engine is ready. Backgrounding cancels preparation and stops listening; corrupted copies have an explicit recovery action.

The coordinator installed the final Android debug build and exercised a new compact download, cancel/retry, Start/Stop, and force-stop/relaunch plus listening with both emulator network services disabled. The app remains installed with the compact bundle available; the existing standard bundle was preserved. The final iOS simulator build also compiled successfully.

The [verification record](04-verification.md) contains exact commands and outputs: 63 package tests, 16 example tests, seven full-check stages, both real catalog downloads and host recognition/reply/synthesis using their installed files. The [consumer guide](../../../doc/model-catalog.md) explains normal use. No manual directory entry, copying of weights or manifest authoring is required in this example.

# Boundaries

Both entries use the same English LJS voice with different model precision. The response function is fixed local demonstration logic, not a general LLM. Real host inference, emulator setup/listening state, iOS compilation and physical-device audio qualification are distinct. Native package distribution, physical Android/iPhone measurements and the prior VITS whole-sentence allocation blocker remain separate open gates. The example requires the existing provisioned native checkout to build.

Git staging and publication were not performed by this task. The byte-identical source snapshot passed packaging without modifying the user's dirty index; six whitespace-only lines in an older append-only review remain explicitly outside this work item's clean scoped check.

# Independent acceptance

The [implementation review](validation/impl-review-01.md) returned PASS on all seven criteria with no findings. It independently ran the package/example suites, five additional controller failure probes, actual cache-corruption rejection, both real native model configurations and 19 native failure checks. The coordinator accepted that verdict and closed this scoped delivery; no broader release qualification is implied.
