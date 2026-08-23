# Hog Pocket — handoff

**Read this first.** It records what is built, what was decided, and the things
that will waste your time if you rediscover them the hard way.

The spec is [`pig-tomagotchi-spec.md`](pig-tomagotchi-spec.md). It is still the
design authority, but several decisions have since overridden it — see
[Deviations](#deviations-from-the-spec). Where this document and the spec
disagree, this document is what the code does.

**Status: M1 through M4 are complete and verified. M5 is next.**

---

## What this is

A 1996-style Tamagotchi. The player raises a pig on a simulated 32×16
monochrome LCD. The pig ages in real time whether or not the app is open. If it
is neglected it dies permanently and the player starts over.

The emotional core is **permadeath plus hidden judgment**: the game never tells
the player they are doing badly, but the adult the pig grows into is decided by
care quality they cannot see. Several rules in the code exist only to protect
that premise — they are called out below.

---

## Getting it running

```bash
./scripts/dev.sh          # then open http://127.0.0.1:5173
```

**`flutter run` does not rebuild on save.** It waits for you to press `r` in its
terminal. Edit a sprite, reload the browser, and you are served the *previous*
bundle — which looks exactly like your change having no effect. `scripts/dev.sh`
keeps flutter's stdin on a FIFO and writes a hot restart into it whenever
anything under `lib/` changes. Use it; this cost an hour once already.

Routes:

| Route | What it is |
| --- | --- |
| `/` | The device itself, on the real `SystemClock`. |
| `/dev` | The dev menu — links to everything below. |
| `/dev/device` | The same device widget as `/`, mounted on a `FakeClock` with speed and jump controls, for watching the long arcs by hand. |
| `/dev/life` | A bot plays a whole life unattended at 600x-10800x, at one of three care qualities. The only way to see an entire life cycle. |
| `/dev/preview` | Drives the real composer from a pet you can poke at. Start here for sprite work. |
| `/dev/sprites` | Every sprite animating at 600ms, with pause and step |
| `/dev/editor` | 32×16 grid editor that emits paste-ready Dart |

Only `/` is meant for playing the game; everything under `/dev` is
scaffolding and is not reachable from the device itself.

## Verifying everything

```bash
cd packages/hog_sim && dart test        # 120 — the simulation
cd packages/hog_sim && dart test -p chrome   # 115 — same suite under dart2js
flutter test                            # 244 — renderer, sprites, composer, the M4 input machine, the life cycle harness
cd functions && npm test                # 14  — the JS bridge conformance
```

All four must pass, with one standing exception: `flutter test` carries one
known failure, `every sprite in the cast is well formed` on `prop.grave` —
Dave's grave redraw is mid-flight and not yet the declared size. Expect
244 passes and that one failure until it lands; anything else red is a
real regression. The `-p chrome` run is not optional — see
[Determinism](#determinism-the-thing-most-likely-to-bite-you).

---

## Architecture

```
packages/hog_sim/        pure Dart. No Flutter, no Firebase. The only simulation.
        |
        |-- path dependency ------> lib/  (Flutter client)
        |
        '-- dart compile js ------> functions/generated/hog_sim.js
                                          ^
                                    functions/src/  (TS: auth + Firestore only)
```

The simulation is written **once**, in Dart, and compiled to JS for the server.
`functions/src/sim.ts` is a typed façade with no game logic in it. Any rule that
leaks into TypeScript is a bug — the client runs the same Dart for its
optimistic UI, and a duplicated rule is a rule that can drift.

`packages/hog_sim/test/golden/vectors.json` holds 92 cases generated on the Dart
VM and replayed in Node against the compiled bundle. That is the check that the
two runtimes agree. Regenerate deliberately:

```bash
cd packages/hog_sim && dart run tool/emit_golden_vectors.dart
```

A diff in that file means the simulation's observable behaviour changed. Fine
when intended, a bug when not.

### Layout

```
packages/hog_sim/lib/src/
  constants.dart     every tunable number. No magic numbers live anywhere else.
  pet_state.dart     immutable model, JSON round-trip, Stage/Form/DeathCause
  advance.dart       the tick loop (spec §5.3 order, which is observable)
  actions.dart       pure action application
  stages.dart        stage timings, forms, lifespans, sleep window, sickness
  rng.dart           deterministic 32-bit randomness — read its header

lib/
  lcd/               LcdSprite, LcdBuffer, LcdPainter, LcdScreen, palette
  sprites/           the cast, as hand-authored ASCII, plus the registry
  game/
    pet_appearance.dart   state -> mood / pose / calling
    frame_composer.dart   state -> a full 32x16 frame
  dev/               preview, gallery, sprite editor
```

---

## Determinism: the thing most likely to bite you

The simulation runs on the Dart VM (tests), in dart2js on the server, and in the
browser. All three must produce **byte-identical** output or the client's
optimistic prediction disagrees with the server and the pig visibly snaps on
every sync.

Two Dart properties break this. Both were measured, not theorised:

**`String.hashCode` differs between runtimes.** `'pet_abc'.hashCode` is
`1023914457` on the VM and `512388185` under dart2js. Never use `hashCode` in
`hog_sim`; use `stableHash()`.

**Ints are 64-bit on the VM but IEEE-754 doubles under dart2js.** Any product of
two 32-bit values reaches 2^64, so masking *after* a plain `*` is already too
late — the precision is gone before the mask runs. The naive FNV multiply passes
on the VM and returns a value 4 too low in JS. Every multiply in `rng.dart` goes
through `_mul32`, which works in 16-bit halves.

The rule: **no `hashCode`, and no integer arithmetic in `hog_sim` without
thinking about 2^53.** Run `dart test -p chrome` after touching it.

---

## Deviations from the spec

These are decisions, not oversights. Do not "fix" them back.

**No shoat stage.** A pig is an egg, then a piglet for its whole 72-hour
childhood, then an adult. Time to adulthood is unchanged. The adult form
branches at the single piglet→adult transition, so the hidden judgment now
weighs the entire upbringing. Two balance values moved with it: the piglet decay
multiplier is 1.25 (the time-weighted average of the two stages it replaced) and
the mistake bands scaled 1.5× to 5 / 14 / 38.

**The mistake bands are 2 / 5 / 8, not the spec's 3 / 9 / 25 or the 5 / 14 / 38
they were first scaled to.** A care mistake costs 18 health and health returns
at 0.2 a tick, so an 864-tick childhood affords about eight of them. The old
bands put the entire runt range past the point where the pig was already dead —
four different deliberate-neglect policies, swept across twenty parameter
combinations, all topped out at 8 mistakes. `life-cycle-harness-design.md` has
the measurement. `/dev/life` is what keeps the new bands honest.

**Front-facing outlined art, not the spec's side view.** Dave drew a
front-facing outlined pig and it is much better: a pig in profile has no face to
emote with. The spec's reference piglet is not used — its single-pixel eyes
split the head into three chunks and read as two blobs. The spec's adult
reference sprite survives as `kFaceIdle1`, the farm hog.

**Death causes are decided by priority, not a 24-hour window.** The spec asks
for `starvation` when health hits zero *and* fullness has been zero for 24
hours. That is unreachable: one zeroed need drains full health in 67 ticks
(5.6h), so nothing survives 288 ticks of starvation to qualify. Implemented as
`fullness == 0` → starvation, else `isSick` → illness, else neglect; old age
when the clock runs out. All four causes are now reachable.

**Mood is a new axis**, not in the spec. See below.

**Values the spec references but never defines** live under a marked heading in
`constants.dart`: per-stage decay multipliers, ideal weight bands, and the egg
not decaying. They are balance knobs.

**`advance` takes `int nowMillis`, not `DateTime`.** Keeps JSON and the JS
bridge free of date conversion.

---

## Rules that protect the game's premise

**Mood must never read `careMistakes` or `stageCareMistakes`.** Those decide
which adult the pig becomes and the player is never told. A pig that looks
miserable because it is hungry is honest feedback it can act on; a pig that
looks miserable because it is tracking toward a runt hands over the secret the
whole design rests on. `moodFor` in `pet_appearance.dart` reads current needs
only, and two tests assert it — including one that sweeps every need level.

**Dave has asked for the adult build to be labelled with text in the UI.** This
contradicts spec §4.2 and §8, which say the form name is never shown. He was
told, and confirmed. Build it as asked; the concern is on the record and does
not need raising again.

---

## Working on sprites

Sprites are hand-authored ASCII in `lib/sprites/*.dart`, not assets. `#` is a lit
dot, `.` unlit, and a space is **transparent** — that third state is what lets
poops and status icons composite over the pig without punching holes in it.

The loop: open `/dev/editor`, hit **Load**, draw, **Copy as Dart**, paste over
the existing literal. The clipboard output names the constant and the file.

Then **always** run:

```bash
flutter test test/sprites/
```

A row one character short does not crash anything — `blit` quietly draws 31
columns and drops the last one, so you get a subtly wrong pig and no error
anywhere. This has caught it three times.

The cast, all four builds × seven poses:

```
piglet     idle happy sad sick eating sleeping wallowing
farmHog    idle happy sad sick eating sleeping wallowing
prizeHog   idle happy sad sick eating sleeping wallowing
runt       idle happy sad sick eating sleeping wallowing
```

Plus `egg` and the props (poop, heart, sick, call, lightOff, grave).

`kHeart` blinks over the mound after a won round of the truffle hunt —
the celebration it was registered for, landed with M4.

Design notes worth keeping:

- The three adults are identical apart from **skull width** — 17 / 15 / 13
  columns around an unchanged 7-wide snout. That one trick makes a prize hog
  read as well-fed and a runt as underdeveloped without a caption.
- **Mood lives in the eye rows only.** Redrawing the skull to change an
  expression is how you get a head that no longer lines up with its own snout.
  That bug shipped once.
- Both frames of an animation must keep the **same lowest lit row**, or the pig
  hovers instead of moving. A test enforces it.

---

## Gotchas

**`Form` collides with Flutter's form widget.** Any file importing both
`hog_sim` and `material.dart` needs `hide Form` on the material import. This
will recur throughout the UI work.

**`kPoopSlots` must have at least `kMaxPoops` entries**, or a full pen renders
tidier than it is and the player gets sick for reasons nothing on screen
explains. A test holds them together.

**The Firestore emulator, not the real project.** Nothing is deployed. Before a
first deploy: `firebase.json` sets the Firestore location to `nam5`, which spec
§2 warns against — compute must be co-located, and that field only applies at
database *creation*. Hosting also still points at `public/` rather than
`build/web`, and both GitHub workflows have a literal `run: "?"` placeholder.

---

## Milestones

| | | |
| --- | --- | --- |
| **M1** Simulation | **done** | 6h in one call == 72 × 5min, incl. across sleep, stage change and death mid-window |
| **M2** Bridge | **done** | 92/92 VM vectors replay identically through dart2js in Node |
| **M3** Renderer | **done** | crisp at three widths with no fractional dots; golden frames per creature state |
| **M4** Local loop | **done** | a pet can be fed, cleaned and played with, and dies if left alone, entirely on the strict three-button interface |
| **M5** Persistence | **next** | anon auth, callables, rules, emulator, debug clock, seeder |
| **M6** Life cycle | | transitions, three forms, death, tombstones, new pet — `/dev/life` already exercises transitions, all three forms and death end to end; tombstones and new-pet remain |

Out of v1: push notifications, account linking, live deploy, discipline and
training (spec D2), sound, graveyard, lineage.

### M4 — the local loop

Everything it needs already exists and is tested. This is assembly, not
invention: `advance`, `applyAction`, `applyMinigame`, `composeFrame` and the
full cast are done.

Build:

- A `GameController` holding one pet in memory, ticking it through `advance()`
- The **three-button A/B/C** interface — cycle, confirm, cancel
- Seven icons in two rows around the screen (train is cut per D2): feed, wallow,
  play, meds, clean, stats, light
- The feed submenu — slop or treat
- Truffle hunt, best of five, resolved client-side
- The crest picker (eight emblems, no text anywhere on the device) and the death
  screen
- The device shell: `LcdTheme.shell` `#E3A6B5`, border and buttons `#C4899A`

Nothing persisted — a pet that vanishes on reload is fine for this milestone and
keeps the input state machine separate from the Firestore work in M5.

**Accept:** a pet can be fed, cleaned and played with, and dies if left alone.

`/dev/preview` already proves the display half end to end. The missing piece is
input and state.

Before the input layer was built, Dave was asked whether the spec's **fixed
three-button** interface — no tapping the screen, no tapping icons directly —
should be built faithfully, or whether icons should also be directly tappable
with the three buttons kept as the primary path. He confirmed strict three
buttons. Nothing on the glass or the shell responds to a tap; that answer is
what shaped the icon strip as fixed glass segments rather than a tappable
menu, and the crest picker as a cycle-and-confirm rather than a grid you reach
into.

---

## Working style that has been productive

Dave edits sprites directly and has good instincts — several of his corrections
(the front-facing direction, per-build wallows, the poop slider bound) were
right where the earlier work was wrong. Show rendered screenshots rather than
describing art, get direction early, and take his version when he redraws
something.

Tests come first, and they have repeatedly caught real bugs rather than
decorating finished work: the dart2js divergence, the hovering sleeping piglet,
three short sprite rows, and the poop-slot mismatch.
