import 'package:flutter/widgets.dart';

import '../game/screens/device_screen.dart';
import '../lcd/lcd_buffer.dart';
import '../lcd/lcd_theme.dart';
import '../sprites/icon_sprites.dart';

/// Seven dots tall, four columns of 7x7 icons at an eight-dot pitch.
const int kStripHeight = 7;
const int kStripSlots = 4;
const int kStripPitch = 8;

/// Where each icon sits on the bezel.
///
/// Both rows keep the same four-column grid. Re-centring the bottom three
/// would break the alignment between the strips and they would stop reading as
/// one piece of moulding — the empty fourth slot is where `train` was before D2
/// cut it. The order matches [DeviceIcon], so A moves the cursor left to right
/// and then along the bottom.
const List<List<DeviceIcon?>> kStripLayout = [
  [DeviceIcon.feed, DeviceIcon.wallow, DeviceIcon.play, DeviceIcon.meds],
  [DeviceIcon.clean, DeviceIcon.stats, DeviceIcon.light, null],
];

/// One strip's worth of dots, with only the icons [include] accepts drawn.
///
/// Called twice per strip — once for the lit icon, once for the dim ones — so
/// the painter can tell the two apart in a single pass.
LcdBuffer stripBuffer(
  List<DeviceIcon?> slots, {
  required bool Function(DeviceIcon) include,
}) {
  final buffer = LcdBuffer.sized(kLcdWidth, kStripHeight);
  for (var i = 0; i < slots.length; i++) {
    final icon = slots[i];
    if (icon == null || !include(icon)) continue;
    buffer.blit(kDeviceIcons[icon]!, i * kStripPitch, 0);
  }
  return buffer;
}

/// Draws a strip in two tones.
///
/// Two buffers rather than two stacked painters: the upper painter would paint
/// its own unlit dots over the lower one, and a strip would end up showing only
/// whichever tone was drawn last.
class IconStripPainter extends CustomPainter {
  const IconStripPainter({
    required this.lit,
    required this.dim,
    required this.dotSize,
    required this.frame,
  });

  final LcdBuffer lit;
  final LcdBuffer dim;
  final int dotSize;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = (dotSize - 1).toDouble();
    final onPaint = Paint()..color = LcdTheme.dotOn;
    final dimPaint = Paint()..color = LcdTheme.dotDim;
    final offPaint = Paint()..color = LcdTheme.dotOff;

    for (var y = 0; y < lit.height; y++) {
      final top = (y * dotSize).toDouble();
      for (var x = 0; x < lit.width; x++) {
        final paint = lit.get(x, y)
            ? onPaint
            : (dim.get(x, y) ? dimPaint : offPaint);
        canvas.drawRect(
          Rect.fromLTWH((x * dotSize).toDouble(), top, dot, dot),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(IconStripPainter old) =>
      old.frame != frame ||
      old.dotSize != dotSize ||
      !identical(old.lit, lit) ||
      !identical(old.dim, dim);
}

/// One row of the bezel.
class IconStrip extends StatelessWidget {
  const IconStrip({
    required this.slots,
    required this.selected,
    required this.dotSize,
    required this.frame,
    this.hidden,
    super.key,
  });

  final List<DeviceIcon?> slots;
  final DeviceIcon? selected;

  /// An icon blinked off this frame, because an action it asked for was
  /// refused.
  final DeviceIcon? hidden;

  final int dotSize;
  final int frame;

  @override
  Widget build(BuildContext context) {
    // `hidden` is excluded from both, not just from `dim`. A refusal almost
    // always lands on the icon the player has selected — that is how they
    // triggered it — so leaving the selected one lit would make the blink
    // invisible in exactly the case it exists for.
    final lit = stripBuffer(
      slots,
      include: (i) => i == selected && i != hidden,
    );
    final dim = stripBuffer(
      slots,
      include: (i) => i != selected && i != hidden,
    );
    return SizedBox(
      width: (kLcdWidth * dotSize).toDouble(),
      height: (kStripHeight * dotSize).toDouble(),
      child: CustomPaint(
        size: Size(
          (kLcdWidth * dotSize).toDouble(),
          (kStripHeight * dotSize).toDouble(),
        ),
        isComplex: false,
        willChange: true,
        painter: IconStripPainter(
          lit: lit,
          dim: dim,
          dotSize: dotSize,
          frame: frame,
        ),
      ),
    );
  }
}
