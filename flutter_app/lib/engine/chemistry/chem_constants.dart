import '../physics_constants.dart';

/// Constants of the Chemistry screen (Part 3.4). Same data shape as the Physics Lab's [PhysicalConstant]; the Physics Lab list
/// itself is not touched. Values already in that list (Avogadro, R, Planck, Boltzmann, particle masses, Rydberg, Bohr radius)
/// are taken from it, so both screens always agree. The rest are CODATA 2018 unless the description says otherwise.

/// R in J/(mol K); same number as the Physics Lab and the calculator's `R` constant.
const double rJoule = 8.314462618;

/// R in L atm/(mol K) = R / 101.325.
const double rLAtm = rJoule / 101.325;

/// R in L kPa/(mol K) (= J/(mol K)).
const double rLkPa = rJoule;

/// R in cal/(mol K), thermochemical calorie (1 cal = 4.184 J).
const double rCal = rJoule / 4.184;

/// Faraday constant, C/mol = NA e (both exact).
const double faraday = 6.02214076e23 * 1.602176634e-19;

/// Standard atmosphere, Pa (exact).
const double atmPa = 101325;

/// Ion product of water at 25 C. Textbook value; the precise figure is 1.008e-14.
const double kw25 = 1.0e-14;

/// Atomic mass unit in MeV/c^2 (CODATA 2018).
const double uMeV = 931.49410242;

/// Rydberg energy in eV (CODATA 2018).
const double rydbergEv = 13.605693122994;

/// 0 C in kelvin (exact).
const double zeroCelsiusK = 273.15;

const double _molarVolume0C1atm = rJoule * 273.15 / 101325 * 1000;
const double _molarVolume0C1bar = rJoule * 273.15 / 100000 * 1000;

PhysicalConstant _fromPhysics(String id, {String? category}) {
  final c = physicalConstants.firstWhere((c) => c.id == id);
  return PhysicalConstant(
    id: c.id,
    name: c.name,
    symbol: c.symbol,
    value: c.value,
    unit: c.unit,
    category: category ?? c.category,
    description: c.description,
  );
}

/// Categories in display order.
const List<String> chemConstantCategories = [
  'Gas constants',
  'Standard conditions',
  'Electrochemistry',
  'Water & solutions',
  'Atoms & particles',
];

final List<PhysicalConstant> chemConstants = [
  _fromPhysics('NA', category: 'Gas constants'),
  _fromPhysics('R', category: 'Gas constants'),
  const PhysicalConstant(
    id: 'R_Latm',
    name: 'Gas Constant (L atm)',
    symbol: 'R',
    value: rLAtm,
    unit: 'L · atm / (mol · K)',
    category: 'Gas constants',
    description: 'R in litre-atmospheres: 8.314462618 / 101.325',
  ),
  const PhysicalConstant(
    id: 'R_LkPa',
    name: 'Gas Constant (L kPa)',
    symbol: 'R',
    value: rLkPa,
    unit: 'L · kPa / (mol · K)',
    category: 'Gas constants',
    description: 'R with pressure in kilopascals and volume in litres (equals the joule value)',
  ),
  const PhysicalConstant(
    id: 'R_cal',
    name: 'Gas Constant (calorie)',
    symbol: 'R',
    value: rCal,
    unit: 'cal / (mol · K)',
    category: 'Gas constants',
    description: 'R in thermochemical calories: 8.314462618 / 4.184',
  ),
  _fromPhysics('kB', category: 'Gas constants'),
  const PhysicalConstant(
    id: 'atm',
    name: 'Standard Atmosphere',
    symbol: 'atm',
    value: atmPa,
    unit: 'Pa',
    category: 'Standard conditions',
    description: 'Exactly 101325 Pa',
  ),
  const PhysicalConstant(
    id: 'Vm_273_1atm',
    name: 'Molar Volume of an Ideal Gas (0 °C, 1 atm)',
    symbol: 'Vm',
    value: _molarVolume0C1atm,
    unit: 'L / mol',
    category: 'Standard conditions',
    description: '273.15 K and 101.325 kPa (older STP). Computed as RT/p',
  ),
  const PhysicalConstant(
    id: 'Vm_273_1bar',
    name: 'Molar Volume of an Ideal Gas (273.15 K, 1 bar)',
    symbol: 'Vm',
    value: _molarVolume0C1bar,
    unit: 'L / mol',
    category: 'Standard conditions',
    description: '273.15 K and 100 kPa (IUPAC STP since 1982). Computed as RT/p',
  ),
  const PhysicalConstant(
    id: 'T0',
    name: 'Zero Celsius',
    symbol: '0 °C',
    value: zeroCelsiusK,
    unit: 'K',
    category: 'Standard conditions',
    description: 'Exactly 273.15 K',
  ),
  const PhysicalConstant(
    id: 'F',
    name: 'Faraday Constant',
    symbol: 'F',
    value: faraday,
    unit: 'C / mol',
    category: 'Electrochemistry',
    description: 'Charge of one mole of electrons: NA × e',
  ),
  _fromPhysics('e', category: 'Electrochemistry'),
  const PhysicalConstant(
    id: 'Kw',
    name: 'Ion Product of Water (25 °C)',
    symbol: 'Kw',
    value: kw25,
    unit: '',
    category: 'Water & solutions',
    description: '[H⁺][OH⁻] at 25 °C, the usual textbook value (more precisely 1.008 × 10⁻¹⁴)',
  ),
  const PhysicalConstant(
    id: 'c_water',
    name: 'Specific Heat of Liquid Water',
    symbol: 'c',
    value: 4.184,
    unit: 'J / (g · K)',
    category: 'Water & solutions',
    description: 'Thermochemical value near 25 °C',
  ),
  const PhysicalConstant(
    id: 'Kf_water',
    name: 'Cryoscopic Constant of Water',
    symbol: 'Kf',
    value: 1.86,
    unit: 'K · kg / mol',
    category: 'Water & solutions',
    description: 'Freezing-point depression per molal of solute (textbook value)',
  ),
  const PhysicalConstant(
    id: 'Kb_water',
    name: 'Ebullioscopic Constant of Water',
    symbol: 'Kb',
    value: 0.512,
    unit: 'K · kg / mol',
    category: 'Water & solutions',
    description: 'Boiling-point elevation per molal of solute (textbook value)',
  ),
  _fromPhysics('h', category: 'Atoms & particles'),
  _fromPhysics('me', category: 'Atoms & particles'),
  _fromPhysics('mp', category: 'Atoms & particles'),
  _fromPhysics('mn', category: 'Atoms & particles'),
  _fromPhysics('u', category: 'Atoms & particles'),
  const PhysicalConstant(
    id: 'u_MeV',
    name: 'Atomic Mass Unit in Energy',
    symbol: 'u·c²',
    value: uMeV,
    unit: 'MeV',
    category: 'Atoms & particles',
    description: 'Energy equivalent of 1 u (CODATA 2018)',
  ),
  _fromPhysics('Rydberg', category: 'Atoms & particles'),
  const PhysicalConstant(
    id: 'Ry_eV',
    name: 'Rydberg Energy',
    symbol: 'hcR∞',
    value: rydbergEv,
    unit: 'eV',
    category: 'Atoms & particles',
    description: 'Ionisation energy of hydrogen in the Bohr model (CODATA 2018)',
  ),
  _fromPhysics('a0', category: 'Atoms & particles'),
];
