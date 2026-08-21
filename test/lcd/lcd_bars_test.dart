import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/lcd/lcd.dart';

void main() {
  group('drawVerticalBar', () {
    test('draws an outline even when empty, so a flat need still reads', () {
      final b = LcdBuffer();
      drawVerticalBar(b, x: 0, y: 0, width: 7, height: 9, fraction: 0);
      expect(b.get(0, 0), isTrue, reason: 'top-left corner');
      expect(b.get(6, 8), isTrue, reason: 'bottom-right corner');
      expect(b.get(3, 4), isFalse, reason: 'interior stays empty');
    });

    test('fills from the bottom', () {
      final b = LcdBuffer();
      drawVerticalBar(b, x: 0, y: 0, width: 7, height: 9, fraction: 0.5);
      expect(b.get(3, 7), isTrue, reason: 'lowest interior row fills first');
      expect(b.get(3, 1), isFalse, reason: 'highest interior row fills last');
    });

    test('a full bar fills every interior row', () {
      final b = LcdBuffer();
      drawVerticalBar(b, x: 0, y: 0, width: 7, height: 9, fraction: 1);
      for (var y = 1; y <= 7; y++) {
        expect(b.get(3, y), isTrue, reason: 'row $y');
      }
    });

    test('0 and 100 are visibly different', () {
      final empty = LcdBuffer();
      final full = LcdBuffer();
      drawVerticalBar(empty, x: 0, y: 0, width: 7, height: 9, fraction: 0);
      drawVerticalBar(full, x: 0, y: 0, width: 7, height: 9, fraction: 1);
      expect(empty.toAscii(), isNot(full.toAscii()));
    });

    test(
      'clamps a fraction outside 0..1 rather than drawing outside itself',
      () {
        // Vertical bars fill upward, so asserting "nothing below the bar"
        // tests the side the overflow never reaches. Compare against a full
        // bar instead: with the clamp removed, fraction 5 writes far above
        // the outline and the two frames diverge.
        final over = LcdBuffer();
        final full = LcdBuffer();
        drawVerticalBar(over, x: 0, y: 4, width: 7, height: 9, fraction: 5);
        drawVerticalBar(full, x: 0, y: 4, width: 7, height: 9, fraction: 1);
        expect(over.toAscii(), full.toAscii());
      },
    );
  });

  group('drawHorizontalBar', () {
    test('fills from the left', () {
      final b = LcdBuffer();
      drawHorizontalBar(b, x: 0, y: 0, width: 22, height: 5, fraction: 0.5);
      expect(
        b.get(1, 2),
        isTrue,
        reason: 'leftmost interior column fills first',
      );
      expect(b.get(20, 2), isFalse, reason: 'rightmost fills last');
    });

    test('draws an outline even when empty', () {
      final b = LcdBuffer();
      drawHorizontalBar(b, x: 0, y: 0, width: 22, height: 5, fraction: 0);
      expect(b.get(0, 0), isTrue);
      expect(b.get(21, 4), isTrue);
    });

    test(
      'clamps a fraction outside 0..1 rather than drawing outside itself',
      () {
        // Same shape as the vertical case: horizontal bars fill from the
        // left, so there are columns to the right of the outline for an
        // unclamped fraction to escape into. Compare against a full bar
        // rather than asserting an untouched corner, which an unclamped fill
        // never reaches anyway.
        final over = LcdBuffer();
        final full = LcdBuffer();
        drawHorizontalBar(over, x: 4, y: 0, width: 22, height: 5, fraction: 5);
        drawHorizontalBar(full, x: 4, y: 0, width: 22, height: 5, fraction: 1);
        expect(over.toAscii(), full.toAscii());
      },
    );
  });

  group('drawPips', () {
    test('draws one pip per count and nothing for the rest', () {
      // No empty placeholders: an unfilled slot would imply a total, and the
      // total is the pig's lifespan, which the player must never be shown.
      final b = LcdBuffer();
      drawPips(b, count: 3, x: 1, y: 0);
      expect(b.get(1, 0), isTrue, reason: 'pip 1');
      expect(b.get(4, 0), isTrue, reason: 'pip 2');
      expect(b.get(7, 0), isTrue, reason: 'pip 3');
      expect(b.get(10, 0), isFalse, reason: 'pip 4 must not be outlined');
    });

    test('wraps onto the next row', () {
      final b = LcdBuffer();
      drawPips(b, count: 11, x: 1, y: 0, perRow: 10);
      expect(b.get(1, 3), isTrue, reason: 'eleventh pip starts a second row');
    });

    test('draws nothing at all for a count of zero', () {
      final b = LcdBuffer();
      drawPips(b, count: 0, x: 1, y: 0);
      expect(b.toAscii(), LcdBuffer().toAscii());
    });

    test('honours a tighter pip for cramped gutters', () {
      // The death screen has seven columns beside the grave and up to twenty
      // days to show, so it uses single dots at a two-dot pitch.
      final b = LcdBuffer();
      drawPips(b, count: 20, x: 25, y: 0, perRow: 4, pitch: 2, size: 1);
      expect(b.get(25, 0), isTrue);
      expect(b.get(31, 8), isTrue, reason: 'twentieth pip still on screen');
    });
  });
}
