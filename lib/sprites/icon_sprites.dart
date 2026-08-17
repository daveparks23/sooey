import '../game/screens/device_screen.dart';
import '../lcd/lcd_sprite.dart';

/// The icons on the bezel.
///
/// All 7x7, because the strip is a four-column grid and a ragged one would read
/// as a jumble rather than a row of fixed segments. Unlike the props these are
/// opaque — an icon sits on bare glass, so there is nothing underneath for a
/// transparent cell to reveal.

/// Feed. A trough, seen end-on. Doubles as slop in the feed submenu.
const kFeedIcon = LcdSprite(7, 7, [
  '.......',
  '#.....#',
  '#######',
  '.#####.',
  '.#####.',
  '..###..',
  '.......',
]);

/// Wallow. A puddle with something splashing out of it.
const kWallowIcon = LcdSprite(7, 7, [
  '.......',
  '..#.#..',
  '.#...#.',
  '#######',
  '.#####.',
  '..###..',
  '.......',
]);

/// Play. The truffle the hunt is for.
const kPlayIcon = LcdSprite(7, 7, [
  '..###..',
  '.#####.',
  '#######',
  '#######',
  '#######',
  '.#####.',
  '..###..',
]);

/// Meds. A cross — the only shape that survives being this small and still
/// means medicine.
const kMedsIcon = LcdSprite(7, 7, [
  '..###..',
  '..###..',
  '#######',
  '#######',
  '#######',
  '..###..',
  '..###..',
]);

/// Clean. A yard brush on the diagonal.
const kCleanIcon = LcdSprite(7, 7, [
  '....##.',
  '...##..',
  '..##...',
  '.####..',
  '#####..',
  '#####..',
  '.......',
]);

/// Stats. A rising bar chart, which is what the screen behind it is.
const kStatsIcon = LcdSprite(7, 7, [
  '.......',
  '.....#.',
  '....##.',
  '...###.',
  '..####.',
  '.#####.',
  '#######',
]);

/// Light. A sun with rays, rather than a bulb — a bulb at 7x7 is a blob.
const kLightIcon = LcdSprite(7, 7, [
  '...#...',
  '.#...#.',
  '..###..',
  '#.###.#',
  '..###..',
  '.#...#.',
  '...#...',
]);

/// Treat. Spec §7.1 names it an apple, so it is one. Only ever seen in the feed
/// submenu, beside [kFeedIcon] standing in for slop.
const kTreatIcon = LcdSprite(7, 7, [
  '...#...',
  '..##...',
  '.#####.',
  '#######',
  '#######',
  '.#####.',
  '..###..',
]);

/// Weight, on the second stats page. A balance.
const kWeightIcon = LcdSprite(7, 7, [
  '...#...',
  '.#####.',
  '#..#..#',
  '...#...',
  '...#...',
  '..###..',
  '.#####.',
]);

/// Every strip icon by the cursor position that reaches it.
const Map<DeviceIcon, LcdSprite> kDeviceIcons = {
  DeviceIcon.feed: kFeedIcon,
  DeviceIcon.wallow: kWallowIcon,
  DeviceIcon.play: kPlayIcon,
  DeviceIcon.meds: kMedsIcon,
  DeviceIcon.clean: kCleanIcon,
  DeviceIcon.stats: kStatsIcon,
  DeviceIcon.light: kLightIcon,
};
