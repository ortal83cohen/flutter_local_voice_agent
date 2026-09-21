# Local model packs

The first profile is `en-US-sherpa-vits`, schema 1, sherpa runtime `1.12.14`,
16 kHz mono model input. Local creation remains offline; explicit preparation
can download a verified catalog pack.
English is the initial fixture language, not an inference from the user's locale.

## Example catalog and advanced local installation

The example uses the [built-in catalog](model-catalog.md): select one of the
three English speech configurations (LJS compact, LJS standard, or compact
VCTK) and explicitly download it. No path or manifest input is required. VCTK
is a speaker choice with integer ids 0 through 108, not a language or quality
ranking. Piper, other languages and physical-device quality remain outside
this catalog. The rest of this guide describes advanced host-provided packs
and offline imports.

## Required roles

| Role | Qualification fixture |
|---|---|
| vad | silero_vad.onnx |
| encoder | encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx |
| decoder | decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx |
| joiner | joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx |
| asrTokens | Zipformer tokens.txt |
| ttsModel | vits-ljs.onnx (LJS qualification fixture; catalog VCTK uses vits-vctk.int8.onnx) |
| ttsTokens | VITS tokens.txt, distinct from ASR tokens |
| ttsLexicon | VITS lexicon.txt |
| license | Actual collected license texts and notices |
| llmModel | Optional local GGUF, only with the separately enabled adapter |

The ASR source archive is
[sherpa-onnx-streaming-zipformer-en-2023-06-26](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2).
The VAD source is
[Silero supplied by sherpa](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx).
The TTS qualification fixture is [csukuangfj/vits-ljs](https://huggingface.co/csukuangfj/vits-ljs).
Catalog compact VCTK uses [csukuangfj/vits-vctk](https://huggingface.co/csukuangfj/vits-vctk)
INT8 at frozen revision 5d7d647d6ea0f6206544735d74b25d3877c0f9ca. Pin the
downloaded contents with hashes and preserve source revisions/notices. Source
model-card license labels are not approval to redistribute an archive. These
voices have a finite lexicon and may warn and omit unknown words. Test your
actual response vocabulary; do not assume arbitrary text support. Speaker
labels on VCTK are integer ids 0 through 108; do not invent names, gender or
accent. Piper remains outside this catalog.

## Manifest creation

Create an inventory JSON array locally. Each file has `role`, relative `path`,
`source` (exact upstream provenance), and `license` (a relative path to a listed
license file). For example, a VAD entry refers to your local `silero_vad.onnx`
and the actual license file you collected. Include every required role above;
do not point ASR and TTS tokens at the same file. Then run:

```sh
python3 tool/create_model_manifest.py /absolute/local/pack --inventory /absolute/inventory.json
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
path does not identify an iPhone path. These manual-copy steps are for advanced hosts, not the reference UI, which
now provides catalog selection and verified downloads.

`FileModelStore.install(source: ..., targetRoot: ...)` is a transactional local
copy. It validates before and after staging, then atomically renames into a
unique active directory on the same filesystem. Retain that returned path;
there is no implicit global active-pack switch and no automatic deletion of
previous versions. Hosts must preserve immutability until all readers dispose.
