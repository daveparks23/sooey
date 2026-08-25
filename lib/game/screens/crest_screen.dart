import '../../lcd/lcd_buffer.dart';
import '../../sprites/crest_sprites.dart';
import 'device_screen.dart';

/// Centred: (32 - 7) ~/ 2 and (16 - 7) ~/ 2.
const int _crestX = 12;
const int _crestY = 4;

/// Pick the emblem that marks this pig.
///
/// The first screen a new pet ever shows, and what the spec's name entry
/// became. You mark the egg before you know what is inside it.
class CrestScreen extends DeviceScreen {
  Crest crest = Crest.values.first;

  @override
  DeviceIcon? get litIcon => null;

  @override
  Transition handle(Button b, GameContext ctx) {
    switch (b) {
      case Button.a:
        crest = Crest.values[(crest.index + 1) % Crest.values.length];
        return const Stay();
      case Button.b:
        return Crested(crest);
      // Nothing behind this screen to go back to.
      case Button.c:
        return const Stay();
    }
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) {
    final buffer = LcdBuffer()..blit(kCrests[crest]!, _crestX, _crestY);

    // Chevrons either side, which is the only way a device with no text can say
    // "there are more of these".
    for (var i = 0; i < 3; i++) {
      buffer
        ..set(6 - i, 6 + i, true)
        ..set(6 - i, 10 - i, true)
        ..set(25 + i, 6 + i, true)
        ..set(25 + i, 10 - i, true);
    }
    return buffer;
  }
}
