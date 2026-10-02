# Verification: Example conversation activity

Coordinator checks run from the repository root on 2026-10-02. The implementation review re-ran the same suite independently and returned PASS. After that review, interrupt-before-start was gated so it no longer writes the listening sentence while capture is false. The example suite was re-run after that gate.

## Full suite before the interrupt gate

```
$ dart format lib example/lib
Formatted 37 files (0 changed) in 0.09 seconds.

$ dart analyze --fatal-infos --fatal-warnings
No issues found!

$ flutter test
00:05 +99: All tests passed!

$ (cd example && flutter test)
00:01 +48: All tests passed!

$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
```

`git diff -- lib` was empty at the implementation review.

## Example suite after the interrupt gate

```
$ dart format example/lib/voice_screen_controller.dart example/test/voice_screen_controller_test.dart
Formatted 2 files (0 changed) in 0.02 seconds.

$ (cd example && flutter test)
00:01 +49: All tests passed!

$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
```

The new test is `interrupt before start leaves the ready status`. Package tests were not re-run after this example-only gate. No file under `lib/` changed.
