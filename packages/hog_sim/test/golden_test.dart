@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'golden_scenarios.dart';

/// Guards the checked-in vector file against drifting from the code that
/// generated it. The same file is replayed in Node against the dart2js bundle,
/// so if this test is stale the cross-runtime check is testing nothing.
void main() {
  test('test/golden/vectors.json is up to date', () {
    final file = File('test/golden/vectors.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run: dart run tool/emit_golden_vectors.dart',
    );

    final onDisk = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final current = buildGoldenVectors();

    // Compare section by section so a failure names what moved.
    for (final section in ['advance', 'action', 'minigame']) {
      final a = onDisk[section]! as List;
      final b = current[section]! as List;
      expect(
        a.length,
        b.length,
        reason: '$section: case count changed — regenerate the vectors',
      );
      for (var i = 0; i < b.length; i++) {
        final name = (b[i] as Map)['name'];
        expect(
          jsonEncode(a[i]),
          jsonEncode(b[i]),
          reason:
              '$section[$i] "$name" changed. If deliberate, regenerate with: '
              'dart run tool/emit_golden_vectors.dart',
        );
      }
    }
  });

  test('the vectors cover enough ground to be worth trusting', () {
    final v = buildGoldenVectors();
    expect((v['advance']! as List).length, greaterThanOrEqualTo(50));
    expect((v['action']! as List).length, greaterThanOrEqualTo(15));
    expect((v['minigame']! as List).length, greaterThanOrEqualTo(10));
  });

  test('the vectors exercise every death cause', () {
    final causes = <String>{};
    for (final c in buildGoldenVectors()['advance']! as List) {
      final cause = ((c as Map)['expected']! as Map)['deathCause'];
      if (cause != null) causes.add(cause as String);
    }
    expect(causes, containsAll(['starvation', 'illness', 'neglect', 'oldAge']));
  });

  test('the vectors exercise every stage and adult form', () {
    final stages = <String>{};
    final forms = <String>{};
    for (final c in buildGoldenVectors()['advance']! as List) {
      final expected = (c as Map)['expected']! as Map;
      stages.add(expected['stage']! as String);
      forms.add(expected['form']! as String);
    }
    expect(stages, containsAll(['egg', 'piglet', 'shoat', 'adult']));
    expect(forms, containsAll(['base', 'prizeHog', 'farmHog', 'runt']));
  });

  test('the vectors include a pig that actually fell ill', () {
    final anySick = (buildGoldenVectors()['advance']! as List).any(
      (c) => ((c as Map)['expected']! as Map)['isSick'] == true,
    );
    expect(anySick, isTrue, reason: 'the sickness roll is never exercised');
  });
}
