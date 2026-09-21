# Tasks: English VITS lexicon voice selection

## Legend

- `[P]` — may run in a parallel subagent. Only mark a task `[P]` if no other `[P]` task in the same group touches any of the same files.
- Every task cites the criteria it satisfies. A task satisfying no criterion does not belong here.
- Owned files are exclusive. Two tasks never list the same file.

## Groups

### Group 1 — Inventory and catalog

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | Pin VCTK INT8 synthesis files and notices with frozen revision, bytes, digest and license paths, reusing the existing compact Zipformer and Silero pins. | AC-002 | tool/model_catalog_inventory.json | | Inventory records every VCTK role used by the catalog. Status: done 2026-09-21. Frozen commit 5d7d647d6ea0f6206544735d74b25d3877c0f9ca. No sid-to-name table. |
| 1.2 | Add speaker count to catalog options, keep both LJS entries, add the compact VCTK entry, and extend catalog tests. | AC-001, AC-002 | lib/src/model_catalog.dart, test/model_catalog_test.dart | | Tests assert three English options and speaker counts 1 and 109. Status: done 2026-09-21. |

### Group 2 — Library and native speaker id

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 2.1 | Accept and validate speaker id on agent create and add a live setter on the Dart facade and platform contract. | AC-003, AC-004, AC-005, AC-006 | lib/src/agent.dart, lib/src/contracts.dart, lib/src/models.dart, test/agent_test.dart, test/reply_validation_test.dart, test/lifecycle_failure_test.dart | | Default id is 0; negative ids fail before native create; a failed setter keeps the previous id and the session. Status: done 2026-09-21. |
| 2.2 | Store, range-check and apply speaker id in the native session, including a setter used by the next generate. | AC-003, AC-004, AC-005, AC-006 | native/include/flva.h, native/src/flva.cpp, native/tests/real_engine_smoke.cpp, native/tests/real_engine_failures.cpp | | Illegal ids fail create or set without changing the stored id or destroying the session; generate reads the stored id. Status: done 2026-09-21. VCTK setter success skipped: no host VCTK assets. |
| 2.3 | Pass speaker id through the existing Android and iOS bridges. | AC-003, AC-004, AC-005 | android/src/main/cpp/bridge.cpp, android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt, ios/Classes/FlutterLocalVoiceAgentPlugin.mm | | Mobile create and setter payloads include speaker id. Status: done 2026-09-21. Mobile compile not re-run in this session. |

### Group 3 — Example

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 3.1 | Persist and restore catalog id plus speaker id, with LJS missing-field fallback and VCTK range refusal. | AC-007, AC-008 | example/lib/model_storage.dart, example/test/model_storage_test.dart | | Selection JSON round-trips both fields and damaged speaker data fails closed. Status: done 2026-09-21. |
| 3.2 | Show the speaker control only for VCTK, apply live speaker changes, and dispose on pack change. | AC-005, AC-007, AC-008, AC-009 | example/lib/voice_screen_controller.dart, example/lib/main.dart, example controller tests | | LJS hides speakers; VCTK lists 0-108; pack change disposes first. Status: done 2026-09-21. |

### Group 4 — Documentation

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 4.1 | Update library consumer documentation and README so they describe three English options, integer speaker ids, and the deferred Piper or language limits. | AC-010, AC-012 | README.md, doc/model-catalog.md, doc/models.md, doc/capabilities.md, doc/model-preparation.md, doc/testing.md | | No consumer guide still claims only two LJS packs. Status: done 2026-09-21. |
| 4.2 | Update wiki product records, add the speaker-id architecture decision, keep the earlier catalog decision, and refresh the index. | AC-011, AC-012 | wiki/product/example-model-catalog.md, wiki/adr/0004-english-vits-voice-selection.md, wiki/adr/0003-example-model-catalog.md, wiki/INDEX.md | | Index reaches every new document; old catalog decision remains. Status: done 2026-09-21. |

### Group 5 — Verification

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 5.1 | Run format, analyzer, Dart tests, wiki lint and the catalog verifier; paste output into the verification record. | AC-002, AC-012 | wiki/work/0009-english-vits-voice-selection/04-verification.md | | Commands are recorded and wiki lint is clean. Status: done 2026-09-21. |

## Serialised files

| File | Owning task |
|---|---|
| lib/src/model_catalog.dart | 1.2 |
| lib/src/agent.dart | 2.1 |
| native/src/flva.cpp | 2.2 |
| example/lib/model_storage.dart | 3.1 |
| example/lib/voice_screen_controller.dart | 3.2 |
| wiki/INDEX.md | 4.2 |

## Test tasks

| # | Covers | Positive case | Negative case |
|---|---|---|---|
| T-001 | AC-001 | Catalog lists three English ids and speaker counts 1, 1, 109 | Catalog accepts a non-English or Piper option |
| T-002 | AC-002 | Verifier matches pinned VCTK digest | Altered bytes fail activation |
| T-003 | AC-003 | Create without speaker id generates with 0 | Missing default becomes a required argument that hosts forget |
| T-004 | AC-004 | Create with 0 on LJS succeeds | Create with -1 or 1 on LJS fails |
| T-005 | AC-005 | VCTK setter 7 is used on the next reply | Setter starts a download |
| T-006 | AC-006 | Failed setter leaves the previous id | Failed setter writes 109 |
| T-007 | AC-007 | LJS restore with old catalog-id-only JSON starts | LJS shows a 109-speaker list |
| T-008 | AC-008 | VCTK restore of speaker 3 is offline | VCTK Start with speaker 109 is enabled |
| T-009 | AC-009 | Pack change disposes before prepare | Previous session still receives start |
| T-010 | AC-010 | Consumer guides name three options and integer ids | README still says the same LJS voice only |
| T-011 | AC-011 | Index links the product record and new decision | Old catalog decision is removed |
| T-012 | AC-012 | Format, analyze and wiki lint output is clean | Wiki lint reports a plan fence or missing index link |
