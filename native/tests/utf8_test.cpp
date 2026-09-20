#include "utf8.h"

#include <cstdio>
#include <cstdlib>
#include <string>
#include <string_view>

static void require(bool condition, const char* message) {
  if (!condition) { std::fprintf(stderr, "FAIL %s\n", message); std::exit(1); }
}

static std::string encode(unsigned scalar) {
  std::string value;
  if (scalar < 0x80) value += static_cast<char>(scalar);
  else if (scalar < 0x800) {
    value += static_cast<char>(0xc0 | (scalar >> 6));
    value += static_cast<char>(0x80 | (scalar & 63));
  } else if (scalar < 0x10000) {
    value += static_cast<char>(0xe0 | (scalar >> 12));
    value += static_cast<char>(0x80 | ((scalar >> 6) & 63));
    value += static_cast<char>(0x80 | (scalar & 63));
  } else {
    value += static_cast<char>(0xf0 | (scalar >> 18));
    value += static_cast<char>(0x80 | ((scalar >> 12) & 63));
    value += static_cast<char>(0x80 | ((scalar >> 6) & 63));
    value += static_cast<char>(0x80 | (scalar & 63));
  }
  return value;
}

int main() {
  using flva_internal::valid_utf8_and_scalar_limit;
  for (unsigned scalar = 1; scalar <= 0x10ffff; ++scalar) {
    const auto encoded = encode(scalar);
    const bool is_scalar = scalar < 0xd800 || scalar > 0xdfff;
    require(valid_utf8_and_scalar_limit(encoded, 1) == is_scalar,
            "Unicode scalar exhaustive validation");
    require(!valid_utf8_and_scalar_limit(encoded, 0), "zero scalar budget");
    for (size_t length = 1; length < encoded.size(); ++length) {
      require(!valid_utf8_and_scalar_limit(std::string_view(encoded).substr(0, length), 1),
              "truncated sequence refused");
    }
  }
  const char* malformed[] = {"\xc0\xaf", "\xc1\xbf", "\xe0\x80\x80", "\xed\xa0\x80",
    "\xf0\x80\x80\x80", "\xf4\x90\x80\x80", "\xf5\x80\x80\x80", "\x80", "\xff",
    "\xe2\x28\xa1", "\xf0\x90\x28\x80"};
  for (auto value : malformed) require(!valid_utf8_and_scalar_limit(value, 240), "malformed UTF-8 refused");
  require(!valid_utf8_and_scalar_limit(std::string_view("a\0b", 3), 240), "embedded NUL refused");
  for (const unsigned scalar : {0x61U, 0xa2U, 0x20acU, 0x10ffffU}) {
    std::string reply;
    for (int i = 0; i < 240; ++i) reply += encode(scalar);
    require(valid_utf8_and_scalar_limit(reply, 240), "240 scalars admitted");
    reply += encode(scalar);
    require(!valid_utf8_and_scalar_limit(reply, 240), "241 scalars refused");
  }
  std::puts("PASS UTF-8 exhaustive scalars, malformed sequences, truncation and reply limits");
}
