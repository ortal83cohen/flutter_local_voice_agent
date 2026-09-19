#include "llm_adapter.h"

#include <atomic>
#include <iostream>
#include <stdexcept>
#include <string>

int main(int argc, char** argv) {
  if (argc != 2) {
    std::cerr << "usage: flva_llm_smoke /absolute/path/to/model.gguf\n";
    return 64;
  }

  try {
    flva::LlmAdapter adapter(argv[1]);
    const std::string reply = adapter.Generate(
        "Reply with only the word offline.", [] { return false; });
    if (reply.empty() || reply.size() > flva::LlmAdapter::kMaxReplyBytes) {
      throw std::runtime_error("smoke received an invalid bounded reply");
    }
    std::cout << "reply=" << reply << "\n";

    std::string decode_prompt;
    for (int index = 0; index < 1024; ++index) {
      decode_prompt += " a";
    }
    std::atomic<int> cancellation_checks{0};
    try {
      static_cast<void>(adapter.Generate(
          decode_prompt,
          [&cancellation_checks] { return cancellation_checks.fetch_add(1) >= 2; }));
      throw std::runtime_error("cancellation unexpectedly completed");
    } catch (const std::runtime_error& error) {
      if (std::string(error.what()) != "llm generation cancelled") {
        throw;
      }
    }
    if (cancellation_checks.load() < 3) {
      throw std::runtime_error("cancellation callback did not reach llama_decode");
    }
    std::cout << "cancellation_during_decode=ok checks="
              << cancellation_checks.load() << "\n";

    std::string over_context_prompt;
    for (int index = 0; index < flva::LlmAdapter::kMaxContextTokens; ++index) {
      over_context_prompt += " a";
    }
    try {
      static_cast<void>(adapter.Generate(
          over_context_prompt, [] { return false; }));
      throw std::runtime_error("over-context prompt unexpectedly completed");
    } catch (const std::runtime_error& error) {
      if (std::string(error.what()) != "llm prompt exceeds bounded context") {
        throw;
      }
    }
    std::cout << "over_context=ok\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "error=" << error.what() << "\n";
    return 1;
  }
}
