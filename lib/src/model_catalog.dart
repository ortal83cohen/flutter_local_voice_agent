import 'model_preparation_models.dart';
import 'models.dart';

/// One verified speech-model configuration, not a general-purpose chat model.
final class VoiceModelOption {
  /// Creates a catalog choice backed by immutable trusted descriptor metadata.
  VoiceModelOption({
    required this.title,
    required this.description,
    required this.language,
    required this.descriptor,
    required List<Uri> allowedRedirectOrigins,
  }) : allowedRedirectOrigins = List<Uri>.unmodifiable(allowedRedirectOrigins);

  /// Stable identifier used to persist a selection.
  String get id => descriptor.id;

  /// Human-readable configuration name.
  final String title;

  /// Purpose and precision tradeoff without unmeasured quality claims.
  final String description;

  /// Supported spoken language.
  final String language;

  /// Trusted source, license, size and SHA-256 metadata.
  final ModelPackDescriptor descriptor;

  /// Exact publisher CDN origins permitted by explicit preparation.
  final List<Uri> allowedRedirectOrigins;

  /// Sum of downloaded payload and notice bytes, excluding generated manifest.
  int get downloadBytes =>
      descriptor.files.fold(0, (sum, file) => sum + file.entry.bytes);
}

/// Pinned English Zipformer/Silero/LJS speech choices for the local example.
///
/// Metadata is recorded in tool/model_catalog_inventory.json. Downloads occur
/// only when a host explicitly invokes preparation. Publisher model cards and
/// full license texts are installed with the weights. Physical-device quality
/// and the upstream VITS allocation bound remain separate qualification gates.
abstract final class VoiceModelCatalog {
  /// Compact first, followed by full precision of the same English voice.
  static final List<VoiceModelOption> entries = List.unmodifiable([
    VoiceModelOption(
      title: 'English compact (INT8)',
      description: 'Smaller INT8 speech models with the LJS English voice.',
      language: 'English (US)',
      descriptor: ModelPackDescriptor(
        id: 'en-us-ljs-zipformer-int8',
        version: 'zipformer-672fbf1-vits-7ac337c',
        files: [
          ModelDownload(
            entry: ModelFileEntry(
              role: 'vad',
              path: 'vad/silero_vad.onnx',
              bytes: 643854,
              sha256:
                  '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
              source:
                  'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models#asset-silero_vad.onnx-id-271935959',
              license: 'licenses/silero-vad-LICENSE',
            ),
            uri: Uri.parse(
              'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'encoder',
              path: 'asr/encoder.int8.onnx',
              bytes: 71083163,
              sha256:
                  '563fde436d16cf7607cf408cd6b30909819d03162652ef389c2450ced3f45ac1',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/672fbf1b30579d6585301139bb363f42a0ad4a24/encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'decoder',
              path: 'asr/decoder.int8.onnx',
              bytes: 1307236,
              sha256:
                  '98da299f471e38bb4e1a8df579b8cc9122d6039576a77e357b3c60f17dd83b02',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/672fbf1b30579d6585301139bb363f42a0ad4a24/decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'joiner',
              path: 'asr/joiner.int8.onnx',
              bytes: 259335,
              sha256:
                  'd944208d660d67c8d72cd2acaeac971fa5ceb8c80e76c1968148846fedd6e297',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/672fbf1b30579d6585301139bb363f42a0ad4a24/joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'asrTokens',
              path: 'asr/tokens.txt',
              bytes: 5048,
              sha256:
                  '49e3c2646595fd907228b3c6787069658f67b17377c60aeb8619c4551b2316fb',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/raw/672fbf1b30579d6585301139bb363f42a0ad4a24/tokens.txt',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'ttsModel',
              path: 'tts/vits-ljs.int8.onnx',
              bytes: 37423560,
              sha256:
                  'b3aa88de0202a040d7d75bac9dbf1a59d81d60c7369046f32241afa7dec65cc1',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff',
              license: 'licenses/vits-ljs-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/resolve/7ac337c834f318e45a34037cb3371cc3929187ff/vits-ljs.int8.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'ttsTokens',
              path: 'tts/tokens.txt',
              bytes: 1084,
              sha256:
                  '5fee2c6b238d712287f2ecb08f34a8a8b413bcb7390862ef6fb6fd6f0f8d3a17',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff',
              license: 'licenses/vits-ljs-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/raw/7ac337c834f318e45a34037cb3371cc3929187ff/tokens.txt',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'ttsLexicon',
              path: 'tts/lexicon.txt',
              bytes: 3708181,
              sha256:
                  'bdccfc6da71c45c48e2e0056fcf0aab760577c5f959f6c1b5eb3e3e916fd5a0e',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff',
              license: 'licenses/vits-ljs-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/raw/7ac337c834f318e45a34037cb3371cc3929187ff/lexicon.txt',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/silero-vad-LICENSE',
              bytes: 1075,
              sha256:
                  '2e63e9a38b6e8fc0c7bc37ce174caca1862870856c6daf5697cfb785e925520b',
              source:
                  'https://github.com/snakers4/silero-vad/blob/60b7ffa243625ebdc1070275a29f18c87843786a/LICENSE',
              license: 'licenses/silero-vad-LICENSE',
            ),
            uri: Uri.parse(
              'https://raw.githubusercontent.com/snakers4/silero-vad/60b7ffa243625ebdc1070275a29f18c87843786a/LICENSE',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/zipformer-README.md',
              bytes: 216,
              sha256:
                  'c914dd28e23310a6dd345ea10495003d3e4820d2ed987181e4c2d67e501b6b76',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/blob/672fbf1b30579d6585301139bb363f42a0ad4a24/README.md',
              license: 'licenses/apache-2.0.txt',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/raw/672fbf1b30579d6585301139bb363f42a0ad4a24/README.md',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/vits-ljs-README.md',
              bytes: 526,
              sha256:
                  '26711a83b9cfccab716b482512ee95f53de9aaf68c3a3c4400c789ab52892a3c',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/blob/7ac337c834f318e45a34037cb3371cc3929187ff/README.md',
              license: 'licenses/apache-2.0.txt',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/raw/7ac337c834f318e45a34037cb3371cc3929187ff/README.md',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/apache-2.0.txt',
              bytes: 11358,
              sha256:
                  'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30',
              source:
                  'https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/LICENSE',
              license: 'licenses/apache-2.0.txt',
            ),
            uri: Uri.parse(
              'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/v1.12.14/LICENSE',
            ),
          ),
        ],
      ),
      allowedRedirectOrigins: [
        Uri.parse('https://us.aws.cdn.hf.co'),
        Uri.parse('https://release-assets.githubusercontent.com'),
      ],
    ),
    VoiceModelOption(
      title: 'English standard (full precision)',
      description:
          'Full-precision speech models with the same LJS English voice. Larger download.',
      language: 'English (US)',
      descriptor: ModelPackDescriptor(
        id: 'en-us-ljs-zipformer-standard',
        version: 'zipformer-672fbf1-vits-7ac337c',
        files: [
          ModelDownload(
            entry: ModelFileEntry(
              role: 'vad',
              path: 'vad/silero_vad.onnx',
              bytes: 643854,
              sha256:
                  '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
              source:
                  'https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models#asset-silero_vad.onnx-id-271935959',
              license: 'licenses/silero-vad-LICENSE',
            ),
            uri: Uri.parse(
              'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'encoder',
              path: 'asr/encoder.onnx',
              bytes: 262127043,
              sha256:
                  'a423883ce5754507fd941755ab0b5bc426a84ac670cbe21cf060e9e2c66dc660',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/672fbf1b30579d6585301139bb363f42a0ad4a24/encoder-epoch-99-avg-1-chunk-16-left-128.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'decoder',
              path: 'asr/decoder.onnx',
              bytes: 2092621,
              sha256:
                  '7bf787f90b194b307e5a4ad6a34fadb4e748304c35f78a8d66358a05b13ee6ef',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/672fbf1b30579d6585301139bb363f42a0ad4a24/decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'joiner',
              path: 'asr/joiner.onnx',
              bytes: 1026405,
              sha256:
                  '210591f72b3c56b8364f85f345dca240bc2b4c00632848f4aa923630d5639d3b',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/672fbf1b30579d6585301139bb363f42a0ad4a24/joiner-epoch-99-avg-1-chunk-16-left-128.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'asrTokens',
              path: 'asr/tokens.txt',
              bytes: 5048,
              sha256:
                  '49e3c2646595fd907228b3c6787069658f67b17377c60aeb8619c4551b2316fb',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/tree/672fbf1b30579d6585301139bb363f42a0ad4a24',
              license: 'licenses/zipformer-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/raw/672fbf1b30579d6585301139bb363f42a0ad4a24/tokens.txt',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'ttsModel',
              path: 'tts/vits-ljs.onnx',
              bytes: 114124456,
              sha256:
                  '5bbd273797a9ecf8d94bd6ec02ad16cb41cbb85f055ad98d528ced3e44c9b31a',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff',
              license: 'licenses/vits-ljs-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/resolve/7ac337c834f318e45a34037cb3371cc3929187ff/vits-ljs.onnx',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'ttsTokens',
              path: 'tts/tokens.txt',
              bytes: 1084,
              sha256:
                  '5fee2c6b238d712287f2ecb08f34a8a8b413bcb7390862ef6fb6fd6f0f8d3a17',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff',
              license: 'licenses/vits-ljs-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/raw/7ac337c834f318e45a34037cb3371cc3929187ff/tokens.txt',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'ttsLexicon',
              path: 'tts/lexicon.txt',
              bytes: 3708181,
              sha256:
                  'bdccfc6da71c45c48e2e0056fcf0aab760577c5f959f6c1b5eb3e3e916fd5a0e',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/tree/7ac337c834f318e45a34037cb3371cc3929187ff',
              license: 'licenses/vits-ljs-README.md',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/raw/7ac337c834f318e45a34037cb3371cc3929187ff/lexicon.txt',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/silero-vad-LICENSE',
              bytes: 1075,
              sha256:
                  '2e63e9a38b6e8fc0c7bc37ce174caca1862870856c6daf5697cfb785e925520b',
              source:
                  'https://github.com/snakers4/silero-vad/blob/60b7ffa243625ebdc1070275a29f18c87843786a/LICENSE',
              license: 'licenses/silero-vad-LICENSE',
            ),
            uri: Uri.parse(
              'https://raw.githubusercontent.com/snakers4/silero-vad/60b7ffa243625ebdc1070275a29f18c87843786a/LICENSE',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/zipformer-README.md',
              bytes: 216,
              sha256:
                  'c914dd28e23310a6dd345ea10495003d3e4820d2ed987181e4c2d67e501b6b76',
              source:
                  'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/blob/672fbf1b30579d6585301139bb363f42a0ad4a24/README.md',
              license: 'licenses/apache-2.0.txt',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/raw/672fbf1b30579d6585301139bb363f42a0ad4a24/README.md',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/vits-ljs-README.md',
              bytes: 526,
              sha256:
                  '26711a83b9cfccab716b482512ee95f53de9aaf68c3a3c4400c789ab52892a3c',
              source:
                  'https://huggingface.co/csukuangfj/vits-ljs/blob/7ac337c834f318e45a34037cb3371cc3929187ff/README.md',
              license: 'licenses/apache-2.0.txt',
            ),
            uri: Uri.parse(
              'https://huggingface.co/csukuangfj/vits-ljs/raw/7ac337c834f318e45a34037cb3371cc3929187ff/README.md',
            ),
          ),
          ModelDownload(
            entry: ModelFileEntry(
              role: 'license',
              path: 'licenses/apache-2.0.txt',
              bytes: 11358,
              sha256:
                  'cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30',
              source:
                  'https://github.com/k2-fsa/sherpa-onnx/blob/v1.12.14/LICENSE',
              license: 'licenses/apache-2.0.txt',
            ),
            uri: Uri.parse(
              'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/v1.12.14/LICENSE',
            ),
          ),
        ],
      ),
      allowedRedirectOrigins: [
        Uri.parse('https://us.aws.cdn.hf.co'),
        Uri.parse('https://release-assets.githubusercontent.com'),
      ],
    ),
  ]);
}
