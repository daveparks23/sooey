import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/frame_composer.dart';
import 'package:sooey/lcd/lcd_buffer.dart';
import 'package:sooey/sprites/sprite_registry.dart';

const refNoon = 1755000000000;
const _hour = 3600000;

PetState pet({
  Stage stage = Stage.adult,
  Form form = Form.farmHog,
  double fullness = 80,
  double comfort = 80,
  bool isSick = false,
  bool lightsOn = true,
  List<int> poops = const [],
  Map<String, int> needZeroSinceTick = const {},
  bool dead = false,
}) {
  var p =
      PetState.newborn(
        petId: 'pet_test',
        ownerId: 'uid_1',
        name: 'Wilbur',
        nowMillis: refNoon - 7 * 24 * _hour,
        utcOffsetMinutes: 0,
      ).copyWith(
        stage: stage,
        form: form,
        lastTickAtMillis: refNoon,
        fullness: fullness,
        comfort: comfort,
        isSick: isSick,
        lightsOn: lightsOn,
        poops: poops,
        needZeroSinceTick: needZeroSinceTick,
      );
  if (dead) {
    p = p.copyWith(
      diedAtMillis: refNoon - 1000,
      deathCause: DeathCause.neglect,
    );
  }
  return p;
}

/// Counts lit dots, which is the cheapest way to ask "did anything get drawn".
int litDots(LcdBuffer b) {
  var n = 0;
  for (var y = 0; y < kLcdHeight; y++) {
    for (var x = 0; x < kLcdWidth; x++) {
      if (b.get(x, y)) n++;
    }
  }
  return n;
}

void main() {
  group('composeFrame', () {
    test('draws the pig', () {
      final b = composeFrame(pet(), frame: 0, nowMillis: refNoon);
      expect(litDots(b), greaterThan(40));
    });

    test('animates between frames', () {
      final a = composeFrame(pet(), frame: 0, nowMillis: refNoon).toAscii();
      final c = composeFrame(pet(), frame: 1, nowMillis: refNoon).toAscii();
      expect(a, isNot(c));
    });

    test('is deterministic for the same inputs', () {
      final a = composeFrame(pet(), frame: 3, nowMillis: refNoon).toAscii();
      final c = composeFrame(pet(), frame: 3, nowMillis: refNoon).toAscii();
      expect(a, c);
    });
  });

  group('death', () {
    test('shows a grave and nothing else', () {
      final b = composeFrame(
        pet(dead: true, poops: const [1, 2, 3], isSick: true),
        frame: 0,
        nowMillis: refNoon,
      );
      final grave = LcdBuffer()
        ..blit(
          kSpriteRegistry['prop.grave']!.a,
          (kLcdWidth - kSpriteRegistry['prop.grave']!.a.width) ~/ 2,
          (kLcdHeight - kSpriteRegistry['prop.grave']!.a.height) ~/ 2,
        );
      expect(b.toAscii(), grave.toAscii());
    });

    test('does not animate — the pig is gone', () {
      final a = composeFrame(pet(dead: true), frame: 0, nowMillis: refNoon);
      final c = composeFrame(pet(dead: true), frame: 1, nowMillis: refNoon);
      expect(a.toAscii(), c.toAscii());
    });
  });

  group('poops', () {
    test('each one adds dots to the floor', () {
      final clean = litDots(composeFrame(pet(), frame: 0, nowMillis: refNoon));
      final dirty = litDots(
        composeFrame(pet(poops: const [1]), frame: 0, nowMillis: refNoon),
      );
      expect(dirty, greaterThan(clean));
    });

    test('more poops means more mess, up to the slots available', () {
      var previous = 0;
      for (var n = 0; n <= kPoopSlots.length; n++) {
        final dots = litDots(
          composeFrame(
            pet(poops: List.generate(n, (i) => i)),
            frame: 0,
            nowMillis: refNoon,
          ),
        );
        expect(dots, greaterThanOrEqualTo(previous), reason: '$n poops');
        previous = dots;
      }
    });

    test('the floor has a slot for every poop the simulation allows', () {
      // A shortfall here would hide mess the player is being judged on.
      expect(kPoopSlots.length, greaterThanOrEqualTo(kMaxPoops));
    });

    test('a full pen draws every poop it holds', () {
      final full = composeFrame(
        pet(poops: List.generate(kMaxPoops, (i) => i)),
        frame: 0,
        nowMillis: refNoon,
      );
      final empty = composeFrame(pet(), frame: 0, nowMillis: refNoon);
      final poopDots = kSpriteRegistry['prop.poop']!.a.rows.fold<int>(
        0,
        (n, r) => n + r.split('#').length - 1,
      );
      expect(litDots(full) - litDots(empty), poopDots * kMaxPoops);
    });

    test('more poops than slots does not overflow the display', () {
      final b = composeFrame(
        pet(poops: List.generate(20, (i) => i)),
        frame: 0,
        nowMillis: refNoon,
      );
      expect(b.toAscii().split('\n').length, kLcdHeight);
    });

    test('sits clear of the pig\'s feet', () {
      // The slots exist so a mess never lands on the animal. If the pig's
      // silhouette is redrawn wider, this is the test that complains.
      final withPoops = composeFrame(
        pet(poops: const [1, 2, 3, 4]),
        frame: 0,
        nowMillis: refNoon,
      );
      final without = composeFrame(pet(), frame: 0, nowMillis: refNoon);
      final poopDots = kSpriteRegistry['prop.poop']!.a.rows.fold<int>(
        0,
        (n, r) => n + r.split('#').length - 1,
      );
      expect(litDots(withPoops) - litDots(without), poopDots * 4);
    });
  });

  group('status icons', () {
    test('an idle sick pig says so with its face, not an icon', () {
      // The sick idle face already carries it; adding the icon would be the
      // display repeating itself.
      final sick = composeFrame(
        pet(isSick: true),
        frame: 0,
        nowMillis: refNoon,
      );
      final sickFace = LcdBuffer()
        ..blit(kSpriteRegistry['farmHog.sick']!.frame(0), 0, 0);
      expect(sick.toAscii(), sickFace.toAscii());
    });

    test('a sleeping sick pig gets the icon, since its eyes are shut', () {
      final night = refNoon + 11 * _hour;
      final sick = litDots(
        composeFrame(pet(isSick: true), frame: 0, nowMillis: night),
      );
      final well = litDots(composeFrame(pet(), frame: 0, nowMillis: night));
      expect(sick, greaterThan(well));
    });

    test('the attention indicator blinks rather than sitting there', () {
      // Compared against a pig in the *same* mood whose need only just
      // bottomed out, so the faces are identical and the only possible
      // difference is the indicator.
      final tick = refNoon ~/ kTickMillis;
      final calling = pet(
        comfort: 0,
        needZeroSinceTick: {'comfort': tick - kTicksAtZeroForCalling},
      );
      final quiet = pet(comfort: 0, needZeroSinceTick: {'comfort': tick});

      expect(
        litDots(composeFrame(calling, frame: 0, nowMillis: refNoon)),
        greaterThan(litDots(composeFrame(quiet, frame: 0, nowMillis: refNoon))),
        reason: 'indicator missing on the lit frame',
      );
      expect(
        litDots(composeFrame(calling, frame: 1, nowMillis: refNoon)),
        litDots(composeFrame(quiet, frame: 1, nowMillis: refNoon)),
        reason: 'indicator did not blink off',
      );
    });

    test('the pen light being off is visible', () {
      final lit = litDots(composeFrame(pet(), frame: 0, nowMillis: refNoon));
      final dark = litDots(
        composeFrame(pet(lightsOn: false), frame: 0, nowMillis: refNoon),
      );
      expect(dark, greaterThan(lit));
    });
  });

  group('life stage', () {
    test('an egg renders as an egg', () {
      final b = composeFrame(
        pet(stage: Stage.egg, form: Form.base),
        frame: 0,
        nowMillis: refNoon,
      );
      final egg = LcdBuffer()..blit(kSpriteRegistry['egg']!.frame(0), 0, 0);
      expect(b.toAscii(), egg.toAscii());
    });

    test('the three adult builds compose to different frames', () {
      final frames = {
        for (final form in [Form.prizeHog, Form.farmHog, Form.runt])
          form: composeFrame(
            pet(form: form),
            frame: 0,
            nowMillis: refNoon,
          ).toAscii(),
      };
      expect(frames.values.toSet().length, 3);
    });

    test('a piglet and an adult compose to different frames', () {
      final piglet = composeFrame(
        pet(stage: Stage.piglet, form: Form.base),
        frame: 0,
        nowMillis: refNoon,
      ).toAscii();
      final adult = composeFrame(pet(), frame: 0, nowMillis: refNoon).toAscii();
      expect(piglet, isNot(adult));
    });
  });

  group('golden frames', () {
    test('a content adult at noon', () {
      // comfort 40 sits between the sad and happy thresholds.
      expect(
        composeFrame(pet(comfort: 40), frame: 0, nowMillis: refNoon).toAscii(),
        [
          '.........###.......###..........',
          '........#...#######...#.........',
          '........#..##.....##..#.........',
          '.........##.........##..........',
          '.........#..#......#.#..........',
          '........#..##.....##..#.........',
          '........#....#####....#.........',
          '........#...#.....#...#.........',
          '........#...#.#.#.#...#.........',
          '........#...#.....#...#.........',
          '.........#...#####...#..........',
          '.........#...........#..........',
          '..........#.........#...........',
          '..........#.........#...........',
          '..........#..#####..#...........',
          '..........####...####...........',
        ].join('\n'),
      );
    });

    test('a filthy pig with a full floor', () {
      final ascii = composeFrame(
        pet(poops: const [1, 2, 3, 4]),
        frame: 0,
        nowMillis: refNoon,
      ).toAscii().split('\n');
      // Four poops, two either side, clear of the pig.
      expect(ascii[12], '...#....#.#.........#...#....#..');
      expect(ascii[13], '..###..####.........#..###..###.');
      expect(ascii[15], '.####.########...####.####.####.');
    });
  });
}
