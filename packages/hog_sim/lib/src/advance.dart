import 'constants.dart';
import 'pet_state.dart';
import 'rng.dart';
import 'stages.dart';

/// Steps [from] forward in [kTickMinutes] increments until it reaches
/// [nowMillis] or the pig dies, whichever comes first.
///
/// Pure: no I/O, no clock reads, no unseeded randomness. The same call on the
/// Dart VM, in dart2js on the server, and in the browser must return identical
/// output — that guarantee is what lets the client predict optimistically.
///
/// Ticks are indexed against absolute time (`millis ~/ kTickMillis`) rather
/// than relative to the last call, which is why advancing six hours in one call
/// equals advancing five minutes seventy-two times regardless of how the caller
/// chops up the window.
PetState advance(PetState from, int nowMillis) {
  if (from.isDead) return from;

  final endTick = nowMillis ~/ kTickMillis;
  var tick = from.lastTickAtMillis ~/ kTickMillis;
  var state = from;
  var iterations = 0;

  while (tick < endTick) {
    if (iterations >= kMaxIterations) {
      // Permadeath bounds the simulation naturally, so reaching this means a
      // bug rather than a long absence. Stop where we are and leave the cursor
      // behind, so the next call picks up rather than losing time.
      return state.copyWith(lastTickAtMillis: tick * kTickMillis);
    }
    tick++;
    iterations++;
    state = _tick(state, tick);
    if (state.isDead) return state;
  }

  return state.copyWith(lastTickAtMillis: nowMillis);
}

/// One five-minute step. The order of operations here is part of the spec
/// because it is observable — see §5.3.
PetState _tick(PetState s, int tick) {
  final tickMillis = tick * kTickMillis;

  // 2. Sleep state, in the pet's own local time.
  final sleeping = isSleepingAtMillis(tickMillis, s.utcOffsetMinutes);

  // 3. Age, and any life-stage transition. The transition may fix the adult
  //    form and the moment of natural death.
  final ageMinutes = (tickMillis - s.bornAtMillis) ~/ 60000;
  final newStage = stageForAgeMinutes(ageMinutes);
  var stage = s.stage;
  var form = s.form;
  var expiresAt = s.expiresAtMillis;
  var stageCareMistakes = s.stageCareMistakes;
  var careMistakes = s.careMistakes;

  if (newStage != stage) {
    if (newStage == Stage.adult) {
      // Branch on the mistakes made during the shoat stage, before the counter
      // is reset. The player is never shown either number.
      form = formForMistakes(stageCareMistakes);
      expiresAt = expiresAtForAdult(s.bornAtMillis, form, stageCareMistakes);
    }
    stage = newStage;
    stageCareMistakes = 0;
  }

  final isEgg = stage == Stage.egg;

  // 4. Deliver poops scheduled for this tick.
  var poops = s.poops;
  var pending = s.pendingPoopTicks;
  var cleanliness = s.cleanliness;
  if (pending.isNotEmpty && pending.any((t) => t <= tick)) {
    final arrived = [
      for (final t in pending)
        if (t <= tick) t,
    ];
    pending = [
      for (final t in pending)
        if (t > tick) t,
    ];
    // The mess happens whether or not there is room left to draw it; only the
    // number of poops on screen is capped.
    cleanliness -= kCleanlinessPerPoop * arrived.length;
    poops = [...poops, ...arrived];
    if (poops.length > kMaxPoops) {
      poops = poops.sublist(poops.length - kMaxPoops);
    }
  }

  // 5. Need decay, stacked stage x form x sleep.
  final multiplier = decayMultiplier(
    stage: stage,
    form: form,
    isSleeping: sleeping,
  );
  final fullness = _clampNeed(s.fullness - kFullnessDecay * multiplier);
  final enrichment = _clampNeed(s.enrichment - kEnrichmentDecay * multiplier);
  final comfort = _clampNeed(s.comfort - kComfortDecay * multiplier);
  cleanliness = _clampNeed(cleanliness - kCleanlinessDecay * multiplier);

  // 6. Weight decay. An egg neither eats nor shrinks.
  var weight = s.weight;
  if (!isEgg) {
    weight = s.weight - kWeightDecay;
    if (weight < kWeightMin) weight = kWeightMin;
    if (weight > kWeightMax) weight = kWeightMax;
  }

  // 7. Sickness roll. The only randomness inside the loop, and the only reason
  //    tickSeed exists.
  var isSick = s.isSick;
  var sickSinceTick = s.sickSinceTick;
  if (!isSick && !isEgg) {
    final p = sicknessProbability(
      cleanliness: cleanliness,
      weight: weight,
      stage: stage,
      form: form,
    );
    if (unitDouble(tickSeed(s.petId, tick)) < p) {
      isSick = true;
      sickSinceTick = tick;
    }
  }

  // 8. Health. Zeroed needs cost health; otherwise a comfortable, well pig
  //    slowly recovers.
  final needs = <String, double>{
    'fullness': fullness,
    'enrichment': enrichment,
    'comfort': comfort,
    'cleanliness': cleanliness,
  };
  var zeroedNeeds = 0;
  var allAboveThreshold = true;
  for (final name in kNeedNames) {
    final v = needs[name]!;
    if (v <= 0) zeroedNeeds++;
    if (v <= kHealthRecoveryThreshold) allAboveThreshold = false;
  }

  var health = s.health;
  if (zeroedNeeds > 0) {
    health -= kHealthLossPerZeroedNeed * zeroedNeeds;
  } else if (allAboveThreshold && !isSick) {
    health += kHealthRecovery;
  }
  if (health < 0) health = 0;
  if (health > 100) health = 100;

  // 9. Care-mistake tracking. `needZeroSinceTick` records when a need bottomed
  //    out and is never reset while it stays there, so it doubles as the
  //    duration used by the death causes below.
  var needZeroSinceTick = s.needZeroSinceTick;
  Map<String, int>? mutableNeedZero;
  for (final name in kNeedNames) {
    final v = needs[name]!;
    final since = needZeroSinceTick[name];
    if (v <= 0) {
      if (since == null) {
        mutableNeedZero ??= Map<String, int>.from(needZeroSinceTick);
        mutableNeedZero[name] = tick;
      } else {
        final ticksAtZero = tick - since + 1;
        if (ticksAtZero > 0 && ticksAtZero % kTicksAtZeroForMistake == 0) {
          careMistakes++;
          stageCareMistakes++;
        }
      }
    } else if (since != null) {
      mutableNeedZero ??= Map<String, int>.from(needZeroSinceTick);
      mutableNeedZero.remove(name);
    }
  }
  if (mutableNeedZero != null) needZeroSinceTick = mutableNeedZero;

  // 10. Death. Checked at the end of the tick; `diedAt` is this tick's
  //     timestamp, never the caller's `now`.
  DeathCause? cause;
  if (health <= 0) {
    if (fullness <= 0) {
      cause = DeathCause.starvation;
    } else if (isSick) {
      cause = DeathCause.illness;
    } else {
      cause = DeathCause.neglect;
    }
  } else if (tickMillis >= expiresAt) {
    cause = DeathCause.oldAge;
  }

  return s.copyWith(
    lastTickAtMillis: tickMillis,
    stage: stage,
    form: form,
    expiresAtMillis: expiresAt,
    fullness: fullness,
    enrichment: enrichment,
    comfort: comfort,
    cleanliness: cleanliness,
    health: health,
    weight: weight,
    isSick: isSick,
    sickSinceTick: sickSinceTick,
    poops: poops,
    pendingPoopTicks: pending,
    needZeroSinceTick: needZeroSinceTick,
    careMistakes: careMistakes,
    stageCareMistakes: stageCareMistakes,
    diedAtMillis: cause == null ? null : tickMillis,
    deathCause: cause,
  );
}

double _clampNeed(double v) {
  if (v < 0) return 0;
  if (v > 100) return 100;
  return v;
}
