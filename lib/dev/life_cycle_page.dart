import 'dart:async';

import 'package:flutter/material.dart' hide Form;
import 'package:hog_sim/hog_sim.dart';

import '../device/device_shell.dart';
import '../game/clock.dart';
import '../game/game_controller.dart';
import '../sprites/sprite_registry.dart';
import 'care_bot.dart';
import 'reference_clock.dart';

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
  ///
  /// 10800x was here and was removed. Even with the press budget scaled to
  /// simulated time it produced a farm hog from the sloppy preset where both
  /// remaining speeds produce a runt: a frame there is 21.6 simulated ticks,
  /// which is too coarse for the 35/60 rescue hysteresis the sloppy plan runs
  /// on — the bot cannot see the floor it meant to stop at. A speed chip that
  /// silently changes which animal you get is worse than a slower run.
  /// Restoring it means decoupling the bot's press cadence from the animation
  /// frame, so it can act between simulated ticks rather than once per frame.
  static const List<int> _speeds = [600, 3600];

  late FakeClock _clock;
  late GameController _controller;
  late CareBot _bot;

  Timer? _timer;
  int _speed = 3600;
  CarePreset _preset = CarePreset.attentive;

  /// Off by default, and the full-life tests pin the same setting.
  ///
  /// The hunt returns up to 25 enrichment in one visit against a treat's 10,
  /// so a run that plays it re-drains for far longer, fits fewer lapse cycles
  /// into childhood, and lands short of the mistakes the preset came for —
  /// measured, sloppy gives a farm hog with the hunt on and a runt with it
  /// off. It is a switch rather than a deletion because watching the pig play
  /// is half the reason there is a device to watch.
  bool _playsHunt = false;

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
    // Pinned rather than DateTime.now(): the bot's sleep/light policy and the
    // sloppy preset's rescue hysteresis are phase-sensitive, so which adult a
    // run produces can depend on the time of day it started. See kRefNoon's
    // doc comment and "The start phase matters for sloppy care" in
    // life-cycle-harness-design.md.
    _clock = FakeClock(kRefNoon);
    _controller = GameController(clock: _clock, utcOffsetMinutes: 0);
    _bot = CareBot(_preset, playsHunt: _playsHunt);
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
      // Presses per frame, scaled so the bot's care throughput per simulated
      // minute is the same at every speed the page offers.
      final budget = botPressBudget(_speed);
      for (var i = 0; i < budget; i++) {
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
        // Not `pet.careMistakes`: the branch happens inside a frame that may
        // have advanced several simulated ticks, and mistakes can still land
        // after it. `decidingMistakes` reads the count back out of the
        // lifespan the branch stamped, which is exact at any frame size.
        _note(
          'grew up into ${pet.form.name} on '
          '${decidingMistakes(pet)} mistakes',
        );
      }
      _lastStage = pet.stage;
    }
    if (pet.isSick && !_wasSick) _note('fell ill');
    _wasSick = pet.isSick;

    if (pet.isDead && !_loggedDeath) {
      _loggedDeath = true;
      final days = (pet.diedAtMillis! - pet.bornAtMillis) / 86400000;
      _note(
        'died of ${pet.deathCause?.name} at '
        '${days.toStringAsFixed(1)} days',
      );
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
                          // neither preset would own, so it starts over — but
                          // onSelected also fires when the chip that is
                          // already lit is tapped again, and throwing away a
                          // run in progress for that is a nasty surprise.
                          onSelected: (_) {
                            if (_preset == preset) return;
                            setState(() {
                              _preset = preset;
                              _reset();
                            });
                          },
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
                          // No reset: with the press budget scaled to
                          // simulated time both speeds raise the same adult,
                          // so this is a viewing control and changing it
                          // mid-run is safe.
                          onSelected: (_) {
                            if (_speed == speed) return;
                            setState(() => _speed = speed);
                          },
                        ),
                    ],
                  ),
                  // The hunt is not scenery: it buys far more enrichment per
                  // visit than a treat, which changes how many mistakes fit
                  // into childhood and therefore which adult the preset
                  // produces. So switching it starts a new pig, for the same
                  // reason changing the preset does.
                  CheckboxListTile(
                    value: _playsHunt,
                    onChanged: (on) => setState(() {
                      _playsHunt = on ?? false;
                      _reset();
                    }),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'play the truffle hunt (changes the adult you get)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
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
                        Text(
                          '${pet.stage.name}/${pet.form.name}  '
                          'age ${_ageLabel()}',
                        ),
                        const Text(
                          "clock pinned to noon UTC, not this machine's time",
                        ),
                        Text(
                          'health ${pet.health.toStringAsFixed(0)}  '
                          'mistakes ${pet.careMistakes}'
                          '${_bot.neglecting ? '  LAPSING' : ''}',
                        ),
                        Text(
                          'full ${pet.fullness.toStringAsFixed(0)}  '
                          'enrich ${pet.enrichment.toStringAsFixed(0)}  '
                          'comfort ${pet.comfort.toStringAsFixed(0)}  '
                          'clean ${pet.cleanliness.toStringAsFixed(0)}',
                        ),
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
