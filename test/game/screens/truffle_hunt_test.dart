import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/game_constants.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/truffle_hunt.dart';

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
      // Assert on the mound the pig actually reaches: _AlwaysLeft sends it to
      // x = -9, covering columns 0-22, which is the LEFT mound at 2-6. The
      // right-hand one at 25-29 is never overlapped, so testing that one would
      // pass whatever the draw order is.
      final hunt = TruffleHunt(random: _AlwaysLeft())
        ..handle(Button.a, testContext());
      final rows = hunt.compose(testContext(), 0).toAscii().split('\n');
      expect(
        rows[14].substring(2, 7),
        contains('#'),
        reason: 'the left-hand mound was erased by the pig on top of it',
      );
    });

    test('moves the pig off centre once it has committed', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      final waiting = hunt.compose(testContext(), 0).toAscii();
      hunt.handle(Button.a, testContext());
      expect(hunt.compose(testContext(), 0).toAscii(), isNot(waiting));
    });

    test('tells an unplayed round from a lost one', () {
      // Both would otherwise be blank, and the player would lose count.
      final fresh = TruffleHunt(random: _AlwaysLeft());
      final lost = TruffleHunt(random: _AlwaysLeft())
        ..handle(Button.c, testContext());
      expect(
        fresh.compose(testContext(), 0).toAscii(),
        isNot(lost.compose(testContext(), 0).toAscii()),
      );
    });
  });
}
