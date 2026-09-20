# Implement-ready handoff

This item is armed for implementation and has not started. No plugin folder, Dart guard, provisioning key or test from 03-tasks.md has been created. Criteria AC-001 through AC-012 are frozen. Adding a criterion after this point requires a new recorded validation round.

## Read first

Read AGENTS.md, wiki/INDEX.md, wiki/conventions/workflow.md, then this folder's STATE.yaml, 02-criteria.md, 01-plan.md, 03-tasks.md and 00-research.md. The confirmation verdict is validation/plan-review-02.md. Do not reopen 0002, 0004, 0006 or 0007 frozen criteria.

## User decisions already recorded

Supported platforms are Android, iOS, macOS, Windows and Linux. Flutter web stays excluded. Windows and Linux are accepted as source-complete plugins. A Flutter desktop build of those two hosts is not required on this macOS checkout.

## Shared decisions that cannot be renegotiated in code

The C ABI in native/include/flva.h is the inference contract. Method names stay create, start, stop, interrupt, reply, poll and dispose on channel flutter_local_voice_agent. PCM never crosses that channel. Desktop logs must not print raw PCM.

macOS uses CocoaPods, compiles shared native sources, and vendors dylibs from sherpa-onnx-v1.12.14-osx-universal2-shared.tar.bz2 with digest 7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413. The macos xcframework static bundle is rejected.

Windows uses WASAPI and CMake imported sherpa from the official v1.12.14 win-x64-shared archive. Linux uses PulseAudio client streams and CMake imported sherpa from the official v1.12.14 linux-x64-shared archive. Measure those two digests during task 2.1 and pin them. A digest mismatch copies nothing.

Permission denial on start returns permissionDenied and leaves capture closed. Excluded targets return unsupportedProfile before native create. Route or device loss after start uses audioUnavailable or routeChanged. Optional llama.cpp stays CPU-only behind the existing compile gate.

## Task order

Run groups in order. Group 4 tasks 4.1 and 4.2 may run in parallel after Group 3 because they own exclusive folders. Tasks 1.1, 2.1, 3.1 and 5.1 stay serial. The implementer of a task writes its tests.

Do not edit android or ios plugin sources except for unavoidable pubspec-owned registration fallout in task 2.1. Do not claim parent VITS, physical-device or consumer-packaging gates closed.

## Reserved new files

These paths are assigned and do not exist yet. Do not create them until the matching task starts.

- test/platform_refusal_test.dart for task 1.1
- tool/test_provision_runtime.py for task 2.1
- macos/ and example/macos/ for task 3.1
- windows/ and example/windows/ for task 4.1
- linux/ and example/linux/ for task 4.2

## Checks when implementation starts

Format lib and example/lib. Analyze with fatal infos and warnings. Run the package tests. Provision macOS and build the example on this host. Search new log sites for PCM dumps. Paste command output. Leave unrelated dirty files untouched. No commit, push or publication.

## First implement step when authorized

Start task 1.1 only. Do not pre-create desktop folders or change pubspec.yaml in the same step.
