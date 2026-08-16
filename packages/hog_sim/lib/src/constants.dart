/// Every tunable number in the simulation. Nothing else in this package may
/// contain a magic number — if a rate or threshold matters, it belongs here.
library;

const int kTickMinutes = 5;
const int kTickMillis = kTickMinutes * 60 * 1000;

/// The four need stats, in the order they are evaluated each tick. All are on a
/// 0–100 scale where 100 is good, which lets the UI, the care-mistake detector
/// and the health calculation treat them identically.
const List<String> kNeedNames = [
  'fullness',
  'enrichment',
  'comfort',
  'cleanliness',
];

// Decay per tick while awake, at adult stage, base form.
const double kFullnessDecay = 0.35; // 100 -> 0 in ~24h
const double kEnrichmentDecay = 0.25; // 100 -> 0 in ~33h
const double kComfortDecay = 0.45; // 100 -> 0 in ~18h
const double kCleanlinessDecay = 0.10; // ambient; poop is the real driver

const Map<String, double> kNeedDecay = {
  'fullness': kFullnessDecay,
  'enrichment': kEnrichmentDecay,
  'comfort': kComfortDecay,
  'cleanliness': kCleanlinessDecay,
};

const double kSleepDecayMultiplier = 0.30;

// Health
const double kHealthLossPerZeroedNeed = 1.5; // per tick, per need at 0
const double kHealthRecovery = 0.20; // per tick, all needs > 50, not sick
const double kHealthRecoveryThreshold = 50.0;

// Weight
const double kWeightMin = 20.0;
const double kWeightMax = 120.0;
const double kWeightPerMeal = 2.0;
const double kWeightPerTreat = 1.0;
const double kWeightPerPlay = -1.0;
const double kWeightDecay = 0.05; // per tick

// Poop
const int kTicksUntilPoop = 30; // 150 min after a meal
const int kMaxPoops = 4;
const double kCleanlinessPerPoop = 15.0; // applied on arrival

// Care mistakes
const int kTicksAtZeroForMistake = 12; // one hour at 0 = one mistake

/// Ticks a need must sit at 0 before the pig starts visibly calling for help.
const int kTicksAtZeroForCalling = 6;

// Sleep window, in the pet's local time.
const int kSleepStartHour = 22;
const int kSleepEndHour = 7;

/// Safety valve on the tick loop. Permadeath bounds the simulation naturally,
/// so hitting this means a bug rather than a long absence.
const int kMaxIterations = 20000;

// --- Stage timings (spec §4.1) -------------------------------------------

const int kEggMinutes = 15;

/// The whole childhood. The spec split this into a 24h piglet stage and a 48h
/// shoat stage; they are merged, and the total is unchanged so the pacing to
/// adulthood is exactly as designed.
const int kPigletMinutes = 72 * 60;

/// Age in minutes at which each stage begins.
const int kPigletBeginsAtMinutes = kEggMinutes; // 15
const int kAdultBeginsAtMinutes =
    kPigletBeginsAtMinutes + kPigletMinutes; // 4335

/// Sentinel lifespan for a pet that has not yet reached adulthood. The real
/// `expiresAt` is fixed at the piglet→adult transition; until then old age is
/// simply unreachable.
const int kExpiresAtSentinelMillis = 4102444800000; // 2100-01-01T00:00:00Z

// --- Values the spec references but never defines -------------------------
// Flagged in the implementation plan. Change these freely; they are balance
// knobs, not invariants.

/// Per-stage decay multiplier. A needier childhood is the classic Tamagotchi
/// shape: the early days demand attention, adulthood is steadier. The egg does
/// not decay at all — it simply hatches.
///
/// 1.25 is the time-weighted average of the two stages this replaced — 1.4 for
/// 24h and 1.15 for 48h works out to 1.23 across the same window — so merging
/// them leaves the overall difficulty of a childhood where it was rather than
/// making three days uniformly as demanding as the old first day.
const Map<String, double> kStageDecayMultiplier = {
  'egg': 0.0,
  'piglet': 1.25,
  'adult': 1.0,
};

/// Ideal weight band per stage, used for `overweightFraction` in the sickness
/// roll. Below or inside the band carries no penalty.
///
/// The piglet band spans what used to be two bands, because one stage now
/// covers a pig growing from newborn to nearly adult. In practice the ceiling
/// rarely binds: weight decays faster over three days than ordinary feeding
/// replaces it, so a piglet trends toward the floor unless deliberately
/// overfed — which is exactly when the penalty should bite.
const Map<String, (double, double)> kIdealWeight = {
  'egg': (20.0, 35.0),
  'piglet': (20.0, 50.0),
  'adult': (60.0, 95.0),
};

const double kNewbornWeight = 22.0;

// --- Sickness (spec §5.4) -------------------------------------------------

const double kSicknessBase = 0.0004;
const double kSicknessPerDirt = 0.0020;
const double kSicknessPerOverweight = 0.0015;

// --- Actions (spec §7) ----------------------------------------------------

const double kSlopFullness = 30.0;
const double kSlopRefusedAbove = 90.0;
const double kTreatFullness = 8.0;
const double kTreatEnrichment = 10.0;
const double kWallowCleanlinessCost = 10.0;
const double kMedsHealthPenalty = 5.0; // medicating a healthy pig

const double kPlayEnrichmentHigh = 25.0; // 4-5 wins
const double kPlayEnrichmentMid = 12.0; // 2-3 wins
const double kPlayEnrichmentLow = 5.0; // 0-1 wins
const int kPlayRounds = 5;
const int kPlayCooldownMillis = 2 * 60 * 1000;

const int kMaxNameLength = 12;

// --- Adult forms (spec §4.2) ----------------------------------------------

/// Decay multiplier applied on top of the stage multiplier once the pig has
/// branched into an adult form.
const Map<String, double> kFormDecayMultiplier = {
  'base': 1.0,
  'prizeHog': 0.85,
  'farmHog': 1.0,
  'runt': 1.25,
};

const Map<String, double> kFormSicknessMultiplier = {
  'base': 1.0,
  'prizeHog': 1.0,
  'farmHog': 1.0,
  'runt': 1.5,
};

/// Mistake bands that decide the adult form, and the lifespan each band buys.
/// Within a band, fewer mistakes means a longer life; the exact day is fixed at
/// the piglet→adult transition and stored as `expiresAt`.
///
/// Scaled 1.5x from the spec's 3 / 9 / 25. Those were tuned for a 48h shoat
/// stage; the judgment now runs over the full 72h childhood, so leaving them
/// alone would have made a prize hog far harder to earn without anyone
/// deciding that it should be.
const int kPrizeHogMaxMistakes = 5;
const int kFarmHogMaxMistakes = 14;

/// Mistake count at which the runt's lifespan bottoms out.
const int kRuntWorstMistakes = 38;

const Map<String, (int, int)> kFormLifespanDays = {
  'prizeHog': (18, 20),
  'farmHog': (15, 17),
  'runt': (12, 14),
};

const int kMinutesPerDay = 24 * 60;
