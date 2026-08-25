import 'package:flutter/material.dart' hide Form;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/device_shell.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/home_screen.dart';

import '../game/screens/screen_test_support.dart';

Future<void> pumpShell(WidgetTester tester, GameController c) async {
  await tester.binding.setSurfaceSize(const Size(600, 900));
  await tester.pumpWidget(MaterialApp(home: DeviceShell(controller: c)));
}

void main() {
  testWidgets('has exactly three buttons', (tester) async {
    // Spec 6: three physical buttons, exactly like the hardware. A fourth
    // would be a different device.
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
    await pumpShell(tester, c);
    expect(find.byType(DeviceButton), findsExactly(3));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tapping a button drives the controller', (tester) async {
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0)
      ..press(Button.b); // past the crest picker
    await pumpShell(tester, c);

    await tester.tap(find.byKey(const ValueKey('button.a')));
    await tester.pump();
    expect((c.screen as HomeScreen).selected, DeviceIcon.feed);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the arrow keys and enter are the three buttons', (tester) async {
    // A key is a physical button by another name. This is not a touch UI: the
    // glass and the bezel stay inert.
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0)
      ..press(Button.b);
    await pumpShell(tester, c);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect((c.screen as HomeScreen).selected, DeviceIcon.feed);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect((c.screen as HomeScreen).selected, isNull, reason: 'C should clear');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('nothing on the glass responds to a tap', (tester) async {
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0)
      ..press(Button.b);
    await pumpShell(tester, c);

    await tester.tapAt(tester.getCenter(find.byType(DeviceShell)));
    await tester.pump();
    expect((c.screen as HomeScreen).selected, isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
