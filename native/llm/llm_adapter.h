#pragma once

#include <functional>
#include <memory>
#include <string>

namespace flva {

/// A serial-use, CPU-only local GGUF adapter. The caller owns serialization.
class LlmAdapter {
 public:
  static constexpr int kMaxContextTokens = 2048;
  static constexpr int kMaxOutputTokens = 128;
  static constexpr int kThreads = 2;
  static constexpr size_t kMaxReplyBytes = 960;
  static constexpr size_t kMaxReplyScalars = 240;
  static constexpr size_t kMaxPriorTurns = 8;

  using Cancelled = std::function<bool()>;

  explicit LlmAdapter(const std::string& local_model_path);
  ~LlmAdapter();

  LlmAdapter(const LlmAdapter&) = delete;
  LlmAdapter& operator=(const LlmAdapter&) = delete;

  /// Generates one bounded reply. Throws std::runtime_error on input, load,
  /// decode, cancellation, or output-limit failures.
  std::string Generate(const std::string& prompt, const Cancelled& cancelled);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace flva
