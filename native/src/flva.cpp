#include "flva.h"
#include "c-api.h"
#include "spsc_ring.h"
#include "resampler.h"
#include "utf8.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <deque>
#include <stdexcept>
#ifdef __ANDROID__
#include <android/log.h>
#define FLVA_NATIVE_LOG(...) __android_log_print(ANDROID_LOG_INFO, "FLVA", __VA_ARGS__)
#else
#define FLVA_NATIVE_LOG(...) ((void)0)
#endif
#ifdef FLVA_ENABLE_LLM
#include "llm_adapter.h"
#endif

namespace {

constexpr int kVadRate = 16000;
constexpr int kVadWindow = 512;
constexpr int kInputMs = 250;
constexpr int kOutputMs = 500;
// Keep enough audio to cover VAD decision latency and the beginning of a word.
constexpr int kPreRollSamples = 8000;
constexpr int kMaxUtteranceSamples = 20 * kVadRate;
constexpr int kMaxReplyBytes = 960;
constexpr int kMaxTtsSeconds = 10;
constexpr int kEventCapacity = 32;

using flva_internal::SpscRing;

struct RenderFrame { uint64_t generation; float sample; };
using CaptureFrame = RenderFrame;

void copy_text(char* target, size_t target_size, const char* source) {
  if (!source || !target_size) return;
  std::strncpy(target, source, target_size - 1);
  target[target_size - 1] = '\0';
}

struct GeneratedAudioDeleter {
  void operator()(const SherpaOnnxGeneratedAudio* audio) const {
    if (audio) SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
  }
};
using OwnedGeneratedAudio = std::unique_ptr<const SherpaOnnxGeneratedAudio, GeneratedAudioDeleter>;

class Session {
 public:
  explicit Session(const FlvaConfig& config)
      : config_(config), input_(static_cast<size_t>(config.input_rate) * kInputMs / 1000),
        output_(new SpscRing<RenderFrame>(kVadRate * kOutputMs / 1000)),
        vad_path_(config.vad ? config.vad : ""), encoder_path_(config.encoder ? config.encoder : ""),
        decoder_path_(config.decoder ? config.decoder : ""), joiner_path_(config.joiner ? config.joiner : ""),
        asr_tokens_path_(config.asr_tokens ? config.asr_tokens : ""), tts_model_path_(config.tts_model ? config.tts_model : ""),
        tts_tokens_path_(config.tts_tokens ? config.tts_tokens : ""), tts_lexicon_path_(config.tts_lexicon ? config.tts_lexicon : ""),
        llm_model_path_(config.llm_model ? config.llm_model : "") {
    config_.vad = vad_path_.c_str(); config_.encoder = encoder_path_.c_str(); config_.decoder = decoder_path_.c_str();
    config_.joiner = joiner_path_.c_str(); config_.asr_tokens = asr_tokens_path_.c_str();
    config_.tts_model = tts_model_path_.c_str(); config_.tts_tokens = tts_tokens_path_.c_str();
    config_.tts_lexicon = tts_lexicon_path_.c_str(); config_.llm_model = llm_model_path_.c_str();
  }
  ~Session() { shutdown(); destroy_engines(); }

  bool initialize(std::string* error) {
    if (config_.speaker_id < 0) { *error = "unsupportedProfile"; return false; }
    if (config_.input_rate < 8000 || config_.input_rate > 192000 || !config_.vad || !config_.encoder ||
        !config_.decoder || !config_.joiner || !config_.asr_tokens || !config_.tts_model ||
        !config_.tts_tokens || !config_.tts_lexicon) { *error = "invalidAsset"; return false; }
    if (std::string(SherpaOnnxGetVersionStr()) != "1.12.14") { *error = "unsupportedProfile"; return false; }
#ifdef FLVA_ENABLE_LLM
    if (!llm_model_path_.empty()) llm_ = std::make_unique<flva::LlmAdapter>(llm_model_path_);
#else
    if (!llm_model_path_.empty()) { *error = "unsupportedProfile"; return false; }
#endif
    const char* paths[] = {config_.vad, config_.encoder, config_.decoder, config_.joiner, config_.asr_tokens,
                           config_.tts_model, config_.tts_tokens, config_.tts_lexicon};
    for (const char* path : paths) if (!path[0] || !SherpaOnnxFileExists(path)) { *error = "missingAsset"; return false; }

    SherpaOnnxVadModelConfig vad{};
    // A slightly more sensitive onset avoids clipping the first syllable on
    // quiet mobile microphones. Background-noise qualification remains a
    // device-level check.
    vad.silero_vad = {config_.vad, 0.38f, 0.5f, 0.25f, kVadWindow, 20.0f};
    vad.sample_rate = kVadRate; vad.num_threads = 1; vad.provider = "cpu";
    vad_ = SherpaOnnxCreateVoiceActivityDetector(&vad, 21.0f);

    SherpaOnnxOnlineRecognizerConfig asr{};
    asr.feat_config = {kVadRate, 80};
    asr.model_config.transducer = {config_.encoder, config_.decoder, config_.joiner};
    asr.model_config.tokens = config_.asr_tokens; asr.model_config.num_threads = 1;
    asr.model_config.provider = "cpu"; asr.decoding_method = "greedy_search";
    asr.enable_endpoint = 1; asr.rule1_min_trailing_silence = 2.4f;
    asr.rule2_min_trailing_silence = 0.8f; asr.rule3_min_utterance_length = 20.0f;
    recognizer_ = SherpaOnnxCreateOnlineRecognizer(&asr);
    if (recognizer_) stream_ = SherpaOnnxCreateOnlineStream(recognizer_);

    SherpaOnnxOfflineTtsConfig tts{};
    tts.model.vits = {config_.tts_model, config_.tts_lexicon, config_.tts_tokens, "", 0.667f, 0.8f, 1.0f, ""};
    tts.model.num_threads = 1; tts.model.provider = "cpu"; tts.max_num_sentences = 1;
    tts_ = SherpaOnnxCreateOfflineTts(&tts);
    if (!vad_ || !recognizer_ || !stream_ || !tts_) { *error = "invalidAsset"; destroy_engines(); return false; }
    output_rate_ = SherpaOnnxOfflineTtsSampleRate(tts_);
    if (output_rate_ <= 0 || output_rate_ > 192000) { *error = "unsupportedProfile"; destroy_engines(); return false; }
    if (config_.speaker_id >= tts_speaker_count()) { *error = "unsupportedProfile"; destroy_engines(); return false; }
    speaker_id_.store(config_.speaker_id, std::memory_order_relaxed);
    output_.reset(new SpscRing<RenderFrame>(static_cast<size_t>(output_rate_) * kOutputMs / 1000));
    worker_ = std::thread(&Session::run, this);
    std::unique_lock<std::mutex> ready(work_mutex_);
    work_cv_.wait(ready,[&]{return worker_observed_generation_.load()!=0 || worker_exited_.load();});
    return !worker_exited_.load();
  }

  int output_rate() const { return output_rate_; }
  int start() {
    if (closed_.load() || worker_exited_.load()) return 0;
    bool expected = false;
    if (!started_.compare_exchange_strong(expected, true)) return 1;
    capture_admission_.store(true);
    publish("state", "listening", "", "", generation_.load()); wake(); return 1;
  }
  uint64_t interrupt() {
    const uint64_t next = generation_.fetch_add(1) + 1;
    // Only the respective SPSC consumers discard their cursors. Generations
    // make already queued frames inaudible until the worker observes this.
    discontinuity_.store(false); cancelled_.store(true); capture_admission_.store(false); wake();
    publish("state", "idle", "", "", next); return next;
  }
  void stop() {
    if (closed_.load()) return;
    started_.store(false); capture_admission_.store(false); const uint64_t stopped_generation = interrupt();
    std::unique_lock<std::mutex> lock(work_mutex_);
    work_cv_.wait(lock, [&] { return worker_exited_.load() || (worker_observed_generation_.load() >= stopped_generation && !worker_busy_.load()); });
  }
  void shutdown() {
    if (closed_.exchange(true)) return;
    interrupt(); quitting_.store(true); wake();
    if (worker_.joinable()) worker_.join();
  }
  int push(const float* frames, int count) {
    if (!frames || count <= 0 || closed_.load() || !started_.load() || !capture_admission_.load()) return 0;
    if (static_cast<size_t>(count) > input_.free()) { capacity_failure(); return 0; }
    for (int i=0;i<count;++i) if (!std::isfinite(frames[i])) { capacity_failure(); return 0; }
    const auto generation=generation_.load();
    std::array<CaptureFrame,256> chunk{};
    for (int offset=0;offset<count;) {
      const int n=std::min(256,count-offset);
      for(int i=0;i<n;++i) chunk[i]={generation,frames[offset+i]};
      input_.push_all(chunk.data(),n); offset+=n;
    }
    return 1;
  }
  void render(float* frames, int count) {
    if (!frames || count <= 0) return;
    const uint64_t active = generation_.load(std::memory_order_acquire);
    for (int i=0;i<count;++i) {
      RenderFrame item{};
      frames[i]=(output_->pop(&item,1)==1 && item.generation==generation_.load(std::memory_order_acquire) && started_.load()) ? item.sample : 0.0f;
    }
    if (active!=generation_.load(std::memory_order_acquire)) std::fill(frames,frames+count,0.0f);
  }
  int reply(uint64_t generation, const char* text) {
    if (!text || !text[0] || strnlen(text, kMaxReplyBytes + 1) > kMaxReplyBytes || !flva_internal::valid_utf8_and_scalar_limit(text, 240)) return 0;
    std::lock_guard<std::mutex> lock(command_mutex_);
    if (closed_.load() || generation != generation_.load() || generation != awaited_reply_) return 0;
    reply_ = text; reply_generation_ = generation; awaited_reply_ = 0;
    publish("reply", "thinking", "", text, generation); wake(); return 1;
  }
  int32_t set_speaker_id(int32_t speaker_id, std::string* error) {
    if (!tts_) { if (error) *error = "unsupportedProfile"; return 0; }
    if (speaker_id < 0 || speaker_id >= tts_speaker_count()) { if (error) *error = "unsupportedProfile"; return 0; }
    speaker_id_.store(speaker_id, std::memory_order_release);
    return 1;
  }
  int poll(FlvaEvent* event) {
    if (!event) return 0;
    std::lock_guard<std::mutex> lock(events_mutex_);
    if (terminal_fault_) {
      std::memset(event,0,sizeof(*event));event->sequence=++sequence_;event->generation=generation_.load();
      copy_text(event->kind,sizeof(event->kind),"error");copy_text(event->activity,sizeof(event->activity),"idle");
      copy_text(event->code,sizeof(event->code),"capacityExceeded");copy_text(event->text,sizeof(event->text),"Native capacity exceeded; session stopped");
      terminal_fault_=false;return 1;
    }
    if (!event_count_) return 0;
    *event = events_[event_read_]; event_read_ = (event_read_ + 1) % kEventCapacity; --event_count_; return 1;
  }

 private:
  // Sherpa reports 0 for single-speaker VITS; only sid 0 is valid in that case.
  int32_t tts_speaker_count() const {
    if (!tts_) return 0;
    const int32_t raw = SherpaOnnxOfflineTtsNumSpeakers(tts_);
    return raw > 0 ? raw : 1;
  }
  void destroy_engines() {
    if (stream_) SherpaOnnxDestroyOnlineStream(stream_); stream_ = nullptr;
    if (recognizer_) SherpaOnnxDestroyOnlineRecognizer(recognizer_); recognizer_ = nullptr;
    if (vad_) SherpaOnnxDestroyVoiceActivityDetector(vad_); vad_ = nullptr;
    if (tts_) SherpaOnnxDestroyOfflineTts(tts_); tts_ = nullptr;
  }
  void wake() { work_cv_.notify_one(); }
  void capacity_failure() { discontinuity_.store(true); cancelled_.store(true); wake(); }
  void publish(const char* kind, const char* activity, const char* code, const char* text, uint64_t generation) {
    std::lock_guard<std::mutex> lock(events_mutex_);
    if (std::strcmp(kind,"partial")==0) {
      for(int i=0;i<event_count_;++i) {
        auto& previous=events_[(event_read_+i)%kEventCapacity];
        if(previous.generation==generation && std::strcmp(previous.kind,"partial")==0) {
          copy_text(previous.text,sizeof(previous.text),text);
          FLVA_NATIVE_LOG(
              "event kind=%s sequence=%llu generation=%llu activity=%s textLength=%zu",
              previous.kind, static_cast<unsigned long long>(previous.sequence),
              static_cast<unsigned long long>(previous.generation), previous.activity,
              strnlen(previous.text, sizeof(previous.text)));
          return;
        }
      }
    }
    if (event_count_ == kEventCapacity) {
      terminal_fault_=true;event_count_=0;event_read_=event_write_=0;
      event_overflow_.store(true);cancelled_.store(true);generation_.fetch_add(1);capture_admission_.store(false);started_.store(false);return;
    }
    FlvaEvent& event = events_[event_write_]; std::memset(&event, 0, sizeof(event));
    event.sequence = ++sequence_; event.generation = generation; copy_text(event.kind, sizeof(event.kind), kind);
    copy_text(event.activity, sizeof(event.activity), activity); copy_text(event.code, sizeof(event.code), code);
    copy_text(event.text, sizeof(event.text), text); event_write_ = (event_write_ + 1) % kEventCapacity; ++event_count_;
    FLVA_NATIVE_LOG(
        "event kind=%s sequence=%llu generation=%llu activity=%s textLength=%zu",
        event.kind, static_cast<unsigned long long>(event.sequence),
        static_cast<unsigned long long>(event.generation), event.activity,
        strnlen(event.text, sizeof(event.text)));
  }
  void reset_turn() {
    SherpaOnnxVoiceActivityDetectorReset(vad_);
    if(stream_) SherpaOnnxDestroyOnlineStream(stream_);
    stream_=SherpaOnnxCreateOnlineStream(recognizer_);
    if(!stream_) throw std::runtime_error("Cannot reset recognizer stream");
    vad_samples_.clear();utterance_samples_=0;pre_roll_.clear();partial_.clear();in_speech_=false;
    {std::lock_guard<std::mutex> lock(command_mutex_);awaited_reply_=0;reply_.clear();reply_generation_=0;}
    cancelled_.store(false);
  }
  void accept_resampled(const float* samples, int count, uint64_t generation) {
    for(int i=0;i<count;++i) {
      if(generation!=generation_.load() || cancelled_.load() || !capture_admission_.load())return;
      vad_samples_.push_back(samples[i]);
      if(vad_samples_.size()!=kVadWindow)continue;
      for(float sample:vad_samples_) {pre_roll_.push_back(sample);if(pre_roll_.size()>kPreRollSamples)pre_roll_.pop_front();}
      SherpaOnnxVoiceActivityDetectorAcceptWaveform(vad_,vad_samples_.data(),kVadWindow);
      const bool speaking=SherpaOnnxVoiceActivityDetectorDetected(vad_)!=0;
      bool began=false;
      if(speaking && !in_speech_) {
        in_speech_=true;began=true;utterance_samples_=0;
        publish("state","recognizing","","",generation);
        FLVA_NATIVE_LOG("vad speech onset generation=%llu", static_cast<unsigned long long>(generation));
        std::array<float,kPreRollSamples> history{};std::copy(pre_roll_.begin(),pre_roll_.end(),history.begin());
        SherpaOnnxOnlineStreamAcceptWaveform(stream_,kVadRate,history.data(),static_cast<int>(pre_roll_.size()));
      }
      if(in_speech_) {
        if(!began)SherpaOnnxOnlineStreamAcceptWaveform(stream_,kVadRate,vad_samples_.data(),kVadWindow);
        utterance_samples_+=kVadWindow;decode_partial(generation);
        if(utterance_samples_>=kMaxUtteranceSamples) {
          publish("error","idle","utteranceTooLong","Utterance limit reached",generation);
          generation_.fetch_add(1);capture_admission_.store(false);vad_samples_.clear();return;
        }
      }
      while(!SherpaOnnxVoiceActivityDetectorEmpty(vad_))SherpaOnnxVoiceActivityDetectorPop(vad_);
      vad_samples_.clear();
      if(in_speech_&&!speaking){finish_transcript(generation);return;}
    }
  }
  void decode_partial(uint64_t generation) {
    while(generation==generation_.load()&&!cancelled_.load()&&SherpaOnnxIsOnlineStreamReady(recognizer_,stream_))SherpaOnnxDecodeOnlineStream(recognizer_,stream_);
    if(generation!=generation_.load()||cancelled_.load())return;
    auto* result=SherpaOnnxGetOnlineStreamResult(recognizer_,stream_);
    if(!result)return;
    const char* text=result->text?result->text:"";
    if(strnlen(text,2048)>=2048){SherpaOnnxDestroyOnlineRecognizerResult(result);capacity_failure();return;}
    std::string now=text;SherpaOnnxDestroyOnlineRecognizerResult(result);
    // Some mobile/runtime combinations expose only the newest decoded span
    // instead of the complete stream result. Preserve already decoded words
    // when the new result is a non-overlapping suffix, while still allowing
    // normal online-ASR revisions and retractions.
    const std::string before = partial_;
    if (!now.empty() && !partial_.empty() &&
        now.find(partial_) == std::string::npos &&
        partial_.find(now) == std::string::npos) {
      partial_ += " ";
      partial_ += now;
    } else if (!now.empty() &&
               (partial_.empty() || now.size() >= partial_.size() ||
                now != partial_)) {
      partial_ = now;
    }
    if(before!=partial_){publish("partial","recognizing","",partial_.c_str(),generation);}
  }
  void finish_transcript(uint64_t generation) {
    capture_admission_.store(false);in_speech_=false;
    std::array<float,4800> tail{};
    SherpaOnnxOnlineStreamAcceptWaveform(stream_,kVadRate,tail.data(),tail.size());
    SherpaOnnxOnlineStreamInputFinished(stream_);decode_partial(generation);
    if(generation!=generation_.load()||cancelled_.load())return;
    if(partial_.empty()){generation_.fetch_add(1);return;}
    {std::lock_guard<std::mutex> lock(command_mutex_);awaited_reply_=generation;}
    publish("final","thinking","",partial_.c_str(),generation);
#ifdef FLVA_ENABLE_LLM
    if(llm_) {
      try {
        auto answer=llm_->Generate(partial_,[&]{return generation!=generation_.load()||cancelled_.load();});
        if(generation==generation_.load()&&!cancelled_.load()&&!reply(generation,answer.c_str()))throw std::runtime_error("LLM produced an empty or unsupported reply");
      }catch(const std::exception& e){
        if(generation==generation_.load()){publish("error","idle","inferenceFailed",e.what(),generation);generation_.fetch_add(1);}
      }
    }
#endif
  }
  struct SynthesisContext { Session* session; uint64_t generation; int admitted = 0; };
  static int32_t tts_callback(const float* samples, int32_t count, void* opaque) {
    SynthesisContext* context = static_cast<SynthesisContext*>(opaque);
    return context->session->admit_tts(samples, count, context);
  }
  int32_t admit_tts(const float* samples, int count, SynthesisContext* context) {
    const int maximum = kMaxTtsSeconds * output_rate_;
    for (int offset = 0; offset < count; ) {
      if(context->generation!=generation_.load()||cancelled_.load())return 0;
      if(context->admitted>=maximum){publish("error","idle","capacityExceeded","TTS duration exceeded",context->generation);generation_.fetch_add(1);capture_admission_.store(false);return 0;}
      const int chunk = std::min({256, count - offset, maximum - context->admitted});
      std::array<RenderFrame, 256> frames{};
      for (int i = 0; i < chunk; ++i) frames[i] = {context->generation, samples[offset + i]};
      if(output_->push_all(frames.data(),chunk)) {
        if(context->admitted==0)publish("state","speaking","","",context->generation);
        offset+=chunk;context->admitted+=chunk;continue;
      }
      std::unique_lock<std::mutex> lock(work_mutex_);
      work_cv_.wait_for(lock, std::chrono::milliseconds(10));
    }
    return 1;
  }
  void synthesize_reply(uint64_t generation, const std::string& text) {
    if (generation != generation_.load() || cancelled_.load()) return;
    // Snapshot the id so an in-flight utterance keeps the speaker it started with.
    const int32_t speaker_id = speaker_id_.load(std::memory_order_acquire);
    SynthesisContext context{this, generation};
    // The engine returns owned audio even when its callback cooperatively
    // cancels. RAII releases it on every exit path.
    OwnedGeneratedAudio audio(SherpaOnnxOfflineTtsGenerateWithCallbackWithArg(
        tts_, text.c_str(), speaker_id, 1.0f, &Session::tts_callback, &context));
    if (!audio) {
      if (generation == generation_.load() && !cancelled_.load()) publish("error", "idle", "inferenceFailed", "", generation);
      generation_.fetch_add(1);return;
    }
    if (generation == generation_.load() && !cancelled_.load()) {
      while (output_->available() && generation == generation_.load() && !cancelled_.load()) {
        std::unique_lock<std::mutex> lock(work_mutex_); work_cv_.wait_for(lock, std::chrono::milliseconds(10));
      }
      if(!cancelled_.load()&&generation==generation_.load()) {
        // A conservative residual-device-buffer guard; acoustic tail is unqualified.
        auto until=std::chrono::steady_clock::now()+std::chrono::milliseconds(250);
        while(std::chrono::steady_clock::now()<until && generation==generation_.load())std::this_thread::sleep_for(std::chrono::milliseconds(2));
        if(generation==generation_.load())generation_.fetch_add(1);
      }
    }
  }
  void run() noexcept {
    try { run_worker(); }
    catch(const std::exception& e){started_.store(false);capture_admission_.store(false);generation_.fetch_add(1);publish("error","idle","inferenceFailed",e.what(),generation_.load());}
    catch(...){started_.store(false);capture_admission_.store(false);generation_.fetch_add(1);publish("error","idle","inferenceFailed","Native worker failed",generation_.load());}
    worker_exited_.store(true);worker_busy_.store(false);wake();
  }
  void run_worker() {
    std::array<CaptureFrame,4096> raw{};
    std::array<float,8194> resampled{};std::array<float,4096> input{};
    flva_internal::Resampler converter(config_.input_rate,kVadRate);
    uint64_t seen_generation=0;
    while(!quitting_.load()) {
      if(event_overflow_.exchange(false)||discontinuity_.exchange(false)) {
        started_.store(false);capture_admission_.store(false);generation_.fetch_add(1);
        std::lock_guard<std::mutex> lock(events_mutex_);terminal_fault_=true;event_count_=0;event_read_=event_write_=0;
      }
      const auto current=generation_.load();
      if(current!=seen_generation) {
        input_.discard();reset_turn();seen_generation=current;converter.reset();
        worker_observed_generation_.store(current);worker_busy_.store(false);
        capture_admission_.store(started_.load());
        if(started_.load())publish("state","listening","","",current);
        wake();
      }
      std::string answer;
      {std::lock_guard<std::mutex> lock(command_mutex_);if(reply_generation_==current&&!reply_.empty()){answer.swap(reply_);reply_generation_=0;}}
      if(!answer.empty()){worker_busy_.store(true);synthesize_reply(current,answer);worker_busy_.store(false);wake();continue;}
      const size_t n=input_.pop(raw.data(),raw.size());
      if(n && started_.load() && capture_admission_.load()) {
        worker_busy_.store(true);
        int valid=0;for(size_t i=0;i<n;++i)if(raw[i].generation==current)input[valid++]=raw[i].sample;
        if(config_.input_rate==kVadRate){if(valid)accept_resampled(input.data(),valid,current);}
        else {
          const int count=converter.process(input.data(),valid,resampled.data(),resampled.size());
          if(count<0)throw std::runtime_error("Resampler capacity exceeded");
          if(count)accept_resampled(resampled.data(),count,current);
        }
        worker_busy_.store(false);wake();continue;
      }
      std::unique_lock<std::mutex> lock(work_mutex_);work_cv_.wait_for(lock,std::chrono::milliseconds(2));
    }
  }

#ifdef FLVA_ENABLE_LLM
  std::unique_ptr<flva::LlmAdapter> llm_;
#endif
  FlvaConfig config_{};
  SpscRing<CaptureFrame> input_;
  std::unique_ptr<SpscRing<RenderFrame>> output_;
  const SherpaOnnxVoiceActivityDetector* vad_ = nullptr;
  const SherpaOnnxOnlineRecognizer* recognizer_ = nullptr;
  const SherpaOnnxOnlineStream* stream_ = nullptr;
  const SherpaOnnxOfflineTts* tts_ = nullptr;
  std::atomic<int32_t> speaker_id_{0};
  int output_rate_ = kVadRate;
  std::thread worker_; std::mutex work_mutex_; std::condition_variable work_cv_;
  std::atomic<bool> started_{false}, capture_admission_{false}, closed_{false}, quitting_{false}, cancelled_{false}, discontinuity_{false}, event_overflow_{false};
  std::atomic<uint64_t> generation_{1};
  std::atomic<bool> worker_exited_{false};
  std::atomic<uint64_t> worker_observed_generation_{0}; std::atomic<bool> worker_busy_{false};
  std::mutex command_mutex_; uint64_t awaited_reply_ = 0, reply_generation_ = 0; std::string reply_;
  std::mutex events_mutex_; std::array<FlvaEvent, kEventCapacity> events_{}; int event_read_ = 0, event_write_ = 0, event_count_ = 0; uint64_t sequence_ = 0; bool terminal_fault_=false;
  std::vector<float> vad_samples_; std::deque<float> pre_roll_; bool in_speech_ = false; int utterance_samples_ = 0; std::string partial_;
  std::string vad_path_, encoder_path_, decoder_path_, joiner_path_, asr_tokens_path_;
  std::string tts_model_path_, tts_tokens_path_, tts_lexicon_path_, llm_model_path_;
};
}  // namespace

struct FlvaSession { Session impl; explicit FlvaSession(const FlvaConfig& config) : impl(config) {} };
extern "C" FlvaSession* flva_create(const FlvaConfig* config, char* error, int32_t error_capacity) {
  if (error && error_capacity > 0) error[0] = '\0';
  if(!config || config->input_rate<8000 || config->input_rate>192000) {if(error&&error_capacity>0)copy_text(error,error_capacity,"invalidAsset");return nullptr;}
  if (config->speaker_id < 0) { if (error && error_capacity > 0) copy_text(error, error_capacity, "unsupportedProfile"); return nullptr; }
  try {
  std::unique_ptr<FlvaSession> session(new FlvaSession(*config)); std::string reason;
  if (!session->impl.initialize(&reason)) { if (error) copy_text(error, error_capacity, reason.c_str()); return nullptr; }
  return session.release();
  }catch(const std::exception& e){if(error&&error_capacity>0)copy_text(error,error_capacity,e.what());return nullptr;}
  catch(...){if(error&&error_capacity>0)copy_text(error,error_capacity,"inferenceFailed");return nullptr;}
}
extern "C" int32_t flva_set_speaker_id(FlvaSession* session, int32_t speaker_id, char* error, int32_t error_capacity) {
  if (error && error_capacity > 0) error[0] = '\0';
  if (!session) { if (error && error_capacity > 0) copy_text(error, error_capacity, "unsupportedProfile"); return 0; }
  std::string reason;
  const int32_t ok = session->impl.set_speaker_id(speaker_id, &reason);
  if (!ok && error && error_capacity > 0) copy_text(error, error_capacity, reason.c_str());
  return ok;
}
extern "C" int32_t flva_output_rate(const FlvaSession* session) { return session ? session->impl.output_rate() : 0; }
extern "C" int32_t flva_start(FlvaSession* session) { return session ? session->impl.start() : 0; }
extern "C" uint64_t flva_interrupt(FlvaSession* session) { return session ? session->impl.interrupt() : 0; }
extern "C" void flva_stop(FlvaSession* session) { if (session) session->impl.stop(); }
extern "C" void flva_destroy(FlvaSession* session) { delete session; }
extern "C" int32_t flva_reply(FlvaSession* session, uint64_t generation, const char* utf8) { return session ? session->impl.reply(generation, utf8) : 0; }
extern "C" int32_t flva_push(FlvaSession* session, const float* samples, int32_t frames) { return session ? session->impl.push(samples, frames) : 0; }
extern "C" void flva_render(FlvaSession* session, float* samples, int32_t frames) { if (session) session->impl.render(samples, frames); else if (samples && frames > 0) std::fill(samples, samples + frames, 0.0f); }
extern "C" int32_t flva_poll(FlvaSession* session, FlvaEvent* event) { return session ? session->impl.poll(event) : 0; }
