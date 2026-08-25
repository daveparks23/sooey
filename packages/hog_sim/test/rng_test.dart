import 'package:hog_sim/hog_sim.dart';
import 'package:test/test.dart';

void main() {
  // Everything in this file exists to defend one property: the simulation must
  // produce identical output on the Dart VM, under dart2js in Node, and in the
  // Flutter web client. Dart's String.hashCode is not stable across those
  // runtimes and Dart ints are 64-bit on the VM but doubles under dart2js, so
  // the seed path is where divergence would creep in first.

  group('stableHash', () {
    // Known answers published with the FNV-1a specification. These are external
    // to our implementation, so they pin the function rather than describe it.
    test('matches the published FNV-1a 32-bit vectors', () {
      expect(stableHash(''), 0x811C9DC5);
      expect(stableHash('a'), 0xE40C292C);
      expect(stableHash('foobar'), 0xBF9CF968);
    });

    test('stays inside 32 bits for long input', () {
      final h = stableHash('a-fairly-long-firestore-document-id-0123456789');
      expect(h, greaterThanOrEqualTo(0));
      expect(h, lessThan(0x100000000));
    });

    test('distinguishes ids that differ only in the last character', () {
      expect(stableHash('pet_aaaa1'), isNot(stableHash('pet_aaaa2')));
    });
  });

  group('splitmix32', () {
    test('stays inside 32 bits', () {
      for (var seed = 0; seed < 2000; seed++) {
        final v = splitmix32(seed);
        expect(v, greaterThanOrEqualTo(0), reason: 'seed $seed');
        expect(v, lessThan(0x100000000), reason: 'seed $seed');
      }
    });

    test('is a pure function of its seed', () {
      expect(splitmix32(12345), splitmix32(12345));
    });

    test('scatters adjacent seeds', () {
      // A truncation bug under dart2js typically collapses neighbouring seeds
      // onto the same output. Adjacent seeds must not correlate.
      final outputs = {for (var s = 0; s < 500; s++) splitmix32(s)};
      expect(outputs.length, 500);
    });
  });

  group('tickSeed', () {
    test('is stable for the same pet and tick', () {
      expect(tickSeed('pet_abc', 5_900_000), tickSeed('pet_abc', 5_900_000));
    });

    test('differs across ticks for one pet', () {
      final a = tickSeed('pet_abc', 5_900_000);
      final b = tickSeed('pet_abc', 5_900_001);
      expect(a, isNot(b));
    });

    test('differs across pets on the same tick', () {
      final a = tickSeed('pet_abc', 5_900_000);
      final b = tickSeed('pet_abd', 5_900_000);
      expect(a, isNot(b));
    });

    test('handles realistic tick indices without overflowing', () {
      // millisSinceEpoch ~/ 300000 is around 5.9e6 today and grows slowly.
      // tickIndex * 0x9E3779B9 must stay exactly representable.
      final v = tickSeed('pet_abc', 6_500_000);
      expect(v, greaterThanOrEqualTo(0));
      expect(v, lessThan(0x100000000));
    });
  });

  group('unitDouble', () {
    test('lands in [0, 1)', () {
      for (var seed = 0; seed < 2000; seed++) {
        final v = unitDouble(splitmix32(seed));
        expect(v, greaterThanOrEqualTo(0.0), reason: 'seed $seed');
        expect(v, lessThan(1.0), reason: 'seed $seed');
      }
    });

    test('is roughly uniform', () {
      // The sickness roll compares against probabilities near 0.0004. A biased
      // or truncated generator would make sickness either constant or absent.
      var sum = 0.0;
      const n = 20000;
      for (var s = 0; s < n; s++) {
        sum += unitDouble(splitmix32(s));
      }
      expect(sum / n, closeTo(0.5, 0.02));
    });

    test('fires rare events at approximately the requested rate', () {
      var hits = 0;
      const n = 100000;
      for (var s = 0; s < n; s++) {
        if (unitDouble(splitmix32(s)) < 0.004) hits++;
      }
      expect(hits, closeTo(400, 120));
    });
  });
}
