import 'package:flutter_test/flutter_test.dart';
import 'package:split_flap_display/main.dart';

void main() {
  testWidgets('shows the split flap display', (tester) async {
    await tester.pumpWidget(const SplitFlapDisplayApp());

    expect(find.text('Split Flap Display'), findsOneWidget);
    expect(find.text('HELLO WORLD'), findsNothing);
    expect(find.text('H'), findsOneWidget);
  });
}