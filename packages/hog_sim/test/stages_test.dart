import 'package:hog_sim/hog_sim.dart';
import 'package:test/test.dart';

void main() {
  group('stageForAgeMinutes', () {
    test('follows the spec timings', () {
      expect(stageForAgeMinutes(0), Stage.egg);
      expect(stageForAgeMinutes(14), Stage.egg);
      expect(stageForAgeMinutes(15), Stage.piglet);
      // The childhood is one stage now, running the full 72 hours.
      expect(stageForAgeMinutes(1455), Stage.piglet);
      expect(stageForAgeMinutes(4334), Stage.piglet);
      expect(stageForAgeMinutes(4335), Stage.adult);
      expect(stageForAgeMinutes(100000), Stage.adult);
    });

    test('never moves backwards as the pig ages', () {
      var previous = 0;
      for (var m = 0; m < 6000; m += 7) {
        final index = stageForAgeMinutes(m).index;
        expect(index, greaterThanOrEqualTo(previous));
        previous = index;
      }
    });
  });

  group('isSleepingAtMillis', () {
    // 2025-08-12T00:00:00Z, so UTC hour equals millis/3600000 % 24.
    const midnightUtc = 1754956800000;
    int atUtcHour(int h) => midnightUtc + h * 3600000;

    test('sleeps from 22:00 through 06:59 local', () {
      for (final hour in [22, 23, 0, 3, 6]) {
        expect(
          isSleepingAtMillis(atUtcHour(hour), 0),
          isTrue,
          reason: '$hour:00 should be asleep',
        );
      }
    });

    test('is awake from 07:00 through 21:59 local', () {
      for (final hour in [7, 12, 18, 21]) {
        expect(
          isSleepingAtMillis(atUtcHour(hour), 0),
          isFalse,
          reason: '$hour:00 should be awake',
        );
      }
    });

    test('respects the pet\'s own offset rather than UTC', () {
      // 02:00 UTC is 21:00 in UTC-5 — still awake there, asleep in UTC.
      expect(isSleepingAtMillis(atUtcHour(2), 0), isTrue);
      expect(isSleepingAtMillis(atUtcHour(2), -300), isFalse);
    });

    test('handles offsets that push local time into the previous day', () {
      // 01:00 UTC is 20:00 the previous day in UTC-5.
      expect(isSleepingAtMillis(atUtcHour(1), -300), isFalse);
      // 04:00 UTC is 23:00 the previous day in UTC-5.
      expect(isSleepingAtMillis(atUtcHour(4), -300), isTrue);
    });

    test('handles positive offsets that roll past midnight', () {
      // 16:00 UTC is 01:00 the next day in UTC+9.
      expect(isSleepingAtMillis(atUtcHour(16), 540), isTrue);
      // 10:00 UTC is 19:00 in UTC+9.
      expect(isSleepingAtMillis(atUtcHour(10), 540), isFalse);
    });
  });

  group('overweightFraction', () {
    test('is zero inside and below the ideal band', () {
      expect(overweightFraction(60, Stage.adult), 0);
      expect(overweightFraction(95, Stage.adult), 0);
      expect(overweightFraction(30, Stage.adult), 0);
    });

    test('reaches one at the maximum weight', () {
      expect(overweightFraction(120, Stage.adult), 1);
    });

    test('scales linearly between the band and the maximum', () {
      expect(overweightFraction(107.5, Stage.adult), closeTo(0.5, 1e-9));
    });

    test('uses a tighter band for younger stages', () {
      // 60kg is fine for an adult but heavy for a piglet.
      expect(overweightFraction(60, Stage.adult), 0);
      expect(overweightFraction(60, Stage.piglet), greaterThan(0));
    });
  });

  group('formForMistakes', () {
    test('follows the spec bands', () {
      expect(formForMistakes(0), Form.prizeHog);
      expect(formForMistakes(kPrizeHogMaxMistakes), Form.prizeHog);
      expect(formForMistakes(kPrizeHogMaxMistakes + 1), Form.farmHog);
      expect(formForMistakes(kFarmHogMaxMistakes), Form.farmHog);
      expect(formForMistakes(kFarmHogMaxMistakes + 1), Form.runt);
      expect(formForMistakes(500), Form.runt);
    });
  });

  group('lifespanMinutes', () {
    int days(Form f, int mistakes) =>
        lifespanMinutes(f, mistakes) ~/ kMinutesPerDay;

    test('spans the band each form is entitled to', () {
      expect(days(Form.prizeHog, 0), 20);
      expect(days(Form.prizeHog, kPrizeHogMaxMistakes), 18);
      expect(days(Form.farmHog, kPrizeHogMaxMistakes + 1), 17);
      expect(days(Form.farmHog, kFarmHogMaxMistakes), 15);
      expect(days(Form.runt, kFarmHogMaxMistakes + 1), 14);
      expect(days(Form.runt, kRuntWorstMistakes), 12);
    });

    test('bottoms out rather than going negative for extreme neglect', () {
      expect(days(Form.runt, 1000), 12);
    });

    test('never rewards more mistakes with a longer life', () {
      var previous = 1 << 30;
      for (var m = 0; m <= 80; m++) {
        final span = lifespanMinutes(formForMistakes(m), m);
        expect(
          span,
          lessThanOrEqualTo(previous),
          reason: 'lifespan grew at $m mistakes',
        );
        previous = span;
      }
    });

    test('stays inside the 12 to 20 day range the spec promises', () {
      for (var m = 0; m <= 80; m++) {
        final d = lifespanMinutes(formForMistakes(m), m) / kMinutesPerDay;
        expect(d, greaterThanOrEqualTo(12));
        expect(d, lessThanOrEqualTo(20));
      }
    });
  });

  group('decay multipliers', () {
    test('the egg does not decay', () {
      expect(kStageDecayMultiplier['egg'], 0.0);
    });

    test('the childhood decays faster than adulthood', () {
      expect(
        kStageDecayMultiplier['piglet']!,
        greaterThan(kStageDecayMultiplier['adult']!),
      );
    });

    test('the prize hog decays slower and the runt faster', () {
      expect(kFormDecayMultiplier['prizeHog']!, lessThan(1.0));
      expect(kFormDecayMultiplier['farmHog']!, 1.0);
      expect(kFormDecayMultiplier['runt']!, greaterThan(1.0));
    });
  });
}
