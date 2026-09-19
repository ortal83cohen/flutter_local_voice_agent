#include "llm_adapter.h"

#include "llama.h"

#include <array>
#include <atomic>
#include <cstdint>
#include <deque>
#include <filesystem>
#include <mutex>
#include <stdexcept>
#include <string_view>
#include <utility>

namespace flva {
namespace {

constexpr size_t kMaxPromptBytes = 8192;

std::mutex g_backend_mutex;
size_t g_backend_users = 0;

bool EndsWith(std::string_view value, std::string_view suffix) {
  return value.size() >= suffix.size() &&
         value.substr(value.size() - suffix.size()) == suffix;
}

size_t UnicodeScalarStarts(std::string_view value) {
  size_t count = 0;
  for (const unsigned char byte : value) {
    if ((byte & 0xc0U) != 0x80U) {
      ++count;
    }
  }
  return count;
}

void TrimIncompleteUtf8(std::string* value) {
  size_t index = 0;
  while (index < value->size()) {
    const unsigned char lead = static_cast<unsigned char>((*value)[index]);
    size_t width = 0;
    if (lead <= 0x7fU) {
      width = 1;
    } else if (lead >= 0xc2U && lead <= 0xdfU) {
      width = 2;
    } else if (lead >= 0xe0U && lead <= 0xefU) {
      width = 3;
    } else if (lead >= 0xf0U && lead <= 0xf4U) {
      width = 4;
    } else {
      break;
    }
    if (index + width > value->size()) {
      break;
    }
    bool valid = true;
    for (size_t offset = 1; offset < width; ++offset) {
      valid = valid &&
          (static_cast<unsigned char>((*value)[index + offset]) & 0xc0U) == 0x80U;
    }
    if ((lead == 0xe0U && static_cast<unsigned char>((*value)[index + 1]) < 0xa0U) ||
        (lead == 0xedU && static_cast<unsigned char>((*value)[index + 1]) > 0x9fU) ||
        (lead == 0xf0U && static_cast<unsigned char>((*value)[index + 1]) < 0x90U) ||
        (lead == 0xf4U && static_cast<unsigned char>((*value)[index + 1]) > 0x8fU)) {
      valid = false;
    }
    if (!valid) {
      break;
    }
    index += width;
  }
  value->resize(index);
}

}  // namespace

struct LlmAdapter::Impl {
  struct Turn {
    std::string prompt;
    std::string reply;
  };

  llama_model* model = nullptr;
  llama_context* context = nullptr;
  llama_sampler* sampler = nullptr;
  const llama_vocab* vocab = nullptr;
  const Cancelled* active_cancel = nullptr;
  std::deque<Turn> prior_turns;
  bool backend_acquired = false;

  static bool Abort(void* data) {
    auto* impl = static_cast<Impl*>(data);
    if (impl == nullptr || impl->active_cancel == nullptr) {
      return false;
    }
    try {
      return (*impl->active_cancel)();
    } catch (...) {
      return true;
    }
  }

  void ResetAfterAbortedWork() {
    llama_memory_clear(llama_get_memory(context), true);
    llama_sampler_reset(sampler);
  }

  void Release() {
    if (sampler != nullptr) {
      llama_sampler_free(sampler);
      sampler = nullptr;
    }
    if (context != nullptr) {
      llama_free(context);
      context = nullptr;
    }
    if (model != nullptr) {
      llama_model_free(model);
      model = nullptr;
    }
    if (backend_acquired) {
      std::lock_guard<std::mutex> lock(g_backend_mutex);
      if (--g_backend_users == 0) {
        llama_backend_free();
      }
      backend_acquired = false;
    }
  }
};

LlmAdapter::LlmAdapter(const std::string& local_model_path) : impl_(new Impl()) {
  const std::filesystem::path path(local_model_path);
  if (local_model_path.empty() || !EndsWith(local_model_path, ".gguf") ||
      !std::filesystem::is_regular_file(path)) {
    throw std::runtime_error("llm model must be an existing local .gguf file");
  }

  {
    std::lock_guard<std::mutex> lock(g_backend_mutex);
    if (g_backend_users++ == 0) {
      llama_backend_init();
    }
    impl_->backend_acquired = true;
  }

  try {
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    impl_->model = llama_model_load_from_file(local_model_path.c_str(), model_params);
    if (impl_->model == nullptr) {
      throw std::runtime_error("llm failed to load local GGUF model");
    }
    impl_->vocab = llama_model_get_vocab(impl_->model);
    if (impl_->vocab == nullptr) {
      throw std::runtime_error("llm model has no vocabulary");
    }

    llama_context_params context_params = llama_context_default_params();
    context_params.n_ctx = kMaxContextTokens;
    context_params.n_batch = kMaxContextTokens;
    context_params.n_ubatch = kMaxContextTokens;
    context_params.n_threads = kThreads;
    context_params.n_threads_batch = kThreads;
    context_params.offload_kqv = false;
    context_params.abort_callback = &Impl::Abort;
    context_params.abort_callback_data = impl_.get();
    impl_->context = llama_init_from_model(impl_->model, context_params);
    if (impl_->context == nullptr) {
      throw std::runtime_error("llm failed to create bounded context");
    }

    llama_sampler_chain_params sampler_params = llama_sampler_chain_default_params();
    impl_->sampler = llama_sampler_chain_init(sampler_params);
    if (impl_->sampler == nullptr) {
      throw std::runtime_error("llm failed to create sampler");
    }
    llama_sampler_chain_add(impl_->sampler, llama_sampler_init_greedy());
  } catch (...) {
    impl_->Release();
    throw;
  }
}

LlmAdapter::~LlmAdapter() {
  if (impl_ != nullptr) {
    impl_->Release();
  }
}

std::string LlmAdapter::Generate(const std::string& prompt, const Cancelled& cancelled) {
  if (!cancelled) {
    throw std::runtime_error("llm generation requires a cancellation callback");
  }
  if (prompt.empty() || prompt.size() > kMaxPromptBytes) {
    throw std::runtime_error("llm prompt is empty or exceeds bounded input bytes");
  }
  if (cancelled()) {
    throw std::runtime_error("llm generation cancelled");
  }

  std::string formatted="User: "+prompt+"\nAssistant:";
  std::array<llama_token,kMaxContextTokens> tokens{};
  int32_t token_count=llama_tokenize(impl_->vocab,formatted.c_str(),formatted.size(),tokens.data(),tokens.size(),true,true);
  if(token_count<0||token_count+kMaxOutputTokens>kMaxContextTokens)
    throw std::runtime_error("llm prompt exceeds bounded context");
  size_t included=0;
  for(auto it=impl_->prior_turns.rbegin();it!=impl_->prior_turns.rend();++it) {
    std::string candidate="User: "+it->prompt+"\nAssistant: "+it->reply+"\n"+formatted;
    if(candidate.size()>kMaxPromptBytes*(kMaxPriorTurns+1))break;
    std::array<llama_token,kMaxContextTokens> proposed{};
    const int n=llama_tokenize(impl_->vocab,candidate.c_str(),candidate.size(),proposed.data(),proposed.size(),true,true);
    if(n<0||n+kMaxOutputTokens>kMaxContextTokens)break;
    formatted=std::move(candidate);tokens=proposed;token_count=n;++included;
  }
  while(impl_->prior_turns.size()>included)impl_->prior_turns.pop_front();

  impl_->active_cancel = &cancelled;
  try {
    // Logical history is rebuilt in `formatted`; no prior request KV state may leak.
    impl_->ResetAfterAbortedWork();
    if (cancelled()) {
      throw std::runtime_error("llm generation cancelled");
    }
    llama_batch batch = llama_batch_get_one(tokens.data(), token_count);
    const int32_t prompt_result = llama_decode(impl_->context, batch);
    if (prompt_result == 2 || cancelled()) {
      impl_->ResetAfterAbortedWork();
      throw std::runtime_error("llm generation cancelled");
    }
    if (prompt_result != 0) {
      impl_->ResetAfterAbortedWork();
      throw std::runtime_error("llm prompt decode failed");
    }

    std::string reply;
    size_t scalar_count = 0;
    for (int generated = 0; generated < kMaxOutputTokens; ++generated) {
      if (cancelled()) {
        impl_->ResetAfterAbortedWork();
        throw std::runtime_error("llm generation cancelled");
      }
      llama_token token = llama_sampler_sample(impl_->sampler, impl_->context, -1);
      if (llama_vocab_is_eog(impl_->vocab, token)) {
        break;
      }

      std::array<char, kMaxReplyBytes> piece{};
      const int32_t piece_size = llama_token_to_piece(
          impl_->vocab, token, piece.data(), static_cast<int32_t>(piece.size()), 0, true);
      if (piece_size < 0 || reply.size() + static_cast<size_t>(piece_size) > kMaxReplyBytes ||
          scalar_count + UnicodeScalarStarts(std::string_view(piece.data(), piece_size)) >
              kMaxReplyScalars) {
        break;
      }
      reply.append(piece.data(), static_cast<size_t>(piece_size));
      scalar_count += UnicodeScalarStarts(std::string_view(piece.data(), piece_size));

      if (cancelled()) {
        impl_->ResetAfterAbortedWork();
        throw std::runtime_error("llm generation cancelled");
      }
      batch = llama_batch_get_one(&token, 1);
      const int32_t decode_result = llama_decode(impl_->context, batch);
      if (decode_result == 2 || cancelled()) {
        impl_->ResetAfterAbortedWork();
        throw std::runtime_error("llm generation cancelled");
      }
      if (decode_result != 0) {
        impl_->ResetAfterAbortedWork();
        throw std::runtime_error("llm token decode failed");
      }
    }
    TrimIncompleteUtf8(&reply);
    if (reply.empty()) {
      throw std::runtime_error("llm produced an empty reply");
    }
    impl_->prior_turns.push_back({prompt, reply});
    while (impl_->prior_turns.size() > kMaxPriorTurns) {
      impl_->prior_turns.pop_front();
    }
    impl_->active_cancel = nullptr;
    return reply;
  } catch (...) {
    impl_->active_cancel = nullptr;
    throw;
  }
}

}  // namespace flva
