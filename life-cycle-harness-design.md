# The life cycle harness — design

A dev-only harness that plays a pig from egg to grave, unattended, on the real
device, so a whole life cycle can be watched in minutes. Read
[`HANDOFF.md`](HANDOFF.md) first; this assumes it.

It comes with a balance change, because measurement during design showed that
one of the three adults cannot currently be reached by play at all.

**Scope:** one new dev route, one care bot, and a four-line rescale of the
mistake bands. No milestone work — nothing here is reachable from `/`, and M5
and M6 are untouched.

**Accept:** from `/dev/life`, pick a care quality, press start, walk away, and
come back to a grave — having produced a prize hog, a farm hog or a runt on
purpose, with a log of what happened on the way.

---

## The four decisions this hangs on

Asked and answered before any of it was designed.

**Watched live on the device, not reported.** The alternative was a headless run
that emits a timeline and a contact sheet of frames. Rejected: the point is to
see the pig live, and a report cannot show that the device survived a life.

**Fully unattended.** The bot picks the crest, tends the pig and plays the
truffle hunt for the entire run. No takeover, no scrubbing, no jump-to-event.
Press start and watch. A repeatable run is worth more than an interactive one,
and taking the buttons back mid-life is a different feature.

**Three care qualities, one knob.** Attentive, adequate and sloppy, producing
the three adults. The form is decided purely by care-mistake count at the
piglet→adult branch, so one number — how many mistakes the bot intends to make
during childhood — covers all three.

**The bot presses real buttons.** It navigates the icon strip with A, confirms
with B and backs out with C, through `GameController.press`, exactly as a player
would. The alternative — applying actions straight to the pet — is simpler but
leaves the device idling on the home screen with needs silently refilling, and
puts none of the M4 input machine under test. A full life is 5,760 ticks and well over a
thousand presses through the real screen stack, which is a far harder exercise
of that machine than any unit test.

---

## Part 1 — the runt is unreachable, and the bands have to move

### What was measured

Two throwaway policies were run headlessly against `hog_sim`, driving a pig from
egg to the piglet→adult branch and trying to accumulate as many care mistakes as
possible without killing it.

The first converts health into mistakes as fast as it can: neglect every need,
rescue the pig at a health floor, recover to a ceiling, repeat. Swept across
floors of 12/20/30/45 and ceilings of 70/90, its best result was **8 mistakes**.

The second plays optimally *for mistakes*: it zeroes only fullness and
enrichment — the two needs that can be topped up in small steps — holds comfort
and cleanliness above the recovery threshold so health can regenerate at all,
and restores to 56 rather than overshooting, so the next drain is as short as
possible. Swept across floors of 4/8/15/25 and ceilings of 60/80/100, its best
result was also **8 mistakes**. Nothing in twenty parameter combinations reached
nine.

Attentive care, as a baseline, produces 0 mistakes and health that never leaves
100.

### Why the ceiling is where it is

A care mistake costs 18 health: `kTicksAtZeroForMistake` (12) ticks with a need
at zero, at `kHealthLossPerZeroedNeed` (1.5) per tick. Health only comes back at
`kHealthRecovery` (0.2) per tick, and only while all four needs are above 50 and
the pig is not sick.

A childhood is `kPigletMinutes / kTickMinutes` = 864 ticks. So the entire health
budget available to spend on mistakes is `100 + 0.2 × 864` = 272.8, which is
**15.15 mistakes even if recovery ran on every single tick of childhood** — and
it cannot, because driving a need to zero means spending ticks below 50, where
nothing recovers. Fifteen is therefore an unreachable arithmetic ceiling, not
merely a hard target. Eight is the practical one.

The runt band begins at `kFarmHogMaxMistakes + 1` = 15. It cannot be entered by
a pig that survives its childhood. `kRuntWorstMistakes` = 38, the count at which
the runt's lifespan bottoms out, would require 684 health.

The reachable range is 0–8 against bands cut at 5 and 14. Prize hog is almost
everything, farm hog is a sliver reachable only by deliberate cruelty, and the
top of the farm band together with the whole runt band is dead space.

### The change

In [`constants.dart`](packages/hog_sim/lib/src/constants.dart), whose own header
calls these balance knobs:

| | now | becomes |
| --- | --- | --- |
| `kPrizeHogMaxMistakes` | 5 | **2** |
| `kFarmHogMaxMistakes` | 14 | **5** |
| `kRuntWorstMistakes` | 38 | **8** |

Which maps the range that exists onto the three forms: prize hog at 0–2, farm
hog at 3–5, runt at 6–8. Lifespan bands are untouched, and every band stays at
least three wide so `lifespanMinutes` keeps interpolating across a real range
rather than dividing by zero.

Nothing else changes. The health economy, the decay rates and the definition of
a mistake all stay exactly as they are — this is the smallest change that makes
all three adults reachable, and it is reversible by editing three numbers back.

What it means at the table: a pig whose needs never bottom out is a prize hog. A
pig that spends three to five hours of its childhood with something at zero is a
farm hog. A runt is a pig that spent six or more hours at zero and nearly died
doing it — which is what a runt should be.

### What it breaks

`stages_test.dart`, `advance_test.dart` and `golden_scenarios.dart` all
reference the bands symbolically, so they follow the new values without edits.
Two things need attention:

- `transition/keeps-lifetime-mistakes` in `golden_scenarios.dart` passes a
  literal `stageCareMistakes: 4`, which was a prize hog and becomes a farm hog.
  The case is about lifetime mistakes surviving the branch, so its intent is
  unaffected — but the literal should become symbolic so it cannot silently
  change meaning again.
- `packages/hog_sim/test/golden/vectors.json` must be regenerated with
  `dart run tool/emit_golden_vectors.dart`. Expect a diff in the transition
  cases and in every `expiresAtMillis` downstream of them. This is a deliberate
  regeneration: the simulation's observable behaviour has changed on purpose.

Both `dart test` and `dart test -p chrome` must pass afterwards, and
`cd functions && npm test` replays the new vectors through dart2js.

---

## Part 2 — the harness

### Shape

Two new files and one route. Nothing under [`lib/game/`](lib/game/) or
`packages/hog_sim/` changes for the harness itself — the bot is a player, and if
it needed the game to change in order to play, that would be a bug in the game
worth knowing about.

```
lib/dev/care_bot.dart         decides one press at a time
lib/dev/life_cycle_page.dart  route /dev/life: preset picker, run, readout
```

[`/dev/device`](lib/dev/device_dev_page.dart) is left exactly as it is for
hand-driving. The new page reuses the same `FakeClock` + `GameController` +
`DeviceShell` assembly.

### The bot

One method:

```dart
Button? nextPress(GameController controller);
```

Null means nothing to do this frame. The page calls it in a short loop, feeding
each answer straight back into `press()`, so every decision sees the screen the
previous press produced rather than a stale one.

It recognises where it is by switching on `controller.screen`:

| Screen | What it does |
| --- | --- |
| `CrestScreen` | B, taking the first crest. The crest is cosmetic and picking one is not what we came to watch. |
| `HomeScreen` | A until `litIcon` is the icon it wants, then B. |
| `FeedMenu` | A if `treat` is not the choice it wants, then B. |
| `TruffleHunt` | A whenever `revealing` is false — one guess per round, five rounds. |
| `StatsScreen` | C. It never opens this; the case exists so an unexpected screen cannot wedge the run. |
| `DeathScreen` | **null, always.** B there is `Restart` and would erase the life just watched. |

Everything it reads is already public — `litIcon`, `FeedMenu.treat`,
`TruffleHunt.revealing`, `pet.isSick`, `pet.poops`. No new accessors, and the
screens stay unaware they are being driven.

It carries one field of memory: the icon it is currently heading for, held until
the action lands or is refused. Without it, a need going urgent mid-navigation
would leave a menu half-open and the bot would thrash between goals.

### The care policy

Each frame the bot picks a goal from the pet, in priority order: medicate if
`isSick` (never otherwise — medicating a healthy pig costs 5 health), clean if
there are poops or cleanliness is low, then whichever serviceable need is
lowest. Fullness is slop, comfort is wallow, enrichment is the truffle hunt.
It also toggles the pen light off at 22:00 local and on at 07:00, which costs
nothing and makes the nights visible.

Care quality is one number: the mistakes the preset intends to make during
childhood.

| Preset | Intended mistakes | Expected adult |
| --- | --- | --- |
| attentive | 0 | prize hog |
| adequate | 4 | farm hog |
| sloppy | 7 | runt |

A preset makes its mistakes **early and all at once**, then cares perfectly for
the rest of childhood. While it is making them it stops servicing every need and
lets them all bottom out together, rescuing the pig whenever health falls to a
floor — 45 for adequate, which never looks dangerous, and 12 for sloppy, which
does. Once the intended count is reached it reverts to attentive care and the
pig recovers for whatever childhood is left.

That shape is not an aesthetic choice. Spacing single-need lapses evenly across
childhood was the obvious design and it does not work: each fresh need has to
drain from full before it can register anything, which costs 178 ticks for
comfort and 320 for enrichment, so a rotating policy stalls at **3 mistakes** in
864 ticks no matter how many lapses it is asked for. That was measured, and it
is why the presets neglect everything at once — mistakes cost the same 18 health
whether one need is at zero or four, so zeroing four earns them four times
faster and leaves far more of the childhood free for health to recover in.

The intended counts are a starting point, not a promise. The preset test below
is what makes them true, and the sloppy preset sits one mistake under the
measured ceiling of eight, so it is the one expected to need tuning.

### Driving the run

The page mounts `DeviceShell` on a `FakeClock` and steps it on the existing
600ms animation frame, exactly as `/dev/device` does. Two differences.

**The bot gets up to six presses per frame.** At 3600× a frame is 7.2 ticks, in
which a piglet loses about 3 fullness and 3 comfort, and feeding alone is a
four-press sequence. At one press per frame the bot spends nearly every frame
navigating and still falls behind. Six presses per frame is not cheating: 600ms
at 3600× is 36 simulated minutes, so six presses in that window is far slower
than a human at 1×.

**Speeds are 600× / 3600× / 10800×.** 3600× puts a full life at about eight
minutes, of which roughly seven are an adult pig that changes very little;
10800× brings it under three, at the cost of the pig visibly stepping rather
than moving, since each frame then advances nearly two simulated hours. 1× and
60× are dropped — a life at 60× is eight hours and nobody is watching that.

The run stops on death. The death screen comes up on its own through the
existing controller path, the bot goes quiet, and the summary stays on screen.

### The readout

In the panel below the glass, never on the LCD — [`death_screen.dart`](lib/game/screens/death_screen.dart)
is deliberate about never showing judgment, and spec §8 forbids a post-mortem
scoreboard on the device. The panel is not the device.

Live: stage, form, age, the four needs, health, mistakes, and whether the bot is
currently in a lapse. Plus an event log — hatched, became adult *with the
mistake count that decided it*, each sickness, died of what at what age — which
is what makes a run reviewable after the fact rather than something you had to
be watching.

One trap: the branch zeroes `stageCareMistakes` on the same tick it fixes the
form, so a panel reading that field will always show 0 at the moment it matters.
It has to read `careMistakes`, which survives the transition and is equal to it
at that point, because the egg stage does not decay and therefore contributes no
mistakes.

### Testing

Unit tests for the bot, driving a `GameController` on a `FakeClock` with no
widgets: it reaches slop from a parked cursor, guesses five times in the hunt,
medicates only when sick, backs out of an unexpected screen, and returns null on
the death screen rather than restarting.

Then the one that matters — a full-life test per preset, headless: build
controller and bot, run the whole childhood, and assert the pig reaches
adulthood as the intended form with its mistake count inside the intended band,
then keep going to confirm it dies of old age inside its form's lifespan band. A
full life is 5,760 ticks of pure arithmetic and something over a thousand
presses, so it runs in well under a second. That test is what keeps the presets honest after any
balance change, and it is the reason the rescale in Part 1 can be trusted
rather than assumed.

`flutter test` carries one standing unrelated failure on `prop.grave`; see
`HANDOFF.md`.

### What the harness actually demonstrated

Three lives came out of the full-life tests, one per preset: attentive care
raises a prize hog at 0 mistakes, dying of old age at day 20; adequate care
raises a farm hog at 4 mistakes, day 16; sloppy care raises a runt at 6
mistakes, lowest health 19, day 14. One knob moved to get there — sloppy's
`rescueBelow` went from 10 to 35 during tuning, because at 10 the pig died in
childhood rather than surviving to the branch as a runt.

That is narrower than it might read. The deciding count sloppy actually
produces is 6 — the floor of the runt band, one above `kFarmHogMaxMistakes` —
not the ceiling. `kRuntWorstMistakes` (8) is exercised by no test in this
repo; `test/dev/life_cycle_run_test.dart` says so directly, and asserts only
that the count falls somewhere inside the runt band. The measured ceiling of
8, cited in Part 1 as the practical limit on what a childhood can survive,
came from two throwaway policies run at design time and hand-tuned to convert
health into mistakes as efficiently as possible — not from the bot, and not
under test. What the harness demonstrates is that a pig can survive 6
mistakes and become a runt; it does not demonstrate that 8 is survivable, only
that a hand-optimized probe reached it once, outside the harness, before any
of this was built.

---

## Out of scope

**No M6 work.** No hatch beat, no growing-up beat, no tombstone polish, no new
sprites. The arc is already legible without them — an egg, then a piglet, then
an adult whose skull width tells you which one you earned, then the grave — and
mixing presentation work into this would make the harness's findings harder to
trust.

**No persistence, no seeking, no takeover.** M5 owns the real debug clock and
will likely replace the fake one under this page; that is a later edit, not a
constraint on this one.

**No new balance work beyond the three constants.** The measurement turned up
one broken thing and this fixes exactly that. Whether a mistake should cost less
health, or whether judgment should weigh something other than mistakes, are
design questions this harness now makes it possible to ask properly.
