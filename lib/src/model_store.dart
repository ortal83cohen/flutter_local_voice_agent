import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'contracts.dart';
import 'models.dart';

/// Filesystem implementation that validates local manifests without networking.
final class FileModelStore implements LocalModelStore {
  /// Largest accepted manifest, in bytes.
  static const maxManifestBytes = 64 * 1024;

  /// Largest accepted manifest file count.
  static const maxEntries = 128;

  /// Largest individual model file, in bytes.
  static const maxFileBytes = 2 * 1024 * 1024 * 1024;

  /// Largest sum of model files, in bytes.
  static const maxTotalBytes = 4 * 1024 * 1024 * 1024;

  /// Creates the local validator.
  const FileModelStore();

  @override
  Future<ValidatedModelBundle> validate(LocalModelBundle bundle) async {
    try {
      final root = Directory(bundle.directory);
      if (!await root.exists()) return _missing('Model root does not exist.');
      final rootReal = await root.resolveSymbolicLinks();
      final manifest = File(bundle.manifestPath);
      if (!await manifest.exists()) {
        return _missing('Model manifest does not exist.');
      }
      final manifestReal = await manifest.resolveSymbolicLinks();
      if (!_within(rootReal, manifestReal)) {
        return _invalid('Manifest escapes the model root.');
      }
      if (await manifest.length() > maxManifestBytes) {
        return _invalid('Manifest exceeds 64 KiB.');
      }
      final document = decodeObjectJson(await manifest.readAsString());
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
        final file = File('$rootReal${Platform.pathSeparator}${entry.path}');
        if (!await file.exists()) {
          return _missing('Missing model file ${entry.path}.');
        }
        final real = await file.resolveSymbolicLinks();
        _require(_within(rootReal, real), 'Model file escapes the model root.');
        final stat = await file.stat();
        _require(
          stat.type == FileSystemEntityType.file,
          'Model entry is not a regular file.',
        );
        _require(
          stat.size == entry.bytes,
          'Byte count differs for ${entry.path}.',
        );
        final digest = await file.openRead().transform(sha256).single;
        _require(
          digest.toString() == entry.sha256,
          'SHA-256 differs for ${entry.path}.',
        );
      }
      return ValidatedModelBundle(
        bundle: bundle,
        files: List.unmodifiable(entries),
      );
    } on AgentFailure {
      rethrow;
    } on FileSystemException catch (error) {
      return _invalid('Cannot resolve model files: ${error.message}');
    } on FormatException catch (error) {
      return _invalid(error.message);
    }
  }

  @override
  Future<LocalModelBundle> install({
    required LocalModelBundle source,
    required String targetRoot,
  }) async {
    final checked = await validate(source);
    final destinationRoot = Directory(targetRoot);
    await destinationRoot.create(recursive: true);
    final stage = await Directory(
      '${destinationRoot.path}${Platform.pathSeparator}.stage-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    try {
      for (final entry in checked.files) {
        final input = File(
          '${source.directory}${Platform.pathSeparator}${entry.path}',
        );
        final output = File(
          '${stage.path}${Platform.pathSeparator}${entry.path}',
        );
        await output.parent.create(recursive: true);
        await input.copy(output.path);
      }
      final stagedManifest = File(
        '${stage.path}${Platform.pathSeparator}manifest.json',
      );
      await File(source.manifestPath).copy(stagedManifest.path);
      await validate(
        LocalModelBundle(
          directory: stage.path,
          manifestPath: stagedManifest.path,
        ),
      );
      final active = Directory(
        '${destinationRoot.path}${Platform.pathSeparator}bundle-${DateTime.now().microsecondsSinceEpoch}',
      );
      await stage.rename(active.path);
      return LocalModelBundle(
        directory: active.path,
        manifestPath: '${active.path}${Platform.pathSeparator}manifest.json',
      );
    } catch (_) {
      if (await stage.exists()) await stage.delete(recursive: true);
      rethrow;
    }
  }
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

bool _within(String root, String child) =>
    child == root || child.startsWith('$root${Platform.pathSeparator}');
