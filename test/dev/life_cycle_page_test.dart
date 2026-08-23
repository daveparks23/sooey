import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/dev/life_cycle_page.dart';

void main() {
  testWidgets('runs a pig out of its shell and into childhood', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LifeCyclePage()));

    expect(find.text('attentive'), findsOneWidget);
    expect(find.text('adequate'), findsOneWidget);
    expect(find.text('sloppy'), findsOneWidget);
    expect(find.textContaining('egg'), findsOneWidget);

    await tester.tap(find.text('Start'));
    // A frame is 36 simulated minutes at 3600x, and an egg hatches at 15.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.textContaining('piglet'), findsOneWidget);
    expect(find.textContaining('hatched'), findsOneWidget);

    // Stop the timer, or the test ends with one pending and fails.
    await tester.tap(find.text('Pause'));
    await tester.pump();
  });
}
