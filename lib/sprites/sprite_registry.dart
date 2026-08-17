import 'package:hog_sim/hog_sim.dart';

import '../lcd/lcd_sprite.dart';
import 'adult_face_sprites.dart';
import 'adult_form_sprites.dart';
import 'icon_sprites.dart';
import 'piglet_face_sprites.dart';
import 'prop_sprites.dart';
import 'wallow_face_sprites.dart';

export 'adult_face_sprites.dart';
export 'adult_form_sprites.dart';
export 'icon_sprites.dart';
export 'piglet_face_sprites.dart';
export 'prop_sprites.dart';
export 'wallow_face_sprites.dart';

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

  /// Base name of the Dart constants behind this animation — `kRuntFaceEat` for
  /// `kRuntFaceEat1` and `kRuntFaceEat2`.
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

/// What the pig is visibly *doing*.
enum PetPose { idle, eating, sleeping, wallowing }

/// How the pig visibly *feels*.
///
/// A separate axis from pose, because these answer different questions and
/// change on different timescales — a pig can be ill while eating, or content
/// while wallowing.
enum PetMood { content, happy, sad, sick }

const _piglet = 'lib/sprites/piglet_face_sprites.dart';
const _adult = 'lib/sprites/adult_face_sprites.dart';
const _forms = 'lib/sprites/adult_form_sprites.dart';
const _wallows = 'lib/sprites/wallow_face_sprites.dart';
const _props = 'lib/sprites/prop_sprites.dart';
const _icons = 'lib/sprites/icon_sprites.dart';

/// Every animation in the game, by name. Powers the sprite editor's load menu
/// and the tests that validate the whole cast.
const Map<String, SpriteAnim> kSpriteRegistry = {
  'egg': SpriteAnim(kEgg1, kEgg2, dartName: 'kEgg', sourceFile: _props),

  // --- Piglet ---------------------------------------------------------------
  'piglet.idle': SpriteAnim(
    kPigletFaceIdle1,
    kPigletFaceIdle2,
    dartName: 'kPigletFaceIdle',
    sourceFile: _piglet,
  ),
  'piglet.happy': SpriteAnim(
    kPigletFaceHappy1,
    kPigletFaceHappy2,
    dartName: 'kPigletFaceHappy',
    sourceFile: _piglet,
  ),
  'piglet.sad': SpriteAnim(
    kPigletFaceSad1,
    kPigletFaceSad2,
    dartName: 'kPigletFaceSad',
    sourceFile: _piglet,
  ),
  'piglet.sick': SpriteAnim(
    kPigletFaceSick1,
    kPigletFaceSick2,
    dartName: 'kPigletFaceSick',
    sourceFile: _piglet,
  ),
  'piglet.eating': SpriteAnim(
    kPigletFaceEat1,
    kPigletFaceEat2,
    dartName: 'kPigletFaceEat',
    sourceFile: _piglet,
  ),
  'piglet.sleeping': SpriteAnim(
    kPigletFaceSleep1,
    kPigletFaceSleep2,
    dartName: 'kPigletFaceSleep',
    sourceFile: _piglet,
  ),
  'piglet.wallowing': SpriteAnim(
    kPigletFaceWallow1,
    kPigletFaceWallow2,
    dartName: 'kPigletFaceWallow',
    sourceFile: _wallows,
  ),

  // --- Farm hog: the reference adult build ----------------------------------
  'farmHog.idle': SpriteAnim(
    kFaceIdle1,
    kFaceIdle2,
    dartName: 'kFaceIdle',
    sourceFile: _adult,
  ),
  'farmHog.happy': SpriteAnim(
    kFaceHappy1,
    kFaceHappy2,
    dartName: 'kFaceHappy',
    sourceFile: _adult,
  ),
  'farmHog.sad': SpriteAnim(
    kFaceSad1,
    kFaceSad2,
    dartName: 'kFaceSad',
    sourceFile: _adult,
  ),
  'farmHog.sick': SpriteAnim(
    kFaceSick1,
    kFaceSick2,
    dartName: 'kFaceSick',
    sourceFile: _adult,
  ),
  'farmHog.eating': SpriteAnim(
    kFaceEat1,
    kFaceEat2,
    dartName: 'kFaceEat',
    sourceFile: _adult,
  ),
  'farmHog.sleeping': SpriteAnim(
    kFaceSleep1,
    kFaceSleep2,
    dartName: 'kFaceSleep',
    sourceFile: _adult,
  ),
  'farmHog.wallowing': SpriteAnim(
    kAdultFaceWallow1,
    kAdultFaceWallow2,
    dartName: 'kAdultFaceWallow',
    sourceFile: _wallows,
  ),

  // --- Prize hog ------------------------------------------------------------
  'prizeHog.idle': SpriteAnim(
    kPrizeFaceIdle1,
    kPrizeFaceIdle2,
    dartName: 'kPrizeFaceIdle',
    sourceFile: _forms,
  ),
  'prizeHog.happy': SpriteAnim(
    kPrizeFaceHappy1,
    kPrizeFaceHappy2,
    dartName: 'kPrizeFaceHappy',
    sourceFile: _forms,
  ),
  'prizeHog.sad': SpriteAnim(
    kPrizeFaceSad1,
    kPrizeFaceSad2,
    dartName: 'kPrizeFaceSad',
    sourceFile: _forms,
  ),
  'prizeHog.sick': SpriteAnim(
    kPrizeFaceSick1,
    kPrizeFaceSick2,
    dartName: 'kPrizeFaceSick',
    sourceFile: _forms,
  ),
  'prizeHog.eating': SpriteAnim(
    kPrizeFaceEat1,
    kPrizeFaceEat2,
    dartName: 'kPrizeFaceEat',
    sourceFile: _forms,
  ),
  'prizeHog.sleeping': SpriteAnim(
    kPrizeFaceSleep1,
    kPrizeFaceSleep2,
    dartName: 'kPrizeFaceSleep',
    sourceFile: _forms,
  ),
  'prizeHog.wallowing': SpriteAnim(
    kPrizeFaceWallow1,
    kPrizeFaceWallow2,
    dartName: 'kPrizeFaceWallow',
    sourceFile: _wallows,
  ),

  // --- Runt -----------------------------------------------------------------
  'runt.idle': SpriteAnim(
    kRuntFaceIdle1,
    kRuntFaceIdle2,
    dartName: 'kRuntFaceIdle',
    sourceFile: _forms,
  ),
  'runt.happy': SpriteAnim(
    kRuntFaceHappy1,
    kRuntFaceHappy2,
    dartName: 'kRuntFaceHappy',
    sourceFile: _forms,
  ),
  'runt.sad': SpriteAnim(
    kRuntFaceSad1,
    kRuntFaceSad2,
    dartName: 'kRuntFaceSad',
    sourceFile: _forms,
  ),
  'runt.sick': SpriteAnim(
    kRuntFaceSick1,
    kRuntFaceSick2,
    dartName: 'kRuntFaceSick',
    sourceFile: _forms,
  ),
  'runt.eating': SpriteAnim(
    kRuntFaceEat1,
    kRuntFaceEat2,
    dartName: 'kRuntFaceEat',
    sourceFile: _forms,
  ),
  'runt.sleeping': SpriteAnim(
    kRuntFaceSleep1,
    kRuntFaceSleep2,
    dartName: 'kRuntFaceSleep',
    sourceFile: _forms,
  ),
  'runt.wallowing': SpriteAnim(
    kRuntFaceWallow1,
    kRuntFaceWallow2,
    dartName: 'kRuntFaceWallow',
    sourceFile: _wallows,
  ),

  // --- Props ----------------------------------------------------------------
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

  // --- Icons ----------------------------------------------------------------
  // Registered so the well-formedness sweep covers them and the sprite editor
  // can load them. They are still, which is why the animation sweeps iterate
  // kCreatureKeys rather than filtering this map.
  'icon.feed': SpriteAnim.still(
    kFeedIcon,
    dartName: 'kFeedIcon',
    sourceFile: _icons,
  ),
  'icon.wallow': SpriteAnim.still(
    kWallowIcon,
    dartName: 'kWallowIcon',
    sourceFile: _icons,
  ),
  'icon.play': SpriteAnim.still(
    kPlayIcon,
    dartName: 'kPlayIcon',
    sourceFile: _icons,
  ),
  'icon.meds': SpriteAnim.still(
    kMedsIcon,
    dartName: 'kMedsIcon',
    sourceFile: _icons,
  ),
  'icon.clean': SpriteAnim.still(
    kCleanIcon,
    dartName: 'kCleanIcon',
    sourceFile: _icons,
  ),
  'icon.stats': SpriteAnim.still(
    kStatsIcon,
    dartName: 'kStatsIcon',
    sourceFile: _icons,
  ),
  'icon.light': SpriteAnim.still(
    kLightIcon,
    dartName: 'kLightIcon',
    sourceFile: _icons,
  ),
  'icon.treat': SpriteAnim.still(
    kTreatIcon,
    dartName: 'kTreatIcon',
    sourceFile: _icons,
  ),
  'icon.weight': SpriteAnim.still(
    kWeightIcon,
    dartName: 'kWeightIcon',
    sourceFile: _icons,
  ),
  'prop.mound': SpriteAnim.still(
    kMound,
    dartName: 'kMound',
    sourceFile: _props,
  ),
};

/// Every pose a creature build is required to provide.
const List<String> kRequiredPoses = [
  'idle',
  'happy',
  'sad',
  'sick',
  'eating',
  'sleeping',
  'wallowing',
];

/// Every creature build in the game.
const List<String> kBuildKeys = ['piglet', 'farmHog', 'prizeHog', 'runt'];

/// Every registry key that is a creature — the things that must animate and
/// must stay on their floor line. Props, icons and crests are none of those.
List<String> get kCreatureKeys => [
  'egg',
  for (final build in kBuildKeys)
    for (final pose in kRequiredPoses) '$build.$pose',
];

/// The registry key for a creature's build — the thing that owns a face.
///
/// `base` should never reach adulthood, since the form is fixed at the
/// piglet→adult transition, but a pet seeded mid-development might, so it falls
/// back to the reference build rather than crashing.
String buildKey({required Stage stage, required Form form}) => switch (stage) {
  Stage.egg => 'egg',
  Stage.piglet => 'piglet',
  Stage.adult => form == Form.base ? 'farmHog' : form.name,
};

/// The animation for a creature in a given pose and mood.
///
/// Mood only reaches the screen through the idle pose. The other three have
/// their eyes spoken for already — sleeping shuts them, eating squeezes them,
/// wallowing buries everything below the chin — so a "happy sleeping" pig would
/// mean drawing crescents on a face whose eyes are closed.
SpriteAnim creatureAnim({
  required Stage stage,
  required Form form,
  required PetPose pose,
  PetMood mood = PetMood.content,
}) {
  if (stage == Stage.egg) return kSpriteRegistry['egg']!;

  final who = buildKey(stage: stage, form: form);
  final what = switch (pose) {
    PetPose.eating => 'eating',
    PetPose.sleeping => 'sleeping',
    PetPose.wallowing => 'wallowing',
    PetPose.idle => switch (mood) {
      PetMood.content => 'idle',
      PetMood.happy => 'happy',
      PetMood.sad => 'sad',
      PetMood.sick => 'sick',
    },
  };

  return kSpriteRegistry['$who.$what'] ?? kSpriteRegistry['$who.idle']!;
}
