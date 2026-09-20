#ifndef FLVA_UTF8_H
#define FLVA_UTF8_H

#include <cstddef>
#include <string_view>

namespace flva_internal {

// Validate Unicode scalars, including shortest encodings and Unicode's upper
// bound. Reject embedded NUL because the native reply ABI uses C strings.
inline bool valid_utf8_and_scalar_limit(std::string_view value,
                                        size_t maximum_scalars) {
  size_t scalars = 0;
  for (size_t index = 0; index < value.size();) {
    const auto lead = static_cast<unsigned char>(value[index]);
    size_t width;
    if (lead > 0 && lead <= 0x7f) width = 1;
    else if (lead >= 0xc2 && lead <= 0xdf) width = 2;
    else if (lead >= 0xe0 && lead <= 0xef) width = 3;
    else if (lead >= 0xf0 && lead <= 0xf4) width = 4;
    else return false;
    if (width > value.size() - index) return false;
    for (size_t offset = 1; offset < width; ++offset) {
      if ((static_cast<unsigned char>(value[index + offset]) & 0xc0) != 0x80) return false;
    }
    if (width > 1) {
      const auto second = static_cast<unsigned char>(value[index + 1]);
      if ((lead == 0xe0 && second < 0xa0) ||
          (lead == 0xed && second > 0x9f) ||
          (lead == 0xf0 && second < 0x90) ||
          (lead == 0xf4 && second > 0x8f)) return false;
    }
    if (++scalars > maximum_scalars) return false;
    index += width;
  }
  return true;
}

}  // namespace flva_internal
#endif
