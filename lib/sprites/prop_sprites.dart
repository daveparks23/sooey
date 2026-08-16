import '../lcd/lcd_sprite.dart';

/// Everything that is not the pig.
///
/// These are small and composited over the creature, which is the entire reason
/// the sprite alphabet has a transparent state — a status icon must sit on top
/// of the pig without punching a hole through it. Note the leading spaces: they
/// are transparent cells, not padding, and deleting them would blank the pig
/// underneath.

/// Poop. Static — a poop that animated would be doing too much.
const kPoop = LcdSprite(4, 4, ['  # ', ' ###', '####', '####']);

/// Celebration, shown briefly after a good round of truffle hunt.
const kHeart = LcdSprite(5, 5, [' # # ', '#####', '#####', ' ### ', '  #  ']);

/// Sickness. A skull rather than a cross, because the pig is not in hospital —
/// it is in trouble.
///
/// This wants to be smaller and cannot be: at 5x5 a skull is an indistinct
/// blob, and the eye sockets — the only thing that makes it read as a skull —
/// need a solid row above and below them to sit in.
const kSickIcon = LcdSprite(7, 6, [
  ' ##### ',
  '#######',
  '#.###.#',
  '#.###.#',
  '#######',
  ' #.#.# ',
]);

/// The attention indicator. Blinks above a pig whose need has bottomed out.
const kCallIcon = LcdSprite(2, 5, ['##', '##', '##', '  ', '##']);

/// The pen light, off. Drawn in a corner so the player can see the light is out
/// even when the pig is asleep and barely visible.
const kLightOffIcon = LcdSprite(3, 3, ['#.#', '.#.', '#.#']);

/// The grave. A cross is punched clean through the stone rather than drawn on
/// it, matching how eyes are handled everywhere else.
///
/// Sized 14 wide for one reason: the cross arms need at least three columns of
/// stone left either side of them. At 12 wide only one column survived, the
/// slab read as cut in half, and the whole thing looked like an archway rather
/// than a headstone.
const kGrave = LcdSprite(14, 12, [
  '....######....',
  '..##########..',
  '.############.',
  '.#####..#####.',
  '.###......###.',
  '.###......###.',
  '.#####..#####.',
  '.#####..#####.',
  '.#####..#####.',
  '.############.',
  '.############.',
  '##############',
]);

/// Shown on the death screen above the grave.
const kSkull = LcdSprite(7, 6, [
  '.#####.',
  '#######',
  '#.###.#',
  '#.###.#',
  '#######',
  '.#.#.#.',
]);

/// The egg, before it hatches. Two frames of a wobble — the only thing an egg
/// can do to look alive.
const kEgg1 = LcdSprite(32, 16, [
  '................................',
  '................................',
  '................................',
  '..............####..............',
  '............########............',
  '...........##########...........',
  '..........############..........',
  '..........############..........',
  '.........##############.........',
  '.........##############.........',
  '.........##############.........',
  '..........############..........',
  '...........##########...........',
  '............########............',
  '................................',
  '................................',
]);

const kEgg2 = LcdSprite(32, 16, [
  '................................',
  '................................',
  '................................',
  '...............####.............',
  '.............########...........',
  '............##########..........',
  '...........############.........',
  '...........############.........',
  '..........##############........',
  '..........##############........',
  '..........##############........',
  '...........############.........',
  '............##########..........',
  '.............########...........',
  '................................',
  '................................',
]);
