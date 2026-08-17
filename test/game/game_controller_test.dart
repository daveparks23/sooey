import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_constants.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/game/screens/crest_screen.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';
import 'package:sooey/game/screens/home_screen.dart';
import 'package:sooey/sprites/sprite_registry.dart';

import 'screens/screen_test_support.dart';

const int _hour = 60 * 60 * 1000;

/// A controller with its pig already hatched and hungry enough to eat.
///
/// Slop is refused above 90 fullness, and a newborn starts at 100, so a test
/// that wants to feed has to let some time pass first. Three hours also clears
/// the fifteen-minute egg.
(GameController, FakeClock) hatched() {
  final clock = FakeClock(kRefNoon - 3 * _hour);
  final c = GameController(clock: clock, utcOffsetMinutes: 0);
  c.press(Button.b); // accept the opening crest
  clock.advance(3 * _hour);
  c.tick();
  return (c, clock);
}

void main() {
  group('a new pet', () {
    test('opens on the crest picker', () {
      final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
      expect(c.screen, isA<CrestScreen>());
    });

    test('starts as an egg', () {
      final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
      expect(c.pet.stage, Stage.egg);
    });

    test('reaches the home screen once the crest is chosen', () {
      final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
      c.press(Button.a);
      final chosen = (c.screen as CrestScreen).crest;
      c.press(Button.b);
      expect(c.screen, isA<HomeScreen>());
      expect(c.crest, chosen);
    });

    test('hatches on its own', () {
      final (c, _) = hatched();
      expect(c.pet.stage, Stage.piglet);
    });
  });

  group('actions', () {
    test('feeding raises fullness and shows the pig eating', () {
      final (c, _) = hatched();
      final before = c.pet.fullness;
      c.press(Button.a); // cursor to feed
      c.press(Button.b); // open the submenu
      expect(c.screen, isA<FeedMenu>());
      c.press(Button.b); // slop
      expect(c.pet.fullness, greaterThan(before));
      expect(c.screen, isA<HomeScreen>(), reason: 'submenu should have closed');
      expect(c.context.transientPose, PetPose.eating);
    });

    test('the eating pose wears off', () {
      final (c, clock) = hatched();
      c.press(Button.a);
      c.press(Button.b);
      c.press(Button.b);
      clock.advance(kTransientPoseMillis + 1);
      expect(c.context.transientPose, isNull);
    });

    test('cleaning clears the pen', () {
      final (c, clock) = hatched();

      // Only slop schedules a poop, and it arrives kTicksUntilPoop (150
      // minutes) later. Without feeding first the pen is empty and this test
      // could not fail.
      c.press(Button.a); // feed
      c.press(Button.b); // open
      c.press(Button.b); // slop
      clock.advance(3 * _hour);
      c.tick();
      expect(c.pet.poops, isNotEmpty, reason: 'a meal should produce a mess');

      while (c.litIcon != DeviceIcon.clean) {
        c.press(Button.a);
      }
      c.press(Button.b);
      expect(c.pet.poops, isEmpty);
      expect(c.pet.cleanliness, 100);
    });

    test('wallowing comforts the pig and dirties it, as spec 7.2 wants', () {
      final (c, _) = hatched();
      c.press(Button.a);
      c.press(Button.a); // cursor to wallow
      final dirtBefore = c.pet.cleanliness;
      c.press(Button.b);
      expect(c.pet.comfort, 100);
      expect(c.pet.cleanliness, lessThan(dirtBefore));
    });
  });

  group('refusals', () {
    test('blink the icon that refused rather than sadden the pig', () {
      // The face reads current needs only and has to stay honest. A pig that
      // looked miserable because a button did nothing would be lying.
      //
      // Note the press sequence: after the first slop the cursor is still on
      // feed, so B reopens the submenu. Pressing A again would walk it on to
      // wallow and the second action would be an accepted wallow instead of a
      // refused bucket.
      final (c, _) = hatched();
      c.press(Button.a); // cursor to feed
      c.press(Button.b); // open
      c.press(Button.b); // slop, accepted — fullness now capped at 100
      c.press(Button.b); // reopen
      c.press(Button.b); // slop again, over 90 and refused
      expect(c.blinkingIcon, DeviceIcon.feed);

      // And the refusal leaves the pig looking exactly as the accepted feed
      // left it. Note this is `eating`, not null — the pose from two presses
      // ago is still running. The point is that the refusal did not touch it.
      expect(
        c.context.transientPose,
        PetPose.eating,
        reason: 'a refusal must not touch the pose the accepted feed set',
      );
    });

    test('stop blinking after a moment', () {
      final (c, clock) = hatched();
      c.press(Button.a);
      c.press(Button.b);
      c.press(Button.b);
      c.press(Button.b);
      c.press(Button.b);
      expect(c.blinkingIcon, isNotNull, reason: 'setup should have refused');
      clock.advance(kRefusalBlinkMillis + 1);
      expect(c.blinkingIcon, isNull);
    });

    test('an egg refuses everything but the light', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);

      // Wallowing: refused. An egg has no mud, no mouth and no mess.
      while (c.litIcon != DeviceIcon.wallow) {
        c.press(Button.a);
      }
      c.press(Button.b);
      expect(c.blinkingIcon, DeviceIcon.wallow);

      // The pen light: the one thing that works before it hatches. Without
      // this half the test would pass even if the light were refused too.
      clock.advance(kRefusalBlinkMillis + 1);
      final litBefore = c.pet.lightsOn;
      while (c.litIcon != DeviceIcon.light) {
        c.press(Button.a);
      }
      c.press(Button.b);
      expect(c.pet.lightsOn, !litBefore, reason: 'the light should toggle');
      expect(c.blinkingIcon, isNull, reason: 'the light was not refused');
    });
  });

  group('death', () {
    test('takes over the screen when the pig dies', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      expect(c.pet.isDead, isTrue);
      expect(c.screen, isA<DeathScreen>());
    });

    test('gives the death a cause', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      expect(c.pet.deathCause, isNotNull);
    });

    test('B starts a fresh pig back at the crest', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      c.press(Button.b);
      expect(c.screen, isA<CrestScreen>());
      expect(c.pet.isDead, isFalse);
      expect(c.pet.stage, Stage.egg);
    });

    test('stops the simulation dead rather than ticking a corpse', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      final died = c.pet.diedAtMillis;
      clock.advance(2 * 24 * _hour);
      c.tick();
      expect(c.pet.diedAtMillis, died);
    });
  });

  group('the frame counter', () {
    test('advances on every tick, so animations run', () {
      final (c, _) = hatched();
      final before = c.frame;
      c.tick();
      expect(c.frame, greaterThan(before));
    });

    test('composes whatever screen is on top', () {
      final (c, _) = hatched();
      expect(c.compose().width, 32);
      expect(c.compose().height, 16);
    });
  });

  test('notifies listeners on a press, so the widget rebuilds', () {
    final (c, _) = hatched();
    var notified = 0;
    c.addListener(() => notified++);
    c.press(Button.a);
    expect(notified, 1);
  });
}
