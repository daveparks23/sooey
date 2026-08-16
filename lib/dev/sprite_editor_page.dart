import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../lcd/lcd.dart';
import '../sprites/sprite_registry.dart';

/// A 32x16 grid editor that emits ready-to-paste Dart literals.
///
/// Dev-only, and worth every line: the spec calls for thirty-odd hand-authored
/// sprites, and iterating on them as string arrays in a source file is
/// miserable. Two frames sit side by side with a live 600ms preview, because at
/// this resolution the *motion* carries the character — a sprite that reads
/// beautifully as a still can look completely dead once it animates.
class SpriteEditorPage extends StatefulWidget {
  const SpriteEditorPage({super.key});

  @override
  State<SpriteEditorPage> createState() => _SpriteEditorPageState();
}

enum _Tool { on, off, transparent }

class _SpriteEditorPageState extends State<SpriteEditorPage>
    with SingleTickerProviderStateMixin {
  /// Two frames of char codes, [frame][y][x].
  late List<List<List<int>>> _frames;
  int _editing = 0;
  _Tool _tool = _Tool.on;
  String? _loadedName;

  late final Ticker _ticker;
  int _previewFrame = 0;

  @override
  void initState() {
    super.initState();
    _frames = [_blank(), _blank()];
    _ticker = Ticker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Duration _lastFlip = Duration.zero;
  void _onTick(Duration elapsed) {
    if (elapsed - _lastFlip < const Duration(milliseconds: kAnimFrameMillis)) {
      return;
    }
    _lastFlip = elapsed;
    setState(() => _previewFrame ^= 1);
  }

  static List<List<int>> _blank() => List.generate(
    kLcdHeight,
    (_) => List<int>.filled(kLcdWidth, LcdSprite.off),
  );

  LcdSprite _spriteOf(int frame) => LcdSprite(kLcdWidth, kLcdHeight, [
    for (final row in _frames[frame]) String.fromCharCodes(row),
  ]);

  void _paint(Offset local, double cell) {
    final x = (local.dx / cell).floor();
    final y = (local.dy / cell).floor();
    if (x < 0 || x >= kLcdWidth || y < 0 || y >= kLcdHeight) return;
    final code = switch (_tool) {
      _Tool.on => LcdSprite.on,
      _Tool.off => LcdSprite.off,
      _Tool.transparent => LcdSprite.transparent,
    };
    if (_frames[_editing][y][x] == code) return;
    setState(() => _frames[_editing][y][x] = code);
  }

  void _load(String name) {
    final anim = kSpriteRegistry[name];
    if (anim == null) return;
    setState(() {
      _loadedName = name;
      _frames = [
        [for (final r in anim.a.rows) r.codeUnits.toList()],
        [for (final r in anim.b.rows) r.codeUnits.toList()],
      ];
    });
  }

  /// Nudges the whole frame, which is how the second frame of an idle pair
  /// almost always starts: the same body, dropped a row.
  void _shift(int dx, int dy) {
    setState(() {
      final src = _frames[_editing];
      final out = _blank();
      for (var y = 0; y < kLcdHeight; y++) {
        for (var x = 0; x < kLcdWidth; x++) {
          final ny = y + dy, nx = x + dx;
          if (ny < 0 || ny >= kLcdHeight || nx < 0 || nx >= kLcdWidth) continue;
          out[ny][nx] = src[y][x];
        }
      }
      _frames[_editing] = out;
    });
  }

  String _asDart() {
    final base = _loadedName ?? 'kNewSprite';
    final buffer = StringBuffer();
    for (var f = 0; f < 2; f++) {
      buffer.writeln('const $base${f + 1} = LcdSprite($kLcdWidth, $kLcdHeight, [');
      for (final row in _frames[f]) {
        buffer.writeln("  '${String.fromCharCodes(row)}',");
      }
      buffer.writeln(']);');
      if (f == 0) buffer.writeln();
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final preview = LcdBuffer()..blit(_spriteOf(_previewFrame), 0, 0);

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(
        title: Text('Sprite editor${_loadedName == null ? '' : ' — $_loadedName'}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Load a sprite',
            onSelected: _load,
            itemBuilder: (_) => [
              for (final name in kSpriteRegistry.keys)
                PopupMenuItem(value: name, child: Text(name)),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text('Load')),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          final grid = _buildGrid();
          final side = _buildSidebar(preview);
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: grid),
                    SizedBox(width: 320, child: side),
                  ],
                )
              : ListView(children: [SizedBox(height: 400, child: grid), side]);
        },
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell =
              (constraints.maxWidth / kLcdWidth)
                  .clamp(4.0, constraints.maxHeight / kLcdHeight)
                  .floorToDouble();
          final w = cell * kLcdWidth;
          final h = cell * kLcdHeight;
          return Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTapDown: (d) => _paint(d.localPosition, cell),
              onPanUpdate: (d) => _paint(d.localPosition, cell),
              child: CustomPaint(
                size: Size(w, h),
                painter: _GridPainter(_frames[_editing], cell),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(LcdBuffer preview) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Editing', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Frame 1')),
              ButtonSegment(value: 1, label: Text('Frame 2')),
            ],
            selected: {_editing},
            onSelectionChanged: (s) => setState(() => _editing = s.first),
          ),
          const SizedBox(height: 12),
          const Text('Brush', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          SegmentedButton<_Tool>(
            segments: const [
              ButtonSegment(value: _Tool.on, label: Text('#')),
              ButtonSegment(value: _Tool.off, label: Text('.')),
              ButtonSegment(value: _Tool.transparent, label: Text('␣')),
            ],
            selected: {_tool},
            onSelectionChanged: (s) => setState(() => _tool = s.first),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: () => _shift(0, -1), child: const Text('↑')),
              OutlinedButton(onPressed: () => _shift(0, 1), child: const Text('↓')),
              OutlinedButton(onPressed: () => _shift(-1, 0), child: const Text('←')),
              OutlinedButton(onPressed: () => _shift(1, 0), child: const Text('→')),
              OutlinedButton(
                onPressed: () => setState(
                  () => _frames[1] = [
                    for (final r in _frames[0]) [...r],
                  ],
                ),
                child: const Text('1→2'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _frames[_editing] = _blank()),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Preview (600ms)',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 140,
            child: LcdScreen(buffer: preview, frame: _previewFrame),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _asDart()));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied as Dart')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy as Dart'),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            padding: const EdgeInsets.all(8),
            color: Colors.black26,
            child: SingleChildScrollView(
              child: SelectableText(
                _asDart(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.cells, this.cell);

  final List<List<int>> cells;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final on = Paint()..color = LcdTheme.dotOn;
    final off = Paint()..color = LcdTheme.dotOff;
    // Transparent cells are drawn as a dark hatch so they are obviously not
    // "off" — confusing the two is the easiest way to author a broken overlay.
    final clear = Paint()..color = const Color(0xFF3A4030);
    final grid = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(Offset.zero & size, Paint()..color = LcdTheme.screen);

    for (var y = 0; y < kLcdHeight; y++) {
      for (var x = 0; x < kLcdWidth; x++) {
        final rect = Rect.fromLTWH(x * cell, y * cell, cell - 1, cell - 1);
        canvas.drawRect(rect, switch (cells[y][x]) {
          LcdSprite.on => on,
          LcdSprite.off => off,
          _ => clear,
        });
      }
    }

    // Guides every 8 columns and at the vertical centre, which is most of how
    // you keep a creature centred without counting dots.
    for (var x = 0; x <= kLcdWidth; x += 8) {
      canvas.drawLine(Offset(x * cell, 0), Offset(x * cell, size.height), grid);
    }
    for (var y = 0; y <= kLcdHeight; y += 8) {
      canvas.drawLine(Offset(0, y * cell), Offset(size.width, y * cell), grid);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
