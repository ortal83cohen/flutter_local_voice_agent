# Capabilities and qualification boundaries

| Capability | Implementation / limit |
|---|---|
| Offline model provisioning | Existing local manifest validation/import remains network-free |
| Explicit model preparation | Host-trusted HTTPS descriptor and private root; streaming integrity, cancellation and verified offline reuse; redirects require explicit bounded exact-origin policy |
| Example model catalog | Two pinned English compact/full-precision speech packs; selection, download, cancel/retry and private offline reuse |
| VAD | Silero, 512-sample windows at 16 kHz |
| STT | sherpa streaming transducer; revisable partials, finalized replies |
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
