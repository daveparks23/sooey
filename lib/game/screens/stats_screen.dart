import 'package:hog_sim/hog_sim.dart';

import '../../lcd/lcd_bars.dart';
import '../../lcd/lcd_buffer.dart';
import '../../sprites/crest_sprites.dart';
import '../../sprites/icon_sprites.dart';
import '../../sprites/prop_sprites.dart';
import 'device_screen.dart';

const int _millisPerDay = 24 * 60 * 60 * 1000;

/// Four columns, one per need: a 7-wide bar over its own icon.
const int _columnPitch = 8;
const int _barHeight = 9;
const int _needIconY = 9;

/// The status pages.
///
/// Nothing here is written. A bar says how much, a pip says how many, and the
/// label under a bar is the icon you would press to fix it — which is a better
/// label than a word, because it also tells you what to do about it.
class StatsScreen extends DeviceScreen {
  static const int pageCount = 3;

  int page = 0;

  @override
  DeviceIcon? get litIcon => DeviceIcon.stats;

  @override
  Transition handle(Button b, GameContext ctx) {
    switch (b) {
      case Button.b:
        page = (page + 1) % pageCount;
        return const Stay();
      case Button.c:
        return const Pop();
      case Button.a:
        return const Stay();
    }
  }

  @override
  LcdBuffer compose(GameContext ctx, int frame) => switch (page) {
    0 => _needsPage(ctx),
    1 => _bodyPage(ctx),
    _ => _lifePage(ctx),
  };

  /// All four needs at once. Paging them would make the only useful thing —
  /// seeing which one is lowest — impossible.
  LcdBuffer _needsPage(GameContext ctx) {
    const icons = [
      kFeedIcon, // fullness
      kPlayIcon, // enrichment
      kWallowIcon, // comfort
      kCleanIcon, // cleanliness
    ];
    final buffer = LcdBuffer();
    for (var i = 0; i < kNeedNames.length; i++) {
      final x = i * _columnPitch;
      drawVerticalBar(
        buffer,
        x: x,
        y: 0,
        width: 7,
        height: _barHeight,
        fraction: ctx.pet.need(kNeedNames[i]) / 100,
      );
      buffer.blit(icons[i], x, _needIconY);
    }
    return buffer;
  }

  LcdBuffer _bodyPage(GameContext ctx) {
    final buffer = LcdBuffer()..blit(kHeart, 1, 1);
    drawHorizontalBar(
      buffer,
      x: 9,
      y: 1,
      width: 22,
      height: 5,
      fraction: ctx.pet.health / 100,
    );
    buffer.blit(kWeightIcon, 0, 9);
    drawHorizontalBar(
      buffer,
      x: 9,
      y: 10,
      width: 22,
      height: 5,
      fraction: (ctx.pet.weight - kWeightMin) / (kWeightMax - kWeightMin),
    );
    return buffer;
  }

  LcdBuffer _lifePage(GameContext ctx) {
    final buffer = LcdBuffer();
    final days = (ctx.nowMillis - ctx.pet.bornAtMillis) ~/ _millisPerDay;
    drawPips(buffer, count: days, x: 1, y: 0);

    // Only an adult has a build to show. A piglet has not been judged yet, and
    // the judging is the one thing the player must never watch happen.
    if (ctx.pet.stage == Stage.adult) {
      buffer.blit(rosetteFor(ctx.pet.form), 12, 9);
    }
    return buffer;
  }
}
