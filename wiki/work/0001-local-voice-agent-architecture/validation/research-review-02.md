# Research review — round 02

- Work item: 0001-local-voice-agent-architecture
- Reviewed artifact: `00-research.md` and `research/speech.md`, `research/intelligence-tts.md`, `research/mobile-systems.md`
- Reviewer: research-confirmation
- Date: 2026-09-19

## Verdict

**PASS**

The research-phase criteria are met. The prior blocking Moonshine license finding is resolved in the current artifact and independently confirmed against both upstream sources. No new blocking findings were identified in this representative review.

## Verification performed

Read only the acceptance criteria, current research artifacts, validation rubric, and preceding research report. The author transcript, plan, decision notes, and implementation were not consulted. This verdict covers the research phase, not a working SDK, final specification, device behavior, or redistribution approval.

Executed from the repository root:

```text
$ python3 tools/lint_wiki.py
lint_wiki: clean (0 warning(s)).
```

Exit code: 0. This check ran before this review report was created.

Fresh primary-source checks used web open/find operations on 2026-09-19:

| Source | Independently observed evidence |
|---|---|
| [Moonshine README](https://github.com/moonshine-ai/moonshine) | MIT is the default across model languages and sizes; the exception concerns legacy non-streaming non-English models. |
| [Moonshine LICENSE](https://github.com/moonshine-ai/moonshine/blob/main/LICENSE) | Every streaming STT model is MIT. The document enumerates the legacy exceptions; TTS/G2P assets and third-party source have separate terms. The reviewed speech comparison does not assign its STT license conclusion to those assets. |
| [MLX Swift examples](https://github.com/ml-explore/mlx-swift-examples) | LLMEval and MLXChatExample explicitly support iOS and macOS. This supports the updated optional Apple-runtime characterization; it does not establish Android support or a provisioned strict-offline Flutter integration. |

The supplement correctly distinguishes current LiteRT-LM evidence from the initial MediaPipe shortlist and generated-audio callbacks from incremental text conditioning. Unknown device memory, latency, accuracy, thermal behavior, package size, and selected model redistribution remain explicit uncertainties, consistent with the acceptance criteria. Source checking is representative rather than an exhaustive audit of every link or model archive.

## Per-criterion results

| Criterion | Research-phase result | Evidence (file:line) | Negative case exercised |
|---|---|---|---|
| AC-001 | pass | `research/speech.md:110`, `:116`, `:136`; `research/intelligence-tts.md:13`, `:84`, `:88`, `:96` | Tested the former language-wide license claim against current primary sources: it is absent from the revised comparison and contradicted by the cited exception list. The revised distinction agrees with both sources. Checked that supplier claims and unknown phone metrics are not presented as this project's benchmark results. |
| AC-005, research support | pass | `research/mobile-systems.md:66`, `:70`, `:80`, `:84` | Unconditional background operation is explicitly excluded; permission, focus, service and app-wide audio-session constraints are documented. This is a document check, not device validation. |
| AC-007, research support | pass | `00-research.md:49`; `research/mobile-systems.md:101`; `research/intelligence-tts.md:49` | Missing local assets cannot justify silent fetching or cloud fallback under the proposed contract. Deterministic logic remains a valid no-LLM route. |
| AC-008, research artifacts | pass | `00-research.md:63`; command output above | Lint detects no current wiki warnings; supporting research is linked from the consolidation. Final specification navigation and downstream artifact requirements are outside this verdict. |
| AC-002, AC-003, AC-004, AC-006 | not assessed in this phase | Research is input to the future specification. | No implementation or final API conformance is inferred from the research. |

## Findings

None.

## Recurrence check

- Previous round: `research-review-01.md` — FAIL.
- F-001: resolved at `research/speech.md:110` and `research/speech.md:116`; the source evidence is recorded at `research/speech.md:136` and was independently rechecked above.
- Recurring findings: none.
- Oscillating: no.

## Routing

No findings to route. This is the second and final research validation round.
