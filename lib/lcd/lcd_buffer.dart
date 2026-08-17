import 'lcd_sprite.dart';

/// Logical resolution of the display. Never change these — every sprite in the
/// game is authored against this grid.
const int kLcdWidth = 32;
const int kLcdHeight = 16;

/// A full frame of the dot-matrix display.
///
/// Composited fresh each frame and handed to a single painter, which is cheap:
/// 512 dots is nothing, and rebuilding avoids any question of stale state.
class LcdBuffer {
  /// The display. Every creature sprite is authored against this size.
  LcdBuffer() : this.sized(kLcdWidth, kLcdHeight);

  /// A buffer of any size. The icon strips are 32x7 pieces of the same glass.
  LcdBuffer.sized(this.width, this.height)
    : _pixels = List.generate(
        height,
        (_) => List<bool>.filled(width, false),
        growable: false,
      );

  final int width;
  final int height;

  final List<List<bool>> _pixels;

  bool get(int x, int y) => _pixels[y][x];

  /// Sets one dot. Out-of-bounds writes are dropped, matching [blit] — bars and
  /// pips are placed by arithmetic rather than by hand, and a dot one past the
  /// edge should nudge off-screen rather than crash the game.
  void set(int x, int y, bool on) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    _pixels[y][x] = on;
  }

  void clear() {
    for (var y = 0; y < height; y++) {
      _pixels[y].fillRange(0, width, false);
    }
  }

  /// Draws [sprite] with its top-left corner at ([dx], [dy]).
  ///
  /// Silently clips anything outside the display. Sprites are positioned by
  /// hand and a pig shuffling one dot past the edge should nudge off-screen,
  /// not crash the game.
  void blit(LcdSprite sprite, int dx, int dy) {
    for (var sy = 0; sy < sprite.rows.length; sy++) {
      final y = dy + sy;
      if (y < 0 || y >= height) continue;
      final row = sprite.rows[sy];
      final targetRow = _pixels[y];
      for (var sx = 0; sx < row.length; sx++) {
        final x = dx + sx;
        if (x < 0 || x >= width) continue;
        switch (row.codeUnitAt(sx)) {
          case LcdSprite.on:
            targetRow[x] = true;
          case LcdSprite.off:
            targetRow[x] = false;
          default: // transparent — leave whatever is underneath
            break;
        }
      }
    }
  }

  /// The frame as `#`/`.` text, one line per row.
  ///
  /// This is what makes the renderer testable: a golden frame is a string diff
  /// a human can read, not an image comparison.
  String toAscii() {
    final buffer = StringBuffer();
    for (var y = 0; y < height; y++) {
      if (y > 0) buffer.writeln();
      for (var x = 0; x < width; x++) {
        buffer.write(_pixels[y][x] ? '#' : '.');
      }
    }
    return buffer.toString();
  }

  @override
  String toString() => toAscii();
}
