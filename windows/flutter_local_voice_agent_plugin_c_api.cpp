#include "include/flutter_local_voice_agent/flutter_local_voice_agent_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_local_voice_agent_plugin.h"

void FlutterLocalVoiceAgentPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_local_voice_agent::FlutterLocalVoiceAgentPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
