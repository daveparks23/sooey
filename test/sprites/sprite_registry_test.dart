import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/lcd/lcd_buffer.dart';
import 'package:sooey/lcd/lcd_sprite.dart';
import 'package:sooey/sprites/sprite_registry.dart';

void main() {
  group('every sprite in the cast', () {
    test('is well formed', () {
      // Collect every failure rather than throwing at the first. The registry
      // is insertion-ordered and validate() throws, so aborting at the first
      // bad sprite silently stops checking everything registered after it —
      // which is most of the cast whenever one sprite is mid-redraw.
      final problems = <String>[];
      kSpriteRegistry.forEach((name, anim) {
        for (final (i, sprite) in [anim.a, anim.b].indexed) {
          try {
            sprite.validate('$name frame ${i + 1}');
          } on ArgumentError catch (e) {
            problems.add('${e.message}');
          }
        }
      });
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('draws something', () {
      kSpriteRegistry.forEach((name, anim) {
        for (final (i, sprite) in [anim.a, anim.b].indexed) {
          expect(
            sprite.rows.any((r) => r.contains('#')),
            isTrue,
            reason: '$name frame ${i + 1} is blank',
          );
        }
      });
    });

    test('fits the display', () {
      kSpriteRegistry.forEach((name, anim) {
        for (final sprite in [anim.a, anim.b]) {
          expect(sprite.width, lessThanOrEqualTo(kLcdWidth), reason: name);
          expect(sprite.height, lessThanOrEqualTo(kLcdHeight), reason: name);
        }
      });
    });
  });

  group('creature animations', () {
    test('move between their two frames', () {
      // A creature whose frames are identical is a pig that looks like a
      // rendering bug. Iterate the creatures rather than filtering the registry
      // by prefix, so adding icons or crests cannot quietly narrow this.
      for (final key in kCreatureKeys) {
        final anim = kSpriteRegistry[key]!;
        expect(
          anim.a.rows.join(),
          isNot(anim.b.rows.join()),
          reason: '$key does not animate',
        );
      }
    });

    test('keep the creature planted on the same floor line', () {
      // The lowest lit row must not jump between frames, or the pig appears to
      // hop rather than shift its weight. Wallowing is exempt: the mud is
      // supposed to slosh.
      int lowestLitRow(LcdSprite s) {
        for (var y = s.rows.length - 1; y >= 0; y--) {
          if (s.rows[y].contains('#')) return y;
        }
        return -1;
      }

      for (final key in kCreatureKeys) {
        if (key.endsWith('.wallowing')) continue;
        final anim = kSpriteRegistry[key]!;
        expect(
          lowestLitRow(anim.a),
          lowestLitRow(anim.b),
          reason: '$key shifts its floor line between frames',
        );
      }
    });

    test('alternate on the frame counter', () {
      const anim = SpriteAnim(kPigletFaceIdle1, kPigletFaceIdle2);
      expect(identical(anim.frame(0), kPigletFaceIdle1), isTrue);
      expect(identical(anim.frame(1), kPigletFaceIdle2), isTrue);
      expect(identical(anim.frame(2), kPigletFaceIdle1), isTrue);
    });
  });

  group('creatureAnim', () {
    test('covers every stage, form and pose', () {
      for (final stage in Stage.values) {
        for (final form in Form.values) {
          for (final pose in PetPose.values) {
            final anim = creatureAnim(stage: stage, form: form, pose: pose);
            expect(
              anim.a.rows.any((r) => r.contains('#')),
              isTrue,
              reason: '${stage.name}/${form.name}/${pose.name} is blank',
            );
          }
        }
      }
    });

    test('gives each adult form a distinct silhouette', () {
      // The player is never told which adult they got, so the three have to be
      // tellable apart at a glance or the hidden judgment lands on nothing.
      final shapes = {
        for (final form in [Form.prizeHog, Form.farmHog, Form.runt])
          form: creatureAnim(
            stage: Stage.adult,
            form: form,
            pose: PetPose.idle,
          ).a.rows.join(),
      };
      expect(shapes[Form.prizeHog], isNot(shapes[Form.farmHog]));
      expect(shapes[Form.farmHog], isNot(shapes[Form.runt]));
      expect(shapes[Form.prizeHog], isNot(shapes[Form.runt]));
    });

    test(
      'makes the prize hog visibly the biggest and the runt the smallest',
      () {
        int litDots(LcdSprite s) =>
            s.rows.fold(0, (n, r) => n + r.split('#').length - 1);

        int sizeOf(Form form) => litDots(
          creatureAnim(stage: Stage.adult, form: form, pose: PetPose.idle).a,
        );

        expect(sizeOf(Form.prizeHog), greaterThan(sizeOf(Form.farmHog)));
        expect(sizeOf(Form.farmHog), greaterThan(sizeOf(Form.runt)));
      },
    );

    test('grows the pig from piglet to adult', () {
      int litDots(LcdSprite s) =>
          s.rows.fold(0, (n, r) => n + r.split('#').length - 1);

      final piglet = litDots(
        creatureAnim(
          stage: Stage.piglet,
          form: Form.base,
          pose: PetPose.idle,
        ).a,
      );
      final adult = litDots(
        creatureAnim(
          stage: Stage.adult,
          form: Form.farmHog,
          pose: PetPose.idle,
        ).a,
      );

      expect(adult, greaterThan(piglet), reason: 'adult should outgrow piglet');
    });

    test('each build wallows in its own silhouette', () {
      // The mud stops at the chin, so the head — the only place the build is
      // expressed — stays in full view. Sharing one wallow would make a prize
      // hog and a runt identical at exactly the moment the player is watching
      // most closely.
      final wallows = {
        for (final build in kBuildKeys)
          build: kSpriteRegistry['$build.wallowing']!.a.rows.join(),
      };
      expect(
        wallows.values.toSet().length,
        wallows.length,
        reason: 'two builds share a wallow',
      );
    });

    test('every build covers every pose', () {
      for (final build in kBuildKeys) {
        for (final pose in kRequiredPoses) {
          expect(
            kSpriteRegistry.containsKey('$build.$pose'),
            isTrue,
            reason: '$build.$pose is missing',
          );
        }
      }
    });
  });
}
