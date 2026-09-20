---
id: pipeline-impl-review-02
title: "Implementation review 02: continuation repairs"
status: active
owner: implementation-review
last_verified: 2026-09-20
applies_to: ["**"]
summary: Independent review of reply validation and platform path repairs, with host evidence and remaining whole-work-item gates.
---

# Implementation review 02

## Verdict

**FAIL for the complete frozen acceptance criteria.** AC-004's hard synthesis allocation bound and AC-008's physical qualification remain unmet. These are pre-existing gates, not regressions introduced by the reviewed continuation.

No new correctness finding was identified in the scoped continuation repairs. Dart invalid-reply rejection and recovery, native strict Unicode validation on an awaited generation, and platform script path corrections have independent supporting evidence below. This statement does not qualify the entire pipeline, mobile runtime, or consumer packaging.

This was one blind review round. Inputs were the frozen criteria, validation rubric, repository instructions, naming convention, source/diff, tests and product documentation. Author plans, research, state, prior review reports and author test logs were not read. No source repairs were made. The only repository write is this report.

## Per-criterion coverage

| Criterion | Verdict | Evidence and qualification boundary |
|---|---|---|
| AC-001 | PASS | E1 runs the filesystem manifest/install tests: corrupt/missing inputs, wrong role/runtime, traversal, symlink escape and invalid staged import have negative coverage. This establishes the tested local preflight/install contract, not a physical mobile import journey. |
| AC-002 | CONDITIONAL | E1 exercises double/concurrent lifecycle operations, paused delivery saturation, native failure, late polling/replies and six new reply cases. Empty/NUL/unpaired-surrogate/oversized replies fault before native reply and recover on a later generation; 240 supplementary scalars are admitted. Full platform integration remains [UNVERIFIED] in this review. |
| AC-003 | PASS | E2/E3 execute ring overflow/underflow/concurrency, resampler capacity/reset, stale generation and real worker stop/interrupt paths under UBSan. Real engine tests complete two turns, then reject overflow and render silence after cancellation. This is host bridge evidence; upstream prebuilt engine internals are not sanitizer-instrumented, and no ASan or device claim is made. |
| AC-004 | FAIL | E3 runs real local speech models and a bounded deterministic reply; malformed/empty/overlong replies are refused on the actual awaited generation, then a valid reply succeeds on that same generation. E2 exhaustively covers Unicode scalar encoding. F-001 remains: text and render limits do not establish a hard pre-allocation PCM bound. Maximum-duration synthesis and full offline-device behavior remain [UNVERIFIED]. |
| AC-005 | CONDITIONAL | E5 checks corrected Gradle/Xcode Flutter SDK paths against the installed SDK and parses the Xcode project/scheme. Platform builds and denial/focus/interruption/route/thermal/background physical negative cases were not run by this reviewer and remain [UNVERIFIED]. Path existence does not establish mobile runtime behavior. |
| AC-006 | CONDITIONAL | Existing adapter source has local-file loading, bounded context/output, CPU cancellation and stale reply invalidation, but pinned llama.cpp compilation and real GGUF negative tests were not rerun in this scope. Those executions remain [UNVERIFIED]; no prior report is substituted for evidence. |
| AC-007 | CONDITIONAL | E4 establishes strict analysis, formatting and wiki lint for the reviewed snapshot. README explicitly limits setup to a repository/path dependency and documents malformed reply rejection and the upstream allocation gate. Missing models and unsupported full duplex retain negative coverage in E1/E3. Package dry run, complete guide walkthrough and mobile builds were not independently run; standalone archive installation remains explicitly unfinished. |
| AC-008 | FAIL | The physical methodology and its negative cases are documented at doc/testing.md:74, but Android/iPhone network-denied and adverse-route/thermal trials with raw evidence were not executed. F-002 records this pre-existing open qualification gate. Host WAV and injected Dart platforms are not device substitutes. |

## Findings

### F-001 — PRE_EXISTING — AC-004 hard PCM allocation bound remains open

Location: `native/src/flva.cpp:305` (engine call); `native/src/flva.cpp:284` (callback-side duration bound); `doc/capabilities.md:21` (documented limitation).

The ten-second guard is applied after the engine supplies a synthesized chunk. It cannot constrain allocation already performed within VITS. The inspected local upstream implementation generates and appends sentence audio before calling its callback (`/private/tmp/flva-sherpa-src-v1.12.14/sherpa-onnx/csrc/offline-tts-vits-impl.h:299`). Rejecting invalid UTF-8 and bounding 240 text scalars does not prove the required hard PCM allocation bound. The same engine call exists at HEAD and the capability document already records the gate. Severity is PRE_EXISTING; its criterion remains blocking for whole-work-item completion.

### F-002 — PRE_EXISTING — physical qualification evidence remains absent

Location: `doc/testing.md:85` and `doc/testing.md:93`.

The required network-denied, lifecycle/cancel, route and thermal trials have a documented protocol but no physical execution evidence in this review. The document expressly states that no physical devices were connected during implementation; the same statement is present at HEAD. AC-008 remains unmet, and AC-005's physical behavior is unqualified. No device performance or acoustic measurement is inferred from host results.

## Independent execution evidence

### E1 — Dart suite

Command:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test --no-pub --reporter expanded
```

The first restricted attempt could not update the external SDK cache:

```text
/Users/ortalcohen/fvm/versions/3.47.0/bin/internal/update_engine_version.sh: line 71: /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/engine.stamp.tmp.85015: Operation not permitted
/Users/ortalcohen/fvm/versions/3.47.0/bin/internal/update_engine_version.sh: line 78: /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/engine.realm: Operation not permitted
```

The tool-approved external-cache retry exited 0. Pasted output:

```text
00:00 +0: loading /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/review_regression_test.dart
00:00 +0: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/review_regression_test.dart: rejects a correctly hashed unsupported manifest role
00:00 +1: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +2: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +3: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +4: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +5: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +6: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +7: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +8: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: empty logic reply faults and permits the next turn
00:00 +9: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_install_test.dart: installs a validated bundle atomically with unchanged hashes
00:00 +10: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +11: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +14: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +15: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +16: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +17: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +18: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:00 +19: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: embedded NUL logic reply faults and permits the next turn
00:00 +20: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +21: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: automatic stop failure is delivered without an unhandled future
00:00 +22: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_install_test.dart: repeated installs retain earlier active bundles
00:00 +23: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +24: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired high surrogate logic reply faults and permits the next turn
00:00 +25: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
00:00 +26: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/lifecycle_failure_test.dart: logic error handles a failed background interrupt
00:00 +27: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: unpaired low surrogate logic reply faults and permits the next turn
00:00 +28: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: interrupt keeps polling and admits the next current final
00:00 +29: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
00:00 +30: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
00:00 +31: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: oversized reply retains capacityExceeded and permits recovery
00:00 +32: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/reply_validation_test.dart: 240 supplementary Unicode scalars and 960 UTF-8 bytes are accepted
00:00 +33: All tests passed!
```

### E2 — standalone native tests under UBSan

The following commands were executed in Python subprocesses with `check=True` and a 30-second execution timeout per test. Each executable used a distinct temporary build path, separate from the author's build.

```sh
clang++ -std=c++17 -g -pthread -fsanitize=undefined -Inative/include -Inative/src native/tests/spsc_ring_test.cpp -o /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-native-jq6_3_fg/spsc_ring_test
/var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-native-jq6_3_fg/spsc_ring_test
clang++ -std=c++17 -g -pthread -fsanitize=undefined -Inative/include -Inative/src native/tests/resampler_test.cpp -o /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-native-jq6_3_fg/resampler_test
/var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-native-jq6_3_fg/resampler_test
clang++ -std=c++17 -g -pthread -fsanitize=undefined -Inative/include -Inative/src native/tests/utf8_test.cpp -o /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-native-jq6_3_fg/utf8_test
/var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-native-jq6_3_fg/utf8_test
```

Source/include arguments above are shortened relative to the repository root; the actual invocations used their absolute equivalents. Pasted output, in the same order:

```text
exit=0
high-frequency rms=0.000070
PASS resampler partition DC attenuation upsample reset invalid capacity
exit=0
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
exit=0
```

### E3 — real speech model integration under UBSan

Commands and full pasted output follow. The runtime and model paths were independently located locally. The bridge and tests were freshly compiled for this review. Runtime/model hashes were not re-audited in this review; pinned provenance is [UNVERIFIED] beyond the supplied local runtime directory and repository header/configuration. Upstream lexicon warnings are preserved; these runs do not qualify arbitrary text pronunciation.

```text
$ clang++ -std=c++17 -g -pthread -fsanitize=undefined -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/include -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src/flva.cpp /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/tests/real_engine_smoke.cpp -L/private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib -lsherpa-onnx-c-api -Wl,-rpath,/private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib -o /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-real-j1nx1uv3/real_engine_smoke
$ /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-real-j1nx1uv3/real_engine_smoke /private/tmp/flva-qualification/models/silero_vad.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/tokens.txt /private/tmp/flva-qualification/models/vits-ljs.onnx /private/tmp/flva-qualification/models/tokens.txt /private/tmp/flva-qualification/models/lexicon.txt /private/tmp/flva-qualification/vad-0.wav
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: (
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
state
state
partial   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
final   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
reply  hello world
state
state
exit=0
$ clang++ -std=c++17 -g -pthread -fsanitize=undefined -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/include -I/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src/flva.cpp /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/tests/real_engine_failures.cpp -L/private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib -lsherpa-onnx-c-api -Wl,-rpath,/private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib -o /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-real-j1nx1uv3/real_engine_failures
$ /var/folders/gl/7cm92gjx1pq9ftt5fxjthhbw0000gn/T/flva-review-real-j1nx1uv3/real_engine_failures /private/tmp/flva-qualification/models/silero_vad.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/tokens.txt /private/tmp/flva-qualification/models/vits-ljs.onnx /private/tmp/flva-qualification/models/tokens.txt /private/tmp/flva-qualification/models/lexicon.txt /private/tmp/flva-qualification/vad-0.wav
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: (
/Users/runner/work/sherpa-onnx/sherpa-onnx/sherpa-onnx/csrc/lexicon.cc:ConvertTokensToIds:91 Unknown token: ̃
PASS missing path rejected
PASS invalid input rate rejected
PASS actual engine create
PASS double start idempotent
PASS interrupt resumes capture while started
PASS old generation reply refused
PASS first real final
PASS 241 scalars refused on awaited generation
PASS malformed UTF-8 refused on awaited generation
PASS empty reply refused on awaited generation
PASS wrong generation refused while awaiting reply
PASS first real reply admitted
PASS first playback drained
PASS second real final after reset
PASS second real reply admitted
PASS second playback drained
PASS capture overflow surfaces error
PASS cancelled generation renders silence
PASS double stop and destroy after active worker
PASSED 19 checks
exit=0
```

### E4 — analysis, formatting and wiki lint

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
exit=0
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib example/lib test/reply_validation_test.dart
Formatted 8 files (0 changed) in 0.03 seconds.
exit=0
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
exit=0
```

Wiki lint was run before this report was written, so that result is not evidence that this report itself has been linted.

### E5 — platform path and project structure checks

Commands:

```sh
python3 - <<'CHECK'
from pathlib import Path
sdk=Path('/Users/ortalcohen/fvm/versions/3.47.0')
for rel in ['packages/flutter_tools/gradle','packages/flutter_tools/bin/xcode_backend.sh']:
 path=sdk/rel
 print(str(path)+': '+('EXISTS' if path.exists() else 'MISSING'))
CHECK
plutil -lint example/ios/Runner.xcodeproj/project.pbxproj
python3 - <<'CHECK'
import xml.etree.ElementTree as ET
ET.parse('example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme')
print('Runner.xcscheme: XML parsed')
CHECK
```

Pasted output:

```text
/Users/ortalcohen/fvm/versions/3.47.0/packages/flutter_tools/gradle: EXISTS
/Users/ortalcohen/fvm/versions/3.47.0/packages/flutter_tools/bin/xcode_backend.sh: EXISTS
example/ios/Runner.xcodeproj/project.pbxproj: OK
Runner.xcscheme: XML parsed
exit=0
```

## Unresolved verification boundaries

No mobile build, physical device test, package dry run, LLM execution, runtime/model hash re-audit, ASan execution or hard VITS pre-allocation bound was established by this review. Negative cases for AC-005, AC-006 and AC-008 were not independently exercised. E1-E5 apply to the inspected continuation snapshot and host toolchain; they do not supply missing qualification evidence. The original restricted Flutter cache attempt was resolved by the approved retry and is not an outstanding test failure.

## Verification performed

Coordinator schema supplement: executed reviewer commands and pasted outputs are retained above in [Independent execution evidence](#independent-execution-evidence). This heading supplies the required report schema; it does not change any result or verdict.

## Recurrence check

Coordinator schema supplement: this is the second numbered implementation review. The reviewer received a fresh context and did not read the previous verdict. The whole-item FAIL retains the already open allocation and physical qualification gates; no new defect was reported in the scoped repairs. No third implementation review is launched. The coordinator must retain those gates and surface the unresolved design/device decisions to the user.
