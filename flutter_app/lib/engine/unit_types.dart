/// Mirrors `UnitCategory` / `UnitDefinition` in `src/types/index.ts`.
class UnitDefinition {
  final String id;
  final String name;
  final String symbol;
  final double Function(double) toBase;
  final double Function(double) fromBase;

  const UnitDefinition({
    required this.id,
    required this.name,
    required this.symbol,
    required this.toBase,
    required this.fromBase,
  });
}

class UnitCategory {
  final String id;
  final String name;

  /// Icon name used for the category's tab (a lucide icon name, e.g. 'Ruler').
  /// The web app has this field but never showed it; the Flutter app does (requested change, see PHASE2_NOTES.md).
  final String iconName;
  final String baseUnit;
  final List<UnitDefinition> units;

  const UnitCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.baseUnit,
    required this.units,
  });
}
