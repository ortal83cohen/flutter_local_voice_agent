#include "include/flutter_local_voice_agent/flutter_local_voice_agent_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <pulse/pulseaudio.h>

#include <atomic>
#include <cmath>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <functional>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

#include "flva.h"

#define FLUTTER_LOCAL_VOICE_AGENT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_local_voice_agent_plugin_get_type(), \
                              FlutterLocalVoiceAgentPlugin))

namespace {

constexpr int kControlCapacity = 32;
constexpr int kDefaultRate = 48000;
constexpr int kMinRate = 8000;
constexpr int kMaxRate = 192000;

static FlMethodResponse* error_response(const char* code, const char* message) {
  return FL_METHOD_RESPONSE(fl_method_error_response_new(code, message, nullptr));
}

static FlMethodResponse* success_null() {
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlValue* call_args(FlMethodCall* call) {
  FlValue* args = fl_method_call_get_args(call);
  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    return args;
  }
  return nullptr;
}

static int32_t lookup_int32(FlValue* args, const char* key, int32_t fallback) {
  if (args == nullptr) {
    return fallback;
  }
  FlValue* value = fl_value_lookup_string(args, key);
  if (value == nullptr) {
    return fallback;
  }
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
    return static_cast<int32_t>(fl_value_get_int(value));
  }
  return fallback;
}

static const char* lookup_cstring(FlValue* map, const char* key, std::string* storage) {
  storage->clear();
  if (map == nullptr) {
    return storage->c_str();
  }
  FlValue* value = fl_value_lookup_string(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return storage->c_str();
  }
  *storage = fl_value_get_string(value);
  return storage->c_str();
}

static bool has_active_window() {
  bool active = false;
  GList* windows = gtk_window_list_toplevels();
  for (GList* node = windows; node != nullptr; node = node->next) {
    if (GTK_IS_WINDOW(node->data) && gtk_window_is_active(GTK_WINDOW(node->data))) {
      active = true;
      break;
    }
  }
  g_list_free(windows);
  return active;
}

static int clamp_rate(int hz) {
  if (hz < kMinRate || hz > kMaxRate) {
    return kDefaultRate;
  }
  return hz;
}

static float rms(const float* samples, int frames) {
  if (samples == nullptr || frames <= 0) {
    return 0;
  }
  double sum = 0;
  for (int i = 0; i < frames; ++i) {
    sum += static_cast<double>(samples[i]) * samples[i];
  }
  return static_cast<float>(std::sqrt(sum / static_cast<double>(frames)));
}

// Convert a Pulse buffer to mono float32. Never log the converted samples.
static int convert_to_mono_float32(const void* data, size_t bytes,
                                   const pa_sample_spec* spec,
                                   std::vector<float>* out) {
  if (data == nullptr || spec == nullptr || out == nullptr || spec->channels < 1) {
    return 0;
  }
  const int channels = spec->channels;
  if (spec->format == PA_SAMPLE_FLOAT32LE || spec->format == PA_SAMPLE_FLOAT32NE) {
    const int frames = static_cast<int>(bytes / (sizeof(float) * static_cast<size_t>(channels)));
    const float* in = static_cast<const float*>(data);
    out->resize(static_cast<size_t>(frames));
    if (channels == 1) {
      memcpy(out->data(), in, static_cast<size_t>(frames) * sizeof(float));
    } else {
      for (int i = 0; i < frames; ++i) {
        float sum = 0;
        for (int ch = 0; ch < channels; ++ch) {
          sum += in[i * channels + ch];
        }
        (*out)[static_cast<size_t>(i)] = sum / static_cast<float>(channels);
      }
    }
    return frames;
  }
  if (spec->format == PA_SAMPLE_S16LE || spec->format == PA_SAMPLE_S16NE) {
    const int frames = static_cast<int>(bytes / (sizeof(int16_t) * static_cast<size_t>(channels)));
    const int16_t* in = static_cast<const int16_t*>(data);
    out->resize(static_cast<size_t>(frames));
    for (int i = 0; i < frames; ++i) {
      float sum = 0;
      for (int ch = 0; ch < channels; ++ch) {
        sum += static_cast<float>(in[i * channels + ch]) / 32768.0f;
      }
      (*out)[static_cast<size_t>(i)] = channels == 1 ? sum : sum / static_cast<float>(channels);
    }
    return frames;
  }
  return 0;
}

static void write_mono_float32(const float* mono, int frames, const pa_sample_spec* spec,
                               void* dest, size_t dest_bytes) {
  memset(dest, 0, dest_bytes);
  if (mono == nullptr || spec == nullptr || dest == nullptr || frames <= 0) {
    return;
  }
  const int channels = spec->channels < 1 ? 1 : spec->channels;
  if (spec->format == PA_SAMPLE_FLOAT32LE || spec->format == PA_SAMPLE_FLOAT32NE) {
    float* out = static_cast<float*>(dest);
    for (int i = 0; i < frames; ++i) {
      for (int ch = 0; ch < channels; ++ch) {
        out[i * channels + ch] = mono[i];
      }
    }
    return;
  }
  if (spec->format == PA_SAMPLE_S16LE || spec->format == PA_SAMPLE_S16NE) {
    int16_t* out = static_cast<int16_t*>(dest);
    for (int i = 0; i < frames; ++i) {
      float sample = mono[i];
      if (sample > 1.0f) {
        sample = 1.0f;
      } else if (sample < -1.0f) {
        sample = -1.0f;
      }
      const int16_t quantized = static_cast<int16_t>(sample * 32767.0f);
      for (int ch = 0; ch < channels; ++ch) {
        out[i * channels + ch] = quantized;
      }
    }
  }
}

static bool is_access_denied(int err) {
  return err == PA_ERR_ACCESS || err == PA_ERR_AUTHKEY;
}

static const char* map_record_failure(int err) {
  if (err == PA_ERR_NOENTITY || err == PA_ERR_CONNECTIONREFUSED ||
      err == PA_ERR_CONNECTIONTERMINATED || err == PA_ERR_INVALIDSERVER) {
    return "audioUnavailable";
  }
  // Portal or Pulse record denial with a live server.
  return "permissionDenied";
}

struct IdleReply {
  FlMethodCall* call;
  FlMethodResponse* response;
};

static gboolean emit_reply(gpointer data) {
  IdleReply* reply = static_cast<IdleReply*>(data);
  GError* error = nullptr;
  fl_method_call_respond(reply->call, reply->response, &error);
  if (error != nullptr) {
    g_warning("FLVA method response failed: %s", error->message);
    g_error_free(error);
  }
  g_object_unref(reply->response);
  g_object_unref(reply->call);
  delete reply;
  return G_SOURCE_REMOVE;
}

class Owner {
 public:
  Owner() {
    worker_ = std::thread([this] { run_control(); });
  }

  ~Owner() { shutdown(); }

  bool enqueue(FlMethodCall* call) {
    if (pending_.fetch_add(1) >= kControlCapacity) {
      pending_.fetch_sub(1);
      return false;
    }
    g_object_ref(call);
    post([this, call] {
      FlMethodResponse* response = execute(call);
      IdleReply* reply = new IdleReply{call, response};
      g_idle_add(emit_reply, reply);
      pending_.fetch_sub(1);
    });
    return true;
  }

  void shutdown() {
    post([this] {
      stop_audio();
      if (session_ != nullptr) {
        flva_destroy(session_);
        session_ = nullptr;
      }
      teardown_pulse();
    });
    {
      std::lock_guard<std::mutex> lock(mu_);
      stop_ = true;
    }
    cv_.notify_all();
    if (worker_.joinable()) {
      worker_.join();
    }
  }

 private:
  enum class RecordOpen { Ok, PermissionDenied, Unavailable };

  void post(std::function<void()> job) {
    {
      std::lock_guard<std::mutex> lock(mu_);
      if (stop_) {
        return;
      }
      jobs_.push(std::move(job));
    }
    cv_.notify_one();
  }

  void run_control() {
    while (true) {
      std::function<void()> job;
      {
        std::unique_lock<std::mutex> lock(mu_);
        cv_.wait(lock, [this] { return stop_ || !jobs_.empty(); });
        if (stop_ && jobs_.empty()) {
          return;
        }
        job = std::move(jobs_.front());
        jobs_.pop();
      }
      job();
    }
  }

  void complete_suspend(const std::string& reason) {
    accept_audio_.store(false);
    running_.store(false);
    stop_audio();
    if (session_ != nullptr) {
      flva_stop(session_);
    }
    suspension_ = reason;
  }

  void request_suspend(const char* reason) {
    accept_audio_.store(false);
    if (!running_.exchange(false)) {
      return;
    }
    const std::string captured = reason;
    post([this, captured] { complete_suspend(captured); });
  }

  FlMethodResponse* execute(FlMethodCall* call) {
    const gchar* method = fl_method_call_get_name(call);
    FlValue* args = call_args(call);
    if (strcmp(method, "create") == 0) {
      return create_session(args);
    }
    if (strcmp(method, "dispose") == 0) {
      stop_audio();
      if (session_ != nullptr) {
        flva_destroy(session_);
        session_ = nullptr;
      }
      teardown_pulse();
      return success_null();
    }
    if (strcmp(method, "stop") == 0) {
      stop_audio();
      if (session_ != nullptr) {
        flva_stop(session_);
      }
      return success_null();
    }
    if (session_ == nullptr) {
      return error_response("invalidState", "Create a session first");
    }
    if (strcmp(method, "start") == 0) {
      return start_audio();
    }
    if (strcmp(method, "setSpeakerId") == 0) {
      char message[2048] = {};
      if (!flva_set_speaker_id(session_, lookup_int32(args, "speakerId", 0), message,
                               static_cast<int32_t>(sizeof(message)))) {
        if (strcmp(message, "unsupportedProfile") == 0) {
          return error_response("unsupportedProfile", message);
        }
        return error_response("audioUnavailable", message);
      }
      return success_null();
    }
    if (strcmp(method, "interrupt") == 0) {
      return FL_METHOD_RESPONSE(
          fl_method_success_response_new(fl_value_new_int(static_cast<int64_t>(flva_interrupt(session_)))));
    }
    if (strcmp(method, "reply") == 0) {
      FlValue* generation_value = args != nullptr ? fl_value_lookup_string(args, "generation") : nullptr;
      FlValue* text_value = args != nullptr ? fl_value_lookup_string(args, "text") : nullptr;
      const uint64_t generation = generation_value != nullptr &&
                                          fl_value_get_type(generation_value) == FL_VALUE_TYPE_INT
                                      ? static_cast<uint64_t>(fl_value_get_int(generation_value))
                                      : 0;
      const char* text = text_value != nullptr && fl_value_get_type(text_value) == FL_VALUE_TYPE_STRING
                             ? fl_value_get_string(text_value)
                             : "";
      if (!flva_reply(session_, generation, text)) {
        return error_response("invalidState", "Stale or oversized reply");
      }
      return success_null();
    }
    if (strcmp(method, "poll") == 0) {
      return poll_events();
    }
    return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  FlMethodResponse* create_session(FlValue* args) {
    if (session_ != nullptr) {
      return error_response("invalidState", "Dispose the previous session first");
    }
    FlValue* mode = args != nullptr ? fl_value_lookup_string(args, "mode") : nullptr;
    if (mode != nullptr && fl_value_get_type(mode) == FL_VALUE_TYPE_STRING &&
        strcmp(fl_value_get_string(mode), "fullDuplexRequired") == 0) {
      return error_response("unsupportedProfile", "Full duplex is not qualified");
    }
    FlValue* paths = args != nullptr ? fl_value_lookup_string(args, "paths") : nullptr;
    if (paths == nullptr || fl_value_get_type(paths) != FL_VALUE_TYPE_MAP) {
      return error_response("invalidAsset", "Missing model paths");
    }
    input_rate_ = query_input_rate();
    source_rate_ = input_rate_;
    std::string vad, encoder, decoder, joiner, asr_tokens, tts_model, tts_tokens, tts_lexicon, llm_model;
    FlvaConfig config{};
    config.vad = lookup_cstring(paths, "vad", &vad);
    config.encoder = lookup_cstring(paths, "encoder", &encoder);
    config.decoder = lookup_cstring(paths, "decoder", &decoder);
    config.joiner = lookup_cstring(paths, "joiner", &joiner);
    config.asr_tokens = lookup_cstring(paths, "asrTokens", &asr_tokens);
    config.tts_model = lookup_cstring(paths, "ttsModel", &tts_model);
    config.tts_tokens = lookup_cstring(paths, "ttsTokens", &tts_tokens);
    config.tts_lexicon = lookup_cstring(paths, "ttsLexicon", &tts_lexicon);
    config.llm_model = lookup_cstring(paths, "llmModel", &llm_model);
    config.input_rate = input_rate_;
    config.speaker_id = lookup_int32(args, "speakerId", 0);
    char message[2048] = {};
    session_ = flva_create(&config, message, static_cast<int32_t>(sizeof(message)));
    if (session_ == nullptr) {
      if (strcmp(message, "unsupportedProfile") == 0) {
        return error_response("unsupportedProfile", message);
      }
      return error_response("inferenceFailed", message);
    }
    g_message("FLVA create inputRate=%d outputRate=%d speakerId=%d", input_rate_,
              flva_output_rate(session_), config.speaker_id);
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "outputRate", fl_value_new_int(flva_output_rate(session_)));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  FlMethodResponse* poll_events() {
    g_autoptr(FlValue) list = fl_value_new_list();
    if (!suspension_.empty()) {
      g_autoptr(FlValue) event = fl_value_new_map();
      fl_value_set_string_take(event, "kind", fl_value_new_string("suspended"));
      fl_value_set_string_take(event, "code", fl_value_new_string(suspension_.c_str()));
      fl_value_append(list, event);
      suspension_.clear();
    }
    FlvaEvent native{};
    for (int i = 0; i < 31 && flva_poll(session_, &native); ++i) {
      g_autoptr(FlValue) event = fl_value_new_map();
      fl_value_set_string_take(event, "sequence", fl_value_new_int(static_cast<int64_t>(native.sequence)));
      fl_value_set_string_take(event, "generation", fl_value_new_int(static_cast<int64_t>(native.generation)));
      fl_value_set_string_take(event, "kind", fl_value_new_string(native.kind));
      fl_value_set_string_take(event, "activity", fl_value_new_string(native.activity));
      fl_value_set_string_take(event, "code", fl_value_new_string(native.code));
      fl_value_set_string_take(event, "text", fl_value_new_string(native.text));
      fl_value_append(list, event);
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(list));
  }

  int query_input_rate() {
    if (!ensure_pulse()) {
      return kDefaultRate;
    }
    refresh_server_info(/*wait=*/true, /*apply_rate=*/true);
    return input_rate_;
  }

  FlMethodResponse* start_audio() {
    if (running_.load()) {
      return success_null();
    }
    if (!ensure_pulse()) {
      return error_response("audioUnavailable", "PulseAudio server is unavailable");
    }
    refresh_server_info(/*wait=*/true, /*apply_rate=*/false);
    if (source_rate_ != 0 && source_rate_ != input_rate_) {
      return error_response("audioUnavailable", "Audio route format changed; recreate the agent");
    }
    const RecordOpen record = open_record();
    if (record != RecordOpen::Ok) {
      close_streams();
      if (record == RecordOpen::PermissionDenied) {
        g_message("FLVA start refused permissionDenied");
        return error_response("permissionDenied", "Microphone permission denied");
      }
      return error_response("audioUnavailable", "Audio input is unavailable");
    }
    if (!flva_start(session_)) {
      close_streams();
      return error_response("invalidState", "Native start failed");
    }
    if (!open_playback()) {
      close_streams();
      flva_stop(session_);
      return error_response("audioUnavailable", "Audio output is unavailable");
    }
    accept_audio_.store(true);
    running_.store(true);
    g_message("FLVA startAudio inputRate=%d outputRate=%d", input_rate_, flva_output_rate(session_));
    return success_null();
  }

  bool ensure_pulse() {
    if (context_ != nullptr && pa_context_get_state(context_) == PA_CONTEXT_READY) {
      return true;
    }
    teardown_pulse();
    mainloop_ = pa_threaded_mainloop_new();
    if (mainloop_ == nullptr) {
      return false;
    }
    pa_mainloop_api* api = pa_threaded_mainloop_get_api(mainloop_);
    context_ = pa_context_new(api, "flutter_local_voice_agent");
    if (context_ == nullptr) {
      teardown_pulse();
      return false;
    }
    pa_context_set_state_callback(context_, &Owner::context_state_cb, this);
    pa_threaded_mainloop_lock(mainloop_);
    if (pa_threaded_mainloop_start(mainloop_) < 0) {
      pa_threaded_mainloop_unlock(mainloop_);
      teardown_pulse();
      return false;
    }
    if (pa_context_connect(context_, nullptr, PA_CONTEXT_NOFLAGS, nullptr) < 0) {
      pa_threaded_mainloop_unlock(mainloop_);
      teardown_pulse();
      return false;
    }
    while (true) {
      const pa_context_state_t state = pa_context_get_state(context_);
      if (state == PA_CONTEXT_READY) {
        break;
      }
      if (!PA_CONTEXT_IS_GOOD(state)) {
        pa_threaded_mainloop_unlock(mainloop_);
        teardown_pulse();
        return false;
      }
      pa_threaded_mainloop_wait(mainloop_);
    }
    pa_context_set_subscribe_callback(context_, &Owner::subscribe_cb, this);
    pa_operation* op = pa_context_subscribe(
        context_,
        static_cast<pa_subscription_mask_t>(PA_SUBSCRIPTION_MASK_SERVER | PA_SUBSCRIPTION_MASK_SOURCE |
                                            PA_SUBSCRIPTION_MASK_SINK),
        nullptr, nullptr);
    if (op != nullptr) {
      pa_operation_unref(op);
    }
    pa_threaded_mainloop_unlock(mainloop_);
    return true;
  }

  void refresh_server_info(bool wait, bool apply_rate) {
    if (context_ == nullptr || mainloop_ == nullptr) {
      return;
    }
    pa_threaded_mainloop_lock(mainloop_);
    pa_operation* op = pa_context_get_server_info(context_, &Owner::server_info_cb, this);
    if (op != nullptr) {
      if (wait) {
        while (pa_operation_get_state(op) == PA_OPERATION_RUNNING) {
          pa_threaded_mainloop_wait(mainloop_);
        }
      }
      pa_operation_unref(op);
    }
    if (wait && !default_source_.empty()) {
      pa_operation* source = pa_context_get_source_info_by_name(context_, default_source_.c_str(),
                                                                &Owner::source_info_cb, this);
      if (source != nullptr) {
        while (pa_operation_get_state(source) == PA_OPERATION_RUNNING) {
          pa_threaded_mainloop_wait(mainloop_);
        }
        pa_operation_unref(source);
      }
    }
    pa_threaded_mainloop_unlock(mainloop_);
    if (apply_rate && source_rate_ != 0) {
      input_rate_ = clamp_rate(source_rate_);
    }
  }

  RecordOpen open_record() {
    pa_sample_spec spec;
    memset(&spec, 0, sizeof(spec));
    spec.format = PA_SAMPLE_FLOAT32LE;
    spec.rate = static_cast<uint32_t>(input_rate_);
    spec.channels = 1;
    pa_buffer_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.maxlength = static_cast<uint32_t>(-1);
    attr.fragsize = pa_usec_to_bytes(20000, &spec);
    const pa_stream_flags_t flags =
        static_cast<pa_stream_flags_t>(PA_STREAM_ADJUST_LATENCY | PA_STREAM_AUTO_TIMING_UPDATE);
    pa_threaded_mainloop_lock(mainloop_);
    record_ = pa_stream_new(context_, "flva-record", &spec, nullptr);
    if (record_ == nullptr) {
      const int err = pa_context_errno(context_);
      pa_threaded_mainloop_unlock(mainloop_);
      g_message("FLVA record stream create failed errno=%d %s", err, pa_strerror(err));
      return is_access_denied(err) ? RecordOpen::PermissionDenied : RecordOpen::Unavailable;
    }
    pa_stream_set_state_callback(record_, &Owner::stream_state_cb, this);
    pa_stream_set_read_callback(record_, &Owner::record_read_cb, this);
    if (pa_stream_connect_record(record_, nullptr, &attr, flags) < 0) {
      const int err = pa_context_errno(context_);
      pa_threaded_mainloop_unlock(mainloop_);
      g_message("FLVA record connect failed errno=%d %s", err, pa_strerror(err));
      return strcmp(map_record_failure(err), "permissionDenied") == 0 ? RecordOpen::PermissionDenied
                                                                      : RecordOpen::Unavailable;
    }
    while (true) {
      const pa_stream_state_t state = pa_stream_get_state(record_);
      if (state == PA_STREAM_READY) {
        break;
      }
      if (!PA_STREAM_IS_GOOD(state)) {
        const int err = pa_context_errno(context_);
        pa_threaded_mainloop_unlock(mainloop_);
        g_message("FLVA record denied or failed errno=%d %s", err, pa_strerror(err));
        return strcmp(map_record_failure(err), "permissionDenied") == 0 ? RecordOpen::PermissionDenied
                                                                        : RecordOpen::Unavailable;
      }
      pa_threaded_mainloop_wait(mainloop_);
    }
    pa_threaded_mainloop_unlock(mainloop_);
    return RecordOpen::Ok;
  }

  bool open_playback() {
    pa_sample_spec spec;
    memset(&spec, 0, sizeof(spec));
    spec.format = PA_SAMPLE_FLOAT32LE;
    spec.rate = static_cast<uint32_t>(flva_output_rate(session_));
    spec.channels = 1;
    pa_buffer_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.maxlength = static_cast<uint32_t>(-1);
    attr.tlength = pa_usec_to_bytes(40000, &spec);
    attr.prebuf = static_cast<uint32_t>(-1);
    attr.minreq = static_cast<uint32_t>(-1);
    const pa_stream_flags_t flags =
        static_cast<pa_stream_flags_t>(PA_STREAM_ADJUST_LATENCY | PA_STREAM_AUTO_TIMING_UPDATE);
    pa_threaded_mainloop_lock(mainloop_);
    playback_ = pa_stream_new(context_, "flva-playback", &spec, nullptr);
    if (playback_ == nullptr) {
      pa_threaded_mainloop_unlock(mainloop_);
      return false;
    }
    pa_stream_set_state_callback(playback_, &Owner::stream_state_cb, this);
    pa_stream_set_write_callback(playback_, &Owner::playback_write_cb, this);
    if (pa_stream_connect_playback(playback_, nullptr, &attr, flags, nullptr, nullptr) < 0) {
      pa_threaded_mainloop_unlock(mainloop_);
      return false;
    }
    while (true) {
      const pa_stream_state_t state = pa_stream_get_state(playback_);
      if (state == PA_STREAM_READY) {
        break;
      }
      if (!PA_STREAM_IS_GOOD(state)) {
        pa_threaded_mainloop_unlock(mainloop_);
        return false;
      }
      pa_threaded_mainloop_wait(mainloop_);
    }
    pa_threaded_mainloop_unlock(mainloop_);
    return true;
  }

  void close_streams() {
    if (mainloop_ == nullptr) {
      record_ = nullptr;
      playback_ = nullptr;
      return;
    }
    pa_threaded_mainloop_lock(mainloop_);
    if (record_ != nullptr) {
      pa_stream_set_read_callback(record_, nullptr, nullptr);
      pa_stream_set_state_callback(record_, nullptr, nullptr);
      pa_stream_disconnect(record_);
      pa_stream_unref(record_);
      record_ = nullptr;
    }
    if (playback_ != nullptr) {
      pa_stream_set_write_callback(playback_, nullptr, nullptr);
      pa_stream_set_state_callback(playback_, nullptr, nullptr);
      pa_stream_disconnect(playback_);
      pa_stream_unref(playback_);
      playback_ = nullptr;
    }
    pa_threaded_mainloop_unlock(mainloop_);
  }

  void stop_audio() {
    accept_audio_.store(false);
    running_.store(false);
    if (session_ != nullptr) {
      flva_interrupt(session_);
    }
    close_streams();
    while (callbacks_.load() != 0) {
      std::this_thread::yield();
    }
  }

  void teardown_pulse() {
    close_streams();
    if (mainloop_ != nullptr) {
      pa_threaded_mainloop_lock(mainloop_);
    }
    if (context_ != nullptr) {
      pa_context_set_state_callback(context_, nullptr, nullptr);
      pa_context_set_subscribe_callback(context_, nullptr, nullptr);
      pa_context_disconnect(context_);
      pa_context_unref(context_);
      context_ = nullptr;
    }
    if (mainloop_ != nullptr) {
      pa_threaded_mainloop_unlock(mainloop_);
      pa_threaded_mainloop_stop(mainloop_);
      pa_threaded_mainloop_free(mainloop_);
      mainloop_ = nullptr;
    }
  }

  static void context_state_cb(pa_context* context, void* userdata) {
    Owner* owner = static_cast<Owner*>(userdata);
    const pa_context_state_t state = pa_context_get_state(context);
    if (state == PA_CONTEXT_READY || state == PA_CONTEXT_FAILED || state == PA_CONTEXT_TERMINATED) {
      pa_threaded_mainloop_signal(owner->mainloop_, 0);
    }
    if ((state == PA_CONTEXT_FAILED || state == PA_CONTEXT_TERMINATED) && owner->running_.load()) {
      g_message("FLVA pulse context lost state=%d", static_cast<int>(state));
      owner->request_suspend("audioUnavailable");
    }
  }

  static void stream_state_cb(pa_stream* stream, void* userdata) {
    Owner* owner = static_cast<Owner*>(userdata);
    const pa_stream_state_t state = pa_stream_get_state(stream);
    if (state == PA_STREAM_READY || state == PA_STREAM_FAILED || state == PA_STREAM_TERMINATED) {
      pa_threaded_mainloop_signal(owner->mainloop_, 0);
    }
    if ((state == PA_STREAM_FAILED || state == PA_STREAM_TERMINATED) && owner->running_.load()) {
      g_message("FLVA pulse stream lost state=%d", static_cast<int>(state));
      owner->request_suspend("audioUnavailable");
    }
  }

  static void subscribe_cb(pa_context* context, pa_subscription_event_type_t type, uint32_t idx,
                           void* userdata) {
    Owner* owner = static_cast<Owner*>(userdata);
    (void)idx;
    if (!owner->running_.load()) {
      return;
    }
    const pa_subscription_event_type_t facility = static_cast<pa_subscription_event_type_t>(
        type & PA_SUBSCRIPTION_EVENT_FACILITY_MASK);
    const pa_subscription_event_type_t kind =
        static_cast<pa_subscription_event_type_t>(type & PA_SUBSCRIPTION_EVENT_TYPE_MASK);
    if (facility == PA_SUBSCRIPTION_EVENT_SERVER && kind == PA_SUBSCRIPTION_EVENT_CHANGE) {
      pa_operation* op = pa_context_get_server_info(context, &Owner::server_change_cb, owner);
      if (op != nullptr) {
        pa_operation_unref(op);
      }
      return;
    }
    if ((facility == PA_SUBSCRIPTION_EVENT_SOURCE || facility == PA_SUBSCRIPTION_EVENT_SINK) &&
        kind == PA_SUBSCRIPTION_EVENT_REMOVE) {
      g_message("FLVA pulse endpoint removed facility=%d", static_cast<int>(facility));
      owner->request_suspend("routeChanged");
    }
  }

  static void server_info_cb(pa_context* context, const pa_server_info* info, void* userdata) {
    (void)context;
    Owner* owner = static_cast<Owner*>(userdata);
    if (info != nullptr) {
      owner->default_source_ = info->default_source_name != nullptr ? info->default_source_name : "";
      owner->default_sink_ = info->default_sink_name != nullptr ? info->default_sink_name : "";
    }
    pa_threaded_mainloop_signal(owner->mainloop_, 0);
  }

  static void server_change_cb(pa_context* context, const pa_server_info* info, void* userdata) {
    (void)context;
    Owner* owner = static_cast<Owner*>(userdata);
    if (info == nullptr || !owner->running_.load()) {
      return;
    }
    const std::string source = info->default_source_name != nullptr ? info->default_source_name : "";
    const std::string sink = info->default_sink_name != nullptr ? info->default_sink_name : "";
    if (source != owner->default_source_ || sink != owner->default_sink_) {
      g_message("FLVA default device changed");
      owner->request_suspend("routeChanged");
    }
  }

  static void source_info_cb(pa_context* context, const pa_source_info* info, int eol, void* userdata) {
    (void)context;
    Owner* owner = static_cast<Owner*>(userdata);
    if (eol != 0) {
      pa_threaded_mainloop_signal(owner->mainloop_, 0);
      return;
    }
    if (info != nullptr) {
      owner->source_rate_ = static_cast<int>(info->sample_spec.rate);
    }
  }

  static void record_read_cb(pa_stream* stream, size_t nbytes, void* userdata) {
    Owner* owner = static_cast<Owner*>(userdata);
    (void)nbytes;
    const void* data = nullptr;
    size_t bytes = 0;
    if (pa_stream_peek(stream, &data, &bytes) < 0) {
      return;
    }
    owner->callbacks_.fetch_add(1);
    if (owner->accept_audio_.load() && owner->session_ != nullptr && data != nullptr && bytes > 0) {
      const pa_sample_spec* spec = pa_stream_get_sample_spec(stream);
      std::vector<float> mono;
      const int frames = convert_to_mono_float32(data, bytes, spec, &mono);
      if (frames > 0) {
        const int pushed = flva_push(owner->session_, mono.data(), frames);
        const int count = owner->callbacks_.load();
        if (pushed == 0 || (count % 100) == 1) {
          g_message("FLVA capture callbacks=%d frames=%d rms=%.4f push=%d", count, frames, rms(mono.data(), frames),
                    pushed);
        }
      }
    }
    owner->callbacks_.fetch_sub(1);
    pa_stream_drop(stream);
  }

  static void playback_write_cb(pa_stream* stream, size_t nbytes, void* userdata) {
    Owner* owner = static_cast<Owner*>(userdata);
    const pa_sample_spec* spec = pa_stream_get_sample_spec(stream);
    if (spec == nullptr || nbytes == 0) {
      return;
    }
    void* buffer = nullptr;
    size_t want = nbytes;
    if (pa_stream_begin_write(stream, &buffer, &want) < 0 || buffer == nullptr) {
      return;
    }
    const size_t frame_bytes = pa_frame_size(spec);
    const int frames = frame_bytes == 0 ? 0 : static_cast<int>(want / frame_bytes);
    std::vector<float> mono(static_cast<size_t>(frames), 0.0f);
    owner->callbacks_.fetch_add(1);
    if (owner->accept_audio_.load() && owner->session_ != nullptr && frames > 0) {
      flva_render(owner->session_, mono.data(), frames);
    }
    owner->callbacks_.fetch_sub(1);
    write_mono_float32(mono.data(), frames, spec, buffer, want);
    pa_stream_write(stream, buffer, want, nullptr, 0, PA_SEEK_RELATIVE);
  }

  std::mutex mu_;
  std::condition_variable cv_;
  std::queue<std::function<void()>> jobs_;
  std::thread worker_;
  bool stop_ = false;
  std::atomic<int> pending_{0};
  std::atomic<bool> accept_audio_{false};
  std::atomic<bool> running_{false};
  std::atomic<int> callbacks_{0};

  FlvaSession* session_ = nullptr;
  int input_rate_ = kDefaultRate;
  int source_rate_ = 0;
  std::string suspension_;
  std::string default_source_;
  std::string default_sink_;

  pa_threaded_mainloop* mainloop_ = nullptr;
  pa_context* context_ = nullptr;
  pa_stream* record_ = nullptr;
  pa_stream* playback_ = nullptr;
};

}  // namespace

struct _FlutterLocalVoiceAgentPlugin {
  GObject parent_instance;
  Owner* owner;
};

G_DEFINE_TYPE(FlutterLocalVoiceAgentPlugin, flutter_local_voice_agent_plugin, g_object_get_type())

static void flutter_local_voice_agent_plugin_handle_method_call(FlutterLocalVoiceAgentPlugin* self,
                                                                FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "start") == 0 && !has_active_window()) {
    g_autoptr(FlMethodResponse) response =
        error_response("invalidState", "Start requires a foreground application");
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  if (self->owner == nullptr || !self->owner->enqueue(method_call)) {
    g_autoptr(FlMethodResponse) response = error_response("capacityExceeded", "Control queue is full");
    fl_method_call_respond(method_call, response, nullptr);
  }
}

static void flutter_local_voice_agent_plugin_dispose(GObject* object) {
  FlutterLocalVoiceAgentPlugin* self = FLUTTER_LOCAL_VOICE_AGENT_PLUGIN(object);
  if (self->owner != nullptr) {
    self->owner->shutdown();
    delete self->owner;
    self->owner = nullptr;
  }
  G_OBJECT_CLASS(flutter_local_voice_agent_plugin_parent_class)->dispose(object);
}

static void flutter_local_voice_agent_plugin_class_init(FlutterLocalVoiceAgentPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_local_voice_agent_plugin_dispose;
}

static void flutter_local_voice_agent_plugin_init(FlutterLocalVoiceAgentPlugin* self) {
  self->owner = new Owner();
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  (void)channel;
  FlutterLocalVoiceAgentPlugin* plugin = FLUTTER_LOCAL_VOICE_AGENT_PLUGIN(user_data);
  flutter_local_voice_agent_plugin_handle_method_call(plugin, method_call);
}

void flutter_local_voice_agent_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterLocalVoiceAgentPlugin* plugin = FLUTTER_LOCAL_VOICE_AGENT_PLUGIN(
      g_object_new(flutter_local_voice_agent_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "flutter_local_voice_agent", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}
