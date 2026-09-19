#include "resampler.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <vector>

using flva_internal::Resampler;
static std::vector<float> run(Resampler& r, const std::vector<float>& in, int block) {
  std::vector<float> result; std::vector<float> out(100000);
  for (size_t i = 0; i < in.size(); i += block) { int n = static_cast<int>(std::min<size_t>(block, in.size() - i)); int k = r.process(in.data() + i, n, out.data(), static_cast<int>(out.size())); assert(k >= 0); result.insert(result.end(), out.begin(), out.begin() + k); }
  return result;
}
int main() {
  assert(!Resampler(7999, 16000).valid()); assert(!Resampler(192001, 16000).valid());
  Resampler bounded(48000, 16000); float one = 0, out[1]; assert(bounded.process(&one, 1, out, -1) == -1);
  std::vector<float> dc(48000, 0.75f); Resampler a(48000, 16000), b(48000, 16000);
  const auto whole = run(a, dc, 48000), split = run(b, dc, 37); assert(whole.size() == split.size());
  for (size_t i = 0; i < whole.size(); ++i) assert(std::fabs(whole[i] - split[i]) < 1e-5f);
  double mean = 0; for (size_t i = 100; i < whole.size(); ++i) mean += whole[i]; mean /= whole.size() - 100; assert(std::fabs(mean - .75) < .01);
  std::vector<float> high(48000); for (int i = 0; i < 48000; ++i) high[i] = std::sin(2 * 3.141592653589793 * 10000 * i / 48000.0);
  Resampler hf(48000, 16000); const auto filtered = run(hf, high, 113); double rms = 0; for (size_t i = 100; i < filtered.size(); ++i) rms += filtered[i] * filtered[i]; rms = std::sqrt(rms / (filtered.size() - 100)); std::printf("high-frequency rms=%f\n", rms); assert(rms < .12);
  std::vector<float> low(8000, .5f); Resampler up(8000, 16000); const auto doubled = run(up, low, 29); assert(doubled.size() > 15000 && doubled.size() < 16000); up.reset(); const auto reset = run(up, low, 8000); assert(reset.size() == doubled.size());
  std::puts("PASS resampler partition DC attenuation upsample reset invalid capacity");
}
