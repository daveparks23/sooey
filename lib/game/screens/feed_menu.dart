import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_buffer.dart';
import '../../sprites/icon_sprites.dart';
import 'device_screen.dart';

/// Where the two icons sit, and where the caret sits under them.
///
/// Two 7-wide icons with a 2-dot gap span 16 columns, which centres at x = 8.
const int _slopX = 8;
const int _treatX = 17;
const int _iconY = 3;
const int _caretY = 12;

/// Slop or treat.
///
/// The one submenu in the game. Slop reuses the strip's feed icon — a trough is
/// a trough — and the treat is the apple spec §7.1 names.
class FeedMenu extends DeviceScreen {
  /// False is slop, the ordinary meal that schedules a poop. True is the apple.
  bool treat = false;

  @override
  DeviceIcon? get litIcon => DeviceIcon.feed;

  @override
  Transition handle(Button b, GameContext ctx) {
    switch (b) {
      case Button.a:
        treat = !treat;
        return const Stay();
      case Button.b:
        return Act(treat ? PetAction.treat : PetAction.slop);
      case Button.c:
        return const Pop();
    }
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) {
    final buffer = LcdBuffer()
      ..blit(kFeedIcon, _slopX, _iconY)
      ..blit(kTreatIcon, _treatX, _iconY);

    // A caret under the one B will take. Both choices stay on screen: a menu
    // that hid the alternative would need a second press to find out what it
    // was.
    final centre = (treat ? _treatX : _slopX) + 3;
    buffer
      ..set(centre, _caretY, true)
      ..set(centre - 1, _caretY + 1, true)
      ..set(centre, _caretY + 1, true)
      ..set(centre + 1, _caretY + 1, true);
    return buffer;
  }
}
