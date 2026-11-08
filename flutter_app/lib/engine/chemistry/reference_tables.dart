import 'elements.dart';
import 'formula.dart';

/// Reference tables (Part 3.3). Each table says where its values come from; none is computed from guesses.

class ReferenceTable {
  const ReferenceTable({required this.id, required this.title, required this.columns, required this.rows, this.note});

  final String id;
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final String? note;
}

const ReferenceTable solubilityRules = ReferenceTable(
  id: 'solubility',
  title: 'Solubility rules (water, about 25 °C)',
  columns: ['Ion or salt', 'Rule', 'Exceptions'],
  note: 'General rules of thumb from general chemistry. Real solubilities are a continuum.',
  rows: [
    ['Group 1 cations (Li⁺, Na⁺, K⁺…) and NH₄⁺', 'Soluble', 'None'],
    ['Nitrates (NO₃⁻), acetates (C₂H₃O₂⁻), chlorates, perchlorates', 'Soluble', 'None (AgC₂H₃O₂ is only moderately soluble)'],
    ['Chlorides, bromides, iodides', 'Soluble', 'Ag⁺, Pb²⁺, Hg₂²⁺ (and Cu⁺ for the halides)'],
    ['Sulfates (SO₄²⁻)', 'Soluble', 'Ba²⁺, Sr²⁺, Pb²⁺, Hg₂²⁺; Ca²⁺ and Ag⁺ slightly soluble'],
    ['Hydroxides (OH⁻)', 'Insoluble', 'Group 1 and NH₄⁺; Ba²⁺, Sr²⁺ soluble; Ca²⁺ slightly'],
    ['Carbonates, phosphates, sulfites, chromates (CO₃²⁻, PO₄³⁻, SO₃²⁻, CrO₄²⁻)', 'Insoluble', 'Group 1 and NH₄⁺'],
    ['Sulfides (S²⁻)', 'Insoluble', 'Group 1, Group 2 and NH₄⁺'],
    ['Oxides (O²⁻)', 'Insoluble', 'Group 1; Ca²⁺, Sr²⁺, Ba²⁺ react to form hydroxides'],
  ],
);

/// Polyatomic ions: formula (as typed) and name. The charge is part of the formula text, so a test can check every row.
class PolyatomicIon {
  const PolyatomicIon(this.formula, this.name);
  final String formula;
  final String name;
}

const List<PolyatomicIon> polyatomicIons = [
  PolyatomicIon('NH4^+', 'ammonium'),
  PolyatomicIon('H3O^+', 'hydronium'),
  PolyatomicIon('Hg2^2+', 'mercury(I)'),
  PolyatomicIon('OH^-', 'hydroxide'),
  PolyatomicIon('CN^-', 'cyanide'),
  PolyatomicIon('SCN^-', 'thiocyanate'),
  PolyatomicIon('CH3COO^-', 'acetate'),
  PolyatomicIon('NO2^-', 'nitrite'),
  PolyatomicIon('NO3^-', 'nitrate'),
  PolyatomicIon('ClO^-', 'hypochlorite'),
  PolyatomicIon('ClO2^-', 'chlorite'),
  PolyatomicIon('ClO3^-', 'chlorate'),
  PolyatomicIon('ClO4^-', 'perchlorate'),
  PolyatomicIon('BrO3^-', 'bromate'),
  PolyatomicIon('IO3^-', 'iodate'),
  PolyatomicIon('MnO4^-', 'permanganate'),
  PolyatomicIon('HCO3^-', 'hydrogen carbonate (bicarbonate)'),
  PolyatomicIon('HSO3^-', 'hydrogen sulfite (bisulfite)'),
  PolyatomicIon('HSO4^-', 'hydrogen sulfate (bisulfate)'),
  PolyatomicIon('H2PO4^-', 'dihydrogen phosphate'),
  PolyatomicIon('CO3^2-', 'carbonate'),
  PolyatomicIon('SO3^2-', 'sulfite'),
  PolyatomicIon('SO4^2-', 'sulfate'),
  PolyatomicIon('S2O3^2-', 'thiosulfate'),
  PolyatomicIon('C2O4^2-', 'oxalate'),
  PolyatomicIon('CrO4^2-', 'chromate'),
  PolyatomicIon('Cr2O7^2-', 'dichromate'),
  PolyatomicIon('HPO4^2-', 'hydrogen phosphate'),
  PolyatomicIon('O2^2-', 'peroxide'),
  PolyatomicIon('SiO3^2-', 'silicate'),
  PolyatomicIon('PO3^3-', 'phosphite'),
  PolyatomicIon('PO4^3-', 'phosphate'),
  PolyatomicIon('BO3^3-', 'borate'),
];

const ReferenceTable activitySeries = ReferenceTable(
  id: 'activity',
  title: 'Activity series of metals',
  columns: ['Order', 'Metal', 'Reacts with'],
  note: 'Most reactive at the top. A metal displaces any metal below it from solution. Metals above H displace H₂ from acids.',
  rows: [
    ['1', 'Li', 'Cold water, steam, acids'],
    ['2', 'K', 'Cold water, steam, acids'],
    ['3', 'Ba', 'Cold water, steam, acids'],
    ['4', 'Ca', 'Cold water, steam, acids'],
    ['5', 'Na', 'Cold water, steam, acids'],
    ['6', 'Mg', 'Steam, acids'],
    ['7', 'Al', 'Steam, acids'],
    ['8', 'Mn', 'Steam, acids'],
    ['9', 'Zn', 'Steam, acids'],
    ['10', 'Cr', 'Steam, acids'],
    ['11', 'Fe', 'Steam, acids'],
    ['12', 'Cd', 'Acids'],
    ['13', 'Co', 'Acids'],
    ['14', 'Ni', 'Acids'],
    ['15', 'Sn', 'Acids'],
    ['16', 'Pb', 'Acids'],
    ['—', 'H₂', 'Reference'],
    ['17', 'Cu', 'Oxidizing acids only'],
    ['18', 'Ag', 'Oxidizing acids only'],
    ['19', 'Hg', 'Oxidizing acids only'],
    ['20', 'Pt', 'Aqua regia'],
    ['21', 'Au', 'Aqua regia'],
  ],
);

const ReferenceTable pkaTable = ReferenceTable(
  id: 'pka',
  title: 'pKa of common acids (25 °C, water)',
  columns: ['Acid', 'Formula', 'pKa'],
  note: 'Textbook values; sources differ in the last digit. Polyprotic acids list each step.',
  rows: [
    ['Hydrochloric', 'HCl', 'strong (about −6)'],
    ['Nitric', 'HNO₃', 'strong (about −1.4)'],
    ['Sulfuric (1st)', 'H₂SO₄', 'strong (about −3)'],
    ['Hydrogen sulfate (2nd)', 'HSO₄⁻', '1.99'],
    ['Phosphoric (1st)', 'H₃PO₄', '2.15'],
    ['Phosphoric (2nd)', 'H₂PO₄⁻', '7.20'],
    ['Phosphoric (3rd)', 'HPO₄²⁻', '12.35'],
    ['Hydrofluoric', 'HF', '3.17'],
    ['Nitrous', 'HNO₂', '3.25'],
    ['Formic', 'HCOOH', '3.75'],
    ['Lactic', 'CH₃CH(OH)COOH', '3.86'],
    ['Benzoic', 'C₆H₅COOH', '4.20'],
    ['Acetic', 'CH₃COOH', '4.76'],
    ['Carbonic (1st)', 'H₂CO₃', '6.35'],
    ['Carbonic (2nd)', 'HCO₃⁻', '10.33'],
    ['Hydrogen sulfide (1st)', 'H₂S', '7.0'],
    ['Hypochlorous', 'HOCl', '7.54'],
    ['Ammonium', 'NH₄⁺', '9.25'],
    ['Hydrocyanic', 'HCN', '9.21'],
    ['Oxalic (1st)', 'H₂C₂O₄', '1.25'],
    ['Oxalic (2nd)', 'HC₂O₄⁻', '4.14'],
    ['Citric (1st)', 'C₆H₈O₇', '3.13'],
    ['Citric (2nd)', 'C₆H₇O₇⁻', '4.76'],
    ['Citric (3rd)', 'C₆H₆O₇²⁻', '6.40'],
  ],
);

const ReferenceTable specificHeats = ReferenceTable(
  id: 'specific_heat',
  title: 'Specific heat capacities (near 25 °C)',
  columns: ['Substance', 'c  (J/(g·K))'],
  note: 'Typical textbook values. Ice and steam values are for the solid and gas phases.',
  rows: [
    ['Water (liquid)', '4.184'],
    ['Ice', '2.09'],
    ['Steam', '2.01'],
    ['Ethanol', '2.44'],
    ['Aluminium', '0.897'],
    ['Iron', '0.449'],
    ['Copper', '0.385'],
    ['Zinc', '0.388'],
    ['Silver', '0.235'],
    ['Lead', '0.129'],
    ['Gold', '0.129'],
    ['Glass (typical)', '0.84'],
  ],
);

/// Common compounds whose molar mass is computed live from the element table.
const List<(String, String)> commonCompounds = [
  ('Water', 'H2O'),
  ('Carbon dioxide', 'CO2'),
  ('Oxygen', 'O2'),
  ('Nitrogen', 'N2'),
  ('Hydrogen', 'H2'),
  ('Methane', 'CH4'),
  ('Ammonia', 'NH3'),
  ('Ethanol', 'C2H5OH'),
  ('Glucose', 'C6H12O6'),
  ('Sucrose', 'C12H22O11'),
  ('Sodium chloride', 'NaCl'),
  ('Sodium hydroxide', 'NaOH'),
  ('Sodium bicarbonate', 'NaHCO3'),
  ('Calcium carbonate', 'CaCO3'),
  ('Hydrochloric acid', 'HCl'),
  ('Sulfuric acid', 'H2SO4'),
  ('Nitric acid', 'HNO3'),
  ('Acetic acid', 'CH3COOH'),
  ('Potassium permanganate', 'KMnO4'),
  ('Copper(II) sulfate pentahydrate', 'CuSO4.5H2O'),
];

/// Rows for the "common molar masses" table, computed from the element table.
List<List<String>> commonMolarMassRows() => [
      for (final (name, formula) in commonCompounds)
        [name, prettyFormula(formula), parseFormula(formula).molarMass.toStringAsFixed(3)],
    ];

/// Electronegativity table: period 2 and 3 main-group elements and the halogens, read from the element table.
List<List<String>> electronegativityRows() {
  final out = <List<String>>[];
  for (final e in chemElements) {
    if (e.electronegativity == null) continue;
    final inPeriod23 = e.period == 2 || e.period == 3;
    final halogenOrAlkali = e.category == 'Halogen' || e.category == 'Alkali metal';
    if (!(inPeriod23 || halogenOrAlkali)) continue;
    if (e.block == 'd') continue;
    out.add([e.symbol, e.name, '${e.period}', e.group == null ? '' : '${e.group}', e.electronegativity!.toStringAsFixed(2)]);
  }
  return out;
}

const String electronegativityNote =
    'Pauling electronegativity rises from left to right across a period and falls down a group. Fluorine is the highest.';

/// All static tables in display order.
const List<ReferenceTable> staticReferenceTables = [solubilityRules, activitySeries, pkaTable, specificHeats];
