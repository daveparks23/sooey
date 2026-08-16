/// A sprite is data, not an image.
///
/// There is no asset pipeline in this project and there should never be one: at
/// 32x16 the whole cast fits in a few hundred lines of source, diffs readably,
/// and costs nothing to load.
class LcdSprite {
  /// The plain constructor stays `const` so sprite files can be compile-time
  /// literals. It does not validate — [LcdSprite.checked] and [validate] do.
  const LcdSprite(this.width, this.height, this.rows);

  /// Validates as it builds. Used by the sprite editor and by the test that
  /// sweeps every registered sprite, where a named error beats a silent
  /// misdraw.
  factory LcdSprite.checked(
    int width,
    int height,
    List<String> rows, [
    String label = 'sprite',
  ]) {
    final s = LcdSprite(width, height, rows);
    s.validate(label);
    return s;
  }

  final int width;
  final int height;

  /// One string per row. `#` turns a dot on, `.` turns it off, and a space
  /// leaves whatever is underneath alone.
  ///
  /// The third state is what lets poops and status icons composite over the pig
  /// without punching holes in it.
  final List<String> rows;

  static const int on = 0x23; // '#'
  static const int off = 0x2E; // '.'
  static const int transparent = 0x20; // ' '

  /// Throws [ArgumentError] if the art does not match its declared size or uses
  /// a character outside the three-state alphabet. Sprites are hand-authored,
  /// so a typo is by far the likeliest defect.
  void validate([String label = 'sprite']) {
    if (rows.length != height) {
      throw ArgumentError(
        '$label: declared height $height but has ${rows.length} rows',
      );
    }
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      if (row.length != width) {
        throw ArgumentError(
          '$label: row $y declared width $width but is ${row.length}',
        );
      }
      for (var x = 0; x < row.length; x++) {
        final c = row.codeUnitAt(x);
        if (c != on && c != off && c != transparent) {
          throw ArgumentError(
            '$label: row $y column $x is "${row[x]}", '
            'expected one of "#", "." or " "',
          );
        }
      }
    }
  }
}
