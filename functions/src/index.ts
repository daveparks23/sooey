/**
 * Hog Pocket Cloud Functions.
 *
 * This layer verifies auth, reads and writes Firestore, and nothing else. All
 * game logic lives in `packages/hog_sim` and reaches here through `./sim`,
 * compiled to JavaScript by `scripts/build-sim.sh`.
 *
 * The callables themselves land in M5; for now this file only re-exports the
 * simulation façade so the build and the conformance test have something to
 * hang off.
 */

import {setGlobalOptions} from "firebase-functions";

// Cost control: this workload is one invocation per player action, so a low
// ceiling is plenty and caps the damage from a runaway client.
setGlobalOptions({maxInstances: 10, region: "us-central1"});

export * from "./sim";
