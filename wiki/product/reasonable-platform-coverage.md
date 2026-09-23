---
id: reasonable-platform-coverage
title: Reasonable platform coverage
status: active
owner: root
last_verified: 2026-09-22
applies_to: ["pubspec.yaml", "doc/capabilities.md", "README.md", "macos/**", "windows/**", "linux/**"]
summary: Five native hosts stay on flva; Flutter web is a separate WASM profile; parent 0002 gates stay open.
---

# Reasonable platform coverage

Work item 0008 registers the existing offline native session on five Flutter
plugin hosts: Android, iOS, macOS, Windows and Linux. The C ABI, method-channel
names and Dart public types stay the same. Android and iOS bridges remain the
existing native-audio owners; this item does not retune mobile rates, add
Android ABIs, enable iOS Swift Package Manager, or change the iOS session mode.

Flutter web is a separate session profile that vendors sherpa-onnx 1.13.8
WASM. It does not load flva.h and does not change native audio ownership.
Excluded targets remain watchOS, tvOS, Wear OS, Android TV, fuchsia, cloud
speech and PCM-through-Dart on the facade. Those hosts fail with
`AgentErrorCode.unsupportedProfile` before native create.

## Provisioning

Build-time operator command from the repository root:

`python3 tool/provision_runtime.py <android|ios|macos|windows|linux>`

Each key verifies a pinned official sherpa-onnx v1.12.14 archive. Desktop
SHA-256 digests are:

- macOS `7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413`
- Windows `78fa331bac4d20828a867b14283950727ce668fe751d1a792352b7e035b0ffe1`
- Linux `b898ed5d7b989192ac6c60b6c0076f9de2e89766930bf1e11738aacbf45f5ed8`

A digest mismatch copies nothing. The running plugin does not download
runtimes.

## Compile-evidence boundary

The macOS example was built on this host with `flutter build macos --debug`
and exited 0. Windows and Linux plugins and example hosts are
source-complete. Flutter desktop builds of those two hosts were not run on
this macOS checkout. That missing compile is a recorded gate, not a silent
pass.

## Parent 0002 gates remain OPEN

Work item 0002 still records these blockers as OPEN:

- VITS allocation (F3 / AC-004)
- Physical mobile qualification (AC-005 / AC-008)
- Clean consumer-install (AC-007)

Desktop registration and the macOS compile do not close those gates. The
[consumer capabilities list](../../doc/capabilities.md) and the
[setup table](../../README.md) carry the same boundary. The historical
[technical PRD](local-voice-agent-prd.md) is not rewritten into a
qualification claim.
