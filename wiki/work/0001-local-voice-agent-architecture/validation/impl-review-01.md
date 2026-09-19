# Implementation review, round 1

## Verdict

**PASS — documentation deliverable.** Every frozen acceptance criterion is met by the submitted specification and supporting artifacts. No blocker or important finding was identified.

This verdict does not establish a working SDK, a published model pack, legal clearance, repository Dart analysis, mobile compilation or device behavior. The recorded repository Flutter/Dart cache failure remains an external verification gap; the criteria explicitly distinguish it from document quality. Standalone Dart analysis below checks only the proposed declarations and example together.

The reviewer received the frozen criteria, final PRD/ADR/index, research/plan/tasks/evidence artifacts and validation rubric. Prior review contents, author conversation and STATE decisions were not read. Existing review and STATE paths were checked only for link existence. This report is new review output; the index snapshot checked below predates its creation.

## Verification performed

All commands below ran from the repository root on 2026-09-19. No runtime source was edited.

### Wiki lint

Command: `python3 tool/lint_wiki.py`

```text
lint_wiki: clean (0 warning(s)).
```

Exit code: 0. This is the submitted-document snapshot before this review report was created.

### Standalone proposed API consistency

Command:

```sh
python3 - <<'PY'
from pathlib import Path
import re
s=Path('wiki/product/local-voice-agent-prd.md').read_text()
blocks=re.findall(r'```dart\n(.*?)\n```',s,re.S)
p=Path('/private/tmp/local_voice_agent_validator_api.dart')
p.write_text('\n\n'.join(blocks)+'\n')
print(f'Extracted {len(blocks)} Dart blocks to {p}')
PY
```

Output, exit code 0:

```text
Extracted 2 Dart blocks to /private/tmp/local_voice_agent_validator_api.dart
```

Command: `/Users/ortalcohen/flutter/bin/cache/dart-sdk/bin/dart --version`

```text
Dart SDK version: 3.10.3 (stable) (Tue Dec 2 01:04:53 2025 -0800) on "macos_arm64"
```

Command: `/Users/ortalcohen/flutter/bin/cache/dart-sdk/bin/dart analyze --fatal-infos --fatal-warnings /private/tmp/local_voice_agent_validator_api.dart`

```text
Analyzing local_voice_agent_validator_api.dart...
No issues found!
```

Both exit codes: 0. This cached language toolchain does not establish compliance with the repository's newer SDK requirement or compile a native backend.

### Document structure and negative plan mutation

Command:

```sh
python3 - <<'PY'
from pathlib import Path
import re
w=Path('wiki/work/0001-local-voice-agent-architecture')
files=[w/'00-research.md',w/'01-plan.md',w/'02-criteria.md',w/'03-tasks.md',w/'04-verification.md',*sorted((w/'research').glob('*.md')),Path('wiki/product/local-voice-agent-prd.md'),Path('wiki/adr/0001-offline-voice-architecture.md')]
index=Path('wiki/INDEX.md').read_text()
count=0
for p in files:
    assert str(p.relative_to('wiki')) in index, f'Unindexed: {p}'
    for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
        if target.startswith(('https://','http://','#')): continue
        target=target.split('#')[0]
        assert (p.parent/target).exists(), f'Broken: {p}: {target}'
        count+=1
plan=(w/'01-plan.md').read_text()
assert not re.search(r'^\s*(```|~~~)',plan,re.M)
assert len(re.findall(r'^# Chapter [1-5]',files[-2].read_text(),re.M)) == 5
assert re.search(r'^\s*(```|~~~)',plan+'\n```dart\ninvalid\n```\n',re.M)
print(f'PASS: {len(files)} allowed deliverable documents indexed; {count} local links exist; five PRD chapters; prose-only plan.')
print('PASS negative inspection: adding a fenced block to an in-memory plan copy is detected; no repository file modified.')
PY
```

Output, exit code 0:

```text
PASS: 10 allowed deliverable documents indexed; 15 local links exist; five PRD chapters; prose-only plan.
PASS negative inspection: adding a fenced block to an in-memory plan copy is detected; no repository file modified.
```

Command:

```sh
python3 - <<'PY'
from pathlib import Path
import re
index=Path('wiki/INDEX.md')
checked=0
for target in re.findall(r'\]\(([^)]+)\)', index.read_text()):
    if target.startswith(('https://','http://','#')): continue
    assert (index.parent/target.split('#')[0]).exists(), target
    checked+=1
print(f'PASS: all {checked} existing wiki index link targets exist (contents of prior reviews and STATE not read).')
PY
```

Output, exit code 0:

```text
PASS: all 27 existing wiki index link targets exist (contents of prior reviews and STATE not read).
```

### Primary-source spot checks

The reviewer independently opened four cited primary sources with the web tool on 2026-09-19 and inspected the relevant returned text. These are selective evidence checks, not an exhaustive source crawl or legal opinion.

- [Moonshine LICENSE](https://github.com/moonshine-ai/moonshine/blob/main/LICENSE): returned source lines 647-679 distinguish the MIT streaming STT models from the exhaustively named legacy non-streaming exceptions. This supports the distinction at PRD line 79.
- [Google MediaPipe LLM guide](https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference): returned source lines 110-114 identify maintenance-only status and migration to LiteRT-LM. This supports PRD line 92 and the research supplement.
- [Android 17 background audio](https://developer.android.com/about/versions/17/changes/bg-audio): returned source lines 55-59 distinguish all-app background restrictions from the additional API-37 requirements and identify possible silent playback failure. This supports the bounded platform statement at PRD line 495; no release or device validation was inferred.
- [Dart NativeCallable.listener](https://api.dart.dev/dart-ffi/NativeCallable/NativeCallable.listener.html): returned source lines 14-20 require asynchronous argument lifetime through completion and prohibit calls after close. This supports PRD line 459 and the shutdown ordering.

## Per-criterion results

Negative cases below are adversarial document traces, as required for this documentation-only work. They are not claims of executed SDK runtime tests. `PRD` refers to `wiki/product/local-voice-agent-prd.md`.

| Criterion | Verdict | Positive evidence | Negative-case inspection and result |
|---|---|---|---|
| AC-001 | PASS | PRD:44-116 compares VAD, STT, runtime and TTS families with explicit selection/tradeoffs. `00-research.md:52-63` lists unresolved decisions and dated source registers; `research/intelligence-tts.md:86-98` carries current migration/callback/licensing boundaries. The spot checks above independently support key claims. | Challenged the inference that runtime openness grants voice redistribution or establishes a universal latency winner. PRD:44,59,116 expressly reject those inferences. Weight/runtime/phonemizer distinctions remain explicit; proposed choices are not fabricated benchmark results. |
| AC-002 | PASS | PRD:120-124 separates control/data paths and worker ownership; PRD:168-200 specifies formats, stateful resampling, SPSC ownership, bounds and backpressure; PRD:202-206 defines timing intervals. | Traced full capture ring, full render ring and paused Dart listener: PRD:178,184-185,190,200,361 drop/mark/reset capture safely, wait only off the callback, reserve cancellation delivery and prohibit unbounded listener buffering. PRD:497 expressly rejects real-time callback waits on Dart/inference. |
| AC-003 | PASS | PRD:210-227 describes lifecycle and turn transitions; PRD:233-235 separates immediate output generation gating from eventual cancellation; PRD:465-479 defines owners and quiescent release. | Traced a cancelled TTS worker finishing after a new turn, route loss during playback and shutdown with an active callback. PRD:227,235 rejects stale generations; PRD:221-222 suspends/revalidates; PRD:459,475-477 prohibits freeing referenced memory or closing live callbacks. A hung worker produces visible failure/quarantine rather than successful disposal. |
| AC-004 | PASS | PRD:241 labels the interface as proposed; PRD:243-357 declares all example-facing types/members; PRD:359-367 defines initialization, errors and event behavior; PRD:373-448 demonstrates local setup, subscription, start, interrupt and cleanup. Standalone fatal analysis returned no issues. | Traced create failure, start failure and disposal failure. PRD:363 requires create unwinding; PRD:436-445 always attempts both subscription cancellations even if disposal throws. PRD:15,241,371 prevents interpreting a nonexistent manifest or proposed factory as a shipped export. |
| AC-005 | PASS | PRD:491-509 covers microphone authorization, Android focus/foreground services, iOS session/interruption policy, private routes and thermal response with primary links. The Android-17 spot check confirms the cited restriction distinction. | Challenged a background start without continuing authorization, headset loss and unavailable full duplex. PRD:493-505 limits background behavior and suspends private output; PRD:233,453 requires explicit capability failure rather than unconditional duplex or background promises. PRD:29,82 excludes cloud fallback. |
| AC-006 | PASS | PRD:517-545 defines qualification, MVP, streaming/duplex and release deliverables with exit gates. PRD:549-566 supplies unit/integration/device/adversarial coverage and a reproducible cold/warm/endurance methodology. | Challenged using desktop success or target budgets as mobile proof. PRD:523,545 requires physical platform evidence and distinguishes host builds/dry-runs; PRD:206,570 explicitly labels numerical aspirations and ceilings unverified. PRD:562 requires reporting failures, preventing success-only latency summaries. |
| AC-007 | PASS | PRD:25-32 states offline initialization/inference, local provisioning and retention; PRD:90,101,374-385 makes deterministic logic sufficient; PRD:483-489 describes hashes, provenance, license inventory and safe activation. | Traced fresh install without assets, corrupt import, untrusted manifest and absent system voice. PRD:29,110,487 requires explicit failure and rejects hidden download/fallback; hashes are explicitly distinguished from authenticity. PRD:30 separates optional host downloads from the SDK/reference offline test. No LLM is required. |
| AC-008 | PASS | `wiki/INDEX.md:43-61` directly links the PRD, ADR, research, plan, criteria, tasks, reviews and evidence; all 27 index targets existed at inspection. The plan is prose-only; wiki lint and the independent local-link/five-chapter check passed with output above. | The in-memory fenced-plan mutation was detected. PRD:13-15 rejects an implemented-SDK interpretation. `04-verification.md:9-27` exposes the actual failed repository Dart attempts instead of calling them successful; its standalone-analysis section preserves the narrower boundary. |

## Findings and severities

No BLOCKER, IMPORTANT or NIT findings in the submitted documentation.

External verification boundary: `wiki/work/0001-local-voice-agent-architecture/04-verification.md:9-27` records the pre-existing SDK-cache permission failure and older cached Dart. This reviewer did not reproduce the repository format/analyzer commands or reinterpret their recorded exit-1 outputs as success. This is not an unmet documentation criterion: `02-criteria.md` explicitly excludes SDK runtime implementation and separates the attempted repository checks from document quality.

Model redistribution, platform floor/device selection, acoustic behavior and benchmark targets remain future product gates, explicitly listed at PRD:572-580. They are neither approved nor demonstrated by this review.

## Recurrence check

First implementation-review round. There is no prior implementation verdict to re-check and no recurrence assessment. The reviewer reports this verdict once and does not propose or apply repairs.

## Post-report formatting check

Mechanical report-format correction only: removed work-item frontmatter and renamed the two existing headings to the repository-required names. Verdict, evidence and findings remain unchanged; no second review was performed.

Command: `python3 tool/lint_wiki.py`

```text
lint_wiki: clean (0 warning(s)).
```

Exit code: 0.
