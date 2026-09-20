---
id: pipeline-05-handoff
title: Continuation handoff after implementation repair
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Resume instructions, verified implementation and unresolved delivery gates.
---

# Continuation handoff

The user requested an orderly stop and a continuation prompt after finishing
in-flight work. All delegated tasks and final build/test runs have settled.
This is a handoff, not completion of the implementation or release phases.
Work item 0002 remains implement / FAIL. Do not confuse 0001 specification
completion with implementation readiness. No commit, push or publication was
performed by this implementation agent. Concurrent repository automation/work
may have changed Git state; preserve all unrelated changes, including work 0003.

## Read first

Read AGENTS.md, wiki/INDEX.md, conventions/workflow.md, conventions/model-routing.md,
the PRD and ADR 0001, then 0002/STATE.yaml, its frozen 02-criteria.md,
validation/impl-review-01.md and 04-verification.md. The last report contains
actual command output and links to raw logs. Follow research/plan/validate/
implement/verify/document with append-only artifacts. Repository text is English.

## Implemented and checked

- Dart public facade, typed events/errors, bounded event delivery, cancellation,
  local hash/size/role manifest verification and staged installation.
- Native worker with real sherpa-onnx 1.12.14 Silero VAD, streaming Zipformer STT
  and VITS synthesis. Bounded application PCM/events, generation filtering,
  worker ownership, stateful FIR resampling, repeated real speech turns.
- Kotlin AudioRecord/AudioTrack and ObjC++ AVAudioEngine bridges, permission,
  lifecycle/focus/interruption/route/thermal hooks. These are implemented;
  physical operating-system behavior is unqualified.
- Optional pinned llama.cpp CPU adapter, bounded context/history/output,
  valid UTF-8 truncation, actual decode cancellation and error propagation.
- Real-model example, local runtime/source provisioning, model-manifest tool,
  documentation, notices, native/Flutter tests.
- Final coordinator checks: 27 Flutter tests, strict analysis, native UBSan
  smoke/failure tests (17 native failure checks), real GGUF and UTF-8 tests.
- Final optional-LLM Android debug APK and arm64 iOS simulator app compile and
  link. The two-slice iOS LLM framework builds for device and simulator; this
  alone does not prove an iOS device application build or device execution.

## Remaining work, in priority order

1. Resolve independent F3 / AC-004. Current VITS allocates a whole sentence
   before its first callback. A legal 235-byte input generated 291,993 samples
   (13.242 seconds) before cancellation. The app's 10-second admission cap does
   not bound this internal allocation. Determine a verifiable engine/model
   allocation limit, or select another real backend with evidence and an ADR.
   Do not label sentence batching as streaming text. Do not silently weaken
   frozen criteria; a necessary scope/criteria change requires recorded validation.
2. Audit the final integrated repairs of F1/F2/F4/F5 using source and tests.
   Keep the original independent FAIL report unchanged. Coordinator fixes are
   not an independent PASS. Follow repository limits on review rounds; do not
   ask the same validator to loop on its own findings.
3. Run installed application integration, starting with available simulators
   and then physical Android/iPhone. Prove actual local microphone-to-speaker
   behavior, permission denial/revocation, interruption/focus loss, lifecycle,
   route/sample-rate changes, thermal suspension and microphone shutdown.
   Exercise cancellation during every stage and stale results. No physical
   device was available in this session. No simulator runtime was executed.
4. Prove clean local model installation with networking denied and restart.
   The example currently takes a model-directory path. A host-owned iPhone
   import/bundled-asset path needs qualification. Local files and build downloads
   are explicit; there is no runtime downloader or cloud fallback.
5. Complete model and transitive dependency license review and exact supported
   model profiles. Test assets are provenance only, not distribution approval.
   VITS reports unknown lexicon tokens; evaluate voice intelligibility and OOV
   behavior. GGUF smoke responds poorly to its requested one-word answer;
   generation quality and model-template support are not approved.
6. Complete bounded-memory/latency/thermal/endurance qualification using the PRD
   protocol and doc/testing.md. ASan hangs before main on this host even for a
   minimal probe; investigate separately. Do not invent device benchmarks or
   treat UBSan/prebuilt libraries as full memory-safety evidence.
7. Verify unsigned release builds and clean consumer packaging for speech-only
   and optional LLM variants. Fix or formally disposition package dry-run's
   historical warnings (ignored tracked files, dirty files, plural tools).
   Concurrent work renamed tools to tool during handoff; rerun dry-run for the
   new snapshot rather than assuming the historical warnings still apply. Do not
   clean/stage/commit simply to remove a warning. Native runtime archives are
   deliberately excluded from the package and must be provisioned explicitly.
   CocoaPods is tested; Swift Package Manager support is still a warning.
8. Finish consumer documentation/capability matrix, architecture changes and
   criteria evidence. Keep half-duplex as baseline. Full duplex/barge-in must
   remain unsupported until route-specific AEC/double-talk evidence exists.
   Only close phases after every applicable gate is actually met.

A Python ONNX graph inspection experiment was attempted but not completed:
Python 3.14's onnx 1.19 installation fell back to a failed source build. No model
was modified and no bounded-graph result exists. Do not rely on this experiment.

## Environment and reproducibility

Use Flutter `/Users/ortalcohen/fvm/versions/3.47.0/bin/flutter` and its Dart 3.13.0.
The default `/Users/ortalcohen/flutter` is older. Android NDK 28.2.13676358 and
CMake/Ninja under `/Users/ortalcohen/Library/Android/sdk/cmake/3.22.1/bin` were used.
Xcode 26.3 is installed at `/Applications/Xcode 2.app`.

See doc/testing.md for commands and model installation, doc/models.md for the
manifest, doc/llm.md for optional switches, and tool/test_native.py for native
invocation. The exact real speech asset command is retained in the review.
Run the example from `example` with the same Flutter SDK, after explicit runtime
and model provisioning; enter the local model-pack path, load, then start.

Temporary inputs may disappear; verify hashes before reusing:

- `/private/tmp/flva-qualification`: sherpa macOS runtime, VAD/VITS models and
  Zipformer ASR directory/test WAV. See review for exact paths.
- `/private/tmp/flva-llm-source`: llama.cpp commit
  `987498f4592a76897863cf53711dce38380c082b` (b10976).
- `/private/tmp/flva-tinyllama-q2.gguf`: SHA-256
  `030a469a63576d59f601ef5608846b7718eaa884dd820e9aa7493efec1788afa`.
- `/private/tmp/flva-android.tar.bz2`, `/private/tmp/flva-ios.tar.bz2`: explicitly
  downloaded pinned runtime inputs; provisioning scripts verify expected hashes.
- `/private/tmp/flva-llm-final-ios/flva-llm.xcframework`: final optional static
  framework copied into ignored ios/Frameworks. Optional simulator is arm64.
- `build/llm-host`: final host smoke/UTF-8 executables. Build outputs are ignored.

## Delegation and delivery

Choose shared interfaces/audio/memory/cancellation contracts before fan-out.
Use stronger planners/reviewers, balanced implementers, fast mechanical agents
per repository routing. Each delegation must name objective, exact output,
exclusive files, tools/sources and artifact path. Parallelize independent work,
never shared configuration, ABI, lockfiles or verdicts. Reviewers use clean
context with criteria and artifact, without author's reasoning. Main agent
must rerun checks and inspect output.

Continue independently on unblocked work; missing physical resources do not
justify stopping source/build/documentation tasks. Record exact blocked gates.
Do not commit, push, publish, deploy, redistribute weights, delete wiki artifacts
or discard unrelated changes. Final reporting must separate implementation,
host test, build, simulator execution and real-device evidence.

## Concurrent checkout change at handoff

After the final builds, another task renamed `tools/` to `tool/` and changed
release/build configuration. Preserve that task's staged and unstaged work.
Commands in historical evidence retain their actual executed spelling; use
`tool/` for current invocations. Final mobile build claims describe the source
snapshot at execution, not later concurrent configuration edits. Re-run affected
checks after integrating concurrent changes. No requalification of those
external edits is claimed here.
