// The 40 metric conversion commands of the fx-991ES PLUS (CONV, manual p.53-55). Factors: NIST Special Publication 811
// (2008), the source the manual names. Entry 17/18 (parsec) and 39/40 (calorie) are the ones to confirm on a real unit.

class CasioConversion {
  const CasioConversion(this.no, this.label, this.factor, {this.offset = 0, this.fromFahrenheit = false});

  final int no;
  final String label;

  /// result = value * factor (+ offset for the temperature pair)
  final double factor;
  final double offset;
  final bool fromFahrenheit;

  double apply(double x) {
    if (no == 37) return (x - 32) / 1.8; // °F -> °C
    if (no == 38) return x * 1.8 + 32; // °C -> °F
    return x * factor;
  }
}

const double _in = 2.54; // cm
const double _ft = 0.3048;
const double _yd = 0.9144;
const double _mile = 1.609344; // km
const double _nmile = 1852; // m
const double _acre = 4046.8564224; // m^2
const double _galUs = 3.785411784; // l
const double _galUk = 4.54609; // l
const double _pc = 3.0856775814913673e13; // km (IAU 2015; NIST SP 811 gives 3.085 678e16 m)
const double _kmh = 1 / 3.6;
const double _oz = 28.349523125; // g
const double _lb = 0.45359237; // kg
const double _atm = 101325; // Pa
const double _mmHg = 133.322387415; // Pa (conventional)
const double _hp = 0.7456998715822702; // kW
const double _kgfCm2 = 98066.5; // Pa
const double _kgfM = 9.80665; // J
const double _psi = 6.894757293168361; // kPa
const double _cal = 4.1855; // J (15 °C)

const List<CasioConversion> kCasioConversions = <CasioConversion>[
  CasioConversion(1, 'in→cm', _in),
  CasioConversion(2, 'cm→in', 1 / _in),
  CasioConversion(3, 'ft→m', _ft),
  CasioConversion(4, 'm→ft', 1 / _ft),
  CasioConversion(5, 'yd→m', _yd),
  CasioConversion(6, 'm→yd', 1 / _yd),
  CasioConversion(7, 'mile→km', _mile),
  CasioConversion(8, 'km→mile', 1 / _mile),
  CasioConversion(9, 'n mile→m', _nmile),
  CasioConversion(10, 'm→n mile', 1 / _nmile),
  CasioConversion(11, 'acre→m²', _acre),
  CasioConversion(12, 'm²→acre', 1 / _acre),
  CasioConversion(13, 'gal(US)→ℓ', _galUs),
  CasioConversion(14, 'ℓ→gal(US)', 1 / _galUs),
  CasioConversion(15, 'gal(UK)→ℓ', _galUk),
  CasioConversion(16, 'ℓ→gal(UK)', 1 / _galUk),
  CasioConversion(17, 'pc→km', _pc),
  CasioConversion(18, 'km→pc', 1 / _pc),
  CasioConversion(19, 'km/h→m/s', _kmh),
  CasioConversion(20, 'm/s→km/h', 3.6),
  CasioConversion(21, 'oz→g', _oz),
  CasioConversion(22, 'g→oz', 1 / _oz),
  CasioConversion(23, 'lb→kg', _lb),
  CasioConversion(24, 'kg→lb', 1 / _lb),
  CasioConversion(25, 'atm→Pa', _atm),
  CasioConversion(26, 'Pa→atm', 1 / _atm),
  CasioConversion(27, 'mmHg→Pa', _mmHg),
  CasioConversion(28, 'Pa→mmHg', 1 / _mmHg),
  CasioConversion(29, 'hp→kW', _hp),
  CasioConversion(30, 'kW→hp', 1 / _hp),
  CasioConversion(31, 'kgf/cm²→Pa', _kgfCm2),
  CasioConversion(32, 'Pa→kgf/cm²', 1 / _kgfCm2),
  CasioConversion(33, 'kgf·m→J', _kgfM),
  CasioConversion(34, 'J→kgf·m', 1 / _kgfM),
  CasioConversion(35, 'lbf/in²→kPa', _psi),
  CasioConversion(36, 'kPa→lbf/in²', 1 / _psi),
  CasioConversion(37, '°F→°C', 1),
  CasioConversion(38, '°C→°F', 1),
  CasioConversion(39, 'J→cal', 1 / _cal),
  CasioConversion(40, 'cal→J', _cal),
];
