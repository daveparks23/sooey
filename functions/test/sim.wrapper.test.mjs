// Exercises the *compiled* TypeScript façade rather than the raw bundle.
//
// `src/sim.ts` requires "../generated/hog_sim.js", which resolves relative to
// `lib/` once tsc has run. That path is easy to break and would fail only at
// deploy time, so pin it here.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const sim = require('../lib/sim.js');

const REF_NOON = 1755000000000;
const HOUR = 3600000;

test('the façade resolves the generated bundle from lib/', () => {
  for (const fn of ['advance', 'applyAction', 'applyMinigame', 'newPet', 'isAlive']) {
    assert.equal(typeof sim[fn], 'function', `${fn} is missing`);
  }
});

test('newPet returns a parsed object, not a JSON string', () => {
  const pet = sim.newPet({
    petId: 'pet_1',
    ownerId: 'uid_1',
    name: 'Wilbur',
    nowMillis: REF_NOON,
    utcOffsetMinutes: 0,
  });
  assert.equal(typeof pet, 'object');
  assert.equal(pet.stage, 'egg');
  assert.equal(sim.isAlive(pet), true);
});

test('a pig fed through the façade gains fullness and schedules a poop', () => {
  const pet = sim.newPet({
    petId: 'pet_1',
    ownerId: 'uid_1',
    name: 'Wilbur',
    nowMillis: REF_NOON,
    utcOffsetMinutes: 0,
  });
  // Hatch it first — an egg has no mouth.
  const piglet = sim.advance(pet, REF_NOON + 6 * HOUR);
  assert.equal(piglet.stage, 'piglet');

  const before = piglet.fullness;
  const outcome = sim.applyAction(piglet, 'slop', REF_NOON + 6 * HOUR);
  assert.equal(outcome.accepted, true);
  assert.equal(outcome.refusal, null);
  assert.ok(outcome.state.fullness > before);
  assert.equal(outcome.state.pendingPoopTicks.length, 1);
});

test('a refusal comes back as feedback rather than an exception', () => {
  const pet = sim.newPet({
    petId: 'pet_1',
    ownerId: 'uid_1',
    name: 'Wilbur',
    nowMillis: REF_NOON,
    utcOffsetMinutes: 0,
  });
  const piglet = sim.advance(pet, REF_NOON + 20 * 60000);
  const outcome = sim.applyAction(piglet, 'slop', REF_NOON + 20 * 60000);
  assert.equal(outcome.accepted, false);
  assert.equal(outcome.refusal, 'notHungry');
  assert.deepStrictEqual(outcome.state, piglet, 'refused actions must not mutate');
});

test('advancing an unattended pig eventually kills it', () => {
  const pet = sim.newPet({
    petId: 'pet_doomed',
    ownerId: 'uid_1',
    name: 'Wilbur',
    nowMillis: REF_NOON,
    utcOffsetMinutes: 0,
  });
  const dead = sim.advance(pet, REF_NOON + 30 * 24 * HOUR);
  assert.equal(sim.isAlive(dead), false);
  assert.ok(dead.diedAtMillis < REF_NOON + 30 * 24 * HOUR, 'died at the tick, not at now');
  assert.ok(['starvation', 'illness', 'neglect', 'oldAge'].includes(dead.deathCause));
});
