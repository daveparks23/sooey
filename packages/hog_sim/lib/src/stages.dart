import 'constants.dart';
import 'pet_state.dart';

/// Which life stage a pig of this age is in.
Stage stageForAgeMinutes(int ageMinutes) {
  if (ageMinutes < kPigletBeginsAtMinutes) return Stage.egg;
  if (ageMinutes < kAdultBeginsAtMinutes) return Stage.piglet;
  return Stage.adult;
}

/// Whether the pig is asleep at this instant, in its own local time.
///
/// The pet stores a fixed UTC offset rather than an IANA zone, so this does not
/// follow daylight saving. See the plan's note on that trade.
bool isSleepingAtMillis(int millis, int utcOffsetMinutes) {
  final localMillis = millis + utcOffsetMinutes * 60000;
  var hour = (localMillis ~/ 3600000) % 24;
  if (hour < 0) hour += 24; // Dart's % can return negative for negative input.
  return hour >= kSleepStartHour || hour < kSleepEndHour;
}

/// How far past its stage's ideal band the pig weighs, normalised to 0–1.
/// Feeds the sickness roll; being underweight carries no penalty.
double overweightFraction(double weight, Stage stage) {
  final bandMax = kIdealWeight[stage.name]!.$2;
  if (weight <= bandMax) return 0;
  final fraction = (weight - bandMax) / (kWeightMax - bandMax);
  return fraction < 0 ? 0 : (fraction > 1 ? 1 : fraction);
}

/// The adult a piglet grows into, decided by the mistakes made across its whole
/// childhood. The player is never shown this — they just get a different pig.
Form formForMistakes(int stageCareMistakes) {
  if (stageCareMistakes <= kPrizeHogMaxMistakes) return Form.prizeHog;
  if (stageCareMistakes <= kFarmHogMaxMistakes) return Form.farmHog;
  return Form.runt;
}

/// Total lifespan from birth, fixed at the piglet→adult transition.
///
/// Within a form's band, fewer mistakes buys a longer life, interpolated across
/// the mistake range that maps to that form.
int lifespanMinutes(Form form, int stageCareMistakes) {
  final (loMistakes, hiMistakes) = switch (form) {
    Form.prizeHog => (0, kPrizeHogMaxMistakes),
    Form.farmHog => (kPrizeHogMaxMistakes + 1, kFarmHogMaxMistakes),
    Form.runt => (kFarmHogMaxMistakes + 1, kRuntWorstMistakes),
    Form.base => throw ArgumentError('base is not an adult form'),
  };
  final (minDays, maxDays) = kFormLifespanDays[form.name]!;

  var m = stageCareMistakes;
  if (m < loMistakes) m = loMistakes;
  if (m > hiMistakes) m = hiMistakes;

  final t = (m - loMistakes) / (hiMistakes - loMistakes);
  final days = maxDays - t * (maxDays - minDays);
  return (days * kMinutesPerDay).round();
}

/// The moment this pig will die of old age, given the adult it just became.
int expiresAtForAdult(int bornAtMillis, Form form, int stageCareMistakes) =>
    bornAtMillis + lifespanMinutes(form, stageCareMistakes) * 60000;

/// Combined decay multiplier for one tick: stage, then form, then sleep.
double decayMultiplier({
  required Stage stage,
  required Form form,
  required bool isSleeping,
}) {
  var m = kStageDecayMultiplier[stage.name]! * kFormDecayMultiplier[form.name]!;
  if (isSleeping) m *= kSleepDecayMultiplier;
  return m;
}

/// Chance the pig falls ill on a single tick.
double sicknessProbability({
  required double cleanliness,
  required double weight,
  required Stage stage,
  required Form form,
}) {
  final base =
      kSicknessBase +
      kSicknessPerDirt * (1 - cleanliness / 100) +
      kSicknessPerOverweight * overweightFraction(weight, stage);
  return base * kFormSicknessMultiplier[form.name]!;
}
