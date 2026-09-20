import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

import 'agent_test.dart' as fixtures;

void main() {
  for (final invalid in <(String, String)>[
    ('empty', ''),
    ('embedded NUL', 'before\u0000after'),
    ('unpaired high surrogate', String.fromCharCode(0xD800)),
    ('unpaired low surrogate', String.fromCharCode(0xDC00)),
  ]) {
    test(
      '${invalid.$1} logic reply faults and permits the next turn',
      () async {
        final replies = <String>[invalid.$2, 'recovered'];
        final native = _ReplyPlatform();
        final agent = await _createAgent(
          native,
          (_) async => replies.removeAt(0),
        );
        final events = <AgentEvent>[];
        final subscription = agent.events.listen(events.add);

        native.addFinal(sequence: 1, generation: 0, text: 'invalid turn');
        await _waitForEvent(
          events,
          (event) => event.kind == AgentEventKind.finalTranscript,
        );
        final fault = await _waitForEvent(
          events,
          (event) => event.kind == AgentEventKind.fault,
        );

        expect(fault.failure?.code, AgentErrorCode.inferenceFailed);
        expect(fault.failure?.fatal, isFalse);
        expect(native.replies, isEmpty);
        await _waitFor(() => native.interruptCalls == 1);

        native.addFinal(sequence: 2, generation: 1, text: 'next turn');
        await _waitForEvent(
          events,
          (event) =>
              event.kind == AgentEventKind.finalTranscript &&
              event.generation == 1,
        );
        await _waitFor(() => native.replies.length == 1);

        expect(native.replies, <String>['1:recovered']);
        await subscription.cancel();
        await agent.dispose();
      },
    );
  }

  test(
    'oversized reply retains capacityExceeded and permits recovery',
    () async {
      final replies = <String>['a' * 241, 'recovered'];
      final native = _ReplyPlatform();
      final agent = await _createAgent(
        native,
        (_) async => replies.removeAt(0),
      );
      final events = <AgentEvent>[];
      final subscription = agent.events.listen(events.add);

      native.addFinal(sequence: 1, generation: 0, text: 'oversized turn');
      await _waitForEvent(
        events,
        (event) => event.kind == AgentEventKind.finalTranscript,
      );
      final fault = await _waitForEvent(
        events,
        (event) => event.kind == AgentEventKind.fault,
      );

      expect(fault.failure?.code, AgentErrorCode.capacityExceeded);
      expect(native.replies, isEmpty);
      await _waitFor(() => native.interruptCalls == 1);

      native.addFinal(sequence: 2, generation: 1, text: 'next turn');
      await _waitForEvent(
        events,
        (event) =>
            event.kind == AgentEventKind.finalTranscript &&
            event.generation == 1,
      );
      await _waitFor(() => native.replies.length == 1);

      expect(native.replies, <String>['1:recovered']);
      await subscription.cancel();
      await agent.dispose();
    },
  );

  test(
    '240 supplementary Unicode scalars and 960 UTF-8 bytes are accepted',
    () async {
      final reply = String.fromCharCodes(
        List<int>.filled(240, 0x1F642, growable: false),
      );
      final native = _ReplyPlatform();
      final agent = await _createAgent(native, (_) async => reply);
      final events = <AgentEvent>[];
      final subscription = agent.events.listen(events.add);

      native.addFinal(sequence: 1, generation: 0, text: 'boundary turn');
      await _waitForEvent(
        events,
        (event) => event.kind == AgentEventKind.finalTranscript,
      );
      await _waitFor(() => native.replies.length == 1);

      expect(native.replies.single, '0:$reply');
      expect(
        events.where((event) => event.kind == AgentEventKind.fault),
        isEmpty,
      );
      expect(native.interruptCalls, 0);
      await subscription.cancel();
      await agent.dispose();
    },
  );
}

Future<LocalVoiceAgent> _createAgent(
  _ReplyPlatform native,
  LocalReplyLogic logic,
) async {
  final root = await fixtures.fixtureFixture();
  addTearDown(() => root.delete(recursive: true));
  final agent = await LocalVoiceAgent.create(
    models: LocalModelBundle(
      directory: root.path,
      manifestPath: '${root.path}/manifest.json',
    ),
    nativePlatform: native,
    logic: logic,
  );
  await agent.start();
  return agent;
}

Future<AgentEvent> _waitForEvent(
  List<AgentEvent> events,
  bool Function(AgentEvent event) matches,
) async {
  await _waitFor(() => events.any(matches));
  return events.firstWhere(matches);
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for asynchronous agent behavior.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

final class _ReplyPlatform implements NativeVoicePlatform {
  final List<Map<String, Object?>> _events = <Map<String, Object?>>[];
  final List<String> replies = <String>[];
  int interruptCalls = 0;

  void addFinal({
    required int sequence,
    required int generation,
    required String text,
  }) {
    _events.add(<String, Object?>{
      'sequence': sequence,
      'generation': generation,
      'kind': 'final',
      'activity': 'thinking',
      'text': text,
    });
  }

  @override
  Future<int> create({
    required Map<String, String> paths,
    required String mode,
  }) async => 24000;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> interrupt() async {
    interruptCalls++;
  }

  @override
  Future<List<Map<String, Object?>>> poll() async {
    final result = List<Map<String, Object?>>.of(_events);
    _events.clear();
    return result;
  }

  @override
  Future<void> reply({required int generation, required String text}) async {
    replies.add('$generation:$text');
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
