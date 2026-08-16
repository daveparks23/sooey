import 'package:flutter/material.dart';

import 'dev/sprite_editor_page.dart';
import 'dev/sprite_gallery_page.dart';

void main() {
  runApp(const HogPocketApp());
}

/// Hog Pocket.
///
/// The home screen is the dev menu for now. M4 replaces it with the device
/// itself and moves these two behind a hidden route.
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
        '/': (_) => const DevMenuPage(),
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
