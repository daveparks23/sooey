import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/game/screens/device_screen.dart';
import 'package:sooey/sprites/icon_sprites.dart';

void main() {
  group('the strip icons', () {
    test('cover every icon the cursor can reach', () {
      // A missing icon would be an invisible strip slot the player can still
      // select and press, which reads as a broken button.
      for (final icon in DeviceIcon.values) {
        expect(kDeviceIcons[icon], isNotNull, reason: icon.name);
      }
    });

    test('are all one size, so the strip is a grid rather than a jumble', () {
      for (final entry in kDeviceIcons.entries) {
        expect(entry.value.width, 7, reason: entry.key.name);
        expect(entry.value.height, 7, reason: entry.key.name);
      }
    });

    test('are well formed', () {
      kDeviceIcons.forEach((icon, sprite) => sprite.validate(icon.name));
      kTreatIcon.validate('kTreatIcon');
      kWeightIcon.validate('kWeightIcon');
    });

    test('are all distinguishable from one another', () {
      // Two icons that render identically make one of them unpressable in
      // practice: the player cannot tell which slot the cursor is on.
      final shapes = kDeviceIcons.values.map((s) => s.rows.join()).toSet();
      expect(shapes.length, kDeviceIcons.length);
    });

    test('each draw something', () {
      for (final entry in kDeviceIcons.entries) {
        expect(
          entry.value.rows.any((r) => r.contains('#')),
          isTrue,
          reason: '${entry.key.name} is blank',
        );
      }
    });
  });
}
