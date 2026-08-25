import 'package:hog_sim/hog_sim.dart';

import '../lcd/lcd_buffer.dart';
import '../sprites/sprite_registry.dart';
import 'pet_appearance.dart';

/// Where poops sit on the floor.
///
/// Two either side of the pig, clear of its feet. Fixed slots rather than
/// scattered positions: a poop that moved between frames would read as an
/// animal rather than a mess.
///
/// There must be at least [kMaxPoops] of these. With fewer, a full pen would
/// silently render as a tidier one — the player would clean what they could
/// see and stay ill for reasons nothing on screen explained.
const List<(int, int)> kPoopSlots = [(1, 12), (6, 12), (22, 12), (27, 12)];

/// Status icons live in the corners, outside the head's column range (x7–x23),
/// so they never sit on the pig's face.
const (int, int) kCallIconAt = (4, 1);
const (int, int) kSickIconAt = (25, 1);
const (int, int) kLightOffIconAt = (0, 0);

/// Builds the full 32x16 frame for a pet.
///
/// Pure — state in, dots out, no widgets and no clock reads. That is what makes
/// the display testable: a golden frame is a string a human can read in a diff,
/// not an image comparison.
LcdBuffer composeFrame(
  PetState pet, {
  required int frame,
  required int nowMillis,
  PetPose? transientPose,
}) {
  final buffer = LcdBuffer();

  // A dead pet is a grave and nothing else. No poops to clean, no status to
  // report, no pig — that emptiness is the point.
  if (pet.isDead) {
    final grave = kSpriteRegistry['prop.grave']!.a;
    buffer.blit(
      grave,
      (kLcdWidth - grave.width) ~/ 2,
      (kLcdHeight - grave.height) ~/ 2,
    );
    return buffer;
  }

  final pose = poseFor(pet, transient: transientPose, nowMillis: nowMillis);
  final mood = moodFor(pet);
  buffer.blit(
    creatureAnim(
      stage: pet.stage,
      form: pet.form,
      pose: pose,
      mood: mood,
    ).frame(frame),
    0,
    0,
  );

  // Poops are drawn over the pig deliberately: they are in the pen, in front of
  // the animal, and a mess you cannot see is a mess you will not clean.
  final poopSprite = kSpriteRegistry['prop.poop']!.a;
  for (var i = 0; i < pet.poops.length && i < kPoopSlots.length; i++) {
    final (x, y) = kPoopSlots[i];
    buffer.blit(poopSprite, x, y);
  }

  // The idle face already shows illness in its eyes, so the icon would only be
  // repeating itself. Every other pose has its eyes spoken for, and that is
  // exactly when the icon has something to say.
  if (pet.isSick && pose != PetPose.idle) {
    final (x, y) = kSickIconAt;
    buffer.blit(kSpriteRegistry['prop.sick']!.a, x, y);
  }

  // Blinks, because a steady mark becomes part of the furniture within a minute
  // and stops being an alarm.
  if (isCallingForAttention(pet, nowMillis: nowMillis) && frame.isEven) {
    final (x, y) = kCallIconAt;
    buffer.blit(kSpriteRegistry['prop.call']!.a, x, y);
  }

  if (!pet.lightsOn) {
    final (x, y) = kLightOffIconAt;
    buffer.blit(kSpriteRegistry['prop.lightOff']!.a, x, y);
  }

  return buffer;
}
