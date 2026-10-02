# Research review — round 01

- Work item: 0011-example-conversation-activity
- Reviewed artifact: `wiki/work/0011-example-conversation-activity/00-research.md`, plus its three streams `research/example-ui.md`, `research/agent-events.md` and `research/product-constraints.md`
- Reviewer: independent research validator
- Date: 2026-10-02

## Verdict

**CONDITIONAL**

The research is substantially accurate — the great majority of its `file:line` citations resolve to exactly the code they claim — but one stream states an enum enumeration that the source contradicts and that a sibling stream contradicts, the synthesis drops two stream-level unresolved questions without resolving or scoping them, and the options table omits a materially different alternative, so the named findings must close or be recorded before the research is relied on further.

## Verification performed

### Wiki lint

```
$ cd /Users/ortalcohen/Documents/GitHub/flutter_local_voice_agent && python3 tool/lint_wiki.py; echo "exit=$?"
lint_wiki: clean (0 warning(s)).
exit=0
```

Run twice: once before this report existed and once after it was written. Both runs produced the output above.

### Enum values actually declared in `lib/src/models.dart`

```
$ rg -n "^  (initializing|ready|running|suspended|stopping|failed|disposed|idle|listening|recognizing|thinking|speaking|interrupting|state|partialTranscript|finalTranscript|replyText|fault)," lib/src/models.dart
15:  initializing,
18:  ready,
21:  running,
24:  suspended,
27:  stopping,
30:  failed,
33:  disposed,
39:  idle,
42:  listening,
45:  recognizing,
48:  thinking,
51:  speaking,
54:  interrupting,
60:  state,
63:  partialTranscript,
66:  finalTranscript,
69:  replyText,
72:  fault,
```

`AgentLifecycle` has seven values and `TurnActivity` has six. This confirms `research/agent-events.md:20` and contradicts `research/example-ui.md:29`.

### Spot-check: the raw enum status string and the fault branch

```
$ sed -n '579,595p' example/lib/voice_screen_controller.dart
  void _handleAgentEvent(AgentEvent event) {
    if (_disposed) return;
    debugPrint(
      'FLVA UI event kind=${event.kind.name} activity=${event.activity.name} textLength=${event.text?.length ?? 0}',
    );
    status = '${event.lifecycle.name} · ${event.activity.name}';
    if (event.kind == AgentEventKind.partialTranscript ||
        event.kind == AgentEventKind.finalTranscript) {
      heard = event.text ?? '';
    }
    if (event.kind == AgentEventKind.replyText) reply = event.text ?? '';
    if (event.failure != null) {
      phase = ExampleSetupPhase.failed;
      status =
          'The on-device speech engine reported a problem. Stop and retry.';
    }
    _notify();
  }
```

Confirms the status format at `:584`, the transcript routing at `:585-589` and the fault branch at `:590-594`, as claimed in `00-research.md:15-16` and `research/agent-events.md:84-86, 90, 96`.

### Spot-check: the unused Start success sentence

```
$ sed -n '476,491p' example/lib/voice_screen_controller.dart
  Future<void> start() => _runSession(
    (session) => session.start(),
    success: 'Listening. Say “hello”, “what is your name?”, or “thank you”.',
    stopAfterStaleCompletion: true,
    overwriteStatus: false,
  );

  Future<void> interrupt() => _runSession(
    (session) => session.interrupt(),
    success: 'Interrupted. The microphone will listen for the next turn.',
  );

  Future<void> stop() => _runSession(
    (session) => session.stop(),
    success: 'Stopped. Tap Start when you want to continue.',
  );
```

Confirms `00-research.md:21-23` and `research/example-ui.md:41`: the listening sentence exists at `:478` and is suppressed by `overwriteStatus: false` at `:480`.

### Spot-check: the agent assigns activity without emitting an event

```
$ sed -n '258,260p;289,292p' lib/src/agent.dart
      _started = true;
      lifecycle = AgentLifecycle.running;
      activity = TurnActivity.listening;
  Future<void> interrupt() async {
    _live();
    _advanceGeneration();
    activity = TurnActivity.interrupting;
```

```
$ sed -n '662,670p' lib/src/agent.dart
TurnActivity? _activity(String v) => switch (v) {
  'idle' => TurnActivity.idle,
  'listening' => TurnActivity.listening,
  'recognizing' => TurnActivity.recognizing,
  'thinking' => TurnActivity.thinking,
  'speaking' => TurnActivity.speaking,
  'interrupting' => TurnActivity.interrupting,
  _ => null,
};
```

Confirms `00-research.md:27` and `research/agent-events.md:49-50, 52, 64`: `listening` at `:260` and `interrupting` at `:292` are field writes with no `_events.add`, and the parser maps all six activity names.

### Spot-check: `AgentLifecycle.initializing` is unreferenced

```
$ rg -n "AgentLifecycle.initializing" --glob '*.dart' --glob '*.kt' --glob '*.swift' --glob '*.cc' --glob '*.cpp' --glob '*.h' --glob '*.js' --glob '*.md'
wiki/work/0011-example-conversation-activity/research/agent-events.md:41:  - A repo-wide grep for `AgentLifecycle.initializing` over `*.dart, *.kt, *.swift, *.cc, *.cpp, *.h, *.js, *.md` found no reference.
```

The only hit is the research note itself. Confirms `research/agent-events.md:41`.

### Spot-check: the test-locked widget assertions

```
$ sed -n '26,38p' example/test/voice_screen_test.dart
    expect(find.text('English voice model'), findsOneWidget);
    expect(find.text('Speaker'), findsNothing);
    expect(find.textContaining('Three English options'), findsOneWidget);
    expect(find.textContaining('VCTK is a speaker choice'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.textContaining('fixed demo rules'), findsOneWidget);
    expect(find.text('Files, sources, and licenses'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.byKey(const Key('start-button')),
    );
    expect(start.onPressed, isNull);
```

Every line cited in `research/example-ui.md:58-59` resolves exactly, including the `FilledButton` cast at `:35-38`.

### Spot-check: the fake session interface and the absence of event coverage

```
$ sed -n '549,580p' example/test/voice_screen_controller_test.dart
final class _FakeSession implements ExampleVoiceSession {
  final StreamController<AgentEvent> _events = StreamController<AgentEvent>();
  final Completer<void> startCompleter = Completer<void>();
  final List<int> setSpeakerIds = <int>[];
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<AgentEvent> get events => _events.stream;

  @override
  Future<void> start() => startCompleter.future;

  @override
  Future<void> interrupt() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _events.close();
  }

  @override
  Future<void> setSpeakerId(int speakerId) async {
    setSpeakerIds.add(speakerId);
  }
}
```

Confirms `research/example-ui.md:82` and `00-research.md:33`: the fake implements exactly `events`, `start`, `interrupt`, `stop`, `dispose` and `setSpeakerId`, and nothing adds to `_events`.

### Spot-check: product-constraint sources

```
$ sed -n '20,22p;24,28p' doc/capabilities.md
| Half duplex | Foreground default; speech admission pauses during response |
| Full duplex / speech barge-in | Unsupported; no AEC qualification claimed |
| Manual interruption | Generation invalidation plus platform playback flushing where supported |
| Background / wake word | Unsupported; session suspends in background |
| Route change | Suspend; iOS changed input rate requires recreate |
| Thermal | Severe/serious system signal suspends; adaptive model tuning not implemented |
| Emulator verification | Android catalog download/cancel/retry, native listening state and offline restart observed; no physical speech/audio qualification |
| Device measurements | No physical Android/iPhone qualification |
```

```
$ sed -n '60,61p;180,181p' README.md
| Background / wake word | Unsupported |
| Full duplex / barge-in | Unsupported |
the microphone, and try “hello”, “what is your name”, or “thank you”. These
are fixed local demo replies, not a general-purpose LLM conversation.
```

Every capability-table and README citation in `research/product-constraints.md:19, 31, 36, 42` resolves to the stated text, including the README-versus-example question-mark difference recorded at `:109`.

### Staleness of the cited wiki source

```
$ head -9 wiki/product/example-model-catalog.md
---
id: example-model-catalog
title: Selectable speech models in the example
status: active
owner: root
last_verified: 2026-09-21
applies_to: ["lib/src/model_catalog.dart", "example/**", "doc/model-catalog.md"]
summary: Three pinned English speech bundles, VCTK integer speaker ids, explicit first download and private offline reuse in the example.
---
```

`last_verified: 2026-09-21` is eleven days old, well inside the 180-day lint warning threshold set at `wiki/conventions/naming.md:55`. No cited wiki source is stale.

### Off-by-one citation checks

```
$ rg -n "One agent API" README.md
38:- **One agent API:** `create`, `start`, `interrupt`, `stop`, `dispose`
```

```
$ sed -n '236,238p' example/lib/main.dart | cat -n
     1	            const Text(
     2	              'Replies are fixed demo rules, not an LLM. Try “hello”, “what is your name?”, or “thank you”.',
     3	            ),
```

```
$ sed -n '152,155p' lib/src/agent.dart | cat -n
     1	    final agent = LocalVoiceAgent._(session, logic, outputRate, speakerId);
     2	    agent._events = BoundedEventStream<AgentEvent>(
     3	      capacity: 32,
     4	      terminalValue: () => AgentEvent(
```

```
$ sed -n '396,399p' lib/src/agent.dart | cat -n
     1	        );
     2	      }
     3	      if (_disposed || !_started || epoch != _epoch) return;
     4	      for (final value in values) {
```

The agent API list is at `README.md:38`, the demo-rules sentence at `example/lib/main.dart:237`, `capacity: 32` at `lib/src/agent.dart:154` and the second poll guard at `lib/src/agent.dart:398`. See F-005.

## Per-criterion results

Not applicable. Per `wiki/conventions/validation-rubrics.md:42`, per-criterion verdicts are required of implementation reviews. `02-criteria.md` is read here only to judge whether the research supports the criteria that were drawn from it; no criterion is adjudicated against code in this round.

## Findings

### F-001 — Stream states an incomplete enum enumeration that the source and a sibling stream contradict

- Severity: IMPORTANT
- Location: `wiki/work/0011-example-conversation-activity/research/example-ui.md:29`
- Criterion affected: AC-003, AC-006, AC-015
- Observation: The stream claims `TurnActivity` has `idle`, `listening`, `recognizing`, `thinking`, `speaking` at `lib/src/models.dart:37-51`, and that `AgentLifecycle` has `initializing`, `ready`, `running`, `suspended`, `stopping` at `lib/src/models.dart:13-27`. The source declares `TurnActivity.interrupting` at `lib/src/models.dart:54`, `AgentLifecycle.failed` at `:30` and `AgentLifecycle.disposed` at `:33`. Both cited ranges stop before the end of their enum, so each enumeration is presented as complete while omitting the trailing values. `research/agent-events.md:20-22` states the correct counts — seven lifecycle values and six activity values — so the two streams disagree, and `00-research.md` does not record or reconcile the disagreement anywhere in its Findings, Options considered or Unresolved sections.
- Why it matters: The research is the input that downstream phases map over. `02-criteria.md` AC-003 requires an exact sentence for `interrupting`, AC-015 requires `interrupting` behavior after the Interrupt control, and AC-006 depends on the `failed` path. A reader working from the UI stream alone would build a mapping missing `interrupting` and would not know that `failed` and `disposed` exist and need a fallback, which is precisely the gap an exhaustive activity-to-sentence mapping must not have.

### F-002 — Options considered omits the event-kind-driven alternative

- Severity: IMPORTANT
- Location: `wiki/work/0011-example-conversation-activity/00-research.md:43-50`
- Criterion affected: none
- Observation: The options table evaluates four approaches, all of which derive the displayed text from `TurnActivity` (or decline to change anything, or move the work into `lib/`). It does not consider driving the plain-English copy from `AgentEvent.kind`, which the same research establishes the example already receives and already acts on: `research/example-ui.md:27` and `research/agent-events.md:90` record that `partialTranscript` and `finalTranscript` set `heard` and `replyText` sets `reply`. This matters because the research simultaneously records, at `00-research.md:66` and in the activity rows of the per-value table at `research/agent-events.md:141-145`, that whether native ever sends `recognizing`, `thinking`, `speaking` or `interrupting` is `[UNVERIFIED]`. The chosen option therefore rests its main user-visible behavior on values whose arrival the research does not establish, and the one alternative built on values the research does establish is never stated or rejected.
- Why it matters: An options table is the record of why the chosen approach beat the others. Omitting the alternative that avoids the artifact's own central uncertainty means the trade-off was never made explicit, so a later phase cannot tell whether it was considered and rejected on merit or simply not seen.

### F-003 — Synthesis drops two stream-level unresolved questions without resolving or scoping them

- Severity: IMPORTANT
- Location: `wiki/work/0011-example-conversation-activity/00-research.md:64-67`
- Criterion affected: AC-015
- Observation: The synthesis carries forward two unresolved items, both drawn from the native-activity question. Two further unresolved items raised by the streams appear in neither the Unresolved section, the Findings, nor the Constraints discovered section, and no other stream resolves them. `research/agent-events.md:160` asks whether the native layer sends a `state` event immediately after `start`, which it says "decides whether the post-Start status gap is brief or long". `research/product-constraints.md:116` asks whether the Interrupt button has any effect when nothing is playing, noting the example enables it whenever a session exists. Neither question is answered elsewhere in the research: no stream read native sources, and `research/agent-events.md:50, 64` confirms only that `interrupt()` sets the Dart field and emits no event.
- Why it matters: `02-criteria.md` AC-015 commits the Interrupt control to writing the same "Listening. Say…" sentence the Start path writes, on the sole basis that the interrupt call returned without throwing. That commitment depends on the dropped `product-constraints.md:116` question. An unresolved question that disappears between a stream and the synthesis stops being visible to the phases that inherit the risk.

### F-004 — Sources section omits a wiki document the research relies on

- Severity: NIT
- Location: `wiki/work/0011-example-conversation-activity/00-research.md:69-74`
- Criterion affected: none
- Observation: The Sources section lists `example/lib/main.dart`, `example/lib/voice_screen_controller.dart`, the two example test files, `lib/src/agent.dart`, `lib/src/models.dart`, `README.md`, `doc/capabilities.md` and `doc/model-catalog.md`. It does not list `wiki/product/example-model-catalog.md`, although `research/product-constraints.md` cites it at `:37`, `:43`, `:55`, `:67`, `:98`, `:100` and `:108` as evidence for load-bearing constraints including "Backgrounding cancels preparation and stops listening" and "Failed setup cannot enable Start". The Findings entry that carries those constraints, `00-research.md:39-41`, likewise names only `main.dart`, `README.md`, `doc/capabilities.md` and `doc/model-catalog.md` in its Evidence line.
- Why it matters: The Sources list is what a later reader re-verifies against when checking whether the research has gone stale. A source that supplied constraints but is absent from the list will not be re-checked.

### F-005 — Several citations are off by one line

- Severity: NIT
- Location: `wiki/work/0011-example-conversation-activity/research/product-constraints.md:31`, `:109`; `wiki/work/0011-example-conversation-activity/research/agent-events.md:71`, `:152`
- Criterion affected: none
- Observation: Four citations name a line adjacent to the one holding the quoted content. `product-constraints.md:31` cites `README.md:37` for the public API list, which is at `README.md:38`. `product-constraints.md:109` cites `example/lib/main.dart:238` for the “what is your name?” phrase, which is at `example/lib/main.dart:237` (`:238` is the closing parenthesis). `agent-events.md:152` cites `lib/src/agent.dart:152-153` for the capacity-32 bound, which is at `lib/src/agent.dart:154`. `agent-events.md:71` cites `lib/src/agent.dart:397` for the second started-and-epoch poll guard, which is at `lib/src/agent.dart:398` (`:397` is a closing brace). Every quoted claim is true of the file; only the line number is adjacent. Spot-checks of roughly sixty other citations across the four artifacts — including all of the `example/test/` citations, the controller status-assignment lines `:144`, `:270-271`, `:319`, `:349`, `:442`, `:540`, `:552`, the `main.dart` widget lines, and the `lib/src/agent.dart` lifecycle and activity assignment lines — resolved exactly.
- Why it matters: `wiki/conventions/validation-rubrics.md:40` makes a file and a line the unit of actionable evidence. A line that lands on a brace costs the next reader a search and weakens confidence in the citations that are correct.

## Recurrence check

- Previous round: none — first round
- Recurring findings: none
- Oscillating: no

## Routing

| Finding | Belongs to phase |
|---|---|
| F-001 | research |
| F-002 | research |
| F-003 | research |
| F-004 | research |
| F-005 | research |
