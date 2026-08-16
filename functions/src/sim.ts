/**
 * Typed access to the Hog Pocket simulation.
 *
 * The simulation itself is written once, in Dart, under `packages/hog_sim`, and
 * compiled to `generated/hog_sim.js` by `scripts/build-sim.sh`. This module is
 * only a typed façade over that bundle.
 *
 * **No game logic belongs in this file, or anywhere else in TypeScript.** The
 * client runs the same Dart code for its optimistic UI, and a rule duplicated
 * here would be a rule that can drift. `test/sim.conformance.test.mjs` replays
 * 92 vectors generated on the Dart VM through this bundle to keep that honest.
 */

export type Stage = "egg" | "piglet" | "shoat" | "adult";
export type Form = "base" | "prizeHog" | "farmHog" | "runt";
export type DeathCause = "starvation" | "illness" | "neglect" | "oldAge";
export type PetActionName =
  | "slop"
  | "treat"
  | "wallow"
  | "clean"
  | "meds"
  | "light";
export type ActionRefusal =
  | "notHungry"
  | "cooldown"
  | "invalid"
  | "dead"
  | "notHatched";

/**
 * The complete state of one pig, exactly as the Dart model serialises it.
 *
 * Times are integer milliseconds since the epoch rather than Firestore
 * Timestamps — the conversion happens at the Firestore boundary, so the
 * simulation never has to know what a Timestamp is.
 */
export interface PetState {
  petId: string;
  ownerId: string;
  name: string;
  bornAtMillis: number;
  lastTickAtMillis: number;
  expiresAtMillis: number;
  utcOffsetMinutes: number;
  stage: Stage;
  form: Form;
  fullness: number;
  enrichment: number;
  comfort: number;
  cleanliness: number;
  health: number;
  weight: number;
  discipline: number;
  isSick: boolean;
  sickSinceTick: number | null;
  lightsOn: boolean;
  poops: number[];
  pendingPoopTicks: number[];
  needZeroSinceTick: Record<string, number>;
  careMistakes: number;
  stageCareMistakes: number;
  lastPlayedAtMillis: number | null;
  diedAtMillis: number | null;
  deathCause: DeathCause | null;
}

export interface ActionOutcome {
  accepted: boolean;
  /** Why the pig declined. A refusal is feedback, not an error. */
  refusal: ActionRefusal | null;
  /** The post-action state, or the state untouched if it was refused. */
  state: PetState;
}

interface HogSimBridge {
  advanceJson(stateJson: string, nowMillis: number): string;
  applyActionJson(
    stateJson: string,
    action: string,
    nowMillis: number
  ): string;
  applyMinigameJson(
    stateJson: string,
    wins: number,
    rounds: number,
    nowMillis: number
  ): string;
  newPetJson(
    petId: string,
    ownerId: string,
    name: string,
    nowMillis: number,
    utcOffsetMinutes: number
  ): string;
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const bridge: HogSimBridge = require("../generated/hog_sim.js");

/**
 * Steps the pig forward to `nowMillis`, or to its death, whichever comes first.
 * Every endpoint must call this before applying anything the player asked for.
 */
export function advance(state: PetState, nowMillis: number): PetState {
  return JSON.parse(bridge.advanceJson(JSON.stringify(state), nowMillis));
}

export function applyAction(
  state: PetState,
  action: PetActionName,
  nowMillis: number
): ActionOutcome {
  return JSON.parse(
    bridge.applyActionJson(JSON.stringify(state), action, nowMillis)
  );
}

export function applyMinigame(
  state: PetState,
  wins: number,
  rounds: number,
  nowMillis: number
): ActionOutcome {
  return JSON.parse(
    bridge.applyMinigameJson(JSON.stringify(state), wins, rounds, nowMillis)
  );
}

export function newPet(params: {
  petId: string;
  ownerId: string;
  name: string;
  nowMillis: number;
  utcOffsetMinutes: number;
}): PetState {
  return JSON.parse(
    bridge.newPetJson(
      params.petId,
      params.ownerId,
      params.name,
      params.nowMillis,
      params.utcOffsetMinutes
    )
  );
}

export function isAlive(state: PetState): boolean {
  return state.diedAtMillis === null;
}
