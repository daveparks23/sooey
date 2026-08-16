import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/pet_appearance.dart';
import 'package:sooey/sprites/sprite_registry.dart';

/// 2025-08-12T12:00:00Z — noon UTC, so a pet at offset 0 is awake.
const refNoon = 1755000000000;
const _hour = 3600000;

PetState pet({
  Stage stage = Stage.adult,
  Form form = Form.farmHog,
  double fullness = 80,
  double enrichment = 80,
  double comfort = 80,
  double cleanliness = 80,
  bool isSick = false,
  int careMistakes = 0,
  int stageCareMistakes = 0,
  Map<String, int> needZeroSinceTick = const {},
  int utcOffsetMinutes = 0,
}) =>
    PetState.newborn(
      petId: 'pet_test',
      ownerId: 'uid_1',
      name: 'Wilbur',
      nowMillis: refNoon - 7 * 24 * _hour,
      utcOffsetMinutes: utcOffsetMinutes,
    ).copyWith(
      stage: stage,
      form: form,
      lastTickAtMillis: refNoon,
      fullness: fullness,
      enrichment: enrichment,
      comfort: comfort,
      cleanliness: cleanliness,
      isSick: isSick,
      careMistakes: careMistakes,
      stageCareMistakes: stageCareMistakes,
      needZeroSinceTick: needZeroSinceTick,
    );

void main() {
  group('moodFor', () {
    test('a well-kept pig is happy', () {
      expect(moodFor(pet()), PetMood.happy);
    });

    test('a pig with a bottomed-out need is sad', () {
      expect(moodFor(pet(comfort: 0)), PetMood.sad);
    });

    test('an ill pig looks ill regardless of its needs', () {
      expect(moodFor(pet(isSick: true)), PetMood.sick);
      expect(moodFor(pet(isSick: true, comfort: 0)), PetMood.sick);
    });

    test('a middling pig is merely content', () {
      expect(moodFor(pet(comfort: 40)), PetMood.content);
    });

    test('the lowest need decides, not the average', () {
      // Three needs full and one on the floor is a distressed pig, even though
      // the average looks fine.
      expect(
        moodFor(
          pet(fullness: 100, enrichment: 100, cleanliness: 100, comfort: 5),
        ),
        PetMood.sad,
      );
    });

    // --- the rule that protects the game's premise --------------------------

    test('care mistakes never reach the pig\'s face', () {
      // The adult form branches on these counts and the player is never told.
      // A face that reflected them would leak the entire hidden judgment, so
      // two pigs identical but for their history must look identical.
      final innocent = pet(careMistakes: 0, stageCareMistakes: 0);
      final wretched = pet(careMistakes: 99, stageCareMistakes: 99);
      expect(moodFor(wretched), moodFor(innocent));
    });

    test('mood is blind to care history at every need level', () {
      for (final need in [0.0, 10.0, 50.0, 90.0, 100.0]) {
        final clean = moodFor(pet(comfort: need));
        final dirty = moodFor(
          pet(comfort: need, careMistakes: 40, stageCareMistakes: 40),
        );
        expect(dirty, clean, reason: 'diverged at comfort $need');
      }
    });

    test('the adult form never changes the mood', () {
      // The player must not be able to infer their pig's build from its face
      // any earlier than the build itself is visible.
      for (final form in [Form.prizeHog, Form.farmHog, Form.runt]) {
        expect(moodFor(pet(form: form, comfort: 0)), PetMood.sad);
        expect(moodFor(pet(form: form)), PetMood.happy);
      }
    });
  });

  group('poseFor', () {
    test('an awake pig with nothing happening is idle', () {
      expect(poseFor(pet(), nowMillis: refNoon), PetPose.idle);
    });

    test('a pig inside its sleep window is asleep', () {
      // refNoon is 12:00, so 23:00 is eleven hours later.
      expect(poseFor(pet(), nowMillis: refNoon + 11 * _hour), PetPose.sleeping);
    });

    test('an action outranks sleep, because a fed pig is eating', () {
      expect(
        poseFor(
          pet(),
          transient: PetPose.eating,
          nowMillis: refNoon + 11 * _hour,
        ),
        PetPose.eating,
      );
    });

    test('follows the pet\'s own timezone', () {
      // 23:00 UTC is 18:00 in UTC-5 — still awake there.
      expect(
        poseFor(pet(utcOffsetMinutes: -300), nowMillis: refNoon + 11 * _hour),
        PetPose.idle,
      );
    });
  });

  group('isCallingForAttention', () {
    int tickAt(int millis) => millis ~/ kTickMillis;

    test('stays quiet for a need that only just bottomed out', () {
      final p = pet(
        comfort: 0,
        needZeroSinceTick: {'comfort': tickAt(refNoon) - 1},
      );
      expect(isCallingForAttention(p, nowMillis: refNoon), isFalse);
    });

    test('calls once a need has been at zero long enough', () {
      final p = pet(
        comfort: 0,
        needZeroSinceTick: {
          'comfort': tickAt(refNoon) - kTicksAtZeroForCalling,
        },
      );
      expect(isCallingForAttention(p, nowMillis: refNoon), isTrue);
    });

    test('an egg never calls', () {
      final p = pet(
        stage: Stage.egg,
        needZeroSinceTick: {'comfort': tickAt(refNoon) - 100},
      );
      expect(isCallingForAttention(p, nowMillis: refNoon), isFalse);
    });

    test('a dead pig never calls', () {
      final p = pet(
        needZeroSinceTick: {'comfort': tickAt(refNoon) - 100},
      ).copyWith(diedAtMillis: refNoon - 1000, deathCause: DeathCause.neglect);
      expect(isCallingForAttention(p, nowMillis: refNoon), isFalse);
    });
  });

  group('creatureAnim', () {
    test('renders mood only through the idle pose', () {
      for (final mood in PetMood.values) {
        final sleeping = creatureAnim(
          stage: Stage.adult,
          form: Form.farmHog,
          pose: PetPose.sleeping,
          mood: mood,
        );
        expect(
          identical(sleeping, kSpriteRegistry['farmHog.sleeping']),
          isTrue,
          reason: '$mood changed the sleeping sprite',
        );
      }
    });

    test('gives every mood its own idle face', () {
      final faces = {
        for (final mood in PetMood.values)
          mood: creatureAnim(
            stage: Stage.adult,
            form: Form.farmHog,
            pose: PetPose.idle,
            mood: mood,
          ).a.rows.join(),
      };
      expect(faces.values.toSet().length, PetMood.values.length);
    });

    test('covers every build, pose and mood without falling back', () {
      for (final stage in [Stage.piglet, Stage.adult]) {
        for (final form in Form.values) {
          for (final pose in PetPose.values) {
            for (final mood in PetMood.values) {
              final anim = creatureAnim(
                stage: stage,
                form: form,
                pose: pose,
                mood: mood,
              );
              expect(
                anim.a.rows.any((r) => r.contains('#')),
                isTrue,
                reason: '${stage.name}/${form.name}/${pose.name}/${mood.name}',
              );
            }
          }
        }
      }
    });

    test('an egg looks like an egg whatever is asked of it', () {
      for (final pose in PetPose.values) {
        for (final mood in PetMood.values) {
          expect(
            identical(
              creatureAnim(
                stage: Stage.egg,
                form: Form.base,
                pose: pose,
                mood: mood,
              ),
              kSpriteRegistry['egg'],
            ),
            isTrue,
          );
        }
      }
    });
  });
}
