import 'package:flutter/widgets.dart';

import 'lcd_buffer.dart';
import 'lcd_painter.dart';

/// The dot grid at a dot size the caller chooses.
///
/// Split out of [LcdScreen] because the glass has to compute one dot size for
/// the matrix and both icon strips together: a strip that sized itself from its
/// own box would land on a different pitch, and the result reads as two screens
/// glued together rather than one piece of glass.
class LcdMatrix extends StatelessWidget {
  const LcdMatrix({
    required this.buffer,
    required this.frame,
    required this.dotSize,
    super.key,
  });

  final LcdBuffer buffer;
  final int frame;
  final int dotSize;

  @override
  Widget build(BuildContext context) {
    final size = Size(
      (buffer.width * dotSize).toDouble(),
      (buffer.height * dotSize).toDouble(),
    );
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        size: size,
        isComplex: false,
        willChange: true,
        painter: LcdPainter(buffer: buffer, frame: frame, dotSize: dotSize),
      ),
    );
  }
}
