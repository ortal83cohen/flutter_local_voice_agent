import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/src/model_preparation.dart';
import 'package:flutter_local_voice_agent/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/preparation_https_server.dart';

ModelPackDescriptor descriptor(Uri uri) => ModelPackDescriptor(
  id: 'redirect-test',
  version: '1',
  files: [
    for (final role in [
      'vad',
      'encoder',
      'decoder',
      'joiner',
      'asrTokens',
      'ttsModel',
      'ttsTokens',
      'ttsLexicon',
      'license',
    ])
      ModelDownload(
        entry: ModelFileEntry(
          role: role,
          path: '$role.bin',
          bytes: 1,
          sha256: sha256.convert([1]).toString(),
          source: 'synthetic TLS',
          license: 'license.bin',
        ),
        uri: uri,
      ),
  ],
);

Matcher failure(ModelPreparationErrorCode code) =>
    isA<ModelPreparationFailure>().having((e) => e.code, 'code', code);

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('flva-redirect-'),
  );
  tearDown(() async => root.delete(recursive: true));

  test(
    'default rejects; opt-in follows all supported redirects and relative targets',
    () async {
      for (final status in [301, 302, 303, 307, 308]) {
        final server = await PreparationHttpsServer.start((request) async {
          if (request.uri.path == '/start') {
            request.response.statusCode = status;
            request.response.headers.set('location', '/final');
          } else {
            expect(request.headers.value('authorization'), isNull);
            expect(request.headers.value('cookie'), isNull);
            expect(request.headers.value('accept-encoding'), 'identity');
            request.response.add([1]);
          }
          await request.response.close();
        });
        try {
          await expectLater(
            ModelPreparationManager(
              rootDirectory: '${root.path}/deny-$status',
              httpClientFactory: server.createClient,
            ).prepare(descriptor(server.uri('/start'))).result,
            throwsA(failure(ModelPreparationErrorCode.network)),
          );
          final result = await ModelPreparationManager(
            rootDirectory: '${root.path}/allow-$status',
            httpClientFactory: server.createClient,
            maxRedirects: 1,
          ).prepare(descriptor(server.uri('/start'))).result;
          expect(await File(result.manifestPath).exists(), isTrue);
        } finally {
          await server.close();
        }
      }
    },
  );

  test(
    'rejects unsafe locations, loops and hop exhaustion without visiting targets',
    () async {
      for (final location in [
        'http://127.0.0.1/model',
        'https://user:secret@localhost/model',
        'https://localhost:65536/model',
        'https://localhost/model#fragment',
        'https://untrusted.invalid/model',
        'https://[malformed',
        '/start',
        '/next',
      ]) {
        var nextRequests = 0;
        final server = await PreparationHttpsServer.start((request) async {
          if (request.uri.path == '/next') nextRequests++;
          request.response.statusCode = 302;
          request.response.headers.set(
            'location',
            request.uri.path == '/next' ? '/third' : location,
          );
          await request.response.close();
        });
        try {
          final preparation = ModelPreparationManager(
            rootDirectory: '${root.path}/pack',
            httpClientFactory: server.createClient,
            maxRedirects: 1,
          ).prepare(descriptor(server.uri('/start')));
          await expectLater(
            preparation.result,
            throwsA(failure(ModelPreparationErrorCode.network)),
          );
          expect(nextRequests, location == '/next' ? 1 : 0);
          expect(
            await root
                .list(recursive: true)
                .where((e) => e.path.contains('bundle-'))
                .isEmpty,
            isTrue,
          );
        } finally {
          await server.close();
        }
      }
    },
  );

  test(
    'cross-origin redirect requires exact opt-in, keeps final hash validation',
    () async {
      var corrupt = false;
      final target = await PreparationHttpsServer.start((request) async {
        expect(request.headers.value('authorization'), isNull);
        request.response.add([corrupt ? 2 : 1]);
        await request.response.close();
      });
      final source = await PreparationHttpsServer.start((request) async {
        request.response.statusCode = 302;
        request.response.headers.set(
          'location',
          target.uri('/model').toString(),
        );
        await request.response.close();
      });
      HttpClient client() {
        final trustedCertificates = {
          utf8.decode(source.certificateBytes),
          utf8.decode(target.certificateBytes),
        };
        return HttpClient(context: SecurityContext(withTrustedRoots: false))
          ..badCertificateCallback = (certificate, host, port) =>
              host == '127.0.0.1' &&
              {source.serverPort, target.serverPort}.contains(port) &&
              trustedCertificates.contains(certificate.pem);
      }

      try {
        await expectLater(
          ModelPreparationManager(
            rootDirectory: '${root.path}/denied',
            httpClientFactory: client,
            maxRedirects: 5,
          ).prepare(descriptor(source.uri('/start'))).result,
          throwsA(failure(ModelPreparationErrorCode.network)),
        );
        expect(target.requestCount, 0);
        final allowed = [Uri.parse(target.uri('/').origin)];
        await ModelPreparationManager(
          rootDirectory: '${root.path}/allowed',
          httpClientFactory: client,
          maxRedirects: 5,
          allowedRedirectOrigins: allowed,
        ).prepare(descriptor(source.uri('/start'))).result;
        corrupt = true;
        await expectLater(
          ModelPreparationManager(
            rootDirectory: '${root.path}/corrupt',
            httpClientFactory: client,
            maxRedirects: 5,
            allowedRedirectOrigins: allowed,
          ).prepare(descriptor(source.uri('/start'))).result,
          throwsA(failure(ModelPreparationErrorCode.integrity)),
        );
      } finally {
        await source.close();
        await target.close();
      }
    },
  );

  test(
    'invalid policy fails before storage/client effects and copies allowlist',
    () async {
      var clients = 0;
      for (final count in [-1, 6]) {
        await expectLater(
          ModelPreparationManager(
            rootDirectory: '${root.path}/absent',
            maxRedirects: count,
            httpClientFactory: () {
              clients++;
              return HttpClient();
            },
          ).prepare(descriptor(Uri.parse('https://example.com/model'))).result,
          throwsA(failure(ModelPreparationErrorCode.invalidDescriptor)),
        );
      }
      for (final origin in [
        'http://example.com',
        'https://example.com/path',
        'https://user@example.com',
        'https://example.com?key=value',
      ]) {
        await expectLater(
          ModelPreparationManager(
            rootDirectory: '${root.path}/absent',
            maxRedirects: 1,
            allowedRedirectOrigins: [Uri.parse(origin)],
          ).prepare(descriptor(Uri.parse('https://example.com/model'))).result,
          throwsA(failure(ModelPreparationErrorCode.invalidDescriptor)),
        );
      }
      final origins = [Uri.parse('https://example.com')];
      final manager = ModelPreparationManager(
        rootDirectory: root.path,
        allowedRedirectOrigins: origins,
      );
      origins.clear();
      expect(manager.allowedRedirectOrigins, hasLength(1));
      expect(
        () => manager.allowedRedirectOrigins.clear(),
        throwsUnsupportedError,
      );
      expect(clients, 0);
      expect(await Directory('${root.path}/absent').exists(), isFalse);
    },
  );

  test(
    'cancel interrupts redirected header wait; timeout stays bounded',
    () async {
      final reached = Completer<void>();
      final release = Completer<void>();
      final server = await PreparationHttpsServer.start((request) async {
        if (request.uri.path == '/start') {
          request.response.statusCode = 302;
          request.response.headers.set('location', '/wait');
        } else {
          if (!reached.isCompleted) reached.complete();
          await release.future;
        }
        await request.response.close();
      });
      try {
        final p = ModelPreparationManager(
          rootDirectory: '${root.path}/cancel',
          maxRedirects: 1,
          httpClientFactory: server.createClient,
        ).prepare(descriptor(server.uri('/start')));
        final expected = expectLater(
          p.result,
          throwsA(failure(ModelPreparationErrorCode.cancelled)),
        );
        await reached.future.timeout(const Duration(seconds: 5));
        p.cancel();
        await expected.timeout(const Duration(seconds: 5));
        await expectLater(
          ModelPreparationManager(
            rootDirectory: '${root.path}/timeout',
            maxRedirects: 1,
            timeout: const Duration(milliseconds: 500),
            httpClientFactory: server.createClient,
          ).prepare(descriptor(server.uri('/start'))).result,
          throwsA(failure(ModelPreparationErrorCode.network)),
        );
      } finally {
        release.complete();
        await server.close();
      }
    },
  );
}
