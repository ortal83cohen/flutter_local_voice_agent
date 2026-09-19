#ifndef FLVA_RESAMPLER_H
#define FLVA_RESAMPLER_H

#include <cmath>
#include <cstddef>
#include <cstdint>

namespace flva_internal {

// Fixed-memory, causal streaming windowed-sinc converter. It holds output
// until the symmetric FIR window is complete, so callers may partition input
// arbitrarily without changing samples. It is intentionally worker-only.
class Resampler {
 public:
  static constexpr int kTaps = 95;
  static constexpr int kHalf = kTaps / 2;

  Resampler(int input_rate, int output_rate)
      : input_rate_(input_rate), output_rate_(output_rate),
        valid_(input_rate >= 8000 && input_rate <= 192000 && output_rate >= 8000 && output_rate <= 192000) {
    if (!valid_) return;
    reset();
  }

  bool valid() const { return valid_; }
  void reset() { write_ = 0; total_ = 0; next_position_ = 0.0; for (float& s : history_) s = 0.0f; }

  // Returns output count, or -1 when output capacity is insufficient. In the
  // latter case no input or state is consumed. Capacity must be at least
  // ceil(n * output_rate/input_rate) + 2 for normal operation.
  int process(const float* input, int n, float* output, int capacity) {
    if (!valid_ || !input || n < 0 || !output || capacity < 0) return -1;
    const int needed = output_count_after(n);
    if (needed > capacity) return -1;
    int produced = 0;
    for (int i = 0; i < n; ++i) {
      push(input[i]);
      while (std::floor(next_position_) + kHalf < total_) {
        output[produced++] = interpolate(next_position_);
        next_position_ += static_cast<double>(input_rate_) / output_rate_;
      }
    }
    return produced;
  }

 private:
  static constexpr double kPi = 3.14159265358979323846264338327950288;
  int output_count_after(int additional) const {
    int count = 0; double position = next_position_; const int64_t end = total_ + additional;
    while (std::floor(position) + kHalf < end) { ++count; position += static_cast<double>(input_rate_) / output_rate_; }
    return count;
  }
  void push(float sample) { history_[write_] = sample; write_ = (write_ + 1) % kTaps; ++total_; }
  float at(int64_t index) const {
    if (index < 0 || index >= total_ || total_ - index > kTaps) return 0.0f;
    const int offset_from_latest = static_cast<int>(total_ - 1 - index);
    int slot = write_ - 1 - offset_from_latest; if (slot < 0) slot += kTaps;
    return history_[slot];
  }
  float interpolate(double position) const {
    const int64_t base = static_cast<int64_t>(std::floor(position));
    double sum = 0.0, gain = 0.0;
    for (int i = -kHalf; i <= kHalf; ++i) {
      const double delta = position - (base + i);
      const int tap = i + kHalf;
      const double window = 0.42 - 0.5 * std::cos(2.0 * kPi * tap / (kTaps - 1)) +
                            0.08 * std::cos(4.0 * kPi * tap / (kTaps - 1));
      const double cutoff = 0.47 * (input_rate_ > output_rate_
          ? static_cast<double>(output_rate_) / input_rate_ : 1.0);
      const double weight = (delta == 0.0 ? 2.0 * cutoff : std::sin(2.0 * kPi * cutoff * delta) / (kPi * delta)) * window;
      sum += at(base + i) * weight; gain += weight;
    }
    return static_cast<float>(gain == 0.0 ? 0.0 : sum / gain);
  }

  int input_rate_ = 0, output_rate_ = 0; bool valid_ = false;
  float history_[kTaps]{};
  int write_ = 0; int64_t total_ = 0; double next_position_ = 0.0;
};
}  // namespace flva_internal
#endif
