import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/stats_screen.dart';

import 'screen_test_support.dart';

void main() {
  group('paging', () {
    test('opens on the needs', () {
      expect(StatsScreen().page, 0);
    });

    test('B moves forward and wraps, so every page is reachable', () {
      final s = StatsScreen();
      for (var i = 1; i < StatsScreen.pageCount; i++) {
        drive(s, 'B', testContext());
        expect(s.page, i);
      }
      drive(s, 'B', testContext());
      expect(s.page, 0);
    });

    test('C leaves', () {
      expect(drive(StatsScreen(), 'C', testContext()).single, isA<Pop>());
    });

    test('keeps the stats icon lit throughout', () {
      expect(StatsScreen().litIcon, DeviceIcon.stats);
    });
  });

  group('the needs page', () {
    test('draws a different frame for a starving pig than a full one', () {
      final hungry = testContext(pet: testPet(fullness: 0));
      final fed = testContext(pet: testPet(fullness: 100));
      expect(
        StatsScreen().compose(hungry, 0).toAscii(),
        isNot(StatsScreen().compose(fed, 0).toAscii()),
      );
    });

    test('shows all four needs at once rather than paging them', () {
      // One bar per need with its own icon beneath. Four separate pages would
      // make comparing them impossible, which is the only thing the page is for.
      for (final name in kNeedNames) {
        final low = testContext(pet: testPet().withNeed(name, 0));
        final high = testContext(pet: testPet().withNeed(name, 100));
        expect(
          StatsScreen().compose(low, 0).toAscii(),
          isNot(StatsScreen().compose(high, 0).toAscii()),
          reason: '$name does not reach the needs page',
        );
      }
    });
  });

  group('the body page', () {
    test('reflects health', () {
      final ill = testContext(pet: testPet(health: 5));
      final well = testContext(pet: testPet(health: 100));
      final s = StatsScreen()..page = 1;
      expect(s.compose(ill, 0).toAscii(), isNot(s.compose(well, 0).toAscii()));
    });

    test('reflects weight', () {
      final thin = testContext(pet: testPet(weight: 25));
      final fat = testContext(pet: testPet(weight: 115));
      final s = StatsScreen()..page = 1;
      expect(s.compose(thin, 0).toAscii(), isNot(s.compose(fat, 0).toAscii()));
    });
  });

  group('the life page', () {
    test('shows one pip per elapsed day', () {
      final young = testContext(pet: testPet(ageDays: 1));
      final old = testContext(pet: testPet(ageDays: 9));
      final s = StatsScreen()..page = 2;
      expect(s.compose(young, 0).toAscii(), isNot(s.compose(old, 0).toAscii()));
    });

    test('shows the rosette only once the pig is an adult', () {
      // The three builds already differ by skull width; the ribbon is the label
      // Dave asked for, and a piglet has not been judged yet.
      final s = StatsScreen()..page = 2;
      final piglet = testContext(pet: testPet(stage: Stage.piglet, ageDays: 2));
      final adult = testContext(pet: testPet(stage: Stage.adult, ageDays: 2));
      expect(
        s.compose(piglet, 0).toAscii(),
        isNot(s.compose(adult, 0).toAscii()),
      );
    });

    test('gives the three builds different ribbons', () {
      final s = StatsScreen()..page = 2;
      final shapes = {
        for (final form in [Form.prizeHog, Form.farmHog, Form.runt])
          s.compose(testContext(pet: testPet(form: form)), 0).toAscii(),
      };
      expect(shapes.length, 3);
    });

    test('never draws an empty pip slot', () {
      // An outlined row of slots would imply a denominator, and the denominator
      // is the lifespan, which is set from the hidden care-mistake count. A
      // count may grow forever; a fraction gives the game away.
      //
      // Two days on a piglet is 2 pips of 4 dots and no rosette, so anything
      // beyond 8 lit dots means empty slots are being outlined.
      final s = StatsScreen()..page = 2;
      final two = s.compose(
        testContext(pet: testPet(stage: Stage.piglet, ageDays: 2)),
        0,
      );
      final lit = two.toAscii().split('').where((c) => c == '#').length;
      expect(lit, 8, reason: 'pips should be a count, not a track');
    });
  });
}
