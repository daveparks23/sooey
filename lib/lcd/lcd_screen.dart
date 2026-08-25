import 'package:flutter/widgets.dart';

import 'lcd_buffer.dart';
import 'lcd_matrix.dart';
import 'lcd_painter.dart';
import 'lcd_theme.dart';

/// The green screen itself: sizes the dot grid to whole pixels, centres it, and
/// paints one frame.
class LcdScreen extends StatelessWidget {
  const LcdScreen({
    required this.buffer,
    required this.frame,
    this.padding = 4,
    super.key,
  });

  final LcdBuffer buffer;
  final int frame;

  /// Screen border around the dot grid, in dot-cells rather than pixels, so the
  /// bezel scales with the display instead of thinning out on large windows.
  final double padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(
          constraints.maxWidth - padding * 2,
          constraints.maxHeight - padding * 2,
        );
        final dotSize = lcdDotSize(available);

        return Container(
          color: LcdTheme.screen,
          alignment: Alignment.center,
          child: LcdMatrix(buffer: buffer, frame: frame, dotSize: dotSize),
        );
      },
    );
  }
}
