import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/icon_strip.dart';
import 'package:sooey/device/lcd_glass.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/lcd/lcd.dart';
import 'package:sooey/sprites/sprite_registry.dart';

void main() {
  group('glassDotSize', () {
    test('accounts for both strips and the gaps, not just the matrix', () {
      // 32 wide by 7 + 1 + 16 + 1 + 7 = 32 tall. A dot size taken from the
      // matrix alone would overflow the box by both strips.
      expect(kGlassHeight, kStripHeight * 2 + kLcdHeight + 2);
      expect(glassDotSize(const Size(320, 320)), 10);
    });

    test('is always whole pixels', () {
      for (var w = 64.0; w < 1200; w += 0.5) {
        final d = glassDotSize(Size(w, w));
        expect(d, d.toInt(), reason: 'width $w');
      }
    });

    test('takes whichever constraint binds', () {
      expect(glassDotSize(const Size(640, 160)), 5);
      expect(glassDotSize(const Size(160, 640)), 5);
    });

    test('stays visible in a cramped box', () {
      expect(glassDotSize(Size.zero), greaterThanOrEqualTo(kMinDotSize));
    });
  });

  group('LcdGlass', () {
    testWidgets('puts the strips and the matrix on one dot pitch', (
      tester,
    ) async {
      // Different pitches are the tell that gives away two screens glued
      // together rather than one piece of glass.
      for (final width in [360.0, 800.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, width));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LcdGlass(
              buffer: LcdBuffer()..blit(kFaceIdle1, 0, 0),
              frame: 0,
              selected: DeviceIcon.feed,
            ),
          ),
        );

        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .toList();

        final matrix = painters.whereType<LcdPainter>().single;
        final strips = painters.whereType<IconStripPainter>().toList();

        expect(strips, hasLength(2), reason: 'width $width');
        for (final strip in strips) {
          expect(strip.dotSize, matrix.dotSize, reason: 'width $width');
        }
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('lights the selected icon and dims the rest', (tester) async {
      await tester.binding.setSurfaceSize(const Size(640, 640));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LcdGlass(
            buffer: LcdBuffer(),
            frame: 0,
            selected: DeviceIcon.feed,
          ),
        ),
      );

      final top = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<IconStripPainter>()
          .first;

      expect(top.lit.toAscii().contains('#'), isTrue, reason: 'nothing lit');
      expect(top.dim.toAscii().contains('#'), isTrue, reason: 'nothing dimmed');
      await tester.binding.setSurfaceSize(null);
    });
  });
}
