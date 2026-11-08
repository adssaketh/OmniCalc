import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/units.dart';

import 'golden_expect.dart';
import 'golden_loader.dart';

// Vectors produced by running the real TypeScript engine (see tools/gen_vectors.ts).
// raw doubles: 1e-9 relative; formula text and catalog names: exact.
void main() {
  final vectors = (loadGolden('units') as List).cast<Map<String, dynamic>>();
  final catalog = (loadGolden('unit_catalog') as List).cast<Map<String, dynamic>>();

  test('golden files are present and non-trivial', () {
    expect(vectors.length, greaterThanOrEqualTo(3000));
    expect(catalog.length, 13);
  });

  test('catalog matches the TypeScript UNIT_CATEGORIES (ids, names, icon names, base units, unit symbols)', () {
    expect(unitCategories.length, catalog.length);
    for (var i = 0; i < catalog.length; i++) {
      final want = catalog[i];
      final got = unitCategories[i];
      expect(got.id, want['id']);
      expect(got.name, want['name']);
      expect(got.iconName, want['iconName'], reason: 'icon of ${got.id}');
      expect(got.baseUnit, want['baseUnit']);
      final wantUnits = (want['units'] as List).cast<Map<String, dynamic>>();
      expect(got.units.length, wantUnits.length, reason: 'unit count of ${got.id}');
      for (var j = 0; j < wantUnits.length; j++) {
        expect(got.units[j].id, wantUnits[j]['id'], reason: '${got.id}[$j].id');
        expect(got.units[j].name, wantUnits[j]['name'], reason: '${got.id}[$j].name');
        expect(got.units[j].symbol, wantUnits[j]['symbol'], reason: '${got.id}[$j].symbol');
      }
    }
  });

  test('every converter category has an icon name (the tabs now show logos)', () {
    for (final c in unitCategories) {
      expect(c.iconName, isNotEmpty, reason: c.id);
    }
  });

  for (final v in vectors) {
    final c = v['c'] as String;
    final a = v['a'] as String;
    final b = v['b'] as String;
    final input = v['v'] as String;
    test('$c: $input $a -> $b', () {
      final category = unitCategories.firstWhere((x) => x.id == c);
      final out = convertUnit(parseGoldenNumber(input), category, a, b);
      expectNum(out.result, {'n': v['r']}, 'result');
      expect(out.formula, v['f'] as String);
    });
  }
}
