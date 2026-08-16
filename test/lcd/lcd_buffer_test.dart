import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/lcd/lcd.dart';
import 'package:sooey/sprites/sprite_registry.dart';

/// Builds a sprite from an ASCII block, trimming the leading newline so test
/// literals can start on their own line.
LcdSprite sprite(String art) {
  final rows = art.split('\n')..removeWhere((r) => r.isEmpty);
  return LcdSprite.checked(rows.first.length, rows.length, rows);
}

void main() {
  group('LcdSprite', () {
    test('accepts a well-formed sprite', () {
      const s = LcdSprite(3, 2, ['#.#', '.#.']);
      expect(s.width, 3);
      expect(s.height, 2);
    });

    test('rejects a row count that disagrees with its height', () {
      expect(
        () => LcdSprite.checked(3, 5, ['#.#', '.#.']),
        throwsArgumentError,
      );
    });

    test('rejects a row whose length disagrees with its width', () {
      expect(() => LcdSprite.checked(3, 2, ['#.#', '.#']), throwsArgumentError);
    });

    test('rejects characters outside the three-state alphabet', () {
      expect(() => LcdSprite.checked(3, 1, ['#x.']), throwsArgumentError);
    });
  });

  group('LcdBuffer', () {
    test('is the fixed logical resolution and starts dark', () {
      final b = LcdBuffer();
      expect(b.width, 32);
      expect(b.height, 16);
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 32; x++) {
          expect(b.get(x, y), isFalse);
        }
      }
    });

    test('clear turns every dot back off', () {
      final b = LcdBuffer()..blit(sprite('###'), 0, 0);
      expect(b.get(1, 0), isTrue);
      b.clear();
      expect(b.get(1, 0), isFalse);
    });
  });

  group('blit', () {
    test('turns dots on for # and off for .', () {
      final b = LcdBuffer()..blit(sprite('#.#'), 0, 0);
      expect(b.get(0, 0), isTrue);
      expect(b.get(1, 0), isFalse);
      expect(b.get(2, 0), isTrue);
    });

    test('leaves the background untouched under a space', () {
      // Transparency is why the sprite alphabet has three states: a poop drawn
      // over the pig must not punch a hole in it.
      final b = LcdBuffer()
        ..blit(sprite('###'), 0, 0)
        ..blit(sprite(' . '), 0, 0);
      expect(b.get(0, 0), isTrue, reason: 'transparent cell');
      expect(b.get(1, 0), isFalse, reason: 'explicit off');
      expect(b.get(2, 0), isTrue, reason: 'transparent cell');
    });

    test('places a sprite at an offset', () {
      final b = LcdBuffer()..blit(sprite('#'), 5, 3);
      expect(b.get(5, 3), isTrue);
      expect(b.get(4, 3), isFalse);
      expect(b.get(5, 2), isFalse);
    });

    test('clips at the right and bottom edges instead of throwing', () {
      final b = LcdBuffer()..blit(sprite('###'), 30, 15);
      expect(b.get(30, 15), isTrue);
      expect(b.get(31, 15), isTrue);
      // The third column would be x = 32 and is simply dropped.
    });

    test('clips at the left and top edges', () {
      final b = LcdBuffer()..blit(sprite('###'), -1, 0);
      expect(b.get(0, 0), isTrue);
      expect(b.get(1, 0), isTrue);
    });

    test('a sprite entirely off-screen changes nothing', () {
      final b = LcdBuffer()..blit(sprite('###'), 100, 100);
      expect(b.toAscii(), LcdBuffer().toAscii());
    });

    test('later blits draw over earlier ones', () {
      final b = LcdBuffer()
        ..blit(sprite('###'), 0, 0)
        ..blit(sprite('.'), 1, 0);
      expect(b.get(1, 0), isFalse);
    });
  });

  group('toAscii', () {
    test('renders 16 rows of 32 characters', () {
      final lines = LcdBuffer().toAscii().split('\n');
      expect(lines.length, 16);
      for (final line in lines) {
        expect(line.length, 32);
      }
    });

    test('round-trips through a sprite', () {
      final b = LcdBuffer()..blit(sprite('#.#\n.#.'), 4, 2);
      final ascii = b.toAscii();
      final rebuilt = LcdBuffer()
        ..blit(LcdSprite.checked(32, 16, ascii.split('\n')), 0, 0);
      expect(rebuilt.toAscii(), ascii);
    });
  });

  group('the cast', () {
    test('creature sprites are the full screen size', () {
      expect(kFaceIdle1.width, 32);
      expect(kFaceIdle1.height, 16);
      expect(kPigletFaceIdle1.width, 32);
      expect(kPigletFaceIdle1.height, 16);
    });

    test('actually draw something', () {
      final b = LcdBuffer()..blit(kFaceIdle1, 0, 0);
      expect(b.toAscii().contains('#'), isTrue);
    });
  });
}
