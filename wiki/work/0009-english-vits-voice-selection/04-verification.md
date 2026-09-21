# Verification: English VITS voice selection

Commands ran on 2026-09-21 from `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent` unless a directory is named. Flutter and Dart are `/Users/ortalcohen/fvm/versions/3.47.0`. This record pastes command output. It does not claim a live VCTK `generate()` on a host that never ran one.

## Host

```text
$ flutter --version
Flutter 3.47.3 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 68c3e597a2 (6 days ago) • 2026-09-15 18:13:12 -0700
Engine • hash 14500179362846c01134680b37c7c64c17652a17 (revision 1436d132c6) (6 days ago) • 2026-09-15 21:28:00.000Z
Tools • Dart 3.13.3 • DevTools 2.50.2
```

## Wiki lint

```text
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
WIKI_EXIT:0
```

## Format and analyzer

`dart format --set-exit-if-changed lib example/lib test example/test` first exited 1 because `test/agent_test.dart` needed a format pass. After `dart format test/agent_test.dart`:

```text
$ dart format --set-exit-if-changed lib example/lib test example/test
Formatted 20 files (0 changed) in 0.21 seconds.
FORMAT_RECHECK:0

$ dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
ANALYZE_PKG_EXIT:0

$ dart analyze --fatal-infos --fatal-warnings
Analyzing example...
No issues found!
ANALYZE_EX_EXIT:0
```

The example analyze command ran with working directory `example/`.

## Tests

```text
$ flutter test
00:03 +72: All tests passed!
TEST_PKG_EXIT:0

$ flutter test
00:01 +26: All tests passed!
TEST_EX_EXIT:0
```

The example test command ran with working directory `example/`. Controller tests include LJS hiding speakers, VCTK exposing ids 0 through 108, Start disabled for restored speaker 109, and a live speaker change that calls the setter without preparing again.

Native VCTK setter-success smoke was skipped earlier in implementation: this host had no VCTK assets at that time.

## Catalog verifier

```text
$ dart run tool/verify_catalog.dart /private/tmp/flva-catalog-verify-0009
Prepare en-us-ljs-zipformer-int8: 114444636 bytes
PASS en-us-ljs-zipformer-int8: verified payload, manifest and zero-client offline reuse
Prepare en-us-ljs-zipformer-standard: 383741867 bytes
PASS en-us-ljs-zipformer-standard: verified payload, manifest and zero-client offline reuse
Prepare en-us-vctk-zipformer-int8: 116261194 bytes
PASS en-us-vctk-zipformer-int8: verified payload, manifest and zero-client offline reuse
CATALOG_EXIT:0
```

Elapsed wall time was 82782 ms. Exit code 0.

Inventory pin for the compact VCTK pack remains commit `5d7d647d6ea0f6206544735d74b25d3877c0f9ca`, `speakerCount` 109, pack `en-us-vctk-zipformer-int8`. There is no sid-to-name table.

## Git-free snapshot check

Snapshot `/private/tmp/flva-verify-snapshot-0008-0009` was copied from `git ls-files --cached --others --exclude-standard` with no `.git` metadata. `PATH` used Flutter 3.47.0.

```text
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Stage 3 passed: format
Stage 4 passed: analysis
00:06 +72: All tests passed!
00:01 +26: All tests passed!
Stage 5 passed: tests
Package has 0 warnings and 1 hint.
Stage 6 passed: package dry run
Stage 7 passed: release helper tests
CHECK_EXIT:0
```

The dry-run hint is that published 0.1.2 is newer than this checkout's 0.1.1. Stage 6 still passed.

## Per-criterion results

| ID | Result | Evidence | Negative case |
|---|---|---|---|
| AC-001 | met | Catalog tests and `VoiceModelOption.speakerCount`. Three English options: LJS INT8, LJS standard, VCTK INT8 with speaker count 109. | A fourth language or Piper entry is not in the catalog. |
| AC-002 | met | `tool/model_catalog_inventory.json` pins revision, bytes, digest and license paths. Catalog verifier PASS for all three packs, including VCTK. | A digest mismatch would fail the verifier. |
| AC-003 | met | `LocalVoiceAgent.create({int speakerId = 0})`. Dart tests cover the default. Native generate reads the stored id. | A missing default that hosts forget is not the published signature. |
| AC-004 | met | Negative create ids fail closed in Dart before native create. Native create rejects an out-of-range id with `unsupportedProfile`. LJS `NumSpeakers()==0` is treated as count 1. | A stored negative id is not accepted. |
| AC-005 | met in example tests; native VCTK generate [UNVERIFIED] | Example controller test: live VCTK speaker change calls the setter and does not prepare again. Native setter-success against real VCTK assets was skipped on this host. This record does not claim audible VCTK output. | Speaker change that re-enters preparation would fail the controller test. |
| AC-006 | met | Failed setter keeps the previous id and the session in Dart and native tests. | A failed set that wrote 109 or destroyed the session would fail those tests. |
| AC-007 | met | LJS hides the speaker control. Missing speaker field restores as 0 and can start. | LJS showing 109 speakers would fail the controller test. |
| AC-008 | met | VCTK shows ids 0 through 108. Restore is offline. Start is disabled for speaker 109. | Start succeeding with speaker 109 would fail the controller test. |
| AC-009 | met | Pack change disposes the previous session before prepare. | Two live sessions after a pack change would fail the switch test. |
| AC-010 | met by review | README and consumer guides name three English options, integer speaker ids, and keep Piper, other languages and physical-device quality outside this catalog. | A shipped guide that still says only two LJS packs was not found. |
| AC-011 | met | `wiki/product/example-model-catalog.md` describes the VCTK speaker control. `wiki/adr/0004-english-vits-voice-selection.md` records the choice. `wiki/adr/0003-example-model-catalog.md` remains reachable from the index. | The earlier catalog decision was not deleted. |
| AC-012 | met | Format recheck 0, package and example analyzer 0, wiki lint 0. See pastes above. | Analyzer info or a wiki lint failure is not recorded after the format recheck. |

## Explicitly not claimed

- A live VCTK `generate()` with audible output on this host.
- Named speakers, gender or accent metadata.
- Physical-device audio, memory or thermal qualification.
- Closure of the existing VITS allocation gate in work item 0002.
- Desktop-bridge ownership. Those files belong to work item 0008.

## Next

One implementation review at `validation/impl-review-01.md`. Do not write a second implementation review unless that report is FAIL and a later implement pass is authorized.
