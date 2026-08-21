import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/frame_composer.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';
import 'package:sooey/game/screens/home_screen.dart';
import 'package:sooey/game/screens/stats_screen.dart';
import 'package:sooey/game/screens/truffle_hunt.dart';
import 'package:sooey/sprites/sprite_registry.dart';

import 'screen_test_support.dart';

void main() {
  group('the cursor', () {
    test('starts on nothing, so the pig is not framed by a menu at rest', () {
      expect(HomeScreen().litIcon, isNull);
    });

    test('lands on feed with the first press of A', () {
      final s = HomeScreen();
      drive(s, 'A', testContext());
      expect(s.selected, DeviceIcon.feed);
    });

    test('visits every icon exactly once in a lap', () {
      final s = HomeScreen();
      final visited = <DeviceIcon>[];
      for (var i = 0; i < DeviceIcon.values.length; i++) {
        drive(s, 'A', testContext());
        visited.add(s.selected!);
      }
      expect(visited.toSet(), DeviceIcon.values.toSet());
    });

    test('comes back to where it started after seven presses', () {
      final s = HomeScreen()..selected = DeviceIcon.feed;
      drive(s, 'AAAAAAA', testContext());
      expect(s.selected, DeviceIcon.feed);
    });

    test('C clears the selection rather than leaving the screen', () {
      // Home is the root of the stack. C here has nothing to pop to, so it
      // means "never mind" instead.
      final s = HomeScreen()..selected = DeviceIcon.meds;
      final out = drive(s, 'C', testContext());
      expect(s.selected, isNull);
      expect(out.single, isA<Stay>());
    });
  });

  group('B', () {
    test('does nothing while nothing is selected', () {
      expect(drive(HomeScreen(), 'B', testContext()).single, isA<Stay>());
    });

    test('acts directly for the icons that have no submenu', () {
      const direct = {
        DeviceIcon.wallow: PetAction.wallow,
        DeviceIcon.clean: PetAction.clean,
        DeviceIcon.meds: PetAction.meds,
        DeviceIcon.light: PetAction.light,
      };
      direct.forEach((icon, action) {
        final s = HomeScreen()..selected = icon;
        final out = drive(s, 'B', testContext()).single;
        expect(out, isA<Act>(), reason: icon.name);
        expect((out as Act).action, action, reason: icon.name);
      });
    });
  });

  group('B opens the three screens that need one', () {
    test('feed opens the submenu', () {
      final s = HomeScreen()..selected = DeviceIcon.feed;
      final out = drive(s, 'B', testContext()).single;
      expect((out as Push).screen, isA<FeedMenu>());
    });

    test('play opens the truffle hunt', () {
      final s = HomeScreen()..selected = DeviceIcon.play;
      final out = drive(s, 'B', testContext()).single;
      expect((out as Push).screen, isA<TruffleHunt>());
    });

    test('stats opens the status pages', () {
      final s = HomeScreen()..selected = DeviceIcon.stats;
      final out = drive(s, 'B', testContext()).single;
      expect((out as Push).screen, isA<StatsScreen>());
    });
  });

  group('play against an egg', () {
    // applyMinigame only refuses `notHatched` after five full rounds are
    // played, so without a refusal here an egg would trot to a mound and
    // snuffle five times before the game admits it could never have worked.
    test('is refused rather than pushed, and blinks the play icon', () {
      final s = HomeScreen()..selected = DeviceIcon.play;
      final ctx = testContext(pet: testPet(stage: Stage.egg, ageDays: 0));
      final out = drive(s, 'B', ctx).single;
      expect(out, isA<Refused>());
      expect((out as Refused).icon, DeviceIcon.play);
    });

    test('is pushed once the pig has hatched', () {
      final s = HomeScreen()..selected = DeviceIcon.play;
      final ctx = testContext(pet: testPet(stage: Stage.piglet));
      final out = drive(s, 'B', ctx).single;
      expect((out as Push).screen, isA<TruffleHunt>());
    });
  });

  group('the frame', () {
    test('is the pig, drawn by the composer that is already tested', () {
      final ctx = testContext();
      expect(
        HomeScreen().compose(ctx, 0).toAscii(),
        composeFrame(ctx.pet, frame: 0, nowMillis: ctx.nowMillis).toAscii(),
      );
    });

    test('shows the egg without any code that knows what an egg is', () {
      // creatureAnim already returns the egg for Stage.egg and applyAction
      // already refuses everything but the light until it hatches, so home
      // needs no egg screen and no special case.
      final ctx = testContext(pet: testPet(stage: Stage.egg, ageDays: 0));
      expect(HomeScreen().compose(ctx, 0).toAscii(), contains('#'));
    });

    test('passes the transient pose through, so an action visibly lands', () {
      final ctx = testContext(transientPose: PetPose.eating);
      final plain = testContext();
      expect(
        HomeScreen().compose(ctx, 0).toAscii(),
        isNot(HomeScreen().compose(plain, 0).toAscii()),
      );
    });
  });
}
