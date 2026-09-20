import 'package:flutter/material.dart';
import 'package:flutter_local_voice_agent/flutter_local_voice_agent.dart';
import 'package:flutter_local_voice_agent_example/main.dart';
import 'package:flutter_local_voice_agent_example/model_storage.dart';
import 'package:flutter_local_voice_agent_example/voice_screen_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog UI has no path input and Start waits for native setup', (
    tester,
  ) async {
    final controller = VoiceScreenController(
      storage: _EmptyStorage(),
      preparationFactory: (_, _, _) => throw StateError('not expected'),
      sessionFactory: (_) => throw StateError('not expected'),
    );
    await tester.pumpWidget(
      MaterialApp(home: VoiceScreen(controller: controller)),
    );
    await tester.pump();

    expect(
      find.byType(DropdownButtonFormField<VoiceModelOption>),
      findsOneWidget,
    );
    expect(find.text('English voice model'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('fixed demo rules'), findsOneWidget);
    expect(find.text('Files, sources, and licenses'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    final start = tester.widget<FilledButton>(
      find.byKey(const Key('start-button')),
    );
    expect(start.onPressed, isNull);

    await controller.close();
  });
}

final class _EmptyStorage extends ExampleModelStorage {
  @override
  Future<String?> readSelection() async => null;
}
