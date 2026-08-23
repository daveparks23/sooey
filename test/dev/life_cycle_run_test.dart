import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/dev/care_bot.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/sprites/sprite_registry.dart';

import '../game/screens/screen_test_support.dart';

/// What one unattended life came to.
typedef LifeResult = ({
  Form form,
  int mistakesAtBranch,
  bool reachedAdult,
  DeathCause? deathCause,
  int ageAtDeathDays,
  double lowestHealth,
});

/// Runs a whole life headlessly, exactly as the page will drive it.
///
/// No widgets: a controller, a fake clock and the bot. 3600x means one frame
/// is 36 simulated minutes, so a twenty-day life is about 800 frames.
LifeResult runLife(CarePreset preset, {int speed = 3600}) {
  final clock = FakeClock(kRefNoon);
  final controller = GameController(clock: clock, utcOffsetMinutes: 0);
  // The hunt draws from dart:math's Random, which would make this test
  // irreproducible. Treats buy the same enrichment deterministically.
  final bot = CareBot(preset, playsHunt: false);

  var mistakesAtBranch = -1;
  var lowestHealth = 100.0;
  var previousStage = controller.pet.stage;

  for (var frame = 0; frame < 5000; frame++) {
    clock.advance(kAnimFrameMillis * speed);
    controller.tick();

    final pet = controller.pet;
    if (pet.stage == Stage.adult && previousStage != Stage.adult) {
      // The branch zeroes stageCareMistakes on the same tick it fixes the
      // form, so the count that decided it has to be read from careMistakes.
      mistakesAtBranch = pet.careMistakes;
    }
    previousStage = pet.stage;
    if (pet.health < lowestHealth) lowestHealth = pet.health;

    if (pet.isDead) {
      return (
        form: pet.form,
        mistakesAtBranch: mistakesAtBranch,
        reachedAdult: mistakesAtBranch >= 0,
        deathCause: pet.deathCause,
        ageAtDeathDays: (pet.diedAtMillis! - pet.bornAtMillis) ~/ 86400000,
        lowestHealth: lowestHealth,
      );
    }

    for (var i = 0; i < kBotPressBudget; i++) {
      final button = bot.nextPress(controller);
      if (button == null) break;
      controller.press(button);
    }
  }
  fail('the pig outlived 5000 frames without dying');
}

void main() {
  test('attentive care raises a prize hog that dies of old age', () {
    final life = runLife(CarePreset.attentive);
    expect(life.reachedAdult, isTrue);
    expect(life.mistakesAtBranch, 0);
    expect(life.form, Form.prizeHog);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(18, 20));
  });

  test('adequate care raises a farm hog', () {
    final life = runLife(CarePreset.adequate);
    expect(life.reachedAdult, isTrue,
        reason: 'a preset that kills its pig is not a care quality');
    expect(life.mistakesAtBranch,
        inInclusiveRange(kPrizeHogMaxMistakes + 1, kFarmHogMaxMistakes));
    expect(life.form, Form.farmHog);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(15, 17));
  });

  test('sloppy care raises a runt that nearly did not make it', () {
    final life = runLife(CarePreset.sloppy);
    expect(life.reachedAdult, isTrue);
    expect(life.mistakesAtBranch, greaterThan(kFarmHogMaxMistakes));
    expect(life.mistakesAtBranch, lessThanOrEqualTo(kRuntWorstMistakes));
    expect(life.form, Form.runt);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(12, 14));
    expect(life.lowestHealth, lessThan(40),
        reason: 'a runt is a pig that nearly died in childhood');
  });
}
