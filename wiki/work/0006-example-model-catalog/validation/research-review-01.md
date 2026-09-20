---
id: example-catalog-research-review-01
title: Example catalog research review round 1
status: active
owner: catalog-research-review
last_verified: 2026-09-20
applies_to: ["lib/**", "example/**"]
summary: Independent validation of catalog metadata, bytes, provenance, and platform research boundaries.
---

# Verdict

PASS for the research phase. The reviewed research establishes two complete English precision variants with grounded payload metadata and feasible transport/storage APIs. This verdict does not satisfy the later implementation acceptance criteria or qualify physical devices, legal redistribution rights, pronunciation quality, or native distribution. The reviewer did not receive the author's plan, state, or transcript.

# Verification performed

## Payload sizes, digests, and inventory closure

Executed independently with Python 3 against `/private/tmp/flva-catalog-data.json` and retained payloads, not the researcher's hash output:

```python
import json, hashlib, pathlib
j = json.load(open('/private/tmp/flva-catalog-data.json'))
c = j['packs'][0]
for f in c['files']:
    e = f['entry']
    p = pathlib.Path('/private/tmp/flva-catalog-cache/compact') / e['path']
    b = p.read_bytes()
    assert len(b) == e['bytes']
    assert hashlib.sha256(b).hexdigest() == e['sha256']
    print(e['path'], len(b), hashlib.sha256(b).hexdigest(), 'MATCH')
assert sum(f['entry']['bytes'] for f in c['files']) == c['totalBytes']
s = j['packs'][1]
repl = {e['role']: e for e in s['replacements']}
full = [repl.get(f['entry']['role'], f['entry']) for f in c['files']]
assert sum(e['bytes'] for e in full) == s['totalBytes']
assert all(e['license'] in {x['path'] for x in full} for e in full)
```

Actual output:

```text
vad/silero_vad.onnx 643854 9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6 MATCH
asr/encoder.int8.onnx 71083163 563fde436d16cf7607cf408cd6b30909819d03162652ef389c2450ced3f45ac1 MATCH
asr/decoder.int8.onnx 1307236 98da299f471e38bb4e1a8df579b8cc9122d6039576a77e357b3c60f17dd83b02 MATCH
asr/joiner.int8.onnx 259335 d944208d660d67c8d72cd2acaeac971fa5ceb8c80e76c1968148846fedd6e297 MATCH
asr/tokens.txt 5048 49e3c2646595fd907228b3c6787069658f67b17377c60aeb8619c4551b2316fb MATCH
tts/vits-ljs.int8.onnx 37423560 b3aa88de0202a040d7d75bac9dbf1a59d81d60c7369046f32241afa7dec65cc1 MATCH
tts/tokens.txt 1084 5fee2c6b238d712287f2ecb08f34a8a8b413bcb7390862ef6fb6fd6f0f8d3a17 MATCH
tts/lexicon.txt 3708181 bdccfc6da71c45c48e2e0056fcf0aab760577c5f959f6c1b5eb3e3e916fd5a0e MATCH
licenses/silero-vad-LICENSE 1075 2e63e9a38b6e8fc0c7bc37ce174caca1862870856c6daf5697cfb785e925520b MATCH
licenses/zipformer-README.md 216 c914dd28e23310a6dd345ea10495003d3e4820d2ed987181e4c2d67e501b6b76 MATCH
licenses/vits-ljs-README.md 526 26711a83b9cfccab716b482512ee95f53de9aaf68c3a3c4400c789ab52892a3c MATCH
licenses/apache-2.0.txt 11358 cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30 MATCH
compact total 114444636 MATCH
standard metadata total 383741867 MATCH
unique roles except license 8
license paths closed True
zipformer-README.md : license: apache-2.0
vits-ljs-README.md : license: apache-2.0
```

The four standard replacements were independently checked using the following additional executed loop:

```python
for e in j['packs'][1]['replacements']:
    p = pathlib.Path('/private/tmp/flva-qualification/models/vits-ljs.onnx') if e['role'] == 'ttsModel' else pathlib.Path('/private/tmp/flva-hf-asr-' + e['uri'].rsplit('/', 1)[1])
    b = p.read_bytes()
    assert len(b) == e['bytes'] and hashlib.sha256(b).hexdigest() == e['sha256']
    print('standard', e['role'], len(b), hashlib.sha256(b).hexdigest(), 'MATCH')
```

```text
standard encoder 262127043 a423883ce5754507fd941755ab0b5bc426a84ac670cbe21cf060e9e2c66dc660 MATCH
standard decoder 2092621 7bf787f90b194b307e5a4ad6a34fadb4e748304c35f78a8d66358a05b13ee6ef MATCH
standard joiner 1026405 210591f72b3c56b8364f85f345dca240bc2b4c00632848f4aa923630d5639d3b MATCH
standard ttsModel 114124456 5bbd273797a9ecf8d94bd6ec02ad16cb41cbb85f055ad98d528ced3e44c9b31a MATCH
```

Negative control executed in memory without editing a payload:

```python
e = j['packs'][0]['files'][0]['entry']
b = (pathlib.Path('/private/tmp/flva-catalog-cache/compact') / e['path']).read_bytes()
mutated = b[:-1] + bytes([b[-1] ^ 1])
assert len(mutated) == e['bytes']
assert hashlib.sha256(mutated).hexdigest() != e['sha256']
print('Negative control: same-length one-byte payload mutation rejected by declared SHA-256')
```

```text
Negative control: same-length one-byte payload mutation rejected by declared SHA-256
```

This is a metadata verification control, not a downloader implementation test.

## Live publisher metadata

The first restricted Python network request failed with `URLError <urlopen error [Errno 8] nodename nor servname provided, or not known>`. The same read-only metadata verification then ran successfully with approved network access:

```python
import json, urllib.request
j = json.load(open('/private/tmp/flva-catalog-data.json'))
for repo, rev in [('csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26', '672fbf1b30579d6585301139bb363f42a0ad4a24'), ('csukuangfj/vits-ljs', '7ac337c834f318e45a34037cb3371cc3929187ff')]:
    data = json.load(urllib.request.urlopen('https://huggingface.co/api/models/' + repo + '/tree/' + rev, timeout=20))
    n = 0
    for e in [f['entry'] | {'uri': f['uri']} for f in j['packs'][0]['files']] + j['packs'][1]['replacements']:
        if '/' + repo + '/' not in e['uri']:
            continue
        m = next(x for x in data if x['path'] == e['uri'].rsplit('/', 1)[1])
        assert m['size'] == e['bytes']
        if 'lfs' in m:
            assert m['lfs']['oid'] == e['sha256']
            n += 1
    print(repo, rev, 'MATCH', n, 'LFS hashes and all referenced sizes')
a = json.load(urllib.request.urlopen('https://api.github.com/repos/k2-fsa/sherpa-onnx/releases/assets/271935959', timeout=20))
e = j['packs'][0]['files'][0]['entry']
assert a['size'] == e['bytes'] and a['digest'] == 'sha256:' + e['sha256']
print('Silero GitHub asset', a['id'], a['size'], a['digest'], 'MATCH')
```

```text
csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26 672fbf1b30579d6585301139bb363f42a0ad4a24 MATCH 6 LFS hashes and all referenced sizes
csukuangfj/vits-ljs 7ac337c834f318e45a34037cb3371cc3929187ff MATCH 2 LFS hashes and all referenced sizes
Silero GitHub asset 271935959 643854 sha256:9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6 MATCH
```

Primary endpoints were the pinned [Zipformer tree](https://huggingface.co/api/models/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24), pinned [VITS tree](https://huggingface.co/api/models/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff), and [GitHub asset metadata](https://api.github.com/repos/k2-fsa/sherpa-onnx/releases/assets/271935959). The two local pinned model cards declare Apache-2.0; that supports the research's attribution statement only. No licensing grant was inferred from a hash, model card, or successful download.

## Storage, transport, and native capability boundaries

Executed source reads:

```text
sed -n '1690,1707p' /Users/ortalcohen/Library/Android/sdk/sources/android-36.1/android/content/Context.java
sed -n '140,152p' /Users/ortalcohen/Library/Android/sdk/sources/android-36.1/android/os/StatFs.java
rg -n 'NSURLIsExcludedFromBackupKey|NSURLVolumeAvailableCapacityForImportantUsageKey' '/Applications/Xcode 2.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/Foundation.framework/Headers/NSURL.h'
sed -n '75,115p' native/src/flva.cpp
sed -n '1,130p' native/tests/real_engine_smoke.cpp
rg -n 'followRedirects = false|FileModelStore|existing|httpClientFactory' lib/src/model_preparation.dart
```

Relevant actual excerpts:

```text
public abstract File getNoBackupFilesDir();
public long getAvailableBytes() {
    return mStat.f_bavail * mStat.f_frsize;
}
250:FOUNDATION_EXPORT NSURLResourceKey const NSURLIsExcludedFromBackupKey        API_AVAILABLE(macos(10.8), ios(5.1), watchos(2.0), tvos(9.0));
361:FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeAvailableCapacityForImportantUsageKey API_AVAILABLE(macos(10.13), ios(11.0)) API_UNAVAILABLE(watchos, tvos);
322:      _client = httpClientFactory();
392:        ..followRedirects = false
```

The Android SDK comments establish no additional file permissions and remote backup exclusion. Apple's installed header identifies backup exclusion as writable and appropriate for Application Support files. Capacity remains advisory. The first Apple SDK lookup used an absent `/Applications/Xcode.app` path; `xcode-select -p` returned `/Applications/Xcode 2.app/Contents/Developer`, and the corrected source inspection above succeeded.

The [official Dart redirect documentation](https://api.dart.dev/dart-io/HttpClientRequest/followRedirects.html) was read independently with the web tool. It confirms automatic redirects have their own header propagation rules and manual requests can enforce per-hop decisions. The research's bounded HTTPS exact-origin approach is grounded; no implemented redirect test was run in this research review.

Native source inspection confirms the transducer encoder/decoder/joiner and the VITS model/lexicon/tokens configuration, plus the exact required runtime version. The smoke source requires nine arguments after the executable and checks recognition, reply acceptance, speaking, and subsequent listening. This reviewer did not rerun the native smoke or device builds. Research explicitly retains their reproduction for acceptance, so historical host timings are not treated as newly verified benchmarks. The inventory contains one English voice at two precisions; it supplies no evidence for another language or speaker.

# Findings

No blocking or important research findings. The research explicitly distinguishes immutable Hugging Face revisions from the mutable Silero release URL with pinned expected content, upstream license declarations from redistribution approval, and host compatibility from physical-device qualification. Its named unresolved native-distribution, device, and VITS boundaries remain open. Implementation and emulator behavior are not claimed by this verdict.

# Recurrence check

First research review for work item 0006. No prior verdict was provided and no previously fixed claim was trusted. All byte/metadata checks above were executed independently. No research finding recurred in this round.

# Routing

Research phase PASS; no defect routing. Plan/implementation acceptance remains a separate review boundary. This report provides no implementation fixes and makes no decision about unresolved release or physical-device gates.

## Verification performed

Coordinator report-schema registration: all independently executed commands and pasted results remain in the original evidence section above. This heading addition does not change the verdict or imply another review.

## Recurrence check

First research validation round for work0006. No previous findings or oscillation established.
