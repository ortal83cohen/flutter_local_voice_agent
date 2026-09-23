import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/web_backend.dart';
import 'src/web_wasm_assets.dart';

/// Web plugin registrant for this package.
///
/// The web session backend is constructed by LocalVoiceAgent.create. This
/// registrant points the plugin manifest at this package and installs the
/// production WASM guard plus session backend default.
final class FlutterLocalVoiceAgentWeb {
  /// Registers the plugin with Flutter web. No method channel is opened.
  static void registerWith(Registrar registrar) {
    registerProductionWebWasmGuard();
    registerWebSessionBackend();
  }
}
