import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/preparation_https_server.dart';

const _requiredRoles = <String>[
  'vad',
  'encoder',
  'decoder',
  'joiner',
  'asrTokens',
  'ttsModel',
  'ttsTokens',
  'ttsLexicon',
];

void main() {
  group('descriptor validation', () {
    test('copies descriptor records and exposes an unmodifiable list', () {
      final original = _downloads(
        Uri.parse('https://models.example.test/files/'),
        _payloads(),
      );
      final originalEntry = original.first.entry;
      final descriptor = ModelPackDescriptor(
        id: 'speech',
        version: '1',
        files: original,
      );
      original.clear();

      expect(descriptor.files, hasLength(_requiredRoles.length + 1));
      expect(
        () => descriptor.files.add(descriptor.files.first),
        throwsUnsupportedError,
      );
      expect(identical(descriptor.files.first.entry, originalEntry), isFalse);
    });

    test(
      'rejects malformed descriptors before disk or network effects',
      () async {
        final payloads = _payloads();
        final base = Uri.parse('https://models.example.test/files/');
        final valid = _downloads(base, payloads);
        final oversizedTotal = _replace(
          _replace(
            _replace(valid, 0, byteCount: FileModelStore.maxFileBytes),
            1,
            byteCount: FileModelStore.maxFileBytes,
          ),
          2,
          byteCount: 1,
        );
        final tooMany = List<ModelDownload>.generate(
          FileModelStore.maxEntries + 1,
          (index) => _download(
            role: index == 0 ? 'vad' : 'license',
            path: 'extra-$index',
            bytes: Uint8List(0),
            uri: base.resolve('extra-$index'),
            license: index == 0 ? 'extra-1' : 'extra-$index',
          ),
        );
        final cases = <String, List<ModelDownload>>{
          'missing required role': valid
              .where((item) => item.entry.role != 'vad')
              .toList(),
          'unsupported role': <ModelDownload>[
            ...valid,
            _download(
              role: 'other',
              path: 'other',
              bytes: Uint8List(0),
              uri: base.resolve('other'),
            ),
          ],
          'missing license': valid
              .where((item) => item.entry.role != 'license')
              .toList(),
          'traversal': _replace(valid, 0, path: '../vad'),
          'embedded dots rejected by store': _replace(
            valid,
            0,
            path: 'vad..bin',
          ),
          'backslash': _replace(valid, 0, path: r'dir\vad'),
          'absolute path': _replace(valid, 0, path: '/models/vad'),
          'empty segment': _replace(valid, 0, path: 'models//vad'),
          'dot segment': _replace(valid, 0, path: 'models/./vad'),
          'non-ASCII path': _replace(valid, 0, path: 'models/väd'),
          'duplicate role': _replace(valid, 1, role: valid.first.entry.role),
          'case-folded duplicate': _replace(
            valid,
            1,
            path: valid.first.entry.path.toUpperCase(),
          ),
          'file-directory collision': _replace(
            valid,
            1,
            path: '${valid.first.entry.path}/child',
          ),
          'reserved manifest': _replace(valid, 0, path: 'MANIFEST.JSON'),
          'reserved manifest prefix': _replace(
            valid,
            0,
            path: 'Manifest.Json/child',
          ),
          'invalid digest': _replace(valid, 0, sha256Value: 'A' * 64),
          'oversized file': _replace(
            valid,
            0,
            byteCount: FileModelStore.maxFileBytes + 1,
          ),
          'oversized total': oversizedTotal,
          'unlisted license reference': _replace(
            valid,
            0,
            license: 'licenses/OTHER.txt',
          ),
          'unbounded source': _replace(
            valid,
            0,
            sourceMetadata: 's' * (FileModelStore.maxManifestBytes + 1),
          ),
          'too many entries': tooMany,
        };

        for (final entry in cases.entries) {
          final parent = await Directory.systemTemp.createTemp(
            'flva-invalid-parent-',
          );
          addTearDown(() => _deleteIfPresent(parent));
          final root = Directory('${parent.path}/models');
          var clients = 0;
          final operation =
              ModelPreparationManager(
                rootDirectory: root.path,
                httpClientFactory: () {
                  clients += 1;
                  return HttpClient();
                },
              ).prepare(
                ModelPackDescriptor(
                  id: 'speech',
                  version: '1',
                  files: entry.value,
                ),
              );
          await _expectFailure(
            operation,
            ModelPreparationErrorCode.invalidDescriptor,
            reason: entry.key,
          );
          expect(await root.exists(), isFalse, reason: entry.key);
          expect(clients, 0, reason: entry.key);
        }
      },
    );

    test('rejects unsafe URL forms and invalid manager timeout', () async {
      final valid = _downloads(
        Uri.parse('https://models.example.test/files/'),
        _payloads(),
      );
      final urls = <Uri>[
        Uri.parse('http://models.example.test/vad'),
        Uri.parse('https:///vad'),
        Uri.parse('https://user:secret@models.example.test/vad'),
        Uri.parse('https://models.example.test/vad#fragment'),
        Uri.parse('https://models.example.test:0/vad'),
        Uri.parse('https://models.example.test:65536/vad'),
        Uri.parse('https://models.example.test:999999999999999999/vad'),
      ];
      for (final uri in urls) {
        final root = Directory(
          '${Directory.systemTemp.path}/flva-never-created-${DateTime.now().microsecondsSinceEpoch}',
        );
        final operation =
            ModelPreparationManager(
              rootDirectory: root.path,
              httpClientFactory: () => throw StateError('must not run'),
            ).prepare(
              ModelPackDescriptor(
                id: 'speech',
                version: '1',
                files: _replace(valid, 0, uri: uri),
              ),
            );
        await _expectFailure(
          operation,
          ModelPreparationErrorCode.invalidDescriptor,
        );
        expect(await root.exists(), isFalse);
      }

      final root = await Directory.systemTemp.createTemp('flva-timeout-');
      addTearDown(() => _deleteIfPresent(root));
      final operation = ModelPreparationManager(
        rootDirectory: root.path,
        timeout: Duration.zero,
      ).prepare(ModelPackDescriptor(id: 'speech', version: '1', files: valid));
      await _expectFailure(
        operation,
        ModelPreparationErrorCode.invalidDescriptor,
      );
    });
  });

  test(
    'installs over real TLS then reuses a fully rehashed offline cache',
    () async {
      final payloads = _payloads(large: true, llm: true);
      final server = await _servePayloads(payloads, responseChunkBytes: 90000);
      addTearDown(server.close);
      final root = await Directory.systemTemp.createTemp('flva-prepare-');
      addTearDown(() => _deleteIfPresent(root));
      final descriptor = _descriptor(server, payloads);

      final first = ModelPreparationManager(
        rootDirectory: root.path,
        httpClientFactory: server.createClient,
      ).prepare(descriptor);
      final bundle = await first.result;
      expect(first.progress.phase, ModelPreparationPhase.ready);
      expect(first.progress.receivedBytes, first.progress.totalBytes);
      expect(server.requestCount, descriptor.files.length);
      expect(
        await const FileModelStore().validate(bundle),
        isA<ValidatedModelBundle>(),
      );
      final requestCount = server.requestCount;

      var clients = 0;
      final reused = ModelPreparationManager(
        rootDirectory: root.path,
        httpClientFactory: () {
          clients += 1;
          throw StateError('offline cache must not construct a client');
        },
      ).prepare(descriptor);
      expect((await reused.result).directory, bundle.directory);
      expect(reused.progress.phase, ModelPreparationPhase.ready);
      expect(clients, 0);
      expect(server.requestCount, requestCount);
    },
  );

  test('accepts an explicitly listed empty license file', () async {
    final payloads = _payloads()..['license'] = Uint8List(0);
    final server = await _servePayloads(payloads);
    addTearDown(server.close);
    final root = await Directory.systemTemp.createTemp('flva-empty-license-');
    addTearDown(() => _deleteIfPresent(root));
    final bundle = await ModelPreparationManager(
      rootDirectory: root.path,
      httpClientFactory: server.createClient,
    ).prepare(_descriptor(server, payloads)).result;
    expect(
      await const FileModelStore().validate(bundle),
      isA<ValidatedModelBundle>(),
    );
  });

  group('response integrity and transport', () {
    test('rejects status and does not expose URL or body in failure', () async {
      const secretBody = 'remote-secret-response-body';
      final payloads = _payloads();
      final server = await PreparationHttpsServer.start((request) async {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(secretBody);
        await request.response.close();
      });
      addTearDown(server.close);
      final root = await Directory.systemTemp.createTemp('flva-status-');
      addTearDown(() => _deleteIfPresent(root));
      final descriptor = _descriptor(
        server,
        payloads,
        query: 'access_token=url-secret',
      );
      final error = await _expectFailure(
        ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        ).prepare(descriptor),
        ModelPreparationErrorCode.network,
      );
      expect(error.toString(), isNot(contains(secretBody)));
      expect(error.toString(), isNot(contains('url-secret')));
      expect(server.requestCount, 1);
      expect(await _stages(root), isEmpty);
    });

    test('rejects redirects and nonidentity response encoding', () async {
      for (final mode in <String>['redirect', 'encoding']) {
        final payloads = _payloads();
        final server = await PreparationHttpsServer.start((request) async {
          if (mode == 'redirect') {
            request.response.statusCode = HttpStatus.found;
            request.response.headers.set(
              HttpHeaders.locationHeader,
              '/elsewhere',
            );
          } else {
            request.response.headers.set(
              HttpHeaders.contentEncodingHeader,
              'gzip',
            );
            request.response.add(payloads.values.first);
          }
          await request.response.close();
        });
        final root = await Directory.systemTemp.createTemp('flva-$mode-');
        try {
          await _expectFailure(
            ModelPreparationManager(
              rootDirectory: root.path,
              httpClientFactory: server.createClient,
            ).prepare(_descriptor(server, payloads)),
            ModelPreparationErrorCode.network,
          );
          expect(server.requestCount, 1, reason: mode);
        } finally {
          await server.close();
          await _deleteIfPresent(root);
        }
      }
    });

    test(
      'rejects declared, truncated, oversized, and wrong-digest bodies',
      () async {
        for (final mode in <String>[
          'declared-length',
          'truncated',
          'oversized',
          'wrong-digest',
        ]) {
          final payloads = _payloads();
          final expected = payloads.values.first;
          final server = await PreparationHttpsServer.start((request) async {
            if (mode == 'declared-length') {
              request.response.contentLength = expected.length + 1;
              request.response.add(expected);
            } else if (mode == 'truncated') {
              request.response.add(expected.sublist(0, expected.length - 1));
            } else if (mode == 'oversized') {
              request.response.add(<int>[...expected, 0]);
            } else {
              request.response.add(
                Uint8List.fromList(expected.map((value) => value ^ 1).toList()),
              );
            }
            await request.response.close();
          });
          final root = await Directory.systemTemp.createTemp('flva-$mode-');
          try {
            await _expectFailure(
              ModelPreparationManager(
                rootDirectory: root.path,
                httpClientFactory: server.createClient,
              ).prepare(_descriptor(server, payloads)),
              ModelPreparationErrorCode.integrity,
            );
            expect(server.requestCount, 1, reason: mode);
            expect(await _stages(root), isEmpty, reason: mode);
          } finally {
            await server.close();
            await _deleteIfPresent(root);
          }
        }
      },
    );

    test('maps a broken response transfer to network', () async {
      final payloads = _payloads();
      final server = await PreparationHttpsServer.start((request) async {
        request.response.contentLength = payloads.values.first.length;
        await request.response.flush();
        final socket = await request.response.detachSocket();
        socket.destroy();
      });
      addTearDown(server.close);
      final root = await Directory.systemTemp.createTemp('flva-broken-');
      addTearDown(() => _deleteIfPresent(root));
      await _expectFailure(
        ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        ).prepare(_descriptor(server, payloads)),
        ModelPreparationErrorCode.network,
      );
      expect(server.requestCount, 1);
    });

    test(
      'maps a throwing client factory to network without leaking details',
      () async {
        final root = await Directory.systemTemp.createTemp('flva-client-');
        addTearDown(() => _deleteIfPresent(root));
        final operation =
            ModelPreparationManager(
              rootDirectory: root.path,
              httpClientFactory: () => throw StateError('factory-secret'),
            ).prepare(
              ModelPackDescriptor(
                id: 'speech',
                version: '1',
                files: _downloads(
                  Uri.parse('https://models.example.test/files/'),
                  _payloads(),
                ),
              ),
            );
        final error = await _expectFailure(
          operation,
          ModelPreparationErrorCode.network,
        );
        expect(error.toString(), isNot(contains('factory-secret')));
        expect(await _stages(root), isEmpty);
      },
    );
  });

  group('timeouts and cancellation', () {
    test('header and body inactivity have finite network timeouts', () async {
      for (final mode in <String>['headers', 'body']) {
        final payloads = _payloads();
        final server = await PreparationHttpsServer.start((request) async {
          if (mode == 'body') await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          request.response.add(payloads.values.first);
          await request.response.close();
        });
        final root = await Directory.systemTemp.createTemp(
          'flva-timeout-$mode-',
        );
        try {
          await _expectFailure(
            ModelPreparationManager(
              rootDirectory: root.path,
              httpClientFactory: server.createClient,
              timeout: const Duration(milliseconds: 500),
            ).prepare(_descriptor(server, payloads)),
            ModelPreparationErrorCode.network,
          );
          expect(server.requestCount, 1, reason: mode);
          expect(await _stages(root), isEmpty, reason: mode);
        } finally {
          await server.close();
          await _deleteIfPresent(root);
        }
      }
    });

    test('cancel interrupts delayed headers and is idempotent', () async {
      final payloads = _payloads();
      final received = Completer<void>();
      final release = Completer<void>();
      final server = await PreparationHttpsServer.start((request) async {
        if (!received.isCompleted) received.complete();
        await release.future;
        request.response.add(payloads.values.first);
        await request.response.close();
      });
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await server.close();
      });
      final root = await Directory.systemTemp.createTemp(
        'flva-cancel-headers-',
      );
      addTearDown(() => _deleteIfPresent(root));
      final operation = ModelPreparationManager(
        rootDirectory: root.path,
        httpClientFactory: server.createClient,
      ).prepare(_descriptor(server, payloads));
      await received.future.timeout(const Duration(seconds: 2));
      operation
        ..cancel()
        ..cancel();
      await _expectFailure(operation, ModelPreparationErrorCode.cancelled);
      expect(operation.progress.phase, ModelPreparationPhase.cancelled);
      final terminal = operation.progress;
      operation.cancel();
      expect(identical(operation.progress, terminal), isTrue);
      expect(await _stages(root), isEmpty);
      release.complete();
    });

    test('cancel interrupts a delayed response body', () async {
      final payloads = _payloads();
      final bodyStarted = Completer<void>();
      final release = Completer<void>();
      final server = await PreparationHttpsServer.start((request) async {
        request.response.add(payloads.values.first.sublist(0, 1));
        await request.response.flush();
        if (!bodyStarted.isCompleted) bodyStarted.complete();
        await release.future;
        request.response.add(payloads.values.first.sublist(1));
        await request.response.close();
      });
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await server.close();
      });
      final root = await Directory.systemTemp.createTemp('flva-cancel-body-');
      addTearDown(() => _deleteIfPresent(root));
      final operation = ModelPreparationManager(
        rootDirectory: root.path,
        httpClientFactory: server.createClient,
      ).prepare(_descriptor(server, payloads));
      await bodyStarted.future.timeout(const Duration(seconds: 2));
      operation.cancel();
      await _expectFailure(operation, ModelPreparationErrorCode.cancelled);
      expect(operation.progress.phase, ModelPreparationPhase.cancelled);
      expect(await _stages(root), isEmpty);
      release.complete();
    });

    test(
      'cancel before transfer prevents requests and cancel after ready is a no-op',
      () async {
        final payloads = _payloads();
        final server = await _servePayloads(payloads);
        addTearDown(server.close);
        final cancelledRoot = await Directory.systemTemp.createTemp(
          'flva-cancel-early-',
        );
        final readyRoot = await Directory.systemTemp.createTemp(
          'flva-cancel-ready-',
        );
        addTearDown(() => _deleteIfPresent(cancelledRoot));
        addTearDown(() => _deleteIfPresent(readyRoot));
        final descriptor = _descriptor(server, payloads);

        final cancelled = ModelPreparationManager(
          rootDirectory: cancelledRoot.path,
          httpClientFactory: server.createClient,
        ).prepare(descriptor);
        cancelled.cancel();
        await _expectFailure(cancelled, ModelPreparationErrorCode.cancelled);
        expect(server.requestCount, 0);
        expect(await _stages(cancelledRoot), isEmpty);

        final ready = ModelPreparationManager(
          rootDirectory: readyRoot.path,
          httpClientFactory: server.createClient,
        ).prepare(descriptor);
        final bundle = await ready.result;
        final snapshot = ready.progress;
        ready.cancel();
        expect(ready.progress.phase, ModelPreparationPhase.ready);
        expect(identical(ready.progress, snapshot), isTrue);
        expect(await File(bundle.manifestPath).exists(), isTrue);
      },
    );
  });

  group('cache and activation safety', () {
    test(
      'tampered manifest, file, and symlink cache fail integrity offline',
      () async {
        for (final mode in <String>['manifest', 'file', 'symlink']) {
          final payloads = _payloads();
          final server = await _servePayloads(payloads);
          final root = await Directory.systemTemp.createTemp(
            'flva-tamper-$mode-',
          );
          final outside = await Directory.systemTemp.createTemp(
            'flva-outside-',
          );
          try {
            final descriptor = _descriptor(server, payloads);
            final installed = await ModelPreparationManager(
              rootDirectory: root.path,
              httpClientFactory: server.createClient,
            ).prepare(descriptor).result;
            final firstPath = descriptor.files.first.entry.path;
            if (mode == 'manifest') {
              final manifest = File(installed.manifestPath);
              final document = jsonDecode(await manifest.readAsString()) as Map;
              final files = document['files'] as List;
              (files.first as Map)['source'] = 'rewritten-but-self-consistent';
              await manifest.writeAsString(jsonEncode(document));
            } else if (mode == 'file') {
              await File(
                '${installed.directory}/$firstPath',
              ).writeAsString('tampered');
            } else {
              final file = File('${installed.directory}/$firstPath');
              final bytes = await file.readAsBytes();
              final external = File('${outside.path}/same-bytes');
              await external.writeAsBytes(bytes);
              await file.delete();
              await Link(file.path).create(external.path);
            }
            final requests = server.requestCount;
            var clients = 0;
            await _expectFailure(
              ModelPreparationManager(
                rootDirectory: root.path,
                httpClientFactory: () {
                  clients += 1;
                  return server.createClient();
                },
              ).prepare(descriptor),
              ModelPreparationErrorCode.integrity,
            );
            expect(clients, 0, reason: mode);
            expect(server.requestCount, requests, reason: mode);
          } finally {
            await server.close();
            await _deleteIfPresent(root);
            await _deleteIfPresent(outside);
          }
        }
      },
    );

    test('does not replace an occupied invalid final destination', () async {
      final payloads = _payloads();
      final server = await _servePayloads(payloads);
      addTearDown(server.close);
      final root = await Directory.systemTemp.createTemp('flva-occupied-');
      addTearDown(() => _deleteIfPresent(root));
      final descriptor = _descriptor(server, payloads);
      final installed = await ModelPreparationManager(
        rootDirectory: root.path,
        httpClientFactory: server.createClient,
      ).prepare(descriptor).result;
      final active = Directory(installed.directory);
      final retained = await active.rename('${active.path}-retained');
      final occupant = File(active.path);
      await occupant.writeAsString('do-not-replace');
      final requests = server.requestCount;

      await _expectFailure(
        ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        ).prepare(descriptor),
        ModelPreparationErrorCode.integrity,
      );
      expect(await occupant.readAsString(), 'do-not-replace');
      expect(await retained.exists(), isTrue);
      expect(server.requestCount, requests);
    });

    test('rejects and preserves a symlink at the final destination', () async {
      final payloads = _payloads();
      final server = await _servePayloads(payloads);
      addTearDown(server.close);
      final root = await Directory.systemTemp.createTemp('flva-final-link-');
      addTearDown(() => _deleteIfPresent(root));
      final descriptor = _descriptor(server, payloads);
      final installed = await ModelPreparationManager(
        rootDirectory: root.path,
        httpClientFactory: server.createClient,
      ).prepare(descriptor).result;
      final active = Directory(installed.directory);
      final retained = await active.rename('${active.path}-retained');
      final link = await Link(active.path).create(retained.path);
      final requests = server.requestCount;

      await _expectFailure(
        ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        ).prepare(descriptor),
        ModelPreparationErrorCode.integrity,
      );
      expect(
        await FileSystemEntity.type(link.path, followLinks: false),
        FileSystemEntityType.link,
      );
      expect(await retained.exists(), isTrue);
      expect(server.requestCount, requests);
    });

    test(
      'retains old versions and abandoned stages after a failed update',
      () async {
        final payloads = _payloads();
        var corrupt = false;
        final server = await PreparationHttpsServer.start((request) async {
          final role = request.uri.pathSegments.last.replaceAll('.bin', '');
          final bytes = payloads[role]!;
          request.response.add(
            corrupt && role == _requiredRoles.first
                ? Uint8List.fromList(bytes.map((value) => value ^ 1).toList())
                : bytes,
          );
          await request.response.close();
        });
        addTearDown(server.close);
        final root = await Directory.systemTemp.createTemp('flva-versions-');
        addTearDown(() => _deleteIfPresent(root));
        final abandoned = await Directory(
          '${root.path}/.stage-abandoned',
        ).create();
        final first = await ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        ).prepare(_descriptor(server, payloads, version: '1')).result;
        corrupt = true;

        await _expectFailure(
          ModelPreparationManager(
            rootDirectory: root.path,
            httpClientFactory: server.createClient,
          ).prepare(_descriptor(server, payloads, version: '2')),
          ModelPreparationErrorCode.integrity,
        );
        expect(await File(first.manifestPath).exists(), isTrue);
        expect(await abandoned.exists(), isTrue);
        expect(await _stages(root), <String>['.stage-abandoned']);
      },
    );

    test(
      'exact URL and version metadata participate in the fingerprint',
      () async {
        final payloads = _payloads();
        final server = await _servePayloads(payloads);
        addTearDown(server.close);
        final root = await Directory.systemTemp.createTemp('flva-fingerprint-');
        addTearDown(() => _deleteIfPresent(root));
        final manager = ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        );
        final first = await manager
            .prepare(
              _descriptor(server, payloads, version: '1', query: 'mirror=1'),
            )
            .result;
        final second = await manager
            .prepare(
              _descriptor(server, payloads, version: '1', query: 'mirror=2'),
            )
            .result;
        final third = await manager
            .prepare(
              _descriptor(server, payloads, version: '2', query: 'mirror=2'),
            )
            .result;
        expect({
          first.directory,
          second.directory,
          third.directory,
        }, hasLength(3));
        expect(await File(first.manifestPath).exists(), isTrue);
        expect(await File(second.manifestPath).exists(), isTrue);
        expect(await File(third.manifestPath).exists(), isTrue);
      },
    );

    test('file-valued storage root produces typed storage failure', () async {
      final parent = await Directory.systemTemp.createTemp('flva-storage-');
      addTearDown(() => _deleteIfPresent(parent));
      final root = File('${parent.path}/models');
      await root.writeAsString('occupied');
      var clients = 0;
      await _expectFailure(
        ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: () {
            clients += 1;
            return HttpClient();
          },
        ).prepare(
          ModelPackDescriptor(
            id: 'speech',
            version: '1',
            files: _downloads(
              Uri.parse('https://models.example.test/files/'),
              _payloads(),
            ),
          ),
        ),
        ModelPreparationErrorCode.storage,
      );
      expect(await root.readAsString(), 'occupied');
      expect(clients, 0);
    });

    test('cached asset read permission failure remains typed storage', () async {
      if (Platform.isWindows) return;
      final payloads = _payloads();
      final server = await _servePayloads(payloads);
      addTearDown(server.close);
      final root = await Directory.systemTemp.createTemp(
        'flva-cache-permission-',
      );
      addTearDown(() => _deleteIfPresent(root));
      final descriptor = _descriptor(server, payloads);
      final installed = await ModelPreparationManager(
        rootDirectory: root.path,
        httpClientFactory: server.createClient,
      ).prepare(descriptor).result;
      final asset = File(
        '${installed.directory}${Platform.pathSeparator}${descriptor.files.first.entry.path}',
      );
      final denied = await Process.run('chmod', <String>['000', asset.path]);
      expect(denied.exitCode, 0);
      addTearDown(() async {
        await Process.run('chmod', <String>['600', asset.path]);
      });
      final requests = server.requestCount;
      var clients = 0;

      final error = await _expectFailure(
        ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: () {
            clients += 1;
            return server.createClient();
          },
        ).prepare(descriptor),
        ModelPreparationErrorCode.storage,
      );
      expect(error.toString(), isNot(contains(asset.path)));
      expect(clients, 0);
      expect(server.requestCount, requests);
    });
  });

  group('concurrent callers', () {
    test(
      'two managers converge and one cancelled caller cannot delete winner',
      () async {
        final payloads = _payloads(large: true);
        final firstRequests = Completer<void>();
        final release = Completer<void>();
        var firstRoleRequests = 0;
        final server = await PreparationHttpsServer.start((request) async {
          final role = request.uri.pathSegments.last.replaceAll('.bin', '');
          final bytes = payloads[role]!;
          if (role == _requiredRoles.first) {
            firstRoleRequests += 1;
            if (firstRoleRequests == 2 && !firstRequests.isCompleted) {
              firstRequests.complete();
            }
            request.response.add(bytes.sublist(0, 1));
            await request.response.flush();
            await release.future;
            request.response.add(bytes.sublist(1));
          } else {
            request.response.add(bytes);
          }
          await request.response.close();
        });
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          await server.close();
        });
        final root = await Directory.systemTemp.createTemp('flva-concurrent-');
        addTearDown(() => _deleteIfPresent(root));
        final descriptor = _descriptor(server, payloads);
        final cancelled = ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        ).prepare(descriptor);
        final survivor = ModelPreparationManager(
          rootDirectory: root.path,
          httpClientFactory: server.createClient,
        ).prepare(descriptor);
        await firstRequests.future.timeout(const Duration(seconds: 3));
        cancelled.cancel();
        release.complete();
        final cancelledResult = _expectFailure(
          cancelled,
          ModelPreparationErrorCode.cancelled,
        );
        final winner = await survivor.result;
        await cancelledResult;
        expect(
          await const FileModelStore().validate(winner),
          isA<ValidatedModelBundle>(),
        );
        expect(await _stages(root), isEmpty);
        expect(
          server.requestCount,
          greaterThanOrEqualTo(descriptor.files.length + 1),
        );
      },
    );

    test(
      'cross-isolate callers atomically converge on one valid directory',
      () async {
        final payloads = _payloads(large: true);
        final firstRequests = Completer<void>();
        final release = Completer<void>();
        var firstRoleRequests = 0;
        final server = await PreparationHttpsServer.start((request) async {
          final role = request.uri.pathSegments.last.replaceAll('.bin', '');
          final bytes = payloads[role]!;
          if (role == _requiredRoles.first) {
            firstRoleRequests += 1;
            if (firstRoleRequests == 2 && !firstRequests.isCompleted) {
              firstRequests.complete();
            }
            await release.future;
          }
          for (var offset = 0; offset < bytes.length; offset += 32768) {
            final end = (offset + 32768).clamp(0, bytes.length);
            request.response.add(bytes.sublist(offset, end));
          }
          await request.response.close();
        });
        addTearDown(() async {
          if (!release.isCompleted) release.complete();
          await server.close();
        });
        final root = await Directory.systemTemp.createTemp('flva-isolates-');
        addTearDown(() => _deleteIfPresent(root));
        final descriptor = _descriptor(server, payloads);
        final data = _isolateData(
          root: root,
          descriptor: descriptor,
          certificate: server.certificateBytes,
        );
        final first = _spawnPreparation(data);
        final second = _spawnPreparation(data);
        await firstRequests.future.timeout(const Duration(seconds: 4));
        release.complete();
        final results = await Future.wait(<Future<String>>[first, second]);
        expect(results.toSet(), hasLength(1));
        final commonDirectory = results.first;
        final bundle = LocalModelBundle(
          directory: commonDirectory,
          manifestPath:
              '$commonDirectory${Platform.pathSeparator}manifest.json',
        );
        expect(
          await const FileModelStore().validate(bundle),
          isA<ValidatedModelBundle>(),
        );
        expect(await _stages(root), isEmpty);
        expect(server.requestCount, descriptor.files.length * 2);
      },
    );
  });
}

Map<String, Uint8List> _payloads({bool large = false, bool llm = false}) {
  final result = <String, Uint8List>{};
  for (final role in _requiredRoles) {
    if (large && role == _requiredRoles.first) {
      result[role] = Uint8List.fromList(
        List<int>.generate(200000, (index) => index % 251),
      );
    } else {
      result[role] = Uint8List.fromList(utf8.encode('synthetic-$role'));
    }
  }
  if (llm) {
    result['llmModel'] = Uint8List.fromList(utf8.encode('synthetic-llm'));
  }
  result['license'] = Uint8List.fromList(utf8.encode('synthetic license'));
  return result;
}

List<ModelDownload> _downloads(Uri base, Map<String, Uint8List> payloads) =>
    payloads.entries
        .map(
          (item) => _download(
            role: item.key,
            path: item.key == 'license'
                ? 'licenses/LICENSE.txt'
                : 'models/${item.key}.bin',
            bytes: item.value,
            uri: base.resolve('${item.key}.bin'),
          ),
        )
        .toList();

ModelDownload _download({
  required String role,
  required String path,
  required Uint8List bytes,
  required Uri uri,
  String license = 'licenses/LICENSE.txt',
}) => ModelDownload(
  entry: ModelFileEntry(
    role: role,
    path: path,
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
    source: 'synthetic preparation fixture',
    license: license,
  ),
  uri: uri,
);

List<ModelDownload> _replace(
  List<ModelDownload> downloads,
  int index, {
  String? role,
  String? path,
  int? byteCount,
  String? sha256Value,
  String? sourceMetadata,
  String? license,
  Uri? uri,
}) {
  final result = downloads.toList();
  final current = result[index];
  result[index] = ModelDownload(
    entry: ModelFileEntry(
      role: role ?? current.entry.role,
      path: path ?? current.entry.path,
      bytes: byteCount ?? current.entry.bytes,
      sha256: sha256Value ?? current.entry.sha256,
      source: sourceMetadata ?? current.entry.source,
      license: license ?? current.entry.license,
    ),
    uri: uri ?? current.uri,
  );
  return result;
}

ModelPackDescriptor _descriptor(
  PreparationHttpsServer server,
  Map<String, Uint8List> payloads, {
  String version = '1',
  String? query,
}) {
  final downloads = payloads.entries.map((item) {
    var uri = server.uri('/${item.key}.bin');
    if (query != null) uri = uri.replace(query: query);
    return _download(
      role: item.key,
      path: item.key == 'license'
          ? 'licenses/LICENSE.txt'
          : 'models/${item.key}.bin',
      bytes: item.value,
      uri: uri,
    );
  }).toList();
  return ModelPackDescriptor(id: 'speech', version: version, files: downloads);
}

Future<PreparationHttpsServer> _servePayloads(
  Map<String, Uint8List> payloads, {
  int responseChunkBytes = 32768,
}) => PreparationHttpsServer.start((request) async {
  final role = request.uri.pathSegments.last.replaceAll('.bin', '');
  final bytes = payloads[role];
  if (bytes == null) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }
  request.response.contentLength = bytes.length;
  for (var offset = 0; offset < bytes.length; offset += responseChunkBytes) {
    final end = (offset + responseChunkBytes).clamp(0, bytes.length);
    request.response.add(bytes.sublist(offset, end));
  }
  await request.response.close();
});

Future<ModelPreparationFailure> _expectFailure(
  ModelPreparation operation,
  ModelPreparationErrorCode code, {
  String? reason,
}) async {
  try {
    await operation.result;
    fail('Expected $code${reason == null ? '' : ' for $reason'}.');
  } on ModelPreparationFailure catch (error) {
    expect(error.code, code, reason: reason);
    final expectedPhase = code == ModelPreparationErrorCode.cancelled
        ? ModelPreparationPhase.cancelled
        : ModelPreparationPhase.failed;
    expect(operation.progress.phase, expectedPhase, reason: reason);
    expect(operation.progress.failure, same(error), reason: reason);
    return error;
  }
}

Future<List<String>> _stages(Directory root) async {
  if (!await root.exists()) return <String>[];
  final names = <String>[];
  await for (final entity in root.list()) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('.stage-')) names.add(name);
  }
  names.sort();
  return names;
}

Future<void> _deleteIfPresent(FileSystemEntity entity) async {
  if (await entity.exists()) await entity.delete(recursive: true);
}

Map<String, Object?> _isolateData({
  required Directory root,
  required ModelPackDescriptor descriptor,
  required Uint8List certificate,
}) => <String, Object?>{
  'root': root.path,
  'certificate': certificate,
  'id': descriptor.id,
  'version': descriptor.version,
  'files': descriptor.files
      .map(
        (download) => <String, Object?>{
          'role': download.entry.role,
          'path': download.entry.path,
          'bytes': download.entry.bytes,
          'sha256': download.entry.sha256,
          'source': download.entry.source,
          'license': download.entry.license,
          'uri': download.uri.toString(),
        },
      )
      .toList(),
};

Future<String> _prepareInIsolate(Map<String, Object?> data) async {
  final rawFiles = data['files']! as List<Object?>;
  final files = rawFiles.map((raw) {
    final item = raw! as Map<Object?, Object?>;
    return ModelDownload(
      entry: ModelFileEntry(
        role: item['role']! as String,
        path: item['path']! as String,
        bytes: item['bytes']! as int,
        sha256: item['sha256']! as String,
        source: item['source']! as String,
        license: item['license']! as String,
      ),
      uri: Uri.parse(item['uri']! as String),
    );
  }).toList();
  final certificate = data['certificate']! as Uint8List;
  final manager = ModelPreparationManager(
    rootDirectory: data['root']! as String,
    httpClientFactory: () {
      final context = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificatesBytes(certificate);
      return HttpClient(context: context);
    },
  );
  final bundle = await manager
      .prepare(
        ModelPackDescriptor(
          id: data['id']! as String,
          version: data['version']! as String,
          files: files,
        ),
      )
      .result;
  return bundle.directory;
}

Future<String> _spawnPreparation(Map<String, Object?> data) async {
  final responses = ReceivePort();
  await Isolate.spawn(_isolateEntry, <Object?>[responses.sendPort, data]);
  final response = await responses.first as List<Object?>;
  responses.close();
  if (response.first == 'ok') return response[1]! as String;
  throw StateError(response[1]! as String);
}

Future<void> _isolateEntry(List<Object?> message) async {
  final output = message.first! as SendPort;
  final rawData = message[1]! as Map<Object?, Object?>;
  try {
    final result = await _prepareInIsolate(
      rawData.map((key, value) => MapEntry('$key', value)),
    );
    output.send(<Object?>['ok', result]);
  } on Object catch (error) {
    output.send(<Object?>['error', '$error']);
  }
}
