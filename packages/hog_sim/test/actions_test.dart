import 'package:hog_sim/hog_sim.dart';
import 'package:test/test.dart';

const refNoon = 1755000000000;
const _hour = 3600000;

int minutes(int n) => n * 60000;

PetState adult({
  double fullness = 50,
  double enrichment = 50,
  double comfort = 50,
  double cleanliness = 50,
  double health = 80,
  double weight = 70,
  bool isSick = false,
  bool lightsOn = true,
  List<int> poops = const [],
  List<int> pendingPoopTicks = const [],
  int? lastPlayedAtMillis,
}) {
  return PetState.newborn(
    petId: 'pet_test',
    ownerId: 'uid_1',
    name: 'Wilbur',
    nowMillis: refNoon - minutes(kAdultBeginsAtMinutes + 60),
    utcOffsetMinutes: 0,
  ).copyWith(
    stage: Stage.adult,
    form: Form.farmHog,
    lastTickAtMillis: refNoon,
    fullness: fullness,
    enrichment: enrichment,
    comfort: comfort,
    cleanliness: cleanliness,
    health: health,
    weight: weight,
    isSick: isSick,
    lightsOn: lightsOn,
    poops: poops,
    pendingPoopTicks: pendingPoopTicks,
    lastPlayedAtMillis: lastPlayedAtMillis,
  );
}

void main() {
  group('slop', () {
    test('fills the pig up and puts weight on it', () {
      final out = applyAction(adult(), PetAction.slop, refNoon);
      expect(out.accepted, isTrue);
      expect(out.state.fullness, 50 + kSlopFullness);
      expect(out.state.weight, 70 + kWeightPerMeal);
    });

    test('schedules a poop for later', () {
      final out = applyAction(adult(), PetAction.slop, refNoon);
      expect(out.state.pendingPoopTicks, [
        refNoon ~/ kTickMillis + kTicksUntilPoop,
      ]);
    });

    test('is refused by a pig that is nearly full', () {
      final out = applyAction(adult(fullness: 95), PetAction.slop, refNoon);
      expect(out.accepted, isFalse);
      expect(out.refusal, ActionRefusal.notHungry);
      expect(out.state, adult(fullness: 95), reason: 'state is untouched');
    });

    test('clamps fullness at 100', () {
      final out = applyAction(adult(fullness: 85), PetAction.slop, refNoon);
      expect(out.state.fullness, 100);
    });

    test('clamps weight at the maximum', () {
      final out = applyAction(adult(weight: 119.5), PetAction.slop, refNoon);
      expect(out.state.weight, kWeightMax);
    });
  });

  group('treat', () {
    test('feeds a little and entertains a little', () {
      final out = applyAction(adult(), PetAction.treat, refNoon);
      expect(out.state.fullness, 50 + kTreatFullness);
      expect(out.state.enrichment, 50 + kTreatEnrichment);
      expect(out.state.weight, 70 + kWeightPerTreat);
    });

    test('schedules no poop', () {
      final out = applyAction(adult(), PetAction.treat, refNoon);
      expect(out.state.pendingPoopTicks, isEmpty);
    });

    test('is accepted even by a nearly full pig', () {
      final out = applyAction(adult(fullness: 95), PetAction.treat, refNoon);
      expect(out.accepted, isTrue);
    });
  });

  group('wallow', () {
    test('cools the pig completely and makes a mess', () {
      final out = applyAction(adult(comfort: 5), PetAction.wallow, refNoon);
      expect(out.state.comfort, 100);
      expect(out.state.cleanliness, 50 - kWallowCleanlinessCost);
    });

    test('is always available', () {
      final out = applyAction(
        adult(comfort: 100, cleanliness: 100),
        PetAction.wallow,
        refNoon,
      );
      expect(out.accepted, isTrue);
    });

    test('cannot push cleanliness below zero', () {
      final out = applyAction(adult(cleanliness: 4), PetAction.wallow, refNoon);
      expect(out.state.cleanliness, 0);
    });
  });

  group('clean', () {
    test('clears the floor and resets cleanliness', () {
      final out = applyAction(
        adult(cleanliness: 12, poops: const [100, 101, 102]),
        PetAction.clean,
        refNoon,
      );
      expect(out.state.poops, isEmpty);
      expect(out.state.cleanliness, 100);
    });

    test('leaves scheduled poops alone', () {
      final out = applyAction(
        adult(poops: const [100], pendingPoopTicks: const [200]),
        PetAction.clean,
        refNoon,
      );
      expect(out.state.pendingPoopTicks, [200]);
    });
  });

  group('meds', () {
    test('cures a sick pig', () {
      final out = applyAction(
        adult(isSick: true).copyWith(sickSinceTick: 123),
        PetAction.meds,
        refNoon,
      );
      expect(out.state.isSick, isFalse);
      expect(out.state.sickSinceTick, isNull);
      expect(out.state.health, 80, reason: 'no penalty for a real cure');
    });

    test('costs health when the pig was not sick', () {
      final out = applyAction(adult(), PetAction.meds, refNoon);
      expect(out.state.health, 80 - kMedsHealthPenalty);
    });

    test('cannot push health below zero', () {
      final out = applyAction(adult(health: 2), PetAction.meds, refNoon);
      expect(out.state.health, 0);
    });
  });

  group('light', () {
    test('toggles the pen light', () {
      final on = adult(lightsOn: true);
      final off = applyAction(on, PetAction.light, refNoon).state;
      expect(off.lightsOn, isFalse);
      expect(applyAction(off, PetAction.light, refNoon).state.lightsOn, isTrue);
    });
  });

  group('minigame', () {
    test('a strong round is worth the most enrichment', () {
      final out = applyMinigame(
        adult(),
        wins: 5,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.accepted, isTrue);
      expect(out.state.enrichment, 50 + kPlayEnrichmentHigh);
      expect(out.state.weight, 70 + kWeightPerPlay);
    });

    test('a middling round is worth less', () {
      final out = applyMinigame(
        adult(),
        wins: 3,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.state.enrichment, 50 + kPlayEnrichmentMid);
    });

    test('a poor round still counts for something', () {
      final out = applyMinigame(
        adult(),
        wins: 1,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.state.enrichment, 50 + kPlayEnrichmentLow);
    });

    test('records when the pig last played', () {
      final out = applyMinigame(
        adult(),
        wins: 3,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.state.lastPlayedAtMillis, refNoon);
    });

    test('rejects a wrong number of rounds', () {
      final out = applyMinigame(
        adult(),
        wins: 3,
        rounds: 7,
        nowMillis: refNoon,
      );
      expect(out.accepted, isFalse);
      expect(out.refusal, ActionRefusal.invalid);
    });

    test('rejects more wins than rounds', () {
      final out = applyMinigame(
        adult(),
        wins: 6,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.accepted, isFalse);
      expect(out.refusal, ActionRefusal.invalid);
    });

    test('rejects a negative score', () {
      final out = applyMinigame(
        adult(),
        wins: -1,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.accepted, isFalse);
    });

    test('rejects a second game inside the cooldown', () {
      final out = applyMinigame(
        adult(lastPlayedAtMillis: refNoon - 30000),
        wins: 5,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.accepted, isFalse);
      expect(out.refusal, ActionRefusal.cooldown);
    });

    test('allows another game once the cooldown has passed', () {
      final out = applyMinigame(
        adult(lastPlayedAtMillis: refNoon - kPlayCooldownMillis),
        wins: 5,
        rounds: 5,
        nowMillis: refNoon,
      );
      expect(out.accepted, isTrue);
    });
  });

  group('a dead pig', () {
    PetState dead() => adult().copyWith(
      diedAtMillis: refNoon - _hour,
      deathCause: DeathCause.neglect,
    );

    test('refuses every action', () {
      for (final action in PetAction.values) {
        final out = applyAction(dead(), action, refNoon);
        expect(out.accepted, isFalse, reason: '${action.name} was accepted');
        expect(out.refusal, ActionRefusal.dead);
      }
    });

    test('refuses the minigame', () {
      final out = applyMinigame(dead(), wins: 5, rounds: 5, nowMillis: refNoon);
      expect(out.accepted, isFalse);
      expect(out.refusal, ActionRefusal.dead);
    });
  });

  group('an egg', () {
    PetState egg() => PetState.newborn(
      petId: 'pet_test',
      ownerId: 'uid_1',
      name: 'Wilbur',
      nowMillis: refNoon,
      utcOffsetMinutes: 0,
    );

    test('cannot be fed before it hatches', () {
      final out = applyAction(egg(), PetAction.slop, refNoon);
      expect(out.accepted, isFalse);
      expect(out.refusal, ActionRefusal.notHatched);
    });

    test('can still have its light switched', () {
      final out = applyAction(egg(), PetAction.light, refNoon);
      expect(out.accepted, isTrue);
    });
  });
}
