/// On-device speech-to-text and text-to-speech with explicit model preparation.
library;

export 'src/agent.dart';
export 'src/contracts.dart';
export 'src/model_store.dart';
export 'src/model_preparation.dart';
export 'src/models.dart';

export 'src/model_catalog.dart';
export 'src/web_backend.dart'
    show registerWebProfileDefaults, registerWebSessionBackend;
export 'src/web_model_store.dart'
    show WebAssetReader, WebAssetWriter, WebModelStore, registerWebModelStore;
