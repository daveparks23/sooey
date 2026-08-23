/// Shared fixtures for the golden vectors.
///
/// These are generated on the Dart VM and replayed in Node against the
/// dart2js-compiled bundle. If the two disagree on so much as one field, the
/// client's optimistic prediction would drift from the server's authority and
/// the pig would visibly snap on every sync — so this file is the contract
/// between the two runtimes.
///
/// Everything here is fixed data. No clock reads, no randomness.
library;

import 'package:hog_sim/hog_sim.dart';

/// 2025-08-12T12:00:00Z — noon UTC, exactly tick-aligned.
const refNoon = 1755000000000;
const hour = 3600000;
const day = 24 * hour;

int mins(int n) => n * 60000;

class AdvanceCase {
  const AdvanceCase(this.name, this.input, this.nowMillis);
  final String name;
  final PetState input;
  final int nowMillis;
}

class ActionCase {
  const ActionCase(this.name, this.input, this.action, this.nowMillis);
  final String name;
  final PetState input;
  final PetAction action;
  final int nowMillis;
}

class MinigameCase {
  const MinigameCase(
    this.name,
    this.input,
    this.wins,
    this.rounds,
    this.nowMillis,
  );
  final String name;
  final PetState input;
  final int wins;
  final int rounds;
  final int nowMillis;
}

PetState _base({
  required String petId,
  required int bornAtMillis,
  int? lastTickAtMillis,
  int utcOffsetMinutes = 0,
}) => PetState.newborn(
  petId: petId,
  ownerId: 'uid_golden',
  name: 'Wilbur',
  nowMillis: bornAtMillis,
  utcOffsetMinutes: utcOffsetMinutes,
).copyWith(lastTickAtMillis: lastTickAtMillis ?? bornAtMillis);

PetState egg({String petId = 'pet_golden', int at = refNoon}) =>
    _base(petId: petId, bornAtMillis: at);

PetState piglet({
  String petId = 'pet_golden',
  int at = refNoon,
  double fullness = 100,
  double enrichment = 100,
  double comfort = 100,
  double cleanliness = 100,
  double health = 100,
  int utcOffsetMinutes = 0,
}) =>
    _base(
      petId: petId,
      bornAtMillis: at - mins(kPigletBeginsAtMinutes + 60),
      lastTickAtMillis: at,
      utcOffsetMinutes: utcOffsetMinutes,
    ).copyWith(
      stage: Stage.piglet,
      fullness: fullness,
      enrichment: enrichment,
      comfort: comfort,
      cleanliness: cleanliness,
      health: health,
      weight: 25,
    );

/// A piglet close to growing up, for the piglet->adult transition.
PetState nearlyGrown({
  String petId = 'pet_golden',
  int at = refNoon,
  int stageCareMistakes = 0,
  int careMistakes = 0,
  int minutesBeforeAdult = 30,
}) =>
    _base(
      petId: petId,
      bornAtMillis: at - mins(kAdultBeginsAtMinutes - minutesBeforeAdult),
      lastTickAtMillis: at,
    ).copyWith(
      stage: Stage.piglet,
      weight: 45,
      stageCareMistakes: stageCareMistakes,
      careMistakes: careMistakes,
    );

PetState adult({
  String petId = 'pet_golden',
  int at = refNoon,
  Form form = Form.farmHog,
  double fullness = 100,
  double enrichment = 100,
  double comfort = 100,
  double cleanliness = 100,
  double health = 100,
  double weight = 70,
  bool isSick = false,
  int? sickSinceTick,
  bool lightsOn = true,
  int utcOffsetMinutes = 0,
  int? expiresAtMillis,
  List<int> poops = const [],
  List<int> pendingPoopTicks = const [],
  Map<String, int> needZeroSinceTick = const {},
  int careMistakes = 0,
  int stageCareMistakes = 0,
  int? lastPlayedAtMillis,
}) =>
    _base(
      petId: petId,
      bornAtMillis: at - mins(kAdultBeginsAtMinutes + 120),
      lastTickAtMillis: at,
      utcOffsetMinutes: utcOffsetMinutes,
    ).copyWith(
      stage: Stage.adult,
      form: form,
      expiresAtMillis: expiresAtMillis ?? kExpiresAtSentinelMillis,
      fullness: fullness,
      enrichment: enrichment,
      comfort: comfort,
      cleanliness: cleanliness,
      health: health,
      weight: weight,
      isSick: isSick,
      sickSinceTick: sickSinceTick,
      lightsOn: lightsOn,
      poops: poops,
      pendingPoopTicks: pendingPoopTicks,
      needZeroSinceTick: needZeroSinceTick,
      careMistakes: careMistakes,
      stageCareMistakes: stageCareMistakes,
      lastPlayedAtMillis: lastPlayedAtMillis,
    );

List<AdvanceCase> advanceCases() {
  final tick = refNoon ~/ kTickMillis;
  return [
    // --- the quiet paths --------------------------------------------------
    AdvanceCase('egg/no-op-before-tick', egg(), refNoon + 60000),
    AdvanceCase('egg/idle-10min', egg(), refNoon + mins(10)),
    AdvanceCase('egg/hatches', egg(), refNoon + mins(20)),
    AdvanceCase('egg/straight-through-to-piglet', egg(), refNoon + 3 * hour),

    // --- plain decay, every stage and form --------------------------------
    AdvanceCase('adult/1h', adult(), refNoon + hour),
    AdvanceCase('adult/6h', adult(), refNoon + 6 * hour),
    AdvanceCase(
      'adult/prize-6h',
      adult(form: Form.prizeHog),
      refNoon + 6 * hour,
    ),
    AdvanceCase('adult/runt-6h', adult(form: Form.runt), refNoon + 6 * hour),
    AdvanceCase('adult/base-6h', adult(form: Form.base), refNoon + 6 * hour),
    AdvanceCase('piglet/6h', piglet(), refNoon + 6 * hour),
    AdvanceCase('piglet/1h', piglet(), refNoon + hour),
    AdvanceCase(
      'older-piglet/6h',
      nearlyGrown(minutesBeforeAdult: 6000),
      refNoon + 6 * hour,
    ),

    // --- the sleep window -------------------------------------------------
    AdvanceCase(
      'sleep/awake-hour',
      adult(at: refNoon + hour),
      refNoon + 2 * hour,
    ),
    AdvanceCase(
      'sleep/asleep-hour',
      adult(at: refNoon + 11 * hour),
      refNoon + 12 * hour,
    ),
    AdvanceCase(
      'sleep/spans-boundary',
      adult(at: refNoon + 9 * hour),
      refNoon + 11 * hour,
    ),
    AdvanceCase(
      'sleep/spans-wake',
      adult(at: refNoon + 17 * hour),
      refNoon + 21 * hour,
    ),
    AdvanceCase('sleep/full-day', adult(), refNoon + day),
    AdvanceCase(
      'sleep/offset-minus-five',
      adult(utcOffsetMinutes: -300),
      refNoon + 12 * hour,
    ),
    AdvanceCase(
      'sleep/offset-plus-nine',
      adult(utcOffsetMinutes: 540),
      refNoon + 12 * hour,
    ),
    AdvanceCase(
      'sleep/offset-plus-thirty',
      adult(utcOffsetMinutes: 330),
      refNoon + 12 * hour,
    ),

    // --- health -----------------------------------------------------------
    AdvanceCase(
      'health/one-zeroed',
      adult(fullness: 0, health: 60),
      refNoon + mins(50),
    ),
    AdvanceCase(
      'health/two-zeroed',
      adult(fullness: 0, comfort: 0, health: 60),
      refNoon + mins(50),
    ),
    AdvanceCase('health/recovering', adult(health: 50), refNoon + mins(50)),
    AdvanceCase(
      'health/blocked-by-sickness',
      adult(health: 50, isSick: true, sickSinceTick: tick - 10),
      refNoon + mins(50),
    ),
    AdvanceCase('health/near-cap', adult(health: 99.9), refNoon + hour),

    // --- poop -------------------------------------------------------------
    AdvanceCase(
      'poop/single-arrival',
      adult(pendingPoopTicks: [tick + 3]),
      refNoon + mins(20),
    ),
    AdvanceCase(
      'poop/not-yet',
      adult(pendingPoopTicks: [tick + 10]),
      refNoon + mins(20),
    ),
    AdvanceCase(
      'poop/overflow',
      adult(pendingPoopTicks: [for (var i = 1; i <= 8; i++) tick + i]),
      refNoon + hour,
    ),
    AdvanceCase(
      'poop/dirty-spiral',
      adult(
        cleanliness: 30,
        weight: 112,
        pendingPoopTicks: [tick + 5, tick + 20, tick + 44, tick + 60],
      ),
      refNoon + 6 * hour,
    ),

    // --- care mistakes ----------------------------------------------------
    AdvanceCase('mistakes/exactly-one', adult(fullness: 0), refNoon + mins(60)),
    AdvanceCase('mistakes/just-short', adult(fullness: 0), refNoon + mins(50)),
    AdvanceCase('mistakes/three', adult(fullness: 0), refNoon + mins(180)),
    AdvanceCase(
      'mistakes/two-needs',
      adult(fullness: 0, comfort: 0),
      refNoon + mins(60),
    ),

    // --- stage transitions ------------------------------------------------
    AdvanceCase('childhood/mid-way', piglet(), refNoon + 25 * hour),
    AdvanceCase(
      'transition/to-prize-hog',
      nearlyGrown(stageCareMistakes: 0),
      refNoon + hour,
    ),
    AdvanceCase(
      'transition/to-prize-hog-worst',
      nearlyGrown(stageCareMistakes: kPrizeHogMaxMistakes),
      refNoon + hour,
    ),
    AdvanceCase(
      'transition/to-farm-hog',
      nearlyGrown(stageCareMistakes: kPrizeHogMaxMistakes + 1),
      refNoon + hour,
    ),
    AdvanceCase(
      'transition/to-farm-hog-worst',
      nearlyGrown(stageCareMistakes: kFarmHogMaxMistakes),
      refNoon + hour,
    ),
    AdvanceCase(
      'transition/to-runt',
      nearlyGrown(stageCareMistakes: kFarmHogMaxMistakes + 1),
      refNoon + hour,
    ),
    AdvanceCase(
      'transition/to-runt-extreme',
      nearlyGrown(stageCareMistakes: 99),
      refNoon + hour,
    ),
    AdvanceCase(
      'transition/keeps-lifetime-mistakes',
      nearlyGrown(stageCareMistakes: kPrizeHogMaxMistakes, careMistakes: 21),
      refNoon + hour,
    ),

    // --- death ------------------------------------------------------------
    AdvanceCase(
      'death/starvation',
      adult(fullness: 0, health: 100),
      refNoon + 10 * day,
    ),
    AdvanceCase(
      'death/fast-neglect',
      adult(fullness: 0, comfort: 0, health: 10),
      refNoon + 30 * day,
    ),
    AdvanceCase(
      'death/old-age',
      adult(expiresAtMillis: refNoon + 6 * hour),
      refNoon + day,
    ),
    // A pig that is fed but never cooled: the only route to `neglect`, since
    // an unattended pig always starves first.
    AdvanceCase(
      'death/neglect',
      adult(
        fullness: 100,
        enrichment: 100,
        comfort: 0,
        cleanliness: 100,
        health: 4,
      ),
      refNoon + 2 * hour,
    ),
    AdvanceCase(
      'death/sick-and-failing',
      adult(comfort: 0, health: 8, isSick: true, sickSinceTick: tick - 300),
      refNoon + 2 * day,
    ),
    AdvanceCase('death/long-absence', adult(), refNoon + 30 * day),
    AdvanceCase('death/very-long-absence', adult(), refNoon + 400 * day),

    // --- the sickness roll, across ids so the seed path is exercised ------
    for (var i = 0; i < 12; i++)
      AdvanceCase(
        'sickness/id-$i',
        adult(petId: 'pet_golden_$i', cleanliness: 0, weight: 118),
        refNoon + 5 * hour,
      ),

    // --- awkward inputs ---------------------------------------------------
    AdvanceCase('edge/now-in-the-past', adult(), refNoon - hour),
    AdvanceCase(
      'edge/unaligned-cursor',
      adult().copyWith(lastTickAtMillis: refNoon + 137000),
      refNoon + 3 * hour + 42000,
    ),
    AdvanceCase(
      'edge/already-dead',
      adult().copyWith(
        diedAtMillis: refNoon - hour,
        deathCause: DeathCause.oldAge,
      ),
      refNoon + day,
    ),
    AdvanceCase(
      'edge/full-of-state',
      adult(
        petId: 'pet_kitchen_sink',
        form: Form.runt,
        fullness: 3,
        enrichment: 61.5,
        comfort: 0,
        cleanliness: 12.25,
        health: 44.75,
        weight: 101.5,
        isSick: true,
        sickSinceTick: tick - 50,
        lightsOn: false,
        poops: [tick - 20, tick - 5],
        pendingPoopTicks: [tick + 7, tick + 33],
        needZeroSinceTick: {'comfort': tick - 9},
        careMistakes: 17,
        stageCareMistakes: 4,
        utcOffsetMinutes: -480,
        lastPlayedAtMillis: refNoon - 90000,
      ),
      refNoon + 9 * hour,
    ),
  ];
}

List<ActionCase> actionCases() {
  final tick = refNoon ~/ kTickMillis;
  return [
    ActionCase('slop/normal', adult(fullness: 50), PetAction.slop, refNoon),
    ActionCase('slop/refused', adult(fullness: 95), PetAction.slop, refNoon),
    ActionCase('slop/clamps', adult(fullness: 85), PetAction.slop, refNoon),
    ActionCase('slop/heavy', adult(weight: 119.5), PetAction.slop, refNoon),
    ActionCase('treat/normal', adult(fullness: 50), PetAction.treat, refNoon),
    ActionCase(
      'treat/when-full',
      adult(fullness: 95),
      PetAction.treat,
      refNoon,
    ),
    ActionCase(
      'wallow/normal',
      adult(comfort: 5, cleanliness: 50),
      PetAction.wallow,
      refNoon,
    ),
    ActionCase(
      'wallow/filthy',
      adult(cleanliness: 4),
      PetAction.wallow,
      refNoon,
    ),
    ActionCase(
      'clean/normal',
      adult(cleanliness: 12, poops: [tick - 3, tick - 1]),
      PetAction.clean,
      refNoon,
    ),
    ActionCase(
      'meds/cures',
      adult(isSick: true, sickSinceTick: tick - 4),
      PetAction.meds,
      refNoon,
    ),
    ActionCase('meds/wasted', adult(health: 80), PetAction.meds, refNoon),
    ActionCase(
      'meds/wasted-at-death-door',
      adult(health: 2),
      PetAction.meds,
      refNoon,
    ),
    ActionCase('light/off', adult(lightsOn: true), PetAction.light, refNoon),
    ActionCase('light/on', adult(lightsOn: false), PetAction.light, refNoon),
    ActionCase('egg/refuses-food', egg(), PetAction.slop, refNoon),
    ActionCase('egg/accepts-light', egg(), PetAction.light, refNoon),
    ActionCase(
      'dead/refuses',
      adult().copyWith(
        diedAtMillis: refNoon - hour,
        deathCause: DeathCause.neglect,
      ),
      PetAction.slop,
      refNoon,
    ),
  ];
}

List<MinigameCase> minigameCases() => [
  MinigameCase('play/perfect', adult(enrichment: 50), 5, 5, refNoon),
  MinigameCase('play/good', adult(enrichment: 50), 4, 5, refNoon),
  MinigameCase('play/middling', adult(enrichment: 50), 3, 5, refNoon),
  MinigameCase('play/poor', adult(enrichment: 50), 1, 5, refNoon),
  MinigameCase('play/shutout', adult(enrichment: 50), 0, 5, refNoon),
  MinigameCase('play/clamps', adult(enrichment: 95), 5, 5, refNoon),
  MinigameCase('play/bad-rounds', adult(), 3, 7, refNoon),
  MinigameCase('play/too-many-wins', adult(), 6, 5, refNoon),
  MinigameCase('play/negative', adult(), -1, 5, refNoon),
  MinigameCase(
    'play/cooldown',
    adult(lastPlayedAtMillis: refNoon - 30000),
    5,
    5,
    refNoon,
  ),
  MinigameCase(
    'play/cooldown-expired',
    adult(lastPlayedAtMillis: refNoon - kPlayCooldownMillis),
    5,
    5,
    refNoon,
  ),
];

/// Builds the full vector document. Used by the emitter and by the test that
/// checks the checked-in file is still current.
Map<String, Object?> buildGoldenVectors() => {
  'note':
      'Generated on the Dart VM by tool/emit_golden_vectors.dart. Replayed in '
      'Node against the dart2js bundle. Regenerate deliberately: a diff here '
      'means the simulation changed.',
  'tickMinutes': kTickMinutes,
  'advance': [
    for (final c in advanceCases())
      {
        'name': c.name,
        'input': c.input.toJson(),
        'nowMillis': c.nowMillis,
        'expected': advance(c.input, c.nowMillis).toJson(),
      },
  ],
  'action': [
    for (final c in actionCases())
      {
        'name': c.name,
        'input': c.input.toJson(),
        'action': c.action.name,
        'nowMillis': c.nowMillis,
        'expected': actionOutcomeToJson(
          applyAction(c.input, c.action, c.nowMillis),
        ),
      },
  ],
  'minigame': [
    for (final c in minigameCases())
      {
        'name': c.name,
        'input': c.input.toJson(),
        'wins': c.wins,
        'rounds': c.rounds,
        'nowMillis': c.nowMillis,
        'expected': actionOutcomeToJson(
          applyMinigame(
            c.input,
            wins: c.wins,
            rounds: c.rounds,
            nowMillis: c.nowMillis,
          ),
        ),
      },
  ],
};
