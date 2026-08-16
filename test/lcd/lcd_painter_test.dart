import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/lcd/lcd.dart';
import 'package:sooey/sprites/sprite_registry.dart';

void main() {
  group('lcdDotSize', () {
    test('is always a whole number of pixels', () {
      // Fractional dot sizes put some dots on half-pixels and the grid
      // shimmers as the window resizes — the tell that gives away a fake LCD.
      for (var w = 64.0; w < 2000; w += 0.5) {
        final size = lcdDotSize(Size(w, w / 2));
        expect(size, size.toInt(), reason: 'width $w');
      }
    });

    test('fits the width when width is the binding constraint', () {
      // 32 columns into 640px is exactly 20px per dot.
      expect(lcdDotSize(const Size(640, 1000)), 20);
      // 700px gives 21.875 — must round down, not up.
      expect(lcdDotSize(const Size(700, 1000)), 21);
    });

    test('fits the height when height is the binding constraint', () {
      // 16 rows into 160px is 10px per dot, which is tighter than 640/32 = 20.
      expect(lcdDotSize(const Size(640, 160)), 10);
    });

    test('takes whichever constraint binds first', () {
      for (var w = 100.0; w < 1200; w += 7) {
        for (var h = 60.0; h < 800; h += 11) {
          final d = lcdDotSize(Size(w, h));
          final grid = lcdGridSize(d);
          // The grid fits...
          expect(grid.width, lessThanOrEqualTo(w), reason: '${w}x$h');
          expect(grid.height, lessThanOrEqualTo(h), reason: '${w}x$h');
          // ...and one more pixel per dot would not have.
          final bigger = lcdGridSize(d + 1);
          expect(
            bigger.width > w || bigger.height > h,
            isTrue,
            reason: 'left space on the table at ${w}x$h',
          );
        }
      }
    });

    test('stays visible in a cramped box rather than collapsing', () {
      expect(lcdDotSize(const Size(10, 10)), greaterThanOrEqualTo(kMinDotSize));
      expect(lcdDotSize(Size.zero), greaterThanOrEqualTo(kMinDotSize));
    });
  });

  group('LcdPainter', () {
    test('repaints when the frame counter advances', () {
      final buffer = LcdBuffer();
      final a = LcdPainter(buffer: buffer, frame: 1, dotSize: 10);
      final b = LcdPainter(buffer: buffer, frame: 2, dotSize: 10);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint when nothing has changed', () {
      final buffer = LcdBuffer();
      final a = LcdPainter(buffer: buffer, frame: 7, dotSize: 10);
      final b = LcdPainter(buffer: buffer, frame: 7, dotSize: 10);
      expect(b.shouldRepaint(a), isFalse);
    });

    test('repaints when the window resizes the dots', () {
      final buffer = LcdBuffer();
      final a = LcdPainter(buffer: buffer, frame: 7, dotSize: 10);
      final b = LcdPainter(buffer: buffer, frame: 7, dotSize: 11);
      expect(b.shouldRepaint(a), isTrue);
    });
  });

  group('LcdScreen', () {
    testWidgets('renders crisply at three window widths', (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, width * 0.6));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LcdScreen(
              buffer: LcdBuffer()..blit(kFarmHogIdle1, 0, 0),
              frame: 0,
            ),
          ),
        );

        final painter = tester.widget<CustomPaint>(
          find.byType(CustomPaint).first,
        );
        final lcd = painter.painter! as LcdPainter;
        expect(
          lcd.dotSize * kLcdWidth,
          painter.size.width,
          reason: 'width $width',
        );
        expect(
          lcd.dotSize * kLcdHeight,
          painter.size.height,
          reason: 'width $width',
        );
      }
      await tester.binding.setSurfaceSize(null);
    });
  });
}
