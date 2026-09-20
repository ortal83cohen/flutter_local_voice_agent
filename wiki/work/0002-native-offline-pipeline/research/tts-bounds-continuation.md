---
id: pipeline-tts-bounds-continuation
title: VITS allocation continuation research
status: draft
owner: root
last_verified: 2026-09-20
applies_to: ["**"]
summary: Source inspection and explicitly unresolved continuation gates.
---

# Findings

1. The frozen requirement is a real-engine allocation bound, not merely a playback or queue bound. `wiki/work/0002-native-offline-pipeline/02-criteria.md:25` requires real pinned VITS with bounded PCM and names overlong output as a negative case. `wiki/work/0002-native-offline-pipeline/STATE.yaml:8-10` keeps F3 open because a complete sentence is allocated before the callback.

2. The application limit is downstream of synthesis. `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src/flva.cpp:293-313` counts and copies callback samples into the bounded render ring, but `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src/flva.cpp:315-321` calls Sherpa first. The observed 235-byte input therefore reaches the application only after the oversized allocation has occurred.

3. Sherpa `max_num_sentences = 1` is not a sample or duration limit. The application sets it at `/Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent/native/src/flva.cpp:116-119`. In pinned Sherpa commit `26aa2fa93210376a89de3a65a1a4dd320c37f5e9`, `/private/tmp/flva-sherpa-src-v1.12.14/sherpa-onnx/csrc/offline-tts-vits-impl.h:246-257` runs `Process` for the whole one-sentence batch and calls the callback only afterward. Lines 430-487 show that `Process` executes the ONNX model, reads its already allocated output shape, and then copies all samples into a `std::vector<float>`.

4. The C API adds another complete PCM allocation. `/private/tmp/flva-sherpa-src-v1.12.14/sherpa-onnx/c-api/c-api.cc:1287-1305` receives the complete `GeneratedAudio`, allocates `new float[audio.samples.size()]`, and copies it. Returning zero from the callback cannot prevent either the ONNX output allocation or the first Sherpa vector; for a one-sentence input, `/private/tmp/flva-sherpa-src-v1.12.14/sherpa-onnx/csrc/offline-tts-vits-impl.h:248-253` also ignores the callback return value.

5. The unbounded dimension originates inside the exported VITS graph. Sherpa's exporter delegates to upstream `SynthesizerTrn.infer` with `max_len=None` at `/private/tmp/flva-sherpa-src-v1.12.14/scripts/vits/export-onnx-ljs.py:79-102`. Upstream VITS computes stochastic durations, sums them into `y_lengths`, and only applies `max_len` at the final decoder input (`models.py:456-478` in `jaywalnut310/vits`). That late slice does not bound allocations for `y_mask`, attention, expanded priors, or latent tensors on lines 468-476.

6. This exact profile has a 22,050 Hz sample rate, 256-sample hop, and decoder upsample product 8 * 8 * 2 * 2 = 256. `/private/tmp/flva-ljs_base.json:19-27` and `:35-48` provide those values. A pre-decoder limit of 861 frames yields at most 220,416 raw samples, or 9.996 seconds. Frame 862 would yield 220,672 samples, or 10.008 seconds.

7. A reply scalar/byte limit alone is insufficient. Frontend text-to-token expansion happens before `Process` at `/private/tmp/flva-sherpa-src-v1.12.14/sherpa-onnx/csrc/offline-tts-vits-impl.h:209-244`, and there is no token-count rejection before the input tensor is created at `:430-457`. A bounded profile needs both a token cap and a frame cap.

8. The repository's checked header exactly matches the pinned tag header, so there is no hidden local duration-cap extension. SHA-256 for all three inspected headers was `e286ded904e93b670ad229d88151dfade58671fc2740a0afb11b0372f3595100`.

# Feasible fix

Keep the public FLVA ABI and frozen criteria unchanged. Replace the accepted TTS asset profile with a reproducibly derived, hash-pinned bounded VITS model, and reject the current unbounded model hash.

1. Fork the pinned `scripts/vits/export-onnx-ljs.py` conversion path and the exact upstream VITS source used by it. Add a fixed `max_frames = 861` invariant immediately after `w_ceil` and before `y_lengths` in `SynthesizerTrn.infer`. Sanitize non-finite duration values, clamp each duration to `[0, max_frames]`, compute the cumulative frames preceding each token, and replace each duration with `min(duration, max(max_frames - preceding, 0))`. Compute `y_lengths`, `y_mask`, attention, priors, latents, and the decoder input only from these bounded durations. This placement bounds every duration-dependent tensor; using the existing final `max_len` slice alone does not.

2. Make overflow observable. Export a scalar `duration_exceeded` output computed from the original sanitized duration sum. Patch the pinned Sherpa VITS implementation internally to inspect that flag before constructing `GeneratedAudio`; return a distinct internal status without copying PCM when it is set. Add an additive, private-to-this-plugin bounded-generation entry point (or equivalent internal adapter status) so `native/src/flva.cpp` publishes `capacityExceeded`. The FLVA C ABI in `native/include/flva.h` need not change. Do not encode overflow only as callback cancellation because the pinned single-sentence path ignores that return value.

3. Add a fixed maximum frontend token count in the same Sherpa fork, checked after `ConvertTextToTokenIds` and blank insertion but before `Process` creates the tensor. The exact number must be selected and recorded for the pinned English profile; it must be high enough for supported replies while remaining an explicit allocation bound. Keep the existing 240-scalar/960-byte application checks as an earlier defense, not as proof of the token bound.

4. Eliminate avoidable full-audio copies on the bounded path. The internal adapter should deliver the already bounded ONNX output to the FLVA callback without also accumulating `GeneratedAudio.samples` and without the C API `new float[]` copy. If retaining the current API for compatibility, the hard bound still holds, but the peak includes multiple 220,416-float buffers and must be documented and measured. A callback-only additive Sherpa function is preferable.

5. Pin the derived model hash, exporter source commit, upstream VITS source commit, configuration hash, Sherpa fork commit, `max_frames`, token limit, sample rate, and hop length in provisioning and manifest validation. Accept only that exact bounded profile for AC-004. Arbitrary "Sherpa-compatible VITS" models must remain unsupported because their graph topology and hop size do not inherit this proof.

This is a backend/profile change and belongs in the existing feature pipeline. It does not require relaxing AC-004, changing half-duplex behavior, or changing the public plugin ABI.

# Tests

Required implementation tests:

- Export determinism: regenerate the bounded ONNX asset from pinned inputs, run `onnx.checker`, compare the recorded SHA-256, and fail provisioning on any mismatch.
- Graph invariant: inspect the exported graph and assert that the bounded duration tensor, rather than the original stochastic duration tensor, is the sole source of `y_lengths`, the first sequence-mask/range length, attention expansion, latent expansion, and decoder time dimension. Assert `max_frames == 861` and decoder upsample product `== 256`.
- Real model negative: replay the existing 235-byte sentence and longer legal replies. Assert the engine reports `duration_exceeded`, publishes `capacityExceeded`, admits zero stale PCM for that generation, and no ONNX/Sherpa PCM buffer exceeds 220,416 floats.
- Boundary: synthesize inputs producing 860, 861, and overflowing predicted frames. Assert successful audio is at most 220,416 samples and overflow never starts playback. Include non-finite synthetic duration outputs in an exporter/unit harness so NaN and infinities cannot bypass the clamp.
- Token bound: drive frontend expansion to exactly the token limit and one token over. The over-limit case must reject before ONNX `Run`.
- Copy/allocation instrumentation: instrument the bounded Sherpa fork's ONNX output and all `GeneratedAudio`/C-API allocations; retain peak allocation counts and sizes as raw evidence. RSS alone is insufficient to prove an individual allocation bound.
- Cancellation: cancel before inference, during bounded inference, in the callback, and after overflow. Assert generation gates prevent playback and owned resources are released.
- Integration: rebuild the pinned runtime for macOS host tests, Android ABIs, and both iOS slices; rerun native UBSan smoke/failure tests and the complete Dart suite. Physical-device qualification remains a separate AC-005/AC-008 gate.

Inspection checks executed for this research:

```text
$ git -C /private/tmp/flva-sherpa-src-v1.12.14 rev-parse HEAD
26aa2fa93210376a89de3a65a1a4dd320c37f5e9
```

```text
$ shasum -a 256 native/include/c-api.h ios/Frameworks/sherpa-onnx.xcframework/Headers/sherpa-onnx/c-api/c-api.h /private/tmp/flva-sherpa-src-v1.12.14/sherpa-onnx/c-api/c-api.h
e286ded904e93b670ad229d88151dfade58671fc2740a0afb11b0372f3595100  native/include/c-api.h
e286ded904e93b670ad229d88151dfade58671fc2740a0afb11b0372f3595100  ios/Frameworks/sherpa-onnx.xcframework/Headers/sherpa-onnx/c-api/c-api.h
e286ded904e93b670ad229d88151dfade58671fc2740a0afb11b0372f3595100  /private/tmp/flva-sherpa-src-v1.12.14/sherpa-onnx/c-api/c-api.h
```

```text
$ shasum -a 256 /private/tmp/flva-qualification/models/vits-ljs.onnx /private/tmp/flva-ljs_base.json
5bbd273797a9ecf8d94bd6ec02ad16cb41cbb85f055ad98d528ced3e44c9b31a  /private/tmp/flva-qualification/models/vits-ljs.onnx
ae18673015c1346c82af442a73f05297216655a4d931dc8d8315a6cef429832e  /private/tmp/flva-ljs_base.json
```

No implementation or acceptance test was run, and no pass claim is made. This was source-level research only.

# Unresolved

- The derived bounded model has not been exported or executed in this research. Its exact output names, exporter compatibility, hash, audio quality, and mobile build impact are `[UNVERIFIED]` until implemented and tested.
- The exact maximum frontend token count is `[UNVERIFIED]`; it must be chosen from the pinned frontend/profile and then enforced, not inferred from UTF-8 scalar count.
- The exact upstream VITS commit used to create the published `vits-ljs.onnx` is not recorded in the inspected model README and is `[UNVERIFIED]`. Reproducible derivation may require pinning a newly selected upstream commit and treating the result as a new model profile.
- Model derivation and redistribution permissions remain a separate legal/provenance gate. The current model README declares Apache-2.0, but that is not distribution approval for a derived artifact.
- ONNX Runtime arena/RSS limits, empirical long-text sweeps, sentence splitting, callback cancellation, and post-output truncation are not substitutes for the pre-`y_lengths` graph invariant. They may supplement evidence but cannot close F3 alone.
- The current unmodified `vits-ljs.onnx` and prebuilt Sherpa 1.12.14 libraries remain unqualified for AC-004. Until the bounded profile and runtime path are implemented and independently reviewed, F3 remains open.
