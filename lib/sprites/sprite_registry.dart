import 'package:hog_sim/hog_sim.dart';

import '../lcd/lcd_sprite.dart';
import 'adult_sprites.dart';
import 'draft_extra_sprites.dart';
import 'draft_face_sprites.dart';
import 'draft_piglet_face_sprites.dart';
import 'piglet_sprites.dart';
import 'prop_sprites.dart';
import 'wallow_sprites.dart';

export 'adult_sprites.dart';
export 'draft_extra_sprites.dart';
export 'draft_face_sprites.dart';
export 'draft_piglet_face_sprites.dart';
export 'piglet_sprites.dart';
export 'prop_sprites.dart';
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
  const SpriteAnim(this.a, this.b, {this.dartName, this.sourceFile});

  /// A still pose, for icons and props that do not move.
  const SpriteAnim.still(LcdSprite frame, {this.dartName, this.sourceFile})
    : a = frame,
      b = frame;

  final LcdSprite a;
  final LcdSprite b;

  /// Base name of the Dart constants behind this animation — `kRuntEat` for
  /// `kRuntEat1` and `kRuntEat2`.
  ///
  /// Exists so the sprite editor can emit code you can paste straight over the
  /// existing literal. Naming the constant after the registry key instead would
  /// produce `runt.eating1`, which is not a valid identifier.
  final String? dartName;

  /// Where those constants live, so the editor can tell you where to paste.
  final String? sourceFile;

  /// Alternates on even/odd frame counts.
  LcdSprite frame(int counter) => counter.isEven ? a : b;

  bool get isStill => identical(a, b);
}

/// What the pig is visibly doing, as opposed to what its stats say.
enum PetPose { idle, eating, sleeping, wallowing }

/// Every animation in the game, by name. Powers the sprite editor's load menu
/// and the test that validates the whole cast.
const _piglets = 'lib/sprites/piglet_sprites.dart';
const _adults = 'lib/sprites/adult_sprites.dart';
const _wallows = 'lib/sprites/wallow_sprites.dart';
const _props = 'lib/sprites/prop_sprites.dart';
const _draft = 'lib/sprites/draft_face_sprites.dart';
const _draftExtra = 'lib/sprites/draft_extra_sprites.dart';
const _draftPiglet = 'lib/sprites/draft_piglet_face_sprites.dart';

const Map<String, SpriteAnim> kSpriteRegistry = {
  'egg': SpriteAnim(kEgg1, kEgg2, dartName: 'kEgg', sourceFile: _props),

  'piglet.idle': SpriteAnim(
    kPigletIdle1,
    kPigletIdle2,
    dartName: 'kPigletIdle',
    sourceFile: _piglets,
  ),
  'piglet.eating': SpriteAnim(
    kPigletEat1,
    kPigletEat2,
    dartName: 'kPigletEat',
    sourceFile: _piglets,
  ),
  'piglet.sleeping': SpriteAnim(
    kPigletSleep1,
    kPigletSleep2,
    dartName: 'kPigletSleep',
    sourceFile: _piglets,
  ),
  'piglet.wallowing': SpriteAnim(
    kPigletWallow1,
    kPigletWallow2,
    dartName: 'kPigletWallow',
    sourceFile: _wallows,
  ),

  'farmHog.idle': SpriteAnim(
    kFarmHogIdle1,
    kFarmHogIdle2,
    dartName: 'kFarmHogIdle',
    sourceFile: _adults,
  ),
  'farmHog.eating': SpriteAnim(
    kFarmHogEat1,
    kFarmHogEat2,
    dartName: 'kFarmHogEat',
    sourceFile: _adults,
  ),
  'farmHog.sleeping': SpriteAnim(
    kFarmHogSleep1,
    kFarmHogSleep2,
    dartName: 'kFarmHogSleep',
    sourceFile: _adults,
  ),

  'prizeHog.idle': SpriteAnim(
    kPrizeHogIdle1,
    kPrizeHogIdle2,
    dartName: 'kPrizeHogIdle',
    sourceFile: _adults,
  ),
  'prizeHog.eating': SpriteAnim(
    kPrizeHogEat1,
    kPrizeHogEat2,
    dartName: 'kPrizeHogEat',
    sourceFile: _adults,
  ),
  'prizeHog.sleeping': SpriteAnim(
    kPrizeHogSleep1,
    kPrizeHogSleep2,
    dartName: 'kPrizeHogSleep',
    sourceFile: _adults,
  ),

  'runt.idle': SpriteAnim(
    kRuntIdle1,
    kRuntIdle2,
    dartName: 'kRuntIdle',
    sourceFile: _adults,
  ),
  'runt.eating': SpriteAnim(
    kRuntEat1,
    kRuntEat2,
    dartName: 'kRuntEat',
    sourceFile: _adults,
  ),
  'runt.sleeping': SpriteAnim(
    kRuntSleep1,
    kRuntSleep2,
    dartName: 'kRuntSleep',
    sourceFile: _adults,
  ),

  'adult.wallowing': SpriteAnim(
    kAdultWallow1,
    kAdultWallow2,
    dartName: 'kAdultWallow',
    sourceFile: _wallows,
  ),

  'prop.poop': SpriteAnim.still(kPoop, dartName: 'kPoop', sourceFile: _props),
  'prop.heart': SpriteAnim.still(
    kHeart,
    dartName: 'kHeart',
    sourceFile: _props,
  ),
  'prop.sick': SpriteAnim.still(
    kSickIcon,
    dartName: 'kSickIcon',
    sourceFile: _props,
  ),
  'prop.call': SpriteAnim.still(
    kCallIcon,
    dartName: 'kCallIcon',
    sourceFile: _props,
  ),
  'prop.lightOff': SpriteAnim.still(
    kLightOffIcon,
    dartName: 'kLightOffIcon',
    sourceFile: _props,
  ),
  'prop.grave': SpriteAnim.still(
    kGrave,
    dartName: 'kGrave',
    sourceFile: _props,
  ),
  'prop.skull': SpriteAnim.still(
    kSkull,
    dartName: 'kSkull',
    sourceFile: _props,
  ),

  // Draft: the front-facing outlined direction. Not used by the game — these
  // exist so the gallery can show them beside the current cast.
  'draft.adult.idle': SpriteAnim(
    kFaceIdle1,
    kFaceIdle2,
    dartName: 'kFaceIdle',
    sourceFile: _draft,
  ),
  'draft.adult.happy': SpriteAnim(
    kFaceHappy1,
    kFaceHappy2,
    dartName: 'kFaceHappy',
    sourceFile: _draft,
  ),
  'draft.adult.sad': SpriteAnim(
    kFaceSad1,
    kFaceSad2,
    dartName: 'kFaceSad',
    sourceFile: _draft,
  ),
  'draft.adult.eating': SpriteAnim(
    kFaceEat1,
    kFaceEat2,
    dartName: 'kFaceEat',
    sourceFile: _draft,
  ),
  'draft.adult.sleeping': SpriteAnim(
    kFaceSleep1,
    kFaceSleep2,
    dartName: 'kFaceSleep',
    sourceFile: _draft,
  ),
  'draft.adult.sick': SpriteAnim(
    kFaceSick1,
    kFaceSick2,
    dartName: 'kFaceSick',
    sourceFile: _draft,
  ),

  'draft.piglet.idle': SpriteAnim(
    kPigletFaceIdle1,
    kPigletFaceIdle2,
    dartName: 'kPigletFaceIdle',
    sourceFile: _draftPiglet,
  ),
  'draft.piglet.happy': SpriteAnim(
    kPigletFaceHappy1,
    kPigletFaceHappy2,
    dartName: 'kPigletFaceHappy',
    sourceFile: _draftPiglet,
  ),
  'draft.piglet.sad': SpriteAnim(
    kPigletFaceSad1,
    kPigletFaceSad2,
    dartName: 'kPigletFaceSad',
    sourceFile: _draftPiglet,
  ),
  'draft.piglet.eating': SpriteAnim(
    kPigletFaceEat1,
    kPigletFaceEat2,
    dartName: 'kPigletFaceEat',
    sourceFile: _draftPiglet,
  ),
  'draft.piglet.sleeping': SpriteAnim(
    kPigletFaceSleep1,
    kPigletFaceSleep2,
    dartName: 'kPigletFaceSleep',
    sourceFile: _draftPiglet,
  ),
  'draft.piglet.sick': SpriteAnim(
    kPigletFaceSick1,
    kPigletFaceSick2,
    dartName: 'kPigletFaceSick',
    sourceFile: _draftPiglet,
  ),

  'draft.prizeHog.idle': SpriteAnim(
    kPrizeFaceIdle1,
    kPrizeFaceIdle2,
    dartName: 'kPrizeFaceIdle',
    sourceFile: _draftExtra,
  ),
  'draft.runt.idle': SpriteAnim(
    kRuntFaceIdle1,
    kRuntFaceIdle2,
    dartName: 'kRuntFaceIdle',
    sourceFile: _draftExtra,
  ),
  'draft.adult.wallowing': SpriteAnim(
    kAdultFaceWallow1,
    kAdultFaceWallow2,
    dartName: 'kAdultFaceWallow',
    sourceFile: _draftExtra,
  ),
  'draft.piglet.wallowing': SpriteAnim(
    kPigletFaceWallow1,
    kPigletFaceWallow2,
    dartName: 'kPigletFaceWallow',
    sourceFile: _draftExtra,
  ),
  'draft.egg': SpriteAnim(
    kEggOutline1,
    kEggOutline2,
    dartName: 'kEggOutline',
    sourceFile: _draftExtra,
  ),
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
      _ => 'adult.wallowing',
    };
    return kSpriteRegistry[key]!;
  }

  final who = switch (stage) {
    Stage.piglet => 'piglet',
    // `base` should never reach adulthood — the form is fixed at the
    // piglet->adult transition — but a pet seeded mid-development might, so
    // fall back to the reference build rather than crashing.
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
