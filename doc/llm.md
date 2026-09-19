# Optional local LLM

The speech-only build excludes llama.cpp. An optional native adapter uses
llama.cpp commit `987498f4592a76897863cf53711dce38380c082b` (tag b10976), CPU only.
The source archive hash is fixed in `tool/provision_llama.py`.

```sh
python3 tool/provision_llama.py /absolute/build-inputs/llama.cpp
```

This is an explicit build-time download; `--archive` accepts a verified local
archive without network access. It is never called by the app.

## Android

Set these Gradle project properties in your host's `android/gradle.properties`:

```properties
flvaEnableLocalLlm=ON
flvaLlamaSource=/absolute/build-inputs/llama.cpp
```

Rebuild the app. Add the local GGUF as a manifest entry with role `llmModel`,
its byte length, SHA-256, precise source revision and actual license reference.
Create the agent with `useLocalLlm: true`; no Dart reply function runs in that
mode. A speech-only build explicitly rejects this configuration.

## iOS

Build an optional static XCFramework with `tool/build_llm_ios.py` using the
pinned local source, then place it at `ios/Frameworks/flva-llm.xcframework`.
Run `FLVA_ENABLE_LOCAL_LLM=1 pod install` in the host iOS project. The flag must
also be supplied whenever CocoaPods regenerates that project. Source and binary
provisioning are build operations, not runtime downloads.

## Limits and semantics

One native worker owns the model, context and sampler. CPU inference uses two
threads, at most 2,048 context tokens and 128 output tokens. Input and complete
history are bounded, with at most eight previous turns. Output is at most 240
Unicode scalars and 960 UTF-8 bytes. Older turns are evicted to fit context;
an oversized current prompt fails instead of being silently truncated.

Cancellation is checked around decode and sampling and via the CPU abort
callback. Output generation invalidation prevents stale speech independently
of how quickly inference stops. GPU backends and arbitrary tool execution are
not supported. Text is supplied as plain conversational context; this preview
is not a general chat-template registry or a safety policy for taking actions.

The temporary host fixture was TinyLlama 1.1B Chat Q2_K from TheBloke's GGUF
repository at revision `52e7645ba7c309695bec7ac98f4f005b139cf465`, hash
`030a469a63576d59f601ef5608846b7718eaa884dd820e9aa7493efec1788afa`.
This is test provenance, not an approved distributed model. No GGUF is bundled.
Generation quality, mobile memory/thermal behavior and supported model templates
remain qualification gates.
