import 'dart:math';

import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_buffer.dart';
import '../../sprites/prop_sprites.dart';
import '../../sprites/sprite_registry.dart';
import '../game_constants.dart';
import '../pet_appearance.dart';
import 'device_screen.dart';

const int _moundLeftX = 2;
const int _moundRightX = 25;
const int _moundY = 12;
const int _tallyX = 10;
const int _heartX = 13;
const int _heartY = 3;

/// Best of five, resolved on the device.
///
/// Spec §7.4 has the pig turning left or right. It cannot: the front-facing
/// redesign left the cast with no left and no right, and drawing eight new
/// poses would risk the skull-and-snout misalignment that has already shipped
/// once. So the pig trots to the mound it picked and snuffles there in the
/// eating pose it already has.
class TruffleHunt extends DeviceScreen {
  /// [random] is `dart:math`'s, injected so tests can make the pig predictable.
  ///
  /// It deliberately is **not** `hog_sim`'s generator. That one is seeded off
  /// `petId` and tick so the VM, dart2js and the browser agree dot for dot;
  /// drawing from it here would make the simulation's output depend on whether
  /// the player happened to play a minigame.
  TruffleHunt({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Null while a round is unplayed, true for a hit, false for a miss.
  final List<bool?> results = List<bool?>.filled(kPlayRounds, null);

  int round = 0;

  /// Which way the pig went, while it is still over there. Null between rounds.
  bool? pigWentLeft;

  int revealUntilMillis = 0;

  int get wins => results.where((r) => r == true).length;

  bool get revealing => pigWentLeft != null;

  @override
  DeviceIcon? get litIcon => DeviceIcon.play;

  @override
  Transition handle(Button b, GameContext ctx) {
    // B has no meaning in a round: the guess is A or C, per spec 7.4. There is
    // no third button left for "abandon" — once a match is under way it runs
    // to its conclusion, which at kHuntRevealMillis a round is over in
    // seconds anyway.
    //
    // A second guess while the pig is still at a mound would resolve a round
    // the player has not seen the answer to yet.
    if (b == Button.b || revealing || round >= kPlayRounds) return const Stay();

    final wentLeft = _random.nextBool();
    pigWentLeft = wentLeft;
    results[round] = (b == Button.a) == wentLeft;
    revealUntilMillis = ctx.nowMillis + kHuntRevealMillis;
    return const Stay();
  }

  @override
  Transition update(GameContext ctx) {
    if (!revealing || ctx.nowMillis < revealUntilMillis) return const Stay();
    pigWentLeft = null;
    round++;
    return round >= kPlayRounds ? Played(wins) : const Stay();
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) {
    final buffer = LcdBuffer();

    final dx = switch (pigWentLeft) {
      true => -kHuntSlide,
      false => kHuntSlide,
      null => 0,
    };
    buffer.blit(
      creatureAnim(
        stage: ctx.pet.stage,
        form: ctx.pet.form,
        pose: revealing ? PetPose.eating : PetPose.idle,
        mood: moodFor(ctx.pet),
      ).frame(frame),
      dx,
      0,
    );

    // Mounds go on *after* the pig. A creature sprite is the full screen with
    // unlit dots all round it, so blitting one at an offset paints over
    // anything already beneath — draw these first and the pig erases one.
    buffer
      ..blit(kMound, _moundLeftX, _moundY)
      ..blit(kMound, _moundRightX, _moundY);

    if (revealing && round < kPlayRounds && results[round] == true) {
      // Blinks, so a win reads as a celebration rather than as furniture.
      if (frame.isEven) buffer.blit(kHeart, _heartX, _heartY);
    }

    _drawTally(buffer);
    return buffer;
  }

  /// Five marks along the top. A win is a block, a loss a single dot, an
  /// unplayed round nothing — otherwise round three and two losses look the
  /// same and the player loses count.
  void _drawTally(LcdBuffer buffer) {
    for (var i = 0; i < kPlayRounds; i++) {
      final x = _tallyX + i * 3;
      switch (results[i]) {
        case true:
          buffer
            ..set(x, 0, true)
            ..set(x + 1, 0, true)
            ..set(x, 1, true)
            ..set(x + 1, 1, true);
        case false:
          buffer.set(x, 0, true);
        case null:
          break;
      }
    }
  }
}
