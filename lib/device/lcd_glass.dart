import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../game/screens/device_screen.dart';
import '../lcd/lcd_buffer.dart';
import '../lcd/lcd_matrix.dart';
import '../lcd/lcd_painter.dart';
import '../lcd/lcd_theme.dart';
import 'icon_strip.dart';

const int kGlassWidth = kLcdWidth;

/// Top strip, gap, matrix, gap, bottom strip.
const int kGlassHeight = kStripHeight * 2 + kLcdHeight + 2;

/// One dot size for the whole glass.
///
/// Computed from the full 32x32 box rather than from the matrix, because every
/// part of the glass has to share a pitch. A strip that sized itself from its
/// own box would land on a different one and the result reads as two screens
/// glued together. Integer scaling only, for the reason `lcd_painter.dart`
/// already documents.
int glassDotSize(Size available) => math.max(
  kMinDotSize,
  math.min(available.width ~/ kGlassWidth, available.height ~/ kGlassHeight),
);

/// The whole piece of simulated LCD: two icon strips and the dot matrix.
class LcdGlass extends StatelessWidget {
  const LcdGlass({
    required this.buffer,
    required this.frame,
    this.selected,
    this.hidden,
    super.key,
  });

  final LcdBuffer buffer;
  final int frame;
  final DeviceIcon? selected;
  final DeviceIcon? hidden;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dotSize = glassDotSize(
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        final gap = SizedBox(height: dotSize.toDouble());

        return Container(
          color: LcdTheme.screen,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconStrip(
                slots: kStripLayout[0],
                selected: selected,
                hidden: hidden,
                dotSize: dotSize,
                frame: frame,
              ),
              gap,
              LcdMatrix(buffer: buffer, frame: frame, dotSize: dotSize),
              gap,
              IconStrip(
                slots: kStripLayout[1],
                selected: selected,
                hidden: hidden,
                dotSize: dotSize,
                frame: frame,
              ),
            ],
          ),
        );
      },
    );
  }
}
