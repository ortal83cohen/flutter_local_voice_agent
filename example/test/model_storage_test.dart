import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_local_voice_agent_example/model_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'selection is persisted and deletion is confined to selected id',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'voice-example-storage-',
      );
      addTearDown(() => root.delete(recursive: true));
      const channel = MethodChannel('test/storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getModelRoot') return root.path;
            if (call.method == 'availableBytes') return 987654321;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final storage = ExampleModelStorage(channel: channel);
      final selected = VoiceModelCatalog.entries.first;
      final other = VoiceModelCatalog.entries.last;
      final selectedDirectory = Directory(
        await storage.optionDirectory(selected),
      );
      final otherDirectory = Directory(await storage.optionDirectory(other));
      await selectedDirectory.create(recursive: true);
      await otherDirectory.create(recursive: true);

      await storage.writeSelection(selected);
      final restored = await storage.readSelection();
      expect(restored, isNotNull);
      expect(restored!.catalogId, selected.id);
      expect(restored.speakerId, 0);
      expect(await storage.availableBytes(), 987654321);

      await storage.deleteOption(selected);
      expect(await selectedDirectory.exists(), isFalse);
      expect(await otherDirectory.exists(), isTrue);
      expect(await storage.readSelection(), isNull);
    },
  );

  test('selection JSON round-trips catalogId and speakerId', () async {
    final storage = await _storageOnTempRoot('voice-example-roundtrip-');
    final option = VoiceModelCatalog.entries.first;

    await storage.writeSelection(option, speakerId: 0);
    final file = File(
      '${await storage.rootDirectory()}${Platform.pathSeparator}selection.json',
    );
    final document = jsonDecode(await file.readAsString());
    expect(document, isA<Map<dynamic, dynamic>>());
    expect(document['catalogId'], option.id);
    expect(document['speakerId'], 0);
    expect(document['speakerId'], isA<int>());

    final restored = await storage.readSelection();
    expect(restored, isNotNull);
    expect(restored!.catalogId, option.id);
    expect(restored.speakerId, 0);
  });

  test('old catalog-id-only JSON restores speakerId 0', () async {
    final root = await Directory.systemTemp.createTemp(
      'voice-example-legacy-selection-',
    );
    addTearDown(() => root.delete(recursive: true));
    final option = VoiceModelCatalog.entries.first;
    await File('${root.path}${Platform.pathSeparator}selection.json')
        .writeAsString(jsonEncode(<String, String>{'catalogId': option.id}));
    final storage = await _storageOnRoot(
      root,
      channelName: 'test/storage-legacy',
    );

    final restored = await storage.readSelection();
    expect(restored, isNotNull);
    expect(restored!.catalogId, option.id);
    expect(restored.speakerId, 0);
  });

  test('damaged speaker field reports an actionable storage error', () async {
    for (final speakerId in <Object>['3', true, <int>[]]) {
      final root = await Directory.systemTemp.createTemp(
        'voice-example-damaged-speaker-',
      );
      addTearDown(() => root.delete(recursive: true));
      await File('${root.path}${Platform.pathSeparator}selection.json')
          .writeAsString(
            jsonEncode(<String, Object>{
              'catalogId': VoiceModelCatalog.entries.first.id,
              'speakerId': speakerId,
            }),
          );
      final storage = await _storageOnRoot(
        root,
        channelName: 'test/storage-damaged-$speakerId',
      );

      await expectLater(
        storage.readSelection(),
        throwsA(
          isA<ExampleStorageException>().having(
            (error) => error.message,
            'message',
            contains('damaged'),
          ),
        ),
      );
    }
  });

  test('negative speakerId reports an actionable storage error', () async {
    final root = await Directory.systemTemp.createTemp(
      'voice-example-negative-speaker-',
    );
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}${Platform.pathSeparator}selection.json')
        .writeAsString(
          jsonEncode(<String, Object>{
            'catalogId': VoiceModelCatalog.entries.first.id,
            'speakerId': -1,
          }),
        );
    final storage = await _storageOnRoot(
      root,
      channelName: 'test/storage-negative-speaker',
    );

    await expectLater(
      storage.readSelection(),
      throwsA(
        isA<ExampleStorageException>().having(
          (error) => error.message,
          'message',
          contains('damaged'),
        ),
      ),
    );
  });

  test('VCTK speaker 3 persists and restores', () async {
    final storage = await _storageOnTempRoot('voice-example-vctk-speaker-');
    final vctk = VoiceModelCatalog.entries.last;

    await storage.writeSelection(vctk, speakerId: 3);
    final restored = await storage.readSelection();
    expect(restored, isNotNull);
    expect(restored!.catalogId, vctk.id);
    expect(restored.speakerId, 3);
  });

  test('VCTK out-of-range speaker id is retained', () async {
    final storage = await _storageOnTempRoot('voice-example-vctk-oor-');
    final vctk = VoiceModelCatalog.entries.last;

    await storage.writeSelection(vctk, speakerId: 109);
    final restored = await storage.readSelection();
    expect(restored, isNotNull);
    expect(restored!.catalogId, vctk.id);
    expect(restored.speakerId, 109);
  });

  test('damaged selection reports an actionable storage error', () async {
    final root = await Directory.systemTemp.createTemp(
      'voice-example-storage-',
    );
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}${Platform.pathSeparator}selection.json')
        .writeAsString('{broken');
    const channel = MethodChannel('test/storage-corrupt');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => root.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final storage = ExampleModelStorage(channel: channel);
    await expectLater(
      storage.readSelection(),
      throwsA(
        isA<ExampleStorageException>().having(
          (error) => error.message,
          'message',
          contains('damaged'),
        ),
      ),
    );
  });
}

Future<ExampleModelStorage> _storageOnTempRoot(String prefix) async {
  final root = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() => root.delete(recursive: true));
  return _storageOnRoot(root, channelName: 'test/storage-$prefix');
}

Future<ExampleModelStorage> _storageOnRoot(
  Directory root, {
  required String channelName,
}) async {
  final channel = MethodChannel(channelName);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getModelRoot') return root.path;
        if (call.method == 'availableBytes') return 987654321;
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  return ExampleModelStorage(channel: channel);
}
