import 'contracts.dart';
import 'models.dart';

/// Production web model store assigned by the Group 2 library.
LocalModelStore Function()? webModelStoreDefault;

/// Production web session backend assigned by the Group 3 library.
VoiceSessionBackend Function()? webSessionBackendDefault;

/// WASM digest guard assigned by the Group 2 pin helper.
///
/// Runs during web create, before any session backend work.
Future<void> Function()? webWasmGuard;

/// Bundle for the current omitted web create. Cleared when create returns.
LocalModelBundle? webCreateBundle;
