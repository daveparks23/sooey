import 'dart:async';

// `Form` is hog_sim's adult build here, not Flutter's form widget.
import 'package:flutter/material.dart' hide Form;
import 'package:hog_sim/hog_sim.dart';

import '../game/frame_composer.dart';
import '../game/pet_appearance.dart';
import '../lcd/lcd.dart';
import '../sprites/sprite_registry.dart';

/// Dev-only: drives the real composer from a pet you can poke at.
///
/// This is the first place the pieces meet — simulation state on one side, dots
/// on the other — so it is also the fastest way to catch a state the display
/// handles badly before the device UI exists to find it for you.
class PetPreviewPage extends StatefulWidget {
  const PetPreviewPage({super.key});

  @override
  State<PetPreviewPage> createState() => _PetPreviewPageState();
}

class _PetPreviewPageState extends State<PetPreviewPage> {
  static const _refNoon = 1755000000000;

  Timer? _timer;
  int _frame = 0;

  Stage _stage = Stage.adult;
  Form _form = Form.farmHog;
  double _lowestNeed = 80;
  bool _isSick = false;
  bool _lightsOn = true;
  bool _asleep = false;
  bool _calling = false;
  bool _dead = false;
  int _poops = 0;
  PetPose? _transient;

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

  int get _nowMillis => _asleep ? _refNoon + 11 * 3600000 : _refNoon;

  PetState get _pet {
    final tick = _nowMillis ~/ kTickMillis;
    var p =
        PetState.newborn(
          petId: 'pet_preview',
          ownerId: 'uid_dev',
          name: 'Wilbur',
          nowMillis: _refNoon - 7 * 24 * 3600000,
          utcOffsetMinutes: 0,
        ).copyWith(
          stage: _stage,
          form: _form,
          lastTickAtMillis: _nowMillis,
          comfort: _lowestNeed,
          isSick: _isSick,
          lightsOn: _lightsOn,
          poops: List.generate(_poops, (i) => i),
          needZeroSinceTick: _calling
              ? {'comfort': tick - kTicksAtZeroForCalling}
              : const {},
        );
    if (_dead) {
      p = p.copyWith(
        diedAtMillis: _nowMillis - 1000,
        deathCause: DeathCause.neglect,
      );
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    final buffer = composeFrame(
      pet,
      frame: _frame,
      nowMillis: _nowMillis,
      transientPose: _transient,
    );
    final pose = poseFor(pet, transient: _transient, nowMillis: _nowMillis);
    final mood = moodFor(pet);

    return Scaffold(
      backgroundColor: const Color(0xFF2A2A2A),
      appBar: AppBar(title: const Text('Pet preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 260,
            child: LcdScreen(buffer: buffer, frame: _frame),
          ),
          const SizedBox(height: 8),
          Text(
            _dead
                ? 'dead — ${pet.deathCause?.name}'
                : '${buildKey(stage: _stage, form: _form)} · '
                      '${pose.name} · ${mood.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
            ),
          ),
          const Divider(height: 32),
          _label('Stage'),
          SegmentedButton<Stage>(
            segments: const [
              ButtonSegment(value: Stage.egg, label: Text('egg')),
              ButtonSegment(value: Stage.piglet, label: Text('piglet')),
              ButtonSegment(value: Stage.adult, label: Text('adult')),
            ],
            selected: {_stage},
            onSelectionChanged: (s) => setState(() => _stage = s.first),
          ),
          const SizedBox(height: 12),
          _label('Adult build'),
          SegmentedButton<Form>(
            segments: const [
              ButtonSegment(value: Form.prizeHog, label: Text('prize')),
              ButtonSegment(value: Form.farmHog, label: Text('farm')),
              ButtonSegment(value: Form.runt, label: Text('runt')),
            ],
            selected: {_form},
            onSelectionChanged: (s) => setState(() => _form = s.first),
          ),
          const SizedBox(height: 12),
          _label('Lowest need — ${_lowestNeed.round()} (mood follows this)'),
          Slider(
            value: _lowestNeed,
            max: 100,
            divisions: 20,
            onChanged: (v) => setState(() => _lowestNeed = v),
          ),
          // Bounded by the simulation, not by taste: `advance` caps a pen at
          // kMaxPoops, so offering more here would preview a state the game
          // can never produce.
          _label('Poops on the floor — $_poops of $kMaxPoops'),
          Slider(
            value: _poops.toDouble(),
            max: kMaxPoops.toDouble(),
            divisions: kMaxPoops,
            onChanged: (v) => setState(() => _poops = v.round()),
          ),
          const SizedBox(height: 8),
          _label('Action pose'),
          SegmentedButton<PetPose?>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: PetPose.eating, label: Text('eating')),
              ButtonSegment(value: PetPose.wallowing, label: Text('wallowing')),
            ],
            selected: {if (_transient != null) _transient},
            onSelectionChanged: (s) =>
                setState(() => _transient = s.isEmpty ? null : s.first),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              _toggle('sick', _isSick, (v) => _isSick = v),
              _toggle('asleep (23:00)', _asleep, (v) => _asleep = v),
              _toggle('calling', _calling, (v) => _calling = v),
              _toggle('lights on', _lightsOn, (v) => _lightsOn = v),
              _toggle('dead', _dead, (v) => _dead = v),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(color: Colors.white70)),
  );

  Widget _toggle(String label, bool value, void Function(bool) set) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Switch(value: value, onChanged: (v) => setState(() => set(v))),
      Text(label, style: const TextStyle(color: Colors.white70)),
    ],
  );
}
