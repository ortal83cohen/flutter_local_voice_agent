#ifndef FLVA_SPSC_RING_H
#define FLVA_SPSC_RING_H

#include <algorithm>
#include <atomic>
#include <cstddef>
#include <vector>

namespace flva_internal {
// One producer and one consumer only. Producers either publish a whole frame
// range or nothing; consumers never observe a partially written range.
template <typename T> class SpscRing {
 public:
  explicit SpscRing(size_t capacity) : values_(capacity + 1), size_(capacity + 1) {}
  size_t capacity() const { return size_ - 1; }
  size_t available() const {
    const size_t r = read_.load(std::memory_order_acquire);
    const size_t w = write_.load(std::memory_order_acquire);
    return w >= r ? w - r : size_ - (r - w);
  }
  size_t free() const { return capacity() - available(); }
  bool push_all(const T* input, size_t count) {
    if (count > free()) return false;
    size_t w = write_.load(std::memory_order_relaxed);
    for (size_t i = 0; i != count; ++i) { values_[w] = input[i]; w = (w + 1) % size_; }
    write_.store(w, std::memory_order_release);
    return true;
  }
  size_t pop(T* output, size_t maximum) {
    const size_t count = std::min(maximum, available());
    size_t r = read_.load(std::memory_order_relaxed);
    for (size_t i = 0; i != count; ++i) { output[i] = values_[r]; r = (r + 1) % size_; }
    read_.store(r, std::memory_order_release);
    return count;
  }
  void discard() { read_.store(write_.load(std::memory_order_acquire), std::memory_order_release); }
 private:
  std::vector<T> values_;
  const size_t size_;
  std::atomic<size_t> read_{0}, write_{0};
};
}  // namespace flva_internal
#endif
