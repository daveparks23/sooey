import 'dart:async';

import 'package:flutter/material.dart';

import '../lcd/lcd.dart';
import '../sprites/sprite_registry.dart';

/// Every sprite in the game, animating at the real 600ms cadence.
///
/// Dev-only, and the fastest way to judge whether the cast reads: a sprite that
/// looks fine as a still can be completely dead in motion, and the only way to
/// know is to watch the whole set side by side.
class SpriteGalleryPage extends StatefulWidget {
  const SpriteGalleryPage({super.key});

  @override
  State<SpriteGalleryPage> createState() => _SpriteGalleryPageState();
}

class _SpriteGalleryPageState extends State<SpriteGalleryPage> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: kAnimFrameMillis),
      (_) => setState(() => _frame++),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = kSpriteRegistry.entries.toList();
    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(
        title: const Text('Sprite gallery'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'frame ${_frame.isEven ? 1 : 2}',
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          childAspectRatio: 1.5,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          final sprite = entry.value.frame(_frame);
          // Small props are centred on the display so they are not marooned in
          // the top-left corner at a size nobody can judge.
          final dx = (kLcdWidth - sprite.width) ~/ 2;
          final dy = (kLcdHeight - sprite.height) ~/ 2;
          final buffer = LcdBuffer()..blit(sprite, dx, dy);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: LcdScreen(buffer: buffer, frame: _frame)),
              const SizedBox(height: 4),
              Text(
                entry.key,
                style: TextStyle(
                  color: entry.value.isStill ? Colors.white38 : Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
