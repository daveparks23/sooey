import 'package:hog_sim/hog_sim.dart';

import '../game/screens/device_screen.dart';
import '../lcd/lcd_sprite.dart';

/// The mark that makes one pig yours, and the ribbon it earns.
///
/// All 7x7 — the same grid as the strip icons. One scale across the whole
/// device is what keeps a crest, an icon and a rosette looking like parts of
/// the same object rather than three borrowed pictures. The death screen's
/// gutter is the binding constraint: centred, a 16-wide grave leaves eight
/// columns either side.

const kCrestLeaf = LcdSprite(7, 7, [
  '......#',
  '.....##',
  '..####.',
  '.#####.',
  '#####..',
  '.###...',
  '#......',
]);

const kCrestStar = LcdSprite(7, 7, [
  '...#...',
  '...#...',
  '#######',
  '.#####.',
  '..###..',
  '.##.##.',
  '##...##',
]);

const kCrestHorseshoe = LcdSprite(7, 7, [
  '.#####.',
  '##...##',
  '##...##',
  '##...##',
  '##...##',
  '#.....#',
  '#.....#',
]);

const kCrestClover = LcdSprite(7, 7, [
  '.##.##.',
  '#######',
  '#######',
  '.#####.',
  '..###..',
  '...#...',
  '...#...',
]);

const kCrestCrown = LcdSprite(7, 7, [
  '#..#..#',
  '#.###.#',
  '#######',
  '#######',
  '#######',
  '#######',
  '.......',
]);

const kCrestMoon = LcdSprite(7, 7, [
  '..###..',
  '.##....',
  '###....',
  '###....',
  '###....',
  '.##....',
  '..###..',
]);

const kCrestAnchor = LcdSprite(7, 7, [
  '...#...',
  '..###..',
  '...#...',
  '.#####.',
  '#..#..#',
  '#..#..#',
  '.#####.',
]);

const kCrestBolt = LcdSprite(7, 7, [
  '....##.',
  '...##..',
  '..###..',
  '.#####.',
  '..##...',
  '.##....',
  '##.....',
]);

const Map<Crest, LcdSprite> kCrests = {
  Crest.leaf: kCrestLeaf,
  Crest.star: kCrestStar,
  Crest.horseshoe: kCrestHorseshoe,
  Crest.clover: kCrestClover,
  Crest.crown: kCrestCrown,
  Crest.moon: kCrestMoon,
  Crest.anchor: kCrestAnchor,
  Crest.bolt: kCrestBolt,
};

/// The prize hog's ribbon: a full rosette with streamers.
const kPrizeRosette = LcdSprite(7, 7, [
  '..###..',
  '.#####.',
  '##.#.##',
  '.#####.',
  '..###..',
  '.##.##.',
  '##...##',
]);

/// The farm hog's: a plain ribbon.
const kFarmRosette = LcdSprite(7, 7, [
  '..###..',
  '.#####.',
  '..###..',
  '...#...',
  '...#...',
  '..#.#..',
  '..#.#..',
]);

/// The runt's: a bare button, no ribbon at all.
const kRuntRosette = LcdSprite(7, 7, [
  '.......',
  '..###..',
  '.#####.',
  '.#####.',
  '..###..',
  '.......',
  '.......',
]);

const Map<Form, LcdSprite> kRosettes = {
  Form.prizeHog: kPrizeRosette,
  Form.farmHog: kFarmRosette,
  Form.runt: kRuntRosette,
};

/// The ribbon for an adult build.
///
/// `base` never reaches adulthood — the form is fixed at the piglet->adult
/// transition — but a pet seeded mid-development might, so it falls back to the
/// reference build rather than crashing the stats page.
LcdSprite rosetteFor(Form form) => kRosettes[form] ?? kFarmRosette;
