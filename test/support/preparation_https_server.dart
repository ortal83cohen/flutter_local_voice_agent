import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Handles one request received by [PreparationHttpsServer].
typedef PreparationHttpsHandler = FutureOr<void> Function(HttpRequest request);

/// Loopback HTTPS server with a runtime-generated certificate trusted by clients.
final class PreparationHttpsServer {
  PreparationHttpsServer._({
    required this._server,
    required this._certificateDirectory,
    required this._certificatePath,
    required this._handler,
  });

  final HttpServer _server;
  final Directory _certificateDirectory;
  final String _certificatePath;
  final PreparationHttpsHandler _handler;
  StreamSubscription<HttpRequest>? _subscription;

  /// Number of requests accepted by this server.
  int requestCount = 0;

  /// Certificate bytes for a separately isolated test client trust store.
  Uint8List get certificateBytes => File(_certificatePath).readAsBytesSync();

  /// Starts a TLS server bound only to IPv4 loopback.
  static Future<PreparationHttpsServer> start(
    PreparationHttpsHandler handler,
  ) async {
    final certificateDirectory = await Directory.systemTemp.createTemp(
      'flva-preparation-tls-',
    );
    final config = File('${certificateDirectory.path}/openssl.cnf');
    final certificate = '${certificateDirectory.path}/certificate.pem';
    final key = '${certificateDirectory.path}/key.pem';
    await config.writeAsString('''
[req]
distinguished_name = subject
x509_extensions = extensions
prompt = no

[subject]
CN = localhost

[extensions]
subjectAltName = @names
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign
extendedKeyUsage = serverAuth

[names]
DNS.1 = localhost
IP.1 = 127.0.0.1
''');
    final generated = await Process.run('openssl', <String>[
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-sha256',
      '-nodes',
      '-days',
      '1',
      '-keyout',
      key,
      '-out',
      certificate,
      '-config',
      config.path,
    ]);
    if (generated.exitCode != 0) {
      await certificateDirectory.delete(recursive: true);
      throw StateError('Failed to generate the loopback TLS certificate.');
    }
    final context = SecurityContext()
      ..useCertificateChain(certificate)
      ..usePrivateKey(key);
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    final fixture = PreparationHttpsServer._(
      server: server,
      certificateDirectory: certificateDirectory,
      certificatePath: certificate,
      handler: handler,
    );
    fixture._subscription = server.listen(fixture._handle);
    return fixture;
  }

  /// Resolves [path] against this server without exposing its port elsewhere.
  Uri uri(String path) => Uri(
    scheme: 'https',
    host: InternetAddress.loopbackIPv4.address,
    port: _server.port,
    path: path,
  );

  /// Creates a client that trusts only this server's generated certificate.
  HttpClient createClient() {
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(_certificatePath);
    return HttpClient(context: context);
  }

  /// Stops the server and removes its generated certificate and private key.
  Future<void> close() async {
    await _subscription?.cancel();
    await _server.close(force: true);
    if (await _certificateDirectory.exists()) {
      await _certificateDirectory.delete(recursive: true);
    }
  }

  Future<void> _handle(HttpRequest request) async {
    requestCount += 1;
    try {
      await _handler(request);
    } on Object {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } on Object {
        // A client cancellation can close the response before the handler ends.
      }
    }
  }
}
