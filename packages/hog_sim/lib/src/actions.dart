import 'constants.dart';
import 'pet_state.dart';

/// Everything the player can do from the icon row.
///
/// `train` is deliberately absent: the discipline mechanic is cut from v1 (D2),
/// though `PetState.discipline` survives so restoring it is not a migration.
enum PetAction { slop, treat, wallow, clean, meds, light }

/// Why an action did not apply. Refusals are feedback, not errors — a pig that
/// turns down a fifth bucket of slop is telling the player something.
enum ActionRefusal { notHungry, cooldown, invalid, dead, notHatched }

class ActionOutcome {
  const ActionOutcome.accepted(this.state) : accepted = true, refusal = null;

  const ActionOutcome.refused(this.state, this.refusal) : accepted = false;

  /// The post-action state, or the state untouched if the action was refused.
  final PetState state;
  final bool accepted;
  final ActionRefusal? refusal;
}

/// Applies one player action. Pure — the caller advances the simulation to
/// [nowMillis] first, then applies this on top.
ActionOutcome applyAction(PetState s, PetAction action, int nowMillis) {
  if (s.isDead) return ActionOutcome.refused(s, ActionRefusal.dead);

  // An egg has no mouth, no mud and no mess. Only the pen light works.
  if (s.stage == Stage.egg && action != PetAction.light) {
    return ActionOutcome.refused(s, ActionRefusal.notHatched);
  }

  switch (action) {
    case PetAction.slop:
      if (s.fullness > kSlopRefusedAbove) {
        return ActionOutcome.refused(s, ActionRefusal.notHungry);
      }
      return ActionOutcome.accepted(
        s.copyWith(
          fullness: _clamp(s.fullness + kSlopFullness, 0, 100),
          weight: _clamp(s.weight + kWeightPerMeal, kWeightMin, kWeightMax),
          pendingPoopTicks: [
            ...s.pendingPoopTicks,
            nowMillis ~/ kTickMillis + kTicksUntilPoop,
          ],
        ),
      );

    case PetAction.treat:
      return ActionOutcome.accepted(
        s.copyWith(
          fullness: _clamp(s.fullness + kTreatFullness, 0, 100),
          enrichment: _clamp(s.enrichment + kTreatEnrichment, 0, 100),
          weight: _clamp(s.weight + kWeightPerTreat, kWeightMin, kWeightMax),
        ),
      );

    // Correct pig care that immediately creates work for the player. This
    // tension is the game.
    case PetAction.wallow:
      return ActionOutcome.accepted(
        s.copyWith(
          comfort: 100,
          cleanliness: _clamp(s.cleanliness - kWallowCleanlinessCost, 0, 100),
        ),
      );

    case PetAction.clean:
      return ActionOutcome.accepted(
        s.copyWith(poops: const [], cleanliness: 100),
      );

    case PetAction.meds:
      if (!s.isSick) {
        // Medicating a healthy animal is itself a care mistake.
        return ActionOutcome.accepted(
          s.copyWith(health: _clamp(s.health - kMedsHealthPenalty, 0, 100)),
        );
      }
      return ActionOutcome.accepted(
        s.copyWith(isSick: false, sickSinceTick: null),
      );

    case PetAction.light:
      return ActionOutcome.accepted(s.copyWith(lightsOn: !s.lightsOn));
  }
}

/// Applies the result of a truffle hunt.
///
/// The minigame itself is resolved client-side for responsiveness; this only
/// validates the shape of the result and the cooldown. Making it cheat-proof is
/// not worth the complexity — the stakes are a few points of enrichment.
ActionOutcome applyMinigame(
  PetState s, {
  required int wins,
  required int rounds,
  required int nowMillis,
}) {
  if (s.isDead) return ActionOutcome.refused(s, ActionRefusal.dead);
  if (s.stage == Stage.egg) {
    return ActionOutcome.refused(s, ActionRefusal.notHatched);
  }
  if (rounds != kPlayRounds || wins < 0 || wins > rounds) {
    return ActionOutcome.refused(s, ActionRefusal.invalid);
  }

  final last = s.lastPlayedAtMillis;
  if (last != null && nowMillis - last < kPlayCooldownMillis) {
    return ActionOutcome.refused(s, ActionRefusal.cooldown);
  }

  final gain = switch (wins) {
    >= 4 => kPlayEnrichmentHigh,
    >= 2 => kPlayEnrichmentMid,
    _ => kPlayEnrichmentLow,
  };

  return ActionOutcome.accepted(
    s.copyWith(
      enrichment: _clamp(s.enrichment + gain, 0, 100),
      weight: _clamp(s.weight + kWeightPerPlay, kWeightMin, kWeightMax),
      lastPlayedAtMillis: nowMillis,
    ),
  );
}

/// Wire format for an action result. Shared by the golden vectors and the JS
/// bridge so the two cannot describe the same outcome differently.
Map<String, Object?> actionOutcomeToJson(ActionOutcome o) => {
  'accepted': o.accepted,
  'refusal': o.refusal?.name,
  'state': o.state.toJson(),
};

double _clamp(double v, double lo, double hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}
