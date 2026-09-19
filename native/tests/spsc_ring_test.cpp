#include "spsc_ring.h"

#include <array>
#include <cassert>
#include <thread>

using flva_internal::SpscRing;

int main() {
  SpscRing<int> ring(4);
  const std::array<int, 4> first{1, 2, 3, 4};
  const std::array<int, 1> too_many{5};
  assert(ring.push_all(first.data(), first.size()));
  assert(!ring.push_all(too_many.data(), too_many.size()));  // bounded overflow rejects all.
  std::array<int, 2> first_out{};
  assert(ring.pop(first_out.data(), first_out.size()) == 2);
  assert((first_out == std::array<int, 2>{1, 2}));
  const std::array<int, 2> second{5, 6};
  assert(ring.push_all(second.data(), second.size()));  // wraps at physical end.
  std::array<int, 4> all{};
  assert(ring.pop(all.data(), all.size()) == 4);
  assert((all == std::array<int, 4>{3, 4, 5, 6}));
  assert(ring.pop(all.data(), all.size()) == 0);  // underflow is bounded.

  SpscRing<int> race(256);
  constexpr int kCount = 256;
  std::thread producer([&] {
    for (int n = 0; n < kCount;) { const int value = n; if (race.push_all(&value, 1)) ++n; }
  });
  for (int expected = 0; expected < kCount;) {
    int value = -1;
    if (race.pop(&value, 1)) { assert(value == expected); ++expected; }
  }
  producer.join();
  return 0;
}
