---
id: pipeline-consumer-packaging-continuation
title: Consumer packaging continuation audit
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["**"]
summary: Source inspection and explicitly unresolved continuation gates.
---

# Clean-consumer and native packaging audit

Audit date: 2026-09-20

Scope: read-only source and current package-payload audit. No application build,
publication, commit, model redistribution, or ABI/engine change was performed.
The current contract remains sherpa-onnx 1.12.14, optional llama.cpp b10976,
Android arm64-v8a, CocoaPods on iOS, and physical-device qualification as a
separate gate.

## Findings

### P0 — The current pub payload cannot supply the native speech runtime required by either platform

- `.pubignore:48-50` excludes `android/src/main/jniLibs/` and
  `ios/Frameworks/`.
- `android/src/main/cpp/CMakeLists.txt:5-8` requires
  `android/src/main/jniLibs/${ANDROID_ABI}/libsherpa-onnx-c-api.so` and stops
  configuration with `FATAL_ERROR` when it is absent.
- `ios/flutter_local_voice_agent.podspec:16-20` declares
  `Frameworks/sherpa-onnx.xcframework` and
  `Frameworks/onnxruntime.xcframework` as vendored frameworks. Those paths are
  absent from the current pub payload.
- The executed current command
  `/Users/ortalcohen/fvm/versions/3.47.0/bin/dart pub publish --dry-run`
  exited 0 and printed a 92 KB payload. Its inventory includes the Android CMake
  file and iOS podspec, but contains no `jniLibs` directory and no `Frameworks`
  directory. This is direct payload evidence, rather than an inference from Git
  ignore state.
- The locally successful builds do not exercise this payload. The runtime inputs
  present in the checkout are ignored local files: `.gitignore:37-39`. The
  checkout currently contains about 20 MB under Android `jniLibs` and about
  376 MB under iOS `Frameworks`.

Impact: a consumer receiving version 0.1.0 from pub.dev would receive the native
bridge source but not the native libraries it links against. Android has an
explicit configuration failure. CocoaPods receives vendored-framework paths
whose files were excluded. A zero-warning pub dry run therefore does not mean
the package is consumable.

### P0 — Published setup instructions depend on tools that the same payload excludes

- `README.md:22-31` instructs the consumer to run
  `python3 tool/provision_runtime.py android` and the corresponding iOS command.
- `.pubignore:1-3` excludes the complete `tool/` directory.
- `tool/provision_runtime.py:33-43` is the only repository implementation that
  installs the pinned runtime files into the exact Android and iOS paths required
  by the build definitions.
- `doc/testing.md:39-45` repeats those unavailable commands for mobile builds.
- `doc/llm.md:3-9` points to the excluded `tool/provision_llama.py`; its iOS path
  at `doc/llm.md:28-34` also depends on the excluded
  `tool/build_llm_ios.py` and excluded `ios/Frameworks/flva-llm.xcframework`.

Impact: even a consumer willing to perform explicit build-time provisioning
cannot follow the published instructions from the published package. The
repository checkout can be provisioned; the current pub artifact cannot.

### P1 — Release checks can pass without proving a clean consumer build

- `tool/check.sh:5-16` runs source lint, dependency resolution, formatting,
  analysis, package tests, host native tests, a pub dry run, and release-helper
  tests. It creates no separate consumer app and builds neither Android nor iOS.
- `tool/test_native.py` without `--runtime` only exercises the native support
  tests; `doc/testing.md:23-29` requires explicit runtime and nine model assets
  for the real speech engine tests.
- `wiki/work/0002-native-offline-pipeline/04-verification.md:119-129` records an
  Android debug build and an arm64 iOS simulator debug build from the provisioned
  repository checkout, and explicitly states that unsigned release builds and
  release installation were not qualified.
- `wiki/work/0002-native-offline-pipeline/STATE.yaml:10-18` already keeps
  AC-007 consumer packaging, release builds, and clean-consumer installation
  open. The current dry run removes the historical warning symptom but does not
  close those gates.

Impact: the release pipeline has no regression test for the P0 payload defect.
`dart pub publish --dry-run` now passes with zero warnings while the native
runtime is absent.

### P1 — Current package documentation contains links and contributor commands that are absent from the payload

- `README.md:35-40` links to `wiki/product/managed-model-setup.md`, but
  `.pubignore:1-4` excludes `wiki/`.
- `README.md:95-100` lists `python3 tool/lint_wiki.py`, while `tool/` and `wiki/`
  are both excluded.
- `README.md:104-108` presents the repository-oriented verification boundary in
  the consumer README, including a command set the consumer artifact cannot run.

Impact: the README rendered for the package contains at least one broken relative
link and commands unavailable to package consumers. This does not cause native
linkage failure, but it makes the actual setup boundary harder to reproduce.

### P1 — Optional LLM packaging is repository-local and not clean-consumer reproducible

- Android enables the adapter through host Gradle properties at
  `android/build.gradle:16-20`; `native/llm/CMakeLists.txt:13-15` then requires a
  local pinned llama.cpp source tree.
- iOS conditionally adds `Frameworks/flva-llm.xcframework` at
  `ios/flutter_local_voice_agent.podspec:17-20`, but `.pubignore:50` excludes it.
- The two scripts that pin/build those inputs are excluded as described above.
- `wiki/work/0002-native-offline-pipeline/04-verification.md:98-117` records that
  the successful optional iOS build used a generated framework copied into the
  ignored checkout directory. That evidence proves that local source snapshot,
  not the pub payload.

Impact: the optional LLM variant cannot be reproduced from the current package
contents. Existing host smoke and provisioned checkout builds remain valid but
are not clean-consumer evidence.

### P2 — The supported architecture and integration surface are intentionally narrow and need exact release evidence

- `android/build.gradle:13-22` pins NDK 28.2.13676358, minSdk 26, and only
  `arm64-v8a`.
- `ios/flutter_local_voice_agent.podspec:13-26` declares iOS 13, CocoaPods,
  C++17, and special simulator exclusions for the optional LLM.
- `README.md:17-20` documents Android arm64-v8a and CocoaPods. The source and
  documentation agree on this narrow support surface.
- `wiki/work/0002-native-offline-pipeline/04-verification.md:113-129` states that
  Swift Package Manager is untested and that no simulator app was launched, no
  physical device ran, and no release installation was qualified.

Impact: this is not an ABI mismatch finding. It is a verification boundary:
release claims must remain limited to Android arm64-v8a and CocoaPods until exact
additional variants are built and qualified.

## Concrete fixes

1. Choose and document one distributable runtime layout before publication,
   while retaining sherpa-onnx 1.12.14 and the current ABI:
   - Preferred direct-package route: after the redistribution/license gate is
     approved, include the pinned Android arm64-v8a libraries and the required
     iOS device/simulator XCFramework slices in the package, with exact hashes,
     notices, and an automated payload allowlist.
   - If pub archive constraints make that impossible, publish a separately
     versioned native artifact/package with immutable checksums and make the
     Flutter package resolve it through a supported, explicit build mechanism.
     Do not require consumers to mutate the global pub cache, and do not add a
     hidden unpinned build download.
2. Keep provisioning utilities needed by supported consumer workflows in a
   shipped location, or remove those commands from the consumer README after the
   runtime becomes self-contained. Split contributor/repository checks from
   package-consumer setup. The optional LLM workflow needs the same treatment for
   its pinned llama source and iOS framework builder.
3. Add a payload contract check that fails unless every path referenced by
   Android CMake and the podspec exists in the actual package staging tree. Also
   reject README/doc links or commands targeting excluded files.
4. Add clean-consumer fixtures created outside this repository. Resolve the
   package from the exact staged archive/payload, not a path dependency pointing
   at this provisioned checkout. Build at least:
   - speech-only Android arm64-v8a debug and unsigned release;
   - speech-only iOS arm64 simulator debug and unsigned device release;
   - optional LLM Android arm64-v8a and iOS arm64 simulator/device variants when
     that feature is advertised as package-supported.
5. Make the release check run the clean-consumer fixtures before the pub dry run.
   Preserve complete command output and archive inventory/hashes as evidence.
   A path build from the repository remains a separate, weaker check.
6. Repair published documentation: remove or replace the excluded wiki link,
   move contributor-only commands out of the package setup, and state exactly
   how a pub consumer obtains native runtime artifacts without runtime network
   access.
7. Keep the work item in implement/FAIL until the frozen AC-007 package gate and
   the independent F3/AC-004 blocker are resolved and a fresh independent review
   is performed. Do not use the new zero-warning dry run to change the verdict.

## Validation commands

The following commands define the reproducible checks after the packaging fix.
They are proposed commands unless explicitly marked as executed.

Executed during this audit:

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/dart pub publish --dry-run
```

Observed: exit 0, `Package has 0 warnings`, 92 KB compressed payload, no
`tool/`, no `android/src/main/jniLibs/`, and no `ios/Frameworks/`.

```sh
/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter --version
/Users/ortalcohen/fvm/versions/3.47.0/bin/dart --version
xcodebuild -version
/Users/ortalcohen/Library/Android/sdk/cmake/3.22.1/bin/cmake --version
```

Observed: Flutter 3.47.0, Dart 3.13.0, Xcode 26.3, and CMake 3.22.1. Android NDK
28.2.13676358 is present. These are toolchain-presence checks, not builds.

Run after implementing a package staging/archive helper:

```sh
python3 tool/assert_package_payload.py /absolute/path/to/staged-package
```

The assertion must verify checksums and exact required slices, and must prove
that every podspec/CMake runtime path and every consumer-doc relative link exists.

Run clean-consumer builds from a temporary directory, using the staged package
as the dependency rather than this checkout:

```sh
flutter pub get
flutter build apk --debug --target-platform android-arm64
flutter build apk --release --target-platform android-arm64
flutter build ios --simulator --debug --no-codesign
flutter build ios --release --no-codesign
```

For optional LLM fixtures, repeat with the documented Android Gradle properties
and `FLVA_ENABLE_LOCAL_LLM=1` for CocoaPods, using only the pinned inputs supplied
or referenced by the staged package. Record the produced APK/app architectures
and linked native library/framework lists.

After package-consumer checks pass, rerun the repository checks independently:

```sh
sh tool/check.sh
python3 tool/test_native.py --ubsan --runtime /absolute/pinned/runtime/lib --assets <nine absolute model/audio paths>
```

Do not collapse these into one claim: host real-engine tests, repository builds,
clean package-consumer builds, simulator execution, release installation, and
physical-device behavior are separate evidence classes.

## External gates

- Redistribution review for the exact sherpa-onnx, ONNX Runtime, optional
  llama.cpp, and transitive binary contents. The current notices are not recorded
  approval to ship the 20 MB/376 MB local runtime trees.
- Pub.dev acceptance of the chosen native artifact layout and archive size.
  Current local evidence only establishes that the stripped 92 KB package passes
  the dry run.
- F3 / AC-004: a hard bound on VITS upstream complete-sentence allocation, or a
  validated backend/design change through the repository workflow.
- Physical Android and iPhone microphone-to-speaker trials, permission/revocation,
  interruption, route and sample-rate changes, lifecycle, cancellation, thermal,
  memory, endurance, and microphone-release evidence from `doc/testing.md:71-90`.
- Installed unsigned/release artifact checks and any eventual store-signing/store
  acceptance. Successful compilation is not device qualification.
- Model/license/OOV and voice-quality review, and optional GGUF template/response
  quality and mobile resource qualification.
- Swift Package Manager remains unsupported/unverified; CocoaPods is the only
  integration path with recorded build evidence.
- Fresh independent implementation validation after the packaging and F3 defects
  are resolved. The existing `STATE.yaml:4-6` verdict remains implement/FAIL.
