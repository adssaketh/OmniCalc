/// One element of the periodic table (Phase 6, Part 3.1). Named `ChemElement` so it cannot clash with Flutter's `Element`.
///
/// Every optional field is `null` when the source data has no value for it; nothing is estimated or invented.
class ChemElement {
  const ChemElement({
    required this.z,
    required this.symbol,
    required this.name,
    required this.mass,
    required this.group,
    required this.period,
    required this.block,
    required this.category,
    required this.electronConfig,
    required this.electronegativity,
    required this.atomicRadiusPm,
    required this.ionizationEnergyEv,
    required this.electronAffinityEv,
    required this.oxidationStates,
    required this.standardState,
    required this.meltingPointK,
    required this.boilingPointK,
    required this.densityGcm3,
    required this.yearDiscovered,
    required this.cpkColor,
  });

  /// Atomic number.
  final int z;
  final String symbol;
  final String name;

  /// Standard atomic weight, g/mol (master prompt Appendix A; superheavy values are mass numbers / estimates).
  final double mass;

  /// IUPAC group 1..18; `null` for the lanthanides and actinides (they sit in the f-block rows).
  final int? group;
  final int period;

  /// 's', 'p', 'd' or 'f'.
  final String block;

  /// One of [elementCategories].
  final String category;

  /// With real superscripts, e.g. `[Ar] 3d⁶ 4s²`.
  final String? electronConfig;

  /// Pauling scale.
  final double? electronegativity;
  final double? atomicRadiusPm;
  final double? ionizationEnergyEv;
  final double? electronAffinityEv;
  final List<int> oxidationStates;

  /// 'gas', 'liquid' or 'solid' at 25 °C and 1 atm.
  final String? standardState;
  final double? meltingPointK;
  final double? boilingPointK;
  final double? densityGcm3;

  /// `null` for elements known since antiquity or without a recorded year.
  final int? yearDiscovered;

  /// 0xFFRRGGBB of the CPK colour, `null` when the dataset has none.
  final int? cpkColor;
}

/// Category names in display order (periodic-table legend and filter chips).
const List<String> elementCategories = [
  'Alkali metal',
  'Alkaline earth metal',
  'Transition metal',
  'Post-transition metal',
  'Metalloid',
  'Nonmetal',
  'Halogen',
  'Noble gas',
  'Lanthanide',
  'Actinide',
];
