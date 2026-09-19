# Research review — round 01

- Work item: 0001-local-voice-agent-architecture
- Reviewed artifact: `00-research.md` and `research/speech.md`, `research/intelligence-tts.md`, `research/mobile-systems.md` in this work item
- Reviewer: research-validator
- Date: 2026-09-19

## Verdict

**FAIL**

The representative comparison and mobile constraints are substantial, but one current model-license claim contradicts its primary source and fails AC-001.

## Verification performed

Read the acceptance criteria, phase rubric, report template, and four research artifacts without reading the plan, author transcript, or other reviews. Reviewed the supplementary sections as part of the artifacts; the consolidation explicitly identifies the MediaPipe and TTS callback updates as superseding initial conclusions. Unknown phone metrics are correctly distinguished from measured results.

Executed from the repository root:

```text
$ python3 tools/lint_wiki.py
lint_wiki: clean (0 warning(s)).
```

Exit code: 0. This was the repository state before creating this report; it does not validate the later final specification.

Primary-source web spot checks used `web.run` open/find operations on 2026-09-19:

| Tool operation and source | Observed evidence |
|---|---|
| Open `https://developers.google.com/edge/litert-lm` | The page lists Android, iOS, Web and desktop, and describes `flutter_gemma` as community-maintained. |
| Open `https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference` | The API update states “maintenance-only mode” and recommends LiteRT-LM migration. |
| Open `https://developer.android.com/about/versions/17/changes/bg-audio`, find `SHORT_SERVICE` | The page distinguishes all-app background restrictions from target-37 while-in-use requirements; playback can fail silently. |
| Open `https://github.com/OHF-Voice/piper1-gpl`, find `GPL` | The repository identifies GPL-3.0 and embedded eSpeak NG phonemization. |
| Open `https://github.com/TEN-framework/ten-vad/blob/main/LICENSE`, find `Additional` | The root license includes Apache terms with additional competition and deployment restrictions. |
| Open `https://github.com/moonshine-ai/moonshine`, find `License`; open its `LICENSE`, find `models` and `legacy` | Both the README and license identify MIT as the default for speech recognition models, including all streaming models; an enumerated legacy non-streaming subset is excepted. This contradicts the research's language-wide distinction. |
| Open `https://github.com/ml-explore/mlx-swift-examples`, find `iOS` | Upstream Swift examples include iOS LLM inference and chat. The research's MLX platform uncertainty is conservative, but this is additional evidence beyond its consulted source. |
| Open `https://developer.apple.com/documentation/speech/speechanalyzer` | The extracted page contained only the documentation shell; this operation did not independently verify the full API contract. |

Representative source checking is not an exhaustive audit of every link, model archive, or transitive dependency. No device benchmark, package build, redistribution approval, or working SDK is asserted by this review.

## Per-criterion results

Research-phase scope only; downstream specification criteria remain for their respective reviews.

| Criterion | Result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | fail | `research/speech.md:110`; runtime/TTS comparison in `research/intelligence-tts.md:13` and supplementary evidence at `:86` | Yes: checked whether an asserted model-license distinction survives the current primary license; it does not. Universal coverage and unmeasured superiority are explicitly disclaimed. |
| AC-005, research support | pass | `research/mobile-systems.md:64` through platform lifecycle sections | Yes: unconditional background microphone and playback guarantees are excluded; Android 17 restrictions were checked against official documentation. This is not device validation. |
| AC-007, research support | pass | `00-research.md:49`; `research/mobile-systems.md:104` onward | Yes: absent assets, hidden network fallback, and mandatory LLM use are explicitly rejected. Final implementation behavior remains unverified. |
| AC-008, current research artifacts | pass | `00-research.md:63`; wiki lint output above | Yes: lint checked current wiki conventions; the final PRD and its navigation are outside this phase's verdict. |

## Findings

### F-001 — Moonshine license distinction incorrectly applies to all non-English models

- Severity: BLOCKER
- Location: `wiki/work/0001-local-voice-agent-architecture/research/speech.md:110`
- Criterion affected: AC-001
- Observation: The report says English models are MIT while non-English models use the Community License. The current [upstream README](https://github.com/moonshine-ai/moonshine) and [root license](https://github.com/moonshine-ai/moonshine/blob/main/LICENSE) instead make speech recognition models MIT by default across languages and sizes, explicitly including every streaming model. Only the enumerated legacy non-streaming non-English models retain the Community License. The table at line 116 also reduces this distinction to language. The source does contain registration/revenue conditions for its Community License section, but those conditions do not apply to every non-English streaming model as the report implies.
- Why it matters: License conditions are a stated comparison dimension and affect which streaming multilingual candidate can be considered for distribution. This is an incorrect current-source characterization, not an unresolved target-device measurement.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | research |
