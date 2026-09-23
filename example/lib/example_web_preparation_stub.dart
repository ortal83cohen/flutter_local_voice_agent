import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';

import 'model_storage.dart';

/// VM stand-in. Production web uses the js_interop preparation.
final class ExampleWebPreparation implements ModelPreparation {
  /// Creates a stub that cannot run on native or VM hosts.
  ExampleWebPreparation({
    required this.storage,
    required this.option,
    required this.allowNetwork,
  });

  /// Unused on this stub.
  final ExampleModelStorage storage;

  /// Unused on this stub.
  final VoiceModelOption option;

  /// Unused on this stub.
  final bool allowNetwork;

  @override
  Future<LocalModelBundle> get result => Future<LocalModelBundle>.error(
    const ModelPreparationFailure(
      ModelPreparationErrorCode.network,
      'Web model preparation is not available on this host.',
    ),
  );

  @override
  ModelPreparationProgress get progress => const ModelPreparationProgress(
    phase: ModelPreparationPhase.failed,
    receivedBytes: 0,
    totalBytes: 0,
    failure: ModelPreparationFailure(
      ModelPreparationErrorCode.network,
      'Web model preparation is not available on this host.',
    ),
  );

  @override
  void cancel() {}
}
