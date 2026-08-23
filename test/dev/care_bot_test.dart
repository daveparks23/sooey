import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/dev/care_bot.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/game/screens/crest_screen.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';
import 'package:sooey/game/screens/home_screen.dart';
import 'package:sooey/game/screens/stats_screen.dart';
import 'package:sooey/game/screens/truffle_hunt.dart';

import '../game/screens/screen_test_support.dart';

void main() {
  group('pressToward', () {
    test('cycles the home cursor until the icon it wants is lit', () {
      final home = HomeScreen();
      expect(home.selected, isNull, reason: 'a new home screen is parked');
      expect(pressToward(BotGoal.slop, home), Button.a);

      home.selected = DeviceIcon.wallow;
      expect(pressToward(BotGoal.slop, home), Button.a);

      home.selected = DeviceIcon.feed;
      expect(pressToward(BotGoal.slop, home), Button.b);
    });

    test('treats and slop share the feed icon but not the caret', () {
      final menu = FeedMenu();
      expect(menu.treat, isFalse, reason: 'the menu opens on slop');
      expect(pressToward(BotGoal.slop, menu), Button.b);
      expect(pressToward(BotGoal.treat, menu), Button.a);

      menu.treat = true;
      expect(pressToward(BotGoal.treat, menu), Button.b);
    });

    test('guesses in the hunt, and waits out the reveal', () {
      final hunt = TruffleHunt();
      expect(hunt.revealing, isFalse);
      expect(pressToward(BotGoal.play, hunt), Button.a);

      hunt.pigWentLeft = true; // what a guess leaves behind
      expect(hunt.revealing, isTrue);
      expect(pressToward(BotGoal.play, hunt), isNull);
    });

    test('takes any crest rather than shopping for one', () {
      expect(pressToward(BotGoal.slop, CrestScreen()), Button.b);
    });

    test('never presses on the death screen', () {
      // B there is Restart, which would erase the life just watched.
      for (final goal in BotGoal.values) {
        expect(pressToward(goal, DeathScreen()), isNull);
      }
    });

    test('backs out of a screen it did not ask for', () {
      expect(pressToward(BotGoal.slop, StatsScreen()), Button.c);
    });
  });

  group('chooseGoal', () {
    const noon = kRefNoon;

    test('leaves an egg alone', () {
      final egg = testPet(stage: Stage.egg, fullness: 0, enrichment: 0);
      expect(
        chooseGoal(egg, neglected: const {}, nowMillis: noon),
        isNull,
        reason: 'an egg refuses everything but the light',
      );
    });

    test('medicates a sick pig before anything else', () {
      final pet = testPet(isSick: true, fullness: 0, comfort: 0);
      expect(chooseGoal(pet, neglected: const {}, nowMillis: noon),
          BotGoal.meds);
    });

    test('never medicates a healthy one', () {
      // Meds on a well pig costs kMedsHealthPenalty health for nothing.
      final pet = testPet(isSick: false);
      expect(chooseGoal(pet, neglected: const {}, nowMillis: noon), isNull);
    });

    test('cleans up after the pig', () {
      final pet = testPet(poops: 2);
      expect(chooseGoal(pet, neglected: const {}, nowMillis: noon),
          BotGoal.clean);
    });

    test('services the lowest need first', () {
      final pet = testPet(fullness: 55, enrichment: 20, comfort: 50);
      expect(chooseGoal(pet, neglected: const {}, nowMillis: noon),
          BotGoal.treat);
      final hungriest = testPet(fullness: 10, enrichment: 50, comfort: 55);
      expect(chooseGoal(hungriest, neglected: const {}, nowMillis: noon),
          BotGoal.slop);
    });

    test('leaves a neglected need alone and moves on to the next', () {
      final pet = testPet(fullness: 5, comfort: 40);
      expect(
        chooseGoal(pet, neglected: const {'fullness'}, nowMillis: noon),
        BotGoal.wallow,
      );
    });

    test('plays the hunt when there is slack, and treats when there is not', () {
      final easy = testPet(enrichment: 20, fullness: 90, comfort: 90,
          cleanliness: 90);
      expect(chooseGoal(easy, neglected: const {}, nowMillis: noon),
          BotGoal.play);

      // The hunt locks the bot on one screen for five frames. With something
      // else close to the floor that is a luxury, so a treat does instead.
      final tight = testPet(enrichment: 20, fullness: 45, comfort: 90,
          cleanliness: 90);
      expect(chooseGoal(tight, neglected: const {}, nowMillis: noon),
          BotGoal.treat,
          reason: 'enrichment is lowest, but fullness under the bar rules '
              'out the hunt');

      final cooling = testPet(enrichment: 20, fullness: 90, comfort: 90,
          cleanliness: 90).copyWith(lastPlayedAtMillis: noon - 1000);
      expect(chooseGoal(cooling, neglected: const {}, nowMillis: noon),
          BotGoal.treat, reason: 'the hunt is still on cooldown');
    });

    test("keeps the pen light on the pig's own clock", () {
      final settled = testPet(fullness: 90, enrichment: 90, comfort: 90,
          cleanliness: 90, lightsOn: true);
      expect(chooseGoal(settled, neglected: const {}, nowMillis: noon), isNull);

      // The hour comes from nowMillis and the pet's own UTC offset, which
      // testPet leaves at zero, so this is 22:00 local.
      const tenPm = 22 * 60 * 60 * 1000;
      expect(chooseGoal(settled, neglected: const {}, nowMillis: tenPm),
          BotGoal.lightOff);
      expect(
        chooseGoal(settled.copyWith(lightsOn: false),
            neglected: const {}, nowMillis: tenPm),
        isNull,
      );
    });
  });

  group('CareBot', () {
    GameController controllerAt(int millis) =>
        GameController(clock: FakeClock(millis), utcOffsetMinutes: 0);

    test('takes the opening crest so the pig can start living', () {
      final c = controllerAt(kRefNoon);
      final bot = CareBot(CarePreset.attentive);
      expect(c.screen, isA<CrestScreen>());
      expect(bot.nextPress(c), Button.b);
    });

    test('goes quiet on the death screen', () {
      // The pet is born at whatever the clock says, so the clock has to move
      // after the controller exists — thirty days with nobody home.
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0);
      c.press(Button.b); // through the crest
      clock.advance(30 * 86400000);
      c.tick();

      expect(c.pet.isDead, isTrue);
      expect(c.screen, isA<DeathScreen>());
      expect(CareBot(CarePreset.attentive).nextPress(c), isNull);
    });

    test('attentive never lets a need bottom out', () {
      final bot = CareBot(CarePreset.attentive);
      expect(bot.neglectedFor(testPet(stage: Stage.piglet)), isEmpty);
    });

    test('sloppy neglects until it has the mistakes it came for', () {
      final bot = CareBot(CarePreset.sloppy);
      final piglet = testPet(stage: Stage.piglet, health: 100);
      expect(bot.neglectedFor(piglet), kLapseNeeds);

      // Rescued once health reaches the floor.
      expect(bot.neglectedFor(piglet.copyWith(health: 5)), isEmpty);
      // Still cared for on the way back up.
      expect(bot.neglectedFor(piglet.copyWith(health: 40)), isEmpty);
      // And back to neglect once recovered.
      expect(bot.neglectedFor(piglet.copyWith(health: 80)), kLapseNeeds);
    });

    test('stops neglecting once the target is met, and after childhood', () {
      final bot = CareBot(CarePreset.sloppy);
      final done = testPet(stage: Stage.piglet, health: 100)
          .copyWith(careMistakes: kCarePlans[CarePreset.sloppy]!.targetMistakes);
      expect(bot.neglectedFor(done), isEmpty);
      expect(bot.neglectedFor(testPet(stage: Stage.adult, health: 100)),
          isEmpty);
    });

    test('every preset target lands inside the band it is aiming at', () {
      expect(formForMistakes(kCarePlans[CarePreset.attentive]!.targetMistakes),
          Form.prizeHog);
      expect(formForMistakes(kCarePlans[CarePreset.adequate]!.targetMistakes),
          Form.farmHog);
      expect(formForMistakes(kCarePlans[CarePreset.sloppy]!.targetMistakes),
          Form.runt);
    });
  });
}
