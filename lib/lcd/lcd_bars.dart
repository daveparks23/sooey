import 'lcd_buffer.dart';

/// Quantities, drawn rather than written.
///
/// The device shows no text and no numerals, so every number the player is
/// allowed to know reaches them as a filled track or a row of marks. See the
/// note on pips below — one of these rules protects the game's premise rather
/// than its style.

/// An outlined track filled from the bottom.
///
/// The outline is drawn whether or not there is anything in it: an empty bar
/// and an absent bar have to be tellable apart, or a pig with one need at zero
/// looks like a pig with a rendering fault.
void drawVerticalBar(
  LcdBuffer buffer, {
  required int x,
  required int y,
  required int width,
  required int height,
  required double fraction,
}) {
  _outline(buffer, x, y, width, height);
  final innerHeight = height - 2;
  final filled = (_clamp01(fraction) * innerHeight).round();
  for (var i = 0; i < filled; i++) {
    final row = y + height - 2 - i;
    for (var col = x + 1; col < x + width - 1; col++) {
      buffer.set(col, row, true);
    }
  }
}

/// An outlined track filled from the left.
void drawHorizontalBar(
  LcdBuffer buffer, {
  required int x,
  required int y,
  required int width,
  required int height,
  required double fraction,
}) {
  _outline(buffer, x, y, width, height);
  final innerWidth = width - 2;
  final filled = (_clamp01(fraction) * innerWidth).round();
  for (var i = 0; i < filled; i++) {
    final col = x + 1 + i;
    for (var row = y + 1; row < y + height - 1; row++) {
      buffer.set(col, row, true);
    }
  }
}

/// A row of marks, one per unit, wrapping every [perRow].
///
/// **Only lit pips are drawn.** There are deliberately no empty placeholders:
/// an outlined row of twenty slots would imply a denominator, and the
/// denominator for age is `expiresAt`, which is fixed from the care-mistake
/// count the player is never allowed to see. A count can grow forever; a
/// fraction gives the game away.
void drawPips(
  LcdBuffer buffer, {
  required int count,
  required int x,
  required int y,
  int perRow = 10,
  int pitch = 3,
  int size = 2,
}) {
  for (var i = 0; i < count; i++) {
    final px = x + (i % perRow) * pitch;
    final py = y + (i ~/ perRow) * pitch;
    for (var dy = 0; dy < size; dy++) {
      for (var dx = 0; dx < size; dx++) {
        buffer.set(px + dx, py + dy, true);
      }
    }
  }
}

void _outline(LcdBuffer buffer, int x, int y, int width, int height) {
  for (var i = 0; i < width; i++) {
    buffer.set(x + i, y, true);
    buffer.set(x + i, y + height - 1, true);
  }
  for (var j = 0; j < height; j++) {
    buffer.set(x, y + j, true);
    buffer.set(x + width - 1, y + j, true);
  }
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
