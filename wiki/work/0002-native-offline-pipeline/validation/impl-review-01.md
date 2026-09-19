---
id: pipeline-impl-review-01
title: "Independent implementation review: Native offline voice pipeline"
status: active
owner: implementation-validator
last_verified: 2026-09-19
applies_to: ["**"]
summary: Blind implementation review with independently executed checks and explicit device gates.
---

# Verdict: FAIL

Reviewed the frozen acceptance criteria, validation rubric, staged and unstaged implementation, current source/tests and consumer documentation. No author plan or prior verdict was used. Source was not modified. This is a snapshot of concurrent implementation; mobile builds and optional iOS packaging were still being performed elsewhere and are not counted as independent verification here.

## Per-criterion verdicts

| Criterion | Verdict | Evidence and negative case |
|---|---|---|
| AC-001 | FAIL | `lib/src/model_store.dart:75` and `:95` enforce duplicate/required roles but accept arbitrary extra roles. Independent probe accepted `unexpectedRole`. Existing tests independently rejected traversal, corruption, missing paths, incompatible profile/runtime and symlink escape. Staging revalidation and rename exist at `:168` and `:177`; an install failure/activation test is absent from the executed suite. |
| AC-002 | FAIL | Bounded paused delivery exists at `lib/src/bounded_stream.dart:52`; late-poll/reply and shared-operation tests execute successfully. However `lib/src/agent.dart:180`, `:208` and `:228` expose raw platform exceptions, and failed stop unconditionally reports ready at `:211`. Independent negative probe reproduced both interrupt/stop raw exceptions and false ready state. `_fatal` also launches an unhandled stop future at `:431`. |
| AC-003 | PASS | Application-owned limits at `native/src/flva.cpp:28`, `:34`, generation filtering at `:174`, event overflow at `:217`, and worker join before destruction at `:151`. Plain ring/resampler tests and real-engine UBSan tests independently cover overflow, stale generation, cancellation, repeated turns and shutdown during active work. This verdict is restricted to native application buffers/ownership; upstream synthesis allocation is AC-004. Upstream prebuilt libraries are not sanitizer-instrumented. |
| AC-004 | FAIL | Actual Silero/Zipformer/VITS WAV smoke and repeated turns execute. Worker inference and RAII ownership are present. The duration bound is applied only after whole-sentence audio reaches `native/src/flva.cpp:299`; `:320` requests an upstream owned generated buffer without a duration cap. An independently executed 235-byte reply allocated 291,993 samples (13.242 seconds) before its first callback, exceeding the stated 10-second PCM bound even when that callback immediately cancels. |
| AC-005 | CONDITIONAL | Android capture/render threads and control executor exist in `android/src/main/kotlin/dev/localvoice/flutter_local_voice_agent/FlutterLocalVoiceAgentPlugin.kt:58` and `:123`; iOS audio callbacks use bounded native operations in `ios/Classes/FlutterLocalVoiceAgentPlugin.mm:99` and `:109`. Permission, interruption, route, thermal and foreground hooks exist. Physical negative cases and mobile builds were not independently executed in this review. `doc/testing.md:82` explicitly retains them as open. No platform readiness conclusion follows from host tests. |
| AC-006 | FAIL | Current optional adapter independently compiles against the local pinned llama source and runs real TinyLlama GGUF; missing-file and excessive-context cases reject. However `native/llm/llm_adapter.cpp:44` leaves a trailing UTF-8 lead byte intact. Native reply rejects this at `native/src/flva.cpp:179`, while the LLM integration ignores that refusal at `:286`, leaving capture closed and the turn awaiting a reply. Independent helper probe reproduced the malformed suffix. Smoke cancellation is only pre-decode: its second callback check at `native/llm/smoke.cpp:27` is consumed by `llm_adapter.cpp:203`, before `llama_decode`; it does not prove cancellation inside inference. |
| AC-007 | CONDITIONAL | README, capabilities, model guide, test guide, LLM guide, notices and changelog exist and explicitly distinguish physical qualification/full duplex. Strict analysis and wiki lint execute successfully. Package dry-run exits 65 with four warnings; output is preserved below. Documentation and `.pubignore` were still changing during this review, so the dry-run describes that invocation's snapshot. Missing model and full-duplex negative tests execute. |
| AC-008 | CONDITIONAL / OPEN | `doc/testing.md:71` defines offline/device/performance methodology; `:90` states no physical devices were connected. There is no independently observed physical Android/iPhone trial or adverse-route/thermal evidence in this review. The criteria explicitly permit this gate to remain open; it is not counted as simulated completion. |

## Findings

1. **BLOCKER — AC-001 — `lib/src/model_store.dart:95`: unknown manifest roles are accepted.** `containsAll` checks only the required subset. A correctly hashed extra file assigned `unexpectedRole` is accepted by the production validator and can be copied into an active staged bundle. The frozen criterion requires exact roles and a wrong-role negative case. This is a schema enforcement defect, not a claim that hashes failed.
2. **BLOCKER — AC-002 — `lib/src/agent.dart:208`: native command failures violate the public typed failure/lifecycle contract.** Stop and interrupt expose `PlatformException`; failed stop becomes ready despite no confirmed native stop. Dispose also lacks conversion, and automatic error-stop futures are unhandled at `:431`. The temporary injected-platform test reproduces raw exceptions and the incorrect ready state.
3. **BLOCKER — AC-004 — `native/src/flva.cpp:320`: the native synthesis allocation is not bounded by the output duration cap.** A legal 235-byte reply produces a complete 13.242-second buffer before the first callback. Cancellation in that callback still returns the full allocated buffer. The 500 ms render ring and 10-second admission counter do not impose the same bound on generated PCM. This is observed with the actual pinned runtime and local VITS fixture.
4. **BLOCKER — AC-006 — `native/llm/llm_adapter.cpp:44`: UTF-8 truncation can leave an invalid final lead byte and stall the optional pipeline.** When generation ends at a byte-piece boundary, a final lead byte has zero following continuation bytes, causing the early return. The malformed result is refused by native reply, whose result is ignored at `native/src/flva.cpp:286`; the closed-capture thinking turn then has no completion/error event. An empty immediate-EOG result reaches the same ignored-refusal path.
5. **IMPORTANT — AC-006 verification — `native/llm/smoke.cpp:27`: cancellation smoke stops before inference.** The callback returns true on its second invocation, which is the explicit pre-decode check, so the diagnostic string suggesting inference cancellation is unsupported. The abort callback implementation exists, but this test does not exercise it during model evaluation.

Physical qualification and package warnings are named gates in the table, not invented platform bugs. No fix or routing decision is made by this report.

## Verification performed

Commands below were executed by this reviewer. Outputs shown as excerpts are explicitly labeled; omitted output is routine progress or upstream model metadata, not a different verdict. Temporary diagnostic source is included later for reproduction.

### Strict analysis and Flutter tests

Initial sandbox attempts of both SDK commands exited 1 with:

```text
/Users/ortalcohen/fvm/versions/3.47.0/bin/internal/update_engine_version.sh: line 71: /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/engine.stamp.tmp.79899: Operation not permitted
/Users/ortalcohen/fvm/versions/3.47.0/bin/internal/update_engine_version.sh: line 78: /Users/ortalcohen/fvm/versions/3.47.0/bin/cache/engine.realm: Operation not permitted
```

Rerun with approved SDK-cache access:

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
exit=0
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test
00:00 +0: loading /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart
00:00 +0: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart: validates real local files with roles, hashes and licenses
00:03 +1: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart: rejects traversal before native setup
00:03 +2: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart: rejects a corrupt file hash
00:03 +3: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart: rejects missing manifest
00:03 +4: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart: rejects missing required model file
00:04 +5: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart: rejects wrong profile and runtime
00:04 +6: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/model_store_test.dart: rejects a symlink escape
00:04 +7: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: final transcript invokes logic and sends current-generation reply
00:04 +8: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: full duplex is rejected before platform create
00:04 +9: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: concurrent start and dispose share native operations
00:04 +10: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: suspension ignores a late logic reply
00:04 +11: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: interrupt keeps polling and admits the next current final
00:04 +12: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: late poll response after dispose is ignored
00:04 +13: /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart: paused bounded delivery replaces backlog with terminal capacity fault
00:04 +14: All tests passed!
exit=0
```

### Native tests

```sh
python3 tool/test_native.py --ubsan --runtime /private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib --assets /private/tmp/flva-qualification/models/silero_vad.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/tokens.txt /private/tmp/flva-qualification/models/vits-ljs.onnx /private/tmp/flva-qualification/models/tokens.txt /private/tmp/flva-qualification/models/lexicon.txt /private/tmp/flva-qualification/asr/sherpa-onnx-streaming-zipformer-en-2023-06-26/test_wavs/0.wav
```

Output excerpt (all compile/run subprocesses exited 0):

```text
PASS ring wrap/overflow/underflow/concurrency
high-frequency rms=0.000070
PASS resampler partition DC attenuation upsample reset invalid capacity
partial   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
final   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
reply  hello world
PASS real_engine_smoke
PASS missing path rejected
PASS invalid input rate rejected
PASS actual engine create
PASS double start idempotent
PASS interrupt resumes capture while started
PASS old generation reply refused
PASS 241 scalar ASCII reply refused
PASS truncated UTF-8 reply refused
PASS first real final
PASS first real reply admitted
PASS first playback drained
PASS second real final after reset
PASS second real reply admitted
PASS second playback drained
PASS capture overflow surfaces error
PASS cancelled generation renders silence
PASS double stop and destroy after active worker
PASSED 17 checks
exit=0
PASS real_engine_failures
```

Upstream VITS also printed repeated `Unknown token: ̃` and `Unknown token: (` lexicon warnings. No ASan or upstream-instrumented result is claimed.

```text
$ python3 tool/test_native.py
[compile/run command lines omitted]
PASS ring wrap/overflow/underflow/concurrency
high-frequency rms=0.000070
PASS resampler partition DC attenuation upsample reset invalid capacity
exit=0
```

### Independent negative probes

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test /private/tmp/flva-review-probe.dart
00:00 +0: loading /private/tmp/flva-review-probe.dart
00:00 +0: review observes unknown model role accepted
OBSERVED: unexpectedRole accepted by production manifest validator
00:00 +1: review observes raw platform exceptions and ready after failed stop
OBSERVED: interrupt/stop expose PlatformException; failed stop reports ready
00:00 +2: All tests passed!
exit=0
```

These tests assert the observed defects, so their green result is not an acceptance pass.

```sh
clang++ -std=c++17 -I native/include /private/tmp/flva-review-tts.cpp -L/private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib -lsherpa-onnx-c-api -Wl,-rpath,/private/tmp/flva-qualification/runtime/sherpa-onnx-v1.12.14-osx-universal2-shared/lib -o /private/tmp/flva-review-tts
/private/tmp/flva-review-tts
```

Output excerpt (both commands exit 0; upstream lexicon warnings omitted):

```text
reply_bytes=235 sample_rate=22050
callback_samples=291993 seconds_at_22050=13.242
returned_samples_after_callback_cancel=291993
```

### Optional LLM build and genuine GGUF smoke

An initial unqualified `cmake` command exited 127: `zsh:1: command not found: cmake`. The installed Android SDK CMake then executed:

```sh
/Users/ortalcohen/Library/Android/sdk/cmake/3.22.1/bin/cmake -S native/llm -B /private/tmp/flva-review-llm -G Ninja -DCMAKE_MAKE_PROGRAM=/Users/ortalcohen/Library/Android/sdk/cmake/3.22.1/bin/ninja -DFLVA_ENABLE_LOCAL_LLM=ON -DLLAMA_CPP_SOURCE_DIR=/private/tmp/flva-llm-source -DCMAKE_BUILD_TYPE=Release
/Users/ortalcohen/Library/Android/sdk/cmake/3.22.1/bin/cmake --build /private/tmp/flva-review-llm --parallel 4 > /private/tmp/flva-review-llm-build.txt 2>&1
/private/tmp/flva-review-llm/flva_llm_smoke /private/tmp/flva-tinyllama-q2.gguf > /private/tmp/flva-review-llm-smoke.txt 2>&1
```

All three commands exited 0. Output excerpts:

```text
-- Configuring done
-- Generating done
-- Build files have been written to: /tmp/flva-review-llm
[79/82] Building CXX object llama.cpp/src/CMakeFiles/llama.dir/unicode.cpp.o
[80/82] Linking CXX static library llama.cpp/src/libllama.a
[81/82] Linking CXX static library libflva_llm_adapter.a
[82/82] Linking CXX executable flva_llm_smoke
reply= Thank you for your feedback. We're glad to hear that our team is making progress in improving the offline experience. We'll be sure to prioritize this feature in our next update. If you have any further suggestions or feedback, please don'
cancellation=ok
over_context=ok
$ /private/tmp/flva-review-llm/flva_llm_smoke /private/tmp/flva-review-missing.gguf
error=llm model must be an existing local .gguf file
exit=1 (expected negative case)
```

Configuration warned that the archive has no Git metadata, ccache/OpenMP were unavailable, and two ARM feature probes failed. Compilation completed. No response-quality claim is made; the fixture did not follow its requested one-word answer.

```sh
clang++ -std=c++17 -I/private/tmp/flva-llm-source/include -I/private/tmp/flva-llm-source/ggml/include /private/tmp/flva-review-utf8.cpp /private/tmp/flva-review-llm/llama.cpp/src/libllama.a /private/tmp/flva-review-llm/llama.cpp/ggml/src/libggml.a /private/tmp/flva-review-llm/llama.cpp/ggml/src/libggml-cpu.a /private/tmp/flva-review-llm/llama.cpp/ggml/src/libggml-base.a /private/tmp/flva-review-llm/llama.cpp/vendor/hash/libvendor-hash.a -framework Foundation -o /private/tmp/flva-review-utf8
/private/tmp/flva-review-utf8
```

Both commands exited 0; output:

```text
after_trim_bytes=3 expected_valid_prefix_bytes=2
```

### Wiki and package checks

```text
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
exit=0
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/dart pub publish --dry-run
[dependency resolution and package inventory omitted]
Package validation found the following 4 potential issues:
* 8 checked-in files are ignored by a `.gitignore`.
* 72 checked-in files are modified in git.
* It's strongly recommended to include a "homepage" or "repository" field in your pubspec.yaml
* Rename the top-level "tools" directory to "tool".
The server may enforce additional checks.
Package has 4 warnings.
exit=65
```

No publishing was performed. Dirty checkout warnings are not permission to commit or discard changes. The full dry-run inventory contained provision scripts and native source, excluded local inference binaries, and was approximately 91 KB compressed at that invocation.

## Diagnostic source retained in this report

The following temporary sources were executed without editing repository source or tests.

### /private/tmp/flva-review-probe.dart

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import '/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/test/agent_test.dart' as fixtures;
class Native implements NativeVoicePlatform {
 Future<int> create({required Map<String,String> paths, required String mode}) async => 16000;
 Future<void> start() async {}
 Future<void> stop() async { throw PlatformException(code:'audioUnavailable', message:'synthetic stop failure'); }
 Future<void> interrupt() async { throw PlatformException(code:'audioUnavailable', message:'synthetic interrupt failure'); }
 Future<void> dispose() async {}
 Future<List<Map<String,Object?>>> poll() async => [];
 Future<void> reply({required int generation,required String text}) async {}
}
void main() {
 test('review observes unknown model role accepted', () async {
 final root=await fixtures.fixtureFixture();
 addTearDown(()=>root.delete(recursive:true));
 final manifest=File('${root.path}/manifest.json');
 final doc=jsonDecode(await manifest.readAsString()) as Map<String,dynamic>;
 final files=doc['files'] as List;
 final extra=Map<String,dynamic>.from(files.first as Map);
 extra['role']='unexpectedRole'; extra['path']='extra';
 await File('${root.path}/vad').copy('${root.path}/extra'); files.add(extra);
 await manifest.writeAsString(jsonEncode(doc));
 final result=await const FileModelStore().validate(LocalModelBundle(directory:root.path,manifestPath:manifest.path));
 expect(result.files.any((e)=>e.role=='unexpectedRole'),true);
 print('OBSERVED: unexpectedRole accepted by production manifest validator');
 });
 test('review observes raw platform exceptions and ready after failed stop', () async {
 final root=await fixtures.fixtureFixture();addTearDown(()=>root.delete(recursive:true));
 final agent=await LocalVoiceAgent.create(models:LocalModelBundle(directory:root.path,manifestPath:'${root.path}/manifest.json'),nativePlatform:Native());
 await agent.start();
 await expectLater(agent.interrupt(),throwsA(isA<PlatformException>()));
 await expectLater(agent.stop(),throwsA(isA<PlatformException>()));
 expect(agent.lifecycle,AgentLifecycle.ready);
 print('OBSERVED: interrupt/stop expose PlatformException; failed stop reports ready');
 await agent.dispose();
 });
}
```

### /private/tmp/flva-review-tts.cpp

```cpp
#include "c-api.h"
#include <cstdio>
#include <string>
int32_t callback(const float*, int32_t count, void*) { printf("callback_samples=%d seconds_at_22050=%.3f\n",count,count/22050.0); return 0; }
int main() {
 SherpaOnnxOfflineTtsConfig c{};
 c.model.vits={"/private/tmp/flva-qualification/models/vits-ljs.onnx","/private/tmp/flva-qualification/models/lexicon.txt","/private/tmp/flva-qualification/models/tokens.txt","",0.667f,0.8f,1.0f,""};
 c.model.num_threads=1;c.model.provider="cpu";c.max_num_sentences=1;
 auto* t=SherpaOnnxCreateOfflineTts(&c); if(!t)return 1;
 std::string reply;for(int i=0;i<39;i++)reply+="hello "; reply+=".";
 printf("reply_bytes=%zu sample_rate=%d\n",reply.size(),SherpaOnnxOfflineTtsSampleRate(t));
 auto* a=SherpaOnnxOfflineTtsGenerateWithCallbackWithArg(t,reply.c_str(),0,1,&callback,nullptr);
 if(a){printf("returned_samples_after_callback_cancel=%d\n",a->n);SherpaOnnxDestroyOfflineTtsGeneratedAudio(a);}
 SherpaOnnxDestroyOfflineTts(t);
}
```

### /private/tmp/flva-review-utf8.cpp

```cpp
#include "/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/llm/llm_adapter.cpp"
#include <iostream>
int main(){std::string incomplete="ok\xe2";flva::TrimIncompleteUtf8(&incomplete);std::cout<<"after_trim_bytes="<<incomplete.size()<<" expected_valid_prefix_bytes=2\n";}
```

## Recurrence check

First implementation validation round. No earlier implementation findings were supplied, compared or rechecked. Each finding above is based on this snapshot and this reviewer's own execution. This report issues one verdict and makes no repair or phase-routing decision.
