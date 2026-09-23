import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:web/web.dart' as web;

import 'model_storage.dart';

/// Host-owned compact-pack fetch into origin-private storage.
///
/// This is not LocalVoiceAgent.create. Create never downloads.
final class ExampleWebPreparation implements ModelPreparation {
  /// Creates one cancellable web preparation for [option].
  ExampleWebPreparation({
    required this.storage,
    required this.option,
    required this.allowNetwork,
  }) : _total = option.descriptor.files.fold(
         0,
         (sum, file) => sum + file.entry.bytes,
       );

  /// Origin-private store that also implements [WebAssetReader].
  final ExampleModelStorage storage;

  /// Compact catalog option being prepared.
  final VoiceModelOption option;

  /// When false, only a previously written pack is accepted.
  final bool allowNetwork;

  final int _total;
  var _received = 0;
  var _cancelled = false;
  web.XMLHttpRequest? _activeRequest;
  ModelPreparationPhase _phase = ModelPreparationPhase.checking;
  String? _currentPath;
  ModelPreparationFailure? _failure;
  late final Future<LocalModelBundle> _result = _run();

  @override
  Future<LocalModelBundle> get result => _result;

  @override
  ModelPreparationProgress get progress => ModelPreparationProgress(
    phase: _phase,
    receivedBytes: _received,
    totalBytes: _total,
    currentPath: _currentPath,
    failure: _failure,
  );

  @override
  void cancel() {
    _cancelled = true;
    _activeRequest?.abort();
  }

  Future<LocalModelBundle> _run() async {
    final files = option.descriptor.files;
    _logExample(
      'prepare start id=${option.id} allowNetwork=$allowNetwork '
      'files=${files.length} totalBytes=$_total',
    );
    try {
      _phase = ModelPreparationPhase.checking;
      final prefix = option.id;
      final bundle = LocalModelBundle(
        directory: prefix,
        manifestPath: '$prefix/manifest.json',
      );
      if (!allowNetwork) {
        _logExample('offline verify start prefix=$prefix');
        _phase = ModelPreparationPhase.verifying;
        final store = WebModelStore(reader: storage);
        await store.validate(bundle);
        _phase = ModelPreparationPhase.ready;
        _logExample('offline verify ready');
        return bundle;
      }
      _phase = ModelPreparationPhase.downloading;
      var completed = 0;
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        _throwIfCancelled();
        _currentPath = file.entry.path;
        _received = completed;
        final uri = browserDownloadUri(file.uri);
        _logExample(
          'file ${index + 1}/${files.length} start path=${file.entry.path} '
          'role=${file.entry.role} expectedBytes=${file.entry.bytes} uri=$uri',
        );
        final bytes = await _fetch(
          uri,
          onBytes: (count) {
            _received = completed + count;
          },
        );
        final digest = sha256.convert(bytes).toString();
        if (bytes.length != file.entry.bytes || digest != file.entry.sha256) {
          _logExample(
            'file integrity failed path=${file.entry.path} '
            'bytes=${bytes.length} expectedBytes=${file.entry.bytes} '
            'sha256=$digest expectedSha256=${file.entry.sha256}',
          );
          throw const ModelPreparationFailure(
            ModelPreparationErrorCode.integrity,
            'A downloaded model file did not match its trusted digest.',
          );
        }
        _logExample(
          'file write path=$prefix/${file.entry.path} bytes=${bytes.length}',
        );
        await storage.write('$prefix/${file.entry.path}', bytes);
        completed += bytes.length;
        _received = completed;
        _logExample(
          'file done path=${file.entry.path} completedBytes=$completed/$_total',
        );
      }
      _throwIfCancelled();
      _logExample('manifest write prefix=$prefix');
      await storage.write(
        '$prefix/manifest.json',
        utf8.encode(_manifestJson()),
      );
      _phase = ModelPreparationPhase.verifying;
      _logExample('pack verify start');
      final store = WebModelStore(reader: storage);
      await store.validate(bundle);
      _phase = ModelPreparationPhase.ready;
      _logExample('prepare ready prefix=$prefix');
      return bundle;
    } on ModelPreparationFailure catch (error) {
      _logExample(
        'prepare failed stage=$_phase path=$_currentPath '
        'code=${error.code.name} message=${error.message}',
      );
      _failure = error;
      _phase = error.code == ModelPreparationErrorCode.cancelled
          ? ModelPreparationPhase.cancelled
          : ModelPreparationPhase.failed;
      rethrow;
    } on AgentFailure catch (error) {
      _logExample(
        'prepare failed stage=$_phase path=$_currentPath '
        'agentCode=${error.code.name} message=${error.message}',
      );
      final wrapped = ModelPreparationFailure(
        allowNetwork
            ? ModelPreparationErrorCode.integrity
            : ModelPreparationErrorCode.network,
        error.message,
      );
      _failure = wrapped;
      _phase = ModelPreparationPhase.failed;
      throw wrapped;
    } on ExampleStorageException catch (error) {
      _logExample(
        'prepare failed stage=$_phase path=$_currentPath '
        'storage message=${error.message}',
      );
      final wrapped = ModelPreparationFailure(
        ModelPreparationErrorCode.storage,
        error.message,
      );
      _failure = wrapped;
      _phase = ModelPreparationPhase.failed;
      throw wrapped;
    } catch (error) {
      _logExample(
        'prepare failed stage=$_phase path=$_currentPath '
        'unexpected ${error.runtimeType}: $error',
      );
      rethrow;
    }
  }

  Future<List<int>> _fetch(
    Uri uri, {
    required void Function(int received) onBytes,
  }) async {
    _throwIfCancelled();
    final done = Completer<List<int>>();
    final request = web.XMLHttpRequest();
    _activeRequest = request;
    _logExample('xhr open uri=$uri');
    request.open('GET', uri.toString(), true);
    request.responseType = 'arraybuffer';
    request.onprogress = ((web.ProgressEvent event) {
      onBytes(event.loaded);
    }).toJS;
    request.onload = ((web.ProgressEvent _) {
      if (done.isCompleted) {
        return;
      }
      _logExample(
        'xhr load uri=$uri status=${request.status} '
        'readyState=${request.readyState}',
      );
      if (request.status < 200 || request.status >= 300) {
        done.completeError(
          ModelPreparationFailure(
            ModelPreparationErrorCode.network,
            'The model source refused the download. HTTP ${request.status}.',
          ),
        );
        return;
      }
      try {
        final bytes = _bytesFromXhrResponse(request.response);
        onBytes(bytes.length);
        _logExample('xhr body uri=$uri bytes=${bytes.length}');
        done.complete(bytes);
      } catch (error) {
        _logExample('xhr body read failed uri=$uri error=$error');
        done.completeError(
          ModelPreparationFailure(
            ModelPreparationErrorCode.network,
            'The model response could not be read. $error',
          ),
        );
      }
    }).toJS;
    request.onerror = ((web.ProgressEvent _) {
      _logExample(
        'xhr error uri=$uri status=${request.status} '
        'readyState=${request.readyState}',
      );
      if (!done.isCompleted) {
        done.completeError(
          const ModelPreparationFailure(
            ModelPreparationErrorCode.network,
            'The model could not be downloaded in this browser.',
          ),
        );
      }
    }).toJS;
    request.onabort = ((web.ProgressEvent _) {
      _logExample('xhr abort uri=$uri');
      if (!done.isCompleted) {
        done.completeError(
          const ModelPreparationFailure(
            ModelPreparationErrorCode.cancelled,
            'Model preparation was cancelled.',
          ),
        );
      }
    }).toJS;
    request.send();
    try {
      return await done.future;
    } on ModelPreparationFailure {
      rethrow;
    } catch (error) {
      throw ModelPreparationFailure(
        ModelPreparationErrorCode.network,
        'The model could not be downloaded in this browser. $error',
      );
    } finally {
      if (identical(_activeRequest, request)) {
        _activeRequest = null;
      }
    }
  }

  Uint8List _bytesFromXhrResponse(JSAny? response) {
    if (response == null) {
      throw const FormatException('The download returned an empty body.');
    }
    if (response.isA<JSArrayBuffer>()) {
      return (response as JSArrayBuffer).toDart.asUint8List();
    }
    if (response.isA<JSUint8Array>()) {
      return (response as JSUint8Array).toDart;
    }
    throw FormatException(
      'The download returned an unexpected body type ${response.runtimeType}.',
    );
  }

  /// Maps catalog URLs that browsers cannot read to a CORS-capable host.
  ///
  /// GitHub release assets omit Access-Control-Allow-Origin, so a page on
  /// localhost cannot fetch them. Hugging Face reflects the requesting Origin
  /// and, for this Silero file, serves the catalog SHA-256
  /// 9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6.
  static Uri browserDownloadUri(Uri uri) {
    const githubVad =
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx';
    const huggingFaceVad =
        'https://huggingface.co/codeandwhisky/sva-genesis/resolve/efd6624543abb314dd31a39b56b97c6dc6291229/silero_vad.onnx';
    if (uri.toString() == githubVad) {
      _logExample('rewrite GitHub VAD url to Hugging Face CORS mirror');
      return Uri.parse(huggingFaceVad);
    }
    return uri;
  }

  void _throwIfCancelled() {
    if (_cancelled) {
      throw const ModelPreparationFailure(
        ModelPreparationErrorCode.cancelled,
        'Model preparation was cancelled.',
      );
    }
  }

  String _manifestJson() => jsonEncode(<String, Object?>{
    'schema': 1,
    'profile': 'en-US-sherpa-vits',
    'runtime': '1.12.14',
    'inputRate': 16000,
    'files': option.descriptor.files
        .map(
          (file) => <String, Object?>{
            'role': file.entry.role,
            'path': file.entry.path,
            'bytes': file.entry.bytes,
            'sha256': file.entry.sha256,
            'source': file.entry.source,
            'license': file.entry.license,
          },
        )
        .toList(),
  });
}

void _logExample(String message) {
  debugPrint('FLVA example $message');
}
