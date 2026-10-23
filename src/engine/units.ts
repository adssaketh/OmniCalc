import { UnitCategory } from '../types';

export const UNIT_CATEGORIES: UnitCategory[] = [
  {
    id: 'length',
    name: 'Length',
    iconName: 'Ruler',
    baseUnit: 'm',
    units: [
      { id: 'm', name: 'Meter', symbol: 'm', toBase: (v) => v, fromBase: (v) => v },
      { id: 'km', name: 'Kilometer', symbol: 'km', toBase: (v) => v * 1000, fromBase: (v) => v / 1000 },
      { id: 'cm', name: 'Centimeter', symbol: 'cm', toBase: (v) => v / 100, fromBase: (v) => v * 100 },
      { id: 'mm', name: 'Millimeter', symbol: 'mm', toBase: (v) => v / 1000, fromBase: (v) => v * 1000 },
      { id: 'in', name: 'Inch', symbol: 'in', toBase: (v) => v * 0.0254, fromBase: (v) => v / 0.0254 },
      { id: 'ft', name: 'Foot', symbol: 'ft', toBase: (v) => v * 0.3048, fromBase: (v) => v / 0.3048 },
      { id: 'yd', name: 'Yard', symbol: 'yd', toBase: (v) => v * 0.9144, fromBase: (v) => v / 0.9144 },
      { id: 'mi', name: 'Mile', symbol: 'mi', toBase: (v) => v * 1609.344, fromBase: (v) => v / 1609.344 },
      { id: 'nmi', name: 'Nautical Mile', symbol: 'nmi', toBase: (v) => v * 1852, fromBase: (v) => v / 1852 },
    ],
  },
  {
    id: 'mass',
    name: 'Mass & Weight',
    iconName: 'Scale',
    baseUnit: 'kg',
    units: [
      { id: 'kg', name: 'Kilogram', symbol: 'kg', toBase: (v) => v, fromBase: (v) => v },
      { id: 'g', name: 'Gram', symbol: 'g', toBase: (v) => v / 1000, fromBase: (v) => v * 1000 },
      { id: 'mg', name: 'Milligram', symbol: 'mg', toBase: (v) => v / 1e6, fromBase: (v) => v * 1e6 },
      { id: 't', name: 'Metric Ton', symbol: 't', toBase: (v) => v * 1000, fromBase: (v) => v / 1000 },
      { id: 'lb', name: 'Pound', symbol: 'lb', toBase: (v) => v * 0.45359237, fromBase: (v) => v / 0.45359237 },
      { id: 'oz', name: 'Ounce', symbol: 'oz', toBase: (v) => v * 0.0283495231, fromBase: (v) => v / 0.0283495231 },
      { id: 'st', name: 'Stone', symbol: 'st', toBase: (v) => v * 6.35029, fromBase: (v) => v / 6.35029 },
    ],
  },
  {
    id: 'temperature',
    name: 'Temperature',
    iconName: 'Thermometer',
    baseUnit: 'C',
    units: [
      { id: 'C', name: 'Celsius', symbol: '°C', toBase: (v) => v, fromBase: (v) => v },
      { id: 'F', name: 'Fahrenheit', symbol: '°F', toBase: (v) => ((v - 32) * 5) / 9, fromBase: (v) => (v * 9) / 5 + 32 },
      { id: 'K', name: 'Kelvin', symbol: 'K', toBase: (v) => v - 273.15, fromBase: (v) => v + 273.15 },
    ],
  },
  {
    id: 'area',
    name: 'Area',
    iconName: 'Square',
    baseUnit: 'sqm',
    units: [
      { id: 'sqm', name: 'Square Meter', symbol: 'm²', toBase: (v) => v, fromBase: (v) => v },
      { id: 'sqkm', name: 'Square Kilometer', symbol: 'km²', toBase: (v) => v * 1e6, fromBase: (v) => v / 1e6 },
      { id: 'sqft', name: 'Square Foot', symbol: 'ft²', toBase: (v) => v * 0.092903, fromBase: (v) => v / 0.092903 },
      { id: 'sqyd', name: 'Square Yard', symbol: 'yd²', toBase: (v) => v * 0.836127, fromBase: (v) => v / 0.836127 },
      { id: 'acre', name: 'Acre', symbol: 'ac', toBase: (v) => v * 4046.86, fromBase: (v) => v / 4046.86 },
      { id: 'ha', name: 'Hectare', symbol: 'ha', toBase: (v) => v * 10000, fromBase: (v) => v / 10000 },
    ],
  },
  {
    id: 'volume',
    name: 'Volume',
    iconName: 'Box',
    baseUnit: 'l',
    units: [
      { id: 'l', name: 'Liter', symbol: 'L', toBase: (v) => v, fromBase: (v) => v },
      { id: 'ml', name: 'Milliliter', symbol: 'mL', toBase: (v) => v / 1000, fromBase: (v) => v * 1000 },
      { id: 'cum', name: 'Cubic Meter', symbol: 'm³', toBase: (v) => v * 1000, fromBase: (v) => v / 1000 },
      { id: 'gal_us', name: 'Gallon (US)', symbol: 'gal', toBase: (v) => v * 3.78541, fromBase: (v) => v / 3.78541 },
      { id: 'gal_uk', name: 'Gallon (UK)', symbol: 'imp gal', toBase: (v) => v * 4.54609, fromBase: (v) => v / 4.54609 },
      { id: 'qt_us', name: 'Quart (US)', symbol: 'qt', toBase: (v) => v * 0.946353, fromBase: (v) => v / 0.946353 },
      { id: 'pt_us', name: 'Pint (US)', symbol: 'pt', toBase: (v) => v * 0.473176, fromBase: (v) => v / 0.473176 },
      { id: 'cup', name: 'Cup (US)', symbol: 'cup', toBase: (v) => v * 0.236588, fromBase: (v) => v / 0.236588 },
      { id: 'floz_us', name: 'Fluid Ounce (US)', symbol: 'fl oz', toBase: (v) => v * 0.0295735, fromBase: (v) => v / 0.0295735 },
    ],
  },
  {
    id: 'speed',
    name: 'Speed',
    iconName: 'Gauge',
    baseUnit: 'mps',
    units: [
      { id: 'mps', name: 'Meters / second', symbol: 'm/s', toBase: (v) => v, fromBase: (v) => v },
      { id: 'kmh', name: 'Kilometers / hour', symbol: 'km/h', toBase: (v) => v / 3.6, fromBase: (v) => v * 3.6 },
      { id: 'mph', name: 'Miles / hour', symbol: 'mph', toBase: (v) => v * 0.44704, fromBase: (v) => v / 0.44704 },
      { id: 'kn', name: 'Knots', symbol: 'kn', toBase: (v) => v * 0.514444, fromBase: (v) => v / 0.514444 },
      { id: 'fps', name: 'Feet / second', symbol: 'ft/s', toBase: (v) => v * 0.3048, fromBase: (v) => v / 0.3048 },
    ],
  },
  {
    id: 'digital',
    name: 'Digital Data',
    iconName: 'HardDrive',
    baseUnit: 'byte',
    units: [
      { id: 'bit', name: 'Bit', symbol: 'b', toBase: (v) => v / 8, fromBase: (v) => v * 8 },
      { id: 'byte', name: 'Byte', symbol: 'B', toBase: (v) => v, fromBase: (v) => v },
      { id: 'kb', name: 'Kilobyte', symbol: 'KB', toBase: (v) => v * 1024, fromBase: (v) => v / 1024 },
      { id: 'mb', name: 'Megabyte', symbol: 'MB', toBase: (v) => v * 1048576, fromBase: (v) => v / 1048576 },
      { id: 'gb', name: 'Gigabyte', symbol: 'GB', toBase: (v) => v * 1073741824, fromBase: (v) => v / 1073741824 },
      { id: 'tb', name: 'Terabyte', symbol: 'TB', toBase: (v) => v * 1099511627776, fromBase: (v) => v / 1099511627776 },
      { id: 'pb', name: 'Petabyte', symbol: 'PB', toBase: (v) => v * 1.1258999e15, fromBase: (v) => v / 1.1258999e15 },
    ],
  },
  {
    id: 'time',
    name: 'Time',
    iconName: 'Clock',
    baseUnit: 's',
    units: [
      { id: 'ms', name: 'Millisecond', symbol: 'ms', toBase: (v) => v / 1000, fromBase: (v) => v * 1000 },
      { id: 's', name: 'Second', symbol: 's', toBase: (v) => v, fromBase: (v) => v },
      { id: 'min', name: 'Minute', symbol: 'min', toBase: (v) => v * 60, fromBase: (v) => v / 60 },
      { id: 'h', name: 'Hour', symbol: 'h', toBase: (v) => v * 3600, fromBase: (v) => v / 3600 },
      { id: 'd', name: 'Day', symbol: 'd', toBase: (v) => v * 86400, fromBase: (v) => v / 86400 },
      { id: 'wk', name: 'Week', symbol: 'wk', toBase: (v) => v * 604800, fromBase: (v) => v / 604800 },
      { id: 'mo', name: 'Month (avg)', symbol: 'mo', toBase: (v) => v * 2629800, fromBase: (v) => v / 2629800 },
      { id: 'yr', name: 'Year (365d)', symbol: 'yr', toBase: (v) => v * 31536000, fromBase: (v) => v / 31536000 },
    ],
  },
  {
    id: 'pressure',
    name: 'Pressure',
    iconName: 'Activity',
    baseUnit: 'pa',
    units: [
      { id: 'pa', name: 'Pascal', symbol: 'Pa', toBase: (v) => v, fromBase: (v) => v },
      { id: 'kpa', name: 'Kilopascal', symbol: 'kPa', toBase: (v) => v * 1000, fromBase: (v) => v / 1000 },
      { id: 'bar', name: 'Bar', symbol: 'bar', toBase: (v) => v * 100000, fromBase: (v) => v / 100000 },
      { id: 'psi', name: 'Pound / sq inch', symbol: 'psi', toBase: (v) => v * 6894.76, fromBase: (v) => v / 6894.76 },
      { id: 'atm', name: 'Atmosphere', symbol: 'atm', toBase: (v) => v * 101325, fromBase: (v) => v / 101325 },
      { id: 'torr', name: 'Torr (mmHg)', symbol: 'Torr', toBase: (v) => v * 133.322, fromBase: (v) => v / 133.322 },
    ],
  },
  {
    id: 'energy',
    name: 'Energy',
    iconName: 'Zap',
    baseUnit: 'j',
    units: [
      { id: 'j', name: 'Joule', symbol: 'J', toBase: (v) => v, fromBase: (v) => v },
      { id: 'kj', name: 'Kilojoule', symbol: 'kJ', toBase: (v) => v * 1000, fromBase: (v) => v / 1000 },
      { id: 'ev', name: 'Electronvolt', symbol: 'eV', toBase: (v) => v * 1.602176634e-19, fromBase: (v) => v / 1.602176634e-19 },
      { id: 'kev', name: 'Kiloelectronvolt', symbol: 'keV', toBase: (v) => v * 1.602176634e-16, fromBase: (v) => v / 1.602176634e-16 },
      { id: 'mev', name: 'Megaelectronvolt', symbol: 'MeV', toBase: (v) => v * 1.602176634e-13, fromBase: (v) => v / 1.602176634e-13 },
      { id: 'gev', name: 'Gigaelectronvolt', symbol: 'GeV', toBase: (v) => v * 1.602176634e-10, fromBase: (v) => v / 1.602176634e-10 },
      { id: 'cal', name: 'Calorie', symbol: 'cal', toBase: (v) => v * 4.184, fromBase: (v) => v / 4.184 },
      { id: 'kcal', name: 'Kilocalorie (Food)', symbol: 'kcal', toBase: (v) => v * 4184, fromBase: (v) => v / 4184 },
      { id: 'wh', name: 'Watt-hour', symbol: 'Wh', toBase: (v) => v * 3600, fromBase: (v) => v / 3600 },
      { id: 'kwh', name: 'Kilowatt-hour', symbol: 'kWh', toBase: (v) => v * 3.6e6, fromBase: (v) => v / 3.6e6 },
      { id: 'btu', name: 'BTU', symbol: 'BTU', toBase: (v) => v * 1055.06, fromBase: (v) => v / 1055.06 },
    ],
  },
  {
    id: 'force',
    name: 'Force',
    iconName: 'Compass',
    baseUnit: 'n',
    units: [
      { id: 'n', name: 'Newton', symbol: 'N', toBase: (v) => v, fromBase: (v) => v },
      { id: 'kn', name: 'Kilonewton', symbol: 'kN', toBase: (v) => v * 1000, fromBase: (v) => v / 1000 },
      { id: 'dyn', name: 'Dyne', symbol: 'dyn', toBase: (v) => v * 1e-5, fromBase: (v) => v * 1e5 },
      { id: 'lbf', name: 'Pound-force', symbol: 'lbf', toBase: (v) => v * 4.44822, fromBase: (v) => v / 4.44822 },
      { id: 'kgf', name: 'Kilogram-force', symbol: 'kgf', toBase: (v) => v * 9.80665, fromBase: (v) => v / 9.80665 },
    ],
  },
  {
    id: 'frequency',
    name: 'Frequency',
    iconName: 'Activity',
    baseUnit: 'hz',
    units: [
      { id: 'hz', name: 'Hertz', symbol: 'Hz', toBase: (v) => v, fromBase: (v) => v },
      { id: 'khz', name: 'Kilohertz', symbol: 'kHz', toBase: (v) => v * 1000, fromBase: (v) => v / 1000 },
      { id: 'mhz', name: 'Megahertz', symbol: 'MHz', toBase: (v) => v * 1e6, fromBase: (v) => v / 1e6 },
      { id: 'ghz', name: 'Gigahertz', symbol: 'GHz', toBase: (v) => v * 1e9, fromBase: (v) => v / 1e9 },
      { id: 'thz', name: 'Terahertz', symbol: 'THz', toBase: (v) => v * 1e12, fromBase: (v) => v / 1e12 },
      { id: 'rpm', name: 'Revolutions / min', symbol: 'rpm', toBase: (v) => v / 60, fromBase: (v) => v * 60 },
      { id: 'rads', name: 'Radian / second', symbol: 'rad/s', toBase: (v) => v / (2 * Math.PI), fromBase: (v) => v * 2 * Math.PI },
    ],
  },
  {
    id: 'magnetic',
    name: 'Magnetic Field (B)',
    iconName: 'Magnet',
    baseUnit: 't',
    units: [
      { id: 't', name: 'Tesla', symbol: 'T', toBase: (v) => v, fromBase: (v) => v },
      { id: 'mt', name: 'Millitesla', symbol: 'mT', toBase: (v) => v * 0.001, fromBase: (v) => v * 1000 },
      { id: 'ut', name: 'Microtesla', symbol: 'µT', toBase: (v) => v * 1e-6, fromBase: (v) => v * 1e6 },
      { id: 'g', name: 'Gauss', symbol: 'G', toBase: (v) => v * 1e-4, fromBase: (v) => v * 1e4 },
    ],
  },
];

export function convertUnit(
  value: number,
  category: UnitCategory,
  fromUnitId: string,
  toUnitId: string
): { result: number; formula: string } {
  const fromUnit = category.units.find((u) => u.id === fromUnitId) || category.units[0];
  const toUnit = category.units.find((u) => u.id === toUnitId) || category.units[1];

  if (isNaN(value)) {
    return { result: 0, formula: '' };
  }

  // Base representation
  const baseValue = fromUnit.toBase(value);
  const targetValue = toUnit.fromBase(baseValue);

  // Derive formula text
  let formula = `1 ${fromUnit.symbol} = ${parseFloat(toUnit.fromBase(fromUnit.toBase(1)).toPrecision(6))} ${toUnit.symbol}`;
  if (category.id === 'temperature') {
    if (fromUnitId === 'C' && toUnitId === 'F') formula = '(°C × 9/5) + 32 = °F';
    else if (fromUnitId === 'F' && toUnitId === 'C') formula = '(°F − 32) × 5/9 = °C';
    else if (fromUnitId === 'C' && toUnitId === 'K') formula = '°C + 273.15 = K';
    else if (fromUnitId === 'K' && toUnitId === 'C') formula = 'K − 273.15 = °C';
  }

  return { result: targetValue, formula };
}
