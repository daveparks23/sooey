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

/// The grave.
///
/// RIP is punched clean through the stone rather than carved onto it, matching
/// how eyes are handled everywhere else in the cast.
///
/// 16 wide because the lettering sets the floor: three 3-wide glyphs with gaps
/// between them needs eleven columns, and the stone has to keep a solid margin
/// either side or the letters break its outline and it stops reading as a slab.
/// At this size an R and an A are the same shape — it is the company of the I
/// and the P that makes it a word.
const kGrave = LcdSprite(16, 12, [
  '......#####......',
  '...###########...',
  '..#############..',
  '..#############..',
  '.##...##.##...##',
  '.##.#.##.##.#.##.',
  '.##..###.##...##.',
  '.##.#.##.##.####.',
  '.##.#.##.##.####.',
  '.###############.',
  '.###############.',
  '#################',
  '#################',
  '#################',
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

/// A mound of earth with a truffle under it. Two of these are the whole set
/// dressing of the truffle hunt.
///
/// Note the transparent surround: a mound is composited over the pig after the
/// pig is drawn, so it must not punch a hole in the ground around itself.
const kMound = LcdSprite(5, 3, [' .#. ', '.###.', '#####']);
