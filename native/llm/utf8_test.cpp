#include "llm_adapter.cpp"

#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void ExpectTrimmed(const std::string& input, const std::string& expected) {
  std::string actual = input;
  flva::TrimIncompleteUtf8(&actual);
  if (actual != expected) {
    throw std::runtime_error("unexpected UTF-8 trim result");
  }
}

}  // namespace

int main() {
  try {
    ExpectTrimmed("plain", "plain");
    ExpectTrimmed("ok\xc2\xa2\xe2\x82\xac\xf0\x90\x8d\x88",
                  "ok\xc2\xa2\xe2\x82\xac\xf0\x90\x8d\x88");
    ExpectTrimmed("ok\xc2", "ok");
    ExpectTrimmed("ok\xe2", "ok");
    ExpectTrimmed("ok\xe2\x82", "ok");
    ExpectTrimmed("ok\xf0", "ok");
    ExpectTrimmed("ok\xf0\x90", "ok");
    ExpectTrimmed("ok\xf0\x90\x8d", "ok");
    ExpectTrimmed("ok\xe0\x80\x80", "ok");
    ExpectTrimmed("ok\x80", "ok");
    std::cout << "utf8_trim=ok\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "error=" << error.what() << "\n";
    return 1;
  }
}
