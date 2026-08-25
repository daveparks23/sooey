// Replays the golden vectors — generated on the Dart VM — against the
// dart2js-compiled simulation running here in Node.
//
// This is the test that justifies the whole architecture. The simulation is
// written once in Dart; if the compiled bundle disagrees with the VM on any
// field of any case, the client's optimistic prediction would drift from the
// server's authority and the pig would visibly snap on every sync.
//
//   npm run build:sim && node --test test/
//
// Regenerate the vectors with:
//   cd ../packages/hog_sim && dart run tool/emit_golden_vectors.dart

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const sim = require('../generated/hog_sim.js');

const vectors = JSON.parse(
  readFileSync(
    new URL('../../packages/hog_sim/test/golden/vectors.json', import.meta.url),
    'utf8',
  ),
);

test('the bundle exposes the bridge contract', () => {
  for (const fn of [
    'advanceJson',
    'applyActionJson',
    'applyMinigameJson',
    'newPetJson',
  ]) {
    assert.equal(typeof sim[fn], 'function', `${fn} is missing`);
  }
});

test('the vector file is the one this build expects', () => {
  assert.equal(vectors.tickMinutes, 5);
  assert.ok(vectors.advance.length >= 50, 'too few advance vectors');
});

test('advance matches the Dart VM on every vector', (t) => {
  for (const v of vectors.advance) {
    const actual = JSON.parse(sim.advanceJson(JSON.stringify(v.input), v.nowMillis));
    assert.deepStrictEqual(actual, v.expected, `advance vector "${v.name}"`);
  }
  t.diagnostic(`${vectors.advance.length} advance vectors matched`);
});

test('applyAction matches the Dart VM on every vector', (t) => {
  for (const v of vectors.action) {
    const actual = JSON.parse(
      sim.applyActionJson(JSON.stringify(v.input), v.action, v.nowMillis),
    );
    assert.deepStrictEqual(actual, v.expected, `action vector "${v.name}"`);
  }
  t.diagnostic(`${vectors.action.length} action vectors matched`);
});

test('applyMinigame matches the Dart VM on every vector', (t) => {
  for (const v of vectors.minigame) {
    const actual = JSON.parse(
      sim.applyMinigameJson(JSON.stringify(v.input), v.wins, v.rounds, v.nowMillis),
    );
    assert.deepStrictEqual(actual, v.expected, `minigame vector "${v.name}"`);
  }
  t.diagnostic(`${vectors.minigame.length} minigame vectors matched`);
});

test('newPet produces a fresh egg', () => {
  const bornAt = 1755000000000;
  const pet = JSON.parse(
    sim.newPetJson('pet_new', 'uid_1', 'Wilbur', bornAt, -300),
  );
  assert.equal(pet.petId, 'pet_new');
  assert.equal(pet.ownerId, 'uid_1');
  assert.equal(pet.name, 'Wilbur');
  assert.equal(pet.stage, 'egg');
  assert.equal(pet.form, 'base');
  assert.equal(pet.bornAtMillis, bornAt);
  assert.equal(pet.lastTickAtMillis, bornAt);
  assert.equal(pet.utcOffsetMinutes, -300);
  assert.equal(pet.fullness, 100);
  assert.equal(pet.diedAtMillis, null);
});

test('newPet truncates an over-long name', () => {
  const pet = JSON.parse(
    sim.newPetJson('p', 'u', 'Bartholomew Cornelius', 1755000000000, 0),
  );
  assert.equal(pet.name.length, 12);
});

// Timestamps are ~1.7e12 and tick indices ~5.9e6. Both are exact as IEEE-754
// doubles, but a regression that routed them through 32-bit arithmetic would
// wrap silently, so pin the boundary explicitly.
test('large timestamps survive the bridge intact', () => {
  const bornAt = 1755000000000;
  const pet = JSON.parse(sim.newPetJson('p', 'u', 'W', bornAt, 0));
  const advanced = JSON.parse(
    sim.advanceJson(JSON.stringify(pet), bornAt + 6 * 3600000),
  );
  assert.equal(advanced.lastTickAtMillis, bornAt + 6 * 3600000);
  assert.equal(advanced.bornAtMillis, bornAt);
});

test('a malformed state is rejected rather than silently mangled', () => {
  assert.throws(() => sim.advanceJson('{"petId":"only-this"}', 1755000000000));
  assert.throws(() => sim.advanceJson('not json at all', 1755000000000));
});
