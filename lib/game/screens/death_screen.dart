import '../../lcd/lcd_bars.dart';
import '../../lcd/lcd_buffer.dart';
import '../../sprites/sprite_registry.dart';
import 'device_screen.dart';

const int _millisPerDay = 24 * 60 * 60 * 1000;
const int _crestX = 0;
const int _crestY = 5;
const int _pipsX = 25;

/// The grave, the crest, and how long the pig lived. Nothing else.
///
/// Spec §8 is explicit: **do not show the care-mistake count, even after
/// death.** Keeping the judgment hidden is what makes a player start again to
/// find out how to do better, and a post-mortem scoreboard would spend the
/// whole game's premise on one screen.
class DeathScreen extends DeviceScreen {
  @override
  DeviceIcon? get litIcon => null;

  @override
  Transition handle(Button b, GameContext ctx) =>
      b == Button.b ? const Restart() : const Stay();

  @override
  LcdBuffer compose(GameContext ctx, int frame) {
    final buffer = LcdBuffer();

    // Composed here rather than through `composeFrame`, which short-circuits a
    // dead pet to a bare grave and returns before anything else can be drawn.
    final grave = kSpriteRegistry['prop.grave']!.a;
    buffer
      ..blit(
        grave,
        (kLcdWidth - grave.width) ~/ 2,
        (kLcdHeight - grave.height) ~/ 2,
      )
      ..blit(kCrests[ctx.crest]!, _crestX, _crestY);

    // The crest sits beside the stone, not on it: the grave already has RIP
    // punched through its middle and there is nowhere on a slab that size for a
    // second mark. Centred, it leaves seven or eight columns either side, which
    // is why the pips here are single dots at a two-dot pitch rather than the
    // blocks the stats page uses — twenty days has to fit in a gutter.
    final died = ctx.pet.diedAtMillis ?? ctx.nowMillis;
    drawPips(
      buffer,
      count: (died - ctx.pet.bornAtMillis) ~/ _millisPerDay,
      x: _pipsX,
      y: 0,
      perRow: 4,
      pitch: 2,
      size: 1,
    );
    return buffer;
  }
}
