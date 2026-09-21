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
        expect(option.speakerCount, pack['speakerCount']);
        expect(option.downloadBytes, pack['totalBytes']);
        final base = (packs.first['files'] as List)
            .cast<Map<String, dynamic>>();
        final replacements = (pack['replacements'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        final expected = resolveInheritedPackFiles(base, replacements);
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

  test(
    'catalog exposes three English options with distinct speaker counts',
    () {
      expect(VoiceModelCatalog.entries, hasLength(3));
      final ids = VoiceModelCatalog.entries.map((option) => option.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, [
        'en-us-ljs-zipformer-int8',
        'en-us-ljs-zipformer-standard',
        'en-us-vctk-zipformer-int8',
      ]);

      final byId = {
        for (final option in VoiceModelCatalog.entries) option.id: option,
      };
      expect(byId['en-us-ljs-zipformer-int8']!.title, 'English compact (INT8)');
      expect(
        byId['en-us-ljs-zipformer-standard']!.title,
        'English standard (full precision)',
      );
      expect(
        byId['en-us-vctk-zipformer-int8']!.title,
        'English compact VCTK (INT8)',
      );
      expect(byId['en-us-ljs-zipformer-int8']!.speakerCount, 1);
      expect(byId['en-us-ljs-zipformer-standard']!.speakerCount, 1);
      expect(byId['en-us-vctk-zipformer-int8']!.speakerCount, 109);

      for (final option in VoiceModelCatalog.entries) {
        expect(option.language, 'English (US)');
        expect(option.id.toLowerCase().contains('piper'), isFalse);
        expect(option.title.toLowerCase().contains('piper'), isFalse);
        expect(option.description.toLowerCase().contains('piper'), isFalse);
        expect(option.language.toLowerCase().contains('hebrew'), isFalse);
        expect(option.title.toLowerCase().contains('hebrew'), isFalse);
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

/// Resolves inherited inventory files.
///
/// Unique synthesis roles match by role. License replacements match by
/// installed path so Silero, Zipformer and Apache notices stay in place.
List<Map<String, dynamic>> resolveInheritedPackFiles(
  List<Map<String, dynamic>> base,
  List<Map<String, dynamic>> replacements,
) {
  final supersededLicensePaths = <String>{};
  for (final replacement in replacements) {
    final role = replacement['role'] as String;
    if (role == 'license') {
      continue;
    }
    for (final file in base) {
      if (file['entry']['role'] != role) {
        continue;
      }
      final previousLicense = file['entry']['license'] as String;
      final nextLicense = replacement['license'] as String?;
      if (nextLicense != null && nextLicense != previousLicense) {
        supersededLicensePaths.add(previousLicense);
      }
    }
  }

  return base.map((file) {
    final fileRole = file['entry']['role'] as String;
    final filePath = file['entry']['path'] as String;
    final Iterable<Map<String, dynamic>> matches;
    if (fileRole == 'license') {
      matches = replacements.where((replacement) {
        if (replacement['role'] != 'license') {
          return false;
        }
        final replacementPath = replacement['path'] as String;
        return replacementPath == filePath ||
            supersededLicensePaths.contains(filePath);
      });
    } else {
      matches = replacements.where(
        (replacement) => replacement['role'] == fileRole,
      );
    }
    if (matches.isEmpty) {
      return file;
    }
    final replacement = matches.single;
    return {
      'entry': {...replacement}..remove('uri'),
      'uri': replacement['uri'],
    };
  }).toList();
}
