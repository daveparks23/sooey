import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/icon_strip.dart';
import 'package:sooey/game/screens/device_screen.dart';

void main() {
  group('the layout', () {
    test('puts four icons above and three below, per spec 6', () {
      expect(kStripLayout, hasLength(2));
      expect(kStripLayout[0].whereType<DeviceIcon>(), hasLength(4));
      expect(kStripLayout[1].whereType<DeviceIcon>(), hasLength(3));
    });

    test('keeps the bottom row on the same four-column grid', () {
      // Re-centring three icons would break the alignment between the strips
      // and they would stop reading as one bezel. The fourth slot is where
      // train was before D2 cut it.
      expect(kStripLayout[1], hasLength(kStripSlots));
      expect(kStripLayout[1].last, isNull);
    });

    test('covers every icon the cursor can reach, exactly once', () {
      final placed = kStripLayout.expand((r) => r).whereType<DeviceIcon>();
      expect(placed.toSet(), DeviceIcon.values.toSet());
      expect(placed, hasLength(DeviceIcon.values.length));
    });

    test('is laid out in cursor order, so A moves left to right', () {
      final placed = kStripLayout
          .expand((r) => r)
          .whereType<DeviceIcon>()
          .toList();
      expect(placed, DeviceIcon.values);
    });
  });

  group('stripBuffer', () {
    test('is the display width and the strip height', () {
      final b = stripBuffer(kStripLayout[0], include: (_) => true);
      expect(b.width, 32);
      expect(b.height, kStripHeight);
    });

    test('draws only the icons it is asked for', () {
      final all = stripBuffer(kStripLayout[0], include: (_) => true);
      final none = stripBuffer(kStripLayout[0], include: (_) => false);
      expect(all.toAscii(), isNot(none.toAscii()));
      expect(none.toAscii().contains('#'), isFalse);
    });

    test('places each icon in its own column', () {
      final first = stripBuffer(
        kStripLayout[0],
        include: (i) => i == DeviceIcon.feed,
      );
      final second = stripBuffer(
        kStripLayout[0],
        include: (i) => i == DeviceIcon.wallow,
      );
      expect(first.get(1, 2), isNot(second.get(1, 2)));
    });

    test('skips the empty slot without shifting anything along', () {
      final bottom = stripBuffer(kStripLayout[1], include: (_) => true);
      for (var y = 0; y < kStripHeight; y++) {
        for (var x = kStripPitch * 3; x < 32; x++) {
          expect(bottom.get(x, y), isFalse, reason: 'slot 4 should be dark');
        }
      }
    });
  });

  group('IconStripPainter', () {
    test('repaints when the selection moves', () {
      final lit = stripBuffer(kStripLayout[0], include: (_) => true);
      final other = stripBuffer(kStripLayout[0], include: (_) => false);
      final dim = stripBuffer(kStripLayout[0], include: (_) => true);
      final a = IconStripPainter(lit: lit, dim: dim, dotSize: 8, frame: 0);
      final b = IconStripPainter(lit: other, dim: dim, dotSize: 8, frame: 0);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint when nothing has changed', () {
      final lit = stripBuffer(kStripLayout[0], include: (_) => true);
      final dim = stripBuffer(kStripLayout[0], include: (_) => false);
      final a = IconStripPainter(lit: lit, dim: dim, dotSize: 8, frame: 3);
      final b = IconStripPainter(lit: lit, dim: dim, dotSize: 8, frame: 3);
      expect(b.shouldRepaint(a), isFalse);
    });
  });

  group('IconStrip', () {
    testWidgets('blinks an icon off even while it is the selected one', (
      tester,
    ) async {
      // A refusal almost always lands on the icon the player has selected —
      // that is how they triggered it. If `hidden` only suppressed the dim
      // pass, the blink would be invisible in exactly the case it exists for.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IconStrip(
            slots: kStripLayout[0],
            selected: DeviceIcon.feed,
            hidden: DeviceIcon.feed,
            dotSize: 8,
            frame: 0,
          ),
        ),
      );

      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
              as IconStripPainter;

      expect(
        painter.lit.toAscii().contains('#'),
        isFalse,
        reason: 'the blinked icon is still lit',
      );
      expect(
        painter.dim.toAscii().contains('#'),
        isTrue,
        reason: 'the other three should still be showing',
      );
    });
  });
}
