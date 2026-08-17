import 'package:flutter/material.dart';

import 'dev/device_dev_page.dart';
import 'dev/pet_preview_page.dart';
import 'dev/sprite_editor_page.dart';
import 'dev/sprite_gallery_page.dart';
import 'device/device_shell.dart';

void main() {
  runApp(const HogPocketApp());
}

/// Hog Pocket.
///
/// `/` is the device. Everything under `/dev` is scaffolding — the fake-clock
/// harness, the pet preview, the sprite gallery and the editor — and none of it
/// is reachable from the device itself.
class HogPocketApp extends StatelessWidget {
  const HogPocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hog Pocket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE3A6B5),
          brightness: Brightness.dark,
        ),
      ),
      routes: {
        '/': (_) => const DevicePage(),
        '/dev': (_) => const DevMenuPage(),
        '/dev/device': (_) => const DeviceDevPage(),
        '/dev/preview': (_) => const PetPreviewPage(),
        '/dev/sprites': (_) => const SpriteGalleryPage(),
        '/dev/editor': (_) => const SpriteEditorPage(),
      },
    );
  }
}

class DevMenuPage extends StatelessWidget {
  const DevMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hog Pocket',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/dev/device'),
              child: const Text('Device (fake clock)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/dev/preview'),
              child: const Text('Pet preview'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/dev/sprites'),
              child: const Text('Sprite gallery'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/dev/editor'),
              child: const Text('Sprite editor'),
            ),
          ],
        ),
      ),
    );
  }
}
