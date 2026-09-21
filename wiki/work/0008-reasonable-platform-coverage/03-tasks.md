# Tasks: Reasonable platform coverage

## Start conditions

All tasks are not started. Criteria AC-001 through AC-012 are frozen. Do not begin Group 1 until an explicit implement request. Preserve unrelated dirty files. Do not commit or publish.

## Legend

- `[P]` — may run in a parallel subagent. Only mark a task `[P]` if no other `[P]` task in the same group touches any of the same files.
- Every task cites the criteria it satisfies. A task satisfying no criterion does not belong here.
- Owned files are exclusive. Two tasks never list the same file.

## Groups

### Group 1 — Shared Dart refusal

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 1.1 | Add a default-target guard so create refuses Flutter web and other non-native hosts with unsupportedProfile before native create, and add tests for that refusal plus the existing full-duplex refusal. | AC-001 | lib/src/agent.dart, test/platform_refusal_test.dart | | Tests fail if native create is invoked on an excluded target; format and analyze pass. Status: done 2026-09-21. |

### Group 2 — Registration and provisioning

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 2.1 | Declare macos, windows and linux plugin classes in the package manifest without adding web, and extend the provisioning script with pinned official v1.12.14 desktop archives, measured SHA-256 digests and install layouts. Add a mismatch test or checked invocation. | AC-002, AC-003, AC-004 | pubspec.yaml, tool/provision_runtime.py, tool/test_provision_runtime.py | | Manifest lists five platforms and no web; a bad digest copies nothing; a matching digest installs the expected libraries. Status: done 2026-09-21. |

### Group 3 — macOS plugin and host build

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 3.1 | Add the macOS CocoaPods plugin that compiles shared native sources, vendors the pinned universal2 dylibs, owns AVAudioEngine push and render, fails start with permissionDenied without opening capture when permission is denied, suspends on deactivate and default-device change, logs no raw PCM, and generates the example macOS host with microphone usage text. Build the example on this host. | AC-005, AC-006, AC-007, AC-011, AC-012 | macos/, example/macos/ | | Source review shows no PCM on the channel or in logs; denied start cannot start capture; documented macOS build exits 0. Status: done 2026-09-21. flutter build macos --debug exit 0. Physical deny-prompt [UNVERIFIED]. |

### Group 4 — Windows and Linux plugins

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 4.1 | Add the Windows plugin with CMake imported sherpa linkage, WASAPI capture and render, the shared method names, and invalidation mapped to audioUnavailable or routeChanged. Generate example/windows sources only. Do not require a Windows Flutter build on this checkout. | AC-008, AC-011, AC-012 | windows/, example/windows/ | `[P]` | Source review shows flva_push and flva_render on audio threads and no PCM channel payload. Status: source done 2026-09-21. Windows Flutter build [UNVERIFIED] on this macOS checkout. |
| 4.2 | Add the Linux plugin with CMake imported sherpa linkage, PulseAudio record and playback, the shared method names, and server or default-device loss mapped to audioUnavailable or routeChanged. Generate example/linux sources only. Do not require a Linux Flutter build on this checkout. | AC-009, AC-011, AC-012 | linux/, example/linux/ | `[P]` | Source review shows flva_push and flva_render on audio threads and no PCM channel payload. Status: source done 2026-09-21. Linux Flutter build [UNVERIFIED] on this macOS checkout. |

### Group 5 — Parent-gate honesty and docs

| # | Task | Satisfies | Files owned | Parallel | Done when |
|---|---|---|---|---|---|
| 5.1 | Update capability and setup documentation to list the five supported platforms, excluded targets, provisioning commands and the compile-evidence boundary. Confirm Android and iOS bridges are unchanged in intent and that 0002 blockers remain open. | AC-010 | doc/capabilities.md, README.md, analysis_options.yaml, example/analysis_options.yaml, wiki/INDEX.md, wiki/product files touched by this item | | Documentation names the five platforms and the open parent gates; android and ios plugin files are not rewritten except for unavoidable shared-manifest fallout owned by 2.1. Status: done 2026-09-21. |

## Serialised files

| File | Owning task |
|---|---|
| pubspec.yaml | 2.1 |
| tool/provision_runtime.py | 2.1 |
| lib/src/agent.dart | 1.1 |
| doc/capabilities.md | 5.1 |
| wiki/INDEX.md | 5.1 |
| analysis_options.yaml | 5.1 |
| example/analysis_options.yaml | 5.1 |
| README.md | 5.1 |

## Test tasks

| # | Covers | Positive case | Negative case |
|---|---|---|---|
| T1 | AC-001 | Excluded-target create throws unsupportedProfile | Native create is invoked or inferenceFailed is thrown |
| T2 | AC-003 | Wrong digest exits non-zero | Destination library appears after a mismatch |
| T3 | AC-004 | Matching digest installs expected library names | Exit 0 with missing expected files |
| T4 | AC-005 / AC-008 / AC-009 | Review or helper tests show push and render on audio callbacks | PCM appears in method-channel arguments |
| T5 | AC-007 | Denied macOS permission returns permissionDenied | Capture starts after denial |
| T6 | AC-006 | macOS example build exits 0 | Success claimed without pasted output |
| T7 | AC-010 | 0002 blockers still listed open | A 0008 document claims those gates closed |
| T8 | AC-011 | New logs omit PCM | Frame values printed |
| T9 | AC-012 | Optional LLM stays CPU-gated | GPU backend enabled by default |
