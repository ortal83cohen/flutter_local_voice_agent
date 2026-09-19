import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects a correctly hashed unsupported manifest role', () async {
    final root = await Directory.systemTemp.createTemp('flva-review-role-');
    addTearDown(() => root.delete(recursive: true));
    const roles = <String>[
      'vad',
      'encoder',
      'decoder',
      'joiner',
      'asrTokens',
      'ttsModel',
      'ttsTokens',
      'ttsLexicon',
      'unexpectedRole',
      'license',
    ];
    final files = <Map<String, Object?>>[];
    for (final role in roles) {
      final path = role == 'license' ? 'LICENSE' : role;
      final bytes = utf8.encode(role);
      await File('${root.path}/$path').writeAsBytes(bytes);
      files.add(<String, Object?>{
        'role': role,
        'path': path,
        'bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'source': 'fixture',
        'license': 'LICENSE',
      });
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
    await expectLater(
      const FileModelStore().validate(
        LocalModelBundle(
          directory: root.path,
          manifestPath: '${root.path}/manifest.json',
        ),
      ),
      throwsA(
        isA<AgentFailure>().having(
          (error) => error.code,
          'code',
          AgentErrorCode.invalidAsset,
        ),
      ),
    );
  });
}
