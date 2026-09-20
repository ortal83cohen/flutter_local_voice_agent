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
      expect(await storage.readSelection(), selected.id);
      expect(await storage.availableBytes(), 987654321);

      await storage.deleteOption(selected);
      expect(await selectedDirectory.exists(), isFalse);
      expect(await otherDirectory.exists(), isTrue);
      expect(await storage.readSelection(), isNull);
    },
  );

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
