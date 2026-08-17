import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_buffer.dart';
import '../frame_composer.dart';
import 'device_screen.dart';
import 'feed_menu.dart';
import 'stats_screen.dart';
import 'truffle_hunt.dart';

/// The device at rest: the pig on the matrix, the strip live around it.
///
/// The root of the stack and the only screen the player can reach without
/// having chosen something first. It has no egg or hatch special case —
/// `creatureAnim` already returns the egg for `Stage.egg`, and `applyAction`
/// already refuses everything but the light until it hatches, so the first
/// fifteen minutes of a pig's life need no code of their own.
class HomeScreen extends DeviceScreen {
  /// Null means the cursor is parked and the pig is unframed. A device sitting
  /// on the shelf should not look like a menu.
  DeviceIcon? selected;

  @override
  DeviceIcon? get litIcon => selected;

  @override
  Transition handle(Button b, GameContext ctx) {
    switch (b) {
      case Button.a:
        selected = _next(selected);
        return const Stay();

      case Button.b:
        final icon = selected;
        if (icon == null) return const Stay();
        return switch (icon) {
          DeviceIcon.feed => Push(FeedMenu()),
          DeviceIcon.play => Push(TruffleHunt()),
          DeviceIcon.stats => Push(StatsScreen()),
          DeviceIcon.wallow => const Act(PetAction.wallow),
          DeviceIcon.clean => const Act(PetAction.clean),
          DeviceIcon.meds => const Act(PetAction.meds),
          DeviceIcon.light => const Act(PetAction.light),
        };

      // Nothing to pop to from the root, so C parks the cursor instead.
      case Button.c:
        selected = null;
        return const Stay();
    }
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) => composeFrame(
    ctx.pet,
    frame: frame,
    nowMillis: ctx.nowMillis,
    transientPose: ctx.transientPose,
  );
}

/// Cycles the cursor, starting it at the first icon from parked.
DeviceIcon _next(DeviceIcon? current) => current == null
    ? DeviceIcon.values.first
    : DeviceIcon.values[(current.index + 1) % DeviceIcon.values.length];
