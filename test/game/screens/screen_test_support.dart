import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/dev/reference_clock.dart' show kRefNoon;
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/sprites/sprite_registry.dart';

export 'package:sooey/dev/reference_clock.dart' show kRefNoon;

// kRefNoon (noon UTC) lives in lib/dev/reference_clock.dart — the /dev/life
// page pins its clock to the same value, so this is one number shared by the
// page and every test that wants it, not two that can drift apart. The pig
// sleeps from 22:00 to 07:00 in its own local time, so a test that wants a
// waking pig starts here.

/// A pet with no history, posed however the test needs it.
PetState testPet({
  Stage stage = Stage.adult,
  Form form = Form.farmHog,
  double fullness = 80,
  double enrichment = 80,
  double comfort = 80,
  double cleanliness = 80,
  double health = 80,
  double weight = 70,
  bool isSick = false,
  bool lightsOn = true,
  int poops = 0,
  int nowMillis = kRefNoon,
  int ageDays = 7,
  DeathCause? deathCause,
}) {
  var pet =
      PetState.newborn(
        petId: 'pet_test',
        ownerId: 'uid_test',
        name: '',
        nowMillis: nowMillis - ageDays * 86400000,
        utcOffsetMinutes: 0,
      ).copyWith(
        stage: stage,
        form: form,
        lastTickAtMillis: nowMillis,
        fullness: fullness,
        enrichment: enrichment,
        comfort: comfort,
        cleanliness: cleanliness,
        health: health,
        weight: weight,
        isSick: isSick,
        lightsOn: lightsOn,
        poops: List.generate(poops, (i) => i),
      );
  if (deathCause != null) {
    pet = pet.copyWith(diedAtMillis: nowMillis, deathCause: deathCause);
  }
  return pet;
}

GameContext testContext({
  PetState? pet,
  Crest crest = Crest.leaf,
  int nowMillis = kRefNoon,
  PetPose? transientPose,
}) => GameContext(
  pet: pet ?? testPet(nowMillis: nowMillis),
  crest: crest,
  nowMillis: nowMillis,
  transientPose: transientPose,
);

/// Drives a screen with a string of presses and collects what it asked for.
///
/// This is the whole reason screens do not touch the pet: a press sequence is a
/// test, with no controller, no clock and no simulation in play.
List<Transition> drive(DeviceScreen screen, String presses, GameContext ctx) {
  const buttons = {'A': Button.a, 'B': Button.b, 'C': Button.c};
  return [
    for (final ch in presses.split(''))
      screen.handle(
        buttons[ch] ?? (throw ArgumentError('not a button: $ch')),
        ctx,
      ),
  ];
}
