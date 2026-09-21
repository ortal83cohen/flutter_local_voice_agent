# Choose and download a speech model

After provisioning the native build inputs described in the README, run the
example with `flutter run`. No model path, manifest or manual file copy is needed.

1. Choose an English speech configuration from the model picker.
2. Tap **Download** to permit HTTPS requests to its publishers. Keep the app in
   the foreground. Progress, cancellation and retry remain available.
3. Once model verification and native engine creation succeed, tap **Start** and
   grant microphone permission. Try “hello”, “what is your name”, or “thank you”.
4. Stop or interrupt the conversation with the corresponding controls. On a
   later launch, the selected installed model is revalidated and loaded offline.

The example uses deterministic local replies to demonstrate speech recognition
and synthesis. It is not a general-purpose chat model. All three options use
Silero VAD and the same streaming Zipformer recognizer. The two LJS packs share
one English voice at different precision levels. Compact VCTK is a speaker
choice, not a language or quality ranking. Speaker labels are integer ids 0
through 108; this catalog does not invent names, gender, or accent. Piper,
other languages, and physical-device quality remain outside this catalog.

| Configuration | Downloaded payload including notices | Purpose |
|---|---:|---|
| English compact (INT8) | 114,444,636 bytes (114.4 MB) | Smaller LJS weights/download; default first choice |
| English standard (full precision) | 383,741,867 bytes (383.7 MB) | Full-precision variant of the same LJS models and voice |
| English compact VCTK (INT8) | 116,261,194 bytes (116.3 MB) | Compact English multi-speaker pack; 109 speakers, ids 0-108 |

Stored payload sizes equal download sizes; a small generated manifest and saved
selection are additional. These figures are not RAM estimates or quality/speed
rankings. The example checks available disk space with a 10 MiB margin before a
transfer; this is advisory and does not reserve space. Separate installations and
abandoned stages can consume additional storage.

## Library catalog

`VoiceModelCatalog.entries` exposes immutable `VoiceModelOption` entries with
`id`, `title`, `description`, `language`, `speakerCount`, `descriptor`,
`downloadBytes` and `allowedRedirectOrigins`. LJS options report speaker count
1. Compact VCTK reports 109. Pass the descriptor to `ModelPreparationManager`
with an app-private root, `maxRedirects: 5` and the entry's redirect origins.
Preparation returns an ordinary `LocalModelBundle`. Hosts may pass a
`speakerId` into `LocalVoiceAgent.create` (default 0) and change it later with
`setSpeakerId`. See [preparation](model-preparation.md) for progress,
cancellation and failure contracts.

The static descriptors are reviewed source metadata, not a remotely fetched
catalog. `tool/model_catalog_inventory.json` records the input inventory, and
`tool/verify_catalog.dart OUTPUT_ROOT` explicitly downloads all three packs,
verifies them and tests zero-client offline reuse. It writes role paths for
native tests into `OUTPUT_ROOT/verification.json`. This command transfers about
614 MB when all three packs are absent; it is deliberately outside routine
unit tests.

## Sources and notices

- [Zipformer pinned revision](https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24).
- [VITS LJS pinned revision](https://huggingface.co/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff).
- [VITS VCTK pinned revision](https://huggingface.co/csukuangfj/vits-vctk/tree/5d7d647d6ea0f6206544735d74b25d3877c0f9ca).
- [Silero release source](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models), asset 271935959, content pinned by SHA-256; the release URL itself is mutable.
- [Silero MIT notice](https://github.com/snakers4/silero-vad/blob/60b7ffa243625ebdc1070275a29f18c87843786a/LICENSE).

Publisher model cards declaring Apache-2.0, full Apache-2.0 text and the Silero
MIT notice are downloaded and verified alongside the weights. Every file has a
pinned expected size and SHA-256; changed publisher bytes fail integrity. No
weights are bundled or redistributed by this repository. Source notices record
publisher declarations; they do not grant additional redistribution rights.

Observed extra CDN origins are `https://us.aws.cdn.hf.co` and
`https://release-assets.githubusercontent.com`. The downloader rejects other
origins, downgrade and excess redirects. Signed temporary URLs are never saved
in the catalog. Publisher/CDN changes may require a catalog update.

## Storage and recovery

The example owns a persistent private base directory: Android's no-backup
files directory and iOS Application Support with backup exclusion. It stores
one subdirectory per known catalog id and a saved selection. Startup uses a
network-disabled preparation factory; a missing or damaged installation never
silently downloads. An explicit retry of a corrupt inactive selection can replace
only that pack's private directory. Other installed packs are retained. Changing
models disposes the old voice session before loading the next.

Backgrounding cancels preparation and stops listening. Cancellation settles before
another operation starts. Return to the foreground and explicitly retry or start.
Failed setup leaves Start unavailable. Network errors require connectivity or a
publisher/catalog update; storage errors require free writable space. No account,
API key or cloud inference service is used.

Real host fixture recognition/synthesis and an emulator flow are distinct from
physical Android/iOS audio, memory or thermal qualification. The VITS finite
lexicon emits known token warnings; arbitrary pronunciation quality and the
upstream whole-sentence allocation bound remain open. Native dependency packaging
for fresh published consumers is also unfinished; see [capabilities](capabilities.md).
