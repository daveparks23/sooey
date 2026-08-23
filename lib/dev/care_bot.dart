import '../game/screens/crest_screen.dart';
import '../game/screens/death_screen.dart';
import '../game/screens/device_screen.dart';
import '../game/screens/feed_menu.dart';
import '../game/screens/home_screen.dart';
import '../game/screens/truffle_hunt.dart';

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
