#include "flutter_local_voice_agent_plugin.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>

#include <initguid.h>

#include <audioclient.h>
#include <avrt.h>
#include <ks.h>
#include <ksmedia.h>
#include <mmdeviceapi.h>
#include <mmreg.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <cmath>
#include <condition_variable>
#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "flva.h"

namespace flutter_local_voice_agent {
namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

template <typename T>
struct ComRelease {
  void operator()(T *pointer) const {
    if (pointer) pointer->Release();
  }
};
template <typename T>
using ComRef = std::unique_ptr<T, ComRelease<T>>;

struct CoTaskFree {
  void operator()(void *pointer) const {
    if (pointer) CoTaskMemFree(pointer);
  }
};

void Log(const char *fmt, ...) {
  char buffer[512];
  va_list args;
  va_start(args, fmt);
  vsnprintf(buffer, sizeof(buffer), fmt, args);
  va_end(args);
  OutputDebugStringA(buffer);
  OutputDebugStringA("\n");
}

bool IsAccessDenied(HRESULT hr) {
  return hr == E_ACCESSDENIED || hr == HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED) ||
         hr == HRESULT_FROM_WIN32(ERROR_PRIVILEGE_NOT_HELD);
}

bool IsDeviceInvalidated(HRESULT hr) { return hr == AUDCLNT_E_DEVICE_INVALIDATED; }

struct DeviceFormat {
  int sample_rate = 0;
  int channels = 0;
  int bits = 16;
  bool ieee_float = false;
  WORD block_align = 0;
};

DeviceFormat ParseWaveFormat(const WAVEFORMATEX *fmt) {
  DeviceFormat out;
  if (!fmt) return out;
  out.sample_rate = static_cast<int>(fmt->nSamplesPerSec);
  out.channels = static_cast<int>(fmt->nChannels);
  out.bits = static_cast<int>(fmt->wBitsPerSample);
  out.block_align = fmt->nBlockAlign;
  out.ieee_float = fmt->wFormatTag == WAVE_FORMAT_IEEE_FLOAT;
  if (fmt->wFormatTag == WAVE_FORMAT_EXTENSIBLE && fmt->cbSize >= 22) {
    const auto *ext = reinterpret_cast<const WAVEFORMATEXTENSIBLE *>(fmt);
    out.ieee_float =
        IsEqualGUID(ext->SubFormat, KSDATAFORMAT_SUBTYPE_IEEE_FLOAT) == TRUE;
  }
  return out;
}

float ReadSample(const BYTE *bytes, const DeviceFormat &fmt) {
  if (fmt.ieee_float && fmt.bits == 32) {
    float value = 0.f;
    memcpy(&value, bytes, sizeof(value));
    return value;
  }
  if (fmt.bits == 16) {
    int16_t sample = 0;
    memcpy(&sample, bytes, sizeof(sample));
    return static_cast<float>(sample) / 32768.f;
  }
  if (fmt.bits == 32) {
    int32_t sample = 0;
    memcpy(&sample, bytes, sizeof(sample));
    return static_cast<float>(sample) / 2147483648.f;
  }
  if (fmt.bits == 24) {
    int32_t sample = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16);
    if (sample & 0x800000) sample |= static_cast<int32_t>(0xFF000000);
    return static_cast<float>(sample) / 8388608.f;
  }
  return 0.f;
}

void WriteSample(BYTE *bytes, const DeviceFormat &fmt, float sample) {
  if (sample > 1.f) sample = 1.f;
  if (sample < -1.f) sample = -1.f;
  if (fmt.ieee_float && fmt.bits == 32) {
    memcpy(bytes, &sample, sizeof(sample));
    return;
  }
  if (fmt.bits == 16) {
    const int16_t value = static_cast<int16_t>(sample * 32767.f);
    memcpy(bytes, &value, sizeof(value));
  }
}

// Convert device PCM to mono float32 before flva_push. Never logs samples.
void ToMonoFloat32(const BYTE *src, UINT32 frames, const DeviceFormat &fmt,
                   float *dest) {
  const int channels = fmt.channels > 0 ? fmt.channels : 1;
  const int bytes_per_sample = fmt.bits > 0 ? fmt.bits / 8 : 4;
  const int step =
      fmt.block_align != 0 ? fmt.block_align : bytes_per_sample * channels;
  for (UINT32 i = 0; i < frames; ++i) {
    const BYTE *frame = src + static_cast<size_t>(i) * static_cast<size_t>(step);
    float sum = 0.f;
    for (int ch = 0; ch < channels; ++ch) {
      sum += ReadSample(frame + ch * bytes_per_sample, fmt);
    }
    dest[i] = sum / static_cast<float>(channels);
  }
}

void FromMonoFloat32(const float *src, UINT32 src_frames, int src_rate,
                     BYTE *dest, UINT32 dest_frames, const DeviceFormat &fmt) {
  const int channels = fmt.channels > 0 ? fmt.channels : 1;
  const int bytes_per_sample = fmt.bits > 0 ? fmt.bits / 8 : 4;
  const int step =
      fmt.block_align != 0 ? fmt.block_align : bytes_per_sample * channels;
  for (UINT32 i = 0; i < dest_frames; ++i) {
    size_t index = 0;
    if (src_frames > 0) {
      if (src_frames == dest_frames || fmt.sample_rate <= 0) {
        index = i < src_frames ? i : src_frames - 1;
      } else {
        index = static_cast<size_t>(
            (static_cast<double>(i) * static_cast<double>(src_rate)) /
            static_cast<double>(fmt.sample_rate));
        if (index >= src_frames) index = src_frames - 1;
      }
    }
    const float sample = src_frames > 0 ? src[index] : 0.f;
    BYTE *frame = dest + static_cast<size_t>(i) * static_cast<size_t>(step);
    for (int ch = 0; ch < channels; ++ch) {
      WriteSample(frame + ch * bytes_per_sample, fmt, sample);
    }
  }
}

float Rms(const float *samples, int frames) {
  if (!samples || frames <= 0) return 0.f;
  double sum = 0;
  for (int i = 0; i < frames; ++i) {
    sum += static_cast<double>(samples[i]) * static_cast<double>(samples[i]);
  }
  return static_cast<float>(sqrt(sum / static_cast<double>(frames)));
}

const EncodableMap *AsMap(const EncodableValue *value) {
  if (!value) return nullptr;
  return std::get_if<EncodableMap>(value);
}

std::string LookupString(const EncodableMap &map, const char *key) {
  const auto it = map.find(EncodableValue(std::string(key)));
  if (it == map.end()) return {};
  if (const auto *text = std::get_if<std::string>(&it->second)) return *text;
  return {};
}

int32_t LookupInt32(const EncodableMap &map, const char *key, int32_t fallback) {
  const auto it = map.find(EncodableValue(std::string(key)));
  if (it == map.end()) return fallback;
  if (const auto *value = std::get_if<int32_t>(&it->second)) return *value;
  if (const auto *value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int32_t>(*value);
  }
  return fallback;
}

uint64_t LookupUint64(const EncodableMap &map, const char *key) {
  const auto it = map.find(EncodableValue(std::string(key)));
  if (it == map.end()) return 0;
  if (const auto *value = std::get_if<int64_t>(&it->second)) {
    return static_cast<uint64_t>(*value);
  }
  if (const auto *value = std::get_if<int32_t>(&it->second)) {
    return static_cast<uint64_t>(*value);
  }
  return 0;
}

WAVEFORMATEX MakeMonoFloat(int sample_rate) {
  WAVEFORMATEX format{};
  format.wFormatTag = WAVE_FORMAT_IEEE_FLOAT;
  format.nChannels = 1;
  format.nSamplesPerSec = static_cast<DWORD>(sample_rate);
  format.wBitsPerSample = 32;
  format.nBlockAlign = 4;
  format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;
  format.cbSize = 0;
  return format;
}

}  // namespace

class FlutterLocalVoiceAgentPlugin::Impl {
 public:
  Impl() {
    control_ = std::thread([this] { ControlLoop(); });
  }

  ~Impl() {
    Submit([this] {
      StopAudio();
      if (session_) {
        flva_destroy(session_);
        session_ = nullptr;
      }
    });
    {
      std::lock_guard<std::mutex> lock(mutex_);
      stop_control_ = true;
    }
    cv_.notify_one();
    if (control_.joinable()) control_.join();
  }

  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const std::string &name = method_call.method_name();
    if (name != "create" && name != "start" && name != "stop" &&
        name != "interrupt" && name != "reply" && name != "poll" &&
        name != "dispose" && name != "setSpeakerId") {
      result->NotImplemented();
      return;
    }
    if (pending_.fetch_add(1) >= 32) {
      pending_.fetch_sub(1);
      result->Error("capacityExceeded", "Control queue is full");
      return;
    }
    EncodableValue args =
        method_call.arguments() ? *method_call.arguments() : EncodableValue();
    Submit([this, name, args = std::move(args),
            result = std::move(result)]() mutable {
      Execute(name, args, std::move(result));
      pending_.fetch_sub(1);
    });
  }

  void Suspend(const char *reason) {
    if (!running_.load() && !accept_audio_.load()) return;
    accept_audio_.store(false);
    if (pending_.fetch_add(1) >= 32) {
      pending_.fetch_sub(1);
      return;
    }
    const std::string code(reason);
    Submit([this, code] {
      StopAudio();
      if (session_) flva_stop(session_);
      suspension_ = code;
      pending_.fetch_sub(1);
    });
  }

  bool IsLive() const { return running_.load() || accept_audio_.load(); }

 private:
  enum class OpenResult { kOk, kPermissionDenied, kUnavailable };

  class DeviceWatcher final : public IMMNotificationClient {
   public:
    explicit DeviceWatcher(Impl *owner) : owner_(owner) {}

    void Detach() { owner_.store(nullptr); }

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **object) override {
      if (!object) return E_POINTER;
      if (riid == IID_IUnknown || riid == __uuidof(IMMNotificationClient)) {
        *object = static_cast<IMMNotificationClient *>(this);
        AddRef();
        return S_OK;
      }
      *object = nullptr;
      return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override {
      return static_cast<ULONG>(InterlockedIncrement(&refs_));
    }

    ULONG STDMETHODCALLTYPE Release() override {
      const LONG value = InterlockedDecrement(&refs_);
      if (value == 0) delete this;
      return static_cast<ULONG>(value);
    }

    HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD state) override {
      Impl *owner = owner_.load();
      if (!owner || !owner->IsLive()) return S_OK;
      if (state == DEVICE_STATE_UNPLUGGED || state == DEVICE_STATE_NOTPRESENT ||
          state == DEVICE_STATE_DISABLED) {
        owner->Suspend("audioUnavailable");
      }
      return S_OK;
    }

    HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override {
      Impl *owner = owner_.load();
      if (owner && owner->IsLive()) owner->Suspend("audioUnavailable");
      return S_OK;
    }

    HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow, ERole role,
                                                     LPCWSTR) override {
      Impl *owner = owner_.load();
      if (!owner || !owner->IsLive()) return S_OK;
      if (role == eConsole || role == eCommunications) {
        owner->Suspend("routeChanged");
      }
      return S_OK;
    }

    HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR,
                                                     const PROPERTYKEY) override {
      return S_OK;
    }

   private:
    std::atomic<Impl *> owner_{nullptr};
    LONG refs_ = 1;
  };

  void Submit(std::function<void()> job) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      jobs_.push_back(std::move(job));
    }
    cv_.notify_one();
  }

  void ControlLoop() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    EnsureEnumerator();
    for (;;) {
      std::function<void()> job;
      {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return stop_control_ || !jobs_.empty(); });
        if (stop_control_ && jobs_.empty()) break;
        job = std::move(jobs_.front());
        jobs_.pop_front();
      }
      job();
    }
    TeardownEnumerator();
    CoUninitialize();
  }

  void EnsureEnumerator() {
    if (enumerator_) return;
    IMMDeviceEnumerator *raw = nullptr;
    const HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                        CLSCTX_ALL, IID_PPV_ARGS(&raw));
    if (FAILED(hr) || !raw) {
      Log("FLVA enumerator create failed hr=0x%08lx", static_cast<unsigned long>(hr));
      return;
    }
    enumerator_.reset(raw);
    watcher_ = new DeviceWatcher(this);
    enumerator_->RegisterEndpointNotificationCallback(watcher_);
  }

  void TeardownEnumerator() {
    if (enumerator_ && watcher_) {
      enumerator_->UnregisterEndpointNotificationCallback(watcher_);
    }
    if (watcher_) {
      watcher_->Detach();
      watcher_->Release();
      watcher_ = nullptr;
    }
    enumerator_.reset();
  }

  int32_t QueryDefaultCaptureRate() {
    if (!enumerator_) return 48000;
    IMMDevice *device = nullptr;
    if (FAILED(enumerator_->GetDefaultAudioEndpoint(eCapture, eConsole, &device)) ||
        !device) {
      return 48000;
    }
    ComRef<IMMDevice> owned(device);
    IAudioClient *client = nullptr;
    HRESULT hr = owned->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                 reinterpret_cast<void **>(&client));
    if (FAILED(hr) || !client) return 48000;
    ComRef<IAudioClient> audio(client);
    WAVEFORMATEX *mix = nullptr;
    hr = audio->GetMixFormat(&mix);
    if (FAILED(hr) || !mix) return 48000;
    std::unique_ptr<WAVEFORMATEX, CoTaskFree> format(mix);
    const int rate = static_cast<int>(format->nSamplesPerSec);
    if (rate < 8000 || rate > 192000) return 48000;
    return rate;
  }

  void Execute(const std::string &name, const EncodableValue &args_value,
               std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const EncodableMap *args = AsMap(&args_value);
    const EncodableMap empty{};
    if (!args) args = &empty;

    if (name == "create") {
      if (session_) {
        result->Error("invalidState", "Dispose the previous session first");
        return;
      }
      if (LookupString(*args, "mode") == "fullDuplexRequired") {
        result->Error("unsupportedProfile", "Full duplex is not qualified");
        return;
      }
      const auto paths_it = args->find(EncodableValue(std::string("paths")));
      const EncodableMap *paths =
          paths_it == args->end() ? nullptr : AsMap(&paths_it->second);
      if (!paths) {
        result->Error("invalidAsset", "Missing model paths");
        return;
      }
      input_rate_ = QueryDefaultCaptureRate();
      vad_ = LookupString(*paths, "vad");
      encoder_ = LookupString(*paths, "encoder");
      decoder_ = LookupString(*paths, "decoder");
      joiner_ = LookupString(*paths, "joiner");
      asr_tokens_ = LookupString(*paths, "asrTokens");
      tts_model_ = LookupString(*paths, "ttsModel");
      tts_tokens_ = LookupString(*paths, "ttsTokens");
      tts_lexicon_ = LookupString(*paths, "ttsLexicon");
      llm_model_ = LookupString(*paths, "llmModel");
      FlvaConfig config{};
      config.vad = vad_.c_str();
      config.encoder = encoder_.c_str();
      config.decoder = decoder_.c_str();
      config.joiner = joiner_.c_str();
      config.asr_tokens = asr_tokens_.c_str();
      config.tts_model = tts_model_.c_str();
      config.tts_tokens = tts_tokens_.c_str();
      config.tts_lexicon = tts_lexicon_.c_str();
      config.llm_model = llm_model_.c_str();
      config.input_rate = input_rate_;
      config.speaker_id = LookupInt32(*args, "speakerId", 0);
      char message[2048]{};
      session_ = flva_create(&config, message, sizeof(message));
      if (!session_) {
        const std::string native(message);
        result->Error(native == "unsupportedProfile" ? "unsupportedProfile"
                                                     : "inferenceFailed",
                      native);
        return;
      }
      const int32_t output_rate = flva_output_rate(session_);
      Log("FLVA create inputRate=%d outputRate=%d speakerId=%d", input_rate_,
          output_rate, config.speaker_id);
      result->Success(EncodableMap{
          {EncodableValue("outputRate"), EncodableValue(output_rate)},
      });
      return;
    }

    if (name == "dispose") {
      StopAudio();
      if (session_) {
        flva_destroy(session_);
        session_ = nullptr;
      }
      result->Success();
      return;
    }
    if (name == "stop") {
      StopAudio();
      if (session_) flva_stop(session_);
      result->Success();
      return;
    }
    if (!session_) {
      result->Error("invalidState", "Create a session first");
      return;
    }
    if (name == "start") {
      StartAudio(std::move(result));
      return;
    }
    if (name == "setSpeakerId") {
      char message[2048]{};
      const int32_t speaker_id = LookupInt32(*args, "speakerId", 0);
      if (!flva_set_speaker_id(session_, speaker_id, message, sizeof(message))) {
        const std::string native(message);
        result->Error(native == "unsupportedProfile" ? "unsupportedProfile"
                                                     : "audioUnavailable",
                      native);
        return;
      }
      result->Success();
      return;
    }
    if (name == "interrupt") {
      result->Success(EncodableValue(static_cast<int64_t>(flva_interrupt(session_))));
      return;
    }
    if (name == "reply") {
      if (!flva_reply(session_, LookupUint64(*args, "generation"),
                      LookupString(*args, "text").c_str())) {
        result->Error("invalidState", "Stale or oversized reply");
        return;
      }
      result->Success();
      return;
    }
    if (name == "poll") {
      EncodableList events;
      if (!suspension_.empty()) {
        events.push_back(EncodableMap{
            {EncodableValue("kind"), EncodableValue("suspended")},
            {EncodableValue("code"), EncodableValue(suspension_)},
        });
        suspension_.clear();
      }
      FlvaEvent event{};
      for (int i = 0; i < 31 && flva_poll(session_, &event); ++i) {
        events.push_back(EncodableMap{
            {EncodableValue("sequence"),
             EncodableValue(static_cast<int64_t>(event.sequence))},
            {EncodableValue("generation"),
             EncodableValue(static_cast<int64_t>(event.generation))},
            {EncodableValue("kind"), EncodableValue(std::string(event.kind))},
            {EncodableValue("activity"),
             EncodableValue(std::string(event.activity))},
            {EncodableValue("code"), EncodableValue(std::string(event.code))},
            {EncodableValue("text"), EncodableValue(std::string(event.text))},
        });
      }
      result->Success(events);
      return;
    }
    result->NotImplemented();
  }

  void StartAudio(std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    if (running_.load()) {
      result->Success();
      return;
    }
    const OpenResult capture = OpenCapture();
    if (capture != OpenResult::kOk) {
      // Capture-open denial must not start render.
      StopAudio();
      if (capture == OpenResult::kPermissionDenied) {
        Log("FLVA start refused permissionDenied");
        result->Error("permissionDenied", "Microphone permission denied");
        return;
      }
      result->Error("audioUnavailable", "Audio input is unavailable");
      return;
    }
    const OpenResult render = OpenRender();
    if (render != OpenResult::kOk) {
      StopAudio();
      result->Error("audioUnavailable", "Audio output is unavailable");
      return;
    }
    if (!flva_start(session_)) {
      StopAudio();
      result->Error("invalidState", "Native start failed");
      return;
    }
    accept_audio_.store(true);
    HRESULT hr = capture_client_->Start();
    if (FAILED(hr)) {
      accept_audio_.store(false);
      StopAudio();
      flva_stop(session_);
      if (IsAccessDenied(hr)) {
        Log("FLVA start refused permissionDenied hr=0x%08lx",
            static_cast<unsigned long>(hr));
        result->Error("permissionDenied", "Microphone permission denied");
        return;
      }
      result->Error("audioUnavailable", "Audio input failed to start");
      return;
    }
    hr = render_client_->Start();
    if (FAILED(hr)) {
      accept_audio_.store(false);
      StopAudio();
      flva_stop(session_);
      result->Error("audioUnavailable", "Audio output failed to start");
      return;
    }
    running_.store(true);
    capture_thread_ = std::thread([this] { CaptureLoop(); });
    render_thread_ = std::thread([this] { RenderLoop(); });
    Log("FLVA startAudio inputRate=%d captureChannels=%d outputRate=%d renderDirect=%d",
        input_rate_, capture_format_.channels, flva_output_rate(session_),
        render_direct_float_ ? 1 : 0);
    result->Success();
  }

  OpenResult OpenCapture() {
    if (!enumerator_) return OpenResult::kUnavailable;
    IMMDevice *device = nullptr;
    HRESULT hr =
        enumerator_->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
    if (FAILED(hr) || !device) return OpenResult::kUnavailable;
    capture_device_.reset(device);

    IAudioClient *client = nullptr;
    hr = capture_device_->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                   reinterpret_cast<void **>(&client));
    if (IsAccessDenied(hr)) return OpenResult::kPermissionDenied;
    if (FAILED(hr) || !client) return OpenResult::kUnavailable;
    capture_client_.reset(client);

    WAVEFORMATEX desired = MakeMonoFloat(input_rate_);
    const DWORD flags = AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
                        AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                        AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
    hr = capture_client_->Initialize(AUDCLNT_SHAREMODE_SHARED, flags, 200000, 0,
                                     &desired, nullptr);
    if (FAILED(hr)) {
      capture_client_.reset();
      client = nullptr;
      hr = capture_device_->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                     reinterpret_cast<void **>(&client));
      if (IsAccessDenied(hr)) return OpenResult::kPermissionDenied;
      if (FAILED(hr) || !client) return OpenResult::kUnavailable;
      capture_client_.reset(client);
      WAVEFORMATEX *mix = nullptr;
      hr = capture_client_->GetMixFormat(&mix);
      if (FAILED(hr) || !mix) return OpenResult::kUnavailable;
      std::unique_ptr<WAVEFORMATEX, CoTaskFree> format(mix);
      if (static_cast<int>(format->nSamplesPerSec) != input_rate_) {
        Log("FLVA capture mix rate changed want=%d got=%u", input_rate_,
            static_cast<unsigned>(format->nSamplesPerSec));
        return OpenResult::kUnavailable;
      }
      hr = capture_client_->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                       AUDCLNT_STREAMFLAGS_EVENTCALLBACK, 200000,
                                       0, format.get(), nullptr);
      if (IsAccessDenied(hr)) return OpenResult::kPermissionDenied;
      if (FAILED(hr)) return OpenResult::kUnavailable;
      capture_format_ = ParseWaveFormat(format.get());
      capture_direct_float_ = false;
    } else {
      capture_format_ = DeviceFormat{input_rate_, 1, 32, true, 4};
      capture_direct_float_ = true;
    }

    capture_event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    if (!capture_event_) return OpenResult::kUnavailable;
    hr = capture_client_->SetEventHandle(capture_event_);
    if (FAILED(hr)) return OpenResult::kUnavailable;

    IAudioCaptureClient *capture = nullptr;
    hr = capture_client_->GetService(__uuidof(IAudioCaptureClient),
                                     reinterpret_cast<void **>(&capture));
    if (FAILED(hr) || !capture) return OpenResult::kUnavailable;
    capture_.reset(capture);
    return OpenResult::kOk;
  }

  OpenResult OpenRender() {
    if (!enumerator_ || !session_) return OpenResult::kUnavailable;
    IMMDevice *device = nullptr;
    HRESULT hr =
        enumerator_->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    if (FAILED(hr) || !device) return OpenResult::kUnavailable;
    render_device_.reset(device);

    IAudioClient *client = nullptr;
    hr = render_device_->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                  reinterpret_cast<void **>(&client));
    if (FAILED(hr) || !client) return OpenResult::kUnavailable;
    render_client_.reset(client);

    const int output_rate = flva_output_rate(session_);
    WAVEFORMATEX desired = MakeMonoFloat(output_rate);
    const DWORD flags = AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
                        AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                        AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;
    hr = render_client_->Initialize(AUDCLNT_SHAREMODE_SHARED, flags, 200000, 0,
                                    &desired, nullptr);
    if (FAILED(hr)) {
      render_client_.reset();
      client = nullptr;
      hr = render_device_->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                    reinterpret_cast<void **>(&client));
      if (FAILED(hr) || !client) return OpenResult::kUnavailable;
      render_client_.reset(client);
      WAVEFORMATEX *mix = nullptr;
      hr = render_client_->GetMixFormat(&mix);
      if (FAILED(hr) || !mix) return OpenResult::kUnavailable;
      std::unique_ptr<WAVEFORMATEX, CoTaskFree> format(mix);
      hr = render_client_->Initialize(AUDCLNT_SHAREMODE_SHARED,
                                      AUDCLNT_STREAMFLAGS_EVENTCALLBACK, 200000,
                                      0, format.get(), nullptr);
      if (FAILED(hr)) return OpenResult::kUnavailable;
      render_format_ = ParseWaveFormat(format.get());
      render_direct_float_ = false;
    } else {
      render_format_ = DeviceFormat{output_rate, 1, 32, true, 4};
      render_direct_float_ = true;
    }

    render_event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    if (!render_event_) return OpenResult::kUnavailable;
    hr = render_client_->SetEventHandle(render_event_);
    if (FAILED(hr)) return OpenResult::kUnavailable;
    hr = render_client_->GetBufferSize(&render_buffer_frames_);
    if (FAILED(hr) || render_buffer_frames_ == 0) return OpenResult::kUnavailable;

    IAudioRenderClient *render = nullptr;
    hr = render_client_->GetService(__uuidof(IAudioRenderClient),
                                    reinterpret_cast<void **>(&render));
    if (FAILED(hr) || !render) return OpenResult::kUnavailable;
    render_.reset(render);
    return OpenResult::kOk;
  }

  void CaptureLoop() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    DWORD task_index = 0;
    HANDLE task = AvSetMmThreadCharacteristicsW(L"Pro Audio", &task_index);
    std::vector<float> mono(512);
    int callbacks = 0;
    while (accept_audio_.load()) {
      const DWORD wait = WaitForSingleObject(capture_event_, 200);
      if (!accept_audio_.load()) break;
      if (wait == WAIT_TIMEOUT) continue;
      UINT32 packet = 0;
      HRESULT hr = capture_->GetNextPacketSize(&packet);
      if (IsDeviceInvalidated(hr)) {
        Log("FLVA capture invalidated hr=0x%08lx", static_cast<unsigned long>(hr));
        Suspend("audioUnavailable");
        break;
      }
      if (FAILED(hr)) {
        if (accept_audio_.load()) Suspend("audioUnavailable");
        break;
      }
      while (packet > 0 && accept_audio_.load()) {
        BYTE *data = nullptr;
        UINT32 frames = 0;
        DWORD flags = 0;
        hr = capture_->GetBuffer(&data, &frames, &flags, nullptr, nullptr);
        if (IsDeviceInvalidated(hr)) {
          Log("FLVA capture invalidated hr=0x%08lx",
              static_cast<unsigned long>(hr));
          Suspend("audioUnavailable");
          packet = 0;
          break;
        }
        if (FAILED(hr)) {
          if (accept_audio_.load()) Suspend("audioUnavailable");
          packet = 0;
          break;
        }
        if (frames > 0 && session_ && accept_audio_.load()) {
          if (mono.size() < frames) mono.resize(frames);
          if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) || !data) {
            memset(mono.data(), 0, frames * sizeof(float));
          } else if (capture_direct_float_) {
            memcpy(mono.data(), data, frames * sizeof(float));
          } else {
            ToMonoFloat32(data, frames, capture_format_, mono.data());
          }
          // Audio thread: flva_push of converted mono float32. No PCM on the channel.
          const int pushed = flva_push(session_, mono.data(), static_cast<int32_t>(frames));
          ++callbacks;
          if (pushed == 0 || (callbacks % 100) == 1) {
            Log("FLVA capture callbacks=%d frames=%u rms=%.4f push=%d", callbacks,
                static_cast<unsigned>(frames), Rms(mono.data(), static_cast<int>(frames)),
                pushed);
          }
        }
        capture_->ReleaseBuffer(frames);
        hr = capture_->GetNextPacketSize(&packet);
        if (FAILED(hr)) {
          if (IsDeviceInvalidated(hr)) Suspend("audioUnavailable");
          else if (accept_audio_.load()) Suspend("audioUnavailable");
          break;
        }
      }
    }
    if (task) AvRevertMmThreadCharacteristics(task);
    CoUninitialize();
  }

  void RenderLoop() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    DWORD task_index = 0;
    HANDLE task = AvSetMmThreadCharacteristicsW(L"Pro Audio", &task_index);
    std::vector<float> mono(512);
    while (accept_audio_.load()) {
      const DWORD wait = WaitForSingleObject(render_event_, 200);
      if (!accept_audio_.load()) break;
      if (wait == WAIT_TIMEOUT) continue;
      UINT32 padding = 0;
      HRESULT hr = render_client_->GetCurrentPadding(&padding);
      if (IsDeviceInvalidated(hr)) {
        Log("FLVA render invalidated hr=0x%08lx", static_cast<unsigned long>(hr));
        Suspend("audioUnavailable");
        break;
      }
      if (FAILED(hr)) {
        if (accept_audio_.load()) Suspend("audioUnavailable");
        break;
      }
      const UINT32 available =
          render_buffer_frames_ > padding ? render_buffer_frames_ - padding : 0;
      if (available == 0) continue;
      BYTE *data = nullptr;
      hr = render_->GetBuffer(available, &data);
      if (IsDeviceInvalidated(hr)) {
        Log("FLVA render invalidated hr=0x%08lx", static_cast<unsigned long>(hr));
        Suspend("audioUnavailable");
        break;
      }
      if (FAILED(hr) || !data) {
        if (accept_audio_.load()) Suspend("audioUnavailable");
        break;
      }
      if (session_ && accept_audio_.load()) {
        if (render_direct_float_) {
          // Audio thread: flva_render writes mono float32. No PCM on the channel.
          flva_render(session_, reinterpret_cast<float *>(data),
                      static_cast<int32_t>(available));
        } else {
          UINT32 need = available;
          if (render_format_.sample_rate > 0) {
            const int output_rate = flva_output_rate(session_);
            need = static_cast<UINT32>(
                (static_cast<double>(available) *
                 static_cast<double>(output_rate)) /
                    static_cast<double>(render_format_.sample_rate) +
                2.0);
          }
          if (mono.size() < need) mono.resize(need);
          flva_render(session_, mono.data(), static_cast<int32_t>(need));
          FromMonoFloat32(mono.data(), need, flva_output_rate(session_), data,
                          available, render_format_);
        }
      } else {
        memset(data, 0, static_cast<size_t>(available) * render_format_.block_align);
      }
      render_->ReleaseBuffer(available, 0);
    }
    if (task) AvRevertMmThreadCharacteristics(task);
    CoUninitialize();
  }

  void StopAudio() {
    accept_audio_.store(false);
    running_.store(false);
    if (session_) flva_interrupt(session_);
    if (capture_event_) SetEvent(capture_event_);
    if (render_event_) SetEvent(render_event_);
    if (capture_thread_.joinable()) capture_thread_.join();
    if (render_thread_.joinable()) render_thread_.join();
    if (capture_client_) capture_client_->Stop();
    if (render_client_) render_client_->Stop();
    capture_.reset();
    render_.reset();
    capture_client_.reset();
    render_client_.reset();
    capture_device_.reset();
    render_device_.reset();
    if (capture_event_) {
      CloseHandle(capture_event_);
      capture_event_ = nullptr;
    }
    if (render_event_) {
      CloseHandle(render_event_);
      render_event_ = nullptr;
    }
    render_buffer_frames_ = 0;
    capture_direct_float_ = false;
    render_direct_float_ = false;
  }

  std::mutex mutex_;
  std::condition_variable cv_;
  std::deque<std::function<void()>> jobs_;
  std::thread control_;
  bool stop_control_ = false;
  std::atomic<int> pending_{0};

  ComRef<IMMDeviceEnumerator> enumerator_;
  DeviceWatcher *watcher_ = nullptr;

  FlvaSession *session_ = nullptr;
  int32_t input_rate_ = 48000;
  std::string vad_;
  std::string encoder_;
  std::string decoder_;
  std::string joiner_;
  std::string asr_tokens_;
  std::string tts_model_;
  std::string tts_tokens_;
  std::string tts_lexicon_;
  std::string llm_model_;
  std::string suspension_;

  std::atomic<bool> accept_audio_{false};
  std::atomic<bool> running_{false};
  ComRef<IMMDevice> capture_device_;
  ComRef<IAudioClient> capture_client_;
  ComRef<IAudioCaptureClient> capture_;
  ComRef<IMMDevice> render_device_;
  ComRef<IAudioClient> render_client_;
  ComRef<IAudioRenderClient> render_;
  HANDLE capture_event_ = nullptr;
  HANDLE render_event_ = nullptr;
  UINT32 render_buffer_frames_ = 0;
  DeviceFormat capture_format_{};
  DeviceFormat render_format_{};
  bool capture_direct_float_ = false;
  bool render_direct_float_ = false;
  std::thread capture_thread_;
  std::thread render_thread_;
};

void FlutterLocalVoiceAgentPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "flutter_local_voice_agent",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterLocalVoiceAgentPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterLocalVoiceAgentPlugin::FlutterLocalVoiceAgentPlugin()
    : impl_(std::make_unique<Impl>()) {}

FlutterLocalVoiceAgentPlugin::~FlutterLocalVoiceAgentPlugin() = default;

void FlutterLocalVoiceAgentPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  impl_->HandleMethodCall(method_call, std::move(result));
}

}  // namespace flutter_local_voice_agent
