import 'package:hog_sim/hog_sim.dart';

import '../lcd/lcd_sprite.dart';
import 'adult_sprites.dart';
import 'piglet_sprites.dart';
import 'prop_sprites.dart';
import 'shoat_sprites.dart';
import 'wallow_sprites.dart';

export 'adult_sprites.dart';
export 'piglet_sprites.dart';
export 'prop_sprites.dart';
export 'shoat_sprites.dart';
export 'wallow_sprites.dart';

/// How long each frame of a two-frame animation holds.
///
/// Not polish. At 32x16 there is almost no room for expressive detail, so
/// motion carries the entire emotional read: a pig that shifts its weight looks
/// alive, and a static one looks like a rendering bug.
const int kAnimFrameMillis = 600;

/// A two-frame animation. Every creature state has exactly two frames — enough
/// for a convincing bob, few enough to hand-author the whole cast.
class SpriteAnim {
  const SpriteAnim(this.a, this.b);

  /// A still pose, for icons and props that do not move.
  const SpriteAnim.still(LcdSprite frame) : a = frame, b = frame;

  final LcdSprite a;
  final LcdSprite b;

  /// Alternates on even/odd frame counts.
  LcdSprite frame(int counter) => counter.isEven ? a : b;

  bool get isStill => identical(a, b);
}

/// What the pig is visibly doing, as opposed to what its stats say.
enum PetPose { idle, eating, sleeping, wallowing }

/// Every animation in the game, by name. Powers the sprite editor's load menu
/// and the test that validates the whole cast.
const Map<String, SpriteAnim> kSpriteRegistry = {
  'egg': SpriteAnim(kEgg1, kEgg2),

  'piglet.idle': SpriteAnim(kPigletIdle1, kPigletIdle2),
  'piglet.eating': SpriteAnim(kPigletEat1, kPigletEat2),
  'piglet.sleeping': SpriteAnim(kPigletSleep1, kPigletSleep2),
  'piglet.wallowing': SpriteAnim(kPigletWallow1, kPigletWallow2),

  'shoat.idle': SpriteAnim(kShoatIdle1, kShoatIdle2),
  'shoat.eating': SpriteAnim(kShoatEat1, kShoatEat2),
  'shoat.sleeping': SpriteAnim(kShoatSleep1, kShoatSleep2),
  'shoat.wallowing': SpriteAnim(kShoatWallow1, kShoatWallow2),

  'farmHog.idle': SpriteAnim(kFarmHogIdle1, kFarmHogIdle2),
  'farmHog.eating': SpriteAnim(kFarmHogEat1, kFarmHogEat2),
  'farmHog.sleeping': SpriteAnim(kFarmHogSleep1, kFarmHogSleep2),

  'prizeHog.idle': SpriteAnim(kPrizeHogIdle1, kPrizeHogIdle2),
  'prizeHog.eating': SpriteAnim(kPrizeHogEat1, kPrizeHogEat2),
  'prizeHog.sleeping': SpriteAnim(kPrizeHogSleep1, kPrizeHogSleep2),

  'runt.idle': SpriteAnim(kRuntIdle1, kRuntIdle2),
  'runt.eating': SpriteAnim(kRuntEat1, kRuntEat2),
  'runt.sleeping': SpriteAnim(kRuntSleep1, kRuntSleep2),

  'adult.wallowing': SpriteAnim(kAdultWallow1, kAdultWallow2),

  'prop.poop': SpriteAnim.still(kPoop),
  'prop.heart': SpriteAnim.still(kHeart),
  'prop.sick': SpriteAnim.still(kSickIcon),
  'prop.call': SpriteAnim.still(kCallIcon),
  'prop.lightOff': SpriteAnim.still(kLightOffIcon),
  'prop.grave': SpriteAnim.still(kGrave),
  'prop.skull': SpriteAnim.still(kSkull),
};

/// The creature animation for a given stage, form and pose.
///
/// The three adult forms share one wallowing pose: below the mud line there is
/// nothing left to tell them apart.
SpriteAnim creatureAnim({
  required Stage stage,
  required Form form,
  required PetPose pose,
}) {
  if (stage == Stage.egg) return kSpriteRegistry['egg']!;

  if (pose == PetPose.wallowing) {
    final key = switch (stage) {
      Stage.piglet => 'piglet.wallowing',
      Stage.shoat => 'shoat.wallowing',
      _ => 'adult.wallowing',
    };
    return kSpriteRegistry[key]!;
  }

  final who = switch (stage) {
    Stage.piglet => 'piglet',
    Stage.shoat => 'shoat',
    // `base` should never reach adulthood — the form is fixed at the
    // shoat->adult transition — but a pet seeded mid-development might, so fall
    // back to the reference build rather than crashing.
    Stage.adult => form == Form.base ? 'farmHog' : form.name,
    Stage.egg => 'egg',
  };

  final poseName = switch (pose) {
    PetPose.idle => 'idle',
    PetPose.eating => 'eating',
    PetPose.sleeping => 'sleeping',
    PetPose.wallowing => 'idle',
  };

  return kSpriteRegistry['$who.$poseName'] ?? kSpriteRegistry['$who.idle']!;
}
