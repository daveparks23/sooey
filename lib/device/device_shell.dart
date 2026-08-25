import 'package:flutter/material.dart' hide Form;
import 'package:flutter/services.dart';

import '../game/clock.dart';
import '../game/game_controller.dart';
import '../game/screens/device_screen.dart';
import '../lcd/lcd_theme.dart';
import 'lcd_glass.dart';

/// One piece of 1996 plastic.
///
/// Deliberately does not follow system dark mode: a plastic toy does not have a
/// dark theme. The palette is fixed in [LcdTheme].
class DeviceShell extends StatelessWidget {
  const DeviceShell({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final button = _buttonFor(event.logicalKey);
        if (button == null) return KeyEventResult.ignored;
        controller.press(button);
        return KeyEventResult.handled;
      },
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Container(
          color: LcdTheme.shell,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LcdTheme.shellBorder,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: LcdGlass(
                      buffer: controller.compose(),
                      frame: controller.frame,
                      selected: controller.litIcon,
                      // Blinks on alternate frames, because a steady mark
                      // becomes furniture within a minute.
                      hidden: controller.frame.isEven
                          ? controller.blinkingIcon
                          : null,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final b in Button.values) ...[
                      DeviceButton(
                        key: ValueKey('button.${b.name}'),
                        onPressed: () => controller.press(b),
                      ),
                      const SizedBox(width: 28),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The keyboard, mapped onto the three buttons.
///
/// A cycles: left arrow or `a`. B confirms: enter, space or `b`. C cancels:
/// right arrow or `c`. The letters and space are there because this runs in a
/// browser as often as on a phone, and a device with three buttons should not
/// require you to find the arrow keys.
///
/// A key is a physical button by another name, which is why none of this
/// contradicts spec §6. Nothing on the glass or the bezel is tappable.
Button? _buttonFor(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
    return Button.a;
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.keyB) {
    return Button.b;
  }
  if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyC) {
    return Button.c;
  }
  return null;
}

class DeviceButton extends StatelessWidget {
  const DeviceButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: LcdTheme.button,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The device on the real clock. This is what `/` mounts.
class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameController(clock: const SystemClock())..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: DeviceShell(controller: _controller));
}
