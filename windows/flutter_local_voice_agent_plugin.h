#ifndef FLUTTER_PLUGIN_FLUTTER_LOCAL_VOICE_AGENT_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_LOCAL_VOICE_AGENT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_local_voice_agent {

class FlutterLocalVoiceAgentPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterLocalVoiceAgentPlugin();

  virtual ~FlutterLocalVoiceAgentPlugin();

  FlutterLocalVoiceAgentPlugin(const FlutterLocalVoiceAgentPlugin &) = delete;
  FlutterLocalVoiceAgentPlugin &operator=(const FlutterLocalVoiceAgentPlugin &) =
      delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace flutter_local_voice_agent

#endif  // FLUTTER_PLUGIN_FLUTTER_LOCAL_VOICE_AGENT_PLUGIN_H_
