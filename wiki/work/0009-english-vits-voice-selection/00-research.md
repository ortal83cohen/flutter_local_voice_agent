# Research: English VITS lexicon voice selection

## Question

Which English voices can this library and example expose without leaving the current sherpa VITS-plus-lexicon contract, and what catalog, native, example and documentation changes does that require?

## Answer

Stay on the existing English Zipformer recognizer, Silero detector and VITS-plus-lexicon synthesizer. Keep the two LJS precision packs. Add one compact VCTK pack so the example can choose a different English speaker from a single downloaded multi-speaker model. Piper, Kokoro, Kitten, Matcha, eSpeak data directories and every non-English language stay out of this item. Exact VCTK file pins remain an implementation inventory step.

## Findings

### Current catalog is precision, not voice

- Claim: The public catalog has two English packs that share the LJS voice, Zipformer recognizer and Silero detector. The documented difference is INT8 versus full precision, not speaker or language.
- Evidence: `lib/src/model_catalog.dart` titles both entries as English LJS. `doc/model-catalog.md` and `wiki/product/example-model-catalog.md` state that both choices use the same US English LJS voice.
- Source: repository files above, last read 2026-09-20.

### Native synthesis hard-codes speaker zero and lexicon VITS

- Claim: Session creation fills only the VITS lexicon configuration. Generation always passes speaker id zero. The vendored C API already accepts a speaker id and can report speaker count.
- Evidence: `native/src/flva.cpp` constructs the VITS model from model, lexicon and tokens and calls generate with speaker id 0. `native/include/c-api.h` documents `SherpaOnnxOfflineTtsNumSpeakers` and generate speaker id. `native/include/flva.h` has no speaker field.
- Source: repository files above, last read 2026-09-20.

### Manifest and preparation profiles are English VITS lexicon

- Claim: Local validation and preparation require profile `en-US-sherpa-vits`, runtime `1.12.14`, input rate 16000, and roles including `ttsModel`, `ttsTokens` and `ttsLexicon`.
- Evidence: `lib/src/model_store.dart`, `lib/src/model_preparation.dart`, `doc/models.md`.
- Source: repository files above, last read 2026-09-20.

### Example selection stores only a catalog id

- Claim: The example picker lists catalog titles. Saved selection is a JSON object with `catalogId` only. Changing models disposes the old session before creating the next.
- Evidence: `example/lib/main.dart`, `example/lib/voice_screen_controller.dart`, `example/lib/model_storage.dart`.
- Source: repository files above, last read 2026-09-20.

### Official English lexicon VITS voices

- Claim: sherpa-onnx documents two English VITS models that use a lexicon file: LJS, one speaker already shipped, and VCTK, 109 speakers with ids 0 through 108. The official VITS page lists VCTK INT8 and full-precision files. This repository already ships LJS INT8 and full precision from the pinned Hugging Face LJS revision; the official VITS page lists only the full-precision LJS file.
- Evidence: Official VITS page lists LJS and VCTK with `--vits-lexicon`. It shows `vits-vctk.int8.onnx` at 37M and `vits-vctk.onnx` at 116M in the unpacked listing. Default speaker id is 0.
- Source: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html consulted 2026-09-20.

### Lessac and other English Piper voices are out of contract

- Claim: `en_US-lessac-medium` and the large English Piper list require `espeak-ng-data` through `--vits-data-dir`. That is the Piper path the user deferred, and it reopens the eSpeak GPL inventory.
- Evidence: The same VITS page documents Lessac with `--vits-data-dir`. The English sample index lists many `vits-piper-en_*` voices. Prior research recorded eSpeak NG as GPL-3.0.
- Source: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html , https://k2-fsa.github.io/sherpa/onnx/tts/all/English/ , `wiki/work/0001-local-voice-agent-architecture/research/intelligence-tts.md`, consulted 2026-09-20.

### VCTK publisher files exist on Hugging Face

- Claim: `csukuangfj/vits-vctk` publishes `vits-vctk.int8.onnx`, `vits-vctk.onnx`, `tokens.txt`, `lexicon.txt` and a model card labelled Apache-2.0. This matches the current LJS pinning pattern. The tree listing is `main`, not a frozen commit.
- Evidence: Hugging Face tree and raw README fetched 2026-09-20. Page-reported sizes were about 39.2 MB INT8, 121 MB full precision, 1.08 kB tokens and 3.71 MB lexicon. Those sizes are UI listings, not hashed downloads.
- Source: https://huggingface.co/csukuangfj/vits-vctk/tree/main , https://huggingface.co/csukuangfj/vits-vctk/raw/main/README.md

### Catalog and library docs currently deny voice choice

- Claim: Consumer and wiki docs say the two packs are the same LJS voice and that arbitrary voices remain future work.
- Evidence: `README.md`, `doc/model-catalog.md`, `doc/capabilities.md`, `doc/models.md`, `doc/model-preparation.md`, `wiki/product/example-model-catalog.md`, `wiki/adr/0003-example-model-catalog.md`.
- Source: repository files above, last read 2026-09-20.

### Optional LLM and non-English work stay unrelated

- Claim: Example replies are deterministic. Hebrew and other languages were already recorded as unverified and are outside the user lock for this item.
- Evidence: `doc/model-catalog.md`, `wiki/work/0004-managed-model-setup/00-research.md`, user decision 2026-09-20.
- Source: repository files and this conversation.

## Options considered

| Option | How it works | Cost | Why rejected / chosen |
|---|---|---|---|
| Keep LJS only | No voice change | Zero | Rejected. The user asked for English voice choice in the example. |
| Add Piper English voices | Many male/female/accent packs through `data_dir` | Native contract change plus eSpeak GPL review | Rejected for this item. The user deferred Piper. |
| Add Kokoro or Kitten | New TTS family already present in the vendored C API | New assets, config, likely eSpeak, quality spike | Rejected. Leaves the lexicon VITS contract. |
| Replace LJS with VCTK | One multi-speaker pack | Loses the already verified LJS fixture | Rejected. Keep the existing packs. |
| Add VCTK compact and standard | Two new complete bundles | Duplicates the large Zipformer download twice | Rejected for this item. One compact VCTK pack is enough to offer speakers. |
| Keep LJS packs and add compact VCTK | Third complete English bundle plus speaker id | Catalog inventory, sid plumbing, example picker, docs | Chosen. Fits the current complete-bundle catalog and lexicon loader. |
| Shared ASR plus TTS overlay | Download voice files only | Changes preparation, storage and catalog identity | Rejected. The catalog contract is a complete speech bundle per id. |

## Constraints discovered

- The native loader requires a lexicon file and rejects a missing TTS path. Piper `data_dir` voices cannot be loaded without a native change.
- A catalog entry is a complete speech bundle. Adding VCTK repeats Silero and Zipformer bytes under a new id.
- Speaker id is a generate argument, not a model file. Changing speaker does not require a new download.
- The current C ABI and Android JNI create path have no speaker field. Existing iOS and any later desktop bridges must receive the same addition.
- Profile `en-US-sherpa-vits` can remain. VCTK is still English VITS with a lexicon.
- sherpa documents VCTK speakers as integers 0-108. No official name table is attached to that model page.
- Publisher license labels are not redistribution approval. The catalog must keep pinned notices, sizes and hashes.
- The open VITS whole-sentence allocation gate remains. A new voice does not close it.
- Work item 0008 is frozen for desktop coverage and must not be silently rewritten. New ABI fields need to be added in the existing Android and iOS bridges in this item.

## Unresolved

- [UNRESOLVED: Exact VCTK revision, byte lengths and SHA-256 values for model, tokens, lexicon and notices. These must be measured from downloaded bytes during implementation inventory, not copied from Hugging Face UI sizes.]
- [UNRESOLVED: Whether a verified sid-to-VCTK-corpus-name table exists in the selected archive. Until then the example may only label speakers by integer id.]
- [UNRESOLVED: Measured intelligibility, RAM, latency and thermal difference between LJS and VCTK INT8 on physical phones.]
- [UNRESOLVED: Whether VCTK INT8 omits the same out-of-lexicon words as LJS for the demo reply vocabulary.]

## Sources

Consulted 2026-09-20:

- `lib/src/model_catalog.dart`, `lib/src/model_store.dart`, `lib/src/model_preparation.dart`, `lib/src/agent.dart`, `lib/src/contracts.dart`
- `native/src/flva.cpp`, `native/include/flva.h`, `native/include/c-api.h`, `android/src/main/cpp/bridge.cpp`
- `example/lib/main.dart`, `example/lib/voice_screen_controller.dart`, `example/lib/model_storage.dart`
- `README.md`, `doc/model-catalog.md`, `doc/models.md`, `doc/capabilities.md`, `doc/model-preparation.md`, `doc/testing.md`
- `wiki/product/example-model-catalog.md`, `wiki/adr/0003-example-model-catalog.md`, `wiki/work/0001-local-voice-agent-architecture/research/intelligence-tts.md`
- https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html
- https://k2-fsa.github.io/sherpa/onnx/tts/all/English/
- https://huggingface.co/csukuangfj/vits-vctk/tree/main
- https://huggingface.co/csukuangfj/vits-vctk/raw/main/README.md
