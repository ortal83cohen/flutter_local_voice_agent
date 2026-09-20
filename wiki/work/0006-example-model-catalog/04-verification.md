---
id: example-catalog-verification
title: Example model catalog verification
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**", "test/**", "tool/**"]
summary: Actual catalog bytes, native host execution, tests and mobile verification with explicit boundaries.
---

# Catalog and example verification

## Real catalog downloads and offline reuse

Command, pinned Dart 3.13 / Flutter 3.47 toolchain:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/cache/dart-sdk/bin/dart run tool/verify_catalog.dart /private/tmp/flva-catalog-installed
```

Exit 0. Exact output from /private/tmp/flva-catalog-real-download.log:

```text
Prepare en-us-ljs-zipformer-int8: 114444636 bytes
PASS en-us-ljs-zipformer-int8: verified payload, manifest and zero-client offline reuse
Prepare en-us-ljs-zipformer-standard: 383741867 bytes
PASS en-us-ljs-zipformer-standard: verified payload, manifest and zero-client offline reuse
```

These are actual publisher downloads through the implemented descriptor/redirect/staging code, not copied fixture files. The installed manifests and role paths are recorded in /private/tmp/flva-catalog-installed/verification.json. Each second preparation used a throwing client factory, proving offline cache reuse without a constructed client. Independent research review additionally rehashed the downloaded research files and compared live publisher metadata.

## Real native inference on installed files

For each entry of verification.json, invoked build/native/real_engine_smoke with its installed vad, encoder, decoder, joiner, asrTokens, ttsModel, ttsTokens and ttsLexicon paths, followed by the genuine mono 16 kHz test_wavs/0.wav fixture from the existing Zipformer qualification cache. Exact expanded commands and output are retained in /private/tmp/flva-catalog-installed-native.log. Both invocations exited 0. Output excerpts:

```text
final   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
reply  hello world
EXIT 0
PASS en-us-ljs-zipformer-int8 actual downloader -> native recognition/reply/synthesis
final   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
reply  hello world
EXIT 0
PASS en-us-ljs-zipformer-standard actual downloader -> native recognition/reply/synthesis
```

The native smoke requires recognition, accepted reply, synthesis and rendered playback completion. It uses the existing genuine sherpa host build, not a fake engine. Upstream VITS emitted the known lexicon token warnings; this does not establish arbitrary pronunciation quality, a hard VITS output allocation bound, or physical device audio qualification.

## Initial package regressions

Command: `/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter test --reporter expanded`, exit 0. Output from /private/tmp/flva-catalog-root-tests.log:

```text
00:05 +63: All tests passed!
```

This includes seven new catalog/redirect test groups. Real TLS coverage checks the default rejection, explicit 301/302/303/307/308 and relative redirects, exact cross-origin opt-in, loop/hop limits, invalid/credential/downgrade targets, unchanged final integrity, policy immutability/admission, delayed-header cancellation and timeout. Existing preparation and offline agent regressions remain intact. Example tests and final full-check evidence follow after the example controller stabilizes.

## Interim mobile compilation

`flutter build apk --debug` on the pinned SDK produced:

```text
Running Gradle task 'assembleDebug'...                             27.0s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

The draft build installed with adb install -r and launched on emulator-5554 (sdk_gphone64_arm64). A standard pack was already installed by the time coordinator UI inspection occurred; that observation is not claimed as a coordinator-observed first download. An initial simultaneous iOS build saw the worker's intermediate incomplete Dart edit (_beginBusy/_endBusy) and failed; a settled-source rebuild is required below. No interim result is final acceptance.

## Settled-source full checks and mobile builds

A byte-preserving copy of 261 tracked and nonignored source files, excluding Git metadata and ignored build/model caches, was checked in /private/tmp/flva-catalog-snapshot-m2ao0v5d. The original staged and unstaged checkout was preserved. Command: `PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH sh tool/check.sh`. Exit 0; full output: /private/tmp/flva-catalog-accepted-check.log. Exact final output:

```text
Package has 0 warnings.
Stage 6 passed: package dry run
PASS bump patch positive case
PASS occupied pub.dev versions positive and malformed-response negative cases
Stage 7 passed: release helper tests
```

Stages 1–5 also passed: formatting, strict analysis, 63 package tests, 16 example tests, native primitive/Unicode checks and wiki lint. The source checkout's earlier dry run reported dirty-Git warnings; the snapshot isolates packaging without staging or modifying user work.

Final commands in example using pinned Flutter: `flutter build apk --debug` and `flutter build ios --simulator --debug`. Both exit 0. Exact output from /private/tmp/flva-catalog-android-accepted.log and /private/tmp/flva-catalog-ios-accepted.log:

```text
Running Gradle task 'assembleDebug'...                              8.2s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Xcode build done.                                           19.6s
✓ Built build/ios/iphonesimulator/Runner.app
```

The final APK installed on emulator-5554 with `adb install -r` returning `Success`. The iOS engine registrar messenger compile error from an intermediate build was corrected; the successful settled build supersedes it. iOS runtime and physical-device qualification are not claimed.

## Android visible first-use and offline acceptance

Using the installed final APK on sdk_gphone64_arm64, the coordinator selected compact from the catalog. Before download the UI reported `This model is not installed yet. Download it when ready.` and disabled Start. Tapping Download showed `Downloading verified model files` and byte progress. Cancel produced `Model preparation was cancelled. Tap Download and prepare to retry.` Retrying downloaded actual network bytes; no model files were copied into the app. It reached `Installed and verified` and `Ready. Tap Start and allow microphone access.` Tapping Start produced `running · listening`; Stop was then tapped.

Evidence is retained in /private/tmp/flva-final-compact-before-download.xml, flva-final-download-progress.xml, flva-final-cancelled.xml, flva-final-retry.xml, flva-final-download-status.xml and flva-final-started.xml. The existing standard installation was preserved; its original download was not attributed to this walkthrough.

For offline restart, recorded both Android wifi_on and mobile_data as 1, disabled both with `adb shell svc wifi disable` and `adb shell svc data disable`, force-stopped the app, then launched it with `adb shell monkey -p dev.localvoice.flutter_local_voice_agent_example 1`. Exact launch output included:

```text
Events injected: 1
## Network stats: elapsed time=17ms (0ms mobile, 0ms wifi, 17ms not connected)
```

Without a download, the saved compact selection restored, verified and reached Ready. Start again produced `running · listening` while network remained disabled. Evidence: /private/tmp/flva-final-offline-ready.xml and /private/tmp/flva-final-offline-listening.xml. Stop was tapped, then both network settings were restored with svc enable. Final screenshot: /private/tmp/flva-example-catalog-final.png. This proves the emulator setup, persistence and listening-state flow, not physical microphone/speaker quality or acoustic latency. Real speech recognition and synthesis evidence is the separate host fixture run above.

## Final source identity and whitespace boundary

Hash comparison of lib, example, test, tool, native, android and ios files against the accepted full-check snapshot printed `Source comparison against full-check snapshot: identical`. Subsequent edits only update documentation and verification records. `python3 tool/lint_wiki.py` printed `lint_wiki: clean (0 warning(s)).` The scoped `git diff HEAD --check -- lib example test tool doc README.md CHANGELOG.md wiki/work/0006-example-model-catalog wiki/product/example-model-catalog.md wiki/adr/0003-example-model-catalog.md wiki/INDEX.md` exited 0 without output.

Whole-checkout `git diff HEAD --check` additionally reports six pre-existing whitespace-only blank lines in work0005/validation/impl-review-02.md (187, 189, 191, 193, 205, 207). That append-only historical report is outside this work item and was preserved. This is not represented as a clean whole-checkout whitespace check.

Exact stage/test lines from the full-check log:

```text
lint_wiki: clean (0 warning(s)).
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Stage 3 passed: format
No issues found!
No issues found!
Stage 4 passed: analysis
00:04 +63: All tests passed!
00:00 +16: All tests passed!
Stage 5 passed: tests
```
