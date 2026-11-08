// Examples printed in the fx-991ES PLUS manual, with their page numbers. Source of truth number 2 (after real_device.json).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/engine.dart';

CasioConfig configOf(Map<String, dynamic>? c) {
  var cfg = const CasioConfig();
  if (c == null) return cfg;
  if (c['format'] == 'lineIO') cfg = cfg.copyWith(displayFormat: CasioDisplayFormat.lineIO, decimalFirst: true);
  if (c['rdec'] == false) cfg = cfg.copyWith(recurring: false);
  if (c['percent'] == 'casio') cfg = cfg.copyWith(phonePercent: false);
  final n = c['number'] as String?;
  if (n != null) {
    final d = int.parse(n.substring(3));
    if (n.startsWith('fix')) cfg = cfg.copyWith(numberFormat: CasioNumberFormat.fix, digits: d);
    if (n.startsWith('sci')) cfg = cfg.copyWith(numberFormat: CasioNumberFormat.sci, digits: d);
  }
  if (c['angle'] == 'rad') cfg = cfg.copyWith(angle: CasioAngle.rad);
  if (c['angle'] == 'gra') cfg = cfg.copyWith(angle: CasioAngle.gra);
  return cfg;
}

void main() {
  // real_device.json: observations from a real fx-991ES PLUS (same shape, "page" replaced by "note"). They outrank the manual.
  final real = (jsonDecode(File('test/casio/real_device.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final examples = (jsonDecode(File('test/casio/guide_examples.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  for (final ex in [...real, ...examples]) {
    test('${ex.containsKey('page') ? 'manual p.${ex['page']}' : 'real device ${ex['note']}'}: ${ex['input']} ${ex['config'] ?? ''}', () {
      final engine = CasioEngine(config: configOf(ex['config'] as Map<String, dynamic>?));
      final o = engine.evaluate(ex['input'] as String);
      expect([for (final f in o.forms) f.display], (ex['forms'] as List).cast<String>());
      if (ex['remainder'] != null) expect(o.remainder, ex['remainder']);
      if (ex['disp'] != null) expect(o.disp, (ex['disp'] as List).cast<String>());
      if (ex['extra'] != null) expect(o.extra, (ex['extra'] as Map).cast<String, String>());
    });
  }
}
