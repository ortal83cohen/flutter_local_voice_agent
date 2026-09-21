import 'package:flutter/services.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

import 'agent_test.dart' as fixtures;

class FailingPlatform implements NativeVoicePlatform {
  String? fail;
  List<Map<String, Object?>> next = [];
  int stops = 0;
  void check(String operation) {
    if (fail == operation) throw PlatformException(code: 'inferenceFailed');
  }

  @override
  Future<int> create({
    required Map<String, String> paths,
    required String mode,
    required int speakerId,
  }) async => 22050;
  @override
  Future<void> start() async => check('start');
  @override
  Future<void> stop() async {
    stops++;
    check('stop');
  }

  @override
  Future<void> interrupt() async => check('interrupt');
  @override
  Future<void> dispose() async => check('dispose');
  @override
  Future<void> reply({required int generation, required String text}) async {}
  @override
  Future<void> setSpeakerId(int speakerId) async {}
  @override
  Future<List<Map<String, Object?>>> poll() async {
    final result = next;
    next = [];
    return result;
  }
}

void main() {
  Future<LocalVoiceAgent> create(
    FailingPlatform platform, {
    LocalReplyLogic? logic,
  }) async {
    final root = await fixtures.fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    return LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: root.path,
        manifestPath: '${root.path}/manifest.json',
      ),
      nativePlatform: platform,
      logic: logic,
    );
  }

  for (final operation in ['start', 'stop', 'interrupt', 'dispose']) {
    test(
      '$operation exposes typed platform failure and permits cleanup',
      () async {
        final native = FailingPlatform();
        final agent = await create(native);
        if (operation != 'start') await agent.start();
        native.fail = operation;
        final action = switch (operation) {
          'start' => agent.start,
          'stop' => agent.stop,
          'interrupt' => agent.interrupt,
          _ => agent.dispose,
        };
        await expectLater(action(), throwsA(isA<AgentFailure>()));
        if (operation == 'stop' || operation == 'dispose') {
          expect(agent.lifecycle, AgentLifecycle.failed);
        }
        native.fail = null;
        await agent.dispose();
        await agent.dispose();
        expect(agent.lifecycle, AgentLifecycle.disposed);
      },
    );
  }
  test(
    'automatic stop failure is delivered without an unhandled future',
    () async {
      final native = FailingPlatform()
        ..fail = 'stop'
        ..next = [
          {
            'sequence': 1,
            'generation': 0,
            'kind': 'error',
            'activity': 'idle',
            'code': 'inferenceFailed',
          },
        ];
      final agent = await create(native);
      final events = <AgentEvent>[];
      final subscription = agent.events.listen(events.add);
      await agent.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(agent.lifecycle, AgentLifecycle.failed);
      expect(native.stops, 1);
      expect(
        events.where((event) => event.failure != null).length,
        greaterThanOrEqualTo(2),
      );
      native.fail = null;
      await agent.dispose();
      await subscription.cancel();
    },
  );
  test('logic error handles a failed background interrupt', () async {
    final native = FailingPlatform()
      ..fail = 'interrupt'
      ..next = [
        {
          'sequence': 1,
          'generation': 0,
          'kind': 'final',
          'activity': 'thinking',
          'text': 'hello',
        },
      ];
    final agent = await create(
      native,
      logic: (_) async => throw StateError('logic failure'),
    );
    await agent.start();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(agent.lifecycle, AgentLifecycle.failed);
    expect(native.stops, 1);
    native.fail = null;
    await agent.dispose();
  });
}
