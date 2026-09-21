# Explicit model preparation

The preparation API is an infrastructure layer for hosts that already have a
trusted model descriptor and a persistent, application-private directory. It
returns the same `LocalModelBundle` used by `LocalVoiceAgent.create`.

The companion `VoiceModelCatalog` supplies three pinned English
configurations: LJS compact, LJS standard, and compact VCTK (109 speakers,
integer ids 0-108). VCTK is a speaker choice, not a language or quality
ranking. Speaker labels are integer ids. Piper, other languages and
physical-device quality remain outside this catalog. The example discovers
private storage and provides selection/download controls; see
[the catalog guide](model-catalog.md). The core still accepts arbitrary
host-trusted compatible descriptors and does not install native libraries.
Physical model qualification remains unfinished.

## Prepare and use

The host supplies `trustedDescriptor` as a `ModelPackDescriptor`, and
`persistentPrivateRoot` as an app-private path. Initiating preparation authorizes
HTTPS requests for that descriptor. Agent creation and inference retain their
existing offline behavior.

```dart
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';

Future<LocalVoiceAgent> prepareAgent({
  required ModelPackDescriptor trustedDescriptor,
  required String persistentPrivateRoot,
}) async {
  final manager = ModelPreparationManager(
    rootDirectory: persistentPrivateRoot,
  );
  final preparation = manager.prepare(trustedDescriptor);
  final bundle = await preparation.result;
  return LocalVoiceAgent.create(
    models: bundle,
    logic: (transcript) async => 'Hello.',
  );
}
```

A valid previously installed bundle is checked against the trusted descriptor
and rehashed before reuse. That path does not create an HTTP client or consult a
remote catalog. A corrupt existing installation fails closed and is not deleted
or overwritten; automatic repair and removal are outside this API.

## Host platform setup

Android hosts that use HTTPS preparation must declare
`android.permission.INTERNET` in their main application manifest, including
release builds. The plugin's manifest currently declares microphone permission
only; the example's debug manifest already declares INTERNET for development.
Do not use debug connectivity as evidence that a release host is configured.
The example declares INTERNET in its main manifest for debug and release.

The example configures persistent private storage with backup exclusion on
Android/iOS. Other hosts must provide their own platform integration; the core
manager takes an explicit root. Preparation on physical Android/iOS devices is
not yet qualified.

## Descriptor and trust

`ModelPackDescriptor` contains an `id`, `version`, and copied, unmodifiable
`files` list. Each `ModelDownload` pairs an existing `ModelFileEntry` with a
`uri`. Entries carry role, relative path, exact byte count, lowercase SHA-256,
provenance source and a reference to a listed license file. Metadata must come
from a source the host has independently chosen to trust. Downloading a manifest
and trusting its self-declared hashes is not authentication.

The generated manifest uses the existing `en-US-sherpa-vits` profile,
sherpa-onnx `1.12.14`, and 16 kHz input. It requires VAD, encoder, decoder, joiner,
ASR tokens, VITS model, VITS tokens, VITS lexicon and license entries. A local LLM
model is optional and is downloaded only if explicitly included; the host still
needs the optional native LLM build to use it.

Paths must be safe ASCII relative paths without traversal, backslashes, empty
segments, case-insensitive aliases or file/directory collisions. `manifest.json`
is reserved. Entry and total limits match `FileModelStore`: at most 128 entries,
2 GiB per file, 4 GiB in total and a 64 KiB manifest. These are admission limits,
not recommendations for mobile memory or storage.

Every source must be a direct HTTPS URL without embedded credentials or a
fragment. Redirects are rejected by default. Hosts may explicitly set
`maxRedirects` from 1 to 5 and supply `allowedRedirectOrigins` containing exact
HTTPS origins (no path/query/credentials). The original source origin is allowed
implicitly. Each hop is validated; loops, unknown origins, HTTP downgrade and
invalid endpoints fail closed. Redirect bodies are cancelled without buffering;
requests do not copy authorization, cookie or referer headers. The catalog lists
the observed publisher CDN origins; a new CDN requires a reviewed catalog update.
Automatic decompression is disabled and nonidentity content encoding is
rejected; hashes and lengths describe exactly the bytes stored. URLs and
response bodies are not included in preparation diagnostics.

`httpClientFactory` is an optional advanced host override for trust/proxy
configuration and controlled testing. The manager owns each returned client and
closes it. Supply a fresh client on each invocation. A permissive certificate
callback weakens the host's transport trust; the default client uses normal
certificate validation.

## Progress, cancellation and failures

A `ModelPreparation` handle exposes `result`, `progress`, and `cancel()`.
`progress` is the latest immutable snapshot, with `phase`, `receivedBytes`,
`totalBytes`, `currentPath` and `failure`. Phases are checking, downloading,
verifying, ready, cancelled and failed. A UI may poll while the operation is
active; there is no buffered event stream that grows when its listener pauses.
Always await or handle `result`, including after cancellation.

```dart
final preparation = manager.prepare(trustedDescriptor);
// Keep the handle in the host's UI/controller while it is active.
final snapshot = preparation.progress;
print('${snapshot.phase}: ${snapshot.receivedBytes}/${snapshot.totalBytes}');
// A user Cancel action calls preparation.cancel().
try {
  final bundle = await preparation.result;
  // Pass bundle to LocalVoiceAgent.create when the host is ready.
} on ModelPreparationFailure catch (failure) {
  print(failure.code);
}
```

Cancellation is idempotent and closes only the operation's network client. It
removes only its owned staging directory before settling, when the filesystem
permits cleanup. If cancellation races the atomic activation, a completely
verified installed bundle can remain available for the next call. Cancellation
after a terminal result does not change that result. Retry starts a new full
transfer; there is no partial-byte resume or background continuation.

`timeout` is a positive connection/header/body inactivity duration (30 seconds
by default). It is not a whole-operation deadline or a mobile throughput
promise. Slow but progressing transfers can take longer than that duration.

| Failure code | Meaning |
|---|---|
| `invalidDescriptor` | Trusted metadata does not meet the supported contract; rejected before storage/network side effects |
| `network` | Connection, HTTP status, redirect, encoding or network timeout failure |
| `integrity` | Received or cached bytes/manifest do not match trusted expected metadata |
| `storage` | Filesystem access, creation, writing or activation failed |
| `cancelled` | The host cancelled this operation |

These preparation errors are separate from `AgentErrorCode`. The existing
`LocalModelStore` interface and offline callers need no downloader methods.

## Storage, concurrency and limits

Each operation creates its own stage under the supplied root, downloads one file
at a time with incremental hashing and bounded writes, then verifies the entire
bundle before atomic activation. The final directory name fingerprints the
complete descriptor. Installed versions are immutable and are never deleted by
preparation. Changing descriptor contents creates a different installation.

Concurrent callers, including isolates, may download duplicate bytes into
separate stages. They converge on a verified complete installation; a losing
caller cleans only its own stage. Cancelling one caller cannot cancel another's
client or delete its installed version. There is no global download scheduler,
single-flight guarantee or aggregate disk quota.

Crash-abandoned stages are ignored and are never treated as installed models.
They are not automatically swept because another process could still be writing
them. The host can reclaim unused staging only after ensuring every preparer is
quiescent. Old installed versions also accumulate; active-version leases,
removal and update policies are separate future work.

The host must protect the private root and prevent external modification of
installed files during preparation or an active voice session. Private-directory
selection, backup exclusion, proactive free-space reservation and cleanup after
process death are host responsibilities in this version. An atomic directory
rename does not constitute a measured mobile power-loss durability guarantee.

Tests with synthetic local HTTPS payloads verify the installer, not model
quality, licenses, microphone behavior, VITS allocation limits or a complete
first-run product flow. See [capabilities](capabilities.md) for those gates.
