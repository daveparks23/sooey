import 'package:flutter/painting.dart';

/// The device's palette, hardcoded.
///
/// This deliberately does not follow system dark mode. The whole point is that
/// it looks like one specific piece of 1996 plastic, and a plastic toy does not
/// have a dark theme.
abstract final class LcdTheme {
  /// A lit dot. Not quite black — real LCD segments never were.
  static const Color dotOn = Color(0xFF1C2410);

  /// An unlit dot, faintly visible against the screen. Drawing these rather
  /// than leaving them blank is most of what sells the illusion.
  static const Color dotOff = Color(0xFF93A667);

  /// An icon segment that is present but not selected. Sits between [dotOn] and
  /// [dotOff] so an unselected icon reads as dormant rather than as absent —
  /// which is how a real LCD's fixed segments behave.
  static const Color dotDim = Color(0xFF525E37);

  static const Color screen = Color(0xFF9CAF6E);

  static const Color shell = Color(0xFFE3A6B5);
  static const Color shellBorder = Color(0xFFC4899A);
  static const Color button = Color(0xFFC4899A);
}
