#include "flva.h"
#include <array>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <thread>
#include <vector>

struct WavHeader {
  char riff[4]; unsigned size; char wave[4]; char fmt[4]; unsigned fmt_size;
  unsigned short format, channels; unsigned sample_rate, byte_rate;
  unsigned short align, bits; char data[4]; unsigned data_size;
};

// This executable intentionally requires genuine sherpa assets and an actual
// mono 16 kHz PCM16 WAV. It has no fake-engine mode.
int main(int argc, char** argv) {
  if (argc != 10) { std::fprintf(stderr, "usage: smoke vad encoder decoder joiner tokens tts-model tts-tokens tts-lexicon pcm16k.wav\n"); return 64; }
  FlvaConfig c{};
  c.vad = argv[1]; c.encoder = argv[2]; c.decoder = argv[3]; c.joiner = argv[4];
  c.asr_tokens = argv[5]; c.tts_model = argv[6]; c.tts_tokens = argv[7];
  c.tts_lexicon = argv[8]; c.llm_model = ""; c.input_rate = 16000;
  char error[40]; FlvaSession* s = flva_create(&c, error, sizeof(error));
  if (!s) { std::fprintf(stderr, "create: %s\n", error); return 1; }
  FILE* f = std::fopen(argv[9], "rb"); if (!f) { flva_destroy(s); return 2; }
  WavHeader h{};
  if (std::fread(&h, sizeof(h), 1, f) != 1 || std::memcmp(h.riff, "RIFF", 4) || std::memcmp(h.wave, "WAVE", 4) ||
      std::memcmp(h.fmt, "fmt ", 4) || std::memcmp(h.data, "data", 4) || h.format != 1 || h.channels != 1 || h.sample_rate != 16000 || h.bits != 16) {
    std::fprintf(stderr, "requires canonical mono PCM16 16k WAV\n"); std::fclose(f); flva_destroy(s); return 3;
  }
  flva_start(s); std::vector<short> pcm(512); std::vector<float> frames(512);
  while (const size_t n = std::fread(pcm.data(), sizeof(short), pcm.size(), f)) {
    for (size_t i = 0; i < n; ++i) frames[i] = pcm[i] / 32768.0f;
    int retries = 0;
    while (!flva_push(s, frames.data(), static_cast<int>(n))) {
      if (++retries == 5000) { std::fprintf(stderr, "input admission timed out\n"); std::fclose(f); flva_stop(s); flva_destroy(s); return 7; }
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    // Keep the host fixture close to its capture cadence so a 250 ms native
    // ring tests bounded admission instead of relying on a giant offline push.
    std::this_thread::sleep_for(std::chrono::milliseconds(32));
  }
  std::fclose(f);
  std::fill(frames.begin(),frames.end(),0.0f);
  for(int i=0;i<32;++i){flva_push(s,frames.data(),512);std::this_thread::sleep_for(std::chrono::milliseconds(32));}
  bool final_seen = false, speaking_seen = false, playback_complete = false;
  for (int i = 0; i < 1500 && !playback_complete; ++i) {
    FlvaEvent event{};
    while (flva_poll(s, &event)) {
      std::fprintf(stderr, "%s %s %s\n", event.kind, event.code, event.text);
      if (std::strcmp(event.kind, "final") == 0) {
        final_seen = true;
        if (!flva_reply(s, event.generation, "hello world")) { flva_stop(s); flva_destroy(s); return 5; }
      }
      if (std::strcmp(event.activity, "speaking") == 0) speaking_seen = true;
      if (speaking_seen && std::strcmp(event.kind, "state") == 0 && std::strcmp(event.activity, "listening") == 0) playback_complete = true;
      if (std::strcmp(event.kind, "error") == 0) { flva_stop(s); flva_destroy(s); return 6; }
    }
    std::array<float, 256> rendered{}; flva_render(s, rendered.data(), static_cast<int>(rendered.size()));
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  flva_stop(s); flva_destroy(s);
  return final_seen && speaking_seen && playback_complete ? 0 : 4;
}
