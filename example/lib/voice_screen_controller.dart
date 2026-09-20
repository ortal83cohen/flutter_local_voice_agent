import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';

import 'model_storage.dart';

enum ExampleSetupPhase {
  starting,
  needsDownload,
  checking,
  downloading,
  verifying,
  creatingSession,
  ready,
  cancelled,
  failed,
}

abstract interface class ExampleVoiceSession {
  Stream<AgentEvent> get events;
  Future<void> start();
  Future<void> interrupt();
  Future<void> stop();
  Future<void> dispose();
}

final class LocalAgentSession implements ExampleVoiceSession {
  LocalAgentSession(this._agent);

  final LocalVoiceAgent _agent;

  @override
  Stream<AgentEvent> get events => _agent.events;
  @override
  Future<void> start() => _agent.start();
  @override
  Future<void> interrupt() => _agent.interrupt();
  @override
  Future<void> stop() => _agent.stop();
  @override
  Future<void> dispose() => _agent.dispose();
}

typedef PreparationFactory = ModelPreparation Function(
  VoiceModelOption option,
  String rootDirectory,
  bool allowNetwork,
);
typedef VoiceSessionFactory = Future<ExampleVoiceSession> Function(
  LocalModelBundle bundle,
);
typedef ProgressTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

final class VoiceScreenController extends ChangeNotifier {
  VoiceScreenController({
    required this.storage,
    required this.preparationFactory,
    required this.sessionFactory,
    List<VoiceModelOption>? catalog,
    ProgressTimerFactory? progressTimerFactory,
  }) : catalog = List<VoiceModelOption>.unmodifiable(
         catalog ?? VoiceModelCatalog.entries,
       ),
       _progressTimerFactory =
           progressTimerFactory ??
           ((duration, callback) =>
               Timer.periodic(duration, (_) => callback()));

  factory VoiceScreenController.production() => VoiceScreenController(
    storage: ExampleModelStorage(),
    preparationFactory: (option, root, allowNetwork) {
      final manager = ModelPreparationManager(
        rootDirectory: root,
        maxRedirects: allowNetwork ? 5 : 0,
        allowedRedirectOrigins: allowNetwork
            ? option.allowedRedirectOrigins
            : const <Uri>[],
        httpClientFactory: allowNetwork
            ? null
            : () => throw StateError(
                'Offline restoration attempted to access the network.',
              ),
      );
      return manager.prepare(option.descriptor);
    },
    sessionFactory: (bundle) async => LocalAgentSession(
      await LocalVoiceAgent.create(models: bundle, logic: fixedDemoReply),
    ),
  );

  static const diskMarginBytes = 10 * 1024 * 1024;
  static const _progressInterval = Duration(milliseconds: 120);

  final ExampleModelStorage storage;
  final PreparationFactory preparationFactory;
  final VoiceSessionFactory sessionFactory;
  final List<VoiceModelOption> catalog;
  final ProgressTimerFactory _progressTimerFactory;

  VoiceModelOption? selected;
  ExampleSetupPhase phase = ExampleSetupPhase.starting;
  ModelPreparationProgress? progress;
  String status = 'Checking saved model setup…';
  String heard = '';
  String reply = '';
  bool operationBusy = false;
  bool allowRepairRemoval = false;

  ModelPreparation? _preparation;
  Timer? _progressTimer;
  ExampleVoiceSession? _session;
  StreamSubscription<AgentEvent>? _events;
  bool _disposed = false;
  bool _resumeRequested = false;
  int _epoch = 0;
  int _busySerial = 0;

  bool get canStart => phase == ExampleSetupPhase.ready && _session != null;
  bool get canPrepare =>
      selected != null && !operationBusy && phase != ExampleSetupPhase.ready;
  bool get canCancel => _preparation != null && operationBusy;
  bool get hasSession => _session != null;

  Future<void> initialize() async {
    if (_disposed) return;
    final epoch = ++_epoch;
    final busy = _beginBusy();
    phase = ExampleSetupPhase.starting;
    status = 'Checking saved model setup…';
    _notify();
    try {
      final id = await storage.readSelection();
      if (!_current(epoch)) return;
      if (id == null) {
        selected = catalog.isEmpty ? null : catalog.first;
        phase = ExampleSetupPhase.needsDownload;
        status = catalog.isEmpty
            ? 'No downloadable model is available in this build.'
            : 'Choose an English voice model, then download it.';
        return;
      }
      final restored = _optionById(id);
      if (restored == null) {
        selected = catalog.isEmpty ? null : catalog.first;
        phase = ExampleSetupPhase.needsDownload;
        status = 'The saved model is no longer in this catalog. Choose another model.';
        allowRepairRemoval = false;
        return;
      }
      selected = restored;
      await _prepareSelected(epoch: epoch, allowNetwork: false);
    } on ExampleStorageException catch (error) {
      if (_current(epoch)) {
        selected ??= catalog.isEmpty ? null : catalog.first;
        phase = ExampleSetupPhase.failed;
        status = error.message;
      }
    } finally {
      _endBusy(busy);
    }
  }

  Future<void> select(VoiceModelOption? option) async {
    if (_disposed || option == null || operationBusy || selected == option) {
      return;
    }
    final epoch = ++_epoch;
    final busy = _beginBusy();
    _notify();
    _cancelPreparation();
    try {
      await _disposeSession();
      if (!_current(epoch)) return;
      selected = option;
      progress = null;
      allowRepairRemoval = false;
      await _prepareSelected(epoch: epoch, allowNetwork: false);
    } finally {
      _endBusy(busy);
    }
  }

  Future<void> downloadAndPrepare() async {
    if (_disposed || operationBusy || selected == null) return;
    final epoch = ++_epoch;
    final busy = _beginBusy();
    final option = selected!;
    allowRepairRemoval = false;
    progress = null;
    _notify();
    try {
      await _disposeSession();
      if (!_current(epoch)) return;
      if (await storage.hasInstalledCandidate(option)) {
        await _prepareSelected(epoch: epoch, allowNetwork: false);
        if (!_current(epoch) || phase == ExampleSetupPhase.ready) return;
        if (phase != ExampleSetupPhase.needsDownload) return;
      }
      final available = await storage.availableBytes();
      if (!_current(epoch)) return;
      final required = option.downloadBytes + diskMarginBytes;
      if (available < required) {
        phase = ExampleSetupPhase.failed;
        status =
            'Not enough free space. Free at least ${_formatMiB(required - available)} more, then retry.';
        return;
      }
      await _prepareSelected(epoch: epoch, allowNetwork: true);
    } on ExampleStorageException catch (error) {
      if (_current(epoch)) {
        phase = ExampleSetupPhase.failed;
        status = error.message;
      }
    } finally {
      _stopProgressTimer();
      _endBusy(busy);
    }
  }

  Future<void> _prepareSelected({
    required int epoch,
    required bool allowNetwork,
  }) async {
    final option = selected!;
    final root = await storage.optionDirectory(option);
    if (!_current(epoch)) return;
    phase = ExampleSetupPhase.checking;
    status = allowNetwork
        ? 'Checking local files before download…'
        : 'Verifying the saved model without network access…';
    _notify();

    final operation = preparationFactory(option, root, allowNetwork);
    _preparation = operation;
    _updateProgress(operation.progress);
    _progressTimer = _progressTimerFactory(_progressInterval, () {
      if (!_current(epoch) || !identical(_preparation, operation)) return;
      _updateProgress(operation.progress);
    });
    try {
      final bundle = await operation.result;
      if (!_current(epoch) || !identical(_preparation, operation)) return;
      _updateProgress(operation.progress);
      _preparation = null;
      _stopProgressTimer();
      phase = ExampleSetupPhase.creatingSession;
      status = 'Starting the on-device speech engine…';
      _notify();
      final session = await sessionFactory(bundle);
      if (!_current(epoch)) {
        await session.dispose();
        return;
      }
      _session = session;
      _events = session.events.listen(
        _handleAgentEvent,
        onError: (Object _) {
          if (_disposed) return;
          phase = ExampleSetupPhase.failed;
          status = 'The local speech session stopped unexpectedly. Prepare the model again.';
          _notify();
        },
      );
      await storage.writeSelection(option);
      if (!_current(epoch)) {
        await _disposeSession();
        return;
      }
      allowRepairRemoval = false;
      phase = ExampleSetupPhase.ready;
      status = 'Ready. Tap Start and allow microphone access.';
      _notify();
    } on ModelPreparationFailure catch (error) {
      if (!_current(epoch)) return;
      _preparation = null;
      _stopProgressTimer();
      allowRepairRemoval =
          error.code == ModelPreparationErrorCode.integrity ||
          (!allowNetwork &&
              (error.code == ModelPreparationErrorCode.network ||
                  error.code == ModelPreparationErrorCode.storage));
      if (error.code == ModelPreparationErrorCode.cancelled) {
        phase = ExampleSetupPhase.cancelled;
        status = 'Model preparation was cancelled. Tap Download and prepare to retry.';
      } else if (!allowNetwork &&
          error.code == ModelPreparationErrorCode.network) {
        allowRepairRemoval = false;
        phase = ExampleSetupPhase.needsDownload;
        status = 'This model is not installed yet. Download it when ready.';
      } else {
        phase = ExampleSetupPhase.failed;
        status = _preparationMessage(error, offlineRestore: !allowNetwork);
      }
      _notify();
    } on ExampleStorageException catch (error) {
      if (!_current(epoch)) return;
      await _disposeSession();
      if (!_current(epoch)) return;
      phase = ExampleSetupPhase.failed;
      status = error.message;
      _notify();
    } on Object {
      if (!_current(epoch)) return;
      _preparation = null;
      _stopProgressTimer();
      phase = ExampleSetupPhase.failed;
      status = allowNetwork
          ? 'The model could not be prepared. Check the connection and retry.'
          : 'The saved model is missing or damaged. Download it again to repair setup.';
      allowRepairRemoval = !allowNetwork;
      _notify();
    }
  }

  void cancelPreparation() {
    if (_disposed || _preparation == null) return;
    status = 'Cancelling model preparation…';
    _preparation!.cancel();
    _notify();
  }

  Future<void> removeDamagedCopy() async {
    final option = selected;
    if (_disposed || operationBusy || !allowRepairRemoval || option == null) {
      return;
    }
    final epoch = ++_epoch;
    final busy = _beginBusy();
    _notify();
    try {
      _cancelPreparation();
      await _disposeSession();
      if (!_current(epoch)) return;
      await storage.deleteOption(option);
      if (!_current(epoch)) return;
      allowRepairRemoval = false;
      progress = null;
      phase = ExampleSetupPhase.needsDownload;
      status =
          'The damaged local copy was removed. Download it again when ready.';
    } on ExampleStorageException catch (error) {
      if (_current(epoch)) {
        phase = ExampleSetupPhase.failed;
        status = error.message;
      }
    } finally {
      _endBusy(busy);
    }
  }

  Future<void> start() => _runSession(
    (session) => session.start(),
    success: 'Listening. Say “hello”, “what is your name?”, or “thank you”.',
    stopAfterStaleCompletion: true,
  );

  Future<void> interrupt() => _runSession(
    (session) => session.interrupt(),
    success: 'Interrupted. The microphone will listen for the next turn.',
  );

  Future<void> stop() => _runSession(
    (session) => session.stop(),
    success: 'Stopped. Tap Start when you want to continue.',
  );

  Future<void> _runSession(
    Future<void> Function(ExampleVoiceSession session) operation, {
    required String success,
    bool stopAfterStaleCompletion = false,
  }) async {
    final session = _session;
    if (_disposed || operationBusy || session == null) return;
    final epoch = _epoch;
    final busy = _beginBusy();
    _notify();
    try {
      await operation(session);
      if ((!_current(epoch) || !identical(_session, session)) &&
          stopAfterStaleCompletion) {
        await session.stop();
        return;
      }
      if (_current(epoch) && identical(_session, session)) status = success;
    } on Object {
      if (_current(epoch) && identical(_session, session)) {
        status = 'The local speech action failed. Check microphone access and try again.';
      }
    } finally {
      _endBusy(busy);
    }
  }

  void onBackground() {
    if (_disposed) return;
    _resumeRequested = false;
    ++_epoch;
    final hadPreparation = _preparation != null;
    final hasSession = _session != null;
    _cancelPreparation();
    if (hadPreparation || (operationBusy && !hasSession)) {
      phase = ExampleSetupPhase.cancelled;
      status = hadPreparation
          ? 'Download cancelled because the app left the foreground.'
          : 'Setup paused because the app left the foreground. Retry when you return.';
    }
    final session = _session;
    if (session != null) {
      unawaited(session.stop().catchError((Object _) {}));
      if (!hadPreparation) {
        status = 'Stopped while the app is in the background.';
      }
    }
    _notify();
  }

  void onResume() {
    if (_disposed) {
      return;
    }
    if (_session != null) {
      if (phase == ExampleSetupPhase.ready) {
        status = 'Ready. Tap Start when you want to continue.';
        _notify();
      }
      return;
    }
    if (phase != ExampleSetupPhase.cancelled) return;
    if (operationBusy) {
      _resumeRequested = true;
      return;
    }
    unawaited(initialize());
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _cancelPreparation();
    await _disposeSession();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

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

  void _updateProgress(ModelPreparationProgress value) {
    progress = value;
    switch (value.phase) {
      case ModelPreparationPhase.checking:
        phase = ExampleSetupPhase.checking;
        break;
      case ModelPreparationPhase.downloading:
        phase = ExampleSetupPhase.downloading;
        status = 'Downloading verified model files…';
        break;
      case ModelPreparationPhase.verifying:
        phase = ExampleSetupPhase.verifying;
        status = 'Verifying every downloaded file…';
        break;
      case ModelPreparationPhase.ready:
      case ModelPreparationPhase.cancelled:
      case ModelPreparationPhase.failed:
        _stopProgressTimer();
        break;
    }
    _notify();
  }

  void _cancelPreparation() {
    _preparation?.cancel();
    _preparation = null;
    _stopProgressTimer();
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> _disposeSession() async {
    final events = _events;
    final session = _session;
    _events = null;
    _session = null;
    await events?.cancel();
    await session?.dispose();
  }

  VoiceModelOption? _optionById(String id) {
    for (final option in catalog) {
      if (option.id == id) return option;
    }
    return null;
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  int _beginBusy() {
    operationBusy = true;
    return ++_busySerial;
  }

  void _endBusy(int serial) {
    if (_disposed || serial != _busySerial) return;
    operationBusy = false;
    _notify();
    if (_resumeRequested && _session == null) {
      _resumeRequested = false;
      unawaited(initialize());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

Future<String> fixedDemoReply(String transcript) async {
  final command = transcript.toLowerCase();
  if (command.contains('hello')) return 'Hello. How are you?';
  if (command.contains('name')) return 'My name is local voice.';
  if (command.contains('thank')) return 'You are welcome.';
  return 'I heard you. Please say hello.';
}

String _preparationMessage(
  ModelPreparationFailure failure, {
  required bool offlineRestore,
}) => switch (failure.code) {
  ModelPreparationErrorCode.cancelled =>
    'Model preparation was cancelled. Tap Download and prepare to retry.',
  ModelPreparationErrorCode.network =>
    offlineRestore
        ? 'The saved model is missing or damaged. Download it again to repair setup.'
        : 'The download failed. Check the connection and tap retry.',
  ModelPreparationErrorCode.integrity => 'A model file failed verification. Remove the damaged copy, then download it again.',
  ModelPreparationErrorCode.storage =>
    'The model could not be stored. Free device space, then retry.',
  ModelPreparationErrorCode.invalidDescriptor =>
    'This catalog entry is not supported by the installed app.',
};

String _formatMiB(int bytes) => '${(bytes / (1024 * 1024)).ceil()} MB';
