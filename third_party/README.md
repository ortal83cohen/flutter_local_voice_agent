# Native dependency inventory

The vendored C header is from sherpa-onnx v1.12.14 (Apache-2.0); its license is
included beside this file. Build-time runtime archives are downloaded only by an
explicit tools/provision_runtime.py command and are SHA-256 pinned there.
The archives include ONNX Runtime 1.17.1. Binary transitive notice completeness,
Android 16 KiB page compatibility, and store submission eligibility are not yet
qualified. Do not redistribute the binary pack on the strength of a successful
local build.

Models are not included. Runtime, model weights, frontend lexicon/tokenizer,
training data and optional phonemizer terms are separate. The locally tested
VITS-LJS profile uses its lexicon rather than an eSpeak data directory. This
statement does not apply to other VITS voices. No model redistribution approval
is implied. See the model installation guide and qualification report.
