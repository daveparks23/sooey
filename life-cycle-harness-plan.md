# Life cycle harness — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rescale the care-mistake bands onto the range a living pig can actually reach, then add a dev-only harness at `/dev/life` that plays a pig from egg to grave unattended on the real device.

**Architecture:** A `CareBot` decides one button press at a time from what the device currently shows, and a dev page feeds those presses into the existing `GameController` on a `FakeClock` running at up to 10800×. The bot presses A/B/C through the real screen stack — no new path into the game, and no change to `lib/game/` or `packages/hog_sim/` outside the three balance constants in Task 1.

**Tech Stack:** Dart 3 / Flutter (web), `package:hog_sim` (pure Dart, path dependency), `flutter_test` and `dart test`.

**Spec:** [`life-cycle-harness-design.md`](life-cycle-harness-design.md). Read it before Task 1; it carries the measurements this plan acts on. [`HANDOFF.md`](HANDOFF.md) is the project orientation and assumed throughout.

## Global Constraints

- **Determinism in `hog_sim`.** No `hashCode`, and no integer arithmetic without thinking about 2^53. After any change under `packages/hog_sim/`, run `dart test` **and** `dart test -p chrome`. Both must pass.
- **`Form` collides with Flutter's form widget.** Any file importing both `hog_sim` and `material.dart` needs `hide Form` on the material import.
- **The harness changes no game code.** Only Task 1 touches `packages/hog_sim/`; Tasks 2–7 add files under `lib/dev/` and `test/dev/` and edit only `lib/main.dart` and `HANDOFF.md`. If the bot appears to need a change in `lib/game/`, stop and report it — that is a finding about the game, not a licence to edit.
- **Judgment never reaches the LCD.** Care-mistake counts appear only in the dev panel outside the glass. Spec §8 and `death_screen.dart` are explicit that the device never shows them.
- **Four suites must pass at the end:** `cd packages/hog_sim && dart test`, `cd packages/hog_sim && dart test -p chrome`, `flutter test`, `cd functions && npm test`. There is one standing known failure — `every sprite in the cast is well formed` on `prop.grave` — documented in `HANDOFF.md`. Anything else red is a real regression.
- **Commit after every task.** Conventional-commit prefixes, matching the existing log (`feat(game):`, `fix(lcd):`, `test(device):`, `docs:`).

---

## File Structure

| File | Responsibility |
| --- | --- |
| `packages/hog_sim/lib/src/constants.dart` (modify) | The three mistake-band values, and nothing else in this plan. |
| `packages/hog_sim/test/stages_test.dart` (modify) | Pins the bands to the reachable range with literals, so a future rescale cannot pass unnoticed. |
| `packages/hog_sim/test/golden_scenarios.dart` (modify) | One literal mistake count becomes symbolic. |
| `packages/hog_sim/test/golden/vectors.json` (regenerate) | Deliberate regeneration; the simulation's observable behaviour changes. |
| `lib/dev/care_bot.dart` (create) | The bot: goal choice, navigation, and the neglect regime. No Flutter imports. |
| `test/dev/care_bot_test.dart` (create) | Unit tests for navigation and goal choice. |
| `test/dev/life_cycle_run_test.dart` (create) | Headless full-life test, one per preset. The thing that keeps the presets honest. |
| `lib/dev/life_cycle_page.dart` (create) | Route `/dev/life`: preset picker, speed chips, the press loop, the readout and the event log. |
| `test/dev/life_cycle_page_test.dart` (create) | The page mounts, runs, and ages a pig. |
| `lib/main.dart` (modify) | The route and a dev-menu button. |
| `HANDOFF.md` (modify) | Route table, the band rescale as a recorded deviation, test counts. |

`care_bot.dart` deliberately imports no Flutter: it is a decision function over `GameController` and `DeviceScreen`, which is what lets the full-life test run without a widget tree.

---

### Task 1: Rescale the mistake bands

**Files:**
- Modify: `packages/hog_sim/lib/src/constants.dart:167-171`
- Modify: `packages/hog_sim/test/stages_test.dart:95-105`
- Modify: `packages/hog_sim/test/golden_scenarios.dart:313`
- Regenerate: `packages/hog_sim/test/golden/vectors.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `kPrizeHogMaxMistakes = 2`, `kFarmHogMaxMistakes = 5`, `kRuntWorstMistakes = 8`. Every later task's preset targets are chosen against these values.

- [ ] **Step 1: Write the failing test**

Add to `packages/hog_sim/test/stages_test.dart`, inside the existing `group('formForMistakes', ...)`:

```dart
    test('bands sit inside the range a living pig can reach', () {
      // A childhood is kPigletMinutes / kTickMinutes = 864 ticks. One mistake
      // costs kTicksAtZeroForMistake * kHealthLossPerZeroedNeed = 18 health,
      // and health only returns at kHealthRecovery per tick and only while all
      // four needs are above kHealthRecoveryThreshold. So the whole budget is
      // 100 + 0.2 * 864 = 273.8 health, or 15.2 mistakes even if recovery ran
      // every tick of childhood — which it cannot, because driving a need to
      // zero means spending ticks below the threshold. Measured ceiling under
      // optimal play: 8. Bands above that are unreachable by play.
      expect(kRuntWorstMistakes, lessThanOrEqualTo(8));
      expect(formForMistakes(2), Form.prizeHog);
      expect(formForMistakes(3), Form.farmHog);
      expect(formForMistakes(5), Form.farmHog);
      expect(formForMistakes(6), Form.runt);
    });
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd packages/hog_sim && dart test test/stages_test.dart -n 'bands sit inside'
```

Expected: FAIL — `kRuntWorstMistakes` is 38, and `formForMistakes(3)` is still `prizeHog`.

- [ ] **Step 3: Change the three constants**

In `packages/hog_sim/lib/src/constants.dart`, replace the mistake-band block with:

```dart
/// Mistake bands that decide the adult form, and the lifespan each band buys.
/// Within a band, fewer mistakes means a longer life; the exact day is fixed at
/// the piglet->adult transition and stored as `expiresAt`.
///
/// Scaled down to the range a pig can reach and survive. A mistake costs 18
/// health and health returns at 0.2 a tick, so an 864-tick childhood affords
/// about 8 of them; the previous bands of 5 / 14 / 38 put the whole runt band
/// past the point where the pig is already dead, and every one of the four
/// deliberate-neglect policies measured during design topped out at 8.
/// See life-cycle-harness-design.md.
const int kPrizeHogMaxMistakes = 2;
const int kFarmHogMaxMistakes = 5;

/// Mistake count at which the runt's lifespan bottoms out.
const int kRuntWorstMistakes = 8;
```

- [ ] **Step 4: Run the stage tests**

```bash
cd packages/hog_sim && dart test test/stages_test.dart
```

Expected: PASS. The other cases in this file use the constants symbolically, so they move with the change.

- [ ] **Step 5: Make the one literal golden case symbolic**

`packages/hog_sim/test/golden_scenarios.dart:313` passes a literal `4`, which was a prize hog under the old bands and is a farm hog under the new ones. The case is about lifetime mistakes surviving the branch, so pin it to the band edge instead of a number that changes meaning:

```dart
    AdvanceCase(
      'transition/keeps-lifetime-mistakes',
      nearlyGrown(
        stageCareMistakes: kPrizeHogMaxMistakes,
        careMistakes: 21,
      ),
      refNoon + hour,
    ),
```

- [ ] **Step 6: Watch the golden vectors fail, which is the point**

```bash
cd packages/hog_sim && dart test test/golden_test.dart
```

Expected: FAIL on the `transition/*` cases. `vectors.json` was generated under the old bands; the form and `expiresAtMillis` those cases produce have changed on purpose.

- [ ] **Step 7: Regenerate the vectors**

```bash
cd packages/hog_sim && dart run tool/emit_golden_vectors.dart
git diff --stat test/golden/vectors.json
```

Expected: the tool reports 92 vectors, and the diff touches the `transition/*` cases and the `expiresAtMillis` values downstream of them. If it touches death or decay cases, stop — something other than the bands moved.

- [ ] **Step 8: Run all four suites**

```bash
cd packages/hog_sim && dart test
cd packages/hog_sim && dart test -p chrome
cd ../.. && flutter test
cd functions && npm test
```

Expected: all pass, except the standing `prop.grave` failure in `flutter test`. The `-p chrome` run is not optional — it is what proves the dart2js build agrees with the VM about the new bands.

- [ ] **Step 9: Commit**

```bash
git add packages/hog_sim/lib/src/constants.dart packages/hog_sim/test/stages_test.dart packages/hog_sim/test/golden_scenarios.dart packages/hog_sim/test/golden/vectors.json
git commit -m "balance(sim): scale the mistake bands onto the range a pig can survive"
```

---

### Task 2: The bot's navigation

**Files:**
- Create: `lib/dev/care_bot.dart`
- Create: `test/dev/care_bot_test.dart`

**Interfaces:**
- Consumes: `Button`, `DeviceIcon`, `DeviceScreen` from `lib/game/screens/device_screen.dart`; the concrete screens from their own files.
- Produces: `enum BotGoal { slop, treat, wallow, play, clean, meds, lightOff, lightOn }`, `DeviceIcon iconFor(BotGoal)`, and `Button? pressToward(BotGoal goal, DeviceScreen screen)`. Tasks 3 and 4 build on all three.

- [ ] **Step 1: Write the failing test**

Create `test/dev/care_bot_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/dev/care_bot.dart';
import 'package:sooey/game/screens/crest_screen.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/game/screens/feed_menu.dart';
import 'package:sooey/game/screens/home_screen.dart';
import 'package:sooey/game/screens/stats_screen.dart';
import 'package:sooey/game/screens/truffle_hunt.dart';

void main() {
  group('pressToward', () {
    test('cycles the home cursor until the icon it wants is lit', () {
      final home = HomeScreen();
      expect(home.selected, isNull, reason: 'a new home screen is parked');
      expect(pressToward(BotGoal.slop, home), Button.a);

      home.selected = DeviceIcon.wallow;
      expect(pressToward(BotGoal.slop, home), Button.a);

      home.selected = DeviceIcon.feed;
      expect(pressToward(BotGoal.slop, home), Button.b);
    });

    test('treats and slop share the feed icon but not the caret', () {
      final menu = FeedMenu();
      expect(menu.treat, isFalse, reason: 'the menu opens on slop');
      expect(pressToward(BotGoal.slop, menu), Button.b);
      expect(pressToward(BotGoal.treat, menu), Button.a);

      menu.treat = true;
      expect(pressToward(BotGoal.treat, menu), Button.b);
    });

    test('guesses in the hunt, and waits out the reveal', () {
      final hunt = TruffleHunt();
      expect(hunt.revealing, isFalse);
      expect(pressToward(BotGoal.play, hunt), Button.a);

      hunt.pigWentLeft = true; // what a guess leaves behind
      expect(hunt.revealing, isTrue);
      expect(pressToward(BotGoal.play, hunt), isNull);
    });

    test('takes any crest rather than shopping for one', () {
      expect(pressToward(BotGoal.slop, CrestScreen()), Button.b);
    });

    test('never presses on the death screen', () {
      // B there is Restart, which would erase the life just watched.
      for (final goal in BotGoal.values) {
        expect(pressToward(goal, DeathScreen()), isNull);
      }
    });

    test('backs out of a screen it did not ask for', () {
      expect(pressToward(BotGoal.slop, StatsScreen()), Button.c);
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/dev/care_bot_test.dart
```

Expected: FAIL — `lib/dev/care_bot.dart` does not exist, so the import cannot resolve.

- [ ] **Step 3: Write the navigation**

Create `lib/dev/care_bot.dart`:

```dart
import '../game/screens/crest_screen.dart';
import '../game/screens/death_screen.dart';
import '../game/screens/device_screen.dart';
import '../game/screens/feed_menu.dart';
import '../game/screens/home_screen.dart';
import '../game/screens/truffle_hunt.dart';

/// One thing the bot is trying to get done.
///
/// Finer than [DeviceIcon] because the feed icon leads to two different
/// choices, and the light is a toggle rather than an action.
enum BotGoal { slop, treat, wallow, play, clean, meds, lightOff, lightOn }

/// The strip icon a goal is reached through.
DeviceIcon iconFor(BotGoal goal) => switch (goal) {
  BotGoal.slop || BotGoal.treat => DeviceIcon.feed,
  BotGoal.wallow => DeviceIcon.wallow,
  BotGoal.play => DeviceIcon.play,
  BotGoal.clean => DeviceIcon.clean,
  BotGoal.meds => DeviceIcon.meds,
  BotGoal.lightOff || BotGoal.lightOn => DeviceIcon.light,
};

/// One press towards [goal], or null when there is nothing to press.
///
/// Pure: it reads the screen and returns a button, exactly as a player looking
/// at the glass would. Nothing here mutates anything.
Button? pressToward(BotGoal goal, DeviceScreen screen) {
  // B on the death screen is Restart. A bot that pressed it would erase the
  // life it was sent to watch, so this case comes first and is unconditional.
  if (screen is DeathScreen) return null;

  // Any crest will do. Which emblem marks the pig is not what we came to see.
  if (screen is CrestScreen) return Button.b;

  if (screen is HomeScreen) {
    return screen.selected == iconFor(goal) ? Button.b : Button.a;
  }
  if (screen is FeedMenu) {
    return screen.treat == (goal == BotGoal.treat) ? Button.b : Button.a;
  }
  if (screen is TruffleHunt) {
    // A guess while the pig is still at a mound resolves a round nobody has
    // seen the answer to, and the screen ignores it anyway.
    return screen.revealing ? null : Button.a;
  }

  // Anything else — stats, or a screen added after this was written — is
  // somewhere the bot did not mean to be. C is the way out of all of them.
  return Button.c;
}
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/dev/care_bot_test.dart
```

Expected: PASS, six tests.

- [ ] **Step 5: Commit**

```bash
git add lib/dev/care_bot.dart test/dev/care_bot_test.dart
git commit -m "feat(dev): teach the care bot to find its way around the device"
```

---

### Task 3: What the bot decides to do

**Files:**
- Modify: `lib/dev/care_bot.dart`
- Modify: `test/dev/care_bot_test.dart`

**Interfaces:**
- Consumes: `BotGoal` from Task 2.
- Produces: `BotGoal? chooseGoal(PetState pet, {required Set<String> neglected, required int nowMillis, bool playsHunt = true})`. Task 4 calls it with the neglect set the preset dictates.

- [ ] **Step 1: Write the failing test**

Append to `test/dev/care_bot_test.dart`, and add these imports at the top of the file:

```dart
import 'package:hog_sim/hog_sim.dart';
import '../game/screens/screen_test_support.dart';
```

```dart
  group('chooseGoal', () {
    const noon = kRefNoon;

    test('leaves an egg alone', () {
      final egg = testPet(stage: Stage.egg, fullness: 0, enrichment: 0);
      expect(
        chooseGoal(egg, neglected: const {}, nowMillis: noon),
        isNull,
        reason: 'an egg refuses everything but the light',
      );
    });

    test('medicates a sick pig before anything else', () {
      final pet = testPet(isSick: true, fullness: 0, comfort: 0);
      expect(chooseGoal(pet, neglected: const {}, nowMillis: noon),
          BotGoal.meds);
    });

    test('never medicates a healthy one', () {
      // Meds on a well pig costs kMedsHealthPenalty health for nothing.
      final pet = testPet(isSick: false);
      final goal = chooseGoal(pet, neglected: const {}, nowMillis: noon);
      expect(goal, isNot(BotGoal.meds));
    });

    test('cleans up after the pig', () {
      final pet = testPet(poops: 2);
      expect(chooseGoal(pet, neglected: const {}, nowMillis: noon),
          BotGoal.clean);
    });

    test('services the lowest need first', () {
      final pet = testPet(fullness: 55, enrichment: 20, comfort: 50);
      expect(chooseGoal(pet, neglected: const {}, nowMillis: noon),
          isNot(BotGoal.slop));
      final hungriest = testPet(fullness: 10, enrichment: 50, comfort: 55);
      expect(chooseGoal(hungriest, neglected: const {}, nowMillis: noon),
          BotGoal.slop);
    });

    test('leaves a neglected need alone and moves on to the next', () {
      final pet = testPet(fullness: 5, comfort: 40);
      expect(
        chooseGoal(pet, neglected: const {'fullness'}, nowMillis: noon),
        BotGoal.wallow,
      );
    });

    test('plays the hunt when there is slack, and treats when there is not', () {
      final easy = testPet(enrichment: 20, fullness: 90, comfort: 90,
          cleanliness: 90);
      expect(chooseGoal(easy, neglected: const {}, nowMillis: noon),
          BotGoal.play);

      // The hunt locks the bot on one screen for five frames. With something
      // else close to the floor that is a luxury, so a treat does instead.
      final tight = testPet(enrichment: 20, fullness: 45, comfort: 90,
          cleanliness: 90);
      expect(chooseGoal(tight, neglected: const {}, nowMillis: noon),
          BotGoal.slop, reason: 'fullness is lower, so it wins first');

      final cooling = testPet(enrichment: 20, fullness: 90, comfort: 90,
          cleanliness: 90).copyWith(lastPlayedAtMillis: noon - 1000);
      expect(chooseGoal(cooling, neglected: const {}, nowMillis: noon),
          BotGoal.treat, reason: 'the hunt is still on cooldown');
    });

    test("keeps the pen light on the pig's own clock", () {
      final settled = testPet(fullness: 90, enrichment: 90, comfort: 90,
          cleanliness: 90, lightsOn: true);
      expect(chooseGoal(settled, neglected: const {}, nowMillis: noon), isNull);

      // The hour comes from nowMillis and the pet's own UTC offset, which
      // testPet leaves at zero, so this is 22:00 local.
      const tenPm = 22 * 60 * 60 * 1000;
      expect(chooseGoal(settled, neglected: const {}, nowMillis: tenPm),
          BotGoal.lightOff);
      expect(
        chooseGoal(settled.copyWith(lightsOn: false),
            neglected: const {}, nowMillis: tenPm),
        isNull,
      );
    });
  });
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/dev/care_bot_test.dart -n chooseGoal
```

Expected: FAIL — `chooseGoal` is undefined.

- [ ] **Step 3: Write the policy**

Add to `lib/dev/care_bot.dart`, with `import 'package:hog_sim/hog_sim.dart';` at the top:

```dart
/// Below this a need gets attention. Above `kHealthRecoveryThreshold` (50) by
/// a margin, because a need that is only just clear of the threshold will drop
/// under it again before the bot next comes round.
const double kServiceBelow = 60;

/// What the pig most needs right now, or null when nothing wants doing.
///
/// [neglected] names the needs this run is deliberately letting bottom out;
/// they are skipped entirely. Pure — it reads a pet and returns an intention.
BotGoal? chooseGoal(
  PetState pet, {
  required Set<String> neglected,
  required int nowMillis,
  bool playsHunt = true,
}) {
  // An egg refuses everything but the light, and the light on an egg is not
  // worth the seven presses it takes to reach.
  if (pet.isDead || pet.stage == Stage.egg) return null;

  if (pet.isSick) return BotGoal.meds;

  if (!neglected.contains('cleanliness') &&
      (pet.poops.isNotEmpty || pet.cleanliness < kServiceBelow)) {
    return BotGoal.clean;
  }

  // The lowest need wins, so nothing bottoms out while something less urgent
  // is topped up.
  String? lowest;
  double lowestValue = kServiceBelow;
  void consider(String name, double value) {
    if (neglected.contains(name) || value >= lowestValue) return;
    lowest = name;
    lowestValue = value;
  }

  consider('fullness', pet.fullness);
  consider('enrichment', pet.enrichment);
  consider('comfort', pet.comfort);

  switch (lowest) {
    case 'fullness':
      return BotGoal.slop;
    case 'comfort':
      return BotGoal.wallow;
    case 'enrichment':
      // The hunt is five rounds, one guess per frame, and the bot is stuck on
      // that screen for all five — so it is only affordable when nothing else
      // is near the floor. A treat buys enrichment in a single visit instead.
      final last = pet.lastPlayedAtMillis;
      final cooling = last != null && nowMillis - last < kPlayCooldownMillis;
      final slack = pet.fullness > kServiceBelow &&
          pet.comfort > kServiceBelow &&
          pet.cleanliness > kServiceBelow;
      return playsHunt && slack && !cooling ? BotGoal.play : BotGoal.treat;
  }

  // Nothing needs doing, so keep the pen light honest. Costs nothing and makes
  // the nights visible as they go past.
  final localHour =
      ((nowMillis + pet.utcOffsetMinutes * 60000) ~/ 3600000) % 24;
  final darkOutside =
      localHour >= kSleepStartHour || localHour < kSleepEndHour;
  if (darkOutside && pet.lightsOn) return BotGoal.lightOff;
  if (!darkOutside && !pet.lightsOn) return BotGoal.lightOn;
  return null;
}
```

- [ ] **Step 4: Run the tests**

```bash
flutter test test/dev/care_bot_test.dart
```

Expected: PASS, fourteen tests.

- [ ] **Step 5: Commit**

```bash
git add lib/dev/care_bot.dart test/dev/care_bot_test.dart
git commit -m "feat(dev): give the care bot a policy for what the pig needs next"
```

---

### Task 4: Presets and the neglect regime

**Files:**
- Modify: `lib/dev/care_bot.dart`
- Modify: `test/dev/care_bot_test.dart`

**Interfaces:**
- Consumes: `chooseGoal` and `pressToward` from Tasks 2–3; `GameController` from `lib/game/game_controller.dart`.
- Produces: `enum CarePreset { attentive, adequate, sloppy }`, `class CarePlan { int targetMistakes; double rescueBelow; double resumeAbove; }`, `const Map<CarePreset, CarePlan> kCarePlans`, and `class CareBot { CareBot(CarePreset preset, {bool playsHunt = true}); Button? nextPress(GameController); bool get neglecting; }`. Tasks 5 and 6 drive `nextPress` and read `neglecting`.

- [ ] **Step 1: Write the failing test**

Append to `test/dev/care_bot_test.dart`, adding these imports:

```dart
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
```

```dart
  group('CareBot', () {
    GameController controllerAt(int millis) =>
        GameController(clock: FakeClock(millis), utcOffsetMinutes: 0);

    test('takes the opening crest so the pig can start living', () {
      final c = controllerAt(kRefNoon);
      final bot = CareBot(CarePreset.attentive);
      expect(c.screen, isA<CrestScreen>());
      expect(bot.nextPress(c), Button.b);
    });

    test('goes quiet on the death screen', () {
      // The pet is born at whatever the clock says, so the clock has to move
      // after the controller exists — thirty days with nobody home.
      final clock = FakeClock(kRefNoon);
      final c = GameController(clock: clock, utcOffsetMinutes: 0);
      c.press(Button.b); // through the crest
      clock.advance(30 * 86400000);
      c.tick();

      expect(c.pet.isDead, isTrue);
      expect(c.screen, isA<DeathScreen>());
      expect(CareBot(CarePreset.attentive).nextPress(c), isNull);
    });

    test('attentive never lets a need bottom out', () {
      final bot = CareBot(CarePreset.attentive);
      expect(bot.neglectedFor(testPet(stage: Stage.piglet)), isEmpty);
    });

    test('sloppy neglects until it has the mistakes it came for', () {
      final bot = CareBot(CarePreset.sloppy);
      final piglet = testPet(stage: Stage.piglet, health: 100);
      expect(bot.neglectedFor(piglet), kLapseNeeds);

      // Rescued once health reaches the floor.
      expect(bot.neglectedFor(piglet.copyWith(health: 5)), isEmpty);
      // Still cared for on the way back up.
      expect(bot.neglectedFor(piglet.copyWith(health: 40)), isEmpty);
      // And back to neglect once recovered.
      expect(bot.neglectedFor(piglet.copyWith(health: 80)), kLapseNeeds);
    });

    test('stops neglecting once the target is met, and after childhood', () {
      final bot = CareBot(CarePreset.sloppy);
      final done = testPet(stage: Stage.piglet, health: 100)
          .copyWith(careMistakes: kCarePlans[CarePreset.sloppy]!.targetMistakes);
      expect(bot.neglectedFor(done), isEmpty);
      expect(bot.neglectedFor(testPet(stage: Stage.adult, health: 100)),
          isEmpty);
    });

    test('every preset target lands inside the band it is aiming at', () {
      expect(formForMistakes(kCarePlans[CarePreset.attentive]!.targetMistakes),
          Form.prizeHog);
      expect(formForMistakes(kCarePlans[CarePreset.adequate]!.targetMistakes),
          Form.farmHog);
      expect(formForMistakes(kCarePlans[CarePreset.sloppy]!.targetMistakes),
          Form.runt);
    });
  });
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/dev/care_bot_test.dart -n CareBot
```

Expected: FAIL — `CareBot`, `CarePreset`, `kCarePlans` and `kLapseNeeds` are undefined.

- [ ] **Step 3: Write the bot**

Add to `lib/dev/care_bot.dart`, with `import '../game/game_controller.dart';`:

```dart
/// How well a run intends to treat its pig.
enum CarePreset { attentive, adequate, sloppy }

/// One preset, as numbers.
class CarePlan {
  const CarePlan({
    required this.targetMistakes,
    required this.rescueBelow,
    required this.resumeAbove,
  });

  /// Mistakes to make during childhood. The adult form is decided by this
  /// count at the piglet->adult branch and by nothing else.
  final int targetMistakes;

  /// Health at which a lapse is called off and the pig is rescued.
  final double rescueBelow;

  /// Health at which neglect resumes, if the target is not yet met.
  final double resumeAbove;
}

const Map<CarePreset, CarePlan> kCarePlans = {
  CarePreset.attentive:
      CarePlan(targetMistakes: 0, rescueBelow: 100, resumeAbove: 100),
  CarePreset.adequate:
      CarePlan(targetMistakes: 4, rescueBelow: 45, resumeAbove: 60),
  CarePreset.sloppy:
      CarePlan(targetMistakes: 7, rescueBelow: 10, resumeAbove: 60),
};

/// The two needs a lapse is allowed to bottom out.
///
/// Comfort and cleanliness are held above the recovery threshold at all times.
/// They are the two that can only be restored to 100 — wallow and clean take
/// no smaller step — so zeroing them buys a long redrain, and with four needs
/// at zero the mistakes arrive four at a time and a target overshoots out of
/// its band. Two needs means an overshoot of at most one.
const Set<String> kLapseNeeds = {'fullness', 'enrichment'};

/// Plays a pig unattended, one button press at a time.
///
/// Deliberately knows nothing about widgets: it reads a [GameController] and
/// returns a button, which is what lets a whole life run in a test with no
/// widget tree in play.
class CareBot {
  CareBot(this.preset, {this.playsHunt = true});

  final CarePreset preset;

  /// False makes the bot use treats instead of the truffle hunt. The hunt
  /// draws from `dart:math`'s Random, so a run that plays it is not
  /// reproducible; the full-life tests turn it off for that reason.
  final bool playsHunt;

  bool _lapsing = true;
  bool _neglecting = false;

  /// Whether the bot is currently letting needs bottom out. For the readout.
  bool get neglecting => _neglecting;

  /// Which needs the run is deliberately ignoring at this moment.
  Set<String> neglectedFor(PetState pet) {
    final plan = kCarePlans[preset]!;
    // Only childhood decides the form, and only mistakes short of the target
    // are wanted. Everything else is attentive care.
    if (pet.stage != Stage.piglet || pet.careMistakes >= plan.targetMistakes) {
      _neglecting = false;
      return const {};
    }
    if (_lapsing && pet.health <= plan.rescueBelow) _lapsing = false;
    if (!_lapsing && pet.health >= plan.resumeAbove) _lapsing = true;
    _neglecting = _lapsing;
    return _lapsing ? kLapseNeeds : const {};
  }

  /// One press, or null when there is nothing worth pressing this frame.
  Button? nextPress(GameController controller) {
    final screen = controller.screen;
    if (screen is DeathScreen) return null;
    if (screen is CrestScreen) return Button.b;

    final goal = chooseGoal(
      controller.pet,
      neglected: neglectedFor(controller.pet),
      nowMillis: controller.context.nowMillis,
      playsHunt: playsHunt,
    );
    // Nothing to do: rest on home, and back out of anywhere else so the next
    // frame starts from a known screen.
    if (goal == null) return screen is HomeScreen ? null : Button.c;
    return pressToward(goal, screen);
  }
}
```

- [ ] **Step 4: Run the tests**

```bash
flutter test test/dev/care_bot_test.dart
```

Expected: PASS, twenty tests.

- [ ] **Step 5: Commit**

```bash
git add lib/dev/care_bot.dart test/dev/care_bot_test.dart
git commit -m "feat(dev): give the care bot three care qualities and a neglect regime"
```

---

### Task 5: The full-life test, and tuning the presets against it

**Files:**
- Create: `test/dev/life_cycle_run_test.dart`

**Interfaces:**
- Consumes: `CareBot`, `CarePreset`, `kCarePlans` from Task 4.
- Produces: `kBotPressBudget` (exported from `lib/dev/care_bot.dart`), which Task 6's page also uses.

This is the task the whole plan exists to make possible. It is also the one most likely to need a second pass: the preset targets are estimates from four measured policies, not guarantees.

- [ ] **Step 1: Add the press budget to `lib/dev/care_bot.dart`**

```dart
/// How many presses the bot may make in one animation frame.
///
/// A frame is 600ms of wall clock. At 3600x that is 36 simulated minutes, in
/// which a piglet loses about 3 fullness and 3 comfort — and feeding is a
/// four-press sequence: cursor to feed, B, cursor to slop, B. At one press a
/// frame the bot spends every frame navigating and still falls behind. Six is
/// far fewer than a human could manage in 36 simulated minutes, so nothing it
/// achieves here is out of a player's reach.
const int kBotPressBudget = 6;
```

- [ ] **Step 2: Write the failing test**

Create `test/dev/life_cycle_run_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/dev/care_bot.dart';
import 'package:sooey/game/clock.dart';
import 'package:sooey/game/game_controller.dart';
import 'package:sooey/sprites/sprite_registry.dart';

import '../game/screens/screen_test_support.dart';

/// What one unattended life came to.
typedef LifeResult = ({
  Form form,
  int mistakesAtBranch,
  bool reachedAdult,
  DeathCause? deathCause,
  int ageAtDeathDays,
  double lowestHealth,
});

/// Runs a whole life headlessly, exactly as the page will drive it.
///
/// No widgets: a controller, a fake clock and the bot. 3600x means one frame
/// is 36 simulated minutes, so a twenty-day life is about 800 frames.
LifeResult runLife(CarePreset preset, {int speed = 3600}) {
  final clock = FakeClock(kRefNoon);
  final controller = GameController(clock: clock, utcOffsetMinutes: 0);
  // The hunt draws from dart:math's Random, which would make this test
  // irreproducible. Treats buy the same enrichment deterministically.
  final bot = CareBot(preset, playsHunt: false);

  var mistakesAtBranch = -1;
  var lowestHealth = 100.0;
  var previousStage = controller.pet.stage;

  for (var frame = 0; frame < 5000; frame++) {
    clock.advance(kAnimFrameMillis * speed);
    controller.tick();

    final pet = controller.pet;
    if (pet.stage == Stage.adult && previousStage != Stage.adult) {
      // The branch zeroes stageCareMistakes on the same tick it fixes the
      // form, so the count that decided it has to be read from careMistakes.
      mistakesAtBranch = pet.careMistakes;
    }
    previousStage = pet.stage;
    if (pet.health < lowestHealth) lowestHealth = pet.health;

    if (pet.isDead) {
      return (
        form: pet.form,
        mistakesAtBranch: mistakesAtBranch,
        reachedAdult: mistakesAtBranch >= 0,
        deathCause: pet.deathCause,
        ageAtDeathDays: (pet.diedAtMillis! - pet.bornAtMillis) ~/ 86400000,
        lowestHealth: lowestHealth,
      );
    }

    for (var i = 0; i < kBotPressBudget; i++) {
      final button = bot.nextPress(controller);
      if (button == null) break;
      controller.press(button);
    }
  }
  fail('the pig outlived 5000 frames without dying');
}

void main() {
  test('attentive care raises a prize hog that dies of old age', () {
    final life = runLife(CarePreset.attentive);
    expect(life.reachedAdult, isTrue);
    expect(life.mistakesAtBranch, 0);
    expect(life.form, Form.prizeHog);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(18, 20));
  });

  test('adequate care raises a farm hog', () {
    final life = runLife(CarePreset.adequate);
    expect(life.reachedAdult, isTrue,
        reason: 'a preset that kills its pig is not a care quality');
    expect(life.mistakesAtBranch,
        inInclusiveRange(kPrizeHogMaxMistakes + 1, kFarmHogMaxMistakes));
    expect(life.form, Form.farmHog);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(15, 17));
  });

  test('sloppy care raises a runt that nearly did not make it', () {
    final life = runLife(CarePreset.sloppy);
    expect(life.reachedAdult, isTrue);
    expect(life.mistakesAtBranch, greaterThan(kFarmHogMaxMistakes));
    expect(life.mistakesAtBranch, lessThanOrEqualTo(kRuntWorstMistakes));
    expect(life.form, Form.runt);
    expect(life.deathCause, DeathCause.oldAge);
    expect(life.ageAtDeathDays, inInclusiveRange(12, 14));
    expect(life.lowestHealth, lessThan(40),
        reason: 'a runt is a pig that nearly died in childhood');
  });
}
```

- [ ] **Step 3: Run it**

```bash
flutter test test/dev/life_cycle_run_test.dart
```

Expected: `attentive` passes. `adequate` and `sloppy` may fail — that is anticipated, not a surprise.

- [ ] **Step 4: Tune, if it failed**

Print what actually happened before changing anything:

```dart
    // Temporary, while tuning. Remove before committing.
    // ignore: avoid_print
    print('$preset -> ${life.form.name} at ${life.mistakesAtBranch} '
        'mistakes, lowest health ${life.lowestHealth}');
```

Then turn exactly one knob in `kCarePlans` at a time, and re-run:

| Symptom | Knob | Direction |
| --- | --- | --- |
| Too few mistakes at the branch | `rescueBelow` | Lower it — the pig is being rescued while it still had health to spend. |
| Overshot the band | `targetMistakes` | Lower it by one. Mistakes arrive in twos, so a target lands on itself or one above. |
| Died in childhood | `rescueBelow` | Raise it, in steps of 5. |
| Never resumes neglect after a rescue | `resumeAbove` | Lower it — recovery is 0.2 health a tick, so a high ceiling can eat the rest of childhood. |

Do **not** touch `packages/hog_sim/` to make this pass. The bands were set from measurement in Task 1; if no combination of these three knobs reaches the runt band alive, that is a real finding about the balance — stop, write down the best result achieved, and report it rather than moving the bands to fit.

Remove the print before committing.

- [ ] **Step 5: Run the whole Flutter suite**

```bash
flutter test
```

Expected: everything passes except the standing `prop.grave` failure. Note the new total for Task 7.

- [ ] **Step 6: Commit**

```bash
git add lib/dev/care_bot.dart test/dev/life_cycle_run_test.dart
git commit -m "test(dev): raise a prize hog, a farm hog and a runt from egg to grave"
```

---

### Task 6: The page

**Files:**
- Create: `lib/dev/life_cycle_page.dart`
- Create: `test/dev/life_cycle_page_test.dart`

**Interfaces:**
- Consumes: `CareBot`, `CarePreset`, `kCarePlans`, `kBotPressBudget` from Tasks 4–5; `DeviceShell`, `FakeClock`, `GameController`, `kAnimFrameMillis`.
- Produces: `class LifeCyclePage extends StatefulWidget`. Task 7 mounts it at `/dev/life`.

- [ ] **Step 1: Write the failing test**

Create `test/dev/life_cycle_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/dev/life_cycle_page.dart';

void main() {
  testWidgets('runs a pig out of its shell and into childhood', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LifeCyclePage()));

    expect(find.text('attentive'), findsOneWidget);
    expect(find.text('adequate'), findsOneWidget);
    expect(find.text('sloppy'), findsOneWidget);
    expect(find.textContaining('egg'), findsOneWidget);

    await tester.tap(find.text('Start'));
    // A frame is 36 simulated minutes at 3600x, and an egg hatches at 15.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.textContaining('piglet'), findsOneWidget);
    expect(find.textContaining('hatched'), findsOneWidget);

    // Stop the timer, or the test ends with one pending and fails.
    await tester.tap(find.text('Pause'));
    await tester.pump();
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/dev/life_cycle_page_test.dart
```

Expected: FAIL — `lib/dev/life_cycle_page.dart` does not exist.

- [ ] **Step 3: Write the page**

Create `lib/dev/life_cycle_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart' hide Form;
import 'package:hog_sim/hog_sim.dart';

import '../device/device_shell.dart';
import '../game/clock.dart';
import '../game/game_controller.dart';
import '../sprites/sprite_registry.dart';
import 'care_bot.dart';

/// Dev-only: a whole life, played by a bot, on a clock you can wind.
///
/// The device widget is the same one `/` mounts and has no idea it is being
/// driven. `/dev/device` is still there for hand-driving; this page is for
/// watching an arc nobody has the patience to play at 1x.
class LifeCyclePage extends StatefulWidget {
  const LifeCyclePage({super.key});

  @override
  State<LifeCyclePage> createState() => _LifeCyclePageState();
}

class _LifeCyclePageState extends State<LifeCyclePage> {
  /// 1x and 60x are missing on purpose: a life at 60x is eight hours.
  static const List<int> _speeds = [600, 3600, 10800];

  late FakeClock _clock;
  late GameController _controller;
  late CareBot _bot;

  Timer? _timer;
  int _speed = 3600;
  CarePreset _preset = CarePreset.attentive;
  final List<String> _log = [];

  Stage _lastStage = Stage.egg;
  bool _wasSick = false;
  bool _loggedDeath = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _running => _timer != null;

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _clock = FakeClock(DateTime.now().millisecondsSinceEpoch);
    _controller = GameController(clock: _clock, utcOffsetMinutes: 0);
    _bot = CareBot(_preset);
    _log.clear();
    _lastStage = Stage.egg;
    _wasSick = false;
    _loggedDeath = false;
  }

  void _toggleRun() {
    setState(() {
      if (_running) {
        _timer!.cancel();
        _timer = null;
      } else {
        _timer = Timer.periodic(
          const Duration(milliseconds: kAnimFrameMillis),
          (_) => _frame(),
        );
      }
    });
  }

  void _frame() {
    _clock.advance(kAnimFrameMillis * _speed);
    _controller.tick();
    _record();

    if (!_controller.pet.isDead) {
      for (var i = 0; i < kBotPressBudget; i++) {
        final button = _bot.nextPress(_controller);
        if (button == null) break;
        _controller.press(button);
      }
    }
    setState(() {});
  }

  /// Turns the things worth remembering into log lines as they happen.
  void _record() {
    final pet = _controller.pet;
    if (pet.stage != _lastStage) {
      if (pet.stage == Stage.piglet) {
        _note('hatched');
      } else if (pet.stage == Stage.adult) {
        // stageCareMistakes is zeroed by the same tick that fixes the form, so
        // the count that decided it has to come from careMistakes — which is
        // equal to it here, the egg stage having contributed none.
        _note('grew up into ${pet.form.name} on ${pet.careMistakes} mistakes');
      }
      _lastStage = pet.stage;
    }
    if (pet.isSick && !_wasSick) _note('fell ill');
    _wasSick = pet.isSick;

    if (pet.isDead && !_loggedDeath) {
      _loggedDeath = true;
      final days = (pet.diedAtMillis! - pet.bornAtMillis) / 86400000;
      _note('died of ${pet.deathCause?.name} at '
          '${days.toStringAsFixed(1)} days');
      _timer?.cancel();
      _timer = null;
    }
  }

  void _note(String what) => _log.add('${_ageLabel()}  $what');

  String _ageLabel() {
    final minutes = (_clock.nowMillis - _controller.pet.bornAtMillis) ~/ 60000;
    return '${(minutes ~/ 1440).toString().padLeft(2)}d'
        '${((minutes % 1440) ~/ 60).toString().padLeft(2, '0')}h';
  }

  @override
  Widget build(BuildContext context) {
    final pet = _controller.pet;

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(title: const Text('Life cycle (bot-driven)')),
      body: Row(
        children: [
          Expanded(child: DeviceShell(controller: _controller)),
          SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in CarePreset.values)
                        ChoiceChip(
                          label: Text(preset.name),
                          selected: _preset == preset,
                          // Changing care quality mid-life would produce a pig
                          // neither preset would own, so it starts over.
                          onSelected: (_) => setState(() {
                            _preset = preset;
                            _reset();
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final speed in _speeds)
                        ChoiceChip(
                          label: Text('${speed}x'),
                          selected: _speed == speed,
                          onSelected: (_) => setState(() => _speed = speed),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _toggleRun,
                        child: Text(_running ? 'Pause' : 'Start'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setState(_reset),
                        child: const Text('New pig'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // The mistake count lives out here on the plastic, never on
                  // the glass: the device is not allowed to show its judgment.
                  DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${pet.stage.name}/${pet.form.name}  '
                            'age ${_ageLabel()}'),
                        Text('health ${pet.health.toStringAsFixed(0)}  '
                            'mistakes ${pet.careMistakes}'
                            '${_bot.neglecting ? '  LAPSING' : ''}'),
                        Text('full ${pet.fullness.toStringAsFixed(0)}  '
                            'enrich ${pet.enrichment.toStringAsFixed(0)}  '
                            'comfort ${pet.comfort.toStringAsFixed(0)}  '
                            'clean ${pet.cleanliness.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final line in _log)
                          Text(
                            line,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test**

```bash
flutter test test/dev/life_cycle_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/dev/life_cycle_page.dart test/dev/life_cycle_page_test.dart
git commit -m "feat(dev): add the page that watches a whole life go past"
```

---

### Task 7: Route, dev menu, and the handoff

**Files:**
- Modify: `lib/main.dart:33-41` (routes) and the `DevMenuPage` button column
- Modify: `HANDOFF.md`

**Interfaces:**
- Consumes: `LifeCyclePage` from Task 6.
- Produces: the route `/dev/life`.

- [ ] **Step 1: Add the route**

In `lib/main.dart`, add the import and the route:

```dart
import 'dev/life_cycle_page.dart';
```

```dart
        '/dev/device': (_) => const DeviceDevPage(),
        '/dev/life': (_) => const LifeCyclePage(),
```

- [ ] **Step 2: Add the dev-menu button**

Directly after the `Device (fake clock)` button in `DevMenuPage`:

```dart
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/dev/life'),
              child: const Text('Life cycle (bot-driven)'),
            ),
```

- [ ] **Step 3: Watch it run**

```bash
./scripts/dev.sh
```

Open `http://127.0.0.1:5173/#/dev/life`, pick `sloppy`, press Start, and watch. Expect the egg to hatch within a couple of seconds, the pig to grow up in about 90 seconds at 3600×, and the log to name the form and the mistake count that decided it. Confirm by eye that the runt's skull is visibly narrower than a prize hog's from an `attentive` run.

- [ ] **Step 4: Update `HANDOFF.md`**

Three edits:

Add to the route table, after `/dev/device`:

```markdown
| `/dev/life` | A bot plays a whole life unattended at 600x-10800x, at one of three care qualities. The only way to see an entire life cycle. |
```

Add to **Deviations from the spec**:

```markdown
**The mistake bands are 2 / 5 / 8, not the spec's 3 / 9 / 25 or the 5 / 14 / 38
they were first scaled to.** A care mistake costs 18 health and health returns
at 0.2 a tick, so an 864-tick childhood affords about eight of them. The old
bands put the entire runt range past the point where the pig was already dead —
four different deliberate-neglect policies, swept across twenty parameter
combinations, all topped out at 8 mistakes. `life-cycle-harness-design.md` has
the measurement. `/dev/life` is what keeps the new bands honest.
```

Update the **Verifying everything** counts from the real output of each suite, and add a line to the M6 row noting that `/dev/life` already exercises transitions, all three forms and death end to end.

- [ ] **Step 5: Run everything one last time**

```bash
cd packages/hog_sim && dart test
cd packages/hog_sim && dart test -p chrome
cd ../.. && flutter test
cd functions && npm test
```

Expected: all green but the standing `prop.grave` failure.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart HANDOFF.md
git commit -m "feat(dev): mount the life cycle harness and record it in the handoff"
```

---

## Notes for whoever executes this

**One deliberate departure from the design.** The spec says the bot carries the icon it is heading for as a field, so a need going urgent mid-navigation cannot leave a menu half-open. It does not: `GameController.press` calls `advance` at the controller's current `nowMillis`, which does not move between presses inside one frame, so the pet only changes when an action actually lands. The goal is therefore already stable for as long as it needs to be, and a remembered goal would be state with nothing to do. If the bot is ever seen thrashing between two icons within a frame, that assumption has broken and the field is the fix.

**The hunt is the only nondeterminism.** `TruffleHunt` draws from `dart:math`'s `Random`, not from `hog_sim`'s seeded generator — deliberately, so playing a minigame cannot alter the simulation's output. It means a run that plays the hunt is not reproducible, and enrichment gains vary between 5 and 25. The full-life tests set `playsHunt: false` for that reason; the page leaves it on, so a run watched on screen may land a mistake either side of the test's result.
