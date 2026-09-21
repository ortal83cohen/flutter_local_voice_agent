# Verification: Android audio and ASR instrumentation

Commands ran on 2026-09-21 from `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent`. Flutter and Dart are `/Users/ortalcohen/fvm/versions/3.47.0`. This record pastes command output. It does not claim a physical Android transcript.

## Host

```text
$ flutter devices
Found 2 connected devices:
  macOS (desktop) • macos  • darwin-arm64   • macOS 26.6.2 25G83 darwin-arm64
  Chrome (web)    • chrome • web-javascript • Google Chrome 153.0.8010.52
DEVICES_EXIT:0
```

No Android emulator or phone is attached. Device capture, `nativePush` continuity, first-syllable retention and complete English ASR remain [UNVERIFIED].

## Checks

```text
$ git diff --check
DIFF_CHECK_EXIT:0

$ dart format --set-exit-if-changed lib example/lib test example/test
Formatted 27 files (0 changed) in 0.13 seconds.
FORMAT_EXIT:0

$ dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
ANALYZE_PKG_EXIT:0

$ flutter test
00:05 +73: All tests passed!
TEST_PKG_EXIT:0

$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
WIKI_EXIT:0
```

The earlier Flutter SDK cache `Operation not permitted` blocker does not reproduce with this FVM 3.47.0 PATH.

## Source evidence

- Android plugin logs use the `FLVA` tag for lifecycle, format and capture summaries. Capture logs include frame counts and bounded amplitude, not PCM arrays.
- JNI `bridge.cpp` logs rejected buffers and push results.
- Native Android builds log VAD speech onset and ASR partial/final text lengths through `FLVA_NATIVE_LOG`.
- Dart `LocalVoiceAgent` logs poll batch size, event kind, generation/sequence, activity and text length. The example logs UI delivery.
- `VOICE_COMMUNICATION`, `kPreRollSamples = 8000` and VAD onset `0.38f` are present on `native/src/flva.cpp` and the Android plugin in the init history of this repository. This record does not treat them as a new 0007 behavior change, and it does not claim they were qualified on a device.

## Remaining device gate

AC-005 allows recording an environment blocker. `flutter devices` listed only macos and chrome. Use the Android log filter `FLVA` on a later connected device during one spoken English phrase and compare capture, push, VAD, ASR, poll and UI lines in that order.

## Scope boundary

This work item is diagnostic logging. It does not claim that Android recognition is fixed or qualified.

## Next

One implementation review at `validation/impl-review-01.md`.
