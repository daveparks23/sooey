/// Deterministic 32-bit randomness for the tick simulation.
///
/// The simulation runs in three places — the Dart VM under test, dart2js on the
/// server, and the Flutter web client — and all three must agree exactly. Two
/// properties of Dart make that harder than it looks:
///
///   * `String.hashCode` is not guaranteed identical across those runtimes, so
///     [stableHash] replaces it.
///   * Dart ints are 64-bit on the VM but IEEE-754 doubles under dart2js, where
///     only integers below 2^53 are exact. Any product of two 32-bit values can
///     reach 2^64, so masking *after* a plain `*` is already too late — the
///     precision is gone. [_mul32] does the multiply in 16-bit halves so the
///     intermediate products stay well inside 2^53.
library;

/// Multiplies two 32-bit values, returning the low 32 bits.
///
/// Equivalent to JavaScript's `Math.imul` for unsigned inputs. The largest
/// intermediate is `0xFFFF * 0xFFFFFFFF` (~2.8e14), comfortably below 2^53.
int _mul32(int a, int b) {
  final aLo = a & 0xFFFF;
  final aHi = (a >>> 16) & 0xFFFF;
  return (aLo * b + (((aHi * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
}

/// FNV-1a, 32-bit. Stable across every Dart runtime, unlike `String.hashCode`.
int stableHash(String s) {
  var h = 0x811C9DC5;
  for (var i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)) & 0xFFFFFFFF;
    h = _mul32(h, 0x01000193);
  }
  return h;
}

/// The 32-bit SplitMix finalizer. Scatters sequential seeds into uncorrelated
/// output, which matters because tick indices are consecutive.
int splitmix32(int seed) {
  var x = (seed + 0x9E3779B9) & 0xFFFFFFFF;
  x = _mul32(x ^ (x >>> 16), 0x21F0AAAD);
  x = _mul32(x ^ (x >>> 15), 0x735A2D97);
  return (x ^ (x >>> 15)) & 0xFFFFFFFF;
}

/// The seed for a single tick of a single pet.
///
/// Used for the sickness roll and nothing else. Minigame randomness is
/// interactive, happens outside the tick loop, and is not seeded from here.
int tickSeed(String petId, int tickIndex) => splitmix32(
  (stableHash(petId) ^ _mul32(tickIndex, 0x9E3779B9)) & 0xFFFFFFFF,
);

/// Maps a 32-bit value onto `[0, 1)`.
double unitDouble(int seed) => (seed & 0xFFFFFFFF) / 4294967296.0;
