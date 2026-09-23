# Capabilities and qualification boundaries

| Capability | Implementation / limit |
|---|---|
| Supported native hosts | Android, iOS, macOS, Windows, Linux on flva.h and sherpa-onnx v1.12.14 |
| Flutter web profile | Separate session behind LocalVoiceAgent. Vendored sherpa-onnx 1.13.8 WASM, Silero VAD, one non-streaming offline recognizer, compact VITS. PCM stays inside the web backend. Create does not download. useLocalLlm and full duplex are `unsupportedProfile`. Browser microphone-to-speaker and compact-catalog WASM load remain [UNVERIFIED] |
| Excluded hosts | watchOS, tvOS, Wear OS, Android TV, fuchsia, cloud speech, Web Speech, PCM-through-Dart on the facade. Those fail with `unsupportedProfile` before native create |
| Android / iOS bridges | Unchanged in intent: native audio ownership, shared method names, PCM stays off the Dart channel |
| Runtime provisioning | Build-time `python3 tool/provision_runtime.py` with one of android, ios, macos, windows or linux against pinned sherpa-onnx v1.12.14 archives. Plugin create does not download runtimes |
| Compile evidence | macOS example was built on this host (`flutter build macos --debug` exit 0). Windows and Linux plugins are source-complete; Flutter desktop builds of those two hosts were not run on this macOS checkout |
| Parent 0002 gates | VITS allocation, physical mobile qualification, and clean consumer-install remain OPEN |
| Offline model provisioning | Existing local manifest validation/import remains network-free |
| Explicit model preparation | Host-trusted HTTPS descriptor and private root; streaming integrity, cancellation and verified offline reuse; redirects require explicit bounded exact-origin policy |
| Example model catalog | Three pinned English speech packs: LJS compact, LJS standard, and compact VCTK (109 speakers, integer ids 0-108). VCTK is a speaker choice, not a language or quality ranking. Piper, other languages and physical-device quality remain outside this catalog. Selection, download, cancel/retry and private offline reuse |
| VAD | Silero, 512-sample windows at 16 kHz |
| STT | Native: sherpa streaming transducer with revisable partials. Web: VAD plus one non-streaming offline recognizer; streaming Zipformer on Flutter web is out of scope |
| Logic | Host-supplied deterministic Dart function; optional native GGUF adapter |
| TTS text input | Nonempty valid Unicode, no NUL, at most 240 scalars / 960 UTF-8 bytes; complete reply input |
| TTS PCM | Sentence callback feeds bounded playback; no sub-sentence streaming claim |
| Half duplex | Foreground default; speech admission pauses during response |
| Full duplex / speech barge-in | Unsupported; no AEC qualification claimed |
| Manual interruption | Generation invalidation plus platform playback flushing where supported |
| Queues | Native capture/render and events are finite; saturation is an error |
| Background / wake word | Unsupported; session suspends in background |
| Route change | Suspend; iOS changed input rate requires recreate |
| Thermal | Severe/serious system signal suspends; adaptive model tuning not implemented |
| Emulator verification | Android catalog download/cancel/retry, native listening state and offline restart observed; no physical speech/audio qualification |
| Device measurements | No physical Android/iPhone qualification |
| Consumer installation | Requires a provisioned repository checkout; native package distribution remains unfinished |
| Model redistribution | No bundled weights or redistribution approval |

Native render bounds do not prove that sherpa VITS' internal whole-sentence
allocation fits the intended 10-second output budget. This is an open release
gate. A successful native build proves compilation/linking only, and host WAV
inference proves only the tested fixture. The benchmark targets in the PRD remain
unratified and must not be advertised as measured product performance.

The Android sample uses arm64 only. iOS uses the supplied simulator/device
slices through CocoaPods; Swift Package Manager support is not implemented.
The SDK does not assume that simultaneous microphone and speaker operation proves
echo cancellation. Optional GPU LLM backends are not enabled; CPU cancellation
is the only intended qualification route.

## Platforms

Supported native hosts are Android, iOS, macOS, Windows and Linux. Android remains
API 26+ arm64-v8a. iOS remains CocoaPods plus AVAudioEngine with
`NSMicrophoneUsageDescription`. macOS uses CocoaPods plus AVAudioEngine and
the pinned osx-universal2-shared runtime. Windows uses WASAPI and the pinned
win-x64-shared runtime. Linux uses PulseAudio and the pinned linux-x64-shared
runtime.

Flutter web is a separate WASM profile, not a native flva host. watchOS, tvOS,
Wear OS, Android TV, fuchsia, cloud speech and PCM-through-Dart on the facade
remain excluded. Those targets fail with `unsupportedProfile` and do not
invoke native create.

Android and iOS plugin bridges stay the existing native-audio owners. This
coverage item does not retune mobile sample rates, add Android ABIs, enable
iOS Swift Package Manager, or change the iOS session mode.

## Runtime provisioning

Provisioning is an explicit build-time operator command from the repository
root:

```sh
python3 tool/provision_runtime.py <android|ios|macos|windows|linux>
```

Each key installs the official sherpa-onnx v1.12.14 archive after SHA-256
verification. Desktop digests pinned in `tool/provision_runtime.py` are:

| Platform | Archive digest |
|---|---|
| macOS | `7e0f7bec6b7a428e7594385f62ebb5c3fc9fadc863a12005302bfd67a45ee413` |
| Windows | `78fa331bac4d20828a867b14283950727ce668fe751d1a792352b7e035b0ffe1` |
| Linux | `b898ed5d7b989192ac6c60b6c0076f9de2e89766930bf1e11738aacbf45f5ed8` |

A digest mismatch exits non-zero and copies no library. Pass
`--archive /path/to/the/archive` for a network-free input. The running
application never invokes this script.

## Compile-evidence boundary

The macOS example was built on this host with `flutter build macos --debug`
and exited 0. Windows and Linux plugin sources and example hosts are
source-complete. Flutter desktop builds of those two hosts were not run on
this macOS checkout. Absence of those two builds is a recorded gate, not a
silent pass and not physical qualification.

## Parent 0002 gates remain OPEN

Work item 0002 still records these blockers as OPEN:

- VITS allocation: the backend generates a complete sentence before its PCM
  callback; the hard synthesis allocation bound is not established.
- Physical mobile qualification: offline, audio, lifecycle and performance
  evidence on physical Android and iPhone devices is unavailable.
- Clean consumer-install: native binaries and provisioning tools stay out of
  the pub payload; a standalone consumer install remains unqualified.

A successful desktop registration or macOS compile does not close those
gates. Do not advertise them as closed.
