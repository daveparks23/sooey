#!/usr/bin/env bash
#
# Compiles packages/hog_sim to JavaScript for the Cloud Functions runtime.
#
# The simulation is written once, in Dart. The client imports the package
# directly; the server runs this compiled bundle. One implementation, so the
# optimistic UI and the authority cannot drift.
#
# Output is gitignored — run `npm run build` (which calls this) after changing
# anything under packages/hog_sim.
set -euo pipefail

FUNCTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$FUNCTIONS_DIR/.." && pwd)"
SIM_DIR="$REPO_ROOT/packages/hog_sim"
OUT_DIR="$FUNCTIONS_DIR/generated"
OUT="$OUT_DIR/hog_sim.js"

if ! command -v dart >/dev/null 2>&1; then
  echo "error: the Dart SDK is required to build the simulation bundle." >&2
  echo "       install it, or run 'flutter doctor' if Flutter is set up." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# Resolve the package's own dependencies; it is not part of the app's lockfile.
(cd "$SIM_DIR" && dart pub get --no-precompile >/dev/null)

dart compile js \
  -O2 \
  --no-source-maps \
  -o "$OUT" \
  "$SIM_DIR/tool/js_entry.dart"

# dart2js emits a self-invoking bundle that installs `globalThis.hogSim`. Node
# needs a CommonJS handle on it; nothing else about the output requires
# patching, and current dart2js output has no `self` references to shim.
printf '\nmodule.exports = globalThis.hogSim;\n' >>"$OUT"

# dart2js leaves a dependency manifest next to the output.
rm -f "$OUT.deps"

echo "built $(basename "$OUT") ($(wc -c <"$OUT" | tr -d ' ') bytes)"
