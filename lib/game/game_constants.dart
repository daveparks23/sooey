/// Tunables for how the device presents itself. The simulation's numbers all
/// live in `hog_sim`'s `constants.dart`; these are about feel, not balance, and
/// none of them may reach the simulation.
library;

/// How long the pig holds an action's pose after the player triggers it.
///
/// Long enough to notice, short enough that it is clearly a reaction rather
/// than a state — feeding the pig should visibly make it eat, not silently move
/// a number.
const int kTransientPoseMillis = 3000;

/// How long a refused action blinks the icon that refused it.
///
/// Refusals blink an icon rather than changing the pig's face. The face reads
/// current needs only and has to stay honest: a pig that looked miserable
/// because a button did nothing would be lying about how it feels.
const int kRefusalBlinkMillis = 1800;

/// How long the pig stays at the mound before the next truffle-hunt round.
const int kHuntRevealMillis = 1500;

/// How far the pig moves when it commits to a mound, in dots.
const int kHuntSlide = 9;
