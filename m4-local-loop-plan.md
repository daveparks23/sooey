# M4 — The Local Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the finished display into a playable device — a pet you can feed, clean, play with, and neglect to death — driven entirely by three buttons.

**Architecture:** A `GameController` owns the pet, a clock and a stack of screens, and is the only thing that mutates the pet. Screens are small objects that turn a button press into a `Transition` and a `GameContext` into an `LcdBuffer`; they never touch the pig. The glass grows an icon strip above and below the existing 32×16 matrix, all three on one shared dot pitch.

**Tech Stack:** Flutter (client), pure Dart (`packages/hog_sim`, untouched here), `flutter_test`.

**Spec:** [`m4-local-loop-design.md`](m4-local-loop-design.md) — read it before Task 1. [`HANDOFF.md`](HANDOFF.md) and [`pig-tomagotchi-spec.md`](pig-tomagotchi-spec.md) are its context.

## Global Constraints

- **Never modify `packages/hog_sim`.** Its golden vectors and dart2js agreement hang off it. If a change there seems necessary, stop and ask — it means something has been misunderstood.
- **`dart test -p chrome` must stay green.** Run it if you touch anything that `hog_sim` sees. Nothing in this plan should.
- **No text, no numerals, no font.** Quantities are bars, counts are pips, labels are icons. This is the milestone's defining constraint.
- **Age is never shown as a fraction.** Pips only, drawn one per elapsed day with no empty placeholders. A denominator would leak `expiresAt`, which encodes the hidden care-mistake count.
- **Mood must never read `careMistakes` or `stageCareMistakes`.** Nor may any refusal or feedback path put a false expression on the pig — the face is the one honest signal in the game.
- **`Form` collides with Flutter's form widget.** Any file importing both `hog_sim` and `material.dart` needs `hide Form` on the material import.
- **Sprites are hand-authored ASCII**, `#` lit, `.` unlit, space transparent. Every row must be exactly as wide as the declared width. Run `flutter test test/sprites/` after touching any.
- **Palette is fixed:** `LcdTheme.shell` `#E3A6B5`, border and buttons `#C4899A`.
- **Pre-existing failure:** `kGrave` in `lib/sprites/prop_sprites.dart` is mid-redraw and fails `validate()` (declared 16×12, has 14 rows). It is Dave's, deliberately left alone. `flutter test test/sprites/` will show exactly one failure — `every sprite in the cast is well formed` — from the start of this plan to the end. **Do not fix it, and do not let it mask a new failure.**
- **Never `git add` a directory. Stage files by explicit path.** `lib/sprites/prop_sprites.dart` is dirty with the WIP above for the whole life of this plan, and a directory-scoped add buries someone else's unversioned work in your commit under a message that does not mention it. This has already happened once here and cost a fix round to unpick.
- **To prove you have not touched a file, diff it against the base commit** — `git diff <base>..HEAD -- <path>` — never `git status`. A file can be untouched relative to the dirty tree you started in and still be modified by your commit.

---

## File Structure

**Created**

| Path | Responsibility |
| --- | --- |
| `lib/lcd/lcd_bars.dart` | `drawVerticalBar`, `drawHorizontalBar`, `drawPips` |
| `lib/lcd/lcd_matrix.dart` | the dot grid at a caller-supplied dot size |
| `lib/game/clock.dart` | `Clock`, `SystemClock`, `FakeClock` |
| `lib/game/game_constants.dart` | presentation tunables |
| `lib/game/game_controller.dart` | the pet, the clock, the screen stack |
| `lib/game/screens/device_screen.dart` | `Button`, `DeviceIcon`, `Crest`, `Transition`, `GameContext`, `DeviceScreen` |
| `lib/game/screens/home_screen.dart` | the pig plus a live icon strip |
| `lib/game/screens/feed_menu.dart` | slop or treat |
| `lib/game/screens/stats_screen.dart` | three status pages |
| `lib/game/screens/truffle_hunt.dart` | the five-round minigame |
| `lib/game/screens/crest_screen.dart` | pick the emblem that marks this pig |
| `lib/game/screens/death_screen.dart` | grave, crest, age |
| `lib/sprites/icon_sprites.dart` | 7 strip icons, the apple, the weight mark |
| `lib/sprites/crest_sprites.dart` | 8 crests, 3 rosettes |
| `lib/device/icon_strip.dart` | strip layout, buffers and its two-tone painter |
| `lib/device/lcd_glass.dart` | strips + matrix on one dot pitch |
| `lib/device/device_shell.dart` | the pink plastic, three buttons, keyboard |
| `lib/dev/device_dev_page.dart` | the same device on a `FakeClock` |

**Modified**

| Path | Change |
| --- | --- |
| `lib/lcd/lcd_buffer.dart` | `width`/`height` become fields; add `.sized()` and `set()` |
| `lib/lcd/lcd_screen.dart` | rewritten in terms of `LcdMatrix` |
| `lib/lcd/lcd_theme.dart` | add `dotDim` |
| `lib/lcd/lcd.dart` | export the two new files |
| `lib/sprites/prop_sprites.dart` | add `kMound` |
| `lib/sprites/sprite_registry.dart` | register icons, crests, rosettes, mound |
| `lib/main.dart` | `/` becomes the device; dev menu moves to `/dev` |
| `test/sprites/sprite_registry_test.dart` | two sweeps iterate creatures, not the whole registry |

---

## Task 1: The buffer, the tone, and the matrix widget

**Files:**
- Modify: `lib/lcd/lcd_buffer.dart`
- Modify: `lib/lcd/lcd_theme.dart:20`
- Create: `lib/lcd/lcd_matrix.dart`
- Modify: `lib/lcd/lcd_screen.dart`
- Modify: `lib/lcd/lcd.dart:9`
- Test: `test/lcd/lcd_buffer_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `LcdBuffer.sized(int width, int height)`, `LcdBuffer.set(int x, int y, bool on)`, `LcdBuffer.width`/`height` as instance fields; `LcdTheme.dotDim`; `LcdMatrix({required LcdBuffer buffer, required int frame, required int dotSize})`.

- [ ] **Step 1: Write the failing tests**

Append to `test/lcd/lcd_buffer_test.dart`, inside `main()`:

```dart
  group('LcdBuffer.sized', () {
    test('takes its own dimensions rather than the display constants', () {
      final b = LcdBuffer.sized(32, 7);
      expect(b.width, 32);
      expect(b.height, 7);
    });

    test('clips a blit at its own edges, not the display size', () {
      // The icon strips are 7 rows tall. A strip that clipped at row 16 would
      // write past the end of its own pixel rows.
      final b = LcdBuffer.sized(8, 3)..blit(sprite('####\n####\n####\n####'), 6, 1);
      expect(b.get(6, 1), isTrue);
      expect(b.get(7, 2), isTrue);
      expect(b.toAscii().split('\n').length, 3);
    });

    test('toAscii reports its own shape', () {
      final lines = LcdBuffer.sized(5, 2).toAscii().split('\n');
      expect(lines.length, 2);
      expect(lines.first.length, 5);
    });

    test('the default constructor is still the display size', () {
      final b = LcdBuffer();
      expect(b.width, 32);
      expect(b.height, 16);
    });
  });

  group('LcdBuffer.set', () {
    test('turns a single dot on and off', () {
      final b = LcdBuffer()
        ..set(3, 4, true);
      expect(b.get(3, 4), isTrue);
      b.set(3, 4, false);
      expect(b.get(3, 4), isFalse);
    });

    test('drops out-of-bounds writes rather than throwing', () {
      // Bars and pips are positioned by arithmetic, not by hand, so a dot one
      // past the edge should nudge off-screen exactly as a blit does.
      final b = LcdBuffer()
        ..set(-1, 0, true)
        ..set(32, 0, true)
        ..set(0, 16, true);
      expect(b.toAscii(), LcdBuffer().toAscii());
    });
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/lcd/lcd_buffer_test.dart`
Expected: FAIL — `The method 'LcdBuffer.sized' isn't defined`, `The method 'set' isn't defined`.

- [ ] **Step 3: Rewrite `lib/lcd/lcd_buffer.dart`**

Replace the class header, the `width`/`height` getters, and every use of `kLcdWidth`/`kLcdHeight` inside the class with the instance fields. `kLcdWidth`/`kLcdHeight` stay declared at the top of the file — they are the sprite-authoring grid and other files import them.

```dart
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
```

In `blit`, change the two bounds checks from `kLcdHeight`/`kLcdWidth` to `height`/`width`. In `toAscii`, change both loop bounds the same way. Leave every doc comment as it is.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/lcd/`
Expected: PASS, all of it — the existing buffer and painter tests included.

- [ ] **Step 5: Add the dim tone**

In `lib/lcd/lcd_theme.dart`, after `dotOff`:

```dart
  /// An icon segment that is present but not selected. Sits between [dotOn] and
  /// [dotOff] so an unselected icon reads as dormant rather than as absent —
  /// which is how a real LCD's fixed segments behave.
  static const Color dotDim = Color(0xFF525E37);
```

- [ ] **Step 6: Split the matrix out of `LcdScreen`**

Create `lib/lcd/lcd_matrix.dart`:

```dart
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
```

Rewrite the `build` of `lib/lcd/lcd_screen.dart` to use it, keeping the class's doc comment, constructor and `padding` behaviour exactly as they are:

```dart
        return Container(
          color: LcdTheme.screen,
          alignment: Alignment.center,
          child: LcdMatrix(buffer: buffer, frame: frame, dotSize: dotSize),
        );
```

Delete the now-unused `grid` local and the `lcd_painter.dart` import if the analyzer flags it; keep `lcdDotSize`.

Add one line to `lib/lcd/lcd.dart`:

```dart
export 'lcd_matrix.dart';
```

Only that one. `lcd_bars.dart` does not exist until Task 2, which adds its own export in its Step 4.

- [ ] **Step 7: Run the full Flutter suite**

Run: `flutter test`
Expected: PASS except the one known `kGrave` failure. `renders crisply at three window widths` must still pass — it reaches through `find.byType(CustomPaint).first` and that path now goes through `LcdMatrix`.

- [ ] **Step 8: Commit**

```bash
git add lib/lcd test/lcd
git commit -m "feat(lcd): size buffers independently, add a dim tone and LcdMatrix"
```

---

## Task 2: Bars and pips

**Files:**
- Create: `lib/lcd/lcd_bars.dart`
- Modify: `lib/lcd/lcd.dart`
- Test: `test/lcd/lcd_bars_test.dart`

**Interfaces:**
- Consumes: `LcdBuffer.set` (Task 1).
- Produces: `drawVerticalBar(LcdBuffer, {required int x, required int y, required int width, required int height, required double fraction})`, `drawHorizontalBar` with the same signature, `drawPips(LcdBuffer, {required int count, required int x, required int y, int perRow, int pitch, int size})`.

- [ ] **Step 1: Write the failing test**

Create `test/lcd/lcd_bars_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/lcd/lcd.dart';

void main() {
  group('drawVerticalBar', () {
    test('draws an outline even when empty, so a flat need still reads', () {
      final b = LcdBuffer();
      drawVerticalBar(b, x: 0, y: 0, width: 7, height: 9, fraction: 0);
      expect(b.get(0, 0), isTrue, reason: 'top-left corner');
      expect(b.get(6, 8), isTrue, reason: 'bottom-right corner');
      expect(b.get(3, 4), isFalse, reason: 'interior stays empty');
    });

    test('fills from the bottom', () {
      final b = LcdBuffer();
      drawVerticalBar(b, x: 0, y: 0, width: 7, height: 9, fraction: 0.5);
      expect(b.get(3, 7), isTrue, reason: 'lowest interior row fills first');
      expect(b.get(3, 1), isFalse, reason: 'highest interior row fills last');
    });

    test('a full bar fills every interior row', () {
      final b = LcdBuffer();
      drawVerticalBar(b, x: 0, y: 0, width: 7, height: 9, fraction: 1);
      for (var y = 1; y <= 7; y++) {
        expect(b.get(3, y), isTrue, reason: 'row $y');
      }
    });

    test('0 and 100 are visibly different', () {
      final empty = LcdBuffer();
      final full = LcdBuffer();
      drawVerticalBar(empty, x: 0, y: 0, width: 7, height: 9, fraction: 0);
      drawVerticalBar(full, x: 0, y: 0, width: 7, height: 9, fraction: 1);
      expect(empty.toAscii(), isNot(full.toAscii()));
    });

    test('clamps a fraction outside 0..1 rather than drawing outside itself', () {
      final b = LcdBuffer();
      drawVerticalBar(b, x: 0, y: 0, width: 7, height: 9, fraction: 5);
      expect(b.get(3, 9), isFalse, reason: 'spilled past the outline');
    });
  });

  group('drawHorizontalBar', () {
    test('fills from the left', () {
      final b = LcdBuffer();
      drawHorizontalBar(b, x: 0, y: 0, width: 22, height: 5, fraction: 0.5);
      expect(b.get(1, 2), isTrue, reason: 'leftmost interior column fills first');
      expect(b.get(20, 2), isFalse, reason: 'rightmost fills last');
    });

    test('draws an outline even when empty', () {
      final b = LcdBuffer();
      drawHorizontalBar(b, x: 0, y: 0, width: 22, height: 5, fraction: 0);
      expect(b.get(0, 0), isTrue);
      expect(b.get(21, 4), isTrue);
    });
  });

  group('drawPips', () {
    test('draws one pip per count and nothing for the rest', () {
      // No empty placeholders: an unfilled slot would imply a total, and the
      // total is the pig's lifespan, which the player must never be shown.
      final b = LcdBuffer();
      drawPips(b, count: 3, x: 1, y: 0);
      expect(b.get(1, 0), isTrue, reason: 'pip 1');
      expect(b.get(4, 0), isTrue, reason: 'pip 2');
      expect(b.get(7, 0), isTrue, reason: 'pip 3');
      expect(b.get(10, 0), isFalse, reason: 'pip 4 must not be outlined');
    });

    test('wraps onto the next row', () {
      final b = LcdBuffer();
      drawPips(b, count: 11, x: 1, y: 0, perRow: 10);
      expect(b.get(1, 3), isTrue, reason: 'eleventh pip starts a second row');
    });

    test('draws nothing at all for a count of zero', () {
      final b = LcdBuffer();
      drawPips(b, count: 0, x: 1, y: 0);
      expect(b.toAscii(), LcdBuffer().toAscii());
    });

    test('honours a tighter pip for cramped gutters', () {
      // The death screen has seven columns beside the grave and up to twenty
      // days to show, so it uses single dots at a two-dot pitch.
      final b = LcdBuffer();
      drawPips(b, count: 20, x: 25, y: 0, perRow: 4, pitch: 2, size: 1);
      expect(b.get(25, 0), isTrue);
      expect(b.get(31, 8), isTrue, reason: 'twentieth pip still on screen');
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/lcd/lcd_bars_test.dart`
Expected: FAIL — `Undefined name 'drawVerticalBar'`.

- [ ] **Step 3: Write the implementation**

Create `lib/lcd/lcd_bars.dart`:

```dart
import 'lcd_buffer.dart';

/// Quantities, drawn rather than written.
///
/// The device shows no text and no numerals, so every number the player is
/// allowed to know reaches them as a filled track or a row of marks. See the
/// note on pips below — one of these rules protects the game's premise rather
/// than its style.

/// An outlined track filled from the bottom.
///
/// The outline is drawn whether or not there is anything in it: an empty bar
/// and an absent bar have to be tellable apart, or a pig with one need at zero
/// looks like a pig with a rendering fault.
void drawVerticalBar(
  LcdBuffer buffer, {
  required int x,
  required int y,
  required int width,
  required int height,
  required double fraction,
}) {
  _outline(buffer, x, y, width, height);
  final innerHeight = height - 2;
  final filled = (_clamp01(fraction) * innerHeight).round();
  for (var i = 0; i < filled; i++) {
    final row = y + height - 2 - i;
    for (var col = x + 1; col < x + width - 1; col++) {
      buffer.set(col, row, true);
    }
  }
}

/// An outlined track filled from the left.
void drawHorizontalBar(
  LcdBuffer buffer, {
  required int x,
  required int y,
  required int width,
  required int height,
  required double fraction,
}) {
  _outline(buffer, x, y, width, height);
  final innerWidth = width - 2;
  final filled = (_clamp01(fraction) * innerWidth).round();
  for (var i = 0; i < filled; i++) {
    final col = x + 1 + i;
    for (var row = y + 1; row < y + height - 1; row++) {
      buffer.set(col, row, true);
    }
  }
}

/// A row of marks, one per unit, wrapping every [perRow].
///
/// **Only lit pips are drawn.** There are deliberately no empty placeholders:
/// an outlined row of twenty slots would imply a denominator, and the
/// denominator for age is `expiresAt`, which is fixed from the care-mistake
/// count the player is never allowed to see. A count can grow forever; a
/// fraction gives the game away.
void drawPips(
  LcdBuffer buffer, {
  required int count,
  required int x,
  required int y,
  int perRow = 10,
  int pitch = 3,
  int size = 2,
}) {
  for (var i = 0; i < count; i++) {
    final px = x + (i % perRow) * pitch;
    final py = y + (i ~/ perRow) * pitch;
    for (var dy = 0; dy < size; dy++) {
      for (var dx = 0; dx < size; dx++) {
        buffer.set(px + dx, py + dy, true);
      }
    }
  }
}

void _outline(LcdBuffer buffer, int x, int y, int width, int height) {
  for (var i = 0; i < width; i++) {
    buffer.set(x + i, y, true);
    buffer.set(x + i, y + height - 1, true);
  }
  for (var j = 0; j < height; j++) {
    buffer.set(x, y + j, true);
    buffer.set(x + width - 1, y + j, true);
  }
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
```

- [ ] **Step 4: Export it and run the tests**

Add `export 'lcd_bars.dart';` to `lib/lcd/lcd.dart`.

Run: `flutter test test/lcd/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/lcd/lcd_bars.dart lib/lcd/lcd.dart test/lcd/lcd_bars_test.dart
git commit -m "feat(lcd): draw bars and pips"
```

---

## Task 3: The clock

**Files:**
- Create: `lib/game/clock.dart`
- Test: `test/game/clock_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `abstract interface class Clock { int get nowMillis; }`, `const SystemClock()`, `FakeClock(int millis)` with `nowMillis` settable and `void advance(int millis)`.

- [ ] **Step 1: Write the failing test**

Create `test/game/clock_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/game/clock.dart';

void main() {
  group('FakeClock', () {
    test('reports the time it was given', () {
      expect(FakeClock(1755000000000).nowMillis, 1755000000000);
    });

    test('advances by a delta', () {
      final c = FakeClock(1000)..advance(500);
      expect(c.nowMillis, 1500);
    });

    test('can be set outright, for jumping a day forward', () {
      final c = FakeClock(1000)..nowMillis = 99;
      expect(c.nowMillis, 99);
    });
  });

  group('SystemClock', () {
    test('is somewhere in the present century', () {
      // Loose on purpose: this is the one place a real clock is read, and the
      // only thing worth asserting is that it is wired to one.
      const c = SystemClock();
      expect(c.nowMillis, greaterThan(1600000000000));
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/game/clock_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:sooey/game/clock.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/game/clock.dart`:

```dart
/// Where the game reads the time.
///
/// `advance` takes an `int nowMillis` rather than reading a clock itself, which
/// is what makes the simulation pure. This interface is the client's half of
/// that bargain: the device runs on [SystemClock], the dev harness runs the same
/// widget on a [FakeClock], and nothing between them knows the difference.
abstract interface class Clock {
  int get nowMillis;
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  int get nowMillis => DateTime.now().millisecondsSinceEpoch;
}

/// A clock the caller drives.
///
/// Deliberately dumb: it holds a number and nothing else. Speed multipliers and
/// jump buttons belong to the dev page that owns one, not in here, so tests can
/// step it exactly where they want it.
class FakeClock implements Clock {
  FakeClock(this.nowMillis);

  @override
  int nowMillis;

  void advance(int millis) => nowMillis += millis;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/game/clock_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/game/clock.dart test/game/clock_test.dart
git commit -m "feat(game): add an injectable clock"
```

---

## Task 4: The screen contract

**Files:**
- Create: `lib/game/screens/device_screen.dart`
- Create: `lib/game/game_constants.dart`
- Create: `test/game/screens/screen_test_support.dart`
- Test: `test/game/screens/device_screen_test.dart`

**Interfaces:**
- Consumes: `LcdBuffer` (Task 1).
- Produces:
  - `enum Button { a, b, c }`
  - `enum DeviceIcon { feed, wallow, play, meds, clean, stats, light }`
  - `enum Crest { leaf, star, horseshoe, clover, crown, moon, anchor, bolt }`
  - `class GameContext { PetState pet; Crest crest; int nowMillis; PetPose? transientPose; }`
  - `sealed class Transition` with `Stay`, `Push(DeviceScreen screen)`, `Pop`, `Act(PetAction action)`, `Played(int wins)`, `Crested(Crest crest)`, `Restart`
  - `abstract class DeviceScreen` with `Transition handle(Button, GameContext)`, `LcdBuffer compose(GameContext, int frame)`, `Transition update(GameContext) => const Stay()`, `DeviceIcon? get litIcon`
  - Test helpers: `List<Transition> drive(DeviceScreen, String presses, GameContext)`, `PetState testPet({...})`, `GameContext testContext({...})`, `const int kRefNoon`
  - Constants: `kTransientPoseMillis`, `kRefusalBlinkMillis`, `kHuntRevealMillis`, `kHuntSlide`

- [ ] **Step 1: Write the constants**

Create `lib/game/game_constants.dart`:

```dart
/// Tunables for how the device presents itself. The simulation's numbers all
/// live in `hog_sim`'s `constants.dart`; these are about feel, not balance, and
/// none of them may reach the simulation.
library;

/// How long the pig holds an action's pose after the player triggers it.
///
/// Long enough to notice, short enough that it is clearly a reaction rather
/// than a state — feeding the pig should visibly make it eat, not silently move
/// a number.
const int kTransientPoseMillis = 3000;

/// How long a refused action blinks the icon that refused it.
///
/// Refusals blink an icon rather than changing the pig's face. The face reads
/// current needs only and has to stay honest: a pig that looked miserable
/// because a button did nothing would be lying about how it feels.
const int kRefusalBlinkMillis = 1800;

/// How long the pig stays at the mound before the next truffle-hunt round.
const int kHuntRevealMillis = 1500;

/// How far the pig moves when it commits to a mound, in dots.
const int kHuntSlide = 9;
```

- [ ] **Step 2: Write the failing test**

Create `test/game/screens/screen_test_support.dart`:

```dart
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/sprites/sprite_registry.dart';

/// Noon UTC. The pig sleeps from 22:00 to 07:00 in its own local time, so a
/// test that wants a waking pig starts here.
const int kRefNoon = 1755000000000;

/// A pet with no history, posed however the test needs it.
PetState testPet({
  Stage stage = Stage.adult,
  Form form = Form.farmHog,
  double fullness = 80,
  double enrichment = 80,
  double comfort = 80,
  double cleanliness = 80,
  double health = 80,
  double weight = 70,
  bool isSick = false,
  bool lightsOn = true,
  int poops = 0,
  int nowMillis = kRefNoon,
  int ageDays = 7,
  DeathCause? deathCause,
}) {
  var pet = PetState.newborn(
    petId: 'pet_test',
    ownerId: 'uid_test',
    name: '',
    nowMillis: nowMillis - ageDays * 86400000,
    utcOffsetMinutes: 0,
  ).copyWith(
    stage: stage,
    form: form,
    lastTickAtMillis: nowMillis,
    fullness: fullness,
    enrichment: enrichment,
    comfort: comfort,
    cleanliness: cleanliness,
    health: health,
    weight: weight,
    isSick: isSick,
    lightsOn: lightsOn,
    poops: List.generate(poops, (i) => i),
  );
  if (deathCause != null) {
    pet = pet.copyWith(diedAtMillis: nowMillis, deathCause: deathCause);
  }
  return pet;
}

GameContext testContext({
  PetState? pet,
  Crest crest = Crest.leaf,
  int nowMillis = kRefNoon,
  PetPose? transientPose,
}) => GameContext(
  pet: pet ?? testPet(nowMillis: nowMillis),
  crest: crest,
  nowMillis: nowMillis,
  transientPose: transientPose,
);

/// Drives a screen with a string of presses and collects what it asked for.
///
/// This is the whole reason screens do not touch the pet: a press sequence is a
/// test, with no controller, no clock and no simulation in play.
List<Transition> drive(DeviceScreen screen, String presses, GameContext ctx) {
  const buttons = {'A': Button.a, 'B': Button.b, 'C': Button.c};
  return [
    for (final ch in presses.split(''))
      screen.handle(
        buttons[ch] ?? (throw ArgumentError('not a button: $ch')),
        ctx,
      ),
  ];
}
```

Create `test/game/screens/device_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/lcd/lcd.dart';

import 'screen_test_support.dart';

/// The smallest screen that satisfies the contract, so the contract itself can
/// be tested without dragging a real one in.
class _Nothing extends DeviceScreen {
  @override
  DeviceIcon? get litIcon => null;

  @override
  Transition handle(Button b, GameContext ctx) => const Stay();

  @override
  LcdBuffer compose(GameContext ctx, int frame) => LcdBuffer();
}

void main() {
  group('the icon order', () {
    test('is the order A cycles, feed first and light last', () {
      // The strip's two rows are laid out from this order, so changing it moves
      // icons on the glass as well as under the cursor.
      expect(DeviceIcon.values.map((i) => i.name).toList(), [
        'feed',
        'wallow',
        'play',
        'meds',
        'clean',
        'stats',
        'light',
      ]);
    });

    test('has seven icons, train having been cut by D2', () {
      expect(DeviceIcon.values.length, 7);
    });
  });

  group('Crest', () {
    test('offers eight emblems', () {
      expect(Crest.values.length, 8);
    });
  });

  group('DeviceScreen', () {
    test('does nothing on update unless it overrides it', () {
      expect(_Nothing().update(testContext()), isA<Stay>());
    });

    test('composes a display-sized buffer', () {
      final buffer = _Nothing().compose(testContext(), 0);
      expect(buffer.width, 32);
      expect(buffer.height, 16);
    });
  });

  group('drive', () {
    test('returns one transition per press', () {
      expect(drive(_Nothing(), 'ABC', testContext()), hasLength(3));
    });

    test('rejects a character that is not a button', () {
      expect(() => drive(_Nothing(), 'X', testContext()), throwsArgumentError);
    });
  });

  group('testPet', () {
    test('builds a living adult by default', () {
      final pet = testPet();
      expect(pet.isDead, isFalse);
      expect(pet.stage, Stage.adult);
    });

    test('builds a dead one on request', () {
      expect(testPet(deathCause: DeathCause.neglect).isDead, isTrue);
    });
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/game/screens/device_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:sooey/game/screens/device_screen.dart'`.

- [ ] **Step 4: Write the implementation**

Create `lib/game/screens/device_screen.dart`:

```dart
import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_buffer.dart';
import '../../sprites/sprite_registry.dart';

/// The device's three physical buttons. There are no others, and nothing on the
/// glass or the shell responds to a tap — spec §6 calls that constraint the
/// charm and it is taken literally.
enum Button { a, b, c }

/// The strip icons, in the order A cycles through them.
///
/// The strip's layout is derived from this order: the first four sit above the
/// matrix and the rest below. `train` is absent — D2 cut the discipline
/// mechanic from v1.
enum DeviceIcon { feed, wallow, play, meds, clean, stats, light }

/// The emblem that marks one pig.
///
/// This is what the spec's name became. The 1996 original never let you name a
/// pet, and a twelve-slot letter picker is the worst screen a three-button
/// device can have. A crest does the same job — it makes the pig yours, and it
/// is what ends up beside the grave.
enum Crest { leaf, star, horseshoe, clover, crown, moon, anchor, bolt }

/// Everything a screen is allowed to know.
///
/// Read-only by construction. Screens decide what a press *means*; the
/// controller decides what it *does*. That split is what lets a screen be
/// tested with a string of presses and nothing else.
class GameContext {
  const GameContext({
    required this.pet,
    required this.crest,
    required this.nowMillis,
    this.transientPose,
  });

  final PetState pet;
  final Crest crest;
  final int nowMillis;

  /// Set for a few seconds after an accepted action, so the pig visibly
  /// responds to it.
  final PetPose? transientPose;
}

/// What a screen wants to happen next.
///
/// Sealed, so the controller's switch over it is checked by the compiler — a
/// new transition cannot be added without every handler being made to consider
/// it.
sealed class Transition {
  const Transition();
}

class Stay extends Transition {
  const Stay();
}

class Push extends Transition {
  const Push(this.screen);
  final DeviceScreen screen;
}

class Pop extends Transition {
  const Pop();
}

/// Apply an action to the pet, then leave the screen that asked for it.
class Act extends Transition {
  const Act(this.action);
  final PetAction action;
}

/// A finished truffle hunt, for `applyMinigame` to validate.
class Played extends Transition {
  const Played(this.wins);
  final int wins;
}

/// The crest is chosen and the pig's life begins.
class Crested extends Transition {
  const Crested(this.crest);
  final Crest crest;
}

/// Start over with a new pet, from the death screen.
class Restart extends Transition {
  const Restart();
}

/// One screen of the device.
///
/// Not `sealed`: Dart only allows that when every subtype is in the same
/// library, and the point of this structure is that each screen is its own
/// small file. Nothing switches over screen types, so sealing would buy
/// nothing.
abstract class DeviceScreen {
  /// Turns a press into an intent. Never touches the pet.
  Transition handle(Button b, GameContext ctx);

  /// Draws the matrix. Pure — no clock reads, no state changes.
  LcdBuffer compose(GameContext ctx, int frame);

  /// Called once per animation frame, before [compose], for screens whose state
  /// moves without a press.
  ///
  /// Only the truffle hunt overrides this: its reveal has to end on its own.
  /// Doing that inside [compose] would put a mutation in a render path and
  /// every other screen would inherit the hazard.
  Transition update(GameContext ctx) => const Stay();

  /// Which strip icon stays lit while this screen is on top, or null for the
  /// screens that are not reached from the strip at all.
  DeviceIcon? get litIcon;
}
```

The `sprite_registry.dart` import is for `PetPose`, which is declared there rather than in `hog_sim`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/game/`
Expected: PASS. Nine of those tests are new — the directory already holds `frame_composer_test.dart`, `pet_appearance_test.dart` and `clock_test.dart`, so the run's total is much larger than nine. Report what you observe.

- [ ] **Step 6: Commit**

```bash
git add lib/game test/game
git commit -m "feat(game): define the screen contract and its test harness"
```

---

## Task 5: The strip icons, the apple and the weight mark

**Files:**
- Create: `lib/sprites/icon_sprites.dart`
- Modify: `lib/sprites/prop_sprites.dart`
- Modify: `lib/sprites/sprite_registry.dart`
- Modify: `test/sprites/sprite_registry_test.dart:41-75`
- Test: `test/sprites/icon_sprites_test.dart`

**Interfaces:**
- Consumes: `DeviceIcon` (Task 4).
- Produces: `kFeedIcon`, `kWallowIcon`, `kPlayIcon`, `kMedsIcon`, `kCleanIcon`, `kStatsIcon`, `kLightIcon`, `kTreatIcon`, `kWeightIcon` — all `LcdSprite(7, 7)`; `kMound` — `LcdSprite(5, 3)`; `const Map<DeviceIcon, LcdSprite> kDeviceIcons`.

All art here is **starter art**. The handoff records that Dave's redraws have been right every time the earlier work disagreed; hand these over and take his versions.

- [ ] **Step 1: Fix the two registry sweeps that these would break**

`creature animations move between their two frames` and `keep the creature planted on the same floor line` currently iterate the whole registry and skip keys starting `prop.`. A still icon at `icon.feed` would fail both. Filtering by prefix would work today and rot the first time a category is added, so make them iterate the creatures they are actually about.

In `test/sprites/sprite_registry_test.dart`, replace the bodies of both tests' loops:

```dart
    test('move between their two frames', () {
      // A creature whose frames are identical is a pig that looks like a
      // rendering bug. Iterate the creatures rather than filtering the registry
      // by prefix, so adding icons or crests cannot quietly narrow this.
      for (final key in kCreatureKeys) {
        final anim = kSpriteRegistry[key]!;
        expect(
          anim.a.rows.join(),
          isNot(anim.b.rows.join()),
          reason: '$key does not animate',
        );
      }
    });

    test('keep the creature planted on the same floor line', () {
      // The lowest lit row must not jump between frames, or the pig appears to
      // hop rather than shift its weight. Wallowing is exempt: the mud is
      // supposed to slosh.
      int lowestLitRow(LcdSprite s) {
        for (var y = s.rows.length - 1; y >= 0; y--) {
          if (s.rows[y].contains('#')) return y;
        }
        return -1;
      }

      for (final key in kCreatureKeys) {
        if (key.endsWith('.wallowing')) continue;
        final anim = kSpriteRegistry[key]!;
        expect(
          lowestLitRow(anim.a),
          lowestLitRow(anim.b),
          reason: '$key shifts its floor line between frames',
        );
      }
    });
```

Add to `lib/sprites/sprite_registry.dart`, below `kBuildKeys`:

```dart
/// Every registry key that is a creature — the things that must animate and
/// must stay on their floor line. Props, icons and crests are none of those.
List<String> get kCreatureKeys => [
  'egg',
  for (final build in kBuildKeys)
    for (final pose in kRequiredPoses) '$build.$pose',
];
```

- [ ] **Step 2: Run the sweep to confirm it still passes unchanged**

Run: `flutter test test/sprites/`
Expected: the one known `kGrave` failure and nothing else. If a second test fails, the refactor is wrong — the two rewritten sweeps must cover exactly what they covered before.

- [ ] **Step 3: Write the failing test**

Create `test/sprites/icon_sprites_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/sprites/icon_sprites.dart';

void main() {
  group('the strip icons', () {
    test('cover every icon the cursor can reach', () {
      // A missing icon would be an invisible strip slot the player can still
      // select and press, which reads as a broken button.
      for (final icon in DeviceIcon.values) {
        expect(kDeviceIcons[icon], isNotNull, reason: icon.name);
      }
    });

    test('are all one size, so the strip is a grid rather than a jumble', () {
      for (final entry in kDeviceIcons.entries) {
        expect(entry.value.width, 7, reason: entry.key.name);
        expect(entry.value.height, 7, reason: entry.key.name);
      }
    });

    test('are well formed', () {
      kDeviceIcons.forEach((icon, sprite) => sprite.validate(icon.name));
      kTreatIcon.validate('kTreatIcon');
      kWeightIcon.validate('kWeightIcon');
    });

    test('are all distinguishable from one another', () {
      // Two icons that render identically make one of them unpressable in
      // practice: the player cannot tell which slot the cursor is on.
      final shapes = kDeviceIcons.values.map((s) => s.rows.join()).toSet();
      expect(shapes.length, kDeviceIcons.length);
    });

    test('each draw something', () {
      for (final entry in kDeviceIcons.entries) {
        expect(
          entry.value.rows.any((r) => r.contains('#')),
          isTrue,
          reason: '${entry.key.name} is blank',
        );
      }
    });
  });
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `flutter test test/sprites/icon_sprites_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:sooey/sprites/icon_sprites.dart'`.

- [ ] **Step 5: Write the art**

Create `lib/sprites/icon_sprites.dart`:

```dart
import '../game/screens/device_screen.dart';
import '../lcd/lcd_sprite.dart';

/// The icons on the bezel.
///
/// All 7x7, because the strip is a four-column grid and a ragged one would read
/// as a jumble rather than a row of fixed segments. Unlike the props these are
/// opaque — an icon sits on bare glass, so there is nothing underneath for a
/// transparent cell to reveal.

/// Feed. A trough, seen end-on. Doubles as slop in the feed submenu.
const kFeedIcon = LcdSprite(7, 7, [
  '.......',
  '#.....#',
  '#######',
  '.#####.',
  '.#####.',
  '..###..',
  '.......',
]);

/// Wallow. A puddle with something splashing out of it.
const kWallowIcon = LcdSprite(7, 7, [
  '.......',
  '..#.#..',
  '.#...#.',
  '#######',
  '.#####.',
  '..###..',
  '.......',
]);

/// Play. The truffle the hunt is for.
const kPlayIcon = LcdSprite(7, 7, [
  '..###..',
  '.#####.',
  '#######',
  '#######',
  '#######',
  '.#####.',
  '..###..',
]);

/// Meds. A cross — the only shape that survives being this small and still
/// means medicine.
const kMedsIcon = LcdSprite(7, 7, [
  '..###..',
  '..###..',
  '#######',
  '#######',
  '#######',
  '..###..',
  '..###..',
]);

/// Clean. A yard brush on the diagonal.
const kCleanIcon = LcdSprite(7, 7, [
  '....##.',
  '...##..',
  '..##...',
  '.####..',
  '#####..',
  '#####..',
  '.......',
]);

/// Stats. A rising bar chart, which is what the screen behind it is.
const kStatsIcon = LcdSprite(7, 7, [
  '.......',
  '.....#.',
  '....##.',
  '...###.',
  '..####.',
  '.#####.',
  '#######',
]);

/// Light. A sun with rays, rather than a bulb — a bulb at 7x7 is a blob.
const kLightIcon = LcdSprite(7, 7, [
  '...#...',
  '.#...#.',
  '..###..',
  '#.###.#',
  '..###..',
  '.#...#.',
  '...#...',
]);

/// Treat. Spec §7.1 names it an apple, so it is one. Only ever seen in the feed
/// submenu, beside [kFeedIcon] standing in for slop.
const kTreatIcon = LcdSprite(7, 7, [
  '...#...',
  '..##...',
  '.#####.',
  '#######',
  '#######',
  '.#####.',
  '..###..',
]);

/// Weight, on the second stats page. A balance.
const kWeightIcon = LcdSprite(7, 7, [
  '...#...',
  '.#####.',
  '#..#..#',
  '...#...',
  '...#...',
  '..###..',
  '.#####.',
]);

/// Every strip icon by the cursor position that reaches it.
const Map<DeviceIcon, LcdSprite> kDeviceIcons = {
  DeviceIcon.feed: kFeedIcon,
  DeviceIcon.wallow: kWallowIcon,
  DeviceIcon.play: kPlayIcon,
  DeviceIcon.meds: kMedsIcon,
  DeviceIcon.clean: kCleanIcon,
  DeviceIcon.stats: kStatsIcon,
  DeviceIcon.light: kLightIcon,
};
```

Add to the end of `lib/sprites/prop_sprites.dart`:

```dart
/// A mound of earth with a truffle under it. Two of these are the whole set
/// dressing of the truffle hunt.
///
/// Note the transparent surround: a mound is composited over the pig after the
/// pig is drawn, so it must not punch a hole in the ground around itself.
const kMound = LcdSprite(5, 3, [' .#. ', '.###.', '#####']);
```

- [ ] **Step 6: Register them**

In `lib/sprites/sprite_registry.dart`, add `import 'icon_sprites.dart';` and `export 'icon_sprites.dart';`, then a new section at the end of `kSpriteRegistry` (before the closing brace):

```dart
  // --- Icons ----------------------------------------------------------------
  // Registered so the well-formedness sweep covers them and the sprite editor
  // can load them. They are still, which is why the animation sweeps iterate
  // kCreatureKeys rather than filtering this map.
  'icon.feed': SpriteAnim.still(
    kFeedIcon,
    dartName: 'kFeedIcon',
    sourceFile: _icons,
  ),
  'icon.wallow': SpriteAnim.still(
    kWallowIcon,
    dartName: 'kWallowIcon',
    sourceFile: _icons,
  ),
  'icon.play': SpriteAnim.still(
    kPlayIcon,
    dartName: 'kPlayIcon',
    sourceFile: _icons,
  ),
  'icon.meds': SpriteAnim.still(
    kMedsIcon,
    dartName: 'kMedsIcon',
    sourceFile: _icons,
  ),
  'icon.clean': SpriteAnim.still(
    kCleanIcon,
    dartName: 'kCleanIcon',
    sourceFile: _icons,
  ),
  'icon.stats': SpriteAnim.still(
    kStatsIcon,
    dartName: 'kStatsIcon',
    sourceFile: _icons,
  ),
  'icon.light': SpriteAnim.still(
    kLightIcon,
    dartName: 'kLightIcon',
    sourceFile: _icons,
  ),
  'icon.treat': SpriteAnim.still(
    kTreatIcon,
    dartName: 'kTreatIcon',
    sourceFile: _icons,
  ),
  'icon.weight': SpriteAnim.still(
    kWeightIcon,
    dartName: 'kWeightIcon',
    sourceFile: _icons,
  ),
  'prop.mound': SpriteAnim.still(
    kMound,
    dartName: 'kMound',
    sourceFile: _props,
  ),
```

And beside the other source-file constants:

```dart
const _icons = 'lib/sprites/icon_sprites.dart';
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/sprites/`
Expected: PASS except the one known `kGrave` failure. If `every sprite in the cast is well formed` now reports an icon as well as the grave, an icon row is the wrong width — count it.

- [ ] **Step 8: Commit**

```bash
git add lib/sprites test/sprites
git commit -m "feat(sprites): add the strip icons, the apple, the weight mark and a mound"
```

---

## Task 6: Crests and rosettes

**Files:**
- Create: `lib/sprites/crest_sprites.dart`
- Modify: `lib/sprites/sprite_registry.dart`
- Test: `test/sprites/crest_sprites_test.dart`

**Interfaces:**
- Consumes: `Crest` (Task 4), `Form` (`hog_sim`).
- Produces: `const Map<Crest, LcdSprite> kCrests`, `const Map<Form, LcdSprite> kRosettes`, `LcdSprite rosetteFor(Form form)` — all sprites `LcdSprite(7, 7)`.

- [ ] **Step 1: Write the failing test**

Create `test/sprites/crest_sprites_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/sprites/crest_sprites.dart';

void main() {
  group('crests', () {
    test('cover every emblem the picker can land on', () {
      for (final crest in Crest.values) {
        expect(kCrests[crest], isNotNull, reason: crest.name);
      }
    });

    test('are 7x7, the size the death screen gutter allows', () {
      // Centred, a 16-wide grave leaves eight columns either side. A 9x9 crest
      // would not fit, which is why the picker shows them at this size too.
      for (final entry in kCrests.entries) {
        expect(entry.value.width, 7, reason: entry.key.name);
        expect(entry.value.height, 7, reason: entry.key.name);
      }
    });

    test('are all distinguishable', () {
      // The crest is what makes one pig yours. Two that render the same would
      // make the choice meaningless.
      final shapes = kCrests.values.map((s) => s.rows.join()).toSet();
      expect(shapes.length, kCrests.length);
    });

    test('are well formed', () {
      kCrests.forEach((crest, sprite) => sprite.validate(crest.name));
    });
  });

  group('rosettes', () {
    test('cover the three adult builds', () {
      for (final form in [Form.prizeHog, Form.farmHog, Form.runt]) {
        expect(kRosettes[form], isNotNull, reason: form.name);
      }
    });

    test('rank the builds by how much rosette there is', () {
      // The rosette replaces the text label Dave asked for, so it has to carry
      // the same ranking a caption would: a placing at a county show.
      int litDots(Form f) =>
          rosetteFor(f).rows.fold(0, (n, r) => n + r.split('#').length - 1);

      expect(litDots(Form.prizeHog), greaterThan(litDots(Form.farmHog)));
      expect(litDots(Form.farmHog), greaterThan(litDots(Form.runt)));
    });

    test('fall back to the farm hog for a form that never reaches adulthood', () {
      // `base` should never get here — the form is fixed at the piglet->adult
      // transition — but a pet seeded mid-development might, and a crash on the
      // stats page is a worse answer than the reference build.
      expect(rosetteFor(Form.base), kRosettes[Form.farmHog]);
    });

    test('are well formed and 7x7', () {
      kRosettes.forEach((form, sprite) {
        sprite.validate(form.name);
        expect(sprite.width, 7, reason: form.name);
        expect(sprite.height, 7, reason: form.name);
      });
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/sprites/crest_sprites_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:sooey/sprites/crest_sprites.dart'`.

- [ ] **Step 3: Write the art**

Create `lib/sprites/crest_sprites.dart`:

```dart
import 'package:hog_sim/hog_sim.dart';

import '../game/screens/device_screen.dart';
import '../lcd/lcd_sprite.dart';

/// The mark that makes one pig yours, and the ribbon it earns.
///
/// All 7x7 — the same grid as the strip icons. One scale across the whole
/// device is what keeps a crest, an icon and a rosette looking like parts of
/// the same object rather than three borrowed pictures. The death screen's
/// gutter is the binding constraint: centred, a 16-wide grave leaves eight
/// columns either side.

const kCrestLeaf = LcdSprite(7, 7, [
  '......#',
  '.....##',
  '..####.',
  '.#####.',
  '#####..',
  '.###...',
  '#......',
]);

const kCrestStar = LcdSprite(7, 7, [
  '...#...',
  '...#...',
  '#######',
  '.#####.',
  '..###..',
  '.##.##.',
  '##...##',
]);

const kCrestHorseshoe = LcdSprite(7, 7, [
  '.#####.',
  '##...##',
  '##...##',
  '##...##',
  '##...##',
  '#.....#',
  '#.....#',
]);

const kCrestClover = LcdSprite(7, 7, [
  '.##.##.',
  '#######',
  '#######',
  '.#####.',
  '..###..',
  '...#...',
  '...#...',
]);

const kCrestCrown = LcdSprite(7, 7, [
  '#..#..#',
  '#.###.#',
  '#######',
  '#######',
  '#######',
  '#######',
  '.......',
]);

const kCrestMoon = LcdSprite(7, 7, [
  '..###..',
  '.##....',
  '###....',
  '###....',
  '###....',
  '.##....',
  '..###..',
]);

const kCrestAnchor = LcdSprite(7, 7, [
  '...#...',
  '..###..',
  '...#...',
  '.#####.',
  '#..#..#',
  '#..#..#',
  '.#####.',
]);

const kCrestBolt = LcdSprite(7, 7, [
  '....##.',
  '...##..',
  '..###..',
  '.#####.',
  '..##...',
  '.##....',
  '##.....',
]);

const Map<Crest, LcdSprite> kCrests = {
  Crest.leaf: kCrestLeaf,
  Crest.star: kCrestStar,
  Crest.horseshoe: kCrestHorseshoe,
  Crest.clover: kCrestClover,
  Crest.crown: kCrestCrown,
  Crest.moon: kCrestMoon,
  Crest.anchor: kCrestAnchor,
  Crest.bolt: kCrestBolt,
};

/// The prize hog's ribbon: a full rosette with streamers.
const kPrizeRosette = LcdSprite(7, 7, [
  '..###..',
  '.#####.',
  '##.#.##',
  '.#####.',
  '..###..',
  '.##.##.',
  '##...##',
]);

/// The farm hog's: a plain ribbon.
const kFarmRosette = LcdSprite(7, 7, [
  '..###..',
  '.#####.',
  '..###..',
  '...#...',
  '...#...',
  '..#.#..',
  '..#.#..',
]);

/// The runt's: a bare button, no ribbon at all.
const kRuntRosette = LcdSprite(7, 7, [
  '.......',
  '..###..',
  '.#####.',
  '.#####.',
  '..###..',
  '.......',
  '.......',
]);

const Map<Form, LcdSprite> kRosettes = {
  Form.prizeHog: kPrizeRosette,
  Form.farmHog: kFarmRosette,
  Form.runt: kRuntRosette,
};

/// The ribbon for an adult build.
///
/// `base` never reaches adulthood — the form is fixed at the piglet->adult
/// transition — but a pet seeded mid-development might, so it falls back to the
/// reference build rather than crashing the stats page.
LcdSprite rosetteFor(Form form) => kRosettes[form] ?? kFarmRosette;
```

- [ ] **Step 4: Register them**

In `lib/sprites/sprite_registry.dart`, add `import 'crest_sprites.dart';`, `export 'crest_sprites.dart';`, `const _crests = 'lib/sprites/crest_sprites.dart';`, and this section at the end of `kSpriteRegistry`:

```dart
  // --- Crests and ribbons ---------------------------------------------------
  'crest.leaf': SpriteAnim.still(
    kCrestLeaf,
    dartName: 'kCrestLeaf',
    sourceFile: _crests,
  ),
  'crest.star': SpriteAnim.still(
    kCrestStar,
    dartName: 'kCrestStar',
    sourceFile: _crests,
  ),
  'crest.horseshoe': SpriteAnim.still(
    kCrestHorseshoe,
    dartName: 'kCrestHorseshoe',
    sourceFile: _crests,
  ),
  'crest.clover': SpriteAnim.still(
    kCrestClover,
    dartName: 'kCrestClover',
    sourceFile: _crests,
  ),
  'crest.crown': SpriteAnim.still(
    kCrestCrown,
    dartName: 'kCrestCrown',
    sourceFile: _crests,
  ),
  'crest.moon': SpriteAnim.still(
    kCrestMoon,
    dartName: 'kCrestMoon',
    sourceFile: _crests,
  ),
  'crest.anchor': SpriteAnim.still(
    kCrestAnchor,
    dartName: 'kCrestAnchor',
    sourceFile: _crests,
  ),
  'crest.bolt': SpriteAnim.still(
    kCrestBolt,
    dartName: 'kCrestBolt',
    sourceFile: _crests,
  ),
  'rosette.prizeHog': SpriteAnim.still(
    kPrizeRosette,
    dartName: 'kPrizeRosette',
    sourceFile: _crests,
  ),
  'rosette.farmHog': SpriteAnim.still(
    kFarmRosette,
    dartName: 'kFarmRosette',
    sourceFile: _crests,
  ),
  'rosette.runt': SpriteAnim.still(
    kRuntRosette,
    dartName: 'kRuntRosette',
    sourceFile: _crests,
  ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/sprites/`
Expected: PASS except the one known `kGrave` failure.

- [ ] **Step 6: Commit**

```bash
git add lib/sprites/crest_sprites.dart lib/sprites/sprite_registry.dart \
        test/sprites/crest_sprites_test.dart
git commit -m "feat(sprites): add eight crests and three rosettes"
```

**Stage those three paths and nothing else.** `lib/sprites/prop_sprites.dart` carries an uncommitted work-in-progress edit that is not yours; `git add lib/sprites` would sweep it into your commit. That has already happened once in this plan.

---

## Task 7: The home screen

**Files:**
- Create: `lib/game/screens/home_screen.dart`
- Test: `test/game/screens/home_screen_test.dart`

**Interfaces:**
- Consumes: `DeviceScreen`, `Button`, `DeviceIcon`, `Transition` (Task 4); `composeFrame` (`lib/game/frame_composer.dart`); `FeedMenu`, `StatsScreen`, `TruffleHunt` (Tasks 8–10).
- Produces: `class HomeScreen extends DeviceScreen` with a mutable `DeviceIcon? selected`.

**Build order note:** this task references three screens that do not exist yet. Write it with the three `Push` cases stubbed to `const Stay()` and a `// Task 8/9/10` comment on each, get its own tests green, then restore them in Task 10's final step. The alternative — building the leaves first — would leave four tasks untestable in isolation.

- [ ] **Step 1: Write the failing test**

Create `test/game/screens/home_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/home_screen.dart';

import 'screen_test_support.dart';

void main() {
  group('the cursor', () {
    test('starts on nothing, so the pig is not framed by a menu at rest', () {
      expect(HomeScreen().litIcon, isNull);
    });

    test('lands on feed with the first press of A', () {
      final s = HomeScreen();
      drive(s, 'A', testContext());
      expect(s.selected, DeviceIcon.feed);
    });

    test('visits every icon exactly once in a lap', () {
      final s = HomeScreen();
      final visited = <DeviceIcon>[];
      for (var i = 0; i < DeviceIcon.values.length; i++) {
        drive(s, 'A', testContext());
        visited.add(s.selected!);
      }
      expect(visited.toSet(), DeviceIcon.values.toSet());
    });

    test('comes back to where it started after seven presses', () {
      final s = HomeScreen()..selected = DeviceIcon.feed;
      drive(s, 'AAAAAAA', testContext());
      expect(s.selected, DeviceIcon.feed);
    });

    test('C clears the selection rather than leaving the screen', () {
      // Home is the root of the stack. C here has nothing to pop to, so it
      // means "never mind" instead.
      final s = HomeScreen()..selected = DeviceIcon.meds;
      final out = drive(s, 'C', testContext());
      expect(s.selected, isNull);
      expect(out.single, isA<Stay>());
    });
  });

  group('B', () {
    test('does nothing while nothing is selected', () {
      expect(drive(HomeScreen(), 'B', testContext()).single, isA<Stay>());
    });

    test('acts directly for the icons that have no submenu', () {
      const direct = {
        DeviceIcon.wallow: PetAction.wallow,
        DeviceIcon.clean: PetAction.clean,
        DeviceIcon.meds: PetAction.meds,
        DeviceIcon.light: PetAction.light,
      };
      direct.forEach((icon, action) {
        final s = HomeScreen()..selected = icon;
        final out = drive(s, 'B', testContext()).single;
        expect(out, isA<Act>(), reason: icon.name);
        expect((out as Act).action, action, reason: icon.name);
      });
    });
  });

  group('the frame', () {
    test('is the pig, drawn by the composer that is already tested', () {
      final ctx = testContext();
      expect(
        HomeScreen().compose(ctx, 0).toAscii(),
        composeFrame(ctx.pet, frame: 0, nowMillis: ctx.nowMillis).toAscii(),
      );
    });

    test('shows the egg without any code that knows what an egg is', () {
      // creatureAnim already returns the egg for Stage.egg and applyAction
      // already refuses everything but the light until it hatches, so home
      // needs no egg screen and no special case.
      final ctx = testContext(pet: testPet(stage: Stage.egg, ageDays: 0));
      expect(HomeScreen().compose(ctx, 0).toAscii(), contains('#'));
    });

    test('passes the transient pose through, so an action visibly lands', () {
      final ctx = testContext(transientPose: PetPose.eating);
      final plain = testContext();
      expect(
        HomeScreen().compose(ctx, 0).toAscii(),
        isNot(HomeScreen().compose(plain, 0).toAscii()),
      );
    });
  });
}
```

Add `import 'package:sooey/game/frame_composer.dart';` and `import 'package:sooey/sprites/sprite_registry.dart';` to that file for `composeFrame` and `PetPose`.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/game/screens/home_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:sooey/game/screens/home_screen.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/game/screens/home_screen.dart`:

```dart
import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_buffer.dart';
import '../frame_composer.dart';
import 'device_screen.dart';

/// The device at rest: the pig on the matrix, the strip live around it.
///
/// The root of the stack and the only screen the player can reach without
/// having chosen something first. It has no egg or hatch special case —
/// `creatureAnim` already returns the egg for `Stage.egg`, and `applyAction`
/// already refuses everything but the light until it hatches, so the first
/// fifteen minutes of a pig's life need no code of their own.
class HomeScreen extends DeviceScreen {
  /// Null means the cursor is parked and the pig is unframed. A device sitting
  /// on the shelf should not look like a menu.
  DeviceIcon? selected;

  @override
  DeviceIcon? get litIcon => selected;

  @override
  Transition handle(Button b, GameContext ctx) {
    switch (b) {
      case Button.a:
        selected = _next(selected);
        return const Stay();

      case Button.b:
        final icon = selected;
        if (icon == null) return const Stay();
        return switch (icon) {
          // Task 8/9/10 restore these three.
          DeviceIcon.feed => const Stay(),
          DeviceIcon.play => const Stay(),
          DeviceIcon.stats => const Stay(),
          DeviceIcon.wallow => const Act(PetAction.wallow),
          DeviceIcon.clean => const Act(PetAction.clean),
          DeviceIcon.meds => const Act(PetAction.meds),
          DeviceIcon.light => const Act(PetAction.light),
        };

      // Nothing to pop to from the root, so C parks the cursor instead.
      case Button.c:
        selected = null;
        return const Stay();
    }
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) => composeFrame(
    ctx.pet,
    frame: frame,
    nowMillis: ctx.nowMillis,
    transientPose: ctx.transientPose,
  );
}

/// Cycles the cursor, starting it at the first icon from parked.
DeviceIcon _next(DeviceIcon? current) => current == null
    ? DeviceIcon.values.first
    : DeviceIcon.values[(current.index + 1) % DeviceIcon.values.length];
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/game/screens/home_screen_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/game/screens/home_screen.dart test/game/screens/home_screen_test.dart
git commit -m "feat(game): add the home screen and its icon cursor"
```

---

## Task 8: The feed submenu

**Files:**
- Create: `lib/game/screens/feed_menu.dart`
- Test: `test/game/screens/feed_menu_test.dart`

**Interfaces:**
- Consumes: `DeviceScreen` (Task 4), `kFeedIcon`, `kTreatIcon` (Task 5).
- Produces: `class FeedMenu extends DeviceScreen` with a mutable `bool treat`.

- [ ] **Step 1: Write the failing test**

Create `test/game/screens/feed_menu_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';

import 'screen_test_support.dart';

void main() {
  test('opens on slop, the ordinary meal', () {
    expect(FeedMenu().treat, isFalse);
  });

  test('keeps the feed icon lit while it is open', () {
    // The strip is how the player knows where they are. Losing the highlight
    // on the way into a submenu would read as having left the menu.
    expect(FeedMenu().litIcon, DeviceIcon.feed);
  });

  test('A toggles between the two', () {
    final s = FeedMenu();
    drive(s, 'A', testContext());
    expect(s.treat, isTrue);
    drive(s, 'A', testContext());
    expect(s.treat, isFalse);
  });

  test('B feeds whichever is showing', () {
    final slop = drive(FeedMenu(), 'B', testContext()).single;
    expect((slop as Act).action, PetAction.slop);

    final treat = drive(FeedMenu(), 'AB', testContext()).last;
    expect((treat as Act).action, PetAction.treat);
  });

  test('C backs out without feeding anything', () {
    expect(drive(FeedMenu(), 'C', testContext()).single, isA<Pop>());
  });

  group('the frame', () {
    test('draws both choices, so the alternative is visible', () {
      final ascii = FeedMenu().compose(testContext(), 0).toAscii();
      expect(ascii, contains('#'));
    });

    test('marks the two choices differently', () {
      // The caret is the only thing that says which one B will pick.
      final slop = FeedMenu().compose(testContext(), 0).toAscii();
      final treat = (FeedMenu()..treat = true).compose(testContext(), 0).toAscii();
      expect(slop, isNot(treat));
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/game/screens/feed_menu_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/game/screens/feed_menu.dart`:

```dart
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/game/screens/feed_menu_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/game/screens/feed_menu.dart test/game/screens/feed_menu_test.dart
git commit -m "feat(game): add the feed submenu"
```

---

## Task 9: The stats pages

**Files:**
- Create: `lib/game/screens/stats_screen.dart`
- Test: `test/game/screens/stats_screen_test.dart`

**Interfaces:**
- Consumes: `DeviceScreen` (Task 4), `drawVerticalBar`/`drawHorizontalBar`/`drawPips` (Task 2), `kDeviceIcons`/`kWeightIcon` (Task 5), `rosetteFor` (Task 6), `kHeart` (existing).
- Produces: `class StatsScreen extends DeviceScreen` with a mutable `int page` and `static const int pageCount = 3`.

- [ ] **Step 1: Write the failing test**

Create `test/game/screens/stats_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/stats_screen.dart';

import 'screen_test_support.dart';

void main() {
  group('paging', () {
    test('opens on the needs', () {
      expect(StatsScreen().page, 0);
    });

    test('B moves forward and wraps, so every page is reachable', () {
      final s = StatsScreen();
      for (var i = 1; i < StatsScreen.pageCount; i++) {
        drive(s, 'B', testContext());
        expect(s.page, i);
      }
      drive(s, 'B', testContext());
      expect(s.page, 0);
    });

    test('C leaves', () {
      expect(drive(StatsScreen(), 'C', testContext()).single, isA<Pop>());
    });

    test('keeps the stats icon lit throughout', () {
      expect(StatsScreen().litIcon, DeviceIcon.stats);
    });
  });

  group('the needs page', () {
    test('draws a different frame for a starving pig than a full one', () {
      final hungry = testContext(pet: testPet(fullness: 0));
      final fed = testContext(pet: testPet(fullness: 100));
      expect(
        StatsScreen().compose(hungry, 0).toAscii(),
        isNot(StatsScreen().compose(fed, 0).toAscii()),
      );
    });

    test('shows all four needs at once rather than paging them', () {
      // One bar per need with its own icon beneath. Four separate pages would
      // make comparing them impossible, which is the only thing the page is for.
      for (final name in kNeedNames) {
        final low = testContext(pet: testPet().withNeed(name, 0));
        final high = testContext(pet: testPet().withNeed(name, 100));
        expect(
          StatsScreen().compose(low, 0).toAscii(),
          isNot(StatsScreen().compose(high, 0).toAscii()),
          reason: '$name does not reach the needs page',
        );
      }
    });
  });

  group('the body page', () {
    test('reflects health', () {
      final ill = testContext(pet: testPet(health: 5));
      final well = testContext(pet: testPet(health: 100));
      final s = StatsScreen()..page = 1;
      expect(s.compose(ill, 0).toAscii(), isNot(s.compose(well, 0).toAscii()));
    });

    test('reflects weight', () {
      final thin = testContext(pet: testPet(weight: 25));
      final fat = testContext(pet: testPet(weight: 115));
      final s = StatsScreen()..page = 1;
      expect(s.compose(thin, 0).toAscii(), isNot(s.compose(fat, 0).toAscii()));
    });
  });

  group('the life page', () {
    test('shows one pip per elapsed day', () {
      final young = testContext(pet: testPet(ageDays: 1));
      final old = testContext(pet: testPet(ageDays: 9));
      final s = StatsScreen()..page = 2;
      expect(s.compose(young, 0).toAscii(), isNot(s.compose(old, 0).toAscii()));
    });

    test('shows the rosette only once the pig is an adult', () {
      // The three builds already differ by skull width; the ribbon is the label
      // Dave asked for, and a piglet has not been judged yet.
      final s = StatsScreen()..page = 2;
      final piglet = testContext(pet: testPet(stage: Stage.piglet, ageDays: 2));
      final adult = testContext(pet: testPet(stage: Stage.adult, ageDays: 2));
      expect(s.compose(piglet, 0).toAscii(), isNot(s.compose(adult, 0).toAscii()));
    });

    test('gives the three builds different ribbons', () {
      final s = StatsScreen()..page = 2;
      final shapes = {
        for (final form in [Form.prizeHog, Form.farmHog, Form.runt])
          s.compose(testContext(pet: testPet(form: form)), 0).toAscii(),
      };
      expect(shapes.length, 3);
    });

    test('never draws an empty pip slot', () {
      // An outlined row of slots would imply a denominator, and the denominator
      // is the lifespan, which is set from the hidden care-mistake count. A
      // count may grow forever; a fraction gives the game away.
      //
      // Two days on a piglet is 2 pips of 4 dots and no rosette, so anything
      // beyond 8 lit dots means empty slots are being outlined.
      final s = StatsScreen()..page = 2;
      final two = s.compose(
        testContext(pet: testPet(stage: Stage.piglet, ageDays: 2)),
        0,
      );
      final lit = two.toAscii().split('').where((c) => c == '#').length;
      expect(lit, 8, reason: 'pips should be a count, not a track');
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/game/screens/stats_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/game/screens/stats_screen.dart`:

```dart
import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_bars.dart';
import '../../lcd/lcd_buffer.dart';
import '../../sprites/crest_sprites.dart';
import '../../sprites/icon_sprites.dart';
import '../../sprites/prop_sprites.dart';
import 'device_screen.dart';

const int _millisPerDay = 24 * 60 * 60 * 1000;

/// Four columns, one per need: a 7-wide bar over its own icon.
const int _columnPitch = 8;
const int _barHeight = 9;
const int _needIconY = 9;

/// The status pages.
///
/// Nothing here is written. A bar says how much, a pip says how many, and the
/// label under a bar is the icon you would press to fix it — which is a better
/// label than a word, because it also tells you what to do about it.
class StatsScreen extends DeviceScreen {
  static const int pageCount = 3;

  int page = 0;

  @override
  DeviceIcon? get litIcon => DeviceIcon.stats;

  @override
  Transition handle(Button b, GameContext ctx) {
    switch (b) {
      case Button.b:
        page = (page + 1) % pageCount;
        return const Stay();
      case Button.c:
        return const Pop();
      case Button.a:
        return const Stay();
    }
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) => switch (page) {
    0 => _needsPage(ctx),
    1 => _bodyPage(ctx),
    _ => _lifePage(ctx),
  };

  /// All four needs at once. Paging them would make the only useful thing —
  /// seeing which one is lowest — impossible.
  LcdBuffer _needsPage(GameContext ctx) {
    const icons = [
      kFeedIcon, // fullness
      kPlayIcon, // enrichment
      kWallowIcon, // comfort
      kCleanIcon, // cleanliness
    ];
    final buffer = LcdBuffer();
    for (var i = 0; i < kNeedNames.length; i++) {
      final x = i * _columnPitch;
      drawVerticalBar(
        buffer,
        x: x,
        y: 0,
        width: 7,
        height: _barHeight,
        fraction: ctx.pet.need(kNeedNames[i]) / 100,
      );
      buffer.blit(icons[i], x, _needIconY);
    }
    return buffer;
  }

  LcdBuffer _bodyPage(GameContext ctx) {
    final buffer = LcdBuffer()..blit(kHeart, 1, 1);
    drawHorizontalBar(
      buffer,
      x: 9,
      y: 1,
      width: 22,
      height: 5,
      fraction: ctx.pet.health / 100,
    );
    buffer.blit(kWeightIcon, 0, 9);
    drawHorizontalBar(
      buffer,
      x: 9,
      y: 10,
      width: 22,
      height: 5,
      fraction: (ctx.pet.weight - kWeightMin) / (kWeightMax - kWeightMin),
    );
    return buffer;
  }

  LcdBuffer _lifePage(GameContext ctx) {
    final buffer = LcdBuffer();
    final days = (ctx.nowMillis - ctx.pet.bornAtMillis) ~/ _millisPerDay;
    drawPips(buffer, count: days, x: 1, y: 0);

    // Only an adult has a build to show. A piglet has not been judged yet, and
    // the judging is the one thing the player must never watch happen.
    if (ctx.pet.stage == Stage.adult) {
      buffer.blit(rosetteFor(ctx.pet.form), 12, 9);
    }
    return buffer;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/game/screens/stats_screen_test.dart`
Expected: PASS, 12 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/game/screens/stats_screen.dart test/game/screens/stats_screen_test.dart
git commit -m "feat(game): add the three stats pages"
```

---

## Task 10: The truffle hunt

**Files:**
- Create: `lib/game/screens/truffle_hunt.dart`
- Modify: `lib/game/screens/home_screen.dart` (restore the three `Push` cases)
- Test: `test/game/screens/truffle_hunt_test.dart`

**Interfaces:**
- Consumes: `DeviceScreen` (Task 4), `kMound`/`kHeart` (Task 5 / existing), `creatureAnim`/`moodFor`, `kHuntRevealMillis`/`kHuntSlide` (Task 4), `kPlayRounds` (`hog_sim`).
- Produces: `class TruffleHunt extends DeviceScreen` with `TruffleHunt({Random? random})`, `List<bool?> results`, `int round`, `int get wins`, `bool get revealing`.

- [ ] **Step 1: Write the failing test**

Create `test/game/screens/truffle_hunt_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/game_constants.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/truffle_hunt.dart';

import 'screen_test_support.dart';

/// A pig that always goes left, so a test can choose to win or lose.
class _AlwaysLeft implements Random {
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}

/// Runs one round to its conclusion: guess, then let the reveal expire.
void playRound(TruffleHunt hunt, Button guess, {required int at}) {
  hunt.handle(guess, testContext(nowMillis: at));
  hunt.update(testContext(nowMillis: at + kHuntRevealMillis + 1));
}

void main() {
  group('a round', () {
    test('A guesses left and C guesses right', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.a, testContext());
      expect(hunt.results.first, isTrue, reason: 'guessed left, pig went left');

      final missed = TruffleHunt(random: _AlwaysLeft());
      missed.handle(Button.c, testContext());
      expect(missed.results.first, isFalse, reason: 'guessed right');
    });

    test('B does nothing — the guess is A or C, per spec 7.4', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.b, testContext());
      expect(hunt.results.first, isNull);
      expect(hunt.round, 0);
    });

    test('ignores further guesses while the pig is still snuffling', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.a, testContext(nowMillis: kRefNoon));
      hunt.handle(Button.c, testContext(nowMillis: kRefNoon + 10));
      expect(hunt.round, 0);
      expect(hunt.results[1], isNull, reason: 'a second round started early');
    });

    test('does not advance until the reveal has run its course', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      hunt.handle(Button.a, testContext(nowMillis: kRefNoon));
      hunt.update(testContext(nowMillis: kRefNoon + kHuntRevealMillis - 1));
      expect(hunt.round, 0, reason: 'cut the reveal short');
      hunt.update(testContext(nowMillis: kRefNoon + kHuntRevealMillis + 1));
      expect(hunt.round, 1);
    });
  });

  group('the match', () {
    test('is best of five and reports the wins', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      var at = kRefNoon;
      for (var i = 0; i < kPlayRounds - 1; i++) {
        playRound(hunt, i.isEven ? Button.a : Button.c, at: at);
        at += kHuntRevealMillis * 2;
      }
      hunt.handle(Button.a, testContext(nowMillis: at));
      final out = hunt.update(
        testContext(nowMillis: at + kHuntRevealMillis + 1),
      );
      expect(out, isA<Played>());
      // Rounds 0, 2, 4 guessed left against a pig that always goes left.
      expect((out as Played).wins, 3);
    });

    test('a perfect match reports five', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      var at = kRefNoon;
      Transition last = const Stay();
      for (var i = 0; i < kPlayRounds; i++) {
        hunt.handle(Button.a, testContext(nowMillis: at));
        last = hunt.update(testContext(nowMillis: at + kHuntRevealMillis + 1));
        at += kHuntRevealMillis * 2;
      }
      expect((last as Played).wins, kPlayRounds);
    });

    test('keeps the play icon lit', () {
      expect(TruffleHunt(random: _AlwaysLeft()).litIcon, DeviceIcon.play);
    });
  });

  group('the frame', () {
    test('draws the mounds over the pig, not under it', () {
      // A creature sprite is the full screen with unlit dots all round the pig,
      // so blitting it at an offset paints over whatever was already there.
      //
      // Assert on the mound the pig actually reaches — _AlwaysLeft sends it to
      // dx = -9, so it covers the LEFT mound at columns 2-6 and never touches
      // the right-hand one — and assert the mound's exact shape rather than
      // merely that something is lit there.
      //
      // A presence check does not discriminate: at that offset the pig's own
      // artwork puts dots at columns 2-6 of row 14, so `contains('#')` passes
      // whichever order the two are drawn in. The mound's rows are '.###.' and
      // '#####'; reverse the order and the pig overwrites both.
      final hunt = TruffleHunt(random: _AlwaysLeft())
        ..handle(Button.a, testContext());
      final rows = hunt.compose(testContext(), 0).toAscii().split('\n');
      expect(rows[13].substring(2, 7), '.###.', reason: 'mound row 2 erased');
      expect(rows[14].substring(2, 7), '#####', reason: 'mound row 3 erased');
    });

    test('moves the pig off centre once it has committed', () {
      final hunt = TruffleHunt(random: _AlwaysLeft());
      final waiting = hunt.compose(testContext(), 0).toAscii();
      hunt.handle(Button.a, testContext());
      expect(hunt.compose(testContext(), 0).toAscii(), isNot(waiting));
    });

    test('tells an unplayed round from a lost one', () {
      // Both would otherwise be blank, and the player would lose count.
      final fresh = TruffleHunt(random: _AlwaysLeft());
      final lost = TruffleHunt(random: _AlwaysLeft())
        ..handle(Button.c, testContext());
      expect(
        fresh.compose(testContext(), 0).toAscii(),
        isNot(lost.compose(testContext(), 0).toAscii()),
      );
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/game/screens/truffle_hunt_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/game/screens/truffle_hunt.dart`:

```dart
import 'dart:math';

import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_buffer.dart';
import '../../sprites/prop_sprites.dart';
import '../../sprites/sprite_registry.dart';
import '../game_constants.dart';
import '../pet_appearance.dart';
import 'device_screen.dart';

const int _moundLeftX = 2;
const int _moundRightX = 25;
const int _moundY = 12;
const int _tallyX = 10;
const int _heartX = 13;
const int _heartY = 3;

/// Best of five, resolved on the device.
///
/// Spec §7.4 has the pig turning left or right. It cannot: the front-facing
/// redesign left the cast with no left and no right, and drawing eight new
/// poses would risk the skull-and-snout misalignment that has already shipped
/// once. So the pig trots to the mound it picked and snuffles there in the
/// eating pose it already has.
class TruffleHunt extends DeviceScreen {
  /// [random] is `dart:math`'s, injected so tests can make the pig predictable.
  ///
  /// It deliberately is **not** `hog_sim`'s generator. That one is seeded off
  /// `petId` and tick so the VM, dart2js and the browser agree dot for dot;
  /// drawing from it here would make the simulation's output depend on whether
  /// the player happened to play a minigame.
  TruffleHunt({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Null while a round is unplayed, true for a hit, false for a miss.
  final List<bool?> results = List<bool?>.filled(kPlayRounds, null);

  int round = 0;

  /// Which way the pig went, while it is still over there. Null between rounds.
  bool? pigWentLeft;

  int revealUntilMillis = 0;

  int get wins => results.where((r) => r == true).length;

  bool get revealing => pigWentLeft != null;

  @override
  DeviceIcon? get litIcon => DeviceIcon.play;

  @override
  Transition handle(Button b, GameContext ctx) {
    // B has no meaning in a round: the guess is A or C, per spec §7.4. That
    // leaves no third button for "abandon", so a match runs to its conclusion
    // — which is five presses, and each round is over in a second and a half.
    //
    // A second guess while the pig is still at a mound would resolve a round
    // the player has not seen the answer to yet.
    if (b == Button.b || revealing || round >= kPlayRounds) return const Stay();

    final wentLeft = _random.nextBool();
    pigWentLeft = wentLeft;
    results[round] = (b == Button.a) == wentLeft;
    revealUntilMillis = ctx.nowMillis + kHuntRevealMillis;
    return const Stay();
  }

  @override
  Transition update(GameContext ctx) {
    if (!revealing || ctx.nowMillis < revealUntilMillis) return const Stay();
    pigWentLeft = null;
    round++;
    return round >= kPlayRounds ? Played(wins) : const Stay();
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) {
    final buffer = LcdBuffer();

    final dx = switch (pigWentLeft) {
      true => -kHuntSlide,
      false => kHuntSlide,
      null => 0,
    };
    buffer.blit(
      creatureAnim(
        stage: ctx.pet.stage,
        form: ctx.pet.form,
        pose: revealing ? PetPose.eating : PetPose.idle,
        mood: moodFor(ctx.pet),
      ).frame(frame),
      dx,
      0,
    );

    // Mounds go on *after* the pig. A creature sprite is the full screen with
    // unlit dots all round it, so blitting one at an offset paints over
    // anything already beneath — draw these first and the pig erases one.
    buffer
      ..blit(kMound, _moundLeftX, _moundY)
      ..blit(kMound, _moundRightX, _moundY);

    if (revealing && round < kPlayRounds && results[round] == true) {
      // Blinks, so a win reads as a celebration rather than as furniture.
      if (frame.isEven) buffer.blit(kHeart, _heartX, _heartY);
    }

    _drawTally(buffer);
    return buffer;
  }

  /// Five marks along the top. A win is a block, a loss a single dot, an
  /// unplayed round nothing — otherwise round three and two losses look the
  /// same and the player loses count.
  void _drawTally(LcdBuffer buffer) {
    for (var i = 0; i < kPlayRounds; i++) {
      final x = _tallyX + i * 3;
      switch (results[i]) {
        case true:
          buffer
            ..set(x, 0, true)
            ..set(x + 1, 0, true)
            ..set(x, 1, true)
            ..set(x + 1, 1, true);
        case false:
          buffer.set(x, 0, true);
        case null:
          break;
      }
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/game/screens/truffle_hunt_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 5: Restore the home screen's three pushes**

In `lib/game/screens/home_screen.dart`, add the three imports and replace the stubbed cases:

```dart
          DeviceIcon.feed => Push(FeedMenu()),
          DeviceIcon.play => Push(TruffleHunt()),
          DeviceIcon.stats => Push(StatsScreen()),
```

Then add to `test/game/screens/home_screen_test.dart`:

```dart
  group('B opens the three screens that need one', () {
    test('feed opens the submenu', () {
      final s = HomeScreen()..selected = DeviceIcon.feed;
      final out = drive(s, 'B', testContext()).single;
      expect((out as Push).screen, isA<FeedMenu>());
    });

    test('play opens the truffle hunt', () {
      final s = HomeScreen()..selected = DeviceIcon.play;
      final out = drive(s, 'B', testContext()).single;
      expect((out as Push).screen, isA<TruffleHunt>());
    });

    test('stats opens the status pages', () {
      final s = HomeScreen()..selected = DeviceIcon.stats;
      final out = drive(s, 'B', testContext()).single;
      expect((out as Push).screen, isA<StatsScreen>());
    });
  });
```

Also update the existing `does nothing while nothing is selected` test if it asserted `Stay` for feed/play/stats — it should not have; it only covers a null selection.

- [ ] **Step 6: Run the game suite**

Run: `flutter test test/game/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/game/screens/truffle_hunt.dart lib/game/screens/home_screen.dart \
        test/game/screens/truffle_hunt_test.dart test/game/screens/home_screen_test.dart
git commit -m "feat(game): add the truffle hunt and wire the home screen's submenus"
```

---

## Task 11: The crest picker and the death screen

**Files:**
- Create: `lib/game/screens/crest_screen.dart`
- Create: `lib/game/screens/death_screen.dart`
- Test: `test/game/screens/crest_screen_test.dart`
- Test: `test/game/screens/death_screen_test.dart`

**Interfaces:**
- Consumes: `DeviceScreen`/`Crest`/`Crested`/`Restart` (Task 4), `kCrests` (Task 6), `drawPips` (Task 2), `kSpriteRegistry` (existing).
- Produces: `class CrestScreen extends DeviceScreen` with a mutable `Crest crest`; `class DeathScreen extends DeviceScreen`.

- [ ] **Step 1: Write the failing tests**

Create `test/game/screens/crest_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/game/screens/crest_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';

import 'screen_test_support.dart';

void main() {
  test('opens on the first emblem', () {
    expect(CrestScreen().crest, Crest.values.first);
  });

  test('A cycles through all eight and comes back round', () {
    final s = CrestScreen();
    final seen = <Crest>{s.crest};
    for (var i = 1; i < Crest.values.length; i++) {
      drive(s, 'A', testContext());
      seen.add(s.crest);
    }
    expect(seen, Crest.values.toSet());
    drive(s, 'A', testContext());
    expect(s.crest, Crest.values.first, reason: 'did not wrap');
  });

  test('B commits the emblem and starts the pig', () {
    final s = CrestScreen();
    drive(s, 'A', testContext());
    final out = drive(s, 'B', testContext()).single;
    expect(out, isA<Crested>());
    expect((out as Crested).crest, s.crest);
  });

  test('C does nothing — there is nowhere behind this screen', () {
    expect(drive(CrestScreen(), 'C', testContext()).single, isA<Stay>());
  });

  test('lights no strip icon: this screen is not reached from the strip', () {
    expect(CrestScreen().litIcon, isNull);
  });

  test('draws a different frame for each emblem', () {
    final s = CrestScreen();
    final shapes = <String>{};
    for (var i = 0; i < Crest.values.length; i++) {
      shapes.add(s.compose(testContext(), 0).toAscii());
      drive(s, 'A', testContext());
    }
    expect(shapes.length, Crest.values.length);
  });
}
```

Create `test/game/screens/death_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';

import 'screen_test_support.dart';

GameContext _dead({Crest crest = Crest.leaf, int ageDays = 9}) => testContext(
  crest: crest,
  pet: testPet(deathCause: DeathCause.neglect, ageDays: ageDays),
);

void main() {
  test('B starts another pig', () {
    expect(DeathScreen().handle(Button.b, _dead()), isA<Restart>());
  });

  test('A and C do nothing — leaving is not an option', () {
    expect(DeathScreen().handle(Button.a, _dead()), isA<Stay>());
    expect(DeathScreen().handle(Button.c, _dead()), isA<Stay>());
  });

  test("shows the pig's crest, so the grave is this pig and not any pig", () {
    final shapes = {
      for (final crest in Crest.values)
        DeathScreen().compose(_dead(crest: crest), 0).toAscii(),
    };
    expect(shapes.length, Crest.values.length);
  });

  test('shows the age it reached', () {
    expect(
      DeathScreen().compose(_dead(ageDays: 2), 0).toAscii(),
      isNot(DeathScreen().compose(_dead(ageDays: 14), 0).toAscii()),
    );
  });

  test('keeps a twenty-day life inside the gutter', () {
    // Twenty days is the longest a prize hog lives. Four single-dot pips per
    // row at a two-dot pitch is the only way that many fit beside the stone —
    // anything wider spills onto the grave.
    //
    // Count the pips rather than asserting the buffer's shape: LcdBuffer is
    // always 16x32, so a shape assertion here would pass unconditionally.
    final rows = DeathScreen().compose(_dead(ageDays: 20), 0).toAscii().split('\n');
    var inGutter = 0;
    for (final row in rows) {
      for (var x = 25; x < 32; x++) {
        if (row[x] == '#') inGutter++;
      }
    }
    expect(inGutter, 20, reason: 'one dot per day, all of them in the gutter');
  });

  test('draws the stone', () {
    // Assert the grave occupies its own columns. A bare `contains('#')` would
    // pass on the crest or the pips alone and could not fail while anything at
    // all was drawn.
    final rows = DeathScreen().compose(_dead(), 0).toAscii().split('\n');
    final stoneRows = rows.where((r) => r.substring(8, 24).contains('#'));
    expect(
      stoneRows.length,
      greaterThanOrEqualTo(10),
      reason: 'the stone should fill most of the middle sixteen columns',
    );
  });

  test('lights no strip icon', () {
    expect(DeathScreen().litIcon, isNull);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/game/screens/crest_screen_test.dart test/game/screens/death_screen_test.dart`
Expected: FAIL — both URIs missing.

- [ ] **Step 3: Write the crest picker**

Create `lib/game/screens/crest_screen.dart`:

```dart
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
```

- [ ] **Step 4: Write the death screen**

Create `lib/game/screens/death_screen.dart`:

```dart
import '../../lcd/lcd_bars.dart';
import '../../lcd/lcd_buffer.dart';
import '../../sprites/crest_sprites.dart';
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/game/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/game/screens/crest_screen.dart lib/game/screens/death_screen.dart \
        test/game/screens/crest_screen_test.dart test/game/screens/death_screen_test.dart
git commit -m "feat(game): add the crest picker and the death screen"
```

---

## Task 12: The controller

**Files:**
- Create: `lib/game/game_controller.dart`
- Test: `test/game/game_controller_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 3, 4, 7–11; `advance`, `applyAction`, `applyMinigame` (`hog_sim`); `kAnimFrameMillis` (`sprite_registry.dart`).
- Produces: `class GameController extends ChangeNotifier` with `GameController({Clock clock, int? utcOffsetMinutes})`, and: `PetState get pet`, `Crest get crest`, `int get frame`, `DeviceScreen get screen`, `DeviceIcon? get litIcon`, `DeviceIcon? get blinkingIcon`, `GameContext get context`, `LcdBuffer compose()`, `void press(Button)`, `void tick()`, `void start()`.

- [ ] **Step 1: Write the failing test**

Create `test/game/game_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_constants.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/game/screens/crest_screen.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';
import 'package:sooey/game/screens/home_screen.dart';
import 'package:sooey/sprites/sprite_registry.dart';

import 'screens/screen_test_support.dart';

const int _hour = 60 * 60 * 1000;

/// A controller with its pig already hatched and hungry enough to eat.
///
/// Slop is refused above 90 fullness, and a newborn starts at 100, so a test
/// that wants to feed has to let some time pass first. Three hours also clears
/// the fifteen-minute egg.
(GameController, FakeClock) hatched() {
  final clock = FakeClock(kRefNoon - 3 * _hour);
  final c = GameController(clock: clock, utcOffsetMinutes: 0);
  c.press(Button.b); // accept the opening crest
  clock.advance(3 * _hour);
  c.tick();
  return (c, clock);
}

void main() {
  group('a new pet', () {
    test('opens on the crest picker', () {
      final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
      expect(c.screen, isA<CrestScreen>());
    });

    test('starts as an egg', () {
      final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
      expect(c.pet.stage, Stage.egg);
    });

    test('reaches the home screen once the crest is chosen', () {
      final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
      c.press(Button.a);
      final chosen = (c.screen as CrestScreen).crest;
      c.press(Button.b);
      expect(c.screen, isA<HomeScreen>());
      expect(c.crest, chosen);
    });

    test('hatches on its own', () {
      final (c, _) = hatched();
      expect(c.pet.stage, Stage.piglet);
    });
  });

  group('actions', () {
    test('feeding raises fullness and shows the pig eating', () {
      final (c, _) = hatched();
      final before = c.pet.fullness;
      c.press(Button.a); // cursor to feed
      c.press(Button.b); // open the submenu
      expect(c.screen, isA<FeedMenu>());
      c.press(Button.b); // slop
      expect(c.pet.fullness, greaterThan(before));
      expect(c.screen, isA<HomeScreen>(), reason: 'submenu should have closed');
      expect(c.context.transientPose, PetPose.eating);
    });

    test('the eating pose wears off', () {
      final (c, clock) = hatched();
      c.press(Button.a);
      c.press(Button.b);
      c.press(Button.b);
      clock.advance(kTransientPoseMillis + 1);
      expect(c.context.transientPose, isNull);
    });

    test('cleaning clears the pen', () {
      final (c, clock) = hatched();

      // Only slop schedules a poop, and it arrives kTicksUntilPoop (150
      // minutes) later. Without feeding first the pen is empty and this test
      // could not fail.
      c.press(Button.a); // feed
      c.press(Button.b); // open
      c.press(Button.b); // slop
      clock.advance(3 * _hour);
      c.tick();
      expect(c.pet.poops, isNotEmpty, reason: 'a meal should produce a mess');

      while (c.litIcon != DeviceIcon.clean) {
        c.press(Button.a);
      }
      c.press(Button.b);
      expect(c.pet.poops, isEmpty);
      expect(c.pet.cleanliness, 100);
    });

    test('wallowing comforts the pig and dirties it, as spec 7.2 wants', () {
      final (c, _) = hatched();
      c.press(Button.a);
      c.press(Button.a); // cursor to wallow
      final dirtBefore = c.pet.cleanliness;
      c.press(Button.b);
      expect(c.pet.comfort, 100);
      expect(c.pet.cleanliness, lessThan(dirtBefore));
    });
  });

  group('refusals', () {
    test('blink the icon that refused rather than sadden the pig', () {
      // The face reads current needs only and has to stay honest. A pig that
      // looked miserable because a button did nothing would be lying.
      //
      // Note the press sequence: after the first slop the cursor is still on
      // feed, so B reopens the submenu. Pressing A again would walk it on to
      // wallow and the second action would be an accepted wallow instead of a
      // refused bucket.
      final (c, _) = hatched();
      c.press(Button.a); // cursor to feed
      c.press(Button.b); // open
      c.press(Button.b); // slop, accepted — fullness now capped at 100
      c.press(Button.b); // reopen
      c.press(Button.b); // slop again, over 90 and refused
      expect(c.blinkingIcon, DeviceIcon.feed);

      // And the refusal leaves the pig looking exactly as the accepted feed
      // left it. Note this is `eating`, not null — the pose from two presses
      // ago is still running. The point is that the refusal did not touch it.
      expect(
        c.context.transientPose,
        PetPose.eating,
        reason: 'a refusal must not touch the pose the accepted feed set',
      );
    });

    test('stop blinking after a moment', () {
      final (c, clock) = hatched();
      c.press(Button.a);
      c.press(Button.b);
      c.press(Button.b);
      c.press(Button.b);
      c.press(Button.b);
      expect(c.blinkingIcon, isNotNull, reason: 'setup should have refused');
      clock.advance(kRefusalBlinkMillis + 1);
      expect(c.blinkingIcon, isNull);
    });

    test('an egg refuses everything but the light', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);

      // Wallowing: refused. An egg has no mud, no mouth and no mess.
      while (c.litIcon != DeviceIcon.wallow) {
        c.press(Button.a);
      }
      c.press(Button.b);
      expect(c.blinkingIcon, DeviceIcon.wallow);

      // The pen light: the one thing that works before it hatches. Without
      // this half the test would pass even if the light were refused too.
      clock.advance(kRefusalBlinkMillis + 1);
      final litBefore = c.pet.lightsOn;
      while (c.litIcon != DeviceIcon.light) {
        c.press(Button.a);
      }
      c.press(Button.b);
      expect(c.pet.lightsOn, !litBefore, reason: 'the light should toggle');
      expect(c.blinkingIcon, isNull, reason: 'the light was not refused');
    });
  });

  group('death', () {
    test('takes over the screen when the pig dies', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      expect(c.pet.isDead, isTrue);
      expect(c.screen, isA<DeathScreen>());
    });

    test('gives the death a cause', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      expect(c.pet.deathCause, isNotNull);
    });

    test('B starts a fresh pig back at the crest', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      c.press(Button.b);
      expect(c.screen, isA<CrestScreen>());
      expect(c.pet.isDead, isFalse);
      expect(c.pet.stage, Stage.egg);
    });

    test('stops the simulation dead rather than ticking a corpse', () {
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0)
        ..press(Button.b);
      clock.advance(5 * 24 * _hour);
      c.tick();
      final died = c.pet.diedAtMillis;
      clock.advance(2 * 24 * _hour);
      c.tick();
      expect(c.pet.diedAtMillis, died);
    });
  });

  group('the frame counter', () {
    test('advances on every tick, so animations run', () {
      final (c, _) = hatched();
      final before = c.frame;
      c.tick();
      expect(c.frame, greaterThan(before));
    });

    test('composes whatever screen is on top', () {
      final (c, _) = hatched();
      expect(c.compose().width, 32);
      expect(c.compose().height, 16);
    });
  });

  test('notifies listeners on a press, so the widget rebuilds', () {
    final (c, _) = hatched();
    var notified = 0;
    c.addListener(() => notified++);
    c.press(Button.a);
    expect(notified, 1);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/game/game_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:sooey/game/game_controller.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/game/game_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hog_sim/hog_sim.dart';

import '../lcd/lcd_buffer.dart';
import '../sprites/sprite_registry.dart';
import 'clock.dart';
import 'game_constants.dart';
import 'screens/crest_screen.dart';
import 'screens/death_screen.dart';
import 'screens/device_screen.dart';
import 'screens/home_screen.dart';

/// One pig, one clock, one stack of screens.
///
/// **The only thing in the client that mutates the pet.** Screens turn a press
/// into an intent and the controller decides what that does — which is what
/// lets a screen be tested with a string of presses and nothing else.
///
/// Nothing here is persisted. A pet vanishes on reload, deliberately: M4 is
/// about landing the input machine before the network arrives in M5.
class GameController extends ChangeNotifier {
  GameController({Clock clock = const SystemClock(), int? utcOffsetMinutes})
    : _clock = clock,
      _utcOffsetMinutes =
          utcOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes {
    _restart();
  }

  final Clock _clock;
  final int _utcOffsetMinutes;

  late PetState _pet;
  late Crest _crest;
  late List<DeviceScreen> _stack;

  int _frame = 0;
  PetPose? _transientPose;
  int _transientUntilMillis = 0;
  DeviceIcon? _blinkingIcon;
  int _blinkUntilMillis = 0;
  Timer? _timer;

  PetState get pet => _pet;
  Crest get crest => _crest;
  int get frame => _frame;
  DeviceScreen get screen => _stack.last;
  DeviceIcon? get litIcon => screen.litIcon;

  /// The icon a refused action is blinking, or null. Expires on its own so no
  /// one has to remember to clear it.
  DeviceIcon? get blinkingIcon =>
      _clock.nowMillis < _blinkUntilMillis ? _blinkingIcon : null;

  GameContext get context => GameContext(
    pet: _pet,
    crest: _crest,
    nowMillis: _clock.nowMillis,
    transientPose: _clock.nowMillis < _transientUntilMillis
        ? _transientPose
        : null,
  );

  LcdBuffer compose() => screen.compose(context, _frame);

  /// Starts the animation timer. Tests drive [tick] by hand instead.
  void start() {
    _timer ??= Timer.periodic(
      const Duration(milliseconds: kAnimFrameMillis),
      (_) => tick(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// One animation frame: advance the simulation, then let the top screen move.
  ///
  /// `advance` is cheap to call this often — it steps in whole five-minute
  /// ticks and does nothing until one has elapsed.
  void tick() {
    _frame++;
    _pet = advance(_pet, _clock.nowMillis);

    if (_pet.isDead) {
      if (_stack.last is! DeathScreen) _stack = [DeathScreen()];
    } else {
      _apply(screen.update(context));
    }
    notifyListeners();
  }

  void press(Button b) {
    _apply(screen.handle(b, context));
    notifyListeners();
  }

  void _apply(Transition t) {
    switch (t) {
      case Stay():
        break;

      case Push(screen: final next):
        _stack.add(next);

      case Pop():
        _popIfNested();

      case Act(:final action):
        // Captured before the pop, because it names the icon that refused.
        final icon = screen.litIcon;
        final outcome = applyAction(_pet, action, _clock.nowMillis);
        _pet = outcome.state;
        if (outcome.accepted) {
          _showPoseFor(action);
        } else {
          _blink(icon);
        }
        _popIfNested();

      case Played(:final wins):
        final outcome = applyMinigame(
          _pet,
          wins: wins,
          rounds: kPlayRounds,
          nowMillis: _clock.nowMillis,
        );
        _pet = outcome.state;
        if (!outcome.accepted) _blink(DeviceIcon.play);
        _popIfNested();

      case Crested(:final crest):
        _crest = crest;
        _stack = [HomeScreen()];

      case Restart():
        _restart();
    }
  }

  /// Home is the root and has nothing behind it, so a pop from there is a
  /// no-op rather than an empty stack.
  void _popIfNested() {
    if (_stack.length > 1) _stack.removeLast();
  }

  /// Lets the player see the action land. Cleaning, medicating and the light
  /// have no pose of their own — the poops vanishing is the feedback.
  void _showPoseFor(PetAction action) {
    final pose = switch (action) {
      PetAction.slop || PetAction.treat => PetPose.eating,
      PetAction.wallow => PetPose.wallowing,
      PetAction.clean || PetAction.meds || PetAction.light => null,
    };
    if (pose == null) return;
    _transientPose = pose;
    _transientUntilMillis = _clock.nowMillis + kTransientPoseMillis;
  }

  void _blink(DeviceIcon? icon) {
    if (icon == null) return;
    _blinkingIcon = icon;
    _blinkUntilMillis = _clock.nowMillis + kRefusalBlinkMillis;
  }

  void _restart() {
    _pet = PetState.newborn(
      petId: 'pet_local',
      ownerId: 'uid_local',
      // The pig has a crest instead of a name. `name` stays in the model
      // because M5's Firestore schema wants it; nothing displays it.
      name: '',
      nowMillis: _clock.nowMillis,
      utcOffsetMinutes: _utcOffsetMinutes,
    );
    _crest = Crest.values.first;
    _stack = [CrestScreen()];
    _transientPose = null;
    _transientUntilMillis = 0;
    _blinkingIcon = null;
    _blinkUntilMillis = 0;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/game/game_controller_test.dart`
Expected: PASS, 18 tests.

If `cleaning clears the pen` fails because no poop arrived, check the arithmetic rather than loosening the test: a slop schedules a poop `kTicksUntilPoop` (30 ticks, 150 minutes) ahead, and the pig must have been fed for one to exist. Feed before advancing.

- [ ] **Step 5: Run everything**

Run: `flutter test`
Expected: PASS except the one known `kGrave` failure.

Run: `cd packages/hog_sim && dart test && dart test -p chrome`
Expected: 119 and 114, both green. Nothing in this task touches `hog_sim`; if a vector moved, something is very wrong.

- [ ] **Step 6: Commit**

```bash
git add lib/game/game_controller.dart test/game/game_controller_test.dart
git commit -m "feat(game): add the controller that owns the pet, the clock and the stack"
```

---

## Task 13: The strip and the glass

**Files:**
- Create: `lib/device/icon_strip.dart`
- Create: `lib/device/lcd_glass.dart`
- Test: `test/device/icon_strip_test.dart`
- Test: `test/device/lcd_glass_test.dart`

**Interfaces:**
- Consumes: `LcdBuffer.sized` (Task 1), `LcdMatrix` (Task 1), `LcdTheme.dotDim` (Task 1), `kDeviceIcons` (Task 5), `DeviceIcon` (Task 4).
- Produces:
  - `const int kStripHeight = 7`, `kStripSlots = 4`, `kStripPitch = 8`
  - `const List<List<DeviceIcon?>> kStripLayout` — two rows of four
  - `LcdBuffer stripBuffer(List<DeviceIcon?> slots, {required bool Function(DeviceIcon) include})`
  - `class IconStripPainter extends CustomPainter` taking `lit`, `dim`, `dotSize`, `frame`
  - `class IconStrip extends StatelessWidget` taking `slots`, `selected`, `hidden`, `dotSize`, `frame`
  - `const int kGlassWidth`, `kGlassHeight`; `int glassDotSize(Size available)`
  - `class LcdGlass extends StatelessWidget` taking `buffer`, `frame`, `selected`, `hidden`

- [ ] **Step 1: Write the failing tests**

Create `test/device/icon_strip_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/icon_strip.dart';
import 'package:sooey/game/screens/device_screen.dart';

void main() {
  group('the layout', () {
    test('puts four icons above and three below, per spec 6', () {
      expect(kStripLayout, hasLength(2));
      expect(kStripLayout[0].whereType<DeviceIcon>(), hasLength(4));
      expect(kStripLayout[1].whereType<DeviceIcon>(), hasLength(3));
    });

    test('keeps the bottom row on the same four-column grid', () {
      // Re-centring three icons would break the alignment between the strips
      // and they would stop reading as one bezel. The fourth slot is where
      // train was before D2 cut it.
      expect(kStripLayout[1], hasLength(kStripSlots));
      expect(kStripLayout[1].last, isNull);
    });

    test('covers every icon the cursor can reach, exactly once', () {
      final placed = kStripLayout.expand((r) => r).whereType<DeviceIcon>();
      expect(placed.toSet(), DeviceIcon.values.toSet());
      expect(placed, hasLength(DeviceIcon.values.length));
    });

    test('is laid out in cursor order, so A moves left to right', () {
      final placed = kStripLayout
          .expand((r) => r)
          .whereType<DeviceIcon>()
          .toList();
      expect(placed, DeviceIcon.values);
    });
  });

  group('stripBuffer', () {
    test('is the display width and the strip height', () {
      final b = stripBuffer(kStripLayout[0], include: (_) => true);
      expect(b.width, 32);
      expect(b.height, kStripHeight);
    });

    test('draws only the icons it is asked for', () {
      final all = stripBuffer(kStripLayout[0], include: (_) => true);
      final none = stripBuffer(kStripLayout[0], include: (_) => false);
      expect(all.toAscii(), isNot(none.toAscii()));
      expect(none.toAscii().contains('#'), isFalse);
    });

    test('places each icon in its own column', () {
      final first = stripBuffer(
        kStripLayout[0],
        include: (i) => i == DeviceIcon.feed,
      );
      final second = stripBuffer(
        kStripLayout[0],
        include: (i) => i == DeviceIcon.wallow,
      );
      expect(first.get(1, 2), isNot(second.get(1, 2)));
    });

    test('skips the empty slot without shifting anything along', () {
      final bottom = stripBuffer(kStripLayout[1], include: (_) => true);
      for (var y = 0; y < kStripHeight; y++) {
        for (var x = kStripPitch * 3; x < 32; x++) {
          expect(bottom.get(x, y), isFalse, reason: 'slot 4 should be dark');
        }
      }
    });
  });

  group('IconStripPainter', () {
    test('repaints when the selection moves', () {
      final lit = stripBuffer(kStripLayout[0], include: (_) => true);
      final other = stripBuffer(kStripLayout[0], include: (_) => false);
      final dim = stripBuffer(kStripLayout[0], include: (_) => true);
      final a = IconStripPainter(lit: lit, dim: dim, dotSize: 8, frame: 0);
      final b = IconStripPainter(lit: other, dim: dim, dotSize: 8, frame: 0);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint when nothing has changed', () {
      final lit = stripBuffer(kStripLayout[0], include: (_) => true);
      final dim = stripBuffer(kStripLayout[0], include: (_) => false);
      final a = IconStripPainter(lit: lit, dim: dim, dotSize: 8, frame: 3);
      final b = IconStripPainter(lit: lit, dim: dim, dotSize: 8, frame: 3);
      expect(b.shouldRepaint(a), isFalse);
    });
  });

  group('IconStrip', () {
    testWidgets('blinks an icon off even while it is the selected one', (
      tester,
    ) async {
      // A refusal almost always lands on the icon the player has selected —
      // that is how they triggered it. If `hidden` only suppressed the dim
      // pass, the blink would be invisible in exactly the case it exists for.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: IconStrip(
            slots: kStripLayout[0],
            selected: DeviceIcon.feed,
            hidden: DeviceIcon.feed,
            dotSize: 8,
            frame: 0,
          ),
        ),
      );

      final painter = tester
          .widget<CustomPaint>(find.byType(CustomPaint))
          .painter! as IconStripPainter;

      expect(
        painter.lit.toAscii().contains('#'),
        isFalse,
        reason: 'the blinked icon is still lit',
      );
      expect(
        painter.dim.toAscii().contains('#'),
        isTrue,
        reason: 'the other three should still be showing',
      );
    });
  });
}
```

Create `test/device/lcd_glass_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/icon_strip.dart';
import 'package:sooey/device/lcd_glass.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/lcd/lcd.dart';
import 'package:sooey/sprites/sprite_registry.dart';

void main() {
  group('glassDotSize', () {
    test('accounts for both strips and the gaps, not just the matrix', () {
      // 32 wide by 7 + 1 + 16 + 1 + 7 = 32 tall. A dot size taken from the
      // matrix alone would overflow the box by both strips.
      expect(kGlassHeight, kStripHeight * 2 + kLcdHeight + 2);
      expect(glassDotSize(const Size(320, 320)), 10);
    });

    test('never overflows the box, and never leaves a whole dot on the table', () {
      // Not "is always whole pixels" — `glassDotSize` returns an `int`, so
      // comparing it to its own `toInt()` is `expect(d, d)` and passes for any
      // implementation, including one that ignores its argument entirely.
      //
      // This checks the property that actually matters. The sweep starts at 64
      // because that is exactly where 64 ~/ 32 reaches kMinDotSize; below it
      // the clamp legitimately overflows the box and the fit assertion would
      // fail for the wrong reason.
      for (var w = 64.0; w < 1200; w += 7) {
        final d = glassDotSize(Size(w, w));
        expect(d * kGlassWidth, lessThanOrEqualTo(w), reason: 'width at $w');
        expect(d * kGlassHeight, lessThanOrEqualTo(w), reason: 'height at $w');
        expect(
          (d + 1) * kGlassWidth > w || (d + 1) * kGlassHeight > w,
          isTrue,
          reason: 'left a whole dot unused at $w',
        );
      }
    });

    test('takes whichever constraint binds', () {
      expect(glassDotSize(const Size(640, 160)), 5);
      expect(glassDotSize(const Size(160, 640)), 5);
    });

    test('stays visible in a cramped box', () {
      expect(glassDotSize(Size.zero), greaterThanOrEqualTo(kMinDotSize));
    });
  });

  group('LcdGlass', () {
    testWidgets('puts the strips and the matrix on one dot pitch', (tester) async {
      // Different pitches are the tell that gives away two screens glued
      // together rather than one piece of glass.
      for (final width in [360.0, 800.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, width));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LcdGlass(
              buffer: LcdBuffer()..blit(kFaceIdle1, 0, 0),
              frame: 0,
              selected: DeviceIcon.feed,
            ),
          ),
        );

        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .toList();

        final matrix = painters.whereType<LcdPainter>().single;
        final strips = painters.whereType<IconStripPainter>().toList();

        expect(strips, hasLength(2), reason: 'width $width');
        for (final strip in strips) {
          expect(strip.dotSize, matrix.dotSize, reason: 'width $width');
        }
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('lights the selected icon and dims the rest', (tester) async {
      await tester.binding.setSurfaceSize(const Size(640, 640));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LcdGlass(
            buffer: LcdBuffer(),
            frame: 0,
            selected: DeviceIcon.feed,
          ),
        ),
      );

      final top = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<IconStripPainter>()
          .first;

      expect(top.lit.toAscii().contains('#'), isTrue, reason: 'nothing lit');
      expect(top.dim.toAscii().contains('#'), isTrue, reason: 'nothing dimmed');
      await tester.binding.setSurfaceSize(null);
    });
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/device/`
Expected: FAIL — both URIs missing.

- [ ] **Step 3: Write the strip**

Create `lib/device/icon_strip.dart`:

```dart
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
```

- [ ] **Step 4: Write the glass**

Create `lib/device/lcd_glass.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../game/screens/device_screen.dart';
import '../lcd/lcd_buffer.dart';
import '../lcd/lcd_matrix.dart';
import '../lcd/lcd_painter.dart';
import '../lcd/lcd_theme.dart';
import 'icon_strip.dart';

const int kGlassWidth = kLcdWidth;

/// Top strip, gap, matrix, gap, bottom strip.
const int kGlassHeight = kStripHeight * 2 + kLcdHeight + 2;

/// One dot size for the whole glass.
///
/// Computed from the full 32x32 box rather than from the matrix, because every
/// part of the glass has to share a pitch. A strip that sized itself from its
/// own box would land on a different one and the result reads as two screens
/// glued together. Integer scaling only, for the reason `lcd_painter.dart`
/// already documents.
int glassDotSize(Size available) => math.max(
  kMinDotSize,
  math.min(
    available.width ~/ kGlassWidth,
    available.height ~/ kGlassHeight,
  ),
);

/// The whole piece of simulated LCD: two icon strips and the dot matrix.
class LcdGlass extends StatelessWidget {
  const LcdGlass({
    required this.buffer,
    required this.frame,
    this.selected,
    this.hidden,
    super.key,
  });

  final LcdBuffer buffer;
  final int frame;
  final DeviceIcon? selected;
  final DeviceIcon? hidden;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dotSize = glassDotSize(
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        final gap = SizedBox(height: dotSize.toDouble());

        return Container(
          color: LcdTheme.screen,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconStrip(
                slots: kStripLayout[0],
                selected: selected,
                hidden: hidden,
                dotSize: dotSize,
                frame: frame,
              ),
              gap,
              LcdMatrix(buffer: buffer, frame: frame, dotSize: dotSize),
              gap,
              IconStrip(
                slots: kStripLayout[1],
                selected: selected,
                hidden: hidden,
                dotSize: dotSize,
                frame: frame,
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/device/`
Expected: PASS, 13 tests.

If `puts the strips and the matrix on one dot pitch` fails, the gap `SizedBox`es are the likely culprit — they must be a whole dot tall or the column's height stops being a multiple of `dotSize`.

- [ ] **Step 6: Commit**

```bash
git add lib/device/icon_strip.dart lib/device/lcd_glass.dart \
        test/device/icon_strip_test.dart test/device/lcd_glass_test.dart
git commit -m "feat(device): add the icon strips and the glass that shares their dot pitch"
```

---

## Task 14: The shell

**Files:**
- Create: `lib/device/device_shell.dart`
- Test: `test/device/device_shell_test.dart`

**Interfaces:**
- Consumes: `GameController` (Task 12), `LcdGlass` (Task 13), `LcdTheme` (existing).
- Produces: `class DeviceShell extends StatelessWidget` taking a `GameController`; `class DevicePage extends StatefulWidget` which owns a `GameController` on a `SystemClock`.

- [ ] **Step 1: Write the failing test**

Create `test/device/device_shell_test.dart`:

```dart
import 'package:flutter/material.dart' hide Form;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/device_shell.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/home_screen.dart';

import '../game/screens/screen_test_support.dart';

Future<void> pumpShell(WidgetTester tester, GameController c) async {
  await tester.binding.setSurfaceSize(const Size(600, 900));
  await tester.pumpWidget(
    MaterialApp(home: DeviceShell(controller: c)),
  );
}

void main() {
  testWidgets('has exactly three buttons', (tester) async {
    // Spec 6: three physical buttons, exactly like the hardware. A fourth
    // would be a different device.
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0);
    await pumpShell(tester, c);
    expect(find.byType(DeviceButton), findsExactly(3));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tapping a button drives the controller', (tester) async {
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0)
      ..press(Button.b); // past the crest picker
    await pumpShell(tester, c);

    await tester.tap(find.byKey(const ValueKey('button.a')));
    await tester.pump();
    expect((c.screen as HomeScreen).selected, DeviceIcon.feed);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('the arrow keys and enter are the three buttons', (tester) async {
    // A key is a physical button by another name. This is not a touch UI: the
    // glass and the bezel stay inert.
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0)
      ..press(Button.b);
    await pumpShell(tester, c);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect((c.screen as HomeScreen).selected, DeviceIcon.feed);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect((c.screen as HomeScreen).selected, isNull, reason: 'C should clear');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('nothing on the glass responds to a tap', (tester) async {
    final c = GameController(clock: FakeClock(kRefNoon), utcOffsetMinutes: 0)
      ..press(Button.b);
    await pumpShell(tester, c);

    await tester.tapAt(tester.getCenter(find.byType(DeviceShell)));
    await tester.pump();
    expect((c.screen as HomeScreen).selected, isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/device/device_shell_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/device/device_shell.dart`. Note the `hide Form` on the material import — `hog_sim`'s adult build collides with Flutter's form widget, and this file reaches both through the controller.

```dart
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/device/device_shell_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/device/device_shell.dart test/device/device_shell_test.dart
git commit -m "feat(device): add the shell, its three buttons and the keyboard mapping"
```

---

## Task 15: The routes, the dev harness, and the acceptance test

**Files:**
- Create: `lib/dev/device_dev_page.dart`
- Modify: `lib/main.dart`
- Test: `test/game/acceptance_test.dart`

**Interfaces:**
- Consumes: `DeviceShell`, `DevicePage` (Task 14), `GameController`, `FakeClock`.
- Produces: `class DeviceDevPage extends StatefulWidget`; routes `/`, `/dev`, `/dev/device`.

- [ ] **Step 1: Write the acceptance test**

This is the milestone's stated acceptance criterion, so it gets its own file rather than hiding among the controller's unit tests.

Create `test/game/acceptance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';

import 'screens/screen_test_support.dart';

const int _hour = 60 * 60 * 1000;

void main() {
  test('a pet can be fed, cleaned and played with, and dies if left alone', () {
    final clock = FakeClock(kRefNoon - 3 * _hour);
    final c = GameController(clock: clock, utcOffsetMinutes: 0);

    // Mark the egg.
    c.press(Button.b);
    expect(c.pet.stage, Stage.egg);

    // It hatches on its own after fifteen minutes, and three hours of piglet
    // is enough decay for the pig to accept a bucket.
    clock.advance(3 * _hour);
    c.tick();
    expect(c.pet.stage, Stage.piglet, reason: 'should have hatched');

    // Fed.
    final hungry = c.pet.fullness;
    c.press(Button.a); // feed
    c.press(Button.b); // open
    c.press(Button.b); // slop
    expect(c.pet.fullness, greaterThan(hungry));

    // Cleaned. The slop schedules a poop 150 minutes out; wait for it.
    clock.advance(3 * _hour);
    c.tick();
    expect(c.pet.poops, isNotEmpty, reason: 'a meal should produce a mess');
    // Walk to the icon rather than counting presses — the cursor is on feed
    // here, and a fixed count silently lands somewhere else if the icon order
    // ever moves.
    while (c.litIcon != DeviceIcon.clean) {
      c.press(Button.a);
    }
    c.press(Button.b);
    expect(c.pet.poops, isEmpty);
    expect(c.pet.cleanliness, 100);

    // Played with.
    final bored = c.pet.enrichment;
    while (c.litIcon != DeviceIcon.play) {
      c.press(Button.a);
    }
    c.press(Button.b); // open the hunt
    for (var i = 0; i < kPlayRounds; i++) {
      c.press(Button.a); // guess left
      clock.advance(2000);
      c.tick(); // let the reveal expire and the round turn over
    }
    expect(c.pet.enrichment, greaterThan(bored), reason: 'a hunt always pays');

    // And left alone.
    clock.advance(6 * 24 * _hour);
    c.tick();
    expect(c.pet.isDead, isTrue);
    expect(c.pet.deathCause, isNotNull);
    expect(c.screen, isA<DeathScreen>());
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/game/acceptance_test.dart`
Expected: PASS.

If the hunt's enrichment assertion fails, check that the loop actually left the hunt: `applyMinigame` only fires on the fifth `update`, and the reveal has to have expired for each round. If the death assertion fails, lengthen the neglect window rather than weakening the assertion — six days should be far past the point of no return for an untended piglet.

- [ ] **Step 3: Write the dev harness**

Create `lib/dev/device_dev_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart' hide Form;
import 'package:hog_sim/hog_sim.dart';

import '../device/device_shell.dart';
import '../game/clock.dart';
import '../game/game_controller.dart';
import '../sprites/sprite_registry.dart';

/// Dev-only: the real device, on a clock you can wind.
///
/// The shell has no idea it is being faked — it is the same widget `/` mounts.
/// This is the only way to see the long arcs by hand: fifteen minutes of egg is
/// fifteen seconds at 60x, seventy-two hours of childhood is seventy-two
/// seconds at 3600x, and a death by neglect is about two minutes.
///
/// M5 replaces the fake clock with the real debug clock.
class DeviceDevPage extends StatefulWidget {
  const DeviceDevPage({super.key});

  @override
  State<DeviceDevPage> createState() => _DeviceDevPageState();
}

class _DeviceDevPageState extends State<DeviceDevPage> {
  static const List<int> _speeds = [1, 60, 600, 3600];

  late final FakeClock _clock;
  late final GameController _controller;
  Timer? _timer;
  int _speed = 1;

  @override
  void initState() {
    super.initState();
    _clock = FakeClock(DateTime.now().millisecondsSinceEpoch);
    _controller = GameController(clock: _clock, utcOffsetMinutes: 0);
    // Drives both the fake clock and the controller, so a speed multiplier is
    // simply a bigger step per frame.
    _timer = Timer.periodic(
      const Duration(milliseconds: kAnimFrameMillis),
      (_) {
        _clock.advance(kAnimFrameMillis * _speed);
        _controller.tick();
        setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _jump(int millis) {
    _clock.advance(millis);
    _controller.tick();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pet = _controller.pet;
    final ageMinutes = (_clock.nowMillis - pet.bornAtMillis) ~/ 60000;
    final localHour =
        ((_clock.nowMillis + pet.utcOffsetMinutes * 60000) ~/ 3600000) % 24;

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(title: const Text('Device (fake clock)')),
      body: Column(
        children: [
          Expanded(child: DeviceShell(controller: _controller)),
          Container(
            color: const Color(0xFF2A2A2A),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '${pet.stage.name}/${pet.form.name} · '
                  'age ${ageMinutes ~/ 60}h${ageMinutes % 60}m · '
                  'local ${localHour.toString().padLeft(2, '0')}:00'
                  '${pet.isDead ? ' · DEAD ${pet.deathCause?.name}' : ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in _speeds)
                      ChoiceChip(
                        label: Text('${s}x'),
                        selected: _speed == s,
                        onSelected: (_) => setState(() => _speed = s),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (label, millis) in const [
                      ('+5m', 5 * 60 * 1000),
                      ('+1h', 60 * 60 * 1000),
                      ('+6h', 6 * 60 * 60 * 1000),
                      ('+24h', 24 * 60 * 60 * 1000),
                    ])
                      OutlinedButton(
                        onPressed: () => _jump(millis),
                        child: Text(label),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rewire the routes**

In `lib/main.dart`, change the class doc comment and the routes map. `/` becomes the device; the dev menu moves behind `/dev` and gains an entry for the harness.

```dart
      routes: {
        '/': (_) => const DevicePage(),
        '/dev': (_) => const DevMenuPage(),
        '/dev/device': (_) => const DeviceDevPage(),
        '/dev/preview': (_) => const PetPreviewPage(),
        '/dev/sprites': (_) => const SpriteGalleryPage(),
        '/dev/editor': (_) => const SpriteEditorPage(),
      },
```

Add `import 'device/device_shell.dart';` and `import 'dev/device_dev_page.dart';`, and replace the stale doc comment on `HogPocketApp`:

```dart
/// Hog Pocket.
///
/// `/` is the device. Everything under `/dev` is scaffolding — the fake-clock
/// harness, the pet preview, the sprite gallery and the editor — and none of it
/// is reachable from the device itself.
```

Then add a button to `DevMenuPage`, first in the list because it is now the most useful one:

```dart
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/dev/device'),
              child: const Text('Device (fake clock)'),
            ),
            const SizedBox(height: 12),
```

and demote the existing `Pet preview` button from `FilledButton` to `OutlinedButton` so there is still exactly one primary action.

Finally, `test/widget_test.dart` asserts the app boots to the dev menu, which stops being true the moment `/` becomes the device. Rewrite it:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/device_shell.dart';
import 'package:sooey/main.dart';

void main() {
  testWidgets('boots to the device, not to the dev menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    await tester.pumpWidget(const HogPocketApp());

    expect(find.byType(DeviceShell), findsOneWidget);
    expect(
      find.text('Sprite gallery'),
      findsNothing,
      reason: 'the scaffolding should be behind /dev now',
    );

    // DevicePage runs an animation timer; unmount it so the test does not end
    // with one pending.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
  });
}
```

- [ ] **Step 5: Run everything**

```bash
flutter test
cd packages/hog_sim && dart test && dart test -p chrome && cd ../..
cd functions && npm test && cd ..
```

Expected: the Flutter suite green except the one known `kGrave` failure; 119 and 114 from `hog_sim`; 14 from `functions`. `packages/hog_sim/test/golden/vectors.json` must be unchanged — `git status` should not list it.

- [ ] **Step 6: See it run**

```bash
./scripts/dev.sh    # then open http://127.0.0.1:5173
```

`flutter run` does not rebuild on save — it waits for `r` in its terminal, and you will be served the previous bundle. Use the script.

Check by hand, and screenshot for Dave rather than describing it:
- `/` opens on the crest picker; A cycles eight emblems, B commits, the egg wobbles.
- `/dev/device` at 3600x: the egg hatches in seconds, the piglet grows up, the pig eventually dies and the grave appears with the crest beside it.
- The strip: A walks the cursor through all seven icons and back; the selected one is brighter than the rest and the strips share the matrix's dot pitch.
- Feed twice in a row and watch the feed icon blink rather than the pig's face change.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/dev/device_dev_page.dart test/game/acceptance_test.dart
git commit -m "feat: mount the device at / and add the fake-clock dev harness"
```

---

## Done when

- `flutter test` is green but for the pre-existing `kGrave` failure.
- `dart test` and `dart test -p chrome` are 119 and 114; `functions` is 14.
- `vectors.json` is untouched — nothing here may change the simulation.
- A pet can be fed, cleaned and played with, and dies if left alone.
- Nowhere on the glass is there a letter or a numeral.
