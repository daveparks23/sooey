import 'package:hog_sim/hog_sim.dart';
import 'package:test/test.dart';

const _bornAt = 1755000000000; // 2025-08-12T12:00:00Z, an arbitrary fixed clock

PetState _newborn() => PetState.newborn(
  petId: 'pet_abc',
  ownerId: 'uid_1',
  name: 'Wilbur',
  nowMillis: _bornAt,
  utcOffsetMinutes: -300,
);

void main() {
  group('newborn', () {
    test('starts as an egg with every need full', () {
      final p = _newborn();
      expect(p.stage, Stage.egg);
      expect(p.form, Form.base);
      expect(p.fullness, 100);
      expect(p.enrichment, 100);
      expect(p.comfort, 100);
      expect(p.cleanliness, 100);
      expect(p.health, 100);
      expect(p.isSick, isFalse);
      expect(p.isDead, isFalse);
    });

    test('anchors the simulation cursor to its birth', () {
      final p = _newborn();
      expect(p.bornAtMillis, _bornAt);
      expect(p.lastTickAtMillis, _bornAt);
    });

    test('carries no care history', () {
      final p = _newborn();
      expect(p.careMistakes, 0);
      expect(p.stageCareMistakes, 0);
      expect(p.poops, isEmpty);
      expect(p.pendingPoopTicks, isEmpty);
      expect(p.needZeroSinceTick, isEmpty);
    });

    test('truncates names to the 12 character limit', () {
      final p = PetState.newborn(
        petId: 'pet_abc',
        ownerId: 'uid_1',
        name: 'Bartholomew Cornelius',
        nowMillis: _bornAt,
        utcOffsetMinutes: 0,
      );
      expect(p.name, 'Bartholomew ');
      expect(p.name.length, 12);
    });
  });

  group('JSON', () {
    test('round-trips every field unchanged', () {
      final original = _newborn().copyWith(
        stage: Stage.adult,
        form: Form.runt,
        fullness: 42.5,
        enrichment: 3.25,
        comfort: 0,
        cleanliness: 88.125,
        health: 17.75,
        weight: 63.5,
        discipline: 55,
        isSick: true,
        sickSinceTick: 5900123,
        lightsOn: false,
        poops: const [5900100, 5900130],
        pendingPoopTicks: const [5900160],
        needZeroSinceTick: const {'comfort': 5900111},
        careMistakes: 7,
        stageCareMistakes: 3,
        lastPlayedAtMillis: _bornAt + 60000,
        diedAtMillis: _bornAt + 120000,
        deathCause: DeathCause.starvation,
      );

      final restored = PetState.fromJson(original.toJson());

      expect(restored, original);
    });

    test('round-trips a pet that is still alive', () {
      final original = _newborn();
      expect(PetState.fromJson(original.toJson()), original);
    });

    test('emits only plain JSON types', () {
      // The dart2js bridge marshals this map as a JSON string, so anything that
      // is not a num, String, bool, List, Map or null would fail at the Node
      // boundary rather than here. Catch it here instead.
      void assertPlain(Object? value, String path) {
        if (value == null || value is num || value is String || value is bool) {
          return;
        }
        if (value is List) {
          for (var i = 0; i < value.length; i++) {
            assertPlain(value[i], '$path[$i]');
          }
          return;
        }
        if (value is Map) {
          value.forEach((k, v) {
            expect(k, isA<String>(), reason: 'non-string key at $path');
            assertPlain(v, '$path.$k');
          });
          return;
        }
        fail('$path is ${value.runtimeType}, which is not JSON-encodable');
      }

      assertPlain(_newborn().toJson(), 'root');
    });

    test('survives an encode/decode cycle through actual JSON text', () {
      final original = _newborn().copyWith(poops: const [1, 2, 3]);
      final text = jsonEncodeState(original);
      expect(jsonDecodeState(text), original);
    });
  });

  group('isDead', () {
    test('is false while diedAt is unset', () {
      expect(_newborn().isDead, isFalse);
    });

    test('is true once diedAt is set', () {
      final dead = _newborn().copyWith(
        diedAtMillis: _bornAt + 1000,
        deathCause: DeathCause.neglect,
      );
      expect(dead.isDead, isTrue);
    });
  });
}
