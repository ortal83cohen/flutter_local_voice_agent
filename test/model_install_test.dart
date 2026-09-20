import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'installs a validated bundle atomically with unchanged hashes',
    () async {
      final source = await _fixture();
      final target = await Directory.systemTemp.createTemp(
        'flva-install-target-',
      );
      addTearDown(() => source.delete(recursive: true));
      addTearDown(() => target.delete(recursive: true));

      final installed = await const FileModelStore().install(
        source: _bundle(source),
        targetRoot: target.path,
      );

      expect(await File(installed.manifestPath).exists(), isTrue);
      final sourceHash = await File('${source.path}/vad')
          .openRead()
          .transform(sha256)
          .single;
      final installedHash = await File('${installed.directory}/vad')
          .openRead()
          .transform(sha256)
          .single;
      expect(installedHash.toString(), sourceHash.toString());
      expect(
        await const FileModelStore().validate(installed),
        isA<ValidatedModelBundle>(),
      );
      expect(await _namedDirectories(target), hasLength(1));
    },
  );

  test(
    'does not create an active or stage directory for a corrupt source',
    () async {
      final source = await _fixture();
      final target = await Directory.systemTemp.createTemp(
        'flva-install-target-',
      );
      addTearDown(() => source.delete(recursive: true));
      addTearDown(() => target.delete(recursive: true));
      await File('${source.path}/vad').writeAsString('corrupt');

      await expectLater(
        const FileModelStore().install(
          source: _bundle(source),
          targetRoot: target.path,
        ),
        throwsA(
          isA<AgentFailure>().having(
            (error) => error.code,
            'code',
            AgentErrorCode.invalidAsset,
          ),
        ),
      );
      expect(await _namedDirectories(target), isEmpty);
    },
  );

  test('rejects a manifest with a missing required role', () async {
    final source = await _fixture();
    addTearDown(() => source.delete(recursive: true));
    await _mutateManifest(source, (document) {
      final files = document['files']! as List<Object?>;
      final vad = files.cast<Map<String, Object?>>().firstWhere(
        (entry) => entry['role'] == 'vad',
      );
      vad['role'] = 'other';
    });
    await expectLater(
      const FileModelStore().validate(_bundle(source)),
      throwsA(
        isA<AgentFailure>().having(
          (error) => error.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });

  test('accepts multiple listed license records', () async {
    final source = await _fixture(extraLicense: true);
    addTearDown(() => source.delete(recursive: true));
    final checked = await const FileModelStore().validate(_bundle(source));
    expect(
      checked.files.where((entry) => entry.role == 'license'),
      hasLength(2),
    );
  });

  test('rejects over-limit manifest before inspecting listed paths', () async {
    final source = await _fixture();
    addTearDown(() => source.delete(recursive: true));
    final entries = List<Map<String, Object?>>.generate(
      129,
      (index) => <String, Object?>{
        'role': 'extra$index',
        'path': '../not-read-$index',
        'bytes': 0,
        'sha256': '0' * 64,
        'source': 'fixture',
        'license': 'LICENSE',
      },
    );
    await File('${source.path}/manifest.json').writeAsString(
      jsonEncode(<String, Object?>{
        'schema': 1,
        'profile': 'en-US-sherpa-vits',
        'runtime': '1.12.14',
        'inputRate': 16000,
        'files': entries,
      }),
    );
    await expectLater(
      const FileModelStore().validate(_bundle(source)),
      throwsA(
        isA<AgentFailure>().having(
          (error) => error.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });

  test('repeated installs retain earlier active bundles', () async {
    final source = await _fixture();
    final target = await Directory.systemTemp.createTemp(
      'flva-install-target-',
    );
    addTearDown(() => source.delete(recursive: true));
    addTearDown(() => target.delete(recursive: true));
    final store = const FileModelStore();
    final first = await store.install(
      source: _bundle(source),
      targetRoot: target.path,
    );
    final second = await store.install(
      source: _bundle(source),
      targetRoot: target.path,
    );
    expect(first.directory, isNot(second.directory));
    expect(await File('${first.directory}/vad').exists(), isTrue);
    expect(await File('${second.directory}/vad').exists(), isTrue);
    expect(await _namedDirectories(target), hasLength(2));
  });
}

LocalModelBundle _bundle(Directory root) => LocalModelBundle(
  directory: root.path,
  manifestPath: '${root.path}/manifest.json',
);

Future<List<Directory>> _namedDirectories(Directory root) => root
    .list()
    .where(
      (entity) =>
          entity is Directory &&
          !entity.path.split(Platform.pathSeparator).last.startsWith('.'),
    )
    .cast<Directory>()
    .toList();

Future<void> _mutateManifest(
  Directory root,
  void Function(Map<String, Object?> document) mutate,
) async {
  final document = (jsonDecode(
    await File('${root.path}/manifest.json').readAsString(),
  ) as Map).map((key, value) => MapEntry('$key', value));
  final files = (document['files']! as List)
      .map((item) => Map<String, Object?>.from(item as Map))
      .toList();
  document['files'] = files;
  mutate(document);
  await File('${root.path}/manifest.json').writeAsString(jsonEncode(document));
}

Future<Directory> _fixture({bool extraLicense = false}) async {
  final root = await Directory.systemTemp.createTemp('flva-install-source-');
  const roles = <String>[
    'vad',
    'encoder',
    'decoder',
    'joiner',
    'asrTokens',
    'ttsModel',
    'ttsTokens',
    'ttsLexicon',
  ];
  final files = <Map<String, Object?>>[];
  for (final role in roles) {
    final bytes = utf8.encode(role);
    await File('${root.path}/$role').writeAsBytes(bytes);
    files.add(_entry(role: role, path: role, bytes: bytes));
  }
  const license = 'fixture license';
  final licenseBytes = utf8.encode(license);
  await File('${root.path}/LICENSE').writeAsBytes(licenseBytes);
  files.add(_entry(role: 'license', path: 'LICENSE', bytes: licenseBytes));
  if (extraLicense) {
    const second = 'second fixture license';
    final secondBytes = utf8.encode(second);
    await File('${root.path}/NOTICE').writeAsBytes(secondBytes);
    files.add(
      _entry(
        role: 'license',
        path: 'NOTICE',
        bytes: secondBytes,
        license: 'NOTICE',
      ),
    );
  }
  await File('${root.path}/manifest.json').writeAsString(
    jsonEncode(<String, Object?>{
      'schema': 1,
      'profile': 'en-US-sherpa-vits',
      'runtime': '1.12.14',
      'inputRate': 16000,
      'files': files,
    }),
  );
  return root;
}

Map<String, Object?> _entry({
  required String role,
  required String path,
  required List<int> bytes,
  String license = 'LICENSE',
}) => <String, Object?>{
  'role': role,
  'path': path,
  'bytes': bytes.length,
  'sha256': sha256.convert(bytes).toString(),
  'source': 'fixture',
  'license': license,
};
