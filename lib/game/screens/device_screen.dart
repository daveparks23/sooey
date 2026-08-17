import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_buffer.dart';
import '../../sprites/sprite_registry.dart';

/// The device's three physical buttons. There are no others, and nothing on the
/// glass or the shell responds to a tap — spec §6 calls that constraint the
/// charm and it is taken literally.
enum Button { a, b, c }

/// The strip icons, in the order A cycles through them.
///
/// The strip's layout is derived from this order: the first four sit above the
/// matrix and the rest below. `train` is absent — D2 cut the discipline
/// mechanic from v1.
enum DeviceIcon { feed, wallow, play, meds, clean, stats, light }

/// The emblem that marks one pig.
///
/// This is what the spec's name became. The 1996 original never let you name a
/// pet, and a twelve-slot letter picker is the worst screen a three-button
/// device can have. A crest does the same job — it makes the pig yours, and it
/// is what ends up beside the grave.
enum Crest { leaf, star, horseshoe, clover, crown, moon, anchor, bolt }

/// Everything a screen is allowed to know.
///
/// Read-only by construction. Screens decide what a press *means*; the
/// controller decides what it *does*. That split is what lets a screen be
/// tested with a string of presses and nothing else.
class GameContext {
  const GameContext({
    required this.pet,
    required this.crest,
    required this.nowMillis,
    this.transientPose,
  });

  final PetState pet;
  final Crest crest;
  final int nowMillis;

  /// Set for a few seconds after an accepted action, so the pig visibly
  /// responds to it.
  final PetPose? transientPose;
}

/// What a screen wants to happen next.
///
/// Sealed, so the controller's switch over it is checked by the compiler — a
/// new transition cannot be added without every handler being made to consider
/// it.
sealed class Transition {
  const Transition();
}

class Stay extends Transition {
  const Stay();
}

class Push extends Transition {
  const Push(this.screen);
  final DeviceScreen screen;
}

class Pop extends Transition {
  const Pop();
}

/// Apply an action to the pet, then leave the screen that asked for it.
class Act extends Transition {
  const Act(this.action);
  final PetAction action;
}

/// A finished truffle hunt, for `applyMinigame` to validate.
class Played extends Transition {
  const Played(this.wins);
  final int wins;
}

/// The crest is chosen and the pig's life begins.
class Crested extends Transition {
  const Crested(this.crest);
  final Crest crest;
}

/// Start over with a new pet, from the death screen.
class Restart extends Transition {
  const Restart();
}

/// One screen of the device.
///
/// Not `sealed`: Dart only allows that when every subtype is in the same
/// library, and the point of this structure is that each screen is its own
/// small file. Nothing switches over screen types, so sealing would buy
/// nothing.
abstract class DeviceScreen {
  /// Turns a press into an intent. Never touches the pet.
  Transition handle(Button b, GameContext ctx);

  /// Draws the matrix. Pure — no clock reads, no state changes.
  LcdBuffer compose(GameContext ctx, int frame);

  /// Called once per animation frame, before [compose], for screens whose state
  /// moves without a press.
  ///
  /// Only the truffle hunt overrides this: its reveal has to end on its own.
  /// Doing that inside [compose] would put a mutation in a render path and
  /// every other screen would inherit the hazard.
  Transition update(GameContext ctx) => const Stay();

  /// Which strip icon stays lit while this screen is on top, or null for the
  /// screens that are not reached from the strip at all.
  DeviceIcon? get litIcon;
}
