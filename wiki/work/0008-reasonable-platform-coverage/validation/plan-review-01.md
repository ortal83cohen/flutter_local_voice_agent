# Plan review — round 01

- Work item: 0008-reasonable-platform-coverage
- Reviewed artifact: wiki/work/0008-reasonable-platform-coverage/01-plan.md
- Reviewer: blind plan validator
- Date: 2026-09-20

## Verdict

**FAIL**

Two stated criteria are not covered by the plan: AC-011 is absent, and AC-007’s start-time denial contract is not specified. Those are unmet criteria, not residual conditions on an otherwise complete plan.

## Verification performed

This is a plan review. No implementation suite was run. The delegated tool set was Read, Grep and Glob only; `python3 tool/lint_wiki.py` was not executed.

Inspected:

- wiki/conventions/validation-rubrics.md
- wiki/templates/validation-report.md
- wiki/work/0008-reasonable-platform-coverage/01-plan.md
- wiki/work/0008-reasonable-platform-coverage/02-criteria.md
- wiki/work/0008-reasonable-platform-coverage/00-research.md and 03-tasks.md, only to test whether plan claims are grounded
- wiki/work/0008-reasonable-platform-coverage/research/desktop.md
- wiki/work/0008-reasonable-platform-coverage/research/exclusions.md
- Files the plan names: pubspec.yaml; tool/provision_runtime.py; lib/src/agent.dart; lib/src/models.dart; native/llm/CMakeLists.txt; ios/Classes/FlutterLocalVoiceAgentPlugin.mm; example/analysis_options.yaml

Grounding checks:

- pubspec.yaml lines 22–27 declare only android and ios. No macos, windows, linux or web plugin folders exist at the package root.
- tool/provision_runtime.py ASSETS keys are android and ios only. Digests are already fail-closed for those keys.
- lib/src/models.dart defines unsupportedProfile, permissionDenied and audioUnavailable. routeChanged is a native suspend string in the Android and iOS plugins, not an AgentErrorCode member.
- lib/src/agent.dart imports dart:io and calls native create after asset validation.
- ios/Classes/FlutterLocalVoiceAgentPlugin.mm gates start on record permission and returns permissionDenied without starting capture.
- native/llm/CMakeLists.txt forces GGML_METAL, GGML_ACCELERATE and GGML_BLAS OFF behind FLVA_ENABLE_LOCAL_LLM.
- 01-plan.md contains no fenced code blocks.
- 02-criteria.md lists AC-001 through AC-012. Frozen at / Frozen by remain “not yet”.

Plan-coverage map (not implementation results):

| Criterion | Covered by plan? | Evidence |
|---|---|---|
| AC-001 | yes | 01-plan.md:19, 29, 53, 87 |
| AC-002 | yes | 01-plan.md:31 |
| AC-003 | yes | 01-plan.md:15, 31, 87 |
| AC-004 | yes | 01-plan.md:15, 31, 55 |
| AC-005 | yes | 01-plan.md:9, 13, 33, 49, 87 |
| AC-006 | yes | 01-plan.md:17, 33, 89 |
| AC-007 | no | 01-plan.md:33 and 53 name a permission request and permissionDenied; they do not bind denial to start or forbid capture. 01-plan.md:91 verification omits the required denial test. |
| AC-008 | yes | 01-plan.md:13, 35, 53, 61 |
| AC-009 | yes | 01-plan.md:13, 37, 53 |
| AC-010 | yes | 01-plan.md:5, 27, 63, 83, 91 |
| AC-011 | no | No plan sentence mentions logs or PCM sample dumps. 01-plan.md:87 reviews channel payloads only. |
| AC-012 | yes | 01-plan.md:39 |

03-tasks.md assigns AC-007 and AC-011 to later tasks. That does not put those obligations into the reviewed plan.

## Per-criterion results

Not applicable. This is a plan review, not an implementation review. Coverage is in Verification performed.

## Findings

### F-001 — Plan never covers the no-PCM-in-logs criterion

- Severity: BLOCKER
- Location: `wiki/work/0008-reasonable-platform-coverage/01-plan.md:87`
- Criterion affected: AC-011
- Observation: AC-011 requires that desktop audio-callback logs not contain raw PCM samples, checked by searching new plugin and native log sites. The plan’s verification approach reviews flva_push, flva_render and method-channel PCM arguments. The risks, steps, interfaces and out-of-scope sections also omit logging.
- Why it matters: An implementer can satisfy every written plan step and still log frame values. The criterion is unmet at plan coverage.

### F-002 — macOS permission denial is not bound to start or to skipped capture

- Severity: BLOCKER
- Location: `wiki/work/0008-reasonable-platform-coverage/01-plan.md:53`
- Criterion affected: AC-007
- Observation: AC-007 requires that a denied macOS microphone permission make start fail with permissionDenied and not start capture, plus a unit or bridge test for that path. The plan says permission denial uses permissionDenied and step 4 says to request microphone permission. It does not say the failure is on start, and it does not say capture must stay closed. Step 9 only offers tests for “any extractable” permission helpers. The verification approach has no denied-permission case.
- Why it matters: The existing iOS bridge already fails start and skips capture on denial. Without that contract in the plan, a macOS owner can request permission at create, ignore denial, or start AVAudioEngine after a failed prompt and still match the written steps.

### F-003 — Rollback omits documentation and test surfaces the plan adds

- Severity: IMPORTANT
- Location: `wiki/work/0008-reasonable-platform-coverage/01-plan.md:79`
- Criterion affected: none
- Observation: Rollback removes desktop plugin folders, example desktop hosts, provisioning keys and the Dart guard, and restores the plugin manifest. Step 8 updates capability and setup documentation and the wiki index. Steps 2 and 9 add guard and provisioning tests. Those artifacts are not in the rollback list.
- Why it matters: Reversing only native and Dart plugin files leaves published platform lists and tests claiming five-platform coverage after the implementation is withdrawn.

### F-004 — Research-open desktop permission paths are not in the risk table

- Severity: IMPORTANT
- Location: `wiki/work/0008-reasonable-platform-coverage/01-plan.md:65`
- Criterion affected: none
- Observation: 00-research.md leaves Linux xdg-desktop-portal or PipeWire session-manager record prompts unresolved. desktop.md also records a Windows microphone DeviceCapability for the example host. The plan specifies AVCaptureDevice and microphone usage text for macOS only. The risk table has no row for portal denial, missing Windows microphone capability, or an unmapped Linux record failure. The generic permissionDenied sentence does not name those hosts.
- Why it matters: Windows and Linux sources can ship without a permission or portal story. A later host then fails in a way the plan neither classifies nor treats as a known trigger.

### F-005 — macOS sherpa link vehicle is preferred, not decided

- Severity: IMPORTANT
- Location: `wiki/work/0008-reasonable-platform-coverage/01-plan.md:15`
- Criterion affected: AC-004, AC-006
- Observation: Research still lists as unresolved whether macOS should vendor osx-universal2 shared dylibs, the macos xcframework static bundle, or a CocoaPods versus other install layout. The plan prefers the universal2 shared archive and says to link the provisioned library. Windows and Linux steps name CMake imported targets. The macOS step does not choose a plugin link vehicle. Digests remain “measured during implementation”.
- Why it matters: AC-004 and AC-006 depend on a deterministic install layout and a macOS build that exits 0. Two implementers can pin different layouts and still claim to follow the plan.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | plan |
| F-002 | plan |
| F-003 | plan |
| F-004 | plan |
| F-005 | plan |
