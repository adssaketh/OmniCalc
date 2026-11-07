// Old engine versus Casio engine over every Part 6 evaluator vector (Part 9, section 9.1). A difference that is not listed in
// test/casio/intended_differences.json (which tools/gen_casio_diff_doc.py turns into docs/INTENDED_DIFFERENCES.md) fails,
// so nothing changes silently. A listed entry that no longer differs fails too, so the list stays accurate.
//
// To refresh after an intended change:  UPDATE_CASIO_DIFF=1 flutter test test/casio/legacy_diff_test.dart
//                                       python3 tools/gen_casio_diff_doc.py

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/engine.dart';

import '../golden/golden_loader.dart';

List<Map<String, Object?>> computeDifferences() {
  final vectors = (loadGolden('evaluator') as List).cast<Map<String, dynamic>>();
  final out = <Map<String, Object?>>[];
  for (final v in vectors) {
    if (v['yDef'] != null) continue; // y = f(x) vectors belong to the equation feature, not to the evaluator
    final expr = v['expr'] as String;
    final rad = v['mode'] == 'rad';
    final e = CasioEngine(config: CasioConfig(angle: rad ? CasioAngle.rad : CasioAngle.deg));
    String? err;
    double? val;
    try {
      val = e.evaluate(expr).value?.v;
    } catch (x) {
      err = CasioEngine.messageOf(x);
    }
    if (v.containsKey('error')) {
      if (err == null || err != v['error']) {
        out.add({'expr': expr, 'mode': v['mode'], 'old': 'ERROR ${v['error']}', 'new': err ?? 'value $val'});
      }
      continue;
    }
    final expected = parseGoldenNumber(v['value'] as String);
    if (val == null || !closeRel(val, expected)) {
      out.add({'expr': expr, 'mode': v['mode'], 'old': v['value'], 'new': err != null ? 'ERROR $err' : '$val'});
    }
  }
  return out;
}

void main() {
  test('every difference from the legacy engine is listed as intended', () {
    final diffs = computeDifferences();
    if (Platform.environment['UPDATE_CASIO_DIFF'] == '1') {
      File('test/casio/intended_differences.raw.json')
          .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(diffs));
    }
    final listed = (jsonDecode(File('test/casio/intended_differences.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    String key(Map<String, Object?> m) => '${m['mode']}|${m['expr']}';
    final listedKeys = {for (final m in listed) key(m)};
    final actualKeys = {for (final m in diffs) key(m)};
    expect(actualKeys.difference(listedKeys), isEmpty, reason: 'differences that are not on the intended list');
    expect(listedKeys.difference(actualKeys), isEmpty, reason: 'listed differences that do not differ any more');
    for (final m in listed) {
      expect(m['id'], isNotNull);
      expect(m['manual'], isNotNull);
    }
  });
}
