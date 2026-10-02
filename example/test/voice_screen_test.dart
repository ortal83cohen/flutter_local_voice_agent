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
      sessionFactory: (_, _) => throw StateError('not expected'),
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
    expect(find.text('Speaker'), findsNothing);
    expect(find.textContaining('Three English options'), findsOneWidget);
    expect(find.textContaining('VCTK is a speaker choice'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.textContaining('fixed demo rules'), findsOneWidget);
    expect(find.text('Files, sources, and licenses'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.byKey(const Key('start-button')),
    );
    expect(start.onPressed, isNull);

    // AC-011: the other two controls are still present beside Start.
    expect(find.byKey(const Key('interrupt-button')), findsOneWidget);
    expect(find.byKey(const Key('stop-button')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('interrupt-button'))),
      isA<OutlinedButton>(),
    );
    expect(
      tester.widget(find.byKey(const Key('stop-button'))),
      isA<OutlinedButton>(),
    );

    await controller.close();
  });

  testWidgets('static copy and the live-region status stay in place', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final controller = _newController();
    await tester.pumpWidget(
      MaterialApp(home: VoiceScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.textContaining('English voice model'), findsWidgets);
    expect(find.text('Files, sources, and licenses'), findsOneWidget);
    expect(find.textContaining('Three English options'), findsOneWidget);
    expect(find.textContaining('VCTK is a speaker choice'), findsOneWidget);
    expect(find.textContaining('fixed demo rules'), findsOneWidget);
    expect(
      find.textContaining('Listening pauses while a reply plays'),
      findsOneWidget,
    );

    final status = find.byKey(const Key('status'));
    expect(status, findsOneWidget);
    expect(tester.widget(status), isA<Text>());
    final liveRegions = tester
        .widgetList<Semantics>(
          find.ancestor(of: status, matching: find.byType(Semantics)),
        )
        .where((semantics) => semantics.properties.liveRegion == true);
    expect(liveRegions, isNotEmpty);

    await controller.close();
  });

  testWidgets('indicator shows an icon, a word and a matching semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _useTallSurface(tester);
    final controller = _newController()
      ..displayedActivity = TurnActivity.speaking;
    await tester.pumpWidget(
      MaterialApp(home: VoiceScreen(controller: controller)),
    );
    await tester.pump();

    final indicator = find.byKey(const Key('activity-indicator'));
    expect(indicator, findsOneWidget);
    expect(
      find.descendant(of: indicator, matching: find.byType(Icon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: indicator, matching: find.text('Speaking')),
      findsOneWidget,
    );
    expect(tester.getSemantics(indicator).label, contains('Speaking'));
    // The enum name is never rendered.
    expect(find.text('speaking'), findsNothing);
    expect(find.textContaining('TurnActivity'), findsNothing);

    // The indicator is the fourth child of the same Wrap as the three buttons.
    final wrap = tester.widget<Wrap>(
      find.ancestor(of: indicator, matching: find.byType(Wrap)).first,
    );
    expect(wrap.children, hasLength(4));
    expect((wrap.children[3].key), const Key('activity-indicator'));
    expect(
      find.descendant(
        of: find.byWidget(wrap),
        matching: find.byKey(const Key('start-button')),
      ),
      findsOneWidget,
    );

    await controller.close();
    semantics.dispose();
  });

  testWidgets('indicator shows Paused when paused and Idle otherwise', (
    tester,
  ) async {
    await _useTallSurface(tester);

    final idle = _newController();
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceScreen(key: UniqueKey(), controller: idle),
      ),
    );
    await tester.pump();
    final indicator = find.byKey(const Key('activity-indicator'));
    expect(
      find.descendant(of: indicator, matching: find.text('Idle')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: indicator, matching: find.text('Paused')),
      findsNothing,
    );
    await idle.close();

    final paused = _newController()
      ..displayedActivity = TurnActivity.idle
      ..activityPaused = true;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceScreen(key: UniqueKey(), controller: paused),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(of: indicator, matching: find.text('Paused')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: indicator, matching: find.text('Idle')),
      findsNothing,
    );
    await paused.close();
  });

  testWidgets('indicator labels every activity with plain words', (
    tester,
  ) async {
    await _useTallSurface(tester);
    const expected = <TurnActivity, String>{
      TurnActivity.idle: 'Idle',
      TurnActivity.listening: 'Listening',
      TurnActivity.recognizing: 'Hearing you',
      TurnActivity.thinking: 'Preparing a reply',
      TurnActivity.speaking: 'Speaking',
      TurnActivity.interrupting: 'Interrupting',
    };
    for (final entry in expected.entries) {
      final controller = _newController()..displayedActivity = entry.key;
      await tester.pumpWidget(
        MaterialApp(
          home: VoiceScreen(key: UniqueKey(), controller: controller),
        ),
      );
      await tester.pump();
      final indicator = find.byKey(const Key('activity-indicator'));
      expect(
        find.descendant(of: indicator, matching: find.text(entry.value)),
        findsOneWidget,
      );
      expect(find.text('Waiting'), findsNothing);
      await controller.close();
    }
  });
}

Future<void> _useTallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

VoiceScreenController _newController() => VoiceScreenController(
  storage: _EmptyStorage(),
  preparationFactory: (_, _, _) => throw StateError('not expected'),
  sessionFactory: (_, _) => throw StateError('not expected'),
);

final class _EmptyStorage extends ExampleModelStorage {
  @override
  Future<ExampleSelection?> readSelection() async => null;
}
