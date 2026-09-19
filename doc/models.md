# Local model packs

The first profile is `en-US-sherpa-vits`, schema 1, sherpa runtime `1.12.14`,
16 kHz mono model input. Supply files locally; the SDK never fetches them.
English is the initial fixture language, not an inference from the user's locale.

## Required roles

| Role | Qualification fixture |
|---|---|
| vad | silero_vad.onnx |
| encoder | encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx |
| decoder | decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx |
| joiner | joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx |
| asrTokens | Zipformer tokens.txt |
| ttsModel | vits-ljs.onnx |
| ttsTokens | VITS tokens.txt, distinct from ASR tokens |
| ttsLexicon | VITS lexicon.txt |
| license | Actual collected license texts and notices |
| llmModel | Optional local GGUF, only with the separately enabled adapter |

The ASR source archive is
[sherpa-onnx-streaming-zipformer-en-2023-06-26](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2).
The VAD source is
[Silero supplied by sherpa](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx).
The TTS source is [csukuangfj/vits-ljs](https://huggingface.co/csukuangfj/vits-ljs).
Pin the downloaded contents with hashes and preserve source revisions/notices.
Source model-card license labels are not approval to redistribute an archive.
This voice has a finite lexicon and may warn and omit unknown words. Test your
actual response vocabulary; do not assume arbitrary text support.

## Manifest creation

Create an inventory JSON array locally. Each file has `role`, relative `path`,
`source` (exact upstream provenance), and `license` (a relative path to a listed
license file). For example, a VAD entry refers to your local `silero_vad.onnx`
and the actual license file you collected. Include every required role above;
do not point ASR and TTS tokens at the same file. Then run:

```sh
python3 tools/create_model_manifest.py /absolute/local/pack --inventory /absolute/inventory.json
```

The tool refuses to overwrite a manifest. It computes `bytes` and `sha256` for
each file and writes schema/profile/runtime/inputRate metadata. Verify your
source and license inventory before making that manifest trusted. The runtime
validates file sizes and hashes again. Absolute/traversal paths, symlink escapes,
missing roles and incompatible runtime versions fail preflight. Limits are
64 KiB manifest, 128 entries, 2 GiB per file and 4 GiB total; those are input
limits, not promised device memory use.

Keep a pack in application-private storage. On Android, a debug app may receive
files with `adb push` followed by `run-as` copying into its `files` directory;
use its actual application ID and paths, and verify the copy's manifest inside
the app. On iOS, use an app-owned import flow or copy into a simulator's app
container obtained with `xcrun simctl get_app_container`. A development-machine
path does not identify an iPhone path. The reference UI takes an already
provisioned directory; it does not implement a network browser or downloader.

`FileModelStore.install(source: ..., targetRoot: ...)` is a transactional local
copy. It validates before and after staging, then atomically renames into a
unique active directory on the same filesystem. Retain that returned path;
there is no implicit global active-pack switch and no automatic deletion of
previous versions. Hosts must preserve immutability until all readers dispose.
