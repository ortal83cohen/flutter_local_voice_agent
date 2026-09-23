---
id: index
title: Wiki index
status: active
owner: unassigned
last_verified: 2026-09-22
applies_to: ["**"]
summary: Router for the whole wiki. One line per document, stating when to read it.
---

# Wiki index

Every document in this wiki is reachable from here in one hop. If you add a document, add its line here in the same commit or the lint fails.

## Conventions — read before writing anything

| Document | Read it when |
|---|---|
| [workflow.md](conventions/workflow.md) | Starting any change. Defines the six phases and the gates between them. |
| [naming.md](conventions/naming.md) | Creating any file or frontmatter block. Defines IDs, slugs, numbering, required fields. |
| [validation-rubrics.md](conventions/validation-rubrics.md) | Acting as a validator, or reading a validation report. Defines verdicts, severities, evidence rules. |
| [model-routing.md](conventions/model-routing.md) | Choosing which model runs a phase or a subagent. |
| [parallelism.md](conventions/parallelism.md) | Deciding whether to fan out to multiple subagents, and how to merge their output. |
| [definition-of-done.md](conventions/definition-of-done.md) | Closing a work item. The checklist that must pass before a phase or item is done. |

## Templates — copy, do not improvise

| Document | Read it when |
|---|---|
| [templates/00-research.md](templates/00-research.md) | Writing the research artifact. |
| [templates/01-plan.md](templates/01-plan.md) | Writing the plan. Prose only, no code blocks. |
| [templates/02-criteria.md](templates/02-criteria.md) | Writing acceptance criteria before implementation. |
| [templates/03-tasks.md](templates/03-tasks.md) | Breaking the plan into ordered tasks. |
| [templates/validation-report.md](templates/validation-report.md) | Producing any validation verdict. |
| [templates/STATE.yaml](templates/STATE.yaml) | Creating a new work item folder. |
| [templates/adr.md](templates/adr.md) | Recording an architecture decision. |

## Project records

Project-specific architecture decisions, product notes, release records, and
work items belong in a fork after the project has a name and a domain. Add them
to this index when they are created.

## Offline voice agent research and specification

| Document | Read it when |
|---|---|
| [Research consolidation](work/0001-local-voice-agent-architecture/00-research.md) | Reviewing delegated evidence, provisional selections and unresolved questions. |
| [Documentation plan](work/0001-local-voice-agent-architecture/01-plan.md) | Understanding the scope and workflow for this specification. |
| [Acceptance criteria](work/0001-local-voice-agent-architecture/02-criteria.md) | Evaluating the research and specification deliverable. |
| [Tasks](work/0001-local-voice-agent-architecture/03-tasks.md) | Checking ownership and dependency order. |
| [Speech research](work/0001-local-voice-agent-architecture/research/speech.md) | Comparing VAD, STT and native recognition alternatives. |
| [Intelligence and TTS research](work/0001-local-voice-agent-architecture/research/intelligence-tts.md) | Comparing local runtimes, voices, streaming and licenses; read supplementary updates too. |
| [Mobile systems research](work/0001-local-voice-agent-architecture/research/mobile-systems.md) | Checking audio, threading, lifecycle and operating-system evidence. |
| [Plan review](work/0001-local-voice-agent-architecture/validation/plan-review-01.md) | Inspecting the independent plan verdict. |
| [Verification evidence](work/0001-local-voice-agent-architecture/04-verification.md) | Distinguishing executed documentation checks from toolchain and device verification gaps. |
| [Work state](work/0001-local-voice-agent-architecture/STATE.yaml) | Checking phase, decisions and unresolved gates. |
| [Technical PRD and architecture](product/local-voice-agent-prd.md) | Implementing the proposed offline SDK; contains all five chapters and proposed Dart examples. |
| [Architecture decision](adr/0001-offline-voice-architecture.md) | Reviewing adapter selection, native ownership and conditional qualification. |
| [Research review round 1](work/0001-local-voice-agent-architecture/validation/research-review-01.md) | Inspecting the original license finding. |
| [Research review round 2](work/0001-local-voice-agent-architecture/validation/research-review-02.md) | Inspecting the independent source-confirmation verdict. |
| [Specification review](work/0001-local-voice-agent-architecture/validation/impl-review-01.md) | Inspecting per-criterion evidence and the independent documentation verdict. |
| [Delivery record](work/0001-local-voice-agent-architecture/05-delivery.md) | Understanding delivered scope, review outcomes and remaining verification gates. |

## Native offline pipeline implementation

| Document | Read it when |
|---|---|
| [00-research](work/0002-native-offline-pipeline/00-research.md) | Inspecting implementation plans, evidence or current gates. |
| [01-plan](work/0002-native-offline-pipeline/01-plan.md) | Inspecting implementation plans, evidence or current gates. |
| [02-criteria](work/0002-native-offline-pipeline/02-criteria.md) | Inspecting implementation plans, evidence or current gates. |
| [03-tasks](work/0002-native-offline-pipeline/03-tasks.md) | Inspecting implementation plans, evidence or current gates. |
| [STATE](work/0002-native-offline-pipeline/STATE.yaml) | Inspecting implementation plans, evidence or current gates. |
| [llm](work/0002-native-offline-pipeline/research/llm.md) | Inspecting implementation plans, evidence or current gates. |
| [mobile](work/0002-native-offline-pipeline/research/mobile.md) | Inspecting implementation plans, evidence or current gates. |
| [speech](work/0002-native-offline-pipeline/research/speech.md) | Inspecting implementation plans, evidence or current gates. |
| [provisioning](work/0002-native-offline-pipeline/research/provisioning.md) | Inspecting implementation evidence and open gates. |
| [research-review-01](work/0002-native-offline-pipeline/validation/research-review-01.md) | Inspecting implementation evidence and open gates. |
| [plan-review-01](work/0002-native-offline-pipeline/validation/plan-review-01.md) | Inspecting implementation evidence and open gates. |

## Release pipeline

| Document | Read it when |
|---|---|
| [Pub.dev release pipeline](product/pubdev-release-pipeline.md) | Configuring checks, release tagging, or GitHub OIDC publication. |
| [Pipeline work item](work/0003-pubdev-release-pipeline/00-research.md) | Reviewing the research, criteria, tasks, and external release gates. |
| [Plan](work/0003-pubdev-release-pipeline/01-plan.md) | Implementing the check entrypoint, bump helpers and GitHub workflows. |
| [Acceptance criteria](work/0003-pubdev-release-pipeline/02-criteria.md) | Checking pipeline stages, occupancy and payload exclusions. |
| [Tasks](work/0003-pubdev-release-pipeline/03-tasks.md) | Ordering helper, workflow and documentation work. |
| [Work state](work/0003-pubdev-release-pipeline/STATE.yaml) | Checking phase and recorded decisions. |
| [Plan review](work/0003-pubdev-release-pipeline/validation/plan-review-01.md) | Inspect the first late plan-coverage verdict. |
| [Plan review confirmation](work/0003-pubdev-release-pipeline/validation/plan-review-02.md) | Inspect the confirmation verdict after the plan coverage patch. |
| [Verification](work/0003-pubdev-release-pipeline/04-verification.md) | Inspect the Git-free snapshot check and dry-run evidence. |
| [Implementation review](work/0003-pubdev-release-pipeline/validation/impl-review-01.md) | Inspect the independent pipeline implementation verdict. |

## Implementation handoff evidence

| Document | Read it when |
|---|---|
| [Implementation review](work/0002-native-offline-pipeline/validation/impl-review-01.md) | Read the independent FAIL and reproduced blockers. |
| [Implementation verification](work/0002-native-offline-pipeline/04-verification.md) | Inspect final coordinator checks and their limits. |
| [Continuation handoff](work/0002-native-offline-pipeline/05-handoff.md) | Resume unfinished implementation and qualification. |

## Managed model setup proposal

| Document | Read it when |
|---|---|
| [Product proposal](product/managed-model-setup.md) | Reviewing the planned first-use experience and library responsibilities. |
| [Research](work/0004-managed-model-setup/00-research.md) | Preparing future managed model implementation; runtime work remains pending. |
| [Implementation plan](work/0004-managed-model-setup/01-plan.md) | Preparing future managed model implementation; runtime work remains pending. |
| [Draft acceptance criteria](work/0004-managed-model-setup/02-criteria.md) | Preparing future managed model implementation; runtime work remains pending. |
| [Ordered implementation tasks](work/0004-managed-model-setup/03-tasks.md) | Preparing future managed model implementation; runtime work remains pending. |
| [Planning state](work/0004-managed-model-setup/STATE.yaml) | Preparing future managed model implementation; runtime work remains pending. |
| [Research review](work/0004-managed-model-setup/validation/research-review-01.md) | Inspect independent evidence review; runtime acceptance remains pending. |
| [Plan review](work/0004-managed-model-setup/validation/plan-review-01.md) | Inspect draft criterion coverage and the recorded documentation-format finding. |

## Native pipeline continuation

| Document | Read it when |
|---|---|
| [Implementation review round 2](work/0002-native-offline-pipeline/validation/impl-review-02.md) | Inspect independent repair evidence and the retained whole-item FAIL. |

## Explicit model preparation core

| Document | Read it when |
|---|---|
| [Research](work/0005-model-preparation-core/00-research.md) | Implement or review the explicit host-configured preparation prerequisite to managed setup. |
| [Plan](work/0005-model-preparation-core/01-plan.md) | Implement or review the explicit host-configured preparation prerequisite to managed setup. |
| [Acceptance criteria](work/0005-model-preparation-core/02-criteria.md) | Implement or review the explicit host-configured preparation prerequisite to managed setup. |
| [Tasks](work/0005-model-preparation-core/03-tasks.md) | Implement or review the explicit host-configured preparation prerequisite to managed setup. |
| [State](work/0005-model-preparation-core/STATE.yaml) | Implement or review the explicit host-configured preparation prerequisite to managed setup. |
| [Research review](work/0005-model-preparation-core/validation/research-review-01.md) | Inspect the independent source verdict and wording correction. |
| [Plan review](work/0005-model-preparation-core/validation/plan-review-01.md) | Inspect the independent plan verdict before implementation freeze. |
| [Preparation product record](product/model-preparation-core.md) | Understand the host-configured core and retained managed-setup requirements. |
| [Preparation architecture decision](adr/0002-explicit-model-preparation.md) | Inspect the separation of explicit delivery and offline inference. |
| [Preparation verification](work/0005-model-preparation-core/04-verification.md) | Inspect coordinator commands, exact output and validation boundaries. |
| [Preparation implementation review 1](work/0005-model-preparation-core/validation/impl-review-01.md) | Inspect the independent FAIL and reproduced descriptor/storage defects. |
| [Preparation delivery and remaining work](work/0005-model-preparation-core/05-delivery.md) | Continue from implemented preparation infrastructure to unresolved parent gates. |
| [Preparation implementation review 2](work/0005-model-preparation-core/validation/impl-review-02.md) | Inspect final independent PASS, per-criterion evidence and retained qualification boundaries. |

## Selectable example model catalog

| Document | Read it when |
|---|---|
| [00-research.md](work/0006-example-model-catalog/00-research.md) | Implement or review the real picker/download/offline example flow. |
| [01-plan.md](work/0006-example-model-catalog/01-plan.md) | Implement or review the real picker/download/offline example flow. |
| [02-criteria.md](work/0006-example-model-catalog/02-criteria.md) | Implement or review the real picker/download/offline example flow. |
| [03-tasks.md](work/0006-example-model-catalog/03-tasks.md) | Implement or review the real picker/download/offline example flow. |
| [STATE.yaml](work/0006-example-model-catalog/STATE.yaml) | Implement or review the real picker/download/offline example flow. |
| [Catalog plan review](work/0006-example-model-catalog/validation/plan-review-01.md) | Inspect plan coverage and reviewed-snapshot boundary. |
| [Catalog research review](work/0006-example-model-catalog/validation/research-review-01.md) | Inspect independent model-byte, source and platform evidence. |
| [Example catalog product](product/example-model-catalog.md) | Understand the implemented selection/download journey, VCTK speaker control and qualification boundaries. |
| [Catalog architecture decision](adr/0003-example-model-catalog.md) | Inspect trusted catalog, bounded CDN redirects and example storage design. |
| [Voice-selection architecture decision](adr/0004-english-vits-voice-selection.md) | Inspect VCTK plus integer speaker id as the English lexicon voice choice. |
| [Example catalog verification](work/0006-example-model-catalog/04-verification.md) | Inspect real downloads, engine execution, final checks and mobile boundaries. |
| [Catalog implementation review](work/0006-example-model-catalog/validation/impl-review-01.md) | Inspect independent per-criterion findings and executed negative checks. |
| [Catalog delivery](work/0006-example-model-catalog/05-delivery.md) | Use the completed example and understand remaining release qualification gates. |

## Android audio diagnostics

| Document | Read it when |
|---|---|
| [Research](work/0007-android-audio-instrumentation/00-research.md) | Trace Android capture, native recognition, Dart polling and UI transcript delivery. |
| [Plan](work/0007-android-audio-instrumentation/01-plan.md) | Implementing diagnostic logs without changing recognition behavior. |
| [Acceptance criteria](work/0007-android-audio-instrumentation/02-criteria.md) | Checking log coverage and the device-evidence boundary. |
| [Tasks](work/0007-android-audio-instrumentation/03-tasks.md) | Ordering Android, native and Dart log work. |
| [Work state](work/0007-android-audio-instrumentation/STATE.yaml) | Checking phase and recorded decisions. |
| [Verification](work/0007-android-audio-instrumentation/04-verification.md) | Inspect the recorded format, analyze, test and device-blocker output. |
| [Implementation review](work/0007-android-audio-instrumentation/validation/impl-review-01.md) | Inspect the first independent implementation verdict. |
| [Implementation review confirmation](work/0007-android-audio-instrumentation/validation/impl-review-02.md) | Inspect the confirmation verdict after the log-field repair. |

## Reasonable platform coverage

| Document | Read it when |
|---|---|
| [Research consolidation](work/0008-reasonable-platform-coverage/00-research.md) | Deciding which Flutter platforms reuse the existing native session. |
| [Implementation plan](work/0008-reasonable-platform-coverage/01-plan.md) | Implementing desktop bridges without changing the C ABI. |
| [Acceptance criteria](work/0008-reasonable-platform-coverage/02-criteria.md) | Checking platform registration, provisioning and unsupported hosts. |
| [Tasks](work/0008-reasonable-platform-coverage/03-tasks.md) | Ordering Dart, provisioning and per-OS plugin work. |
| [Current gap](work/0008-reasonable-platform-coverage/research/current-gap.md) | Inspecting the existing Android and iOS bridges. |
| [Desktop feasibility](work/0008-reasonable-platform-coverage/research/desktop.md) | Checking macOS, Windows and Linux audio and sherpa evidence. |
| [Exclusions](work/0008-reasonable-platform-coverage/research/exclusions.md) | Confirming web and appliance targets stay unsupported. |
| [Work state](work/0008-reasonable-platform-coverage/STATE.yaml) | Checking phase and recorded decisions. |
| [Research review](work/0008-reasonable-platform-coverage/validation/research-review-01.md) | Inspect the independent source verdict. |
| [Plan review](work/0008-reasonable-platform-coverage/validation/plan-review-01.md) | Inspect the first plan coverage verdict before confirmation. |
| [Plan review confirmation](work/0008-reasonable-platform-coverage/validation/plan-review-02.md) | Inspect the patched-plan confirmation verdict. |
| [Implement-ready handoff](work/0008-reasonable-platform-coverage/05-implement-ready.md) | Read the pre-implementation freeze handoff. Implementation has started. |
| [Implementation review](work/0008-reasonable-platform-coverage/validation/impl-review-01.md) | Inspect the first independent implementation verdict. |
| [Implementation review confirmation](work/0008-reasonable-platform-coverage/validation/impl-review-02.md) | Inspect the confirmation verdict after the AC-007 test repair. |
| [Verification](work/0008-reasonable-platform-coverage/04-verification.md) | Inspect the recorded desktop, provision and unsupported-host checks. |
| [Platform coverage product](product/reasonable-platform-coverage.md) | Checking supported hosts, exclusions, provisioning and the compile-evidence boundary. |

## Flutter web offline profile

| Document | Read it when |
|---|---|
| [Research consolidation](work/0010-flutter-web-offline-profile/00-research.md) | Deciding whether Flutter web can keep the offline sherpa contract. |
| [Implementation plan](work/0010-flutter-web-offline-profile/01-plan.md) | Implementing the web session backend without changing flva.h. |
| [Acceptance criteria](work/0010-flutter-web-offline-profile/02-criteria.md) | Checking web compile, WASM pin, half-duplex and native honesty. |
| [Tasks](work/0010-flutter-web-offline-profile/03-tasks.md) | Ordering the dart:io split, WASM backend, example and docs. |
| [Upstream sherpa web](work/0010-flutter-web-offline-profile/research/upstream-sherpa-web.md) | Inspecting official WASM and Flutter web demos. |
| [Local gap](work/0010-flutter-web-offline-profile/research/local-gap.md) | Inspecting dart:io, the web refusal and plugin-collision risk. |
| [Rejected alternatives](work/0010-flutter-web-offline-profile/research/rejected-alternatives.md) | Checking why Web Speech, whisper and flva-to-WASM were rejected. |
| [Work state](work/0010-flutter-web-offline-profile/STATE.yaml) | Checking phase, decisions and the validation gate. |
| [Research review](work/0010-flutter-web-offline-profile/validation/research-review-01.md) | Inspect the independent source verdict. |
| [Plan review](work/0010-flutter-web-offline-profile/validation/plan-review-01.md) | Inspect the first plan coverage verdict before confirmation. |
| [Plan review confirmation](work/0010-flutter-web-offline-profile/validation/plan-review-02.md) | Inspect the patched-plan confirmation verdict. |
| [Implementation verification](work/0010-flutter-web-offline-profile/04-verification.md) | Inspect pasted format, analyze, tests, web build and the unverified live paths. |
| [Implementation review 1](work/0010-flutter-web-offline-profile/validation/impl-review-01.md) | Inspect the independent PASS, per-criterion evidence and retained unverified live paths. |
| [Product proposal](product/flutter-web-offline-profile.md) | Reading the active web profile limits. Browser microphone and compact-pack WASM load stay unverified. |
| [Web architecture decision](adr/0005-flutter-web-offline-profile.md) | Reviewing the accepted WASM-backend exception to native PCM ownership. |

## English VITS voice selection

| Document | Read it when |
|---|---|
| [Research](work/0009-english-vits-voice-selection/00-research.md) | Reviewing English lexicon voice options and why VCTK was chosen. |
| [Plan](work/0009-english-vits-voice-selection/01-plan.md) | Implementing catalog, speaker id and documentation updates. |
| [Acceptance criteria](work/0009-english-vits-voice-selection/02-criteria.md) | Checking voice selection, persistence and documentation gates. |
| [Tasks](work/0009-english-vits-voice-selection/03-tasks.md) | Ordering inventory, native, example and documentation work. |
| [Work state](work/0009-english-vits-voice-selection/STATE.yaml) | Checking phase and recorded decisions. |
| [Research review](work/0009-english-vits-voice-selection/validation/research-review-01.md) | Inspect the independent source verdict. |
| [Plan review](work/0009-english-vits-voice-selection/validation/plan-review-01.md) | Inspect the first plan coverage verdict before confirmation. |
| [Plan review confirmation](work/0009-english-vits-voice-selection/validation/plan-review-02.md) | Inspect the patched-plan confirmation verdict. |
| [Implementation review](work/0009-english-vits-voice-selection/validation/impl-review-01.md) | Inspect the independent implementation verdict. |
| [Verification](work/0009-english-vits-voice-selection/04-verification.md) | Inspect the recorded catalog, speaker-id and documentation checks. |
| [Example catalog product](product/example-model-catalog.md) | Understand the VCTK speaker control and integer ids on the implemented catalog. |
| [Catalog architecture decision](adr/0003-example-model-catalog.md) | Read the earlier trusted-catalog and storage decision; it was not superseded. |
| [Voice-selection architecture decision](adr/0004-english-vits-voice-selection.md) | Reviewing why VCTK plus integer speaker id is the English lexicon voice choice. |
