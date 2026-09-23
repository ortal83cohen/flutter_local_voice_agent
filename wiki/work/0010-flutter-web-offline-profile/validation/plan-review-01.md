# Plan review — round 01

- Work item: 0010-flutter-web-offline-profile
- Reviewed artifact: wiki/work/0010-flutter-web-offline-profile/01-plan.md (also inspected 02-criteria.md and 03-tasks.md)
- Reviewer: blind plan validator
- Date: 2026-09-22

## Verdict

**FAIL**

AC-004, AC-005, AC-010, and AC-013 are unmet at plan coverage: required outcomes are absent from 01-plan.md, so an implementer can follow the plan and still miss those criteria.

## Verification performed

This is a plan review. No implementation suite was run.

Commands run by this reviewer:

```
python3 tool/lint_wiki.py
```

```
lint_wiki: clean (0 warning(s)).
```

```
python3 - <<'PY'
from pathlib import Path
plan = Path('wiki/work/0010-flutter-web-offline-profile/01-plan.md').read_text()
print('plan_fenced_triple_backtick:', plan.count('```'))
print('plan_fenced_tilde:', plan.count('~~~'))
print('plan_lines:', len(plan.splitlines()))
print('plan_has_html_pre:', '<pre' in plan.lower())
print('plan_has_code_tag:', '<code' in plan.lower())
print('sherpa_onnx_web_in_plan:', 'sherpa_onnx_web' in plan)
lock = Path('pubspec.lock').read_text().splitlines()
hits = [f'{i}:{line}' for i, line in enumerate(lock, 1) if 'web' in line.lower()]
print('pubspec_lock_web_lines:', len(hits))
PY
```

```
plan_fenced_triple_backtick: 0
plan_fenced_tilde: 0
plan_lines: 102
plan_has_html_pre: False
plan_has_code_tag: False
sherpa_onnx_web_in_plan: False
pubspec_lock_web_lines: 0
```

```
python3 - <<'PY'
from pathlib import Path
import re
text = Path('lib/src/model_catalog.dart').read_text().splitlines()
chunk = '\n'.join(text[56:229])
nums = [int(n) for n in re.findall(r'bytes: (\d+)', chunk)]
print('compact_file_entries:', len(nums))
print('compact_bytes_sum:', sum(nums))
PY
```

```
compact_file_entries: 12
compact_bytes_sum: 114444636
```

Inspected:

- wiki/conventions/validation-rubrics.md
- wiki/templates/validation-report.md
- wiki/conventions/naming.md
- wiki/work/0010-flutter-web-offline-profile/01-plan.md
- wiki/work/0010-flutter-web-offline-profile/02-criteria.md
- wiki/work/0010-flutter-web-offline-profile/03-tasks.md
- pubspec.yaml
- pubspec.lock
- lib/src/agent.dart
- lib/src/contracts.dart
- lib/src/models.dart
- lib/src/model_store.dart
- lib/src/model_preparation.dart
- lib/src/model_catalog.dart
- test/platform_refusal_test.dart
- analysis_options.yaml
- example/analysis_options.yaml
- tool/provision_runtime.py
- wiki/product/flutter-web-offline-profile.md
- wiki/product/reasonable-platform-coverage.md
- wiki/adr/0005-flutter-web-offline-profile.md

Grounding checks:

- 01-plan.md contains zero fenced code blocks (triple-backtick count 0, tilde-fence count 0). The risk table is a markdown table, not a fenced block. `python3 tool/lint_wiki.py` reported clean with 0 warnings.
- 02-criteria.md lists AC-001 through AC-018. Frozen at / Frozen by remain "not yet" (02-criteria.md:4-5). 01-plan.md:27 and 03-tasks.md:3 also say the criteria are not frozen. Freeze is not claimed.
- 03-tasks.md assigns every criterion to at least one task: AC-001, AC-002, AC-003, AC-007, and AC-008 to 1.1; AC-004, AC-005, AC-017, and AC-018 to 2.1; AC-006 to 2.2; AC-009, AC-010, AC-011, AC-012, AC-013, and AC-016 to 3.1; AC-014 to 4.1; AC-015 to 5.1. Each task row has a Satisfies cell. Task text is not treated as plan coverage.
- Rollback is present at 01-plan.md:88. It names the web backend, vendored WASM, web model store, web example storage, web plugin registration, web tests, and the host-guard restoration to unsupportedProfile, and it leaves native plugins, flva, catalog inventory, and provision_runtime.py untouched. The architecture-decision sentence in that rollback is finding F-009.
- Every risk row at 01-plan.md:75-84 has a mitigation and a trigger.
- Host choice is decided at 01-plan.md:31 and 01-plan.md:43: web create uses the web backend and does not open a method channel; fuchsia and other non-native non-web targets throw unsupportedProfile; native create stays on MethodChannelVoicePlatform.
- The compact-pack byte figure at 01-plan.md:13 matches the first catalog descriptor, `en-us-ljs-zipformer-int8`: 12 file entries sum to 114444636 (lib/src/model_catalog.dart:57-229).
- Current web refusal is `kIsWeb` throwing unsupportedProfile before native create (lib/src/agent.dart:547-553). pubspec.yaml:37-49 registers android, ios, macos, windows, and linux only. Dependencies at pubspec.yaml:26-29 are flutter and crypto. `AgentErrorCode` already includes invalidAsset, missingAsset, unsupportedProfile, permissionDenied, audioUnavailable, capacityExceeded, and inferenceFailed (lib/src/models.dart:76-102).
- FileModelStore requires manifest runtime `1.12.14` (lib/src/model_store.dart:49-51). Model preparation writes that same string (lib/src/model_preparation.dart:73).
- provision_runtime.py:110-111 raises on SHA-256 mismatch before extract at line 112 and before the install copies. 01-plan.md:33's "same style as provision_runtime.py" is the plan sentence that covers AC-018's copy-or-load-nothing obligation.
- wiki/product/reasonable-platform-coverage.md:47-53 still records parent 0002 VITS allocation, physical mobile qualification, and clean consumer-install as open. 01-plan.md:69 and 01-plan.md:102 keep those gates open.
- 03-tasks.md:25 tells task 2.1 to register this package's own web implementation and to forbid sherpa_onnx_web. Those words are not in 01-plan.md (`sherpa_onnx_web_in_plan: False`).

Plan-coverage map (not implementation results):

| Criterion | Covered by plan? | Evidence |
|---|---|---|
| AC-001 | covered | 01-plan.md:31, 43, 96 |
| AC-002 | covered | 01-plan.md:15, 43, 96 |
| AC-003 | covered | 01-plan.md:29, 96 |
| AC-004 | uncovered | 01-plan.md:11, 55, 88, 98 name sherpa_onnx, record, and the five native hosts; they do not name sherpa_onnx_web or a web platform key that points at this package |
| AC-005 | uncovered | 01-plan.md:33 fails the backend before microphone permission and does not name invalidAsset or unsupportedProfile; 01-plan.md:63 assigns unsupportedProfile to missing WASM, not a digest mismatch |
| AC-006 | covered | 01-plan.md:13, 37, 61, 96 |
| AC-007 | covered | 01-plan.md:13, 59, 96 |
| AC-008 | covered | 01-plan.md:13, 31, 59 |
| AC-009 | covered | 01-plan.md:37, 63 |
| AC-010 | uncovered | 01-plan.md:37 returns permissionDenied and does not open capture; playback on that path is unstated |
| AC-011 | covered | 01-plan.md:11, 37, 65, 96 |
| AC-012 | covered | 01-plan.md:37, 39, 77 |
| AC-013 | uncovered | 01-plan.md:39 flushes playback and invalidates the generation; it does not return the session to listening or idle |
| AC-014 | covered | 01-plan.md:41, 47, 100 |
| AC-015 | covered | 01-plan.md:15, 45, 69, 82, 98, 102 |
| AC-016 | covered | 01-plan.md:37, 65, 83 |
| AC-017 | covered | 01-plan.md:11, 76, 92 |
| AC-018 | covered | 01-plan.md:11, 33 |

03-tasks.md:25 states the missing AC-004 registration and sherpa_onnx_web ban. That does not put the obligation into the reviewed plan.

## Per-criterion results

Not applicable. This is a plan review, not an implementation review. Coverage is in Verification performed.

## Findings

### F-001 — Web plugin registration and sherpa_onnx_web are unstated

- Severity: BLOCKER
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:11`
- Criterion affected: AC-004
- Observation: AC-004 requires no dependency on sherpa_onnx, sherpa_onnx_web, or record, and it requires the existing android, ios, macos, windows, and linux plugin keys plus a web registration that points at this package's own web implementation. 01-plan.md:11 forbids the pub.dev sherpa_onnx plugin and the record plugin. 01-plan.md:55 keeps the five native hosts. 01-plan.md:98 inspects pubspec.yaml for sherpa_onnx and record. The string sherpa_onnx_web does not occur in 01-plan.md. 01-plan.md:88 names "web plugin registration" only as something rollback removes, and it does not say that registration points at this package. 03-tasks.md:25 states both missing obligations. Current platforms are the five native keys only (pubspec.yaml:37-49).
- Why it matters: An implementer can omit the web platform key, point it at another registrant, or add sherpa_onnx_web, and still match every sentence in the plan. The criterion is unmet at plan coverage.

### F-002 — WASM digest failure has no required error code

- Severity: BLOCKER
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:33`
- Criterion affected: AC-005
- Observation: AC-005 requires web create to fail with invalidAsset or unsupportedProfile and not to request the microphone. 01-plan.md:33 says a digest mismatch fails the web backend before microphone permission is requested. 01-plan.md:96 says that mismatch throws before getUserMedia. 01-plan.md:63 assigns unsupportedProfile to secure-context failure and missing WASM, not to a wrong digest. 01-plan.md:61 assigns invalidAsset to a web model-key hash mismatch, not to the WASM pin. No plan sentence binds the WASM digest failure to either allowed code.
- Why it matters: An implementer can throw inferenceFailed, or another code, after detecting a bad digest and still match the written plan. The criterion is unmet at plan coverage.

### F-003 — Microphone denial does not forbid playback

- Severity: BLOCKER
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:37`
- Criterion affected: AC-010
- Observation: AC-010 requires start, when microphone permission is denied, to fail with permissionDenied and not to start capture or playback. The negative case is capture or TTS playback after denial. 01-plan.md:37 says denied permission makes start return permissionDenied and does not open capture. The same step still says to play generated TTS through Web Audio. No plan sentence says playback stays stopped on the denial path.
- Why it matters: An implementer can start TTS playback after denial, as long as capture stays closed, and still match the plan sentence. The criterion is unmet at plan coverage.

### F-004 — Interrupt does not name the post-interrupt state

- Severity: BLOCKER
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:39`
- Criterion affected: AC-013
- Observation: AC-013 requires interrupt during web speaking to flush playback, invalidate the current generation, and return to a listening or idle state without emitting the cancelled audio. 01-plan.md:39 says interrupt flushes playback and invalidates the current generation. The same sentence lists listening, speaking, interrupting, and idle as events the backend wires. It does not say interrupt ends in listening or idle. Existing interrupt sets activity to interrupting and does not move to listening or idle (lib/src/agent.dart:226-229).
- Why it matters: An implementer can leave the session in interrupting after the flush and still match the plan sentence. The criterion is unmet at plan coverage.

### F-005 — package web is treated as already available

- Severity: IMPORTANT
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:9`
- Criterion affected: none
- Observation: 01-plan.md:9 says the web backend owns microphone capture and speaker playback through the browser packages already available to Flutter web. 01-plan.md:11 says capture and playback use package web. pubspec.yaml:26-29 depends on flutter and crypto only. pubspec.lock has no line containing "web" (`pubspec_lock_web_lines: 0`). No plan step says to add that package. Task 2.1 owns pubspec.yaml and does not mention it (03-tasks.md:25). Task 3.1 is the task that implements getUserMedia and Web Audio (03-tasks.md:32).
- Why it matters: The web audio owner cannot import package web from the dependency set the plan says is already available. The library manifest and the audio task do not share a written decision to add it.

### F-006 — Web manifest runtime check is undecided

- Severity: IMPORTANT
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:55`
- Criterion affected: AC-001
- Observation: 01-plan.md:55 pins Flutter web to vendored sherpa-onnx 1.13.8 WASM and native hosts to sherpa-onnx v1.12.14. 01-plan.md:29 says the web model store hash-checks bundled or origin-private files. It does not say whether that store still requires manifest runtime `1.12.14`. FileModelStore rejects any other runtime (lib/src/model_store.dart:49-51). Model preparation writes `1.12.14` (lib/src/model_preparation.dart:73). The compact pack named at 01-plan.md:13 is the catalog entry whose files sum to 114444636 bytes.
- Why it matters: A web store that requires runtime 1.13.8 rejects that compact manifest before WASM load. A store that drops the check accepts a different runtime string. Both follow the plan, and they do not agree on what a validated compact pack is.

### F-007 — Web model address strings are undecided

- Severity: IMPORTANT
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:13`
- Criterion affected: AC-001, AC-014
- Observation: 01-plan.md:13 says web create validates a web model store instead of Directory paths, and that models arrive as example assets or through a preparation write into a private origin store. 01-plan.md:41 allows the example to install into the origin-private store or to load example assets. 01-plan.md:61 confines web model keys to bundled assets or a private origin store. Public LocalModelBundle still carries directory and manifestPath strings (lib/src/models.dart:112-116). LocalModelStore.install still takes targetRoot (lib/src/contracts.dart:8-12). The plan says the web store never uses Directory or File (01-plan.md:29) and does not say what those strings contain on web.
- Why it matters: The example host and the web store can choose different strings for the same pack and still follow the plan. Create validation and the example Start gate then have no shared address.

### F-008 — Two tasks claim the web model-store library

- Severity: IMPORTANT
- Location: `wiki/work/0010-flutter-web-offline-profile/03-tasks.md:19`
- Criterion affected: none
- Observation: 03-tasks.md:11 says owned files are exclusive and two tasks never list the same file. Task 1.1 owns "new web-conditional libraries those modules require" for the model store split, and its done-when requires analyze to accept a web target (03-tasks.md:19). Task 2.2 owns "new web model-store library" (03-tasks.md:26). The web conditional library that model_store.dart requires is that web model-store library. The plan puts the web model store in the same split (01-plan.md:29).
- Why it matters: The exclusive-ownership rule in the task list is already broken for the library both tasks describe. Group 1's web analyze result and group 2's store implementation are not assigned to disjoint files.

### F-009 — Rollback removes the architecture decision

- Severity: IMPORTANT
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:88`
- Criterion affected: none
- Observation: 01-plan.md:88 says rollback removes the new architecture decision if it was added in this item. wiki/adr/0005-flutter-web-offline-profile.md is already in the tree, with status proposed (wiki/adr/0005-flutter-web-offline-profile.md:14). wiki/conventions/naming.md:51 says wiki documents are never deleted and are retired by supersession. The rollback sentence names removal and does not name supersession.
- Why it matters: The written rollback deletes an ADR that this work item has already added.

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
| F-006 | plan |
| F-007 | plan |
| F-008 | plan |
| F-009 | plan |
