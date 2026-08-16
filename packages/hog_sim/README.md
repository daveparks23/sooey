# hog_sim

The Hog Pocket tick simulation. Pure Dart — no Flutter, no Firebase, no
platform libraries.

This package runs in three places:

| Where | How | Role |
| --- | --- | --- |
| `dart test` | Dart VM | the reference implementation |
| Cloud Functions | `dart compile js` → Node | the authority |
| Flutter web client | dart2js / wasm | optimistic UI |

All three must produce **byte-identical** output. If they diverge, the client's
prediction disagrees with the server and the pig visibly snaps to a different
state on every sync.

## Determinism rules

Two properties of Dart make cross-runtime agreement harder than it looks. Both
have bitten this code already; the probes are recorded below so nobody has to
rediscover them.

### 1. Never use `hashCode`

`String.hashCode` is not stable across runtimes. Measured on this machine:

| Expression | Dart VM | dart2js |
| --- | --- | --- |
| `'pet_abc'.hashCode` | `1023914457` | `512388185` |

Use `stableHash()` (FNV-1a, pinned to the published test vectors) instead.

### 2. Mask every integer operation — and multiply through `_mul32`

Dart ints are 64-bit on the VM but IEEE-754 doubles under dart2js, where only
integers below 2^53 are exact. A product of two 32-bit values reaches 2^64, so
masking *after* a plain `*` is already too late — the precision is gone before
the mask runs:

```dart
h = (h * 0x01000193) & 0xFFFFFFFF;   // WRONG
```

That line passes on the VM and silently returns a value 4 too low under
dart2js. `rng.dart` does every multiply in 16-bit halves via `_mul32` so the
intermediates stay inside 2^53.

### 3. Times are integer milliseconds

No `DateTime` or `Duration` crosses the wire or lives in `PetState`. Millisecond
timestamps are ~1.7e12, comfortably exact under dart2js, and pass through the
Node bridge and Firestore without conversion.

## The golden vectors

`test/golden/vectors.json` holds 92 cases — an input state, a timestamp, and the
expected output — generated on the VM and replayed in Node against the compiled
bundle. They cover every stage, every adult form, every death cause, the sleep
boundary, poop overflow, care-mistake accrual, and twelve pet ids' worth of
sickness rolls.

```bash
dart run tool/emit_golden_vectors.dart   # regenerate (deliberately)
dart test                                # includes a staleness check
dart test -p chrome                      # same suite, compiled with dart2js
```

A diff in the vector file means the simulation's observable behaviour changed.
That is fine when intended and a bug when not.

## Deviations from the spec

Recorded here because they are decisions, not oversights.

**`advance` takes `int nowMillis`, not `DateTime`.** Keeps the JSON and the JS
bridge free of date conversion.

**Death causes are decided by priority, not by a 24-hour window.** The spec
asks for `starvation` when health hits zero *and* fullness has been zero for the
preceding 24 hours. That is unreachable: a single zeroed need drains 100 health
in 67 ticks (5.6 hours) at `kHealthLossPerZeroedNeed`, so no pig survives 288
ticks of starvation to qualify. The same applies to `illness`. Both causes would
be dead code and every death would report `neglect`. Implemented instead as:

```
health <= 0 and fullness == 0  -> starvation
health <= 0 and isSick         -> illness
health <= 0, otherwise         -> neglect
tick >= expiresAt              -> oldAge
```

which preserves the spec's row order and makes all four reachable. `neglect` now
means what it should: a pig that was fed but left hot, bored or filthy.

**Values the spec references but never defines** live under a marked heading in
`constants.dart`: the per-stage decay multipliers, the ideal weight bands, and
the egg not decaying. They are balance knobs — change them freely and regenerate
the vectors.
