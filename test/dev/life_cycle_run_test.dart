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

/// Runs a whole life headlessly, exactly as the page drives it.
///
/// No widgets: a controller, a fake clock and the bot. 3600x means one frame
/// is 36 simulated minutes, so a twenty-day life is about 800 frames — and at
/// 600x a frame is 6 minutes, so the same life is about 4,800.
///
/// The press budget comes from `botPressBudget(speed)`, which is what the page
/// uses too: presses per frame have to scale with how much simulated time a
/// frame covers, or the same preset raises a different adult at each speed.
LifeResult runLife(CarePreset preset, {int speed = 3600}) {
  final clock = FakeClock(kRefNoon);
  final controller = GameController(clock: clock, utcOffsetMinutes: 0);
  // The hunt draws from dart:math's Random, which would make this test
  // irreproducible. Treats buy the same enrichment deterministically.
  final bot = CareBot(preset, playsHunt: false);

  final budget = botPressBudget(speed);
  var lowestHealth = 100.0;

  // A twenty-day life is 28,800 simulated minutes; the loop bound has to cover
  // that at the slowest speed the page offers, with room to spare.
  final maxFrames = 20 * 24 * 60 * 60000 ~/ (kAnimFrameMillis * speed) + 500;

  for (var frame = 0; frame < maxFrames; frame++) {
    clock.advance(kAnimFrameMillis * speed);
    controller.tick();

    final pet = controller.pet;
    if (pet.health < lowestHealth) lowestHealth = pet.health;

    if (pet.isDead) {
      final reachedAdult = pet.form != Form.base;
      return (
        form: pet.form,
        mistakesAtBranch: reachedAdult ? decidingMistakes(pet) : -1,
        reachedAdult: reachedAdult,
        deathCause: pet.deathCause,
        ageAtDeathDays: (pet.diedAtMillis! - pet.bornAtMillis) ~/ 86400000,
        lowestHealth: lowestHealth,
      );
    }

    for (var i = 0; i < budget; i++) {
      final button = bot.nextPress(controller);
      if (button == null) break;
      controller.press(button);
    }
  }
  fail('the pig outlived $maxFrames frames at ${speed}x without dying');
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
    expect(
      life.reachedAdult,
      isTrue,
      reason: 'a preset that kills its pig is not a care quality',
    );
    expect(
      life.mistakesAtBranch,
      inInclusiveRange(kPrizeHogMaxMistakes + 1, kFarmHogMaxMistakes),
    );
    expect(life.form, Form.farmHog);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(15, 17));
  });

  // This run's deciding count lands on the runt band floor (one above
  // kFarmHogMaxMistakes), not its ceiling: rescueBelow: 35 calls the lapse
  // off well before the pig could ever accumulate kRuntWorstMistakes (8).
  // What this test demonstrates is that sloppy care survives childhood and
  // produces a runt with the intended near-death signature — it does not
  // demonstrate that the runt band's ceiling is reachable or survivable.
  // No test in this file exercises kRuntWorstMistakes, and an independent
  // re-measurement with hand-optimized neglect policies topped out at 7, so
  // treat 8 as marginal rather than as a demonstrated ceiling.
  test('sloppy care raises a runt that nearly did not make it', () {
    final life = runLife(CarePreset.sloppy);
    expect(life.reachedAdult, isTrue);
    expect(life.mistakesAtBranch, greaterThan(kFarmHogMaxMistakes));
    expect(life.mistakesAtBranch, lessThanOrEqualTo(kRuntWorstMistakes));
    expect(life.form, Form.runt);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(12, 14));
    expect(
      life.lowestHealth,
      lessThan(40),
      reason: 'a runt is a pig that nearly died in childhood',
    );
  });

  // The three tests above run at the page's default speed. These run every
  // preset at every speed the page actually offers, because the whole promise
  // of the harness is that the chip you pick to watch at cannot change the
  // animal you get. It could, before `botPressBudget` scaled the press budget
  // with simulated time: at 600x the sloppy preset produced a farm hog and at
  // 10800x it starved the pig in childhood.
  group('every preset raises its advertised adult at every page speed', () {
    const advertised = {
      CarePreset.attentive: Form.prizeHog,
      CarePreset.adequate: Form.farmHog,
      CarePreset.sloppy: Form.runt,
    };
    // Kept in step with `_speeds` in lib/dev/life_cycle_page.dart by hand:
    // it is private, and a dev page should not export its chip list.
    const pageSpeeds = [600, 3600];

    for (final speed in pageSpeeds) {
      for (final MapEntry(key: preset, value: form) in advertised.entries) {
        test('${preset.name} at ${speed}x', () {
          final life = runLife(preset, speed: speed);
          expect(
            life.reachedAdult,
            isTrue,
            reason: 'a preset that kills its pig is not a care quality',
          );
          expect(life.form, form);
          expect(
            formForMistakes(life.mistakesAtBranch),
            form,
            reason: 'the deciding count has to sit in the form it produced',
          );
          expect(life.deathCause, DeathCause.oldAge);
        });
      }
    }
  });
}
