# Verification and physical qualification

## Dart

```sh
flutter pub get
flutter test
dart format lib example/lib
dart analyze --fatal-infos --fatal-warnings
python3 tool/lint_wiki.py
```

The preparation tests additionally need the `openssl` executable on the host.
They generate a temporary localhost certificate/key, start a real TLS server and
configure the test client to trust that certificate. No key is committed and no
real model download is required. These controlled synthetic payloads qualify
installer behavior only. Tests exercise truncated/corrupt responses, redirects,
network waits, cancellation, cache integrity and concurrent activation.

These tests use actual temporary files for manifest integrity and injected
platform schedulers for lifecycle fault cases. They do not count as speech-engine
or microphone tests. Flutter 3.47.0 / Dart 3.13.0 is the validation toolchain.

## Native

```sh
python3 tool/test_native.py --ubsan
```

This runs bounded-ring, stateful resampler and exhaustive Unicode scalar tests.
Malformed native replies are also tested during an actual awaited real-engine
reply, followed by a valid reply on the same generation. This prevents a stale
generation rejection from masking a missing input check. Add `--runtime` pointing to
the local sherpa `lib` directory and `--assets` with these nine absolute paths,
in order: Silero, encoder, decoder, joiner, ASR tokens, VITS model, VITS tokens,
VITS lexicon, and mono 16 kHz PCM16 test WAV. The script compiles and runs real
speech smoke and failure tests. It has no fake-engine mode. It checks repeated
real turns, stale replies, overflow, invalid assets/rates, interruption, silence
after cancellation and stop/dispose.

`--sanitize` additionally requests ASan. The local host's ASan runtime stalled
before `main` even for an empty probe; that run is not counted as passed. UBSan
and ordinary tests execute separately. Upstream prebuilt inference libraries
are not sanitizer-instrumented, so a sanitized bridge is not proof about their
internal memory behavior.

## Mobile builds

```sh
python3 tool/provision_runtime.py android --archive /local/pinned-android.tar.bz2
python3 tool/provision_runtime.py ios --archive /local/pinned-ios.tar.bz2
cd example
flutter build apk --debug --target-platform android-arm64
flutter build ios --simulator --debug --no-codesign
flutter build ios --release --no-codesign
```

Builds prove source compilation and linkage for that variant. A simulator does
not qualify iPhone microphones, audio focus, routes, thermals or memory. Debug
and unsigned artifacts are not release/store approval. Optional LLM builds are
described in [the LLM guide](llm.md).

## Catalog and example acceptance

Run `flutter test` inside example in addition to the root package tests. The
controller/widget tests cover selection, download cancellation and retry,
private storage, cache reuse, corruption recovery, low capacity and late
lifecycle completions. Run `sh tool/check.sh` for the combined checks.

For real publisher bytes, run `dart run tool/verify_catalog.dart /absolute/temp/output`.
This downloads all three English catalog configurations — LJS compact, LJS
standard, and compact VCTK (109 speakers, integer ids 0-108) — about 614 MB
combined, verifies all declared bytes and manifests, then retries with a
client factory that throws to prove offline reuse. VCTK is a speaker choice,
not a language or quality ranking. Piper, other languages and physical-device
quality remain outside this catalog. Its verification.json records installed
role paths for the native smoke command described above. Network access and
disk space are required; this is separate from ordinary unit tests.

In the provisioned example, select a catalog entry, tap Download and prepare,
then Start once ready. On VCTK, speaker labels are integer ids 0 through 108.
No directory entry or model copying is required. Verify cancel/retry, model
switching and a force-stop/relaunch with device networking disabled. Restore
networking after the test. See [the catalog guide](model-catalog.md) for
source, size, storage and recovery details. Advanced host-managed local packs
remain supported by the library as described in [models](models.md).

## Required device protocol (still open)

Use at least two Android tiers and two iPhone generations for release decisions.
Record app revision, exact models and hashes, compiler/runtime versions, OS,
route, thermal state, thread counts, context, output rate and power conditions.
Run 100 warm utterances, 20 independent cold starts and a 30-minute sustained
session; include failed and cancelled trials. Measure p50/p95 speech-end to first
audible output, externally measured interruption tail, WER/CER, command success,
process/native memory, battery/thermal trajectory, dropped capture and render
underflow. Do not substitute Dart timestamps for audible speaker timing.

Test clean local installation and restart with network denied. Cover permission
deny/revoke, phone interruption, focus loss, backgrounding, headphones removed,
Bluetooth/USB changes, silence/noise, maximum-duration speech, cancellation during
load/ASR/logic/TTS/playback, repeated stop/dispose, slow event consumers, invalid
models and low storage. Capture evidence of microphone release after stop.

Full duplex remains unavailable until self-echo and double-talk tests meet
ratified false/missed-interruption limits on each supported route. Simultaneous
capture/playback is not AEC evidence. No physical device was connected during
this implementation; no physical performance or acoustic numbers are claimed.
