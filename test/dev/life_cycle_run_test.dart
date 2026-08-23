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

/// Recovers the exact `stageCareMistakes` that decided [pet]'s adult form,
/// from the lifespan the branch stamped onto `expiresAtMillis`.
///
/// Reading `pet.careMistakes` right after the transition looks like the
/// obvious way to get this, but it is only exact at one-tick granularity.
/// At 3600x, one `controller.tick()` call advances ~7.2 simulated ticks
/// (`kAnimFrameMillis * 3600 / kTickMillis`), and `needZeroSinceTick` is not
/// reset by a stage change — so a need still at zero when the branch fires
/// can tick over another mistake in the same frame, *after* the branch,
/// inflating the cumulative `careMistakes` this test would otherwise read.
///
/// `expiresAtMillis`, by contrast, is stamped once at the branch tick and
/// never touched again, and `lifespanMinutes` is strictly monotonic in the
/// mistake count within a form's band. So the deciding count is recovered
/// exactly by scanning that band for the one value whose `expiresAtForAdult`
/// reproduces the pig's actual `expiresAtMillis` — independent of how many
/// ticks a single frame happened to advance.
int decidingMistakes(PetState pet) {
  final (lo, hi) = switch (pet.form) {
    Form.prizeHog => (0, kPrizeHogMaxMistakes),
    Form.farmHog => (kPrizeHogMaxMistakes + 1, kFarmHogMaxMistakes),
    Form.runt => (kFarmHogMaxMistakes + 1, kRuntWorstMistakes),
    Form.base => throw ArgumentError('base is not an adult form'),
  };
  for (var m = lo; m <= hi; m++) {
    if (expiresAtForAdult(pet.bornAtMillis, pet.form, m) ==
        pet.expiresAtMillis) {
      return m;
    }
  }
  fail(
    'no mistake count in [$lo, $hi] reproduces this ${pet.form.name}\'s '
    'expiresAtMillis (${pet.expiresAtMillis})',
  );
}

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

  var lowestHealth = 100.0;

  for (var frame = 0; frame < 5000; frame++) {
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

  // This run's deciding count lands on the runt band floor (one above
  // kFarmHogMaxMistakes), not its ceiling: rescueBelow: 35 calls the lapse
  // off well before the pig could ever accumulate kRuntWorstMistakes (8).
  // What this test demonstrates is that sloppy care survives childhood and
  // produces a runt with the intended near-death signature — it does not
  // demonstrate that the runt band's ceiling is reachable or survivable.
  // No test in this file exercises kRuntWorstMistakes.
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
