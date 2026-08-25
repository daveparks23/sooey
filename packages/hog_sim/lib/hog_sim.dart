/// The Hog Pocket tick simulation.
///
/// Pure Dart with no Flutter, Firebase, or platform dependencies, so the same
/// code can run in the client for optimistic UI and on the server as the
/// authority. See `README.md` in this package for the determinism rules that
/// keep those two in agreement.
library;

export 'src/actions.dart';
export 'src/advance.dart';
export 'src/constants.dart';
export 'src/pet_state.dart';
export 'src/stages.dart';
export 'src/rng.dart';
