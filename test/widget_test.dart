import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sooey/device/device_shell.dart';
import 'package:sooey/main.dart';

void main() {
  testWidgets('boots to the device, not to the dev menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    await tester.pumpWidget(const HogPocketApp());

    expect(find.byType(DeviceShell), findsOneWidget);
    expect(
      find.text('Sprite gallery'),
      findsNothing,
      reason: 'the scaffolding should be behind /dev now',
    );

    // DevicePage runs an animation timer; unmount it so the test does not end
    // with one pending.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
  });
}
