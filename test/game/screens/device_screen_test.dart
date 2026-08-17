import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/lcd/lcd.dart';

import 'screen_test_support.dart';

/// The smallest screen that satisfies the contract, so the contract itself can
/// be tested without dragging a real one in.
class _Nothing extends DeviceScreen {
  @override
  DeviceIcon? get litIcon => null;

  @override
  Transition handle(Button b, GameContext ctx) => const Stay();

  @override
  LcdBuffer compose(GameContext ctx, int frame) => LcdBuffer();
}

void main() {
  group('the icon order', () {
    test('is the order A cycles, feed first and light last', () {
      // The strip's two rows are laid out from this order, so changing it moves
      // icons on the glass as well as under the cursor.
      expect(DeviceIcon.values.map((i) => i.name).toList(), [
        'feed',
        'wallow',
        'play',
        'meds',
        'clean',
        'stats',
        'light',
      ]);
    });

    test('has seven icons, train having been cut by D2', () {
      expect(DeviceIcon.values.length, 7);
    });
  });

  group('Crest', () {
    test('offers eight emblems', () {
      expect(Crest.values.length, 8);
    });
  });

  group('DeviceScreen', () {
    test('does nothing on update unless it overrides it', () {
      expect(_Nothing().update(testContext()), isA<Stay>());
    });

    test('composes a display-sized buffer', () {
      final buffer = _Nothing().compose(testContext(), 0);
      expect(buffer.width, 32);
      expect(buffer.height, 16);
    });
  });

  group('drive', () {
    test('returns one transition per press', () {
      expect(drive(_Nothing(), 'ABC', testContext()), hasLength(3));
    });

    test('rejects a character that is not a button', () {
      expect(() => drive(_Nothing(), 'X', testContext()), throwsArgumentError);
    });
  });

  group('testPet', () {
    test('builds a living adult by default', () {
      final pet = testPet();
      expect(pet.isDead, isFalse);
      expect(pet.stage, Stage.adult);
    });

    test('builds a dead one on request', () {
      expect(testPet(deathCause: DeathCause.neglect).isDead, isTrue);
    });
  });
}
