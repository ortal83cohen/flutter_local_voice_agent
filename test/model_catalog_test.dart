import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_voice_agent/src/model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exported catalog exactly matches reviewed source inventory and notices',
    () {
      final inventory = jsonDecode(
        File('tool/model_catalog_inventory.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final packs = (inventory['packs'] as List).cast<Map<String, dynamic>>();
      expect(VoiceModelCatalog.entries, hasLength(packs.length));
      for (var i = 0; i < packs.length; i++) {
        final pack = packs[i];
        final option = VoiceModelCatalog.entries[i];
        expect(option.id, pack['id']);
        expect(option.downloadBytes, pack['totalBytes']);
        final base = (packs.first['files'] as List)
            .cast<Map<String, dynamic>>();
        final replacements = (pack['replacements'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final expected = base.map((file) {
          final replacement = replacements.where(
            (r) => r['role'] == file['entry']['role'],
          );
          if (replacement.isEmpty) return file;
          final r = replacement.single;
          return {
            'entry': {...r}..remove('uri'),
            'uri': r['uri'],
          };
        }).toList();
        expect(option.descriptor.files, hasLength(expected.length));
        for (var f = 0; f < expected.length; f++) {
          final actual = option.descriptor.files[f];
          expect(actual.uri.toString(), expected[f]['uri']);
          final e = actual.entry;
          expect({
            'role': e.role,
            'path': e.path,
            'bytes': e.bytes,
            'sha256': e.sha256,
            'source': e.source,
            'license': e.license,
          }, expected[f]['entry']);
          expect(
            option.descriptor.files.any(
              (d) => d.entry.role == 'license' && d.entry.path == e.license,
            ),
            isTrue,
          );
        }
        expect(
          option.allowedRedirectOrigins.map((u) => u.toString()).toList(),
          inventory['recommendedTransport']['allowedRedirectOrigins'],
        );
      }
    },
  );

  test('catalog choices and trusted metadata cannot be mutated', () {
    expect(() => VoiceModelCatalog.entries.clear(), throwsUnsupportedError);
    for (final option in VoiceModelCatalog.entries) {
      expect(
        () => option.allowedRedirectOrigins.clear(),
        throwsUnsupportedError,
      );
      expect(() => option.descriptor.files.clear(), throwsUnsupportedError);
      expect(option.language, 'English (US)');
      expect(
        option.descriptor.files.any((f) => f.entry.role == 'llmModel'),
        isFalse,
      );
    }
  });
}
