import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../lcd/lcd.dart';
import '../sprites/sprite_registry.dart';

/// A grid editor that emits ready-to-paste Dart literals.
///
/// Dev-only, and worth every line: the spec calls for thirty-odd hand-authored
/// sprites, and iterating on them as string arrays in a source file is
/// miserable. Two frames sit side by side with a live 600ms preview, because at
/// this resolution the *motion* carries the character — a sprite that reads
/// beautifully as a still can look completely dead once it animates.
///
/// The canvas follows the loaded sprite's own size rather than always being
/// 32x16, so the small props (the 4x4 poop, the status icons) can be edited
/// here too.
class SpriteEditorPage extends StatefulWidget {
  const SpriteEditorPage({super.key});

  @override
  State<SpriteEditorPage> createState() => _SpriteEditorPageState();
}

enum _Tool { on, off, transparent }

class _SpriteEditorPageState extends State<SpriteEditorPage> {
  /// Two frames of char codes, `[frame][y][x]`.
  late List<List<List<int>>> _frames;
  int _width = kLcdWidth;
  int _height = kLcdHeight;

  int _editing = 0;
  _Tool _tool = _Tool.on;
  String? _loadedName;
  bool _still = false;

  late final Ticker _ticker;
  int _previewFrame = 0;
  Duration _lastFlip = Duration.zero;

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

  void _onTick(Duration elapsed) {
    if (elapsed - _lastFlip < const Duration(milliseconds: kAnimFrameMillis)) {
      return;
    }
    _lastFlip = elapsed;
    setState(() => _previewFrame ^= 1);
  }

  List<List<int>> _blank() =>
      List.generate(_height, (_) => List<int>.filled(_width, LcdSprite.off));

  LcdSprite _spriteOf(int frame) => LcdSprite(_width, _height, [
    for (final row in _frames[frame]) String.fromCharCodes(row),
  ]);

  void _paint(Offset local, double cell) {
    final x = (local.dx / cell).floor();
    final y = (local.dy / cell).floor();
    if (x < 0 || x >= _width || y < 0 || y >= _height) return;
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
      _still = anim.isStill;
      _width = anim.a.width;
      _height = anim.a.height;
      _editing = 0;
      _frames = [
        [for (final r in anim.a.rows) r.codeUnits.toList()],
        [for (final r in anim.b.rows) r.codeUnits.toList()],
      ];
    });
  }

  void _newSprite() {
    setState(() {
      _loadedName = null;
      _still = false;
      _width = kLcdWidth;
      _height = kLcdHeight;
      _editing = 0;
      _frames = [_blank(), _blank()];
    });
  }

  /// Nudges the whole frame, which is how the second frame of an idle pair
  /// almost always starts: the same body, dropped a row.
  void _shift(int dx, int dy) {
    setState(() {
      final src = _frames[_editing];
      final out = _blank();
      for (var y = 0; y < _height; y++) {
        for (var x = 0; x < _width; x++) {
          final ny = y + dy, nx = x + dx;
          if (ny < 0 || ny >= _height || nx < 0 || nx >= _width) continue;
          out[ny][nx] = src[y][x];
        }
      }
      _frames[_editing] = out;
    });
  }

  /// Emits the sprite as Dart you can paste straight over the existing literal.
  ///
  /// The constant name comes from the registry rather than the display key —
  /// naming it after the key would produce `runt.eating1`, which is not a
  /// valid identifier.
  String _asDart() {
    final anim = _loadedName == null ? null : kSpriteRegistry[_loadedName];
    final base = anim?.dartName ?? 'kNewSprite';
    final buffer = StringBuffer();

    if (anim?.sourceFile != null) {
      final target = _still ? base : '${base}1 / ${base}2';
      buffer.writeln('// Paste over $target in ${anim!.sourceFile}');
    }

    final frameCount = _still ? 1 : 2;
    for (var f = 0; f < frameCount; f++) {
      final name = _still ? base : '$base${f + 1}';
      buffer.writeln('const $name = LcdSprite($_width, $_height, [');
      for (final row in _frames[f]) {
        buffer.writeln("  '${String.fromCharCodes(row)}',");
      }
      buffer.writeln(']);');
      if (f == 0 && frameCount > 1) buffer.writeln();
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Small props are centred so they are not marooned in the corner at a size
    // nobody can judge.
    final sprite = _spriteOf(_still ? 0 : _previewFrame);
    final preview = LcdBuffer()
      ..blit(
        sprite,
        (kLcdWidth - sprite.width) ~/ 2,
        (kLcdHeight - sprite.height) ~/ 2,
      );

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(
        title: Text(
          'Sprite editor${_loadedName == null ? '' : ' — $_loadedName'}',
        ),
        actions: [
          TextButton(onPressed: _newSprite, child: const Text('New')),
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
                    SizedBox(
                      width: 340,
                      child: SingleChildScrollView(child: side),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    SizedBox(height: 400, child: grid),
                    side,
                  ],
                );
        },
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = (constraints.maxWidth / _width)
              .clamp(4.0, constraints.maxHeight / _height)
              .floorToDouble();
          return Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTapDown: (d) => _paint(d.localPosition, cell),
              onPanUpdate: (d) => _paint(d.localPosition, cell),
              child: CustomPaint(
                size: Size(cell * _width, cell * _height),
                painter: _GridPainter(_frames[_editing], cell, _width, _height),
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
          Text(
            '$_width x $_height${_still ? '  (still)' : ''}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (!_still) ...[
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
          ],
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
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _shift(0, -1),
                child: const Text('↑'),
              ),
              OutlinedButton(
                onPressed: () => _shift(0, 1),
                child: const Text('↓'),
              ),
              OutlinedButton(
                onPressed: () => _shift(-1, 0),
                child: const Text('←'),
              ),
              OutlinedButton(
                onPressed: () => _shift(1, 0),
                child: const Text('→'),
              ),
              if (!_still)
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
          Text(
            _still ? 'Preview' : 'Preview (600ms)',
            style: const TextStyle(color: Colors.white70),
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied as Dart')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy as Dart'),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
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
  _GridPainter(this.cells, this.cell, this.width, this.height);

  final List<List<int>> cells;
  final double cell;
  final int width;
  final int height;

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

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final rect = Rect.fromLTWH(x * cell, y * cell, cell - 1, cell - 1);
        canvas.drawRect(rect, switch (cells[y][x]) {
          LcdSprite.on => on,
          LcdSprite.off => off,
          _ => clear,
        });
      }
    }

    // Guides every 8 cells: most of how you keep a creature centred without
    // counting dots.
    for (var x = 0; x <= width; x += 8) {
      canvas.drawLine(Offset(x * cell, 0), Offset(x * cell, size.height), grid);
    }
    for (var y = 0; y <= height; y += 8) {
      canvas.drawLine(Offset(0, y * cell), Offset(size.width, y * cell), grid);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
