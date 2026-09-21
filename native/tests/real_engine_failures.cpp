#include "flva.h"

#include <array>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

struct WavHeader {
  char riff[4]; unsigned size; char wave[4]; char fmt[4]; unsigned fmt_size;
  unsigned short format, channels; unsigned sample_rate, byte_rate;
  unsigned short align, bits; char data[4]; unsigned data_size;
};

struct Assets {
  const char *vad, *encoder, *decoder, *joiner, *tokens, *tts_model, *tts_tokens, *tts_lexicon, *wav;
};

static int passed = 0;
static bool check(bool condition, const char* name) {
  std::printf("%s %s\n", condition ? "PASS" : "FAIL", name);
  if (condition) ++passed;
  return condition;
}

static FlvaConfig config(const Assets& a, int rate = 16000) {
  FlvaConfig c{};
  c.vad = a.vad; c.encoder = a.encoder; c.decoder = a.decoder; c.joiner = a.joiner;
  c.asr_tokens = a.tokens; c.tts_model = a.tts_model; c.tts_tokens = a.tts_tokens;
  c.tts_lexicon = a.tts_lexicon; c.llm_model = ""; c.input_rate = rate;
  return c;
}

static bool file_exists(const char* path) {
  if (!path || !path[0]) return false;
  FILE* file = std::fopen(path, "rb");
  if (!file) return false;
  std::fclose(file);
  return true;
}

static std::string sibling_file(const char* path, const char* name) {
  std::string directory = path ? path : "";
  const auto slash = directory.find_last_of("/\\");
  if (slash == std::string::npos) return name;
  return directory.substr(0, slash + 1) + name;
}

// Host inventory locations used by catalog/qualification fixtures. Absence is a
// catalog-asset gate, not a silent pass of the multi-speaker setter.
static const char* find_vctk_tts(const char* argv_tts) {
  if (argv_tts && std::strstr(argv_tts, "vctk")) return argv_tts;
  static std::string sibling_int8;
  static std::string sibling_full;
  sibling_int8 = sibling_file(argv_tts, "vits-vctk.int8.onnx");
  sibling_full = sibling_file(argv_tts, "vits-vctk.onnx");
  const char* candidates[] = {
    sibling_int8.c_str(),
    sibling_full.c_str(),
    "/private/tmp/flva-qualification/models/vits-vctk.int8.onnx",
    "/private/tmp/flva-qualification/models/vits-vctk.onnx",
    "/private/tmp/flva-catalog-installed/en-us-vctk-zipformer-int8/tts/vits-vctk.int8.onnx",
  };
  for (const char* path : candidates) if (file_exists(path)) return path;
  return nullptr;
}

static FlvaSession* create(const Assets& a) {
  char error[40]{};
  FlvaConfig c = config(a);
  FlvaSession* s = flva_create(&c, error, sizeof(error));
  if (!s) std::fprintf(stderr, "create failure: %s\n", error);
  return s;
}

static bool wait_for(FlvaSession* s, const char* kind, const char* activity, FlvaEvent* found, int timeout_ms) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout_ms);
  while (std::chrono::steady_clock::now() < deadline) {
    FlvaEvent event{};
    while (flva_poll(s, &event)) {
      if ((!kind || std::strcmp(event.kind, kind) == 0) && (!activity || std::strcmp(event.activity, activity) == 0)) {
        if (found) *found = event;
        return true;
      }
    }
    std::array<float, 256> render{};
    flva_render(s, render.data(), static_cast<int>(render.size()));
    std::this_thread::sleep_for(std::chrono::milliseconds(5));
  }
  return false;
}

static bool feed_wav_until_final(FlvaSession* s, const char* path, FlvaEvent* final) {
  FILE* file = std::fopen(path, "rb");
  if (!file) return false;
  WavHeader h{};
  if (std::fread(&h, sizeof(h), 1, file) != 1 || std::memcmp(h.riff, "RIFF", 4) || std::memcmp(h.wave, "WAVE", 4) ||
      h.format != 1 || h.channels != 1 || h.sample_rate != 16000 || h.bits != 16) { std::fclose(file); return false; }
  std::array<short, 512> pcm{}; std::array<float, 512> samples{};
  while (const size_t n = std::fread(pcm.data(), sizeof(short), pcm.size(), file)) {
    for (size_t i = 0; i != n; ++i) samples[i] = pcm[i] / 32768.0f;
    int retries = 0;
    while (!flva_push(s, samples.data(), static_cast<int>(n))) {
      FlvaEvent ignored{}; while (flva_poll(s, &ignored)) { if(std::strcmp(ignored.kind,"final")==0){*final=ignored;std::fclose(file);return true;} }
      if (++retries > 5000) { std::fclose(file); return false; }
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    FlvaEvent ignored{}; while (flva_poll(s, &ignored)) { if(std::strcmp(ignored.kind,"final")==0){*final=ignored;std::fclose(file);return true;} }
    std::this_thread::sleep_for(std::chrono::milliseconds(32));
  }
  std::fclose(file);
  samples.fill(0);
  for(int i=0;i<40;++i){
    flva_push(s,samples.data(),samples.size());
    FlvaEvent event{};while(flva_poll(s,&event)){if(std::strcmp(event.kind,"final")==0){*final=event;return true;}}
    std::this_thread::sleep_for(std::chrono::milliseconds(32));
  }
  return wait_for(s, "final", nullptr, final, 12000);
}

int main(int argc, char** argv) {
  if (argc != 10) {
    std::fprintf(stderr, "usage: failures vad encoder decoder joiner tokens tts-model tts-tokens tts-lexicon pcm16k.wav\n");
    return 64;
  }
  const Assets a{argv[1], argv[2], argv[3], argv[4], argv[5], argv[6], argv[7], argv[8], argv[9]};
  char error[40]{};
  FlvaConfig bad_path = config(a); bad_path.vad = "/private/tmp/flva-no-such-vad.onnx";
  check(flva_create(&bad_path, error, sizeof(error)) == nullptr && std::strcmp(error, "missingAsset") == 0, "missing path rejected");
  FlvaConfig bad_rate = config(a, 7999); std::memset(error, 0, sizeof(error));
  check(flva_create(&bad_rate, error, sizeof(error)) == nullptr && std::strcmp(error, "invalidAsset") == 0, "invalid input rate rejected");

  int expected = 19;
  FlvaConfig negative_speaker = config(a); negative_speaker.speaker_id = -1; std::memset(error, 0, sizeof(error));
  check(flva_create(&negative_speaker, error, sizeof(error)) == nullptr && std::strcmp(error, "unsupportedProfile") == 0,
        "create speaker_id -1 rejected");
  ++expected;
  FlvaConfig huge_speaker = config(a); huge_speaker.speaker_id = 100000; std::memset(error, 0, sizeof(error));
  check(flva_create(&huge_speaker, error, sizeof(error)) == nullptr && std::strcmp(error, "unsupportedProfile") == 0,
        "create speaker_id 100000 rejected");
  ++expected;
  FlvaConfig speaker_one = config(a); speaker_one.speaker_id = 1; std::memset(error, 0, sizeof(error));
  FlvaSession* multi = flva_create(&speaker_one, error, sizeof(error));
  if (multi) {
    flva_destroy(multi);
  } else {
    check(std::strcmp(error, "unsupportedProfile") == 0, "create speaker_id 1 rejected on single-speaker TTS");
    ++expected;
  }

  FlvaSession* s = create(a);
  if (!check(s != nullptr, "actual engine create")) return 1;
  std::memset(error, 0, sizeof(error));
  check(flva_set_speaker_id(s, 100000, error, sizeof(error)) == 0 && std::strcmp(error, "unsupportedProfile") == 0,
        "setter out of range rejected");
  ++expected;
  check(flva_output_rate(s) > 0, "failed setter leaves stored id and usable session");
  ++expected;
  check(flva_start(s) == 1 && flva_start(s) == 1, "double start idempotent");
  const uint64_t old = flva_interrupt(s);
  std::array<float, 512> silence{};
  bool accepted_after_interrupt = false;
  for (int i = 0; i < 500 && !accepted_after_interrupt; ++i) {
    accepted_after_interrupt = flva_push(s, silence.data(), static_cast<int>(silence.size())) == 1;
    std::this_thread::sleep_for(std::chrono::milliseconds(2));
  }
  check(accepted_after_interrupt, "interrupt resumes capture while started");
  check(flva_reply(s, old, "stale") == 0, "old generation reply refused");
  // Feed twice through real engines. A new final/reply pair must not reuse the
  // preceding stream's decoder state or generation.
  for (int turn = 0; turn != 2; ++turn) {
    FlvaEvent final{};
    const bool got_final = feed_wav_until_final(s, a.wav, &final);
    check(got_final && final.text[0], turn == 0 ? "first real final" : "second real final after reset");
    if (got_final && turn == 0) {
      std::string long_ascii(241, 'a');
      check(flva_reply(s, final.generation, long_ascii.c_str()) == 0, "241 scalars refused on awaited generation");
      const char* malformed[] = {"\xF0\x9F", "\xc0\xaf", "\xe0\x80\x80", "\xed\xa0\x80",
        "\xf0\x80\x80\x80", "\xf4\x90\x80\x80", "\xf5\x80\x80\x80", "\x80", "\xff"};
      bool rejected = true;
      for (auto text : malformed) rejected = (flva_reply(s, final.generation, text) == 0) && rejected;
      check(rejected, "malformed UTF-8 refused on awaited generation");
      check(flva_reply(s, final.generation, "") == 0, "empty reply refused on awaited generation");
      check(flva_reply(s, final.generation + 1, "hello") == 0, "wrong generation refused while awaiting reply");
    }
    if (got_final) {
      check(flva_reply(s, final.generation, "hello") == 1, turn == 0 ? "first real reply admitted" : "second real reply admitted");
      check(wait_for(s, "state", "listening", nullptr, 15000), turn == 0 ? "first playback drained" : "second playback drained");
    }
  }

  // Overflow must remain bounded and surface a capacity error; poll while
  // feeding so the fixed event lane itself is not the accidental test target.
  flva_interrupt(s);
  for(int i=0;i<500&&!flva_push(s,silence.data(),silence.size());++i)std::this_thread::sleep_for(std::chrono::milliseconds(2));
  std::array<float,4001> overflow{};
  flva_push(s,overflow.data(),overflow.size());
  check(wait_for(s, "error", nullptr, nullptr, 3000), "capture overflow surfaces error");
  std::array<float, 128> rendered{}; flva_render(s, rendered.data(), static_cast<int>(rendered.size()));
  bool all_silent = true; for (float sample : rendered) all_silent = all_silent && sample == 0.0f;
  check(all_silent, "cancelled generation renders silence");
  flva_stop(s); flva_stop(s); flva_destroy(s);
  check(true, "double stop and destroy after active worker");

  bool vctk_setter_ran = false;
  const char* vctk_tts = find_vctk_tts(a.tts_model);
  if (vctk_tts) {
    Assets vctk = a;
    vctk.tts_model = vctk_tts;
    FlvaSession* vs = create(vctk);
    std::memset(error, 0, sizeof(error));
    check(vs != nullptr && flva_set_speaker_id(vs, 7, error, sizeof(error)) == 1 && error[0] == '\0',
          "VCTK setter non-zero id");
    ++expected;
    vctk_setter_ran = true;
    if (vs) flva_destroy(vs);
  } else {
    std::printf("SKIP VCTK setter non-zero id: catalog-asset gate (VCTK TTS not in host inventory)\n");
  }

  std::printf("PASSED %d checks\n", passed);
  if (!vctk_setter_ran) std::printf("VCTK setter success skipped: catalog-asset gate, not a silent pass\n");
  return passed == expected ? 0 : 1;
}
