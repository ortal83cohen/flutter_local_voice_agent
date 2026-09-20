import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'model_preparation_models.dart';
import 'model_store.dart';
import 'models.dart';

export 'model_preparation_models.dart';

/// Creates a separately owned HTTP client for one preparation operation.
typedef ModelPreparationHttpClientFactory = HttpClient Function();

/// Downloads and verifies explicit host-selected model descriptors.
final class ModelPreparationManager {
  /// Creates a manager for a host-owned private [rootDirectory].
  ModelPreparationManager({
    required this.rootDirectory,
    ModelPreparationHttpClientFactory? httpClientFactory,
    this.timeout = const Duration(seconds: 30),
    this.maxRedirects = 0,
    List<Uri> allowedRedirectOrigins = const [],
  }) : httpClientFactory = httpClientFactory ?? HttpClient.new,
       allowedRedirectOrigins = List<Uri>.unmodifiable(allowedRedirectOrigins);

  /// Host-selected persistent application-private storage root.
  final String rootDirectory;

  /// Factory invoked once for each operation that needs network access.
  final ModelPreparationHttpClientFactory httpClientFactory;

  /// Positive deadline used for request headers and response-body inactivity.
  final Duration timeout;

  /// Maximum HTTPS redirects per file (0 to 5); zero rejects all redirects.
  final int maxRedirects;

  /// Extra exact HTTPS origins permitted for redirects, beyond the source origin.
  ///
  /// Entries must contain only scheme, host and optional port. No credentials,
  /// path (except /), query or fragment is accepted. Never use signed CDN URLs.
  final List<Uri> allowedRedirectOrigins;

  /// Starts an independently cancellable preparation of [descriptor].
  ModelPreparation prepare(ModelPackDescriptor descriptor) {
    final operation = _PreparationOperation(
      rootDirectory: rootDirectory,
      httpClientFactory: httpClientFactory,
      timeout: timeout,
      descriptor: descriptor,
      maxRedirects: maxRedirects,
      allowedRedirectOrigins: allowedRedirectOrigins,
    );
    operation.start();
    return operation;
  }
}

final class _PreparationOperation implements ModelPreparation {
  _PreparationOperation({
    required this.rootDirectory,
    required this.httpClientFactory,
    required this.timeout,
    required this.descriptor,
    required this.maxRedirects,
    required this.allowedRedirectOrigins,
  });

  static const _profile = 'en-US-sherpa-vits';
  static const _runtime = '1.12.14';
  static const _inputRate = 16000;
  static const _writeChunkBytes = 64 * 1024;
  static const _requiredRoles = <String>{
    'vad',
    'encoder',
    'decoder',
    'joiner',
    'asrTokens',
    'ttsModel',
    'ttsTokens',
    'ttsLexicon',
  };
  static const _allowedRoles = <String>{
    ..._requiredRoles,
    'llmModel',
    'license',
  };

  final String rootDirectory;
  final ModelPreparationHttpClientFactory httpClientFactory;
  final Duration timeout;
  final ModelPackDescriptor descriptor;
  final int maxRedirects;
  final List<Uri> allowedRedirectOrigins;
  final Completer<LocalModelBundle> _result = Completer<LocalModelBundle>();

  HttpClient? _client;
  Directory? _stage;
  var _cancelled = false;
  var _terminal = false;
  var _receivedBytes = 0;
  var _totalBytes = 0;
  ModelPreparationProgress _progress = const ModelPreparationProgress(
    phase: ModelPreparationPhase.checking,
    receivedBytes: 0,
    totalBytes: 0,
  );

  @override
  Future<LocalModelBundle> get result => _result.future;

  @override
  ModelPreparationProgress get progress => _progress;

  void start() {
    unawaited(_run());
  }

  @override
  void cancel() {
    if (_terminal || _cancelled) return;
    _cancelled = true;
    _client?.close(force: true);
  }

  Future<void> _run() async {
    ModelPreparationFailure? outcome;
    LocalModelBundle? bundle;
    try {
      final trusted = _validateDescriptor();
      _totalBytes = trusted.totalBytes;
      _setProgress(ModelPreparationPhase.checking);
      _checkCancelled();
      final root = await _prepareRoot();
      _checkCancelled();
      final active = Directory(
        '${root.path}${Platform.pathSeparator}bundle-${trusted.fingerprint}',
      );
      final activeType = await FileSystemEntity.type(
        active.path,
        followLinks: false,
      );
      _checkCancelled();
      if (activeType != FileSystemEntityType.notFound) {
        if (activeType != FileSystemEntityType.directory) {
          throw _integrity('Installed model destination is not a directory.');
        }
        bundle = await _verifyBundle(active, trusted);
        _checkCancelled();
      } else {
        bundle = await _downloadAndActivate(root, active, trusted);
        _checkCancelled();
      }
    } on ModelPreparationFailure catch (error) {
      outcome = error;
    } on FileSystemException {
      outcome = _storage('Model storage operation failed.');
    } on TimeoutException {
      outcome = _cancelled
          ? _cancelledFailure()
          : _network('Network operation timed out.');
    } on SocketException {
      outcome = _cancelled
          ? _cancelledFailure()
          : _network('Network request failed.');
    } on HttpException {
      outcome = _cancelled
          ? _cancelledFailure()
          : _network('Network request failed.');
    } on TlsException {
      outcome = _cancelled
          ? _cancelledFailure()
          : _network('Secure network request failed.');
    } on Object {
      outcome = _cancelled
          ? _cancelledFailure()
          : _network('Network client operation failed.');
    } finally {
      _client?.close(force: true);
      _client = null;
      final stage = _stage;
      if (stage != null) {
        try {
          if (await stage.exists()) await stage.delete(recursive: true);
        } on FileSystemException {
          // Cleanup never replaces the original operation outcome.
        }
      }
      _stage = null;
    }

    if (_cancelled && outcome == null) outcome = _cancelledFailure();
    if (outcome != null) {
      _finishFailure(outcome);
      return;
    }
    _setProgress(ModelPreparationPhase.ready);
    _terminal = true;
    _result.complete(bundle!);
  }

  _TrustedDescriptor _validateDescriptor() {
    if (timeout <= Duration.zero) {
      throw _invalidDescriptor('Timeout must be positive.');
    }
    if (!_boundedNonEmpty(descriptor.id) ||
        !_boundedNonEmpty(descriptor.version)) {
      throw _invalidDescriptor('Descriptor id and version must be non-empty.');
    }
    if (maxRedirects < 0 ||
        maxRedirects > 5 ||
        allowedRedirectOrigins.any(
          (uri) =>
              !_validHttpsUri(uri) ||
              uri.hasQuery ||
              (uri.path.isNotEmpty && uri.path != '/'),
        )) {
      throw _invalidDescriptor('Invalid HTTPS redirect policy.');
    }
    final files = descriptor.files;
    if (files.isEmpty || files.length > FileModelStore.maxEntries) {
      throw _invalidDescriptor('Descriptor file count is invalid.');
    }
    final roles = <String>{};
    final paths = <String>{};
    final pathList = <String>[];
    var totalBytes = 0;
    for (final download in files) {
      final entry = download.entry;
      if (!_allowedRoles.contains(entry.role)) {
        throw _invalidDescriptor('Descriptor contains an unsupported role.');
      }
      if (entry.role != 'license' && !roles.add(entry.role)) {
        throw _invalidDescriptor('Descriptor contains a duplicate role.');
      }
      if (entry.bytes < 0 || entry.bytes > FileModelStore.maxFileBytes) {
        throw _invalidDescriptor('Descriptor contains an invalid byte count.');
      }
      totalBytes += entry.bytes;
      if (totalBytes > FileModelStore.maxTotalBytes) {
        throw _invalidDescriptor('Descriptor total byte count is too large.');
      }
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.sha256)) {
        throw _invalidDescriptor('Descriptor contains an invalid SHA-256.');
      }
      if (!_boundedNonEmpty(entry.source)) {
        throw _invalidDescriptor(
          'Descriptor contains invalid source metadata.',
        );
      }
      _validatePath(entry.path, name: 'file path');
      _validatePath(entry.license, name: 'license path');
      final folded = entry.path.toLowerCase();
      if (folded == 'manifest.json' ||
          folded.startsWith('manifest.json/') ||
          !paths.add(folded)) {
        throw _invalidDescriptor(
          'Descriptor contains a reserved or duplicate path.',
        );
      }
      pathList.add(folded);
      final uri = download.uri;
      if (!_validHttpsUri(uri)) {
        throw _invalidDescriptor(
          'Descriptor contains an invalid HTTPS source.',
        );
      }
    }
    if (!roles.containsAll(_requiredRoles)) {
      throw _invalidDescriptor('Descriptor misses a required model role.');
    }
    for (var index = 0; index < pathList.length; index += 1) {
      for (var other = index + 1; other < pathList.length; other += 1) {
        final first = pathList[index];
        final second = pathList[other];
        if (first.startsWith('$second/') || second.startsWith('$first/')) {
          throw _invalidDescriptor(
            'Descriptor paths have a file-directory collision.',
          );
        }
      }
    }
    final licenses = files
        .where((download) => download.entry.role == 'license')
        .map((download) => download.entry.path)
        .toSet();
    if (licenses.isEmpty ||
        files.any((download) => !licenses.contains(download.entry.license))) {
      throw _invalidDescriptor(
        'Descriptor contains an invalid license reference.',
      );
    }
    final manifest = _canonicalManifest(files);
    final manifestBytes = utf8.encode(manifest);
    if (manifestBytes.length > FileModelStore.maxManifestBytes) {
      throw _invalidDescriptor('Canonical manifest exceeds the size limit.');
    }
    final identity = jsonEncode(<String, Object?>{
      'id': descriptor.id,
      'version': descriptor.version,
      'manifest': jsonDecode(manifest),
      'urls': files.map((download) => download.uri.toString()).toList(),
    });
    return _TrustedDescriptor(
      manifestBytes: manifestBytes,
      fingerprint: sha256.convert(utf8.encode(identity)).toString(),
      totalBytes: totalBytes,
    );
  }

  Future<Directory> _prepareRoot() async {
    if (rootDirectory.trim().isEmpty) {
      throw _storage('Model storage root is empty.');
    }
    final root = Directory(rootDirectory);
    final before = await FileSystemEntity.type(root.path, followLinks: false);
    if (before == FileSystemEntityType.notFound) {
      await root.create(recursive: true);
    } else if (before != FileSystemEntityType.directory) {
      throw _storage('Model storage root is not a directory.');
    }
    final after = await FileSystemEntity.type(root.path, followLinks: false);
    if (after != FileSystemEntityType.directory) {
      throw _storage('Model storage root is not a directory.');
    }
    return root;
  }

  Future<LocalModelBundle> _downloadAndActivate(
    Directory root,
    Directory active,
    _TrustedDescriptor trusted,
  ) async {
    try {
      _stage = await root.createTemp('.stage-${trusted.fingerprint}-');
    } on FileSystemException {
      throw _storage('Cannot create model staging storage.');
    }
    _checkCancelled();
    try {
      _client = httpClientFactory();
    } on Object {
      throw _network('Cannot create network client.');
    }
    final client = _client!;
    client
      ..autoUncompress = false
      ..connectionTimeout = timeout;

    for (final download in descriptor.files) {
      _checkCancelled();
      _setProgress(
        ModelPreparationPhase.downloading,
        currentPath: download.entry.path,
      );
      await _downloadFile(client, _stage!, download);
    }
    _checkCancelled();
    try {
      await File(
        '${_stage!.path}${Platform.pathSeparator}manifest.json',
      ).writeAsBytes(trusted.manifestBytes, flush: true);
    } on FileSystemException {
      throw _storage('Cannot write the staged model manifest.');
    }
    _checkCancelled();
    await _verifyBundle(_stage!, trusted);
    _checkCancelled();
    _setProgress(ModelPreparationPhase.verifying);

    final before = await FileSystemEntity.type(active.path, followLinks: false);
    if (before != FileSystemEntityType.notFound) {
      if (before != FileSystemEntityType.directory) {
        throw _integrity('Installed model destination is occupied.');
      }
      return _verifyBundle(active, trusted);
    }
    try {
      await _stage!.rename(active.path);
      _stage = null;
      _checkCancelled();
      return LocalModelBundle(
        directory: active.path,
        manifestPath: '${active.path}${Platform.pathSeparator}manifest.json',
      );
    } on FileSystemException {
      final winnerType = await FileSystemEntity.type(
        active.path,
        followLinks: false,
      );
      if (winnerType == FileSystemEntityType.directory) {
        final winner = await _verifyBundle(active, trusted);
        _checkCancelled();
        return winner;
      }
      if (winnerType != FileSystemEntityType.notFound) {
        throw _integrity('Installed model destination is occupied.');
      }
      throw _storage('Cannot activate the verified model bundle.');
    }
  }

  Future<HttpClientResponse> _request(HttpClient client, Uri uri) async {
    HttpClientRequest request;
    try {
      request = await client.getUrl(uri).timeout(timeout);
      request
        ..followRedirects = false
        ..persistentConnection = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    } on TimeoutException {
      throw _cancelled
          ? _cancelledFailure()
          : _network('Network request timed out.');
    } on Object {
      throw _cancelled
          ? _cancelledFailure()
          : _network('Network request failed.');
    }
    _checkCancelled();
    HttpClientResponse response;
    try {
      response = await request.close().timeout(timeout);
    } on TimeoutException {
      request.abort();
      throw _cancelled
          ? _cancelledFailure()
          : _network('Network response headers timed out.');
    } on Object {
      throw _cancelled
          ? _cancelledFailure()
          : _network('Network response failed.');
    }
    _checkCancelled();
    return response;
  }

  Future<HttpClientResponse> _openDownload(
    HttpClient client,
    Uri source,
  ) async {
    var current = source;
    final visited = <Uri>{source};
    final origins = <String>{
      source.origin,
      ...allowedRedirectOrigins.map((uri) => uri.origin),
    };
    for (var hops = 0; ; hops++) {
      final response = await _request(client, current);
      if (response.statusCode == HttpStatus.ok) return response;
      if (!const {301, 302, 303, 307, 308}.contains(response.statusCode) ||
          hops >= maxRedirects) {
        throw _network(
          'Network response did not return status 200 within the redirect policy.',
        );
      }
      final locations = response.headers[HttpHeaders.locationHeader];
      Uri? target;
      if (locations != null &&
          locations.length == 1 &&
          locations.single.isNotEmpty &&
          utf8.encode(locations.single).length <=
              FileModelStore.maxManifestBytes) {
        try {
          target = current.resolve(locations.single);
        } on FormatException {
          // Invalid remote metadata is a transport error, not a host descriptor.
        }
      }
      if (target == null ||
          !_validHttpsUri(target) ||
          !origins.contains(target.origin) ||
          !visited.add(target)) {
        throw _network('Network redirect destination is not permitted.');
      }
      // Cancel the redirect body rather than draining unbounded remote data.
      // persistentConnection=false prevents this socket from being reused.
      await response.listen((_) {}).cancel().timeout(timeout);
      _checkCancelled();
      current = target;
    }
  }

  Future<void> _downloadFile(
    HttpClient client,
    Directory stage,
    ModelDownload download,
  ) async {
    final response = await _openDownload(client, download.uri);
    final encodings = response.headers[HttpHeaders.contentEncodingHeader];
    if (encodings != null &&
        encodings
            .expand((value) => value.split(','))
            .any((value) => value.trim().toLowerCase() != 'identity')) {
      throw _network('Network response uses an unsupported content encoding.');
    }
    if (response.contentLength >= 0 &&
        response.contentLength != download.entry.bytes) {
      throw _integrity('Downloaded byte count does not match the descriptor.');
    }

    final output = File(
      '${stage.path}${Platform.pathSeparator}${download.entry.path}',
    );
    RandomAccessFile? sink;
    final digestSink = _DigestSink();
    final input = sha256.startChunkedConversion(digestSink);
    var fileBytes = 0;
    try {
      await output.parent.create(recursive: true);
      sink = await output.open(mode: FileMode.write);
      await for (final received in response.timeout(timeout)) {
        _checkCancelled();
        var offset = 0;
        while (offset < received.length) {
          _checkCancelled();
          final end = min(offset + _writeChunkBytes, received.length);
          final length = end - offset;
          if (fileBytes + length > download.entry.bytes) {
            throw _integrity('Downloaded byte count exceeds the descriptor.');
          }
          input.add(received.sublist(offset, end));
          await sink.writeFrom(received, offset, end);
          fileBytes += length;
          _receivedBytes += length;
          _setProgress(
            ModelPreparationPhase.downloading,
            currentPath: download.entry.path,
          );
          offset = end;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } on ModelPreparationFailure {
      rethrow;
    } on TimeoutException {
      throw _cancelled
          ? _cancelledFailure()
          : _network('Network response body timed out.');
    } on FileSystemException {
      throw _storage('Cannot write downloaded model content.');
    } on Object {
      throw _cancelled
          ? _cancelledFailure()
          : _network('Network response body failed.');
    } finally {
      input.close();
      if (sink != null) {
        try {
          await sink.close();
        } on FileSystemException {
          // The primary write or verification result remains authoritative.
        }
      }
    }
    _checkCancelled();
    if (fileBytes != download.entry.bytes) {
      throw _integrity('Downloaded byte count does not match the descriptor.');
    }
    final actualDigest = digestSink.value.toString();
    if (actualDigest != download.entry.sha256) {
      throw _integrity('Downloaded SHA-256 does not match the descriptor.');
    }
  }

  Future<LocalModelBundle> _verifyBundle(
    Directory directory,
    _TrustedDescriptor trusted,
  ) async {
    _setProgress(ModelPreparationPhase.verifying);
    _checkCancelled();
    final rootType = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (rootType != FileSystemEntityType.directory) {
      throw _integrity('Installed model root is not a regular directory.');
    }
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}manifest.json',
    );
    final manifestType = await FileSystemEntity.type(
      manifest.path,
      followLinks: false,
    );
    if (manifestType != FileSystemEntityType.file) {
      throw _integrity('Installed model manifest is missing or unsafe.');
    }
    final length = await manifest.length();
    if (length != trusted.manifestBytes.length ||
        length > FileModelStore.maxManifestBytes) {
      throw _integrity('Installed model manifest differs from the descriptor.');
    }
    final bytes = await manifest.readAsBytes();
    if (!_equalBytes(bytes, trusted.manifestBytes)) {
      throw _integrity('Installed model manifest differs from the descriptor.');
    }
    for (final download in descriptor.files) {
      _checkCancelled();
      await _requireRegularManagedPath(directory, download.entry.path);
    }
    final bundle = LocalModelBundle(
      directory: directory.path,
      manifestPath: manifest.path,
    );
    try {
      await const FileModelStore().validate(bundle);
    } on AgentFailure catch (error) {
      // FileModelStore wraps FileSystemException with this internal prefix;
      // the cached-permission regression protects this classification bridge.
      if (error.message.startsWith('Cannot resolve model files:')) {
        throw _storage('Cannot read installed model content.');
      }
      throw _integrity('Installed model content differs from the descriptor.');
    }
    _checkCancelled();
    return bundle;
  }

  Future<void> _requireRegularManagedPath(
    Directory root,
    String relative,
  ) async {
    final components = relative.split('/');
    var current = root.path;
    for (var index = 0; index < components.length; index += 1) {
      current = '$current${Platform.pathSeparator}${components[index]}';
      final type = await FileSystemEntity.type(current, followLinks: false);
      final expected = index == components.length - 1
          ? FileSystemEntityType.file
          : FileSystemEntityType.directory;
      if (type != expected) {
        throw _integrity('Installed model path is missing or unsafe.');
      }
    }
  }

  String _canonicalManifest(List<ModelDownload> files) =>
      jsonEncode(<String, Object?>{
        'schema': 1,
        'profile': _profile,
        'runtime': _runtime,
        'inputRate': _inputRate,
        'files': files
            .map(
              (download) => <String, Object?>{
                'role': download.entry.role,
                'path': download.entry.path,
                'bytes': download.entry.bytes,
                'sha256': download.entry.sha256,
                'source': download.entry.source,
                'license': download.entry.license,
              },
            )
            .toList(),
      });

  void _validatePath(String value, {required String name}) {
    if (value.isEmpty ||
        value.startsWith('/') ||
        value.contains('\\') ||
        value.contains('..') ||
        value.contains(':') ||
        value.codeUnits.any((unit) => unit > 0x7f || unit == 0)) {
      throw _invalidDescriptor('Descriptor contains an invalid $name.');
    }
    final components = value.split('/');
    if (components.any(
      (component) =>
          component.isEmpty ||
          component == '.' ||
          component == '..' ||
          !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(component),
    )) {
      throw _invalidDescriptor('Descriptor contains an invalid $name.');
    }
  }

  bool _boundedNonEmpty(String value) =>
      value.trim().isNotEmpty &&
      utf8.encode(value).length <= FileModelStore.maxManifestBytes;

  void _checkCancelled() {
    if (_cancelled) throw _cancelledFailure();
  }

  void _setProgress(
    ModelPreparationPhase phase, {
    String? currentPath,
    ModelPreparationFailure? failure,
  }) {
    if (_terminal) return;
    _progress = ModelPreparationProgress(
      phase: phase,
      receivedBytes: _receivedBytes,
      totalBytes: _totalBytes,
      currentPath: currentPath,
      failure: failure,
    );
  }

  void _finishFailure(ModelPreparationFailure failure) {
    if (_terminal) return;
    _terminal = true;
    _progress = ModelPreparationProgress(
      phase: failure.code == ModelPreparationErrorCode.cancelled
          ? ModelPreparationPhase.cancelled
          : ModelPreparationPhase.failed,
      receivedBytes: _receivedBytes,
      totalBytes: _totalBytes,
      failure: failure,
    );
    _result.completeError(failure);
  }
}

final class _TrustedDescriptor {
  const _TrustedDescriptor({
    required this.manifestBytes,
    required this.fingerprint,
    required this.totalBytes,
  });

  final List<int> manifestBytes;
  final String fingerprint;
  final int totalBytes;
}

final class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value!;

  @override
  void add(Digest data) {
    if (_value != null) throw StateError('Digest already completed.');
    _value = data;
  }

  @override
  void close() {}
}

bool _equalBytes(List<int> first, List<int> second) {
  if (first.length != second.length) return false;
  var difference = 0;
  for (var index = 0; index < first.length; index += 1) {
    difference |= first[index] ^ second[index];
  }
  return difference == 0;
}

ModelPreparationFailure _invalidDescriptor(String message) =>
    ModelPreparationFailure(
      ModelPreparationErrorCode.invalidDescriptor,
      message,
    );
ModelPreparationFailure _network(String message) =>
    ModelPreparationFailure(ModelPreparationErrorCode.network, message);
ModelPreparationFailure _integrity(String message) =>
    ModelPreparationFailure(ModelPreparationErrorCode.integrity, message);
ModelPreparationFailure _storage(String message) =>
    ModelPreparationFailure(ModelPreparationErrorCode.storage, message);
ModelPreparationFailure _cancelledFailure() => const ModelPreparationFailure(
  ModelPreparationErrorCode.cancelled,
  'Model preparation was cancelled.',
);

bool _validHttpsUri(Uri uri) {
  try {
    return uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        (!uri.hasPort || (uri.port >= 1 && uri.port <= 65535)) &&
        utf8.encode(uri.toString()).length <= FileModelStore.maxManifestBytes;
  } on FormatException {
    return false;
  }
}
