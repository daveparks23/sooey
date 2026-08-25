import 'package:flutter/material.dart' hide Form;
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/dev/life_cycle_page.dart';
import 'package:sooey/sprites/sprite_registry.dart';

/// Runs the page until it stops itself, which it does when the pig dies.
///
/// The Start/Pause label is the signal: the page flips it back to Start when
/// it cancels its own timer on death. Reading the log for a grave would not
/// do — a long enough log scrolls the last line out of the viewport.
Future<void> pumpToGrave(WidgetTester tester) async {
  // A twenty-day life at 3600x is 800 frames of 36 simulated minutes.
  for (var frame = 0; frame < 1000; frame++) {
    await tester.pump(const Duration(milliseconds: kAnimFrameMillis));
    if (find.text('Start').evaluate().isNotEmpty) return;
  }
  fail('the pig outlived 1000 frames without dying');
}

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

  // The point of the page. Not a duplicate of the headless full-life tests:
  // those pin the bot, and this pins what the page actually builds — which is
  // where the harness was wrong, because the page was constructing a bot with
  // the truffle hunt on while every test constructed one with it off, and the
  // sloppy preset produced a farm hog on the page and a runt in the test.
  group('a whole life on the page produces the advertised adult', () {
    const advertised = {
      'attentive': Form.prizeHog,
      'adequate': Form.farmHog,
      'sloppy': Form.runt,
    };

    for (final MapEntry(key: preset, value: form) in advertised.entries) {
      testWidgets('$preset care raises a ${form.name}', (tester) async {
        await tester.pumpWidget(const MaterialApp(home: LifeCyclePage()));
        await tester.tap(find.text(preset));
        await tester.pump();

        await tester.tap(find.text('Start'));
        await pumpToGrave(tester);

        expect(
          find.textContaining('grew up into ${form.name} on '),
          findsOneWidget,
        );
        expect(find.textContaining('adult/${form.name}'), findsOneWidget);
      });
    }
  });

  testWidgets('switching the truffle hunt on starts a new pig', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LifeCyclePage()));

    await tester.tap(find.text('Start'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.textContaining('hatched'), findsOneWidget);

    // The hunt buys enrichment a treat cannot match, so a childhood played
    // half under each setting belongs to neither. Toggling starts over — and
    // that also cancels the timer, so nothing is pending at the end here.
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    expect(find.textContaining('hatched'), findsNothing);
    expect(find.textContaining('egg'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('re-tapping the lit preset chip leaves the run alone', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LifeCyclePage()));

    await tester.tap(find.text('Start'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.textContaining('hatched'), findsOneWidget);

    // ChoiceChip.onSelected fires on the chip that is already selected too,
    // and throwing away a run in progress for that is a nasty surprise.
    await tester.tap(find.text('attentive'));
    await tester.pump();

    expect(find.textContaining('hatched'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget, reason: 'still running');

    await tester.tap(find.text('Pause'));
    await tester.pump();
  });
}
