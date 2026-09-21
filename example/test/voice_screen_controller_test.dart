import 'dart:async';

import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_voice_agent_example/model_storage.dart';
import 'package:flutter_local_voice_agent_example/voice_screen_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first launch waits for an explicit download', () async {
    final harness = _Harness();
    await harness.controller.initialize();

    expect(harness.controller.selected, VoiceModelCatalog.entries.first);
    expect(harness.controller.phase, ExampleSetupPhase.needsDownload);
    expect(harness.controller.canStart, isFalse);
    expect(harness.preparations, isEmpty);

    await harness.controller.close();
  });

  test('disk preflight blocks transfer before creating preparation', () async {
    final option = VoiceModelCatalog.entries.first;
    final harness = _Harness(
      availableBytes:
          option.downloadBytes + VoiceScreenController.diskMarginBytes - 1,
    );
    await harness.controller.initialize();
    await harness.controller.downloadAndPrepare();

    expect(harness.preparations, isEmpty);
    expect(harness.controller.phase, ExampleSetupPhase.failed);
    expect(harness.controller.status, contains('Not enough free space'));
    expect(harness.controller.canStart, isFalse);

    await harness.controller.close();
  });

  test(
    'verified cached retry bypasses fresh-download disk preflight',
    () async {
      final harness = _Harness(availableBytes: 0, installedCandidate: true);
      await harness.controller.initialize();

      final pending = harness.controller.downloadAndPrepare();
      await _flush();
      final preparation = harness.preparations.single;
      expect(preparation.allowNetwork, isFalse);
      preparation.completeReady();
      await pending;

      expect(harness.storage.availableBytesCalls, 0);
      expect(harness.controller.phase, ExampleSetupPhase.ready);
      expect(harness.controller.canStart, isTrue);

      await harness.controller.close();
    },
  );

  test(
    'explicit preparation creates a session and persists selection',
    () async {
      final harness = _Harness();
      await harness.controller.initialize();

      final pending = harness.controller.downloadAndPrepare();
      await _flush();
      final preparation = harness.preparations.single;
      expect(preparation.allowNetwork, isTrue);
      expect(preparation.root, endsWith(VoiceModelCatalog.entries.first.id));
      expect(harness.controller.operationBusy, isTrue);

      preparation.completeReady();
      await pending;

      expect(harness.controller.phase, ExampleSetupPhase.ready);
      expect(harness.controller.canStart, isTrue);
      expect(harness.storage.writtenId, VoiceModelCatalog.entries.first.id);
      expect(harness.sessions, hasLength(1));

      await harness.controller.close();
    },
  );

  test(
    'offline restoration never requests a network-enabled preparation',
    () async {
      final option = VoiceModelCatalog.entries.last;
      final harness = _Harness(savedId: option.id);

      final pending = harness.controller.initialize();
      await _flush();
      final preparation = harness.preparations.single;
      expect(preparation.option, option);
      expect(preparation.allowNetwork, isFalse);

      preparation.completeReady();
      await pending;
      expect(harness.controller.phase, ExampleSetupPhase.ready);
      expect(harness.controller.canStart, isTrue);

      await harness.controller.close();
    },
  );

  test('cancel stays busy until preparation cleanup settles', () async {
    final harness = _Harness();
    await harness.controller.initialize();

    final pending = harness.controller.downloadAndPrepare();
    await _flush();
    final preparation = harness.preparations.single;
    harness.controller.cancelPreparation();

    expect(preparation.cancelled, isTrue);
    expect(harness.controller.operationBusy, isTrue);
    expect(harness.controller.canPrepare, isFalse);

    preparation.completeCancelled();
    await pending;
    expect(harness.controller.operationBusy, isFalse);
    expect(harness.controller.phase, ExampleSetupPhase.cancelled);
    expect(harness.controller.canStart, isFalse);

    await harness.controller.close();
  });

  test('background cancels setup and ignores a late ready bundle', () async {
    final harness = _Harness();
    await harness.controller.initialize();

    final pending = harness.controller.downloadAndPrepare();
    await _flush();
    final preparation = harness.preparations.single;
    harness.controller.onBackground();

    expect(preparation.cancelled, isTrue);
    expect(harness.controller.operationBusy, isTrue);
    expect(harness.controller.phase, ExampleSetupPhase.cancelled);

    preparation.completeReady();
    await pending;
    expect(harness.sessions, isEmpty);
    expect(harness.controller.operationBusy, isFalse);
    expect(harness.controller.canStart, isFalse);

    await harness.controller.close();
  });

  test('resume recovers setup after cancellation settles', () async {
    final harness = _Harness();
    await harness.controller.initialize();
    final pending = harness.controller.downloadAndPrepare();
    await _flush();
    final preparation = harness.preparations.single;

    harness.controller.onBackground();
    harness.controller.onResume();
    preparation.completeCancelled();
    await pending;
    await _flush();

    expect(harness.controller.operationBusy, isFalse);
    expect(harness.controller.phase, ExampleSetupPhase.needsDownload);
    expect(harness.controller.selected, isNotNull);

    await harness.controller.close();
  });

  test(
    'background prevents a late start result from replacing stopped status',
    () async {
      final harness = _Harness();
      await harness.controller.initialize();
      final prepare = harness.controller.downloadAndPrepare();
      await _flush();
      harness.preparations.single.completeReady();
      await prepare;

      final session = harness.sessions.single;
      final start = harness.controller.start();
      await _flush();
      harness.controller.onBackground();
      expect(session.stopCalls, 1);
      session.startCompleter.complete();
      await start;

      expect(harness.controller.status, contains('background'));
      expect(harness.controller.operationBusy, isFalse);

      await harness.controller.close();
    },
  );

  test('pending Start remains reusable across background and resume', () async {
    final harness = _Harness();
    await harness.controller.initialize();
    final prepare = harness.controller.downloadAndPrepare();
    await _flush();
    harness.preparations.single.completeReady();
    await prepare;

    final session = harness.sessions.single;
    final start = harness.controller.start();
    await _flush();
    harness.controller.onBackground();
    expect(harness.controller.phase, ExampleSetupPhase.ready);
    expect(session.stopCalls, 1);

    harness.controller.onResume();
    session.startCompleter.complete();
    await start;

    expect(session.stopCalls, 2);
    expect(harness.controller.phase, ExampleSetupPhase.ready);
    expect(harness.controller.canStart, isTrue);
    expect(harness.controller.status, contains('Ready'));

    await harness.controller.close();
  });

  test(
    'switching models disposes the old session and reuses installed cache',
    () async {
      final harness = _Harness();
      await harness.controller.initialize();
      final prepare = harness.controller.downloadAndPrepare();
      await _flush();
      harness.preparations.single.completeReady();
      await prepare;

      final session = harness.sessions.single;
      final switchFuture = harness.controller.select(
        VoiceModelCatalog.entries.last,
      );
      await _flush();
      expect(session.disposeCalls, 1);
      final restore = harness.preparations.last;
      expect(restore.option, VoiceModelCatalog.entries.last);
      expect(restore.allowNetwork, isFalse);
      restore.completeReady();
      await switchFuture;

      expect(session.disposeCalls, 1);
      expect(harness.controller.selected, VoiceModelCatalog.entries.last);
      expect(harness.controller.speakerId, 0);
      expect(harness.controller.phase, ExampleSetupPhase.ready);

      await harness.controller.close();
    },
  );

  test('switching to a missing cache asks for explicit download', () async {
    final harness = _Harness();
    await harness.controller.initialize();

    final switching = harness.controller.select(VoiceModelCatalog.entries.last);
    await _flush();
    harness.preparations.single.completeFailure(
      ModelPreparationErrorCode.network,
    );
    await switching;

    expect(harness.controller.phase, ExampleSetupPhase.needsDownload);
    expect(harness.controller.canPrepare, isTrue);
    expect(harness.controller.allowRepairRemoval, isFalse);

    await harness.controller.close();
  });

  test(
    'integrity failure offers explicit removal and preserves other ids',
    () async {
      final harness = _Harness();
      await harness.controller.initialize();
      final pending = harness.controller.downloadAndPrepare();
      await _flush();
      harness.preparations.single.completeFailure(
        ModelPreparationErrorCode.integrity,
      );
      await pending;

      expect(harness.controller.allowRepairRemoval, isTrue);
      await harness.controller.removeDamagedCopy();
      expect(harness.storage.deletedIds, <String>[
        VoiceModelCatalog.entries.first.id,
      ]);
      expect(harness.controller.phase, ExampleSetupPhase.needsDownload);

      await harness.controller.close();
    },
  );

  test('LJS hides speakers and old catalog-id restore can start', () async {
    final option = VoiceModelCatalog.entries.first;
    final harness = _Harness(savedId: option.id, savedSpeakerId: 0);

    final pending = harness.controller.initialize();
    await _flush();
    final preparation = harness.preparations.single;
    expect(preparation.allowNetwork, isFalse);
    expect(preparation.option, option);
    preparation.completeReady();
    await pending;

    expect(option.speakerCount, 1);
    expect(harness.controller.speakerIds, isEmpty);
    expect(harness.controller.showsSpeakerControl, isFalse);
    expect(harness.controller.speakerId, 0);
    expect(harness.controller.phase, ExampleSetupPhase.ready);
    expect(harness.controller.canStart, isTrue);

    await harness.controller.close();
  });

  test('VCTK exposes speaker ids 0 through 108', () async {
    final option = VoiceModelCatalog.entries.last;
    final harness = _Harness(savedId: option.id);

    final pending = harness.controller.initialize();
    await _flush();
    harness.preparations.single.completeReady();
    await pending;

    expect(option.speakerCount, 109);
    expect(harness.controller.showsSpeakerControl, isTrue);
    expect(harness.controller.speakerIds.first, 0);
    expect(harness.controller.speakerIds.last, 108);
    expect(harness.controller.speakerIds, hasLength(109));
    expect(harness.controller.speakerIds.contains(109), isFalse);

    await harness.controller.close();
  });

  test('VCTK Start is disabled when restored speaker id is 109', () async {
    final option = VoiceModelCatalog.entries.last;
    final harness = _Harness(savedId: option.id, savedSpeakerId: 109);

    final pending = harness.controller.initialize();
    await _flush();
    harness.preparations.single.completeReady();
    await pending;

    expect(harness.controller.phase, ExampleSetupPhase.ready);
    expect(harness.controller.hasSession, isTrue);
    expect(harness.controller.speakerId, 109);
    expect(harness.controller.canStart, isFalse);

    await harness.controller.close();
  });

  test(
    'live VCTK speaker change calls setter and does not prepare again',
    () async {
      final option = VoiceModelCatalog.entries.last;
      final harness = _Harness(savedId: option.id, savedSpeakerId: 0);

      final pending = harness.controller.initialize();
      await _flush();
      harness.preparations.single.completeReady();
      await pending;

      final session = harness.sessions.single;
      final preparationCount = harness.preparations.length;
      await harness.controller.setSpeakerId(7);

      expect(session.setSpeakerIds, <int>[7]);
      expect(harness.controller.speakerId, 7);
      expect(harness.storage.writtenId, option.id);
      expect(harness.storage.writtenSpeakerId, 7);
      expect(harness.preparations, hasLength(preparationCount));
      expect(harness.sessions, hasLength(1));
      expect(session.disposeCalls, 0);
      expect(harness.controller.phase, ExampleSetupPhase.ready);
      expect(harness.controller.canStart, isTrue);

      await harness.controller.close();
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final class _Harness {
  _Harness({
    String? savedId,
    int savedSpeakerId = 0,
    int? availableBytes,
    bool installedCandidate = false,
  }) : storage = _FakeStorage(
         savedId: savedId,
         savedSpeakerId: savedSpeakerId,
         availableBytesValue: availableBytes ?? 1 << 50,
         installedCandidate: installedCandidate,
       ) {
    controller = VoiceScreenController(
      storage: storage,
      preparationFactory: (option, root, allowNetwork) {
        final preparation = _FakePreparation(
          option: option,
          root: root,
          allowNetwork: allowNetwork,
        );
        preparations.add(preparation);
        return preparation;
      },
      sessionFactory: (bundle, speakerId) async {
        final session = _FakeSession();
        sessions.add(session);
        createdSpeakerIds.add(speakerId);
        return session;
      },
    );
  }

  final _FakeStorage storage;
  final List<_FakePreparation> preparations = <_FakePreparation>[];
  final List<_FakeSession> sessions = <_FakeSession>[];
  final List<int> createdSpeakerIds = <int>[];
  late final VoiceScreenController controller;
}

final class _FakeStorage extends ExampleModelStorage {
  _FakeStorage({
    required this.savedId,
    required this.savedSpeakerId,
    required this.availableBytesValue,
    required this.installedCandidate,
  });

  final String? savedId;
  final int savedSpeakerId;
  final int availableBytesValue;
  final bool installedCandidate;
  int availableBytesCalls = 0;
  String? writtenId;
  int? writtenSpeakerId;
  final List<String> deletedIds = <String>[];

  @override
  Future<ExampleSelection?> readSelection() async {
    final id = savedId;
    if (id == null) return null;
    return ExampleSelection(catalogId: id, speakerId: savedSpeakerId);
  }

  @override
  Future<int> availableBytes() async {
    availableBytesCalls++;
    return availableBytesValue;
  }

  @override
  Future<bool> hasInstalledCandidate(VoiceModelOption option) async =>
      installedCandidate;

  @override
  Future<String> optionDirectory(VoiceModelOption option) async =>
      '/private/models/${option.id}';

  @override
  Future<void> writeSelection(
    VoiceModelOption option, {
    int speakerId = 0,
  }) async {
    writtenId = option.id;
    writtenSpeakerId = speakerId;
  }

  @override
  Future<void> deleteOption(VoiceModelOption option) async {
    deletedIds.add(option.id);
  }
}

final class _FakePreparation implements ModelPreparation {
  _FakePreparation({
    required this.option,
    required this.root,
    required this.allowNetwork,
  });

  final VoiceModelOption option;
  final String root;
  final bool allowNetwork;
  final Completer<LocalModelBundle> _result = Completer<LocalModelBundle>();
  bool cancelled = false;
  ModelPreparationProgress _progress = const ModelPreparationProgress(
    phase: ModelPreparationPhase.downloading,
    receivedBytes: 2,
    totalBytes: 10,
  );

  @override
  ModelPreparationProgress get progress => _progress;

  @override
  Future<LocalModelBundle> get result => _result.future;

  @override
  void cancel() {
    cancelled = true;
  }

  void completeReady() {
    _progress = const ModelPreparationProgress(
      phase: ModelPreparationPhase.ready,
      receivedBytes: 10,
      totalBytes: 10,
    );
    _result.complete(
      const LocalModelBundle(
        directory: '/private/bundle',
        manifestPath: '/private/bundle/manifest.json',
      ),
    );
  }

  void completeCancelled() {
    _progress = const ModelPreparationProgress(
      phase: ModelPreparationPhase.cancelled,
      receivedBytes: 2,
      totalBytes: 10,
      failure: ModelPreparationFailure(
        ModelPreparationErrorCode.cancelled,
        'Cancelled.',
      ),
    );
    _result.completeError(
      const ModelPreparationFailure(
        ModelPreparationErrorCode.cancelled,
        'Cancelled.',
      ),
    );
  }

  void completeFailure(ModelPreparationErrorCode code) {
    _progress = ModelPreparationProgress(
      phase: ModelPreparationPhase.failed,
      receivedBytes: 2,
      totalBytes: 10,
      failure: ModelPreparationFailure(code, 'Test failure.'),
    );
    _result.completeError(ModelPreparationFailure(code, 'Test failure.'));
  }
}

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
