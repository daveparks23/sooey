import 'dart:async';

import 'package:flutter/material.dart' hide Form;
import 'package:hog_sim/hog_sim.dart';

import '../device/device_shell.dart';
import '../game/clock.dart';
import '../game/game_controller.dart';
import '../sprites/sprite_registry.dart';
import 'care_bot.dart';

/// Dev-only: a whole life, played by a bot, on a clock you can wind.
///
/// The device widget is the same one `/` mounts and has no idea it is being
/// driven. `/dev/device` is still there for hand-driving; this page is for
/// watching an arc nobody has the patience to play at 1x.
class LifeCyclePage extends StatefulWidget {
  const LifeCyclePage({super.key});

  @override
  State<LifeCyclePage> createState() => _LifeCyclePageState();
}

class _LifeCyclePageState extends State<LifeCyclePage> {
  /// 1x and 60x are missing on purpose: a life at 60x is eight hours.
  static const List<int> _speeds = [600, 3600, 10800];

  late FakeClock _clock;
  late GameController _controller;
  late CareBot _bot;

  Timer? _timer;
  int _speed = 3600;
  CarePreset _preset = CarePreset.attentive;
  final List<String> _log = [];

  Stage _lastStage = Stage.egg;
  bool _wasSick = false;
  bool _loggedDeath = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _running => _timer != null;

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _clock = FakeClock(DateTime.now().millisecondsSinceEpoch);
    _controller = GameController(clock: _clock, utcOffsetMinutes: 0);
    _bot = CareBot(_preset);
    _log.clear();
    _lastStage = Stage.egg;
    _wasSick = false;
    _loggedDeath = false;
  }

  void _toggleRun() {
    setState(() {
      if (_running) {
        _timer!.cancel();
        _timer = null;
      } else {
        _timer = Timer.periodic(
          const Duration(milliseconds: kAnimFrameMillis),
          (_) => _frame(),
        );
      }
    });
  }

  void _frame() {
    _clock.advance(kAnimFrameMillis * _speed);
    _controller.tick();
    _record();

    if (!_controller.pet.isDead) {
      for (var i = 0; i < kBotPressBudget; i++) {
        final button = _bot.nextPress(_controller);
        if (button == null) break;
        _controller.press(button);
      }
    }
    setState(() {});
  }

  /// Turns the things worth remembering into log lines as they happen.
  void _record() {
    final pet = _controller.pet;
    if (pet.stage != _lastStage) {
      if (pet.stage == Stage.piglet) {
        _note('hatched');
      } else if (pet.stage == Stage.adult) {
        // stageCareMistakes is zeroed by the same tick that fixes the form, so
        // the count that decided it has to come from careMistakes — which is
        // equal to it here, the egg stage having contributed none.
        _note('grew up into ${pet.form.name} on ${pet.careMistakes} mistakes');
      }
      _lastStage = pet.stage;
    }
    if (pet.isSick && !_wasSick) _note('fell ill');
    _wasSick = pet.isSick;

    if (pet.isDead && !_loggedDeath) {
      _loggedDeath = true;
      final days = (pet.diedAtMillis! - pet.bornAtMillis) / 86400000;
      _note('died of ${pet.deathCause?.name} at '
          '${days.toStringAsFixed(1)} days');
      _timer?.cancel();
      _timer = null;
    }
  }

  void _note(String what) => _log.add('${_ageLabel()}  $what');

  String _ageLabel() {
    final minutes = (_clock.nowMillis - _controller.pet.bornAtMillis) ~/ 60000;
    return '${(minutes ~/ 1440).toString().padLeft(2)}d'
        '${((minutes % 1440) ~/ 60).toString().padLeft(2, '0')}h';
  }

  @override
  Widget build(BuildContext context) {
    final pet = _controller.pet;

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(title: const Text('Life cycle (bot-driven)')),
      body: Row(
        children: [
          Expanded(child: DeviceShell(controller: _controller)),
          SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final preset in CarePreset.values)
                        ChoiceChip(
                          label: Text(preset.name),
                          selected: _preset == preset,
                          // Changing care quality mid-life would produce a pig
                          // neither preset would own, so it starts over.
                          onSelected: (_) => setState(() {
                            _preset = preset;
                            _reset();
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final speed in _speeds)
                        ChoiceChip(
                          label: Text('${speed}x'),
                          selected: _speed == speed,
                          onSelected: (_) => setState(() => _speed = speed),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _toggleRun,
                        child: Text(_running ? 'Pause' : 'Start'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setState(_reset),
                        child: const Text('New pig'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // The mistake count lives out here on the plastic, never on
                  // the glass: the device is not allowed to show its judgment.
                  DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${pet.stage.name}/${pet.form.name}  '
                            'age ${_ageLabel()}'),
                        Text('health ${pet.health.toStringAsFixed(0)}  '
                            'mistakes ${pet.careMistakes}'
                            '${_bot.neglecting ? '  LAPSING' : ''}'),
                        Text('full ${pet.fullness.toStringAsFixed(0)}  '
                            'enrich ${pet.enrichment.toStringAsFixed(0)}  '
                            'comfort ${pet.comfort.toStringAsFixed(0)}  '
                            'clean ${pet.cleanliness.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final line in _log)
                          Text(
                            line,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
