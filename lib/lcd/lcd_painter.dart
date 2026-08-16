import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'lcd_buffer.dart';
import 'lcd_theme.dart';

/// Smallest dot that still reads as a dot rather than a smudge, given that one
/// pixel of every cell is spent on the gap.
const int kMinDotSize = 2;

/// Edge length of one dot cell for a display of [available] size.
///
/// **Integer scaling only.** A fractional dot size makes some dots land on
/// half-pixels and the whole grid shimmers as the window resizes — which is
/// exactly the tell that gives away a fake LCD. Rounding down and letting the
/// grid be slightly smaller than its box is always the right trade.
int lcdDotSize(Size available) {
  final byWidth = available.width ~/ kLcdWidth;
  final byHeight = available.height ~/ kLcdHeight;
  return math.max(kMinDotSize, math.min(byWidth, byHeight));
}

/// The pixel size of the whole grid at a given dot size.
Size lcdGridSize(int dotSize) =>
    Size((kLcdWidth * dotSize).toDouble(), (kLcdHeight * dotSize).toDouble());

/// Draws the 512 dots of one frame.
class LcdPainter extends CustomPainter {
  const LcdPainter({
    required this.buffer,
    required this.frame,
    required this.dotSize,
  });

  final LcdBuffer buffer;

  /// Monotonic frame counter. Repainting is keyed off this rather than the
  /// buffer's contents: the buffer is mutable and rebuilt in place, so
  /// comparing it would either be wrong or cost more than the repaint.
  final int frame;

  final int dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    // One pixel of each cell is the gap between dots.
    final dot = (dotSize - 1).toDouble();
    final onPaint = Paint()..color = LcdTheme.dotOn;
    final offPaint = Paint()..color = LcdTheme.dotOff;

    for (var y = 0; y < kLcdHeight; y++) {
      final top = (y * dotSize).toDouble();
      for (var x = 0; x < kLcdWidth; x++) {
        // Unlit dots are drawn, not skipped. Seeing the dormant grid behind the
        // image is most of what makes this read as a real LCD.
        canvas.drawRect(
          Rect.fromLTWH((x * dotSize).toDouble(), top, dot, dot),
          buffer.get(x, y) ? onPaint : offPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LcdPainter old) =>
      old.frame != frame ||
      old.dotSize != dotSize ||
      !identical(old.buffer, buffer);
}
