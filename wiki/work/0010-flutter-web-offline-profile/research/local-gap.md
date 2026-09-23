# Research: Local repository gap for Flutter web

## Question

What in this repository currently prevents a Flutter web host from compiling and running the offline voice agent, and which existing contracts must a web profile preserve?

## Answer

Create already refuses Flutter web with unsupportedProfile before native create. Three library modules import dart:io, so a web compile fails even if that guard is removed. The public facade, offline contract, half-duplex mode and native flva session on five hosts must stay. A web profile therefore needs a second session backend, not a change to flva.h.

## Findings

### Current refusal

- Claim: LocalVoiceAgent.create calls a host guard that throws unsupportedProfile on Flutter web and on fuchsia, and does not invoke native create.
- Evidence: lib/src/agent.dart defines _refuseUnsupportedHost. On kIsWeb it throws AgentFailure with message Flutter web is not a supported platform for the native offline voice pipeline. test/platform_refusal_test.dart proves a fuchsia override refuses before fake native create, and a macOS override reaches create.
- Source: lib/src/agent.dart; test/platform_refusal_test.dart — consulted 2026-09-22

### dart:io hard dependency

- Claim: The published library cannot compile for web because agent, model store and model preparation import dart:io. FileModelStore.validate also rejects a manifest unless runtime is the string 1.12.14 and inputRate is 16000. The catalog inventory labels that same runtime. A web store that required runtime 1.13.8 would reject the existing compact pack before any WASM load.
- Evidence: lib/src/agent.dart uses Directory, Platform.pathSeparator and filesystem path maps for native create. lib/src/model_store.dart FileModelStore uses Directory, File and symbolic-link confinement, and equals runtime to 1.12.14. lib/src/model_preparation.dart uses dart:io for explicit download and private-root install and writes runtime 1.12.14. example/lib/model_storage.dart also imports dart:io. tool/model_catalog_inventory.json labels runtime 1.12.14.
- Source: lib/src/agent.dart; lib/src/model_store.dart; lib/src/model_preparation.dart; example/lib/model_storage.dart; tool/model_catalog_inventory.json — consulted 2026-09-22

### Native audio contract

- Claim: NativeVoicePlatform documents that no audio crosses the method-channel boundary. Create builds a role-to-filesystem-path map and the native worker owns capture and render.
- Evidence: lib/src/contracts.dart states no audio crosses this interface. wiki/adr/0001-offline-voice-architecture.md rejects a channel-only PCM pipeline. wiki/product/reasonable-platform-coverage.md lists Flutter web, WASM and PCM-through-Dart as excluded hosts that fail before native create.
- Source: lib/src/contracts.dart; wiki/adr/0001-offline-voice-architecture.md; wiki/product/reasonable-platform-coverage.md — consulted 2026-09-22

### Plugin manifest and runtime pin

- Claim: The plugin registers android, ios, macos, windows and linux only. Native sherpa is pinned to official v1.12.14 archives through tool/provision_runtime.py. There is no web plugin key.
- Evidence: pubspec.yaml flutter.plugin.platforms. doc/capabilities.md lists those five hosts and names Flutter web as excluded.
- Source: pubspec.yaml; doc/capabilities.md; tool/provision_runtime.py — consulted 2026-09-22

### Model catalog size

- Claim: The example catalog has three English packs. Compact LJS is 114,444,636 bytes. Full-precision LJS is 383,741,867 bytes. Compact VCTK is 116,261,194 bytes. All share Zipformer plus Silero; VCTK swaps the VITS voice.
- Evidence: wiki/product/example-model-catalog.md records those exact sizes and the speaker-id contract.
- Source: wiki/product/example-model-catalog.md — consulted 2026-09-22

### Parent gates

- Claim: Work 0002 still records VITS allocation, physical mobile qualification and clean consumer-install as open. Web work must not close them.
- Evidence: wiki/product/reasonable-platform-coverage.md and wiki/work/0002-native-offline-pipeline/STATE.yaml.
- Source: wiki/product/reasonable-platform-coverage.md; wiki/work/0002-native-offline-pipeline/STATE.yaml — consulted 2026-09-22

### Dual-plugin collision if sherpa_onnx is added

- Claim: Adding the pub.dev sherpa_onnx package as a dependency of this plugin would pull federated native sherpa implementations into consumer Android, iOS and desktop builds beside libflva.
- Evidence: sherpa_onnx 1.13.8 lists sherpa_onnx_android_arm64, armeabi, x86, x86_64, ios, linux, macos, windows and web as dependencies. This repository already links pinned sherpa-onnx v1.12.14 into those hosts through flva. Two ONNX runtimes in one app is an unresolved collision risk and a size regression.
- Source: https://pub.dev/packages/sherpa_onnx — consulted 2026-09-22; pubspec.yaml; tool/provision_runtime.py — consulted 2026-09-22

### record plugin as a library dependency

- Claim: Adding package record at the library root would register a second microphone plugin on mobile and desktop even if Dart only used it on web.
- Evidence: record is a federated Flutter plugin. Flutter registers plugin implementations for every dependency, not only for conditional imports. Native hosts already own capture inside the existing plugins.
- Source: https://pub.dev/packages/record — consulted 2026-09-22; android, ios, macos, windows and linux plugin folders — consulted 2026-09-22

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Keep refusing web | Leave the guard and dart:io imports | Zero | Rejected by the request for a product-fit web path |
| Depend on sherpa_onnx plus record | Fastest Flutter integration | Dual native sherpa and a second mic plugin | Rejected |
| Conditional dart:io plus a web backend that vendors WASM and uses package web | More binding work, isolated hosts | Medium-high | Chosen |
| Compile flva.cpp with Emscripten | Keep the C coordinator | Highest, still needs JS audio | Rejected for the first slice |

## Constraints discovered

- kIsWeb is already imported through foundation in agent.dart.
- FileModelStore symbolic-link rules have no web equivalent. A web store must confine keys to a private origin store or bundled assets and still hash-check every file.
- LocalVoiceAgent.create currently resolves real filesystem paths before native create. A web create path cannot use Directory.resolveSymbolicLinks or Platform.pathSeparator.
- Tests under test/ import dart:io freely. They remain VM tests. Web-specific tests need a separate compile or conditional test file.
- example/web exists as a generic Flutter bootstrap from earlier research and is not a voice plugin host.

## Unresolved

- [UNRESOLVED: Whether Flutter web compilation of this package succeeds after only splitting dart:io, before a web backend exists. That is an implementation spike.]
- [UNRESOLVED: Whether the example catalog downloader can target Origin Private File System with the existing descriptor and hash policy without a new preparation protocol.]
- [UNRESOLVED: Exact Flutter web plugin registration shape that vendors WASM assets without adding a federated third-party speech plugin.]

## Sources

- lib/src/agent.dart — 2026-09-22
- lib/src/model_store.dart — 2026-09-22
- lib/src/model_preparation.dart — 2026-09-22
- lib/src/contracts.dart — 2026-09-22
- test/platform_refusal_test.dart — 2026-09-22
- pubspec.yaml — 2026-09-22
- doc/capabilities.md — 2026-09-22
- wiki/adr/0001-offline-voice-architecture.md — 2026-09-22
- wiki/product/reasonable-platform-coverage.md — 2026-09-22
- wiki/product/example-model-catalog.md — 2026-09-22
- https://pub.dev/packages/sherpa_onnx — 2026-09-22
- https://pub.dev/packages/record — 2026-09-22
