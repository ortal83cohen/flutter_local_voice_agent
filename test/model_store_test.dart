import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates real local files with roles, hashes and licenses', () async {
    final fixture = await _fixture();
    addTearDown(() => fixture.delete(recursive: true));
    final checked = await const FileModelStore().validate(_bundle(fixture));
    expect(checked.files, hasLength(9));
  });

  test('rejects traversal before native setup', () async {
    final fixture = await _fixture(pathOverride: '../outside');
    addTearDown(() => fixture.delete(recursive: true));
    await expectLater(
      const FileModelStore().validate(_bundle(fixture)),
      throwsA(
        isA<AgentFailure>().having(
          (error) => error.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });

  test('rejects a corrupt file hash', () async {
    final fixture = await _fixture();
    addTearDown(() => fixture.delete(recursive: true));
    await File('${fixture.path}/vad').writeAsString('corrupt');
    await expectLater(
      const FileModelStore().validate(_bundle(fixture)),
      throwsA(isA<AgentFailure>()),
    );
  });

  test('rejects missing manifest', () async {
    final fixture = await _fixture();
    addTearDown(() => fixture.delete(recursive: true));
    await File('${fixture.path}/manifest.json').delete();
    await expectLater(
      const FileModelStore().validate(_bundle(fixture)),
      throwsA(
        isA<AgentFailure>().having(
          (e) => e.code,
          'code',
          AgentErrorCode.missingAsset,
        ),
      ),
    );
  });

  test('rejects missing required model file', () async {
    final fixture = await _fixture();
    addTearDown(() => fixture.delete(recursive: true));
    await File('${fixture.path}/vad').delete();
    await expectLater(
      const FileModelStore().validate(_bundle(fixture)),
      throwsA(
        isA<AgentFailure>().having(
          (e) => e.code,
          'code',
          AgentErrorCode.missingAsset,
        ),
      ),
    );
  });

  test('rejects wrong profile and runtime', () async {
    final fixture = await _fixture();
    addTearDown(() => fixture.delete(recursive: true));
    final map =
        jsonDecode(await File('${fixture.path}/manifest.json').readAsString())
            as Map<String, Object?>;
    map['profile'] = 'wrong';
    await File('${fixture.path}/manifest.json').writeAsString(jsonEncode(map));
    await expectLater(
      const FileModelStore().validate(_bundle(fixture)),
      throwsA(
        isA<AgentFailure>().having(
          (e) => e.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });

  test('rejects a symlink escape', () async {
    final fixture = await _fixture();
    addTearDown(() => fixture.delete(recursive: true));
    final outside = await Directory.systemTemp.createTemp('flva-outside-');
    addTearDown(() => outside.delete(recursive: true));
    await File('${outside.path}/vad').writeAsString('vad');
    await File('${fixture.path}/vad').delete();
    await Link('${fixture.path}/vad').create('${outside.path}/vad');
    await expectLater(
      const FileModelStore().validate(_bundle(fixture)),
      throwsA(
        isA<AgentFailure>().having(
          (e) => e.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });
}

LocalModelBundle _bundle(Directory root) => LocalModelBundle(
  directory: root.path,
  manifestPath: '${root.path}/manifest.json',
);

Future<Directory> _fixture({String? pathOverride}) async {
  final root = await Directory.systemTemp.createTemp('flva-model-');
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
  final entries = <Map<String, Object?>>[];
  for (final role in roles) {
    final value = utf8.encode(role);
    await File('${root.path}/$role').writeAsBytes(value);
    entries.add(<String, Object?>{
      'role': role,
      'path': role == 'vad' && pathOverride != null ? pathOverride : role,
      'bytes': value.length,
      'sha256': sha256.convert(value).toString(),
      'source': 'fixture',
      'license': 'LICENSE',
    });
  }
  const license = 'fixture license';
  await File('${root.path}/LICENSE').writeAsString(license);
  entries.add(<String, Object?>{
    'role': 'license',
    'path': 'LICENSE',
    'bytes': utf8.encode(license).length,
    'sha256': sha256.convert(utf8.encode(license)).toString(),
    'source': 'fixture',
    'license': 'LICENSE',
  });
  await File('${root.path}/manifest.json').writeAsString(
    jsonEncode(<String, Object?>{
      'schema': 1,
      'profile': 'en-US-sherpa-vits',
      'runtime': '1.12.14',
      'inputRate': 16000,
      'files': entries,
    }),
  );
  return root;
}
