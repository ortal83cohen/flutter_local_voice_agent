# Plan review — round 02

- Work item: 0010-flutter-web-offline-profile
- Reviewed artifact: wiki/work/0010-flutter-web-offline-profile/01-plan.md (also inspected 02-criteria.md and 03-tasks.md)
- Reviewer: blind plan validator
- Date: 2026-09-22

## Verdict

**PASS**

AC-001 through AC-018 are each stated in 01-plan.md, rollback and the risk rows are specific, and the remaining task-boundary gap is not a blocker.

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
import re
root = Path('.')
plan = (root / 'wiki/work/0010-flutter-web-offline-profile/01-plan.md').read_text()
print('plan_fenced_triple_backtick:', plan.count('```'))
print('plan_fenced_tilde:', plan.count('~~~'))
print('plan_lines:', len(plan.splitlines()))
print('plan_has_html_pre:', '<pre' in plan.lower())
print('plan_has_code_tag:', '<code' in plan.lower())
print('sherpa_onnx_web_in_plan:', 'sherpa_onnx_web' in plan)
print('package_web_add_in_plan:', 'package web' in plan)
lock_path = root / 'pubspec.lock'
lock = lock_path.read_text().splitlines() if lock_path.exists() else []
hits = [f'{i}:{line}' for i, line in enumerate(lock, 1) if re.search(r'\bweb\b', line, re.I)]
print('pubspec_lock_exists:', lock_path.exists())
print('pubspec_lock_web_word_lines:', len(hits))
text = (root / 'lib/src/model_catalog.dart').read_text()
parts = re.split(r"\n        id: '", text)
print('descriptor_chunks:', len(parts)-1)
for part in parts[1:]:
    ident = part.split("'", 1)[0]
    cut = part
    for marker in ('\n    VoiceModelOption(', '\n  ];'):
        if marker in cut:
            cut = cut.split(marker)[0]
            break
    nums = [int(n) for n in re.findall(r'bytes: (\d+)', cut)]
    print(f'id={ident} files={len(nums)} sum={sum(nums)}')
PY
```

```
plan_fenced_triple_backtick: 0
plan_fenced_tilde: 0
plan_lines: 108
plan_has_html_pre: False
plan_has_code_tag: False
sherpa_onnx_web_in_plan: True
package_web_add_in_plan: True
pubspec_lock_exists: True
pubspec_lock_web_word_lines: 0
descriptor_chunks: 3
id=en-us-ljs-zipformer-int8 files=12 sum=114444636
id=en-us-ljs-zipformer-standard files=12 sum=383741867
id=en-us-vctk-zipformer-int8 files=12 sum=116261194
```

Inspected:

- wiki/conventions/validation-rubrics.md
- wiki/templates/validation-report.md
- wiki/conventions/naming.md
- wiki/work/0010-flutter-web-offline-profile/01-plan.md
- wiki/work/0010-flutter-web-offline-profile/02-criteria.md
- wiki/work/0010-flutter-web-offline-profile/03-tasks.md
- wiki/work/0010-flutter-web-offline-profile/validation/plan-review-01.md
- pubspec.yaml
- pubspec.lock
- lib/src/agent.dart
- lib/src/contracts.dart
- lib/src/models.dart
- lib/src/model_store.dart
- lib/src/model_preparation.dart
- lib/src/model_catalog.dart
- test/platform_refusal_test.dart
- tool/provision_runtime.py
- wiki/product/reasonable-platform-coverage.md
- wiki/adr/0005-flutter-web-offline-profile.md

Grounding checks:

- 01-plan.md contains zero fenced code blocks (triple-backtick count 0, tilde-fence count 0). The risk table is a markdown table, not a fenced block. `python3 tool/lint_wiki.py` reported clean with 0 warnings.
- 02-criteria.md lists AC-001 through AC-018. Frozen at / Frozen by remain "not yet" (02-criteria.md:4-5). 01-plan.md:29 and 03-tasks.md:3 also say the criteria are not frozen. Freeze is not claimed.
- 03-tasks.md assigns every criterion to at least one task: AC-001, AC-002, AC-003, AC-007, and AC-008 to 1.1; AC-004, AC-005, AC-017, and AC-018 to 2.1; AC-006 to 2.2; AC-009, AC-010, AC-011, AC-012, AC-013, and AC-016 to 3.1; AC-014 to 4.1; AC-015 to 5.1. Each task row has a Satisfies cell. Task text is not treated as plan coverage.
- Rollback is present at 01-plan.md:93. It names the web backend, vendored WASM, web model store, web example storage path, web plugin registration, the package web dependency, web tests, and restoration of the web host guard to unsupportedProfile. It leaves native plugins, flva, catalog inventory, and provision_runtime.py untouched. It says to supersede the architecture decision and not to delete it.
- Every risk row at 01-plan.md:81-90 has a mitigation and a trigger.
- Host choice is decided at 01-plan.md:33 and 01-plan.md:45: web create uses the web backend and does not open a method channel; fuchsia and other non-native non-web targets throw unsupportedProfile; native create stays on MethodChannelVoicePlatform.
- Round 01 coverage gaps are now sentences in the plan. AC-004 names sherpa_onnx_web and a web platform key that points at this package (01-plan.md:11, 01-plan.md:13, 01-plan.md:61, 01-plan.md:104). AC-005 binds a WASM digest mismatch to invalidAsset, with no load, no copy, and no microphone request (01-plan.md:35, 01-plan.md:69). AC-010 says microphone denial does not start playback (01-plan.md:39). AC-013 returns interrupt during speaking to listening or idle and does not emit the cancelled audio (01-plan.md:41).
- The manifest does not depend on package web today (pubspec.yaml:26-29; pubspec.lock has no line containing the word web). 01-plan.md:9 and 01-plan.md:35 say this item adds that package in the Group 2 manifest change. Task 2.1 says the same (03-tasks.md:25).
- The web model store accepts manifest runtime 1.12.14 and does not require 1.13.8 (01-plan.md:59). FileModelStore requires `1.12.14` (lib/src/model_store.dart:50). Model preparation writes that string (lib/src/model_preparation.dart:73).
- On web, LocalModelBundle.directory is an origin-private or bundled-asset prefix, manifestPath keeps the native manifest file name, and the compact English pack uses the catalog identifier as that prefix (01-plan.md:43). The byte figure 114,444,636 matches only `en-us-ljs-zipformer-int8` (12 files, sum 114444636). The other two catalog entries sum to 383741867 and 116261194. Native manifests use the file name manifest.json (lib/src/model_preparation.dart:363, lib/src/model_store.dart:170).
- Current web refusal throws unsupportedProfile before native create (lib/src/agent.dart:49, lib/src/agent.dart:548-553). Fuchsia takes the same guard and throws unsupportedProfile (lib/src/agent.dart:561-568). test/platform_refusal_test.dart:14-35 expects that refusal before native create. pubspec.yaml:38-49 registers android, ios, macos, windows, and linux only. Dependencies at pubspec.yaml:26-29 are flutter and crypto.
- AgentErrorCode already includes invalidAsset, missingAsset, unsupportedProfile, permissionDenied, audioUnavailable, capacityExceeded, and inferenceFailed (lib/src/models.dart:76-102). AgentEvent fields are sequence, generation, kind, lifecycle, activity, text, and failure (lib/src/models.dart:182-213).
- provision_runtime.py:110-111 raises on SHA-256 mismatch before extract at line 112. 01-plan.md:35 also states that a WASM digest mismatch loads or copies nothing.
- wiki/product/reasonable-platform-coverage.md:47-53 still records parent 0002 VITS allocation, physical mobile qualification, and clean consumer-install as open. 01-plan.md:75 and 01-plan.md:108 keep those gates open.
- wiki/adr/0005-flutter-web-offline-profile.md:14 has status proposed. wiki/conventions/naming.md:51 says documents are retired by supersession and are not deleted. 01-plan.md:93 matches that rule.
- agent.dart, model_store.dart, and model_preparation.dart each import dart:io (lib/src/agent.dart:3, lib/src/model_store.dart:2, lib/src/model_preparation.dart:3). 01-plan.md:31 puts those imports behind conditional libraries.

Plan-coverage map (not implementation results):

| Criterion | Covered by plan? | Evidence |
|---|---|---|
| AC-001 | covered | 01-plan.md:33, 102 |
| AC-002 | covered | 01-plan.md:17, 45, 102 |
| AC-003 | covered | 01-plan.md:9, 31, 102 |
| AC-004 | covered | 01-plan.md:11, 13, 61, 104 |
| AC-005 | covered | 01-plan.md:35, 69, 102 |
| AC-006 | covered | 01-plan.md:15, 31, 67, 102 |
| AC-007 | covered | 01-plan.md:15, 65, 102 |
| AC-008 | covered | 01-plan.md:15, 33, 49, 65 |
| AC-009 | covered | 01-plan.md:39, 69 |
| AC-010 | covered | 01-plan.md:39 |
| AC-011 | covered | 01-plan.md:11, 39, 71, 102 |
| AC-012 | covered | 01-plan.md:39, 41, 83 |
| AC-013 | covered | 01-plan.md:41 |
| AC-014 | covered | 01-plan.md:43, 49, 106 |
| AC-015 | covered | 01-plan.md:17, 47, 75, 97, 104, 108 |
| AC-016 | covered | 01-plan.md:39, 71, 89 |
| AC-017 | covered | 01-plan.md:11, 82, 97 |
| AC-018 | covered | 01-plan.md:11, 35 |

No prior uncovered obligation from plan-review-01 remains silent in 01-plan.md. AC-004, AC-005, AC-010, and AC-013 are covered by the lines in the map above.

## Per-criterion results

Not applicable. This is a plan review, not an implementation review. Coverage is in Verification performed.

## Findings

### F-001 — Create never switches from the hash-free stub to the production store

- Severity: IMPORTANT
- Location: `wiki/work/0010-flutter-web-offline-profile/01-plan.md:31`
- Criterion affected: AC-006
- Observation: 01-plan.md:31 limits Group 1 to conditional import barrels and web compile stubs that do not implement compact-pack hash policy, and it has Group 2 add a separate production web model-store library that hash-checks. 01-plan.md:15 and 01-plan.md:67 require web create to validate that hash-checking store and to fail with missingAsset or invalidAsset. 03-tasks.md:11 says owned files are exclusive and two tasks never list the same file. Task 1.1 owns lib/src/agent.dart, lib/src/model_store.dart, and those barrels (03-tasks.md:19). Task 2.2 owns only the new production library and its tests, and it says that library is not the Group 1 compile stub (03-tasks.md:26). No sentence names a file both the selector and the production library may change so that create calls the hash-checking store.
- Why it matters: Web create can stay on the stub that the plan says does not implement hash policy, while task 2.2 still adds an unreferenced library and still obeys exclusive ownership. AC-006's error mapping is written, and the create path that must apply it is not assigned.

## Recurrence check

- Previous round: wiki/work/0010-flutter-web-offline-profile/validation/plan-review-01.md
- Recurring findings: none
- Oscillating: no

Round 01 F-001 through F-009 are not repeated. This report's F-001 is not the same defect as round 01 F-008. That finding was two tasks claiming one web model-store library. The plan and task list now name a compile stub and a separate production library.

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | plan |
