/// Writes the golden vectors used to hold the dart2js-compiled server to the
/// same behaviour as the Dart VM.
///
///     dart run tool/emit_golden_vectors.dart
///
/// Regenerate deliberately. A diff in `test/golden/vectors.json` means the
/// simulation's observable behaviour changed — which is fine when intended and
/// a bug when not.
library;

import 'dart:convert';
import 'dart:io';

import '../test/golden_scenarios.dart';

void main(List<String> args) {
  final vectors = buildGoldenVectors();
  final text = '${const JsonEncoder.withIndent('  ').convert(vectors)}\n';

  final file = File('test/golden/vectors.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(text);

  final advanceCount = (vectors['advance']! as List).length;
  final actionCount = (vectors['action']! as List).length;
  final minigameCount = (vectors['minigame']! as List).length;
  stdout.writeln(
    'Wrote ${file.path}: $advanceCount advance, $actionCount action, '
    '$minigameCount minigame '
    '(${advanceCount + actionCount + minigameCount} vectors, '
    '${text.length} bytes)',
  );
}
