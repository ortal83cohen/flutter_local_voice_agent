---
id: pipeline-research-llm
title: "LLM adapter feasibility: pinned llama.cpp C API"
status: draft
owner: root
last_verified: 2026-09-19
applies_to: ["**"]
summary: Implementation work artifact and evidence boundaries.
---

# LLM adapter feasibility: pinned llama.cpp C API

## Question

Can the optional local-LLM adapter use a bounded, native-owned llama.cpp C API
path while leaving the speech-only build free of an LLM runtime and model?

## Answer

Yes, as a conditional native adapter. Select the upstream `b10976` source tag
(the official release identifies its commit as `987498f`) for the integration
spike, but do not call it a production-supply-chain pin until the checkout
records the full 40-character commit object and archive hash. The tagged public
C header has the needed model/context lifecycle, token loop, explicit context
limits, and CPU-only decode abort callback.

The adapter must compile behind an `ENABLE_LOCAL_LLM` build flag. The native
worker exclusively owns the model, context, sampler, cancellation flag, and
output buffer; no GGUF is downloaded or bundled by this research task. The
speech-only variant must omit the llama.cpp target, bridge, model preflight, and
model asset entirely.

## Sources / pin / API

### Selected runtime pin

- **Selected integration source:** `ggml-org/llama.cpp` tag `b10976`, released
  2026-09-15. Its official release page identifies commit prefix `987498f`,
  marks it GPG-verified, and lists Android arm64 CPU plus an iOS XCFramework.
  Source: <https://github.com/ggml-org/llama.cpp/releases/tag/b10976>.
- **Immutability gate:** the public release page exposes only the abbreviated
  commit ID. Resolve and record the full object ID before vendoring or locking;
  that full ID is currently [UNVERIFIED] because this workspace could not reach
  GitHub through `git`. A moving branch name must never be used.
- The upstream README declares the runtime MIT-licensed. Source:
  <https://github.com/ggml-org/llama.cpp/blob/master/README.md>. This does not
  settle third-party files selected by optional backends; keep only the CPU path
  in the first spike unless its complete notice inventory is captured.

### Verified C API surface at `b10976`

The tag's `include/llama.h` provides:

- `llama_backend_init` / `llama_backend_free` once per native runtime process;
  `llama_model_default_params`, `llama_context_default_params`,
  `llama_model_load_from_file`, `llama_init_from_model`, `llama_free`, and
  `llama_model_free` for explicit lifecycle. Source:
  <https://raw.githubusercontent.com/ggml-org/llama.cpp/b10976/include/llama.h>.
- `llama_model_get_vocab`, `llama_tokenize`, `llama_batch_get_one`,
  `llama_decode`, `llama_sampler_chain_init`, sampler-chain addition,
  `llama_sampler_sample`, `llama_token_to_piece`, and `llama_vocab_is_eog` for
  the bounded token loop. The upstream tagged simple example demonstrates this
  sequence with a local `-m model.gguf` path. Source:
  <https://raw.githubusercontent.com/ggml-org/llama.cpp/b10976/examples/simple/simple.cpp>.
- `llama_context_params.n_ctx` and `n_batch`; the header defines `n_batch` as
  the logical maximum batch submitted to `llama_decode`. The adapter sets both
  explicitly rather than accepting model defaults. Source:
  <https://raw.githubusercontent.com/ggml-org/llama.cpp/b10976/include/llama.h>.
- `abort_callback` in context parameters and `llama_set_abort_callback`; the
  header says a true callback result aborts `llama_decode` and that it currently
  works only with CPU execution. `llama_decode` documents return code `2` for
  aborted work and warns that processed micro-batches remain in context memory.
  Source: <https://raw.githubusercontent.com/ggml-org/llama.cpp/b10976/include/llama.h>.

## Build dependencies

### Android and iOS route

Build llama.cpp as a native static library from the locked source checkout and
link it only into the LLM-enabled Android/iOS native target. The primary path is
CPU arm64: it is the configuration represented by the selected official Android
release. Do not enable OpenCL, Vulkan, CUDA, server, tools, examples, tests, or
the embedded UI for this adapter spike.

The current upstream CMake project builds `ggml` and `src` as the core library,
while common utilities, tests, examples, tools, and the app are separately
gated. Its CMake options include `LLAMA_BUILD_TESTS`, `LLAMA_BUILD_TOOLS`,
`LLAMA_BUILD_EXAMPLES`, and `LLAMA_BUILD_APP`. Source:
<https://github.com/ggml-org/llama.cpp/blob/master/CMakeLists.txt>. The exact
option inventory must be rechecked against the locked `b10976` checkout before
adding Gradle or Xcode build files; upstream APIs and CMake flags evolve.

For iOS, the selected tag's release distributes an iOS XCFramework; upstream's
current `build-xcframework.sh` requires CMake 3.28+ and `xcrun`. Source:
<https://github.com/ggml-org/llama.cpp/blob/master/build-xcframework.sh>.
For Android, provide the NDK toolchain, `arm64-v8a`, and the project deployment
floor through CMake. Upstream's Android OpenCL example shows the required NDK
toolchain inputs, but is deliberately not a dependency of the CPU route. Source:
<https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md>.

Proposed bounded CMake invocation after source checkout (not executed here):

    cmake -S vendor/llama.cpp -B build/llama-android-arm64 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" -DANDROID_ABI=arm64-v8a -DBUILD_SHARED_LIBS=OFF -DLLAMA_BUILD_COMMON=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_APP=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_UI=OFF
    cmake --build build/llama-android-arm64

This is a proposed command, not successful build evidence. It is deliberately
not a command for downloading a model or enabling a network server.

## Cancellation and limits

### Required worker contract

1. At adapter creation, verify that the supplied path is a regular local
   `.gguf` file inside the host-approved local model location. Reject URLs,
   missing files, oversize files, unsupported extension, and paths outside the
   approved root. The adapter makes no download request.
2. Construct exactly one model and one context on the LLM worker. Serialize all
   calls that touch them; expose no llama.cpp pointer to Dart or another worker.
3. Before decode, tokenize the completed bounded prompt. Reject it if its token
   count plus `maxOutputTokens` exceeds explicit `maxContextTokens`; configure
   `n_ctx = maxContextTokens` and a positive `n_batch` no larger than that
   limit. Do not silently truncate a user prompt.
4. Install the tag-supported abort callback to read the worker cancellation
   flag. The flag must be checked before prompt processing, before every
   `llama_decode`, after every decode, and before appending each sampled token.
   Handle `llama_decode == 2` as cancellation, clear/recreate context state
   before accepting another request, and never reuse a potentially partial KV
   state.
5. Generate at most `maxOutputTokens`, stop on EOG, and append each token piece
   only while both a maximum UTF-8 byte count and the caller's reply-text limit
   permit it. Return the bounded completed text or a typed cancellation/limit
   result. Never allow generation to spill into an unbounded native string or
   Dart message.
6. On stop or disposal, invalidate the request generation, wait for the worker
   to leave llama.cpp, then free sampler, context, and model on that same worker.
   The upstream header limits abort-callback effectiveness to CPU; GPU routes
   require an independent cancellation qualification and are out of scope.

### Model and fixture status

`TinyLlama/TinyLlama-1.1B-Chat-v1.0` is a small (1B-parameter) proposed model
for a local-only feasibility fixture. Its publisher lists Apache-2.0, and the
separate `TinyModel/TinyLlama-1.1B-Chat-v1.0-GGUF` repository also lists
Apache-2.0. Sources:
<https://huggingface.co/TinyLlama/TinyLlama-1.1B-Chat-v1.0> and
<https://huggingface.co/TinyModel/TinyLlama-1.1B-Chat-v1.0-GGUF>.

That is source metadata, not shipping approval. The exact GGUF filename,
repository revision, SHA-256, notices, provenance of the conversion, acceptable
quality, and redistribution decision remain unrecorded. The workspace contains
no `.gguf`, `.onnx`, or `.bin` fixture, so neither model loading nor inference
has been executed.

## Exact commands / output evidence

Read-only local evidence, run 2026-09-19:

    $ git ls-remote https://github.com/ggml-org/llama.cpp.git refs/tags/b10976 refs/tags/b10976^{}
    fatal: unable to access 'https://github.com/ggml-org/llama.cpp.git/': Could not resolve host: github.com

    $ find . -type f \( -iname '*.gguf' -o -iname '*.bin' -o -iname '*.onnx' \) -print
    [no output]

    $ rg -n "assets:|flutter_local_voice_agent|name:" pubspec.yaml
    1:name: library_name

The first command prevents resolving the full immutable SHA in this environment.
The second and third show no local fixture and no present package asset route.
No source checkout, CMake configure, native build, model load, token generation,
or device run has passed; each is [UNVERIFIED].

## Unresolved

- [UNRESOLVED: Resolve `b10976` to its full 40-character commit object and lock the exact source archive hash before implementation.]
- [UNRESOLVED: Verify `b10976` CMake option names by configuring the locked checkout for Android and iOS CPU arm64.]
- [UNRESOLVED: Choose exact `maxContextTokens`, `maxOutputTokens`, maximum reply bytes, model-file-size ceiling, and worker thread count from target-device budgets.]
- [UNRESOLVED: Select a precise GGUF file, revision, SHA-256, conversion provenance, notices, and redistribution approval after legal review.]
- [UNRESOLVED: Prove CPU abort latency, state recovery after return code `2`, memory bounds, offline-with-network-denied behavior, and lifecycle disposal on physical Android and iOS devices.]
