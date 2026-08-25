import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/sprites/crest_sprites.dart';

void main() {
  group('crests', () {
    test('cover every emblem the picker can land on', () {
      for (final crest in Crest.values) {
        expect(kCrests[crest], isNotNull, reason: crest.name);
      }
    });

    test('are 7x7, the size the death screen gutter allows', () {
      // Centred, a 16-wide grave leaves eight columns either side. A 9x9 crest
      // would not fit, which is why the picker shows them at this size too.
      for (final entry in kCrests.entries) {
        expect(entry.value.width, 7, reason: entry.key.name);
        expect(entry.value.height, 7, reason: entry.key.name);
      }
    });

    test('are all distinguishable', () {
      // The crest is what makes one pig yours. Two that render the same would
      // make the choice meaningless.
      final shapes = kCrests.values.map((s) => s.rows.join()).toSet();
      expect(shapes.length, kCrests.length);
    });

    test('are well formed', () {
      kCrests.forEach((crest, sprite) => sprite.validate(crest.name));
    });
  });

  group('rosettes', () {
    test('cover the three adult builds', () {
      for (final form in [Form.prizeHog, Form.farmHog, Form.runt]) {
        expect(kRosettes[form], isNotNull, reason: form.name);
      }
    });

    test('rank the builds by how much rosette there is', () {
      // The rosette replaces the text label Dave asked for, so it has to carry
      // the same ranking a caption would: a placing at a county show.
      int litDots(Form f) =>
          rosetteFor(f).rows.fold(0, (n, r) => n + r.split('#').length - 1);

      expect(litDots(Form.prizeHog), greaterThan(litDots(Form.farmHog)));
      expect(litDots(Form.farmHog), greaterThan(litDots(Form.runt)));
    });

    test('fall back to the farm hog for a form that never reaches adulthood', () {
      // `base` should never get here — the form is fixed at the piglet->adult
      // transition — but a pet seeded mid-development might, and a crash on the
      // stats page is a worse answer than the reference build.
      expect(rosetteFor(Form.base), kRosettes[Form.farmHog]);
    });

    test('are well formed and 7x7', () {
      kRosettes.forEach((form, sprite) {
        sprite.validate(form.name);
        expect(sprite.width, 7, reason: form.name);
        expect(sprite.height, 7, reason: form.name);
      });
    });
  });
}
