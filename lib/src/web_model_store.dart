import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'contracts.dart';
import 'models.dart';
import 'web_defaults.dart';

/// Reads store-relative or asset-relative bytes. A null result means absent.
abstract interface class WebAssetReader {
  /// Returns the bytes for [key], or null when the key is missing.
  Future<List<int>?> read(String key);
}

/// Writes store-relative bytes into an origin-private store.
abstract interface class WebAssetWriter {
  /// Stores [bytes] at [key].
  Future<void> write(String key, List<int> bytes);
}

/// Hash-checks a compact pack from bundled assets or an origin-private store.
///
/// This is the production web [LocalModelStore]. It never uses dart:io and
/// never requests the microphone. Create does not download.
final class WebModelStore implements LocalModelStore {
  /// Largest accepted manifest, in bytes.
  static const maxManifestBytes = 64 * 1024;

  /// Largest accepted manifest file count.
  static const maxEntries = 128;

  /// Largest individual model file, in bytes.
  static const maxFileBytes = 2 * 1024 * 1024 * 1024;

  /// Largest sum of model files, in bytes.
  static const maxTotalBytes = 4 * 1024 * 1024 * 1024;

  /// Creates the web validator.
  const WebModelStore({required this.reader, this.writer});

  /// Byte source for manifests and listed model files.
  final WebAssetReader reader;

  /// Optional destination for [install]. Absent writes fail closed.
  final WebAssetWriter? writer;

  @override
  Future<ValidatedModelBundle> validate(LocalModelBundle bundle) async {
    try {
      final manifestKey = _manifestKey(bundle);
      final manifestBytes = await reader.read(manifestKey);
      if (manifestBytes == null) {
        return _missing('Model manifest does not exist.');
      }
      if (manifestBytes.length > maxManifestBytes) {
        return _invalid('Manifest exceeds 64 KiB.');
      }
      final document = decodeObjectJson(utf8.decode(manifestBytes));
      _require(document['schema'] == 1, 'Manifest schema must be 1.');
      _require(
        document['profile'] == 'en-US-sherpa-vits',
        'Unsupported manifest profile.',
      );
      _require(
        document['runtime'] == '1.12.14',
        'Unsupported runtime version.',
      );
      _require(document['inputRate'] == 16000, 'Input rate must be 16000.');
      final rawFiles = document['files'];
      _require(
        rawFiles is List &&
            rawFiles.isNotEmpty &&
            rawFiles.length <= maxEntries,
        'Invalid files list.',
      );
      final entries = <ModelFileEntry>[];
      var total = 0;
      final roles = <String>{};
      final paths = <String>{};
      for (final raw in rawFiles! as List) {
        final value = objectMap(raw);
        final entry = ModelFileEntry(
          role: _string(value, 'role'),
          path: _relative(value, 'path'),
          bytes: _positiveInt(value, 'bytes', maxFileBytes),
          sha256: _sha(value),
          source: _string(value, 'source'),
          license: _relative(value, 'license'),
        );
        _require(
          entry.role == 'license' || roles.add(entry.role),
          'Duplicate role ${entry.role}.',
        );
        _require(paths.add(entry.path), 'Duplicate path ${entry.path}.');
        total += entry.bytes;
        _require(total <= maxTotalBytes, 'Total model size exceeds 4 GiB.');
        entries.add(entry);
      }
      const required = <String>{
        'vad',
        'encoder',
        'decoder',
        'joiner',
        'asrTokens',
        'ttsModel',
        'ttsTokens',
        'ttsLexicon',
      };
      const allowed = <String>{...required, 'llmModel', 'license'};
      _require(
        entries.every((entry) => allowed.contains(entry.role)),
        'Manifest contains an unsupported role.',
      );
      _require(
        roles.containsAll(required),
        'Manifest misses a required model role.',
      );
      final licensePaths = entries
          .where((entry) => entry.role == 'license')
          .map((entry) => entry.path)
          .toSet();
      _require(licensePaths.isNotEmpty, 'Manifest has no license file entry.');
      for (final entry in entries) {
        _require(
          licensePaths.contains(entry.license),
          'License reference is not a listed license path.',
        );
        final fileBytes = await reader.read(_fileKey(bundle, entry.path));
        if (fileBytes == null) {
          return _missing('Missing model file ${entry.path}.');
        }
        _require(
          fileBytes.length == entry.bytes,
          'Byte count differs for ${entry.path}.',
        );
        _require(
          sha256.convert(fileBytes).toString() == entry.sha256,
          'SHA-256 differs for ${entry.path}.',
        );
      }
      return ValidatedModelBundle(
        bundle: bundle,
        files: List.unmodifiable(entries),
      );
    } on AgentFailure {
      rethrow;
    } on FormatException catch (error) {
      return _invalid(error.message);
    }
  }

  @override
  Future<LocalModelBundle> install({
    required LocalModelBundle source,
    required String targetRoot,
  }) async {
    final destination = writer;
    if (destination == null) {
      throw const AgentFailure(
        AgentErrorCode.missingAsset,
        'The web model store cannot write.',
        fatal: false,
      );
    }
    final checked = await validate(source);
    for (final entry in checked.files) {
      final bytes = await reader.read(_fileKey(source, entry.path));
      if (bytes == null) {
        throw AgentFailure(
          AgentErrorCode.missingAsset,
          'Missing model file ${entry.path}.',
          fatal: false,
        );
      }
      await destination.write(_join(targetRoot, entry.path), bytes);
    }
    final manifestBytes = await reader.read(_manifestKey(source));
    if (manifestBytes == null) {
      throw const AgentFailure(
        AgentErrorCode.missingAsset,
        'Model manifest does not exist.',
        fatal: false,
      );
    }
    final installed = LocalModelBundle(
      directory: targetRoot,
      manifestPath: _join(targetRoot, 'manifest.json'),
    );
    await destination.write(_manifestKey(installed), manifestBytes);
    await validate(installed);
    return installed;
  }
}

/// Assigns [WebModelStore] as the omitted web create default.
void registerWebModelStore(WebAssetReader reader) {
  webModelStoreDefault = () => WebModelStore(reader: reader);
}

Never _missing(String detail) =>
    throw AgentFailure(AgentErrorCode.missingAsset, detail, fatal: false);
Never _invalid(String detail) =>
    throw AgentFailure(AgentErrorCode.invalidAsset, detail, fatal: false);
void _require(bool condition, String message) {
  if (!condition) _invalid(message);
}

String _string(Map<String, Object?> map, String name) {
  final value = map[name];
  if (value is! String || value.trim().isEmpty) {
    _invalid('Missing non-empty $name.');
  }
  return value;
}

String _relative(Map<String, Object?> map, String name) {
  final value = _string(map, name);
  if (value.startsWith('/') ||
      value.startsWith('\\') ||
      value.contains('..') ||
      value.contains(':') ||
      value.contains('\u0000')) {
    _invalid('Path $name must be a safe relative path.');
  }
  return value;
}

int _positiveInt(Map<String, Object?> map, String name, int maximum) {
  final value = map[name];
  if (value is! int || value < 0 || value > maximum) _invalid('Invalid $name.');
  return value;
}

String _sha(Map<String, Object?> map) {
  final value = _string(map, 'sha256');
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    _invalid('sha256 must be a lowercase SHA-256 digest.');
  }
  return value;
}

String _join(String directory, String relative) =>
    directory.isEmpty ? relative : '$directory/$relative';

String _fileKey(LocalModelBundle bundle, String relative) =>
    _join(bundle.directory, relative);

String _manifestKey(LocalModelBundle bundle) {
  final directory = bundle.directory;
  final manifestPath = bundle.manifestPath;
  if (directory.isNotEmpty &&
      (manifestPath == directory || manifestPath.startsWith('$directory/'))) {
    return manifestPath;
  }
  if (manifestPath.contains('/')) {
    return manifestPath;
  }
  return _join(directory, 'manifest.json');
}
