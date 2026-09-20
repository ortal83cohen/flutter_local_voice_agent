---
id: pipeline-04-verification
title: Implementation verification snapshot
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Executed checks, review dispositions and explicitly unfulfilled exit gates.
---

# Verification snapshot

This work item remains in implementation. The independent verdict in
[impl-review-01](validation/impl-review-01.md) is FAIL and is preserved unchanged.
The following are coordinator checks after repairs, not a replacement verdict.

## Verification performed

Commands below ran from the repository unless a directory is specified. Flutter
is `/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter`; Dart is its cached SDK.
Raw outputs are in the linked files; excerpts are reproduced here.

### Dart

`dart format lib example/lib test`:

```text
Formatted lib/src/agent.dart
Formatted test/lifecycle_failure_test.dart
Formatted 12 files (2 changed) in 0.04 seconds.
```

`flutter test --reporter expanded` (exit 0):

```text
00:03 +27: All tests passed!
```

`dart analyze --fatal-infos --fatal-warnings` (exit 0):

```text
Analyzing flutter_local_voice_agent...
No issues found!
```

See [tests](evidence/dart-tests-final.txt), [analysis](evidence/analyze-final.txt),
and [format](evidence/format-final.txt). These include real filesystem integrity
and staging tests and injected platform lifecycle tests. They are not engine or
microphone proof. Six final regression cases cover typed start/stop/interrupt/
dispose failure, cleanup retry, automatic stop failure and failed background
interrupt after a logic error.

### Real native engines

The complete exact nine-asset native command and independent output are retained
in [the review](validation/impl-review-01.md). Coordinator output is also retained
in [native-tests-03](evidence/native-tests-03.txt). The command is
`python3 tool/test_native.py --ubsan --runtime <local-sherpa-lib> --assets <nine-local-assets>`.
No mock inference implementation is linked.

```text
PASS ring wrap/overflow/underflow/concurrency
high-frequency rms=0.000070
PASS resampler partition DC attenuation upsample reset invalid capacity
PASS real_engine_smoke
PASSED 17 checks
PASS real_engine_failures
```

Host real VAD/ASR/TTS tests cover repeated turns and cancelled playback. This is
WAV input and PCM drain on macOS, not mobile microphone/speaker qualification.
ASan stalled before main even in a trivial host probe; UBSan is the completed
sanitizer check. Upstream prebuilt libraries are not sanitizer-instrumented.

### Optional LLM

With CMake at `/Users/ortalcohen/Library/Android/sdk/cmake/3.22.1/bin/cmake`,
configure `native/llm` into `build/llm-host`, setting `FLVA_ENABLE_LOCAL_LLM=ON`,
`LLAMA_CPP_SOURCE_DIR=/private/tmp/flva-llm-source`, Release and Ninja (the Ninja
binary is adjacent to CMake). The executed follow-up commands were
`cmake --build build/llm-host --parallel 4`, `build/llm-host/flva_utf8_test`, and
`build/llm-host/flva_llm_smoke /private/tmp/flva-tinyllama-q2.gguf`.
[Raw output](evidence/llm-host-final.txt), exit 0:

```text
utf8_trim=ok
llama_decode: failed to decode, ret = 2
cancellation_during_decode=ok checks=3
over_context=ok
```

The ret=2 line is the intentionally exercised CPU abort. Real model generation
also returned text. It failed the fixture's one-word conversational intent;
this is engine/cancellation evidence, not response-quality approval.

### Mobile compilation

The final local optional LLM XCFramework was generated with:

`python3 tool/build_llm_ios.py --source /private/tmp/flva-llm-source --cmake /Users/ortalcohen/Library/Android/sdk/cmake/3.22.1/bin/cmake --output /private/tmp/flva-llm-final-ios`

[Framework output](evidence/llm-ios-framework-final.txt), exit 0. The framework
was copied into ignored `ios/Frameworks`, followed by
`FLVA_ENABLE_LOCAL_LLM=1 pod install --project-directory=example/ios`.
From `example`, `FLVA_ENABLE_LOCAL_LLM=1 flutter build ios --simulator --debug --no-pub`
returned exit 0 ([output](evidence/ios-llm-final.txt)):

```text
Xcode build done.                                           18.3s
✓ Built build/ios/iphonesimulator/Runner.app
```

This optional build supports the arm64 simulator slice. Swift Package Manager
migration remains a Flutter warning; CocoaPods is the tested path. Earlier
`ios-llm-build.txt` does NOT establish optional linkage because pod installation
failed and left a stale configuration. `ios-llm-build-02.txt` records the later
slice failure. The final build above supersedes these attempts.

Android final command from `example`:
`env ORG_GRADLE_PROJECT_flvaEnableLocalLlm=ON ORG_GRADLE_PROJECT_flvaLlamaSource=/private/tmp/flva-llm-source flutter build apk --debug --no-pub`.
Exit 0, [final output](evidence/android-llm-final.txt):

```text
Running Gradle task 'assembleDebug'...                             65.8s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

No app was launched in a simulator or on a physical mobile device. Neither
unsigned release builds nor release installation were qualified.

### Package validation

`dart pub publish --dry-run` returned exit 65, not PASS:

```text
Package has 3 warnings.
```

[Full output](evidence/package-dry-run-final.txt): tracked ignored files, dirty
tracked files and the plural `tools` directory remain warnings. Repository URL
metadata was added. Nothing was published; no commit or cleanup is authorized.

## Review decisions

- F1: fixed role allowlist; unknown-role and staged import regressions pass.
- F2: mapped public native PlatformExceptions, retained failed stop state,
  retryable disposal, and caught automatic stop/interrupt failures. Six new
  coordinator regression tests pass. This is not physical resource-release proof.
- F3: OPEN BLOCKER. Upstream VITS allocates a whole sentence before callback.
  Independent input of 235 bytes yielded 291,993 samples / 13.242 seconds before
  cancellation, exceeding the 10-second admission bound. Short text alone does
  not prove an internal hard allocation limit. AC-004 remains unsatisfied.
- F4: fixed UTF-8 valid-prefix handling and rejected/empty LLM reply propagation.
  Host regression and real model smoke pass.
- F5: replaced pre-decode-only cancellation smoke with actual CPU decode abort.
  The final output above records three cancellation checks.

## Recurrence check

No validator was asked to recheck its own findings. The single independent FAIL
stands. The coordinator verified repairs and recorded F3 as unresolved, instead
of changing frozen criteria. Missing physical tests, ASan, hard synthesis bounds,
release packaging and consumer qualification remain explicit open gates.

## Concurrent checkout note

At handoff another task renamed tools to tool and edited build/release files.
The commands above retain the spelling actually executed. Their outputs prove
that execution snapshot; subsequent external configuration changes require
their own validation. See 05-handoff.md.

## Handoff documentation checks

After observing the concurrent rename, `python3 tool/lint_wiki.py` exited 0:

```text
lint_wiki: clean (0 warning(s)).
```

`git diff --check` exited 0 with no output. The initial lint invocation against
removed tools/lint_wiki.py failed; the evidence log retains that attempt.
