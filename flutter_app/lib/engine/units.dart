import 'js_number.dart';
import 'unit_types.dart';

export 'unit_types.dart';
export 'units_data.dart' show unitCategories;

/// Port of `convertUnit` in `src/engine/units.ts`.
///
/// Unknown unit ids fall back to the first unit (from) and the second unit (to), exactly like the web app.
({double result, String formula}) convertUnit(
  double value,
  UnitCategory category,
  String fromUnitId,
  String toUnitId,
) {
  final fromUnit = _find(category, fromUnitId) ?? category.units[0];
  final toUnit = _find(category, toUnitId) ?? category.units[1];

  if (value.isNaN) {
    return (result: 0.0, formula: '');
  }

  // Base representation
  final baseValue = fromUnit.toBase(value);
  final targetValue = toUnit.fromBase(baseValue);

  // Derive formula text: `${parseFloat(x.toPrecision(6))}`
  final ratio = jsToString(jsParseFloat(jsToPrecision(toUnit.fromBase(fromUnit.toBase(1)), 6)));
  var formula = '1 ${fromUnit.symbol} = $ratio ${toUnit.symbol}';
  if (category.id == 'temperature') {
    if (fromUnitId == 'C' && toUnitId == 'F') {
      formula = '(°C × 9/5) + 32 = °F';
    } else if (fromUnitId == 'F' && toUnitId == 'C') {
      formula = '(°F − 32) × 5/9 = °C';
    } else if (fromUnitId == 'C' && toUnitId == 'K') {
      formula = '°C + 273.15 = K';
    } else if (fromUnitId == 'K' && toUnitId == 'C') {
      formula = 'K − 273.15 = °C';
    }
  }

  return (result: targetValue, formula: formula);
}

UnitDefinition? _find(UnitCategory category, String id) {
  for (final u in category.units) {
    if (u.id == id) return u;
  }
  return null;
}
