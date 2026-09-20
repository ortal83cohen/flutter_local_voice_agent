# Research review — round 01

- Work item: 0009-english-vits-voice-selection
- Reviewed artifact: wiki/work/0009-english-vits-voice-selection/00-research.md
- Reviewer: blind-research-validator
- Date: 2026-09-20

## Verdict

**PASS**

The merged research’s stay-on-lexicon-VITS conclusion, the keep-LJS-plus-compact-VCTK choice, and the explicit unresolved inventory and quality questions are supported by the current repository and by independently re-checked sherpa and Hugging Face sources. Remaining findings are citation wording only and do not invalidate the criteria that depend on this research. This verdict certifies research accuracy only; AC-001 through AC-012 still require later implementation evidence.

## Verification performed

The reviewer read `00-research.md`, `02-criteria.md`, `wiki/conventions/validation-rubrics.md` and `wiki/templates/validation-report.md`. Work item 0009 plan, task list, work-item state and author transcripts were not inputs. Cited repository files and URLs were re-checked independently.

```text
$ python3 tool/lint_wiki.py
lint_wiki: clean (0 warning(s)).
```

Repository spot checks:

```text
$ python3 - <<'PY'
from pathlib import Path

def show(path, needles):
    lines = Path(path).read_text().splitlines()
    print(f'===== {path} =====')
    for i,line in enumerate(lines,1):
        if any(n.lower() in line.lower() for n in needles):
            print(f'{i}:{line}')
    print()

show('lib/src/model_catalog.dart', ['English compact','English standard','LJS English','en-us-ljs','VoiceModelCatalog'])
show('native/include/flva.h', ['tts_lexicon','speaker','sid','FlvaConfig'])
show('example/lib/model_storage.dart', ['catalogId'])
show('README.md', ['same English voice','No Hebrew'])
show('doc/model-catalog.md', ['same','US English LJS','Both choices'])
show('wiki/product/example-model-catalog.md', ['same LJS','precision choice'])
show('wiki/adr/0003-example-model-catalog.md', ['arbitrary voices'])
show('wiki/work/0004-managed-model-setup/00-research.md', ['Hebrew'])
show('wiki/work/0001-local-voice-agent-architecture/research/intelligence-tts.md', ['GPL-3.0','eSpeak NG'])
PY
===== lib/src/model_catalog.dart =====
44:abstract final class VoiceModelCatalog {
48:      title: 'English compact (INT8)',
49:      description: 'Smaller INT8 speech models with the LJS English voice.',
52:        id: 'en-us-ljs-zipformer-int8',
220:      title: 'English standard (full precision)',
221:      description: 'Full-precision speech models with the same LJS English voice. Larger download.',
224:        id: 'en-us-ljs-zipformer-standard',

===== native/include/flva.h =====
13:  const char *tts_model, *tts_tokens, *tts_lexicon;
16:} FlvaConfig;
24:FlvaSession *flva_create(const FlvaConfig *, char *error, int32_t error_capacity);

===== example/lib/model_storage.dart =====
95:      if (value is! Map || value['catalogId'] is! String) {
98:      return value['catalogId'] as String;
119:        jsonEncode(<String, String>{'catalogId': option.id}),

===== README.md =====
117:The packs use the same English voice at different precision levels. No Hebrew,

===== doc/model-catalog.md =====
15:and synthesis. It is not a general-purpose chat model. Both choices use the same
16:US English LJS voice, Silero VAD and streaming Zipformer recognizer:

===== wiki/product/example-model-catalog.md =====
13:The example offers complete English speech bundles: compact INT8 (114,444,636 bytes) and full precision (383,741,867 bytes). They use the same LJS voice, Zipformer recognizer and Silero detector; this is a precision choice, not a speaker or language selector. `VoiceModelCatalog.entries` exports exact content metadata, publisher notices and observed CDN origins. The source inventory is tool/model_catalog_inventory.json.

===== wiki/adr/0003-example-model-catalog.md =====
17:Keep the existing native inference pipeline and local reply callback. A downloadable speech configuration is not a general-purpose LLM. Background, active-session and asynchronous disposal guards are part of the visible workflow. Physical-device quality, arbitrary voices/languages, updates, automatic orphan cleanup and native consumer packaging remain separately tracked work.

===== wiki/work/0004-managed-model-setup/00-research.md =====
50:- [UNRESOLVED: required languages beyond the initial English candidate; Hebrew support is UNVERIFIED.]

===== wiki/work/0001-local-voice-agent-architecture/research/intelligence-tts.md =====
30:| Piper, current project | ... stated licence is GPL-3.0. ...
98:... the current eSpeak NG project is GPL-3.0. ...
104:| eSpeak NG | ... its repository reports GPL-3.0. ...

$ rg -n "FlvaConfig|flva_create|speaker|sid" ios/Classes/FlutterLocalVoiceAgentPlugin.mm android/src/main/cpp/bridge.cpp
android/src/main/cpp/bridge.cpp:31:  FlvaConfig c{v[0].c_str(),v[1].c_str(),v[2].c_str(),v[3].c_str(),v[4].c_str(),v[5].c_str(),v[6].c_str(),v[7].c_str(),v[8].c_str(),16000};
android/src/main/cpp/bridge.cpp:32:  char error[2048]{}; auto *s=flva_create(&c,error,sizeof(error));
ios/Classes/FlutterLocalVoiceAgentPlugin.mm:69:    FlvaConfig c{};
ios/Classes/FlutterLocalVoiceAgentPlugin.mm:72:    char message[2048]{};_session=flva_create(&c,message,sizeof(message));

$ rg -n "SherpaOnnxOfflineTtsNumSpeakers|Generate\(" native/include/c-api.h | head
1115:SherpaOnnxOfflineTtsNumSpeakers(const SherpaOnnxOfflineTts *tts);
1120:SHERPA_ONNX_API const SherpaOnnxGeneratedAudio *SherpaOnnxOfflineTtsGenerate(
```

Native generate hard-codes speaker id 0 at `native/src/flva.cpp:332-333` (`SherpaOnnxOfflineTtsGenerateWithCallbackWithArg(..., 0, 1.0f, ...)`). VITS construction at `native/src/flva.cpp:112` fills model, lexicon and tokens and leaves `data_dir` empty. Example pack change disposes first at `example/lib/voice_screen_controller.dart:176`. Catalog `VoiceModelOption` has no speaker-count field today. Profile `en-US-sherpa-vits`, runtime `1.12.14`, input rate 16000 and roles `ttsModel` / `ttsTokens` / `ttsLexicon` are required in `lib/src/model_store.dart` and `lib/src/model_preparation.dart`.

URL re-checks on 2026-09-20 (curl):

- `https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html` HTTP 200. Table and VCTK section state English multi-speaker VCTK with 109 speakers, ids 0 through 108, default speaker id 0, `--vits-lexicon`, and unpacked listing `vits-vctk.int8.onnx` 37M / `vits-vctk.onnx` 116M. LJS section is English single-speaker with `--vits-lexicon` and lists `vits-ljs.onnx` 109M only. The fetched page contains no `vits-ljs.int8` string and no `female` string. Lessac usage examples use `--vits-data-dir=./vits-piper-en_US-lessac-medium/espeak-ng-data`.
- `https://k2-fsa.github.io/sherpa/onnx/tts/all/English/` HTTP 200. Lists many `vits-piper-en_*` voices, including `vits-piper-en_US-lessac-medium`.
- `https://huggingface.co/csukuangfj/vits-vctk/tree/main` HTTP 200. Title is `csukuangfj/vits-vctk at main`. Embedded listing sizes: `vits-vctk.int8.onnx` 39240108 bytes, `vits-vctk.onnx` 121285056 bytes, `tokens.txt` 1084 bytes, `lexicon.txt` 3708181 bytes.
- `https://huggingface.co/csukuangfj/vits-vctk/raw/main/README.md` HTTP 200. YAML `license: apache-2.0`.
- `https://huggingface.co/api/models/csukuangfj/vits-vctk` HTTP 200. `sha` `5d7d647d6ea0f6206544735d74b25d3877c0f9ca`; tag `license:apache-2.0`; siblings include `vits-vctk.int8.onnx`, `vits-vctk.onnx`, `tokens.txt`, `lexicon.txt` and `README.md`. No sid-to-corpus-name table filename is present.

No implementation test, catalog download, digest measurement, or physical-device run was executed. Negative cases in AC-001 through AC-012 remain future implementation checks.

## Per-criterion results

Not applicable. This is a research review. AC-001 through AC-012 were used to judge whether the research’s claims, alternatives and sources can support later implementation, not to certify code.

## Findings

### F-001 — Official VITS page does not call LJS female

- Severity: NIT
- Location: `wiki/work/0009-english-vits-voice-selection/00-research.md:39`
- Criterion affected: none
- Observation: The official-voices claim describes LJS as “one female speaker already shipped.” The cited VITS page, independently fetched on 2026-09-20, labels LJS as English single-speaker and contains no `female` string. The repository catalog titles and descriptions say “LJS English voice,” not female. Gender metadata is explicitly not required by the criteria.
- Why it matters: The cited primary source does not support the gender word. The single-speaker fact that later criteria rely on is otherwise confirmed.

### F-002 — Official VITS page does not list an LJS INT8 file

- Severity: NIT
- Location: `wiki/work/0009-english-vits-voice-selection/00-research.md:39`
- Criterion affected: none
- Observation: The same paragraph says both LJS and VCTK “have INT8 and full-precision ONNX files,” with evidence that the official VITS page shows the VCTK INT8 and full-precision unpacked listing. The independently fetched LJS section lists only `vits-ljs.onnx` at 109M; the page text contains no `vits-ljs.int8`. LJS INT8 is present in this repository’s catalog as `tts/vits-ljs.int8.onnx` from the pinned Hugging Face LJS revision.
- Why it matters: The “both” INT8 claim is true of the current catalog, but the official page cited as evidence does not document LJS INT8. VCTK INT8 on that page and on Hugging Face was confirmed.

## Recurrence check

- Previous round: none — first research review
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | research |
| F-002 | research |
