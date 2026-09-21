# Implementation review — round 01

- Work item: 0009-english-vits-voice-selection
- Reviewed artifact: implementation files listed in the review request, current working tree
- Reviewer: impl-review-0009
- Date: 2026-09-21

## Verdict

**PASS**

Every frozen criterion AC-001 through AC-012 is met on the inspected tree, with no blocker or important correctness defect.

## Verification performed

Working directory: `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent`. PATH placed Flutter 3.47.0 first. Commands were run by this reviewer. `/private/tmp/flva-catalog-verify-0009` already existed, so the catalog verifier was pointed at that directory.

### 1. `python3 tool/lint_wiki.py`

```
lint_wiki: clean (0 warning(s)).
```

Exit 0.

### 2. `dart format --set-exit-if-changed lib example/lib test example/test`

```
Formatted 26 files (0 changed) in 0.13 seconds.
FORMAT_EXIT:0
```

### 3. `dart analyze --fatal-infos --fatal-warnings`

```
Analyzing flutter_local_voice_agent...
No issues found!
ROOT_ANALYZE_EXIT:0
```

### 4. `dart analyze --fatal-infos --fatal-warnings` (cwd `example`)

```
Analyzing example...
No issues found!
EXAMPLE_ANALYZE_EXIT:0
```

### 5. `flutter test`

```
00:00 +0: loading /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_catalog_test.dart
...
00:09 +72: All tests passed!
ROOT_TEST_EXIT:0
```

72 tests. Exit 0.

### 6. `flutter test` (cwd `example`)

```
00:00 +0: loading /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_test.dart
00:00 +0: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_test.dart: catalog UI has no path input and Start waits for native setup
00:01 +1: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: selection is persisted and deletion is confined to selected id
00:02 +2: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: selection JSON round-trips catalogId and speakerId
00:02 +3: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: old catalog-id-only JSON restores speakerId 0
00:02 +4: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: damaged speaker field reports an actionable storage error
00:02 +5: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: negative speakerId reports an actionable storage error
00:02 +6: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: VCTK speaker 3 persists and restores
00:02 +7: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: VCTK out-of-range speaker id is retained
00:02 +8: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/model_storage_test.dart: damaged selection reports an actionable storage error
00:04 +9: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: first launch waits for an explicit download
00:04 +10: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: disk preflight blocks transfer before creating preparation
00:04 +11: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: verified cached retry bypasses fresh-download disk preflight
00:04 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: explicit preparation creates a session and persists selection
00:04 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: offline restoration never requests a network-enabled preparation
00:04 +14: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: cancel stays busy until preparation cleanup settles
00:04 +15: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: background cancels setup and ignores a late ready bundle
00:04 +16: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: resume recovers setup after cancellation settles
00:04 +17: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: background prevents a late start result from replacing stopped status
00:04 +18: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: pending Start remains reusable across background and resume
00:04 +19: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: switching models disposes the old session and reuses installed cache
00:04 +20: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: switching to a missing cache asks for explicit download
00:04 +21: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: integrity failure offers explicit removal and preserves other ids
00:04 +22: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: LJS hides speakers and old catalog-id restore can start
00:04 +23: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: VCTK exposes speaker ids 0 through 108
00:04 +24: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: VCTK Start is disabled when restored speaker id is 109
00:04 +25: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/example/test/voice_screen_controller_test.dart: live VCTK speaker change calls setter and does not prepare again
00:04 +26: All tests passed!
EXAMPLE_TEST_EXIT:0
```

### 7. `dart run tool/verify_catalog.dart /private/tmp/flva-catalog-verify-0009`

```
Prepare en-us-ljs-zipformer-int8: 114444636 bytes
PASS en-us-ljs-zipformer-int8: verified payload, manifest and zero-client offline reuse
Prepare en-us-ljs-zipformer-standard: 383741867 bytes
PASS en-us-ljs-zipformer-standard: verified payload, manifest and zero-client offline reuse
Prepare en-us-vctk-zipformer-int8: 116261194 bytes
PASS en-us-vctk-zipformer-int8: verified payload, manifest and zero-client offline reuse
VERIFY_CATALOG_EXIT:0
```

## Per-criterion results

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | `lib/src/model_catalog.dart:50` lists three unmodifiable entries; compact LJS at `:51`, standard LJS at `:224`, compact VCTK at `:397` with `speakerCount: 109`. `test/model_catalog_test.dart:56` asserts length 3, the three ids, titles, languages `English (US)`, speaker counts 1/1/109, and no Piper or Hebrew strings. Inventory `tool/model_catalog_inventory.json:52` records the same VCTK id and `speakerCount` 109. | yes — catalog test rejects a fourth language, Piper, and VCTK speaker count 1 |
| AC-002 | pass | VCTK synthesis and notice replacements in `tool/model_catalog_inventory.json:58` each carry source revision `5d7d647d6ea0f6206544735d74b25d3877c0f9ca`, exact `bytes`, `sha256`, installed `license` path and `uri`. Exported catalog matches that inventory in `test/model_catalog_test.dart:8`. Preparation refuses a non-hex digest at `lib/src/model_preparation.dart:246` and a mismatched body at `:565`. This reviewer re-ran `dart run tool/verify_catalog.dart /private/tmp/flva-catalog-verify-0009`; VCTK passed payload, manifest and zero-client reuse. | yes — `test/model_preparation_test.dart:339` rejects wrong-digest bodies; catalog entries all require `sha256` |
| AC-003 | pass | `LocalVoiceAgent.create` defaults `speakerId` to 0 at `lib/src/agent.dart:33` and forwards that value at `:76`. `test/agent_test.dart:238` asserts native create and `agent.speakerId` are 0 when the host omits an id. Native generate snapshots `speaker_id_` at `native/src/flva.cpp:345` after create stores the config id at `:120`. Smoke constructs `FlvaConfig c{}` at `native/tests/real_engine_smoke.cpp:20`, which zero-initializes `speaker_id`. Android and iOS default a missing argument to 0 (`FlutterLocalVoiceAgentPlugin.kt:86`, `FlutterLocalVoiceAgentPlugin.mm:72`). | yes — create-without-id test fails if native sees a non-zero id |
| AC-004 | pass | Dart rejects `speakerId < 0` with `unsupportedProfile` before native create at `lib/src/agent.dart:42`. `test/agent_test.dart:255` asserts that path and `native.created == false`. Native rejects a negative id before engine start at `native/src/flva.cpp:80` and `flva_create` at `:439`, and rejects `speaker_id >= tts_speaker_count()` after TTS load and before the worker is used for capture at `:119`. `native/tests/real_engine_failures.cpp:136` rejects -1 and `:140` rejects 100000; LJS speaker 1 is rejected when sherpa reports a single speaker (`:144`). Android `create` does not call `startAudio` (`FlutterLocalVoiceAgentPlugin.kt:80` vs `:90`). | yes — negative Dart create never reaches native; native too-large create returns nullptr with `unsupportedProfile` |
| AC-005 | pass | Ready-path setter at `example/lib/voice_screen_controller.dart:361` calls `session.setSpeakerId` and does not call `_prepareSelected`. `example/test/voice_screen_controller_test.dart:353` sets VCTK speaker 7, asserts one session, unchanged preparation count, and `disposeCalls == 0`. Native stores an in-range id at `native/src/flva.cpp:186` and generate uses that snapshot at `:345`. Native VCTK setter success is present at `native/tests/real_engine_failures.cpp:214` when a VCTK TTS file is found. Catalog-verify VCTK bytes exist and re-verified in command 7. | yes — live speaker change does not start another preparation |
| AC-006 | pass | Dart writes `_speakerId` only after native setter success (`lib/src/agent.dart:218`). `test/agent_test.dart:323` keeps previous id 3, does not dispose, and maps `unsupportedProfile` when native rejects 109. Native `set_speaker_id` returns 0 without storing when `speaker_id` is outside `[0, count)` (`native/src/flva.cpp:185`). `native/tests/real_engine_failures.cpp:156` rejects 100000 and `:159` still sees a usable session (`output_rate > 0`). | yes — failed setter keeps id 3 and the session |
| AC-007 | pass | `speakerIds` is empty when `speakerCount <= 1` (`example/lib/voice_screen_controller.dart:144`). UI shows the speaker dropdown only when `showsSpeakerControl` is true (`example/lib/main.dart:118`). Missing `speakerId` restores 0 (`example/lib/model_storage.dart:174`). `canStart` requires verified ready session and `speakerId < option.speakerCount` (`example/lib/voice_screen_controller.dart:132`). `example/test/voice_screen_controller_test.dart:295` hides LJS speakers and allows Start after offline LJS restore. `example/test/model_storage_test.dart:75` restores speaker 0 from catalog-id-only JSON. Widget test finds no Speaker label on first launch (`example/test/voice_screen_test.dart:27`). | yes — LJS speaker list is empty; missing field does not block Start |
| AC-008 | pass | VCTK `speakerIds` are `0 .. count-1` (`example/lib/voice_screen_controller.dart:145`). `example/test/voice_screen_controller_test.dart:317` asserts 0 through 108 and excludes 109. Storage persists both fields (`example/lib/model_storage.dart:134`, `example/test/model_storage_test.dart:154`). Restore uses `allowNetwork: false` (`example/lib/voice_screen_controller.dart:185`); production factory throws if a client is constructed (`:88`). `example/test/voice_screen_controller_test.dart:86` restores VCTK with `allowNetwork == false`. Out-of-range saved id 109 leaves `canStart` false (`:336`). Start button is gated on `canStart` (`example/lib/main.dart:246`). | yes — VCTK restore does not enable network; Start is false for speaker 109 |
| AC-009 | pass | `select` disposes the live session before preparing the next pack (`example/lib/voice_screen_controller.dart:206`). `example/test/voice_screen_controller_test.dart:223` switches from the first catalog option to `entries.last` (the third, VCTK) and asserts the previous session `disposeCalls == 1` before the next restore completes. | yes — old session is disposed on pack change |
| AC-010 | pass | README states three English packs, VCTK as speaker choice, integer ids, and Piper / other languages / physical-device quality outside the catalog (`README.md:124`, `:137`). Same statements in `doc/model-catalog.md:15`, `doc/models.md:10`, `doc/capabilities.md:13`, `doc/model-preparation.md:7`, `doc/testing.md:71`. No reviewed library guide still says the catalog is only two LJS packs or ranks quality. | yes — searched shipped guides for leftover two-pack-only and quality-ranking claims; none found |
| AC-011 | pass | Product record describes VCTK integer speaker control (`wiki/product/example-model-catalog.md:13`). New decision `wiki/adr/0004-english-vits-voice-selection.md:1` is active and records VCTK plus speaker id. Earlier decision `wiki/adr/0003-example-model-catalog.md:1` remains `status: active` and points at ADR 0004 for speakers (`:19`). Index reaches both decisions (`wiki/INDEX.md:145`, `:146`, `:188`, `:189`). Wiki lint was clean. | yes — 0004 is present; 0003 was not deleted |
| AC-012 | pass | Commands 1–4 in Verification performed: wiki lint clean, format unchanged, package analyze clean, example analyze clean, all with `--fatal-infos --fatal-warnings`. | yes — no analyzer info and no wiki lint failure remained |

## Findings

### F-001 — Product record overstates missing-field Start refusal for VCTK

- Severity: NIT
- Location: `wiki/product/example-model-catalog.md:15`
- Criterion affected: none
- Observation: The sentence says a missing speaker field falls back to 0 for LJS and refuses Start for VCTK until the user picks a valid id. Storage treats a missing field as 0 for every pack (`example/lib/model_storage.dart:174`). Speaker 0 is inside the VCTK range, so `canStart` is true after that restore. Start is refused for an out-of-range saved id such as 109, which is a different case.
- Why it matters: The product sentence conflates the missing-field fallback with the out-of-range Start gate. It does not remove the implemented VCTK control required by AC-011.

### F-002 — Native VCTK setter probe omits the catalog-verify tree

- Severity: NIT
- Location: `native/tests/real_engine_failures.cpp:59`
- Criterion affected: none
- Observation: `find_vctk_tts` looks at a sibling of the LJS fixture, `/private/tmp/flva-qualification/models`, and `/private/tmp/flva-catalog-installed/...`. It does not search `/private/tmp/flva-catalog-verify-0009`, where this reviewer confirmed inventoried VCTK bytes. The VCTK setter check is written to skip when those probe paths miss. Qualification models on this host contained `vits-ljs.onnx` only.
- Why it matters: The native “setter success when VCTK assets exist” path can skip even after a passing catalog verify. Controller tests still cover the no-redownload requirement. This is a probe-path gap, not a missing setter implementation.

## Recurrence check

- Previous round: none — first implementation review
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | implement (wiki product wording) |
| F-002 | implement (native test probe paths) |
