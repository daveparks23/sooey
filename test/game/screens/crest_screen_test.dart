import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/game/screens/crest_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';

import 'screen_test_support.dart';

void main() {
  test('opens on the first emblem', () {
    expect(CrestScreen().crest, Crest.values.first);
  });

  test('A cycles through all eight and comes back round', () {
    final s = CrestScreen();
    final seen = <Crest>{s.crest};
    for (var i = 1; i < Crest.values.length; i++) {
      drive(s, 'A', testContext());
      seen.add(s.crest);
    }
    expect(seen, Crest.values.toSet());
    drive(s, 'A', testContext());
    expect(s.crest, Crest.values.first, reason: 'did not wrap');
  });

  test('B commits the emblem and starts the pig', () {
    final s = CrestScreen();
    drive(s, 'A', testContext());
    final out = drive(s, 'B', testContext()).single;
    expect(out, isA<Crested>());
    expect((out as Crested).crest, s.crest);
  });

  test('C does nothing — there is nowhere behind this screen', () {
    expect(drive(CrestScreen(), 'C', testContext()).single, isA<Stay>());
  });

  test('lights no strip icon: this screen is not reached from the strip', () {
    expect(CrestScreen().litIcon, isNull);
  });

  test('draws a different frame for each emblem', () {
    final s = CrestScreen();
    final shapes = <String>{};
    for (var i = 0; i < Crest.values.length; i++) {
      shapes.add(s.compose(testContext(), 0).toAscii());
      drive(s, 'A', testContext());
    }
    expect(shapes.length, Crest.values.length);
  });
}
