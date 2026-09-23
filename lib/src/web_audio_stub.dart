import 'models.dart';
import 'web_audio.dart';

/// VM compile stand-in. Production web uses the js_interop owner.
WebAudioOwner createPlatformWebAudioOwner() {
  throw const AgentFailure(
    AgentErrorCode.unsupportedProfile,
    'Web audio is not available on this host.',
    fatal: false,
  );
}
