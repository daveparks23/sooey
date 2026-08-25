# Pig Tamagotchi — Build Specification

**Working title:** Hog Pocket
**Target:** Flutter Web + Firebase (Firestore, Auth, Cloud Functions/Cloud Run, FCM)
**Audience:** implementing agent
**Status:** design locked except where marked `OPEN DECISION`

---

## 1. What this is

A virtual pet in the style of a 1996 Tamagotchi. The player raises a pig on a
simulated dot-matrix LCD. The pig ages in real time whether or not the app is
open. If the player neglects it, it dies permanently and they start over with a
new pig.

The emotional core is **permadeath plus hidden judgment**: the game never tells
the player they are doing badly, but the adult the pig grows into is determined
by care quality they cannot see.

### 1.1 Locked design decisions

| Decision | Choice |
| --- | --- |
| Visual fidelity | True LCD — 32×16 monochrome dot grid, black dots on green |
| Time model | Real time; the pig ages while the app is closed |
| Death | Permadeath. Pet is gone. Player starts a new one. |
| Lineage / inheritance | None. A tombstone record only. |
| Art pipeline | None. Sprites are hand-authored data, not image assets. |

### 1.2 Non-goals

- No sprite sheets, PNGs, or asset loading. **Do not add Flame or any game engine.**
- No PixelLab / Retro Diffusion / AI art step. Sprites are `List<String>` literals.
- No multiplayer, breeding, trading, or social features in v1.
- No monetization, no analytics beyond Firebase defaults.
- No sound in v1 (see §16, deferred).

---

## 2. Tech stack and constraints

- **Flutter** stable channel, web target. Also builds for iOS/Android but web is primary.
- **Firestore** — one document per pet, one per user. Named database + region must
  match the Cloud Functions / Cloud Run region. Do not let Firestore land in a
  multi-region (`nam5`) while compute sits in a single region; pick `us-central1`
  for both.
- **Firebase Auth** — anonymous sign-in on first load, with an upgrade path to
  Google / email link so a player does not lose their pig when they clear storage.
- **Cloud Functions Gen 2** or **Cloud Run** — see `OPEN DECISION D1`.
- **FCM web push** — requires `web/firebase-messaging-sw.js`. On iOS Safari, push
  only fires if the user has added the PWA to their home screen. Surface this in
  the UI rather than silently failing.

### 2.1 `OPEN DECISION D1` — where the simulation runs

The tick simulation (§5) is the single most important piece of code in this
project, and both client and server need to run it. Two viable options:

**Option A — Dart everywhere (recommended).**
Put the simulation in a shared Dart package (`packages/hog_sim`). The Flutter
client imports it for optimistic UI. Deploy the same package as a **Dart Cloud
Run service** (`shelf` router) that acts as the authoritative backend. One
implementation, no drift.
*Cost:* no official Dart Firebase Admin SDK. You verify ID tokens yourself
(fetch Google's public certs, validate the JWT) and talk to Firestore through
the `googleapis` package or the REST API. Roughly a day of plumbing.

**Option B — TypeScript functions.**
Port the simulation to TypeScript for Cloud Functions Gen 2, keep a Dart copy
client-side purely for optimistic display, and reconcile from the server response
on every call.
*Cost:* the same logic maintained in two languages forever. Every decay-rate
tweak is two edits and a desync bug waiting to happen.

**Recommendation: Option A.** The plumbing cost is one-time; the duplication cost
in Option B is permanent. The rest of this spec assumes Option A and describes
endpoints as HTTP routes; if Option B is chosen, they map 1:1 onto callable
functions.

---

## 3. The pig's stats

All need stats are `double` on a **0–100 scale where 100 is good**. This
uniformity matters — it lets the UI, the care-mistake detector, and the health
calculation treat every need identically.

| Stat | Meaning | 100 means | 0 means |
| --- | --- | --- | --- |
| `fullness` | Hunger | Just ate | Starving |
| `enrichment` | Mental stimulation | Content | Bored, destructive |
| `comfort` | Thermal comfort | Cool, recently wallowed | Overheating |
| `cleanliness` | Pen hygiene | Clean | Filthy |
| `health` | Derived condition | Healthy | Dead |

Plus:

| Field | Type | Range | Notes |
| --- | --- | --- | --- |
| `weight` | double | 20–120 | Not a need. Ideal band varies by stage. |
| `discipline` | double | 0–100 | Raised by training, lowered by ignoring misbehavior. |
| `isSick` | bool | | Blocks health recovery; needs medicine. |
| `isSleeping` | bool | | Derived from local time, not stored authoritatively. |

### 3.1 Why these stats

`comfort` is the signature mechanic and should not be cut. Pigs cannot sweat —
they thermoregulate by wallowing in mud. This produces a mechanic no other
virtual pet has: **the action that fixes comfort actively damages cleanliness.**
Wallowing is correct pig care and it makes a mess. That tension is the game.

Similarly, `fullness` inverts the usual Tamagotchi reflex. Pigs do not
self-regulate intake. Feeding always helps hunger and always adds weight, and an
overweight pig decays faster and gets sick more. Feeding is not a free action.

---

## 4. Constants

Put all of these in one file, `packages/hog_sim/lib/src/constants.dart`. Do not
scatter magic numbers through the simulation.

```dart
const int kTickMinutes = 5;

// Decay per tick while awake, at adult stage, base form.
const double kFullnessDecay    = 0.35;  // 100 -> 0 in ~24h
const double kEnrichmentDecay  = 0.25;  // 100 -> 0 in ~33h
const double kComfortDecay     = 0.45;  // 100 -> 0 in ~18h
const double kCleanlinessDecay = 0.10;  // ambient; poop is the real driver

const double kSleepDecayMultiplier = 0.30;

// Health
const double kHealthLossPerZeroedNeed = 1.5;   // per tick, per need at 0
const double kHealthRecovery          = 0.20;  // per tick, all needs > 50, not sick

// Weight
const double kWeightPerMeal   = 2.0;
const double kWeightPerTreat  = 1.0;
const double kWeightPerPlay   = -1.0;
const double kWeightDecay     = 0.05;  // per tick

// Poop
const int kTicksUntilPoop = 30;   // 150 min after a meal
const int kMaxPoops       = 4;
const double kCleanlinessPerPoop = 15.0;  // applied on arrival

// Care mistakes
const int kTicksAtZeroForMistake = 12;  // one hour at 0 = one mistake

// Sleep window (pet's local time, stored per pet)
const int kSleepStartHour = 22;
const int kSleepEndHour   = 7;
```

### 4.1 Stage timings

| Stage | Begins at age | Duration |
| --- | --- | --- |
| `egg` | 0 | 15 minutes |
| `piglet` | 15 min | 24 hours |
| `shoat` | ~24 h | 48 hours |
| `adult` | ~72 h | until death |

Natural death from old age: adults die between **day 12 and day 20**, with the
exact day set at the shoat→adult transition based on accumulated care mistakes.
Fewer mistakes buys a longer life. Store as `expiresAt` on the pet so it is a
plain timestamp comparison, not a recomputation.

### 4.2 Adult forms

At the shoat→adult transition, branch on `stageCareMistakes` accumulated during
the shoat stage:

| Mistakes | Form | Effect |
| --- | --- | --- |
| 0–3 | `prizeHog` | Decay rates ×0.85, lifespan 18–20 days |
| 4–9 | `farmHog` | Decay rates ×1.0, lifespan 15–17 days |
| 10+ | `runt` | Decay rates ×1.25, lifespan 12–14 days, sickness chance ×1.5 |

Each form has its own sprite pair (§10.4). **The player is never shown the
mistake count or the form name.** They just get a different-looking pig.

---

## 5. The tick simulation

This is the heart of the project. Build and test it **before writing any UI.**

### 5.1 Signature

```dart
/// Pure. No I/O, no clock reads, no unseeded randomness.
PetState advance(PetState from, DateTime now);
```

`advance` steps the pet forward in `kTickMinutes` increments from
`from.lastTickAt` until it reaches `now` or the pet dies, whichever is first.

### 5.2 Why you cannot subtract

It is tempting to write `fullness -= elapsedMinutes * rate`. Do not. The
simulation is path-dependent:

- `health` only degrades during ticks where a need is *already* at 0, so you need
  to know the order in which needs bottomed out.
- The pet sleeps between 22:00 and 07:00, and decay is multiplied by 0.3 during
  those ticks. A 12-hour absence spans both states.
- Poops arrive on a schedule and each one drops `cleanliness` on arrival, which
  changes the sickness roll for every subsequent tick.
- Life-stage transitions change decay multipliers mid-window.

Ten hours at 5-minute ticks is 120 iterations of arithmetic. It is free. Simulate
properly.

### 5.3 Per-tick order of operations

Execute in exactly this order. The order is part of the spec because it is
observable.

1. `tickIndex = millisSinceEpoch ~/ (kTickMinutes * 60000)`
2. Determine `isSleeping` from the pet's local hour at this tick.
3. Advance age; apply any life-stage transition (may change `form`, `expiresAt`).
4. Deliver any poops scheduled for this tick; apply `kCleanlinessPerPoop` each.
5. Apply need decay, multiplied by stage multiplier, form multiplier, and sleep
   multiplier. Clamp to 0.
6. Apply weight decay.
7. Roll for sickness (§5.4) if not already sick.
8. Apply health change: subtract `kHealthLossPerZeroedNeed` for each need at 0;
   otherwise if all needs > 50 and not sick, add `kHealthRecovery`. Clamp 0–100.
9. Update `needZeroSinceTick` per need; if any need has been at 0 for
   `kTicksAtZeroForMistake` ticks, increment `careMistakes` and
   `stageCareMistakes`, then reset that need's counter.
10. Check death conditions (§8). If dead, stop the loop immediately and record
    `diedAt` as the timestamp of this tick — not `now`.

### 5.4 Determinism

Any randomness inside the loop must be reproducible, or the client's optimistic
prediction will disagree with the server and the pig will visibly "snap" to a
different state on every sync.

```dart
int tickSeed(String petId, int tickIndex) =>
    _splitmix64(petId.hashCode ^ (tickIndex * 0x9E3779B9));
```

Use that seed for the sickness roll and nothing else. Minigame randomness is
*interactive*, happens outside the tick loop, and is handled in §7.4.

Sickness probability per tick:

```
p = base * formMultiplier
base = 0.0004
     + 0.0020 * (1 - cleanliness/100)
     + 0.0015 * overweightFraction
```

where `overweightFraction` is how far `weight` exceeds the stage's ideal band,
normalized 0–1.

### 5.5 Bounding the simulation

Permadeath bounds this naturally: if the player has been away three weeks, the
loop terminates at the death tick, typically within a day or two of simulated
time. Still, add a hard cap of **20,000 iterations** as a safety valve and log if
it is ever hit — that means a bug, not a long absence.

### 5.6 Required tests

`advance` must have unit tests before any UI work begins. At minimum:

- A pet with full needs, advanced 1 hour, loses the expected amount of each stat.
- A pet advanced across the 22:00 boundary decays more slowly on the far side.
- A pet with `fullness = 0` loses health at exactly `kHealthLossPerZeroedNeed`
  per tick, and twice that when two needs are zeroed.
- A pet advanced 30 days dies, and `diedAt` is the death tick, not `now`.
- `advance(s, t)` called once for a 6-hour window equals `advance` called 72
  times for 5-minute windows. **This property test is the important one** — it is
  what guarantees client and server agree.
- Two calls with the same `petId` and window produce byte-identical output.

---

## 6. Screen layout and navigation

Three physical buttons, exactly like the original hardware. Do not add a
touch-anywhere UI; the constraint is the charm.

- **A (left)** — cycle selection through the icon row
- **B (center)** — confirm / act
- **C (right)** — cancel / back

Eight icons, four above the screen and four below, each highlighted when
selected:

| Icon | Action |
| --- | --- |
| `feed` | Opens a submenu: slop or treat |
| `wallow` | Comfort restore |
| `play` | Truffle-hunt minigame |
| `train` | Discipline |
| `meds` | Cure sickness |
| `clean` | Remove poops |
| `stats` | Status screens |
| `light` | Toggle the pen light |

The pig is drawn on the LCD between the two icon rows. Poops render as separate
small sprites at fixed floor positions.

---

## 7. Actions

All actions route through the server (§12). The client applies the result
optimistically and reconciles from the response.

### 7.1 Feed

- **Slop** — `fullness +30`, `weight +kWeightPerMeal`, schedules a poop
  `kTicksUntilPoop` ahead. Rejected if `fullness > 90` (the pig refuses; this is
  feedback, not an error).
- **Treat (apple)** — `fullness +8`, `enrichment +10`, `weight +kWeightPerTreat`,
  no poop scheduled.

### 7.2 Wallow

`comfort → 100`, `cleanliness -10`. Always available. This is the mechanic that
teaches the player the game has real pig logic in it: doing the right thing makes
a mess they then have to clean.

### 7.3 Clean

Removes all poops. `cleanliness → 100`. Each poop left on screen when cleanliness
would otherwise recover is what drives sickness, so this is the highest-frequency
action.

### 7.4 Play — truffle hunt

Best of five. Each round the pig turns left or right; the player guesses with A
or C. Purely client-side, resolved instantly for responsiveness, then the result
is submitted for validation.

- 4–5 correct: `enrichment +25`, `weight +kWeightPerPlay`
- 2–3 correct: `enrichment +12`
- 0–1 correct: `enrichment +5`

Server validates only that `rounds == 5` and `0 <= wins <= 5` and that the pet
has not played within the last 2 minutes. Do not try to make the minigame
cheat-proof; the stakes do not justify it.

### 7.5 Train

When a need has been at 0 for more than 6 ticks, the pig starts "calling" — a
blinking attention indicator. Responding with the *correct* action clears it.
Responding with `train` while the pig is calling legitimately is a mistake and
costs `discipline -10`. Training when the pig misbehaves without cause gives
`discipline +15`.

Discipline is not currently wired into evolution. `OPEN DECISION D2`: either
fold `discipline` into the adult-form branch alongside care mistakes, or cut the
training mechanic entirely from v1. Recommendation: cut it from v1 and add it in
v1.1 once the core loop is proven. It adds surface area without adding much.

### 7.6 Meds

Clears `isSick`. If used when the pig is not sick, `health -5` — medicating a
healthy animal is a care mistake.

---

## 8. Death

The pet dies when any of these is true at the end of a tick:

| Condition | `deathCause` |
| --- | --- |
| `health <= 0` and `fullness == 0` for the preceding 24h | `starvation` |
| `health <= 0` and `isSick` for the preceding 24h | `illness` |
| `health <= 0`, other | `neglect` |
| `now >= expiresAt` | `oldAge` |

On death:

1. Set `diedAt` (the tick timestamp), `deathCause`, and freeze all stats.
2. Write a tombstone to `users/{uid}/tombstones/{petId}` with name, lifespan in
   minutes, stage and form reached, and total care mistakes.
3. Increment `users/{uid}.petsRaised` and update `bestLifespanMinutes`.
4. Clear `users/{uid}.currentPetId`.

The death screen shows a simple grave sprite, the pig's name, and its age.
Nothing else. **Do not show the care-mistake count even after death** — keeping
the judgment hidden is what makes players replay to find out how to do better.

---

## 9. Notifications

Offline decay plus permadeath without notifications is a game that kills your pet
while you are not looking. Push is not optional.

**Do not scan the pets collection on a schedule.** Instead:

- On every write to a pet, compute `nextCriticalAt` — the timestamp at which the
  first need will reach 0 — by running the simulation forward with no player
  intervention. Store it on the document.
- A scheduled job every 15 minutes runs a single indexed query:
  `where('nextCriticalAt', '<=', now).where('diedAt', '==', null)` and notifies
  only those pets. Requires a composite index on `(diedAt, nextCriticalAt)`.
- Rate-limit to one push per pet per 4 hours via a `lastNotifiedAt` field.
- Suppress pushes during the pet's sleep window.

Notification copy should be diegetic and never nagging: "Wilbur is getting
hungry." Never "Come back to the app!"

---

## 10. Rendering

### 10.1 The display

- Logical resolution: **32 columns × 16 rows** of dots. Never change this.
- Dot size: `floor(availableWidth / 32)`, with a 1px gap. Integer scaling only —
  fractional dot sizes produce visible shimmer.
- Colors (hardcoded, does not respond to system dark mode):
  - dot on: `#1C2410`
  - dot off: `#93A667`
  - screen background: `#9CAF6E`
  - device shell: `#E3A6B5`, shell border `#C4899A`, buttons `#C4899A`

### 10.2 Sprite format

A sprite is a small struct, not an image:

```dart
class LcdSprite {
  final int width;
  final int height;
  final List<String> rows;  // '#' = on, '.' = off, ' ' = transparent
  const LcdSprite(this.width, this.height, this.rows);
}
```

Note the three-state cell. Transparent is required so poops and status icons can
be composited over the background without punching holes in it.

### 10.3 Compositing

```dart
class LcdBuffer {
  final List<List<bool>> pixels;  // [16][32]
  void clear();
  void blit(LcdSprite sprite, int dx, int dy);
}
```

Build the full 32×16 frame in a buffer each frame, then hand it to a single
`CustomPainter` that draws 512 rects. `shouldRepaint` compares the frame counter,
not the buffer contents.

### 10.4 Animation

Every creature state needs **two frames alternating every 600ms**. This is not
optional polish. At 32×16 you have almost no room for expressive detail, so
motion carries the entire emotional read — a pig that shifts its weight while
idle looks alive, and a static one looks like a rendering bug.

Required frame pairs:

- piglet idle, piglet eating, piglet sleeping
- shoat idle, shoat eating, shoat sleeping
- adult idle × 3 forms, adult eating × 3 forms, adult sleeping × 3 forms
- wallowing, sick, calling for attention, dead/grave
- poop (4×4, static), heart (celebration), skull (death screen)

That is roughly 30 sprites. At ten minutes each of grid editing, it is an
afternoon — cheaper than any generated-art pipeline would have been.

### 10.5 Starter sprite data

These two are done. Use them as the reference for style and proportion when
authoring the rest — chunky solid masses, eyes as *holes* punched in the body
rather than drawn dots, no single-pixel details.

```dart
// Adult hog, idle frame 1. 32x16, side view facing right.
const kAdultHogIdle1 = LcdSprite(32, 16, [
  "................................",
  "................................",
  ".................##...##........",
  "................####.####.......",
  "..............##############....",
  ".........####################...",
  ".....##.######################..",
  "...##.####################.####.",
  "....###########################.",
  "....##########################.#",
  "....############################",
  ".....#########################..",
  "......######################....",
  "........####..####...####.####..",
  "........####..####...####.####..",
  "................................",
]);

// Piglet, idle frame 1. 32x16, front view.
const kPigletIdle1 = LcdSprite(32, 16, [
  "................................",
  "................................",
  "................................",
  "................................",
  "................................",
  "............##...##.............",
  "...........####.####............",
  "..........############..........",
  ".........####.####.####.........",
  ".........##############.........",
  ".........####.##.#####..........",
  "..........############..........",
  "...........##....##.............",
  "...........##....##.............",
  "................................",
  "................................",
]);
```

For frame 2 of each idle animation, shift the legs by one row and drop the body
one row. That single-pixel bob is enough.

---

## 11. Data model

### 11.1 `users/{uid}`

| Field | Type | Notes |
| --- | --- | --- |
| `currentPetId` | string? | null when between pets |
| `petsRaised` | int | |
| `bestLifespanMinutes` | int | |
| `fcmTokens` | string[] | |
| `timezone` | string | IANA name; drives the sleep window |
| `createdAt` | timestamp | server |

### 11.2 `pets/{petId}`

| Field | Type | Notes |
| --- | --- | --- |
| `ownerId` | string | |
| `name` | string | player-chosen, max 12 chars |
| `bornAt` | timestamp | server |
| `lastTickAt` | timestamp | server; the simulation cursor |
| `nextCriticalAt` | timestamp | for the notification query |
| `expiresAt` | timestamp | old-age death |
| `diedAt` | timestamp? | null while alive |
| `deathCause` | string? | |
| `stage` | string | `egg` / `piglet` / `shoat` / `adult` |
| `form` | string | `base` / `prizeHog` / `farmHog` / `runt` |
| `fullness` | double | |
| `enrichment` | double | |
| `comfort` | double | |
| `cleanliness` | double | |
| `health` | double | |
| `weight` | double | |
| `discipline` | double | |
| `isSick` | bool | |
| `lightsOn` | bool | |
| `poops` | int[] | tick indices of arrival |
| `pendingPoopTicks` | int[] | scheduled future arrivals |
| `needZeroSinceTick` | map<string,int?> | per-need mistake tracking |
| `careMistakes` | int | lifetime, hidden |
| `stageCareMistakes` | int | reset at each transition, hidden |
| `lastNotifiedAt` | timestamp? | |

### 11.3 `users/{uid}/tombstones/{petId}`

Name, `bornAt`, `diedAt`, `lifespanMinutes`, `stage`, `form`, `deathCause`,
`careMistakes`. Written once, never updated.

---

## 12. Server API and security

### 12.1 Firestore rules

The client is **never** allowed to write to `pets`. Every state change goes
through the server, which is the only holder of a trusted clock. This is what
prevents a player from editing `lastTickAt` to skip decay or fast-forward
evolution.

```
match /pets/{petId} {
  allow read: if request.auth != null
              && resource.data.ownerId == request.auth.uid;
  allow write: if false;
}

match /users/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow update: if request.auth != null && request.auth.uid == uid
                && request.resource.data.diff(resource.data)
                     .affectedKeys().hasOnly(['fcmTokens', 'timezone']);
  match /tombstones/{petId} {
    allow read: if request.auth != null && request.auth.uid == uid;
    allow write: if false;
  }
}
```

### 12.2 Endpoints

Every endpoint verifies the Firebase ID token, loads the pet, runs
`advance(pet, serverNow)` **first**, then applies the requested action, then
recomputes `nextCriticalAt`, then writes. Every response returns the complete
post-action `PetState` so the client can reconcile.

| Route | Body | Returns |
| --- | --- | --- |
| `POST /pets` | `{name}` | `PetState` |
| `POST /pets/{id}/sync` | — | `PetState` |
| `POST /pets/{id}/action` | `{action, payload?}` | `PetState` |
| `POST /pets/{id}/minigame` | `{wins, rounds}` | `PetState` |
| `GET /pets/{id}` | — | `PetState` (no advance; debug only) |

A player may hold at most one living pet. `POST /pets` fails with 409 if
`currentPetId` is set and that pet is alive.

An invocation per player action is a rounding error in cost for this workload.
Set Gen 2 min instances to 0 and accept the cold start.

---

## 13. Project structure

```
hog_pocket/
  packages/
    hog_sim/                  # pure Dart, zero Flutter/Firebase deps
      lib/
        hog_sim.dart
        src/
          constants.dart
          pet_state.dart      # immutable model + JSON round-trip
          advance.dart        # the tick loop
          actions.dart        # pure action application
          rng.dart            # splitmix64
      test/                   # exhaustive; see §5.6
  app/                        # Flutter web client
    lib/
      lcd/                    # LcdSprite, LcdBuffer, LcdPainter
      sprites/                # sprite data files, one per creature
      screens/
      services/               # auth, api client, fcm
  server/                     # Dart Cloud Run service (Option A)
    bin/server.dart
    lib/
      auth.dart               # ID token verification
      firestore.dart
      routes.dart
  firestore.rules
  firestore.indexes.json
```

`packages/hog_sim` must not import `package:flutter` or any Firebase package.
That constraint is what lets the same code run on Cloud Run. Enforce it with an
analyzer rule if convenient.

---

## 14. Build order

Each milestone has an acceptance criterion. Do not proceed until it passes.

**M1 — Simulation.** `packages/hog_sim` complete with the tests in §5.6 green.
No UI, no Firebase.
*Accept:* the 6-hour-vs-72-ticks equivalence property test passes.

**M2 — Renderer.** `LcdSprite`, `LcdBuffer`, `LcdPainter`, and the two starter
sprites animating at 600ms in a bare Flutter page.
*Accept:* the pig renders crisply at three window widths with no fractional dots.

**M3 — Local loop.** Wire the simulation to the renderer with in-memory state and
the three-button UI. Fully playable, nothing persisted.
*Accept:* a pet can be fed, cleaned, and played with, and dies if left alone.

**M4 — Persistence.** Anonymous auth, Firestore, the server, rules locked to
read-only. Reload the page and the pig has aged correctly.
*Accept:* close the tab for an hour, reopen, and the stat drop matches what the
simulation predicts to within one tick.

**M5 — Life cycle.** Stage transitions, the three adult forms, death, tombstones,
starting a new pet.
*Accept:* a pet neglected from birth reaches `runt`; a well-cared-for one reaches
`prizeHog`.

**M6 — Notifications.** FCM web push, `nextCriticalAt`, the scheduled job, the
composite index, iOS PWA guidance in the UI.
*Accept:* a push arrives within 15 minutes of a need bottoming out, and no more
than one arrives per 4 hours.

---

## 15. Open decisions

| ID | Decision | Recommendation |
| --- | --- | --- |
| D1 | Dart Cloud Run vs TypeScript functions (§2.1) | Dart Cloud Run |
| D2 | Keep or cut the discipline/training mechanic (§7.5) | Cut from v1 |
| D3 | Should the tick be 5 or 15 minutes? | Start at 5; raise if write volume becomes a concern |
| D4 | Timezone source — device or user-selected? | Device on first run, editable in settings |

---

## 16. Deferred to later versions

- Sound. Piezo-style square-wave beeps via `dart:web_audio` would be extremely
  period-appropriate but add nothing to the core loop.
- A graveyard screen browsing past tombstones.
- Lineage — a new pet inheriting a trait from its predecessor. Deliberately
  excluded from v1 because permadeath is more affecting without a consolation
  prize.
- Multiple simultaneous pets.
- A shop / currency loop. Probably never; it works against the tone.