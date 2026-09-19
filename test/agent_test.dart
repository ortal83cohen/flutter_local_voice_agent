import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_local_voice_agent/src/bounded_stream.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'final transcript invokes logic and sends current-generation reply',
    () async {
      final root = await fixtureFixture();
      addTearDown(() => root.delete(recursive: true));
      final native = _FakePlatform()
        ..next = <Map<String, Object?>>[
          <String, Object?>{
            'sequence': 1,
            'generation': 0,
            'kind': 'final',
            'activity': 'thinking',
            'text': 'hello',
          },
        ];
      final agent = await LocalVoiceAgent.create(
        models: LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
        nativePlatform: native,
        logic: (text) async => 'reply:$text',
      );
      await agent.start();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(native.replies, <String>['0:reply:hello']);
      expect(
        native.paths['vad'],
        '${await root.resolveSymbolicLinks()}${Platform.pathSeparator}vad',
      );
      await agent.dispose();
    },
  );

  test('full duplex is rejected before platform create', () async {
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakePlatform();
    await expectLater(
      LocalVoiceAgent.create(
        models: LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
        nativePlatform: native,
        mode: ConversationMode.fullDuplexRequired,
      ),
      throwsA(isA<AgentFailure>()),
    );
    expect(native.created, isFalse);
  });

  test('concurrent start and dispose share native operations', () async {
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakePlatform()..startGate = Completer<void>();
    final agent = await LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: root.path,
        manifestPath: '${root.path}/manifest.json',
      ),
      nativePlatform: native,
    );
    final one = agent.start();
    final two = agent.start();
    expect(identical(one, two), isTrue);
    native.startGate!.complete();
    await one;
    final disposeOne = agent.dispose();
    final disposeTwo = agent.dispose();
    expect(identical(disposeOne, disposeTwo), isTrue);
    await disposeOne;
    expect(native.startCalls, 1);
    expect(native.disposeCalls, 1);
  });

  test('suspension ignores a late logic reply', () async {
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final logic = Completer<String>();
    final native = _FakePlatform()
      ..next = <Map<String, Object?>>[
        <String, Object?>{
          'sequence': 1,
          'generation': 0,
          'kind': 'final',
          'activity': 'thinking',
          'text': 'hello',
        },
        <String, Object?>{'kind': 'suspended', 'code': 'routeLost'},
      ];
    final agent = await LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: root.path,
        manifestPath: '${root.path}/manifest.json',
      ),
      nativePlatform: native,
      logic: (_) => logic.future,
    );
    await agent.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    logic.complete('late');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(native.replies, isEmpty);
    expect(agent.lifecycle, AgentLifecycle.suspended);
    await agent.dispose();
  });

  test('interrupt keeps polling and admits the next current final', () async {
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final native = _FakePlatform();
    final agent = await LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: root.path,
        manifestPath: '${root.path}/manifest.json',
      ),
      nativePlatform: native,
      logic: (text) async => text,
    );
    await agent.start();
    await agent.interrupt();
    native.next = <Map<String, Object?>>[
      <String, Object?>{
        'sequence': 2,
        'generation': 1,
        'kind': 'final',
        'activity': 'thinking',
        'text': 'next',
      },
    ];
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(native.replies, <String>['1:next']);
    await agent.dispose();
  });

  test('late poll response after dispose is ignored', () async {
    final root = await fixtureFixture();
    addTearDown(() => root.delete(recursive: true));
    final gate = Completer<List<Map<String, Object?>>>();
    final native = _FakePlatform()..pollGate = gate;
    final agent = await LocalVoiceAgent.create(
      models: LocalModelBundle(
        directory: root.path,
        manifestPath: '${root.path}/manifest.json',
      ),
      nativePlatform: native,
      logic: (_) async => 'reply',
    );
    await agent.start();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await agent.dispose();
    gate.complete(<Map<String, Object?>>[
      <String, Object?>{
        'sequence': 1,
        'generation': 0,
        'kind': 'final',
        'activity': 'thinking',
        'text': 'ignored',
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(native.replies, isEmpty);
  });

  test(
    'paused bounded delivery replaces backlog with terminal capacity fault',
    () async {
      var overflowed = false;
      final stream = BoundedEventStream<AgentEvent>(
        capacity: 2,
        onOverflow: () async {
          overflowed = true;
        },
        terminalValue: () => const AgentEvent(
          sequence: 99,
          generation: 0,
          kind: AgentEventKind.fault,
          lifecycle: AgentLifecycle.failed,
          activity: TurnActivity.idle,
          failure: AgentFailure(
            AgentErrorCode.capacityExceeded,
            'full',
            fatal: true,
          ),
        ),
      );
      final received = <AgentEvent>[];
      final subscription = stream.stream.listen(received.add);
      subscription.pause();
      stream.add(
        const AgentEvent(
          sequence: 1,
          generation: 0,
          kind: AgentEventKind.state,
          lifecycle: AgentLifecycle.running,
          activity: TurnActivity.listening,
        ),
      );
      stream.add(
        const AgentEvent(
          sequence: 2,
          generation: 0,
          kind: AgentEventKind.state,
          lifecycle: AgentLifecycle.running,
          activity: TurnActivity.listening,
        ),
      );
      stream.add(
        const AgentEvent(
          sequence: 3,
          generation: 0,
          kind: AgentEventKind.state,
          lifecycle: AgentLifecycle.running,
          activity: TurnActivity.listening,
        ),
      );
      subscription.resume();
      await Future<void>.delayed(Duration.zero);
      expect(overflowed, isTrue);
      expect(received.single.failure!.code, AgentErrorCode.capacityExceeded);
      await subscription.cancel();
      await stream.close();
    },
  );
}

Future<Directory> fixtureFixture() async {
  // Reuse the real filesystem fixture helper through its public test behavior.
  final root = await Directory.systemTemp.createTemp('flva-agent-');
  const roles = <String>[
    'vad',
    'encoder',
    'decoder',
    'joiner',
    'asrTokens',
    'ttsModel',
    'ttsTokens',
    'ttsLexicon',
    'license',
  ];
  final files = <Map<String, Object?>>[];
  for (final role in roles) {
    final file = role == 'license' ? 'LICENSE' : role;
    await File('${root.path}/$file').writeAsString(role);
    final bytes = await File('${root.path}/$file').readAsBytes();
    files.add(<String, Object?>{
      'role': role,
      'path': file,
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'source': 'fixture',
      'license': 'LICENSE',
    });
  }
  await File('${root.path}/manifest.json').writeAsString(
    '{"schema":1,"profile":"en-US-sherpa-vits","runtime":"1.12.14","inputRate":16000,"files":${jsonEncode(files)}}',
  );
  return root;
}

final class _FakePlatform implements NativeVoicePlatform {
  bool created = false;
  int startCalls = 0;
  int disposeCalls = 0;
  Completer<void>? startGate;
  Completer<List<Map<String, Object?>>>? pollGate;
  Map<String, String> paths = <String, String>{};
  List<Map<String, Object?>> next = <Map<String, Object?>>[];
  final List<String> replies = <String>[];
  @override
  Future<int> create({
    required Map<String, String> paths,
    required String mode,
  }) async {
    created = true;
    this.paths = paths;
    return 24000;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  Future<void> interrupt() async {}
  @override
  Future<List<Map<String, Object?>>> poll() async {
    if (pollGate != null) return pollGate!.future;
    final value = next;
    next = <Map<String, Object?>>[];
    return value;
  }

  @override
  Future<void> reply({required int generation, required String text}) async {
    replies.add('$generation:$text');
  }

  @override
  Future<void> start() async {
    startCalls++;
    if (startGate != null) await startGate!.future;
  }

  @override
  Future<void> stop() async {}
}
