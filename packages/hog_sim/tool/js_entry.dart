/// dart2js entry point: exposes the simulation to Node as `globalThis.hogSim`.
///
/// Compiled by `functions/scripts/build-sim.sh` into
/// `functions/generated/hog_sim.js`, where the TypeScript Cloud Functions
/// consume it. The Functions layer holds no game logic at all — it verifies
/// auth, reads the pet, calls in here, and writes the result back.
///
/// The contract is deliberately strings in, strings out. Marshalling only JSON
/// text across the boundary avoids every structured-clone and prototype
/// question that richer interop would raise, and costs an encode/decode that is
/// noise next to a Firestore round trip.
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:hog_sim/hog_sim.dart';

String _advanceJson(String stateJson, double nowMillis) =>
    jsonEncodeState(advance(jsonDecodeState(stateJson), nowMillis.toInt()));

String _applyActionJson(String stateJson, String action, double nowMillis) {
  final outcome = applyAction(
    jsonDecodeState(stateJson),
    _actionByName(action),
    nowMillis.toInt(),
  );
  return jsonEncode(actionOutcomeToJson(outcome));
}

String _applyMinigameJson(
  String stateJson,
  double wins,
  double rounds,
  double nowMillis,
) {
  final outcome = applyMinigame(
    jsonDecodeState(stateJson),
    wins: wins.toInt(),
    rounds: rounds.toInt(),
    nowMillis: nowMillis.toInt(),
  );
  return jsonEncode(actionOutcomeToJson(outcome));
}

String _newPetJson(
  String petId,
  String ownerId,
  String name,
  double nowMillis,
  double utcOffsetMinutes,
) => jsonEncodeState(
  PetState.newborn(
    petId: petId,
    ownerId: ownerId,
    name: name,
    nowMillis: nowMillis.toInt(),
    utcOffsetMinutes: utcOffsetMinutes.toInt(),
  ),
);

PetAction _actionByName(String name) {
  for (final a in PetAction.values) {
    if (a.name == name) return a;
  }
  throw ArgumentError('unknown action: $name');
}

void main() {
  final exports = JSObject();
  exports.setProperty('advanceJson'.toJS, _advanceJson.toJS);
  exports.setProperty('applyActionJson'.toJS, _applyActionJson.toJS);
  exports.setProperty('applyMinigameJson'.toJS, _applyMinigameJson.toJS);
  exports.setProperty('newPetJson'.toJS, _newPetJson.toJS);
  globalContext.setProperty('hogSim'.toJS, exports);
}
