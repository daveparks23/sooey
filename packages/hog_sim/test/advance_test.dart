import 'package:hog_sim/hog_sim.dart';
import 'package:test/test.dart';

/// 2025-08-12T12:00:00Z — exactly noon UTC and exactly tick-aligned, so a pet
/// with offset 0 starts wide awake.
const refNoon = 1755000000000;

const _hour = 3600000;
const _day = 24 * _hour;

int minutes(int n) => n * 60000;

/// An adult in `base` form, so the stage and form decay multipliers are both
/// 1.0 and the expected arithmetic stays readable.
PetState adult({
  int at = refNoon,
  double fullness = 100,
  double enrichment = 100,
  double comfort = 100,
  double cleanliness = 100,
  double health = 100,
  double weight = 70,
  bool isSick = false,
  int? sickSinceTick,
  int utcOffsetMinutes = 0,
  int? expiresAtMillis,
  List<int> pendingPoopTicks = const [],
  List<int> poops = const [],
  Map<String, int> needZeroSinceTick = const {},
  int stageCareMistakes = 0,
  int careMistakes = 0,
}) {
  return PetState.newborn(
    petId: 'pet_test',
    ownerId: 'uid_1',
    name: 'Wilbur',
    nowMillis: at - minutes(kAdultBeginsAtMinutes + 60),
    utcOffsetMinutes: utcOffsetMinutes,
  ).copyWith(
    stage: Stage.adult,
    form: Form.base,
    lastTickAtMillis: at,
    expiresAtMillis: expiresAtMillis ?? kExpiresAtSentinelMillis,
    fullness: fullness,
    enrichment: enrichment,
    comfort: comfort,
    cleanliness: cleanliness,
    health: health,
    weight: weight,
    isSick: isSick,
    sickSinceTick: sickSinceTick,
    pendingPoopTicks: pendingPoopTicks,
    poops: poops,
    needZeroSinceTick: needZeroSinceTick,
    stageCareMistakes: stageCareMistakes,
    careMistakes: careMistakes,
  );
}

void main() {
  group('decay', () {
    test('an adult loses the expected amount of each need in one hour', () {
      final after = advance(adult(), refNoon + _hour);

      // 12 ticks, no stage/form/sleep multiplier.
      expect(after.fullness, closeTo(100 - 12 * kFullnessDecay, 1e-9));
      expect(after.enrichment, closeTo(100 - 12 * kEnrichmentDecay, 1e-9));
      expect(after.comfort, closeTo(100 - 12 * kComfortDecay, 1e-9));
      expect(after.cleanliness, closeTo(100 - 12 * kCleanlinessDecay, 1e-9));
      expect(after.weight, closeTo(70 - 12 * kWeightDecay, 1e-9));
    });

    test('needs clamp at zero rather than going negative', () {
      final after = advance(adult(fullness: 1), refNoon + 6 * _hour);
      expect(after.fullness, 0);
    });

    test('does nothing when now is before the next tick boundary', () {
      final before = adult();
      final after = advance(before, refNoon + 60000); // one minute
      expect(after.fullness, before.fullness);
      expect(after.comfort, before.comfort);
    });

    test('an egg does not decay at all', () {
      final egg = PetState.newborn(
        petId: 'pet_test',
        ownerId: 'uid_1',
        name: 'Wilbur',
        nowMillis: refNoon,
        utcOffsetMinutes: 0,
      );
      final after = advance(egg, refNoon + minutes(10));
      expect(after.stage, Stage.egg);
      expect(after.fullness, 100);
      expect(after.comfort, 100);
    });

    test('a piglet decays faster than an adult over the same window', () {
      final pigletBorn = refNoon - minutes(kPigletBeginsAtMinutes + 60);
      final piglet = PetState.newborn(
        petId: 'pet_test',
        ownerId: 'uid_1',
        name: 'Wilbur',
        nowMillis: pigletBorn,
        utcOffsetMinutes: 0,
      ).copyWith(stage: Stage.piglet, lastTickAtMillis: refNoon, weight: 25);

      final pigletAfter = advance(piglet, refNoon + _hour);
      final adultAfter = advance(adult(), refNoon + _hour);
      expect(pigletAfter.comfort, lessThan(adultAfter.comfort));
    });

    test('a prize hog decays slower than a runt over the same window', () {
      final prize = advance(
        adult().copyWith(form: Form.prizeHog),
        refNoon + 6 * _hour,
      );
      final runt = advance(
        adult().copyWith(form: Form.runt),
        refNoon + 6 * _hour,
      );
      expect(prize.comfort, greaterThan(runt.comfort));
    });
  });

  group('sleep', () {
    // refNoon is 12:00 UTC and tick-aligned, so hour offsets land exactly on
    // tick boundaries. A tick stamped exactly 22:00 is already asleep.

    test('an asleep hour costs the sleep multiplier of an awake one', () {
      // 13:00 -> 14:00 is twelve fully awake ticks.
      final awakeLoss =
          100 -
          advance(adult(at: refNoon + _hour), refNoon + 2 * _hour).comfort;
      // 23:00 -> 00:00 is twelve fully asleep ticks.
      final asleepLoss =
          100 -
          advance(
            adult(at: refNoon + 11 * _hour),
            refNoon + 12 * _hour,
          ).comfort;

      expect(asleepLoss, lessThan(awakeLoss));
      expect(asleepLoss, closeTo(awakeLoss * kSleepDecayMultiplier, 1e-9));
    });

    test('a window spanning the boundary decays at both rates', () {
      // 21:00 -> 23:00 is 24 ticks. The first eleven (21:05 through 21:55) are
      // awake; the tick stamped 22:00 is the first asleep one, giving thirteen.
      final after = advance(
        adult(at: refNoon + 9 * _hour),
        refNoon + 11 * _hour,
      );
      final expected =
          100 - 11 * kComfortDecay - 13 * kComfortDecay * kSleepDecayMultiplier;
      expect(after.comfort, closeTo(expected, 1e-9));
    });
  });

  group('health', () {
    test('loses exactly the per-need rate while one need is zeroed', () {
      final after = advance(
        adult(fullness: 0, health: 60),
        refNoon + minutes(50), // 10 ticks
      );
      expect(after.health, closeTo(60 - 10 * kHealthLossPerZeroedNeed, 1e-9));
    });

    test('loses at twice the rate while two needs are zeroed', () {
      final after = advance(
        adult(fullness: 0, comfort: 0, health: 60),
        refNoon + minutes(50),
      );
      expect(
        after.health,
        closeTo(60 - 10 * 2 * kHealthLossPerZeroedNeed, 1e-9),
      );
    });

    test('recovers while every need is above the threshold', () {
      final after = advance(adult(health: 50), refNoon + minutes(50));
      expect(after.health, closeTo(50 + 10 * kHealthRecovery, 1e-9));
    });

    test('does not recover while sick', () {
      final after = advance(
        adult(health: 50, isSick: true, sickSinceTick: refNoon ~/ kTickMillis),
        refNoon + minutes(50),
      );
      expect(after.health, 50);
    });

    test('does not recover while a need sits below the threshold', () {
      final after = advance(
        adult(health: 50, comfort: 10),
        refNoon + minutes(50),
      );
      expect(after.health, 50);
    });

    test('clamps to 100', () {
      final after = advance(adult(health: 99.9), refNoon + _hour);
      expect(after.health, 100);
    });
  });

  group('poop', () {
    test('a scheduled poop arrives and dirties the pen', () {
      final arrival = refNoon ~/ kTickMillis + 3;
      final after = advance(
        adult(pendingPoopTicks: [arrival]),
        refNoon + minutes(20),
      );
      expect(after.poops, [arrival]);
      expect(after.pendingPoopTicks, isEmpty);
      // Four ticks of ambient decay plus the poop itself.
      expect(
        after.cleanliness,
        closeTo(100 - 4 * kCleanlinessDecay - kCleanlinessPerPoop, 1e-9),
      );
    });

    test('does not arrive before its scheduled tick', () {
      final arrival = refNoon ~/ kTickMillis + 10;
      final after = advance(
        adult(pendingPoopTicks: [arrival]),
        refNoon + minutes(20),
      );
      expect(after.poops, isEmpty);
      expect(after.pendingPoopTicks, [arrival]);
    });

    test('the floor holds no more than the maximum', () {
      final base = refNoon ~/ kTickMillis;
      final after = advance(
        adult(pendingPoopTicks: [for (var i = 1; i <= 8; i++) base + i]),
        refNoon + _hour,
      );
      expect(after.poops.length, kMaxPoops);
    });
  });

  group('care mistakes', () {
    test('records one mistake after an hour at zero', () {
      // 12 ticks at zero is exactly one mistake.
      final after = advance(
        adult(fullness: 0, needZeroSinceTick: {}),
        refNoon + minutes(kTicksAtZeroForMistake * kTickMinutes),
      );
      expect(after.careMistakes, 1);
      expect(after.stageCareMistakes, 1);
    });

    test('records nothing before the threshold', () {
      final after = advance(
        adult(fullness: 0),
        refNoon + minutes((kTicksAtZeroForMistake - 2) * kTickMinutes),
      );
      expect(after.careMistakes, 0);
    });

    test('keeps accruing while the need stays at zero', () {
      final after = advance(
        adult(fullness: 0),
        refNoon + minutes(kTicksAtZeroForMistake * kTickMinutes * 3),
      );
      expect(after.careMistakes, 3);
    });

    test('counts each zeroed need separately', () {
      final after = advance(
        adult(fullness: 0, comfort: 0),
        refNoon + minutes(kTicksAtZeroForMistake * kTickMinutes),
      );
      expect(after.careMistakes, 2);
    });

    test('forgets the counter once the need is restored', () {
      final partway = advance(
        adult(fullness: 0),
        refNoon + minutes(6 * kTickMinutes),
      );
      expect(partway.needZeroSinceTick.containsKey('fullness'), isTrue);

      final fed = partway.copyWith(fullness: 80);
      final after = advance(fed, partway.lastTickAtMillis + minutes(30));
      expect(after.needZeroSinceTick.containsKey('fullness'), isFalse);
      expect(after.careMistakes, 0);
    });
  });

  group('stage transitions', () {
    test('an egg hatches into a piglet', () {
      final egg = PetState.newborn(
        petId: 'pet_test',
        ownerId: 'uid_1',
        name: 'Wilbur',
        nowMillis: refNoon,
        utcOffsetMinutes: 0,
      );
      final after = advance(egg, refNoon + minutes(20));
      expect(after.stage, Stage.piglet);
    });

    test('a shoat becomes an adult and its form is fixed', () {
      final born = refNoon - minutes(kAdultBeginsAtMinutes - 5);
      final shoat =
          PetState.newborn(
            petId: 'pet_test',
            ownerId: 'uid_1',
            name: 'Wilbur',
            nowMillis: born,
            utcOffsetMinutes: 0,
          ).copyWith(
            stage: Stage.shoat,
            lastTickAtMillis: refNoon,
            stageCareMistakes: 2,
            careMistakes: 9,
          );

      final after = advance(shoat, refNoon + minutes(30));
      expect(after.stage, Stage.adult);
      expect(after.form, Form.prizeHog);
      expect(after.expiresAtMillis, lessThan(kExpiresAtSentinelMillis));
      expect(after.stageCareMistakes, 0, reason: 'reset at the transition');
      expect(after.careMistakes, 9, reason: 'lifetime count is untouched');
    });

    test('a neglected shoat becomes a runt', () {
      final born = refNoon - minutes(kAdultBeginsAtMinutes - 5);
      final shoat =
          PetState.newborn(
            petId: 'pet_test',
            ownerId: 'uid_1',
            name: 'Wilbur',
            nowMillis: born,
            utcOffsetMinutes: 0,
          ).copyWith(
            stage: Stage.shoat,
            lastTickAtMillis: refNoon,
            stageCareMistakes: 14,
          );

      final after = advance(shoat, refNoon + minutes(30));
      expect(after.form, Form.runt);
    });

    test('the prize hog outlives the runt', () {
      int expiryFor(int mistakes) {
        final born = refNoon - minutes(kAdultBeginsAtMinutes - 5);
        final shoat =
            PetState.newborn(
              petId: 'pet_test',
              ownerId: 'uid_1',
              name: 'Wilbur',
              nowMillis: born,
              utcOffsetMinutes: 0,
            ).copyWith(
              stage: Stage.shoat,
              lastTickAtMillis: refNoon,
              stageCareMistakes: mistakes,
            );
        return advance(shoat, refNoon + minutes(30)).expiresAtMillis;
      }

      expect(expiryFor(0), greaterThan(expiryFor(14)));
    });
  });

  group('death', () {
    test('a pet advanced thirty days dies', () {
      final after = advance(
        adult(fullness: 0, comfort: 0, health: 10),
        refNoon + 30 * _day,
      );
      expect(after.isDead, isTrue);
    });

    test('records the death tick rather than the moment of the call', () {
      final now = refNoon + 30 * _day;
      final after = advance(adult(fullness: 0, comfort: 0, health: 10), now);
      expect(after.diedAtMillis, isNotNull);
      expect(after.diedAtMillis, lessThan(now));
      expect(
        after.diedAtMillis! % kTickMillis,
        0,
        reason: 'must land on a tick boundary',
      );
    });

    test('freezes the pet so a later call changes nothing', () {
      final dead = advance(
        adult(fullness: 0, comfort: 0, health: 10),
        refNoon + 30 * _day,
      );
      final later = advance(dead, refNoon + 60 * _day);
      expect(later, dead);
    });

    test('starvation when fullness has been zero for a day', () {
      final after = advance(
        adult(fullness: 0, health: 100),
        refNoon + 10 * _day,
      );
      expect(after.deathCause, DeathCause.starvation);
    });

    test('old age when the clock runs out on a healthy pig', () {
      // The window has to be short enough that the pig is still healthy when
      // its clock runs out — an unattended pig dies of neglect inside a day, so
      // old age is only reachable here with a near-term expiry.
      final expiry = refNoon + 6 * _hour;
      final after = advance(adult(expiresAtMillis: expiry), refNoon + _day);
      expect(after.deathCause, DeathCause.oldAge);
      expect(after.diedAtMillis, greaterThanOrEqualTo(expiry - kTickMillis));
      expect(after.diedAtMillis, lessThanOrEqualTo(expiry + kTickMillis));
    });
  });

  group('determinism', () {
    test('two identical calls produce byte-identical output', () {
      final start = adult(fullness: 30, cleanliness: 20, weight: 110);
      final a = advance(start, refNoon + 3 * _day);
      final b = advance(start, refNoon + 3 * _day);
      expect(jsonEncodeState(a), jsonEncodeState(b));
    });

    /// Runs the same five-hour window for [n] different pet ids and counts how
    /// many fell ill. Five hours keeps every pig alive (a single zeroed need
    /// takes about 67 ticks to kill), so this measures the sickness roll rather
    /// than the death loop.
    int sickCountAcrossIds({
      required double cleanliness,
      required double weight,
      int n = 60,
    }) {
      var count = 0;
      for (var i = 0; i < n; i++) {
        final start = PetState.fromJson({
          ...adult(cleanliness: cleanliness, weight: weight).toJson(),
          'petId': 'pet_$i',
        });
        if (advance(start, refNoon + 5 * _hour).isSick) count++;
      }
      return count;
    }

    test('the sickness roll varies by pet id', () {
      final n = sickCountAcrossIds(cleanliness: 0, weight: 118);
      expect(n, greaterThan(0), reason: 'no pig ever got sick');
      expect(n, lessThan(60), reason: 'every single pig got sick');
    });

    test(
      'a filthy overweight pig falls ill far more often than a clean one',
      () {
        final filthy = sickCountAcrossIds(cleanliness: 0, weight: 118);
        final clean = sickCountAcrossIds(cleanliness: 100, weight: 70);
        expect(clean, lessThan(filthy));
      },
    );
  });

  group('the equivalence property', () {
    // This is the test that guarantees the client's optimistic prediction and
    // the server's authoritative run agree. If it fails, the pig visibly snaps
    // to a different state on every sync.

    PetState stepwise(PetState from, int steps, int stepMillis) {
      var s = from;
      for (var i = 1; i <= steps; i++) {
        s = advance(s, from.lastTickAtMillis + i * stepMillis);
      }
      return s;
    }

    test('one six-hour call equals seventy-two five-minute calls', () {
      final start = adult(fullness: 40, comfort: 30, cleanliness: 25);
      final oneShot = advance(start, refNoon + 6 * _hour);
      final stepped = stepwise(start, 72, kTickMillis);
      expect(jsonEncodeState(stepped), jsonEncodeState(oneShot));
    });

    test('holds across the sleep boundary', () {
      final start = adult(at: refNoon + 9 * _hour, fullness: 40, comfort: 30);
      final oneShot = advance(start, refNoon + 15 * _hour);
      final stepped = stepwise(start, 72, kTickMillis);
      expect(jsonEncodeState(stepped), jsonEncodeState(oneShot));
    });

    test('holds across a stage transition', () {
      final born = refNoon - minutes(kAdultBeginsAtMinutes - 30);
      final shoat =
          PetState.newborn(
            petId: 'pet_test',
            ownerId: 'uid_1',
            name: 'Wilbur',
            nowMillis: born,
            utcOffsetMinutes: 0,
          ).copyWith(
            stage: Stage.shoat,
            lastTickAtMillis: refNoon,
            stageCareMistakes: 5,
          );

      final oneShot = advance(shoat, refNoon + 6 * _hour);
      final stepped = stepwise(shoat, 72, kTickMillis);
      expect(jsonEncodeState(stepped), jsonEncodeState(oneShot));
    });

    test('holds across poop arrivals and a sickness window', () {
      final base = refNoon ~/ kTickMillis;
      final start = adult(
        cleanliness: 30,
        weight: 112,
        pendingPoopTicks: [base + 5, base + 20, base + 44, base + 60],
      );
      final oneShot = advance(start, refNoon + 6 * _hour);
      final stepped = stepwise(start, 72, kTickMillis);
      expect(jsonEncodeState(stepped), jsonEncodeState(oneShot));
    });

    test('holds for uneven step sizes over three days', () {
      final start = adult(fullness: 20, comfort: 15, cleanliness: 10);
      final oneShot = advance(start, refNoon + 3 * _day);

      var stepped = start;
      // Deliberately not tick-aligned, to prove tick boundaries are absolute
      // rather than relative to whenever the last call happened.
      for (var offset = 0; offset <= 3 * _day; offset += 7 * 60000 + 13000) {
        stepped = advance(stepped, refNoon + offset);
      }
      stepped = advance(stepped, refNoon + 3 * _day);

      expect(jsonEncodeState(stepped), jsonEncodeState(oneShot));
    });

    test('holds when the pet dies partway through the window', () {
      final start = adult(fullness: 0, comfort: 0, health: 20);
      final oneShot = advance(start, refNoon + 10 * _day);
      final stepped = stepwise(start, 10 * 24 * 12, kTickMillis);
      expect(jsonEncodeState(stepped), jsonEncodeState(oneShot));
      expect(oneShot.isDead, isTrue);
    });
  });

  group('bounding', () {
    test('a very long absence terminates without hanging', () {
      final after = advance(adult(), refNoon + 400 * _day);
      expect(after.lastTickAtMillis, greaterThan(refNoon));
    });

    test('never runs away past the iteration cap in a single call', () {
      // An immortal pet with the sentinel expiry and no needs would otherwise
      // simulate forever; the cap must stop it.
      final immortal = adult(at: refNoon).copyWith(health: 100);
      final after = advance(immortal, refNoon + 3650 * _day);
      final ticksRun = (after.lastTickAtMillis - refNoon) ~/ kTickMillis;
      expect(ticksRun, lessThanOrEqualTo(kMaxIterations));
    });
  });
}
