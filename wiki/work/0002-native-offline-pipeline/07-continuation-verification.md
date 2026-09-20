---
id: pipeline-07-continuation-verification
title: Continuation verification evidence
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["**"]
summary: Executed repair checks, mobile builds and emulator launch with remaining qualification gates.
---

# Verification boundaries

These results describe the continuation changes. They do not close the VITS upstream allocation bound, native consumer distribution, managed model installation or physical Android/iPhone qualification. No publication, commit or push was performed by this continuation agent. HEAD changed concurrently to 02e440e; external release work was preserved.

## Integrated repository checks

Command: `PATH=/Users/ortalcohen/fvm/versions/3.47.0/bin:$PATH sh tool/check.sh`.
The command exits 65 at package validation because tracked files are modified. It is not a green full check. The source/test stages pass as shown below. Baseline before edits had zero package warnings. Do not stage or commit to conceal the final warning. Full log: `/private/tmp/flva-final-check.log`.

Selected exact output:

```text
lint_wiki: clean (0 warning(s)).
Stage 1 passed: wiki lint
Stage 2 passed: dependencies
Formatted 13 files (0 changed) in 0.04 seconds.
Stage 3 passed: format
No issues found!
No issues found!
Stage 4 passed: analysis
00:01 +33: All tests passed!
PASS ring wrap/overflow/underflow/concurrency
PASS resampler partition DC attenuation upsample reset invalid capacity
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
Stage 5 passed: tests
* 7 checked-in files are modified in git.
Package has 1 warning.
exit=65
```

Stage 7 did not run after the dry-run warning. Both release-helper checks were executed separately:

```text
$ sh tool/test_bump_patch_version.sh
PASS bump patch positive case
$ sh tool/test_occupied_pubdev_versions.sh
PASS occupied pub.dev versions positive and malformed-response negative cases
exit=0 (each command)
```

## Real native engines

Command uses `python3 tool/test_native.py --ubsan --runtime` with the pinned local sherpa runtime and the nine assets from the historical review/handoff. The exact expanded compiler/executable/asset commands and full output are retained in `/private/tmp/flva-real-repair.log`. Upstream VITS still reports lexicon warnings; voice quality is not qualified. Prebuilt engine internals are not sanitizer-instrumented.

Selected exact output:

```text
exit=0
exit=0
PASS ring wrap/overflow/underflow/concurrency
exit=0
PASS resampler partition DC attenuation upsample reset invalid capacity
exit=0
exit=0
PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits
exit=0
exit=0
partial   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
final   AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP HERE AND THERE THE SQUALID QUARTER OF THE BROTHELS
reply  hello world
exit=0
PASS real_engine_smoke
exit=0
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
PASS real_engine_failures
```

The new native Unicode test checks every code point through U+10FFFF, excludes surrogate values, rejects truncated and malformed sequences, and checks scalar-count boundaries. The real-engine negative reply cases run only after a finalized transcript with its awaited generation, and a valid reply then succeeds on that same generation. Thus state mismatch cannot substitute for malformed-input rejection.

## Debug mobile builds

Both commands ran from `example/`, speech-only configuration, after restoring the SDK-owned `packages/flutter_tools` paths.

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/flutter build apk --debug --target-platform android-arm64
Running Gradle task 'assembleDebug'...                             36.3s
✓ Built build/app/outputs/flutter-apk/app-debug.apk
exit=0
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/flutter build ios --simulator --debug --no-codesign
Building dev.localvoice.flutterLocalVoiceAgentExample for simulator (ios)...
The following plugins do not support Swift Package Manager for ios:
  - flutter_local_voice_agent
This will become an error in a future version of Flutter. Please contact the plugin maintainers to request Swift Package Manager adoption.
Plugin flutter_local_voice_agent does not have Swift Package Manager support for ios. Consider adding Swift Package Manager compatibility to your plugin. See https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors for more information.
Running Xcode build...
Xcode build done.                                           35.4s
✓ Built build/ios/iphonesimulator/Runner.app
exit=0
```

Flutter warns that the plugin lacks Swift Package Manager support. CocoaPods build evidence does not qualify Swift Package Manager. These are locally provisioned checkout builds, not clean-consumer package builds.

## Android emulator execution

Current enumeration found Android 16/API 36 arm64 emulator `emulator-5554`, macOS and Chrome; no physical phone was listed. Installed the freshly built debug APK with `adb -s emulator-5554 install -r`, then launched the example Activity:

```text
Performing Streamed Install
Success
Status: ok
LaunchState: COLD
Activity: dev.localvoice.flutter_local_voice_agent_example/.MainActivity
TotalTime: 1767
WaitTime: 1769
Complete
```

UIAutomator observed the expected first-use screen and disabled Start. Tapped the visible Load models button with the empty path and observed:

```text
AgentFailure(AgentErrorCode.missingAsset): Model root does not exist. enabled=true
Start enabled=false
Interrupt enabled=false
Stop enabled=false
```

UI evidence: `/private/tmp/flva-emulator-start.xml` and `/private/tmp/flva-emulator-missing.xml`. This verifies installed launch and the missing-model negative path only. No model pack existed in the app's files directory. No microphone capture, speech playback, permission/lifecycle route trial, offline model reuse or physical audio claim follows.

## Release-mode compilation

Both commands ran from `example/` using the locally provisioned speech-only runtime. Android's generated example release configuration uses its development signing configuration; this is not store signing approval. iOS signing was explicitly disabled. Neither release artifact was installed on a physical device.

```text
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/flutter build apk --release --target-platform android-arm64
Running Gradle task 'assembleRelease'...
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 1420 bytes (99.9% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Running Gradle task 'assembleRelease'...                           39.4s
✓ Built build/app/outputs/flutter-apk/app-release.apk (37.5MB)
exit=0
$ /Users/ortalcohen/fvm/versions/3.47.0/bin/flutter build ios --release --no-codesign
Warning: Building for device with codesigning disabled. You will have to manually codesign before deploying to device.
Building dev.localvoice.flutterLocalVoiceAgentExample for device (ios-release)...
The following plugins do not support Swift Package Manager for ios:
  - flutter_local_voice_agent
This will become an error in a future version of Flutter. Please contact the plugin maintainers to request Swift Package Manager adoption.
Plugin flutter_local_voice_agent does not have Swift Package Manager support for ios. Consider adding Swift Package Manager compatibility to your plugin. See https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors for more information.
Running Xcode build...
Xcode build done.                                           77.0s
✓ Built build/ios/iphoneos/Runner.app (46.0MB)
exit=0
```

## Independent review and documentation checks

[Implementation review round 2](validation/impl-review-02.md) independently ran 33 Dart tests, strict analysis and real-engine UBSan smoke plus 19 failure checks. It found no new defect in these repairs and retained FAIL for the complete frozen criteria because allocation and physical qualification remain open. This is the second review; no third loop was launched. The coordinator appended missing report-schema headings without changing the verdict or evidence.

```text
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
exit=0
$ git diff HEAD --check
exit=0 (no output)
```

The user's other concurrent work changed staged files, including LICENSE and this continuation's files. The continuation agent neither staged nor committed them and did not alter the unrelated LICENSE. Verification describes the captured source snapshot, not a claim of ownership of concurrent Git operations.

Trailing spaces in pasted tool progress output were removed for repository whitespace checks; substantive output is unchanged. Concurrently staged earlier copies retain whitespace warnings until their owner stages the final versions. The final worktree check is against HEAD and does not modify the index.
