# M4 — the local loop

Design for the milestone that turns the finished display into a game you can
play. Read [`HANDOFF.md`](HANDOFF.md) first; this assumes it.

Where this document and [`pig-tomagotchi-spec.md`](pig-tomagotchi-spec.md)
disagree, this document is what M4 builds, and the disagreements are listed
under [Deviations](#deviations-from-the-spec).

**Scope:** input and state. Nothing is persisted — a pet vanishes on reload,
deliberately, so the input machine lands before the network does.

**Accept:** a pet can be fed, cleaned and played with, and dies if left alone.

---

## The four decisions this hangs on

Asked and answered before any of it was designed.

**Strict three buttons.** A cycles, B confirms, C cancels. Nothing on the glass
or the shell responds to a tap. Spec §6 calls the constraint the charm and it is
taken literally. The keyboard's arrow keys and Enter map to the three buttons —
that is a physical button by another name, not a touch UI.

**The icons are fixed segments on the glass**, not printed on the plastic. They
are dot art in the same three-state alphabet as everything else, above and below
the matrix, on the same piece of simulated LCD. Selection is brightness: the
chosen icon is fully lit, the rest sit at a dim intermediate tone.

**The truffle hunt is a pig trotting to one side**, not a pig turning to face
one. The front-facing redesign left the cast with no left or right — all 28
creature sprites face the player — so the minigame's verb had to change. The pig
slides to the mound it picked and snuffles there in the existing eating pose. No
new creature art.

**Nothing is written in words.** No font, no numerals, nowhere. This is a taste
call rather than a technical limit — `kGrave` carries RIP in 3-wide glyphs and it
reads — but a dot-matrix toy that shows you words and numbers stops being a toy
and starts being a dashboard. The 1996 original had essentially no text on
screen. Quantities are bars, counts are pips, labels are the icon you would press
to fix the thing being labelled.

Going textless made this milestone smaller: a ~40-glyph font and a text layout
engine dropped out, and about twenty small sprites came back in.

---

## What already exists

All of it tested, none of it changing: `advance`, `applyAction`,
`applyMinigame`, `composeFrame`, `moodFor`, `poseFor`, the full 28-sprite cast,
`LcdSprite`, `LcdBuffer`, `LcdPainter`, `LcdScreen`. M4 is assembly plus an
input machine plus twenty-one new sprites.

`hog_sim` is not touched at all. If a change to it seems necessary, that is a
signal something has been misunderstood — go back and check, because the golden
vectors and the dart2js agreement both hang off it.

---

## The glass

The display is one piece of glass 32 dots wide and 32 tall:

```
rows  0-6    top icon strip      feed  wallow  play  meds
row   7      gap
rows  8-23   the 32x16 matrix    the pig lives here
row   24     gap
rows 25-31   bottom icon strip   clean  stats  light  (empty)
```

Both strips use the same four-column grid — 7x7 icons at x = 0, 8, 16, 24.
Keeping the grid rather than centring three across the bottom is what keeps the
two strips reading as one bezel. The fourth bottom slot stays dark; it is where
`train` was before D2 cut it.

`LcdGlass` computes the dot size **once** from the whole 32x32 box and hands the
same integer down to all three painters. This is the part most likely to be got
wrong: a strip that derives its own dot size from its own box ends up on a
different pitch from the matrix, and the result reads as two screens glued
together rather than one. Integer scaling only, for the reason `lcd_painter.dart`
already documents.

### Two small changes underneath

`LcdBuffer` and `LcdPainter` are both hardcoded to 32x16. The strips are dot art
on the same glass and need their own size and a second tone, so:

- `LcdBuffer.sized(width, height)` alongside the existing default constructor,
  with `width`/`height` becoming fields that `blit`, `clear` and `toAscii` clip
  against instead of the constants. `LcdBuffer()` behaves exactly as it does now
  and every current call site is untouched. `kLcdWidth`/`kLcdHeight` remain the
  sprite-authoring grid and do not move.
- `LcdTheme.dotDim`, a tone between `dotOn` and `dotOff`, for unselected icons.
- `LcdMatrix`, the dot-grid half of `LcdScreen` split out so it can be given a
  dot size rather than computing its own. `LcdScreen` keeps its behaviour and is
  rewritten in terms of it; the glass needs the same split.

`LcdPainter` is **not** changed. The obvious approach — teaching it a second
colour — turns out to be the wrong one, because a strip needs two tones in a
single pass and a painter with one `onColor` would have to be stacked with
another, the upper one painting its unlit dots over the lower. The strip gets its
own painter taking two same-sized buffers, `lit` and `dim`: a dot in `lit` paints
`dotOn`, one in `dim` paints `dotDim`, the rest paint `dotOff`. One pass, no
stacking, and the matrix painter stays exactly as it is.

---

## The state machine

`GameController` owns exactly three things — the pet, the clock, and a stack of
screens — and is **the only thing that mutates the pet**. A 600ms timer bumps the
animation counter and calls `advance(pet, clock.nowMillis)`, which is cheap
because `advance` steps in whole five-minute ticks and no-ops until one has
elapsed.

Screens never touch the pet. They handle a press and return an intent:

```dart
enum Button { a, b, c }
enum DeviceIcon { feed, wallow, play, meds, clean, stats, light }
enum Crest { leaf, star, horseshoe, clover, crown, moon, anchor, bolt }

sealed class Transition {}
class Stay    extends Transition {}
class Push    extends Transition { final DeviceScreen screen; }
class Pop     extends Transition {}
class Act     extends Transition { final PetAction action; }  // apply, then pop
class Played  extends Transition { final int wins; }          // -> applyMinigame
class Crested extends Transition { final Crest crest; }       // the pet begins
class Restart extends Transition {}                           // after death

abstract class DeviceScreen {
  Transition handle(Button b, GameContext ctx);
  LcdBuffer compose(GameContext ctx, int frame);

  /// Called once per animation frame, before compose, for screens whose state
  /// moves on its own. Only the truffle hunt overrides it.
  Transition update(GameContext ctx) => const Stay();

  /// Which strip icon stays lit while this screen is on top, or null.
  DeviceIcon? get litIcon;
}
```

`Transition` is sealed — every case lives in that one file, so the controller's
switch over it is checked. `DeviceScreen` cannot be: Dart only allows sealing
when every subtype is in the same library, and the whole point of the structure
is that each screen is its own file. Nothing switches over screen types anyway,
so sealing it would buy nothing.

`update` exists because the truffle hunt is the one screen whose state advances
without a press — the reveal has to end on its own. Doing that inside `compose`
would put a mutation in a render path, and every other screen would inherit the
hazard.

`GameContext` is read-only: the pet, the crest, `nowMillis`, and the transient
pose. A screen may hold its own cursor or round counter — that is UI state by
definition — but nothing about the pig.

That split is the whole reason for the structure. A screen is testable with no
controller, no clock and no pet in play: `drive(TruffleHunt(seed), 'ACACA')`
returns a list of transitions and a frame you can read in a diff.

`litIcon` gives the strip a rule rather than a special case per screen: whichever
screen is on top says which icon it belongs to, so the feed icon stays lit while
you are inside the feed menu, and the crest, egg and death screens light nothing.

### Feedback for accepted and refused actions

An accepted action sets a transient pose for `kTransientPoseMillis` (3s) —
`composeFrame` already takes one. Slop and treat show eating, wallow shows
wallowing, clean simply has the poops disappear.

A refusal — `notHungry` when the pig turns down a fifth bucket, `cooldown` on the
hunt — **blinks the selected strip icon three times**. It must not be shown by
putting a sad face on the pig. `moodFor` reads current needs only, deliberately,
so that what the pig's face says is always true about the pig; borrowing that
face to mean "the button didn't work" would make the one honest signal in the
game lie.

---

## The screens

**Crest** — the first screen a new pet ever shows. Eight emblems: leaf, star,
horseshoe, clover, crown, moon, anchor, bolt. One shown at a time, 7x7 and
centred, small chevrons either side. A cycles, B confirms. You mark the egg
before you know what is inside it.

7x7 rather than something grander because the crest has to fit the death screen's
left gutter as well as this one, and choosing it at the size you will live with
beats choosing a big one that shrinks. It is also the icon grid's size, so the
whole device stays on one scale.

This replaces the spec's name entry. The 1996 original never let you name your
pet, and a 12-slot letter picker is the worst screen a three-button device can
have — 26 presses to reach Z. The crest does what the name did: it makes the pig
yours, and it is what gets carved into the grave.

**Home** — the pig on the matrix via the existing `composeFrame`, the strip live.
A moves the selection, B activates it, C deselects. Seven icons, so from any one
of them seven presses of A come back to it.

There is no separate egg screen. `creatureAnim` already returns the egg for
`Stage.egg` and `applyAction` already refuses everything but the light until it
hatches, so home renders the wobbling egg and refuses presses for its fifteen
minutes without a line of code that knows what an egg is. No crack animation in
M4; there is no art for one.

**FeedMenu** — slop and treat as two icons on the matrix. A toggles, B confirms
and emits `Act`, C pops. Pushed by the feed icon; the feed icon stays lit. Slop
reuses the strip's feed icon; treat needs one new apple, which spec §7.1 names.

**Stats** — paged with B, exited with C.

```
page 1   four vertical bars, each with its icon beneath
         fullness/feed  enrichment/play  comfort/wallow  cleanliness/clean

page 2   heart + health bar, weight mark + weight bar

page 3   age as day pips, and for adults the rosette
```

Page 1 needs no labels because the label is the icon you would press to fix it.
Each bar is a 7-wide outlined track over rows 0-8, so its interior is 5 wide and
7 tall — eight distinguishable states counting empty — filling from the bottom.
Icons sit at rows 9-15. The four are shown in `kNeedNames` order, which is also
the order the tick loop evaluates them.

**Death** — the grave centred, the pet's crest in the left gutter, its age in
pips in the right. Nothing else, exactly as spec §8 asks, and in particular no
care-mistake count. B starts a fresh pet, which in M4 means a new in-memory one
and back to the crest screen.

The crest sits *beside* the stone rather than on it: `kGrave` already has RIP
punched through its middle, relettered deliberately, and there is nowhere on a
16x12 slab to put a second mark without wrecking it. Centred, the grave leaves
eight columns either side, which a 7x7 crest fits with a column to spare. That
tolerance is the constraint on any future regrave — past about 18 columns wide,
the gutters stop fitting the crest.

This screen composes its own buffer rather than calling `composeFrame`, which
short-circuits a dead pet to a bare grave and nothing else.

---

## The truffle hunt

Best of five, resolved client-side, per spec §7.4.

Each round draws two mounds at fixed floor positions, left and right, with the
pig centred. A guesses left, C guesses right; B is idle during a round. The pig
then slides to the side it chose — a horizontal blit offset, no new creature art
— and drops into the existing eating pose to snuffle. A hit flashes `kHeart`,
which is finally what that registered-but-undrawn sprite is for.

**A match cannot be abandoned, and that follows from the spec rather than being
a choice.** §7.4 spends A and C on the two guesses, which leaves no third button
for "back" — this is the one screen where C does not mean cancel. Nothing gets
stuck: five presses ends the match, each round resolves in a second and a half,
and the controller pops the screen when the result is applied.

**Draw order is pig, then mounds, then tally.** The creature sprites are full
32x16 with unlit dots everywhere around the pig, so blitting one at an offset
paints over anything already beneath it. Mounds go on top, or they get erased.

The tally runs along the top: a win is a filled mark, a loss a single dot, an
unplayed round nothing — so round three is distinguishable from two losses.

**The pig's per-round choice must not use `hog_sim`'s RNG.** That generator is
seeded off `petId` and tick precisely so the VM, dart2js and the browser agree
dot for dot; drawing from it here would make the simulation's output depend on
whether the player happened to play a minigame. The hunt is client-side and
deliberately unvalidated, so it takes an injected `dart:math` `Random` that tests
seed.

At the end the controller calls `applyMinigame(pet, wins: n, rounds: 5)`, which
enforces the two-minute cooldown. A `cooldown` refusal blinks the play icon
rather than doing nothing.

---

## The clock

```dart
abstract interface class Clock { int get nowMillis; }
class SystemClock implements Clock { ... }   // DateTime.now()
class FakeClock   implements Clock { ... }   // settable, scalable, jumpable
```

`/` mounts the device on `SystemClock`. `/dev/device` mounts **the same widget**
on a `FakeClock` with speed (1x / 60x / 600x / 3600x) and jump (+5m / +1h / +6h /
+24h) controls beneath it, plus a readout of stage, age and local time. The shell
never knows it is being faked.

That is the only way to see the long arcs by hand: 15 minutes of egg is 15
seconds at 60x, 72 hours of childhood is 72 seconds at 3600x, and a death by
neglect is about two minutes. M5 swaps `FakeClock` for the real debug clock.

The existing dev menu moves from `/` to `/dev`; `/` becomes the device.

---

## New art

Twenty-one small sprites, all hand-authored in the existing three-state alphabet,
all swept by the well-formedness test, all loadable in `/dev/editor`.

| | |
| --- | --- |
| 7 strip icons, 7x7 | feed, wallow, play, meds, clean, stats, light |
| 1 apple, 7x7 | treat, in the feed menu; slop reuses the feed icon |
| 8 crests, 7x7 | leaf, star, horseshoe, clover, crown, moon, anchor, bolt |
| 3 rosettes, 7x7 | prize (full, with streamers), farm (plain ribbon), runt (bare) |
| 1 weight mark, 7x7 | for the stats page |
| 1 mound, 5x3 | for the truffle hunt |

Everything but the mound is 7x7. One scale across the whole device is what keeps
a crest, an icon and a rosette looking like parts of the same object.

Bars and pips are drawn procedurally in `lcd_bars.dart`, not authored.

Registering these breaks two existing tests, and the fix is the point rather than
a workaround. `creature animations move between their two frames` and `keep the
creature planted on the same floor line` currently sweep the whole registry and
skip anything keyed `prop.`, so a still icon under `icon.feed` would fail both.
They should iterate `kBuildKeys × kRequiredPoses` plus `egg` instead — the
creatures they are actually about. Filtering by prefix would work today and rot
the first time somebody adds a category.

Expect to hand the icons over early and take Dave's redraws — the handoff records
that going the other way has been the wrong call every time so far.

---

## Layout

```
lib/game/
  clock.dart              Clock, SystemClock, FakeClock
  game_constants.dart     presentation tunables (transient pose duration, ...)
  game_controller.dart    the pet, the clock, the screen stack
  screens/
    device_screen.dart    the base, Button, DeviceIcon, Crest, Transition,
                          GameContext
    crest_screen.dart
    home_screen.dart
    feed_menu.dart
    stats_screen.dart
    truffle_hunt.dart
    death_screen.dart
lib/device/
  device_shell.dart       the pink plastic, three buttons, keyboard mapping
  lcd_glass.dart          strips + matrix on one dot pitch
  icon_strip.dart         the strip, and its two-tone painter
lib/lcd/
  lcd_bars.dart           drawVerticalBar, drawHorizontalBar, drawPips
  lcd_matrix.dart         the dot grid at a given dot size
lib/sprites/
  icon_sprites.dart
  crest_sprites.dart
  rosette_sprites.dart
lib/dev/
  device_dev_page.dart    the fake-clock harness
```

Many small files rather than few large ones, which is the point of the structure
that was chosen: each is understandable on its own and each has a test that
drives it on its own.

`Form` collides with Flutter's form widget, so every file here that imports both
`hog_sim` and `material.dart` needs `hide Form` — as `pet_preview_page.dart`
already does.

The shell's palette is fixed: `LcdTheme.shell` `#E3A6B5`, border and buttons
`#C4899A`.

---

## Testing

Logic stays testable without a widget harness, as it already is everywhere else
in this repo.

- **Each screen** driven by a press string against golden ASCII frames.
  `drive(screen, 'ABCA')` returns the transitions; `compose()` returns a frame a
  human can read in a diff.
- **The controller** against a `FakeClock`: an action applies, a refusal
  surfaces, a pet left alone dies with a cause.
- **The strip**: every icon is reachable within seven presses of A, and the
  selected one is the lit one.
- **The glass**: strip and matrix resolve to the same dot size at several widths,
  the check `LcdPainter` already has for the matrix alone.
- **Bars and pips**: 0 and 100 render distinguishably, and pips draw no empty
  placeholders.
- **The new sprites** are picked up by the existing registry sweep.

The four existing suites stay green, `dart test -p chrome` included. Nothing in
M4 touches `hog_sim`, so the golden vectors must not move; if they do, something
has gone wrong.

---

## Deviations from the spec

Additions to the list already in `HANDOFF.md`.

**No text anywhere, and no names.** Spec §6 and §8 assume the pet has a name and
that the death screen shows it. It has a crest instead. `PetState.name` stays in
the model untouched — M5's Firestore schema wants it — and M5 will need a field
for the crest.

**Seven icons, not eight.** `train` was already cut by D2. Its slot in the bottom
strip stays empty rather than the remaining three being re-centred.

**The truffle hunt's pig trots rather than turns.** Spec §7.4 says the pig turns
left or right. The front-facing cast has no such pose and drawing eight of them —
two per build — would risk the skull-and-snout misalignment the handoff records
as having shipped once already.

**The adult build is shown as a rosette.** The handoff records Dave asking for
the build to be labelled in text, against spec §4.2 and §8. With text gone it is
a prize ribbon on stats page 3: full rosette for prize hog, plain ribbon for farm
hog, bare button for runt. It carries the same information a caption would, and
it ranks them, which is what he wanted.

**Age is pips with no denominator.** Not a bar, and not a fraction. The
denominator would be `expiresAt`, which is fixed at the piglet→adult transition
from the hidden mistake count — so an age bar would quietly hand the player the
judgment the entire design depends on keeping secret. Pips are drawn only for
elapsed days, with no empty placeholders, so nothing on screen implies a total.

---

## Out of scope

No persistence, auth, Firestore or callables — that is M5. No stage-transition or
death ceremony beyond the screens above, no tombstones and no new-pet flow beyond
"B on the death screen starts another" — that is M6. No sound, no notifications,
no discipline.
