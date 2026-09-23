import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:web/web.dart' as web;

import 'model_storage_types.dart';

export 'model_storage_types.dart';

/// Origin-private web storage for the compact catalog pack.
class ExampleModelStorage implements WebAssetReader, WebAssetWriter {
  /// Creates origin-private web storage. [channel] is unused on web.
  ExampleModelStorage({MethodChannel? channel});

  static const _selectionKey = 'flva.example.selection';
  static const _cacheName = 'flva-example-models';
  final Map<String, List<int>> _memory = <String, List<int>>{};

  /// Origin-private prefix used as [LocalModelBundle.directory].
  Future<String> rootDirectory() async => '';

  /// Remaining origin quota, or a conservative fallback.
  Future<int> availableBytes() async {
    try {
      final estimate = await web.window.navigator.storage.estimate().toDart;
      final remaining = estimate.quota - estimate.usage;
      if (remaining.isNaN || remaining < 0) {
        throw const ExampleStorageException(
          'Available device storage could not be measured. Free some space and try again.',
        );
      }
      return remaining.toInt();
    } catch (error) {
      if (error is ExampleStorageException) rethrow;
      return 512 * 1024 * 1024;
    }
  }

  /// Store prefix for [option]. The compact pack uses the catalog identifier.
  Future<String> optionDirectory(VoiceModelOption option) async {
    _requireCatalogOption(option);
    return option.id;
  }

  /// True when a manifest is already present for [option].
  Future<bool> hasInstalledCandidate(VoiceModelOption option) async {
    _requireCatalogOption(option);
    final bytes = await read('${option.id}/manifest.json');
    return bytes != null && bytes.isNotEmpty;
  }

  /// Reads the last prepared catalog selection, if any.
  Future<ExampleSelection?> readSelection() async {
    try {
      final raw = web.window.localStorage.getItem(_selectionKey);
      if (raw == null || raw.isEmpty) return null;
      final value = jsonDecode(raw);
      if (value is! Map || value['catalogId'] is! String) {
        throw const FormatException('Invalid selection document.');
      }
      return ExampleSelection(
        catalogId: value['catalogId'] as String,
        speakerId: _speakerIdFromDocument(value),
      );
    } on FormatException {
      throw const ExampleStorageException(
        'The saved model selection is damaged. Choose a model to repair setup.',
      );
    }
  }

  /// Writes the prepared catalog selection.
  Future<void> writeSelection(
    VoiceModelOption option, {
    int speakerId = 0,
  }) async {
    _requireCatalogOption(option);
    try {
      web.window.localStorage.setItem(
        _selectionKey,
        jsonEncode(<String, Object>{
          'catalogId': option.id,
          'speakerId': speakerId,
        }),
      );
    } catch (_) {
      throw const ExampleStorageException(
        'The selected model is ready, but its offline selection could not be saved. Check device storage and try again.',
      );
    }
  }

  /// Removes stored files for [option] and a matching selection.
  Future<void> deleteOption(VoiceModelOption option) async {
    _requireCatalogOption(option);
    final prefix = '${option.id}/';
    _memory.removeWhere((key, _) => key == option.id || key.startsWith(prefix));
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final keys = await cache.keys().toDart;
      for (var i = 0; i < keys.length; i++) {
        final request = keys[i];
        final url = request.url;
        if (url.contains(prefix) || url.endsWith('/${option.id}')) {
          await cache.delete(request).toDart;
        }
      }
      final selected = await readSelection();
      if (selected?.catalogId == option.id) {
        web.window.localStorage.removeItem(_selectionKey);
      }
    } catch (_) {
      throw const ExampleStorageException(
        'The damaged model copy could not be removed. Restart the app and try again.',
      );
    }
  }

  @override
  Future<List<int>?> read(String key) async {
    final cached = _memory[key];
    if (cached != null) return cached;
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final match = await cache.match(_request(key)).toDart;
      if (match == null) return null;
      final buffer = await match.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();
      _memory[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, List<int> bytes) async {
    _memory[key] = bytes;
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final payload = Uint8List.fromList(bytes);
      final headers = web.Headers();
      headers.set('content-type', 'application/octet-stream');
      await cache
          .put(
            _request(key),
            web.Response(payload.toJS, web.ResponseInit(headers: headers)),
          )
          .toDart;
    } catch (error) {
      debugPrint(
        'FLVA example storage write failed key=$key bytes=${bytes.length} '
        'error=$error',
      );
      throw const ExampleStorageException(
        'The model could not be written to origin-private storage.',
      );
    }
  }

  web.Request _request(String key) {
    final path = key.split('/').map(Uri.encodeComponent).join('/');
    return web.Request('https://flva.local/models/$path'.toJS);
  }

  int _speakerIdFromDocument(Map<dynamic, dynamic> value) {
    if (!value.containsKey('speakerId')) {
      return 0;
    }
    final speakerId = value['speakerId'];
    if (speakerId is! int || speakerId < 0) {
      throw const FormatException('Invalid selection document.');
    }
    return speakerId;
  }

  void _requireCatalogOption(VoiceModelOption option) {
    if (option.id != VoiceModelCatalog.entries.first.id &&
        !VoiceModelCatalog.entries.any(
          (candidate) =>
              identical(candidate, option) || candidate.id == option.id,
        )) {
      throw const ExampleStorageException(
        'The selected model is not part of this app catalog.',
      );
    }
  }
}
