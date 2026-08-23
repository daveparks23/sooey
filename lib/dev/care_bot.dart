import 'package:hog_sim/hog_sim.dart';

import '../game/game_controller.dart';
import '../game/screens/crest_screen.dart';
import '../game/screens/death_screen.dart';
import '../game/screens/device_screen.dart';
import '../game/screens/feed_menu.dart';
import '../game/screens/home_screen.dart';
import '../game/screens/truffle_hunt.dart';

/// How many presses the bot may make in one animation frame.
///
/// A frame is 600ms of wall clock. At 3600x that is 36 simulated minutes, in
/// which a piglet loses about 3 fullness and 3 comfort — and feeding is a
/// four-press sequence: cursor to feed, B, cursor to slop, B. At one press a
/// frame the bot spends every frame navigating and still falls behind. Six is
/// far fewer than a human could manage in 36 simulated minutes, so nothing it
/// achieves here is out of a player's reach.
const int kBotPressBudget = 6;

/// One thing the bot is trying to get done.
///
/// Finer than [DeviceIcon] because the feed icon leads to two different
/// choices, and the light is a toggle rather than an action.
enum BotGoal { slop, treat, wallow, play, clean, meds, lightOff, lightOn }

/// The strip icon a goal is reached through.
DeviceIcon iconFor(BotGoal goal) => switch (goal) {
  BotGoal.slop || BotGoal.treat => DeviceIcon.feed,
  BotGoal.wallow => DeviceIcon.wallow,
  BotGoal.play => DeviceIcon.play,
  BotGoal.clean => DeviceIcon.clean,
  BotGoal.meds => DeviceIcon.meds,
  BotGoal.lightOff || BotGoal.lightOn => DeviceIcon.light,
};

/// One press towards [goal], or null when there is nothing to press.
///
/// Pure: it reads the screen and returns a button, exactly as a player looking
/// at the glass would. Nothing here mutates anything.
Button? pressToward(BotGoal goal, DeviceScreen screen) {
  // B on the death screen is Restart. A bot that pressed it would erase the
  // life it was sent to watch, so this case comes first and is unconditional.
  if (screen is DeathScreen) return null;

  // Any crest will do. Which emblem marks the pig is not what we came to see.
  if (screen is CrestScreen) return Button.b;

  if (screen is HomeScreen) {
    return screen.selected == iconFor(goal) ? Button.b : Button.a;
  }
  if (screen is FeedMenu) {
    return screen.treat == (goal == BotGoal.treat) ? Button.b : Button.a;
  }
  if (screen is TruffleHunt) {
    // A guess while the pig is still at a mound resolves a round nobody has
    // seen the answer to, and the screen ignores it anyway.
    return screen.revealing ? null : Button.a;
  }

  // Anything else — stats, or a screen added after this was written — is
  // somewhere the bot did not mean to be. C is the way out of all of them.
  return Button.c;
}

/// Below this a need gets attention. Above `kHealthRecoveryThreshold` (50) by
/// a margin, because a need that is only just clear of the threshold will drop
/// under it again before the bot next comes round.
const double kServiceBelow = 60;

/// What the pig most needs right now, or null when nothing wants doing.
///
/// [neglected] names the needs this run is deliberately letting bottom out;
/// they are skipped entirely. Pure — it reads a pet and returns an intention.
BotGoal? chooseGoal(
  PetState pet, {
  required Set<String> neglected,
  required int nowMillis,
  bool playsHunt = true,
}) {
  // An egg refuses everything but the light, and the light on an egg is not
  // worth the seven presses it takes to reach.
  if (pet.isDead || pet.stage == Stage.egg) return null;

  if (pet.isSick) return BotGoal.meds;

  if (!neglected.contains('cleanliness') &&
      (pet.poops.isNotEmpty || pet.cleanliness < kServiceBelow)) {
    return BotGoal.clean;
  }

  // The lowest need wins, so nothing bottoms out while something less urgent
  // is topped up.
  String? lowest;
  double lowestValue = kServiceBelow;
  void consider(String name, double value) {
    if (neglected.contains(name) || value >= lowestValue) return;
    lowest = name;
    lowestValue = value;
  }

  consider('fullness', pet.fullness);
  consider('enrichment', pet.enrichment);
  consider('comfort', pet.comfort);

  switch (lowest) {
    case 'fullness':
      return BotGoal.slop;
    case 'comfort':
      return BotGoal.wallow;
    case 'enrichment':
      // The hunt is five rounds, one guess per frame, and the bot is stuck on
      // that screen for all five — so it is only affordable when nothing else
      // is near the floor. A treat buys enrichment in a single visit instead.
      final last = pet.lastPlayedAtMillis;
      final cooling = last != null && nowMillis - last < kPlayCooldownMillis;
      final slack = pet.fullness > kServiceBelow &&
          pet.comfort > kServiceBelow &&
          pet.cleanliness > kServiceBelow;
      return playsHunt && slack && !cooling ? BotGoal.play : BotGoal.treat;
  }

  // Nothing needs doing, so keep the pen light honest. Costs nothing and makes
  // the nights visible as they go past.
  final localHour =
      ((nowMillis + pet.utcOffsetMinutes * 60000) ~/ 3600000) % 24;
  final darkOutside =
      localHour >= kSleepStartHour || localHour < kSleepEndHour;
  if (darkOutside && pet.lightsOn) return BotGoal.lightOff;
  if (!darkOutside && !pet.lightsOn) return BotGoal.lightOn;
  return null;
}

/// How well a run intends to treat its pig.
enum CarePreset { attentive, adequate, sloppy }

/// One preset, as numbers.
class CarePlan {
  const CarePlan({
    required this.targetMistakes,
    required this.rescueBelow,
    required this.resumeAbove,
  });

  /// Mistakes to make during childhood. The adult form is decided by this
  /// count at the piglet->adult branch and by nothing else.
  final int targetMistakes;

  /// Health at which a lapse is called off and the pig is rescued.
  final double rescueBelow;

  /// Health at which neglect resumes, if the target is not yet met.
  final double resumeAbove;
}

const Map<CarePreset, CarePlan> kCarePlans = {
  CarePreset.attentive:
      CarePlan(targetMistakes: 0, rescueBelow: 100, resumeAbove: 100),
  CarePreset.adequate:
      CarePlan(targetMistakes: 4, rescueBelow: 45, resumeAbove: 60),
  CarePreset.sloppy:
      CarePlan(targetMistakes: 7, rescueBelow: 35, resumeAbove: 60),
};

/// The two needs a lapse is allowed to bottom out.
///
/// Comfort and cleanliness are held above the recovery threshold at all times.
/// They are the two that can only be restored to 100 — wallow and clean take
/// no smaller step — so zeroing them buys a long redrain, and with four needs
/// at zero the mistakes arrive four at a time and a target overshoots out of
/// its band. Two needs means an overshoot of at most one.
const Set<String> kLapseNeeds = {'fullness', 'enrichment'};

/// Plays a pig unattended, one button press at a time.
///
/// Deliberately knows nothing about widgets: it reads a [GameController] and
/// returns a button, which is what lets a whole life run in a test with no
/// widget tree in play.
class CareBot {
  CareBot(this.preset, {this.playsHunt = true});

  final CarePreset preset;

  /// False makes the bot use treats instead of the truffle hunt. The hunt
  /// draws from `dart:math`'s Random, so a run that plays it is not
  /// reproducible; the full-life tests turn it off for that reason.
  final bool playsHunt;

  bool _lapsing = true;
  bool _neglecting = false;

  /// Whether the bot is currently letting needs bottom out. For the readout.
  bool get neglecting => _neglecting;

  /// Which needs the run is deliberately ignoring at this moment.
  Set<String> neglectedFor(PetState pet) {
    final plan = kCarePlans[preset]!;
    // Only childhood decides the form, and only mistakes short of the target
    // are wanted. Everything else is attentive care.
    if (pet.stage != Stage.piglet || pet.careMistakes >= plan.targetMistakes) {
      _neglecting = false;
      return const {};
    }
    if (_lapsing && pet.health <= plan.rescueBelow) _lapsing = false;
    if (!_lapsing && pet.health >= plan.resumeAbove) _lapsing = true;
    _neglecting = _lapsing;
    return _lapsing ? kLapseNeeds : const {};
  }

  /// One press, or null when there is nothing worth pressing this frame.
  Button? nextPress(GameController controller) {
    final screen = controller.screen;
    if (screen is DeathScreen) return null;
    if (screen is CrestScreen) return Button.b;

    final goal = chooseGoal(
      controller.pet,
      neglected: neglectedFor(controller.pet),
      nowMillis: controller.context.nowMillis,
      playsHunt: playsHunt,
    );
    // Nothing to do: rest on home, and back out of anywhere else so the next
    // frame starts from a known screen.
    if (goal == null) return screen is HomeScreen ? null : Button.c;
    return pressToward(goal, screen);
  }
}
