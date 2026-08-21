import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/game_constants.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/truffle_hunt.dart';
import 'package:sooey/lcd/lcd_buffer.dart';
import 'package:sooey/sprites/sprite_registry.dart';

import 'screen_test_support.dart';

/// A pig that always goes left, so a test can choose to win or lose.
class _AlwaysLeft implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

/// Runs one round to its conclusion: guess, then let the reveal expire.
void playRound(TruffleHunt hunt, Button guess, {required int at}) {
  hunt.handle(guess, testContext(nowMillis: at));
  hunt.update(testContext(nowMillis: at + kHuntRevealMillis + 1));
}

void main() {
  group('a round', () {
    test('A guesses left and C guesses right', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.a, testContext());
      expect(hunt.results.first, isTrue, reason: 'guessed left, pig went left');

      final missed = TruffleHunt(random: _AlwaysLeft());
      missed.handle(Button.c, testContext());
      expect(missed.results.first, isFalse, reason: 'guessed right');
    });

    test('B does nothing — the guess is A or C, per spec 7.4', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.b, testContext());
      expect(hunt.results.first, isNull);
      expect(hunt.round, 0);
    });

    test('ignores further guesses while the pig is still snuffling', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.a, testContext(nowMillis: kRefNoon));
      hunt.handle(Button.c, testContext(nowMillis: kRefNoon + 10));
      expect(hunt.round, 0);
      expect(hunt.results[1], isNull, reason: 'a second round started early');
    });

    test('does not advance until the reveal has run its course', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.a, testContext(nowMillis: kRefNoon));
      hunt.update(testContext(nowMillis: kRefNoon + kHuntRevealMillis - 1));
      expect(hunt.round, 0, reason: 'cut the reveal short');
      hunt.update(testContext(nowMillis: kRefNoon + kHuntRevealMillis + 1));
      expect(hunt.round, 1);
    });
  });

  group('the match', () {
    test('is best of five and reports the wins', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      var at = kRefNoon;
      for (var i = 0; i < kPlayRounds - 1; i++) {
        playRound(hunt, i.isEven ? Button.a : Button.c, at: at);
        at += kHuntRevealMillis * 2;
      }
      hunt.handle(Button.a, testContext(nowMillis: at));
      final out = hunt.update(
        testContext(nowMillis: at + kHuntRevealMillis + 1),
      );
      expect(out, isA<Played>());
      // Rounds 0, 2, 4 guessed left against a pig that always goes left.
      expect((out as Played).wins, 3);
    });

    test('a perfect match reports five', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      var at = kRefNoon;
      Transition last = const Stay();
      for (var i = 0; i < kPlayRounds; i++) {
        hunt.handle(Button.a, testContext(nowMillis: at));
        last = hunt.update(testContext(nowMillis: at + kHuntRevealMillis + 1));
        at += kHuntRevealMillis * 2;
      }
      expect((last as Played).wins, kPlayRounds);
    });

    test('keeps the play icon lit', () {
      expect(TruffleHunt(random: _AlwaysLeft()).litIcon, DeviceIcon.play);
    });
  });

  group('the frame', () {
    test('draws the mounds over the pig, not under it', () {
      // A creature sprite is the full screen with unlit dots all round the pig,
      // so blitting it at an offset paints over whatever was already there.
      //
      // Assert the mound's exact shape, not merely that something is lit there.
      // At dx = -9 the pig's own artwork puts dots at columns 2-6 of row 14, so
      // a presence check passes whichever order the two are drawn in. The
      // mound's rows are '.###.' and '#####'; reverse the order and the pig
      // overwrites both.
      final hunt = TruffleHunt(random: _AlwaysLeft())
        ..handle(Button.a, testContext());
      final rows = hunt.compose(testContext(), 0).toAscii().split('\n');
      expect(rows[13].substring(2, 7), '.###.', reason: 'mound row 2 erased');
      expect(rows[14].substring(2, 7), '#####', reason: 'mound row 3 erased');
    });

    test('moves the pig exactly kHuntSlide dots off centre once it has '
        'committed', () {
      // A whole-frame inequality would pass even if the pig moved by the
      // wrong amount, or didn't move at all and only the pose or the tally
      // changed — handle() changes all three at once. Isolate the offset by
      // reconstructing the same pose with no slide, from the same building
      // blocks compose() itself uses, and checking the real frame against it
      // shifted by exactly kHuntSlide.
      final hunt = TruffleHunt(random: _AlwaysLeft())
        ..handle(Button.a, testContext());
      const frameIndex = 1;
      final actual = hunt
          .compose(testContext(), frameIndex)
          .toAscii()
          .split('\n');

      final pet = testContext().pet;
      final centred = LcdBuffer()
        ..blit(
          creatureAnim(
            stage: pet.stage,
            form: pet.form,
            pose: PetPose.eating,
          ).frame(frameIndex),
          0,
          0,
        );
      final expectedRow = centred.toAscii().split('\n')[7];

      // Deliberately literal rather than `kHuntSlide`: if the two were tied
      // together, a bug that zeroed the constant would zero both sides of
      // this comparison at once and the test would still pass. (Proved by
      // hand: with `kHuntSlide` forced to 0 and this literal left at 9, the
      // pig visibly stops moving and the assertion below fails; tying the
      // shift to the constant instead left it passing regardless.) The
      // assertion just below keeps this literal honest against the real
      // constant.
      const expectedSlide = 9;
      expect(
        kHuntSlide,
        expectedSlide,
        reason: 'kHuntSlide changed — update the literal shift above to match',
      );

      // Row 7 sits inside the head, clear of the tally (rows 0-1), the heart
      // (row 3) and the mounds (rows 12-14), so nothing else this frame
      // draws can explain a match or a mismatch here — only the pig's own
      // horizontal offset can.
      final shifted = [
        for (var x = 0; x < 32; x++)
          x + expectedSlide < 32 ? expectedRow[x + expectedSlide] : '.',
      ].join();
      expect(
        actual[7],
        shifted,
        reason:
            'the committed pig should sit exactly kHuntSlide dots left '
            'of where it sits centred',
      );
    });

    test('tells an unplayed round from a lost one', () {
      // Compose from a hunt that never calls handle() at all, so pigWentLeft
      // stays null throughout and the pig is centred and idle in every one
      // of the three frames below — only `results[0]` (set directly, since
      // it is a public field meant for exactly this) varies. A whole-frame
      // inequality between "fresh" and "one loss" would pass even if the
      // tally drew nothing at all and the difference came only from a stray
      // pixel elsewhere, which is exactly how this test used to pass with
      // the `case false:` branch deleted.
      const x = 10; // _tallyX, slot 0
      final unplayedRow0 = TruffleHunt(
        random: _AlwaysLeft(),
      ).compose(testContext(), 0).toAscii().split('\n')[0];
      final unplayedRow1 = TruffleHunt(
        random: _AlwaysLeft(),
      ).compose(testContext(), 0).toAscii().split('\n')[1];
      expect(unplayedRow0[x], '.', reason: 'unplayed: nothing at (x,0)');
      expect(unplayedRow0[x + 1], '.', reason: 'unplayed: nothing at (x+1,0)');
      expect(unplayedRow1[x], '.', reason: 'unplayed: nothing at (x,1)');
      expect(unplayedRow1[x + 1], '.', reason: 'unplayed: nothing at (x+1,1)');

      final lost = TruffleHunt(random: _AlwaysLeft())..results[0] = false;
      final lostFrame = lost.compose(testContext(), 0).toAscii().split('\n');
      expect(lostFrame[0][x], '#', reason: 'loss: a single dot at (x,0)');
      expect(lostFrame[0][x + 1], '.', reason: 'loss: nothing at (x+1,0)');
      expect(lostFrame[1][x], '.', reason: 'loss: nothing at (x,1)');
      expect(lostFrame[1][x + 1], '.', reason: 'loss: nothing at (x+1,1)');

      final won = TruffleHunt(random: _AlwaysLeft())..results[0] = true;
      final wonFrame = won.compose(testContext(), 0).toAscii().split('\n');
      expect(wonFrame[0][x], '#', reason: 'win: (x,0) lit');
      expect(wonFrame[0][x + 1], '#', reason: 'win: (x+1,0) lit');
      expect(wonFrame[1][x], '#', reason: 'win: (x,1) lit');
      expect(wonFrame[1][x + 1], '#', reason: 'win: (x+1,1) lit');
    });
  });
}
