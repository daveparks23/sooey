import 'dart:async';

import 'package:flutter/material.dart' hide Form;

import '../device/device_shell.dart';
import '../game/clock.dart';
import '../game/game_controller.dart';
import '../sprites/sprite_registry.dart';

/// Dev-only: the real device, on a clock you can wind.
///
/// The shell has no idea it is being faked — it is the same widget `/` mounts.
/// This is the only way to see the long arcs by hand: fifteen minutes of egg is
/// fifteen seconds at 60x, seventy-two hours of childhood is seventy-two
/// seconds at 3600x, and a death by neglect is about two minutes.
///
/// M5 replaces the fake clock with the real debug clock.
class DeviceDevPage extends StatefulWidget {
  const DeviceDevPage({super.key});

  @override
  State<DeviceDevPage> createState() => _DeviceDevPageState();
}

class _DeviceDevPageState extends State<DeviceDevPage> {
  static const List<int> _speeds = [1, 60, 600, 3600];

  late final FakeClock _clock;
  late final GameController _controller;
  Timer? _timer;
  int _speed = 1;

  @override
  void initState() {
    super.initState();
    _clock = FakeClock(DateTime.now().millisecondsSinceEpoch);
    _controller = GameController(clock: _clock, utcOffsetMinutes: 0);
    // Drives both the fake clock and the controller, so a speed multiplier is
    // simply a bigger step per frame.
    _timer = Timer.periodic(const Duration(milliseconds: kAnimFrameMillis), (
      _,
    ) {
      _clock.advance(kAnimFrameMillis * _speed);
      _controller.tick();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _jump(int millis) {
    _clock.advance(millis);
    _controller.tick();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pet = _controller.pet;
    final ageMinutes = (_clock.nowMillis - pet.bornAtMillis) ~/ 60000;
    final localHour =
        ((_clock.nowMillis + pet.utcOffsetMinutes * 60000) ~/ 3600000) % 24;

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(title: const Text('Device (fake clock)')),
      body: Column(
        children: [
          Expanded(child: DeviceShell(controller: _controller)),
          Container(
            color: const Color(0xFF2A2A2A),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '${pet.stage.name}/${pet.form.name} · '
                  'age ${ageMinutes ~/ 60}h${ageMinutes % 60}m · '
                  'local ${localHour.toString().padLeft(2, '0')}:00'
                  '${pet.isDead ? ' · DEAD ${pet.deathCause?.name}' : ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in _speeds)
                      ChoiceChip(
                        label: Text('${s}x'),
                        selected: _speed == s,
                        onSelected: (_) => setState(() => _speed = s),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (label, millis) in const [
                      ('+5m', 5 * 60 * 1000),
                      ('+1h', 60 * 60 * 1000),
                      ('+6h', 6 * 60 * 60 * 1000),
                      ('+24h', 24 * 60 * 60 * 1000),
                    ])
                      OutlinedButton(
                        onPressed: () => _jump(millis),
                        child: Text(label),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
