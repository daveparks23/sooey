import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hog_sim/hog_sim.dart';

import '../lcd/lcd_buffer.dart';
import '../sprites/sprite_registry.dart';
import 'clock.dart';
import 'game_constants.dart';
import 'screens/crest_screen.dart';
import 'screens/death_screen.dart';
import 'screens/device_screen.dart';
import 'screens/home_screen.dart';

/// One pig, one clock, one stack of screens.
///
/// **The only thing in the client that mutates the pet.** Screens turn a press
/// into an intent and the controller decides what that does — which is what
/// lets a screen be tested with a string of presses and nothing else.
///
/// Nothing here is persisted. A pet vanishes on reload, deliberately: M4 is
/// about landing the input machine before the network arrives in M5.
class GameController extends ChangeNotifier {
  GameController({this._clock = const SystemClock(), int? utcOffsetMinutes})
    : _utcOffsetMinutes =
          utcOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes {
    _restart();
  }

  final Clock _clock;
  final int _utcOffsetMinutes;

  late PetState _pet;
  late Crest _crest;
  late List<DeviceScreen> _stack;

  int _frame = 0;
  PetPose? _transientPose;
  int _transientUntilMillis = 0;
  DeviceIcon? _blinkingIcon;
  int _blinkUntilMillis = 0;
  Timer? _timer;

  PetState get pet => _pet;
  Crest get crest => _crest;
  int get frame => _frame;
  DeviceScreen get screen => _stack.last;
  DeviceIcon? get litIcon => screen.litIcon;

  /// The icon a refused action is blinking, or null. Expires on its own so no
  /// one has to remember to clear it.
  DeviceIcon? get blinkingIcon =>
      _clock.nowMillis < _blinkUntilMillis ? _blinkingIcon : null;

  GameContext get context => GameContext(
    pet: _pet,
    crest: _crest,
    nowMillis: _clock.nowMillis,
    transientPose: _clock.nowMillis < _transientUntilMillis
        ? _transientPose
        : null,
  );

  LcdBuffer compose() => screen.compose(context, _frame);

  /// Starts the animation timer. Tests drive [tick] by hand instead.
  void start() {
    _timer ??= Timer.periodic(
      const Duration(milliseconds: kAnimFrameMillis),
      (_) => tick(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// One animation frame: advance the simulation, then let the top screen move.
  ///
  /// `advance` is cheap to call this often — it steps in whole five-minute
  /// ticks and does nothing until one has elapsed.
  void tick() {
    _frame++;
    _pet = advance(_pet, _clock.nowMillis);

    if (_pet.isDead) {
      if (_stack.last is! DeathScreen) _stack = [DeathScreen()];
    } else {
      _apply(screen.update(context));
    }
    notifyListeners();
  }

  void press(Button b) {
    _apply(screen.handle(b, context));
    notifyListeners();
  }

  void _apply(Transition t) {
    switch (t) {
      case Stay():
        break;

      case Push(screen: final next):
        _stack.add(next);

      case Pop():
        _popIfNested();

      case Act(:final action):
        // Captured before the pop, because it names the icon that refused.
        final icon = screen.litIcon;
        final outcome = applyAction(_pet, action, _clock.nowMillis);
        _pet = outcome.state;
        if (outcome.accepted) {
          _showPoseFor(action);
        } else {
          _blink(icon);
        }
        _popIfNested();

      case Played(:final wins):
        final outcome = applyMinigame(
          _pet,
          wins: wins,
          rounds: kPlayRounds,
          nowMillis: _clock.nowMillis,
        );
        _pet = outcome.state;
        if (!outcome.accepted) _blink(DeviceIcon.play);
        _popIfNested();

      case Crested(:final crest):
        _crest = crest;
        _stack = [HomeScreen()];

      case Restart():
        _restart();
    }
  }

  /// Home is the root and has nothing behind it, so a pop from there is a
  /// no-op rather than an empty stack.
  void _popIfNested() {
    if (_stack.length > 1) _stack.removeLast();
  }

  /// Lets the player see the action land. Cleaning, medicating and the light
  /// have no pose of their own — the poops vanishing is the feedback.
  void _showPoseFor(PetAction action) {
    final pose = switch (action) {
      PetAction.slop || PetAction.treat => PetPose.eating,
      PetAction.wallow => PetPose.wallowing,
      PetAction.clean || PetAction.meds || PetAction.light => null,
    };
    if (pose == null) return;
    _transientPose = pose;
    _transientUntilMillis = _clock.nowMillis + kTransientPoseMillis;
  }

  void _blink(DeviceIcon? icon) {
    if (icon == null) return;
    _blinkingIcon = icon;
    _blinkUntilMillis = _clock.nowMillis + kRefusalBlinkMillis;
  }

  void _restart() {
    _pet = PetState.newborn(
      petId: 'pet_local',
      ownerId: 'uid_local',
      // The pig has a crest instead of a name. `name` stays in the model
      // because M5's Firestore schema wants it; nothing displays it.
      name: '',
      nowMillis: _clock.nowMillis,
      utcOffsetMinutes: _utcOffsetMinutes,
    );
    _crest = Crest.values.first;
    _stack = [CrestScreen()];
    _transientPose = null;
    _transientUntilMillis = 0;
    _blinkingIcon = null;
    _blinkUntilMillis = 0;
  }
}
