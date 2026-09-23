# Verification: Flutter web offline voice profile

Commands ran on 2026-09-22 from `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent` unless a directory is named. Flutter and Dart are the host SDK below. This record pastes command output. It does not close work item 0002. It does not claim a browser microphone-to-speaker session or a compact-catalog ONNX load in sherpa-onnx 1.13.8 WASM.

## Host

```text
$ flutter --version
Flutter 3.47.3 • channel stable • https://github.com/flutter/flutter.git
Framework • revision e8113bf456 (2 weeks ago) • 2026-09-04 13:20:08 -0700
Engine • hash 0e228ec8c8d2abc9fcf1d053e8a40665bb859ec7 (revision 06a2e2a110) (18 days ago) • 2026-09-03 16:07:13.000Z
Tools • Dart 3.13.3 • DevTools 2.60.0
```

## Wiki lint

```text
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
WIKI_EXIT:0
```

## Format and analyzer

```text
$ dart format lib example/lib
Formatted 37 files (0 changed) in 0.19 seconds.

$ dart analyze --fatal-infos --fatal-warnings
Analyzing flutter_local_voice_agent...
No issues found!
```

Web-conditional libraries under `lib/` that are not `*_io.dart` have no `import 'dart:io'`.

```text
$ python3 - <<'PY'
from pathlib import Path
bad=[]
for p in Path('lib').rglob('*.dart'):
    if p.name.endswith('_io.dart'):
        continue
    text=p.read_text()
    if "import 'dart:io'" in text or 'import "dart:io"' in text:
        bad.append(str(p))
print('web_graph_dart_io', bad or 'none')
PY
web_graph_dart_io none
```

## Tests

```text
$ flutter test
00:07 +98: All tests passed!
```

```text
$ cd example && flutter test
00:00 +26: All tests passed!
```

## pubspec inspection

```text
has_package_web True
has_sherpa_onnx_dep False
has_sherpa_onnx_web_dep False
has_record_dep False
web_plugin_class True
web_fileName True
catalog_onnx_in_plugin_assets False
wasm_assets True
```

The plugin ships pinned `assets/sherpa_onnx_web/` runtime files and `third_party/sherpa_onnx_web` Apache-2.0 notices. Catalog ONNX weights are absent from the plugin package.

## Example web build

Ran from `example/`:

```text
$ flutter build web
Compiling lib/main.dart for the Web...                             21.1s
✓ Built build/web
```

Exit 0. Start remains disabled until a validated compact pack exists (`VoiceScreenController.canStart` requires `ExampleSetupPhase.ready` and a session).

## Native plugin ownership

```text
$ git diff --stat -- android ios macos windows linux
```

Empty. Native plugin folders were not rewritten. Android, iOS, macOS, Windows and Linux still own audio through flva.

## Parent 0002 blockers remain OPEN

```text
blockers:
  - "F3 / AC-004: VITS allocates an entire sentence before callback; hard synthesis allocation bound not established."
  - "AC-005 / AC-008: physical mobile offline, audio, lifecycle and performance qualification unavailable."
  - "AC-007: native binaries and provisioning tools are excluded from the pub payload; clean consumer installation remains unqualified. Final dirty-checkout dry run exits 65 with one warning."
```

No 0010 document closes those gates.

## Unverified live paths

- Compact catalog Zipformer plus VITS load in sherpa-onnx 1.13.8 WASM is [UNVERIFIED]. The host had no local pack for a load spike. A rejected construct is mapped to `invalidAsset`. There is no silent model swap.
- Browser microphone-to-speaker session is [UNVERIFIED]. The user will run that check after this work item finishes.

## Criterion map

| ID | Result | Evidence |
|---|---|---|
| AC-001 | pass | `test/web_profile_test.dart`; web create uses the session backend, not method-channel create |
| AC-002 | pass | `test/platform_refusal_test.dart` fuchsia refusal |
| AC-003 | pass | `web_graph_dart_io none`; analyze clean |
| AC-004 | pass | pubspec inspection above |
| AC-005 | pass | `test/wasm_pin_test.dart`; mismatch is `invalidAsset` before microphone |
| AC-006 | pass | `test/web_model_store_test.dart` empty and tampered packs |
| AC-007 | pass | `test/web_profile_test.dart` useLocalLlm |
| AC-008 | pass | `test/web_profile_test.dart` full duplex |
| AC-009 | pass | `test/web_backend_test.dart` insecure context |
| AC-010 | pass | `test/web_backend_test.dart` permissionDenied |
| AC-011 | pass | `test/web_backend_test.dart` events have no PCM fields |
| AC-012 | pass | `test/web_backend_test.dart` VAD final plus half-duplex gate |
| AC-013 | pass | `test/web_backend_test.dart` interrupt flush |
| AC-014 | pass | `flutter build web` exit 0 pasted above |
| AC-015 | pass | empty native plugin diff; 0002 blockers still OPEN |
| AC-016 | pass | web logs print counters only; searched new web log sites |
| AC-017 | pass | plugin assets are WASM plus notice; no catalog weights |
| AC-018 | pass | pinned SHA-256 and Apache-2.0 notice; mismatch loads nothing |
