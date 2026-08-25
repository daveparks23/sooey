import 'package:flutter_test/flutter_test.dart';
import 'package:hog_sim/hog_sim.dart';
import 'package:sooey/game/screens/death_screen.dart';
import 'package:sooey/game/screens/device_screen.dart';

import 'screen_test_support.dart';

GameContext _dead({Crest crest = Crest.leaf, int ageDays = 9}) => testContext(
  crest: crest,
  pet: testPet(deathCause: DeathCause.neglect, ageDays: ageDays),
);

void main() {
  test('B starts another pig', () {
    expect(DeathScreen().handle(Button.b, _dead()), isA<Restart>());
  });

  test('A and C do nothing — leaving is not an option', () {
    expect(DeathScreen().handle(Button.a, _dead()), isA<Stay>());
    expect(DeathScreen().handle(Button.c, _dead()), isA<Stay>());
  });

  test("shows the pig's crest, so the grave is this pig and not any pig", () {
    final shapes = {
      for (final crest in Crest.values)
        DeathScreen().compose(_dead(crest: crest), 0).toAscii(),
    };
    expect(shapes.length, Crest.values.length);
  });

  test('shows the age it reached', () {
    expect(
      DeathScreen().compose(_dead(ageDays: 2), 0).toAscii(),
      isNot(DeathScreen().compose(_dead(ageDays: 14), 0).toAscii()),
    );
  });

  test('keeps a twenty-day life inside the gutter', () {
    // Twenty days is the longest a prize hog lives. Four single-dot pips per
    // row at a two-dot pitch is the only way that many fit beside the stone —
    // anything wider spills onto the grave.
    //
    // Count the pips rather than asserting the buffer's shape: LcdBuffer is
    // always 16x32, so a shape assertion here would pass unconditionally.
    final rows = DeathScreen()
        .compose(_dead(ageDays: 20), 0)
        .toAscii()
        .split('\n');
    var inGutter = 0;
    for (final row in rows) {
      for (var x = 25; x < 32; x++) {
        if (row[x] == '#') inGutter++;
      }
    }
    expect(inGutter, 20, reason: 'one dot per day, all of them in the gutter');
  });

  test('draws the stone', () {
    // Assert the grave occupies its own columns. A bare `contains('#')` would
    // pass on the crest or the pips alone and could not fail while anything at
    // all was drawn.
    final rows = DeathScreen().compose(_dead(), 0).toAscii().split('\n');
    final stoneRows = rows.where((r) => r.substring(8, 24).contains('#'));
    expect(
      stoneRows.length,
      greaterThanOrEqualTo(10),
      reason: 'the stone should fill most of the middle sixteen columns',
    );
  });

  test('lights no strip icon', () {
    expect(DeathScreen().litIcon, isNull);
  });
}
