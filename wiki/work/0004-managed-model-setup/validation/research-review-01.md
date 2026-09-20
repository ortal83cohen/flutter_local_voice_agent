---
id: managed-model-research-review-01
title: "Managed model setup research review round 1"
status: draft
owner: reviewer
last_verified: 2026-09-20
applies_to: ["wiki/**"]
summary: Independent research-only review confirms source grounding and explicit unresolved implementation gates.
---

# Verdict: PASS

This verdict covers the draft research's accuracy and evidence boundaries. It does not accept the future runtime implementation or certify AC-001 through AC-010 as implemented. The criteria explicitly reserve asset selection, distribution, API naming and native packaging decisions for a later reviewed freeze.

## Findings

No research defects found in the assigned scope. Current source supports the manual-directory example, deterministic replies, local-only validation and staging, restricted speech profile, online transducer and lexicon-based VITS configuration, and separately provisioned native dependencies. The proposed managed workflow is clearly separated from current behavior.

## Pre-existing and pending items

- PRE_EXISTING — `wiki/work/0002-native-offline-pipeline/STATE.yaml:11`: the VITS synthesis-allocation bound remains open. The research accurately preserves that limitation at `wiki/work/0004-managed-model-setup/00-research.md:29`.
- PRE_EXISTING — `wiki/work/0002-native-offline-pipeline/STATE.yaml:12`: physical mobile qualification remains unavailable. No physical-device success is asserted by this research.
- Explicit research limits, not review defects — `wiki/work/0004-managed-model-setup/00-research.md:47`: default assets, distribution, measurements, API names, native packaging and additional language qualification remain unresolved. No values, rights or supported devices were inferred.
- Wiki index/pending integration: the wiki linter reported no issue in the snapshot checked below.

## Checks and evidence

Independently inspected `example/lib/main.dart`, `lib/src/agent.dart`, `lib/src/contracts.dart`, `lib/src/model_store.dart`, `native/src/flva.cpp`, `README.md`, `tool/provision_runtime.py`, `android/src/main/cpp/CMakeLists.txt`, `ios/flutter_local_voice_agent.podspec`, `doc/models.md`, `doc/llm.md`, the PRD's offline contract and the existing pipeline state.

Command:

```sh
rg -n 'manifestPath:|logic:|Unsupported manifest profile|runtime.*1.12.14|SHA-256 differs|stage.rename|SherpaOnnxOnlineRecognizerConfig|tts.model.vits|Provision pinned|vendored_frameworks' example/lib/main.dart lib/src/model_store.dart native/src/flva.cpp android/src/main/cpp/CMakeLists.txt ios/flutter_local_voice_agent.podspec
```

Output:

```text
example/lib/main.dart:67:        manifestPath: '$directory/manifest.json',
example/lib/main.dart:69:      logic: (text) async {
ios/flutter_local_voice_agent.podspec:20:  s.vendored_frameworks = frameworks
android/src/main/cpp/CMakeLists.txt:7:  message(FATAL_ERROR "Provision pinned sherpa v1.12.14 libraries with tool/provision_runtime.py; no runtime download is performed.")
lib/src/model_store.dart:47:        'Unsupported manifest profile.',
lib/src/model_store.dart:50:        document['runtime'] == '1.12.14',
lib/src/model_store.dart:131:          'SHA-256 differs for ${entry.path}.',
lib/src/model_store.dart:176:          manifestPath: stagedManifest.path,
lib/src/model_store.dart:182:      await stage.rename(active.path);
lib/src/model_store.dart:185:        manifestPath: '${active.path}${Platform.pathSeparator}manifest.json',
native/src/flva.cpp:106:    SherpaOnnxOnlineRecognizerConfig asr{};
native/src/flva.cpp:117:    tts.model.vits = {config_.tts_model, config_.tts_lexicon, config_.tts_tokens, "", 0.667f, 0.8f, 1.0f, ""};
```

Command:

```sh
rg -n 'UNRESOLVED|UNVERIFIED|not implemented|no runtime implementation' wiki/work/0004-managed-model-setup/00-research.md doc/models.md
```

Output:

```text
doc/models.md:12:fully offline setup. It is not implemented; the current SDK never fetches models.
wiki/work/0004-managed-model-setup/00-research.md:8:summary: Planned managed model setup; no runtime implementation is delivered by this record.
wiki/work/0004-managed-model-setup/00-research.md:47:- [UNRESOLVED: exact default files, pinned revisions, distribution rights and notices, and download host.]
wiki/work/0004-managed-model-setup/00-research.md:48:- [UNRESOLVED: measured download/installed/peak installation sizes and supported physical-device resource limits.]
wiki/work/0004-managed-model-setup/00-research.md:49:- [UNRESOLVED: final public API names and native dependency packaging mechanism.]
wiki/work/0004-managed-model-setup/00-research.md:50:- [UNRESOLVED: required languages beyond the initial English candidate; Hebrew support is UNVERIFIED.]
```

Command:

```sh
python3 tool/lint_wiki.py
```

Output, exit 0:

```text
lint_wiki: clean (0 warning(s)).
```

This linter result was obtained before writing this report. It is a wiki consistency check, not runtime acceptance.

## Official-source verification

The web tool opened all three cited URLs on 2026-09-20. [Android app-specific storage](https://developer.android.com/training/data-storage/app-specific) confirms persistent internal application directories and access without storage permissions. [Apple background downloads](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background) confirms explicit background-session configuration and completion handling for downloads across suspension. The Apple page body required a search retrieval after its direct open returned only the JavaScript shell; the retrieved official article supplied those details. [The sherpa model index](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/index.html) was reachable; it is not evidence of any selected bundle's compatibility or redistribution rights.

## Limits

No model download, consumer build, inference run, network observation, failure-injection test or physical-device test was performed. The negative cases in AC-001 through AC-010 are future implementation acceptance, outside this research review. No author reasoning, conversation transcript or plan was used. This is one review verdict; no source edits or follow-up revalidation were performed.

## Verification performed

Coordinator format addendum, 2026-09-20: the reviewer's exact commands and pasted
outputs remain preserved in Checks and evidence above. That lint run preceded
report creation; it does not establish lint compliance of the report itself.
The coordinator reproduced the missing-section lint failure and appended these
required headings without changing the independent research verdict. Final
post-integration checks are recorded in STATE.yaml.

## Recurrence check

This is research review round 1 for work item 0004. There is no earlier
research verdict for this item and no repeated finding. The required-heading
repair is a coordinator documentation correction, not a second validator round.
