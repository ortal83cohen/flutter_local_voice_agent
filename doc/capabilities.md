# Capabilities and qualification boundaries

| Capability | Implementation / limit |
|---|---|
| Offline model provisioning | Local manifest, SHA-256 and staging; no runtime networking |
| VAD | Silero, 512-sample windows at 16 kHz |
| STT | sherpa streaming transducer; revisable partials, finalized replies |
| Logic | Host-supplied deterministic Dart function; optional native GGUF adapter |
| TTS text input | Complete bounded reply, not streaming text input |
| TTS PCM | Sentence callback feeds bounded playback; no sub-sentence streaming claim |
| Half duplex | Foreground default; speech admission pauses during response |
| Full duplex / speech barge-in | Unsupported; no AEC qualification claimed |
| Manual interruption | Generation invalidation plus platform playback flushing where supported |
| Queues | Native capture/render and events are finite; saturation is an error |
| Background / wake word | Unsupported; session suspends in background |
| Route change | Suspend; iOS changed input rate requires recreate |
| Thermal | Severe/serious system signal suspends; adaptive model tuning not implemented |
| Device measurements | No physical devices connected during implementation |
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
