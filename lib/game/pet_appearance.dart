import 'package:hog_sim/hog_sim.dart';

import '../sprites/sprite_registry.dart';

/// Turns a pet's state into what the player sees.
///
/// Pure, and deliberately separate from the simulation: `hog_sim` decides what
/// is true about the pig, this decides how the pig looks about it.

/// A need at or below this reads as distress on the pig's face.
const double kSadNeedThreshold = 15.0;

/// Every need above this reads as delight.
const double kHappyNeedThreshold = 70.0;

/// How the pig feels, from what is true about it *right now*.
///
/// **Mood must never read `careMistakes` or `stageCareMistakes`.** Those decide
/// which adult the pig becomes, and the whole design rests on the player never
/// being told. A pig that looks miserable because it is hungry is honest
/// feedback it can act on; a pig that looks miserable because it is tracking
/// toward a runt would hand over the secret the game is built around. The test
/// suite asserts this, because it is the kind of rule that erodes quietly.
PetMood moodFor(PetState pet) {
  if (pet.isSick) return PetMood.sick;

  var lowest = 100.0;
  var highest = 0.0;
  for (final name in kNeedNames) {
    final v = pet.need(name);
    if (v < lowest) lowest = v;
    if (v > highest) highest = v;
  }

  if (lowest <= kSadNeedThreshold) return PetMood.sad;
  if (lowest > kHappyNeedThreshold) return PetMood.happy;
  return PetMood.content;
}

/// What the pig is doing.
///
/// [transient] is set for a few seconds after an action so the player sees the
/// pig respond — feeding it should visibly make it eat, not silently move a
/// number. Sleep wins over nothing else: a pig woken to be fed is eating.
PetPose poseFor(PetState pet, {PetPose? transient, required int nowMillis}) {
  if (transient != null) return transient;
  if (isSleepingAtMillis(nowMillis, pet.utcOffsetMinutes)) {
    return PetPose.sleeping;
  }
  return PetPose.idle;
}

/// Whether the pig is visibly asking for help.
///
/// A need has to have been at rock bottom for a while before the pig starts
/// calling — otherwise the indicator would flicker on every dip and stop
/// meaning anything.
bool isCallingForAttention(PetState pet, {required int nowMillis}) {
  if (pet.isDead || pet.stage == Stage.egg) return false;
  final tick = nowMillis ~/ kTickMillis;
  for (final name in kNeedNames) {
    final since = pet.needZeroSinceTick[name];
    if (since != null && tick - since >= kTicksAtZeroForCalling) return true;
  }
  return false;
}
