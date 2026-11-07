/**
 * Generates the large static tables of the Dart engine mechanically from the TypeScript source, so nothing is typed by hand.
 *
 *   npx tsx flutter_app/tools/gen_engine_data.ts            # (re)write the three generated Dart files
 *   npx tsx flutter_app/tools/gen_engine_data.ts --check    # fail if the committed files differ from a fresh generation
 *
 * Output (do not edit by hand, re-run this script instead):
 *   lib/engine/units_data.dart          <- src/engine/units.ts           (parsed from the source text: the lambdas are copied verbatim)
 *   lib/engine/physics_constants.dart   <- src/engine/physics.ts         (PHYSICAL_CONSTANTS, imported)
 *   lib/engine/currency_data.dart       <- src/engine/currency.ts        (POPULAR_CURRENCIES + DEFAULT_RATES_USD, imported)
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PHYSICAL_CONSTANTS } from '../../src/engine/physics';
import { POPULAR_CURRENCIES, DEFAULT_RATES_USD } from '../../src/engine/currency';

const here = path.dirname(fileURLToPath(import.meta.url));
const libDir = path.join(here, '..', 'lib', 'engine');
const srcDir = path.join(here, '..', '..', 'src', 'engine');
const check = process.argv.includes('--check');

const HEADER = (src: string) =>
  `// GENERATED FILE - DO NOT EDIT.\n// Source of truth: ${src}\n// Regenerate with: npx tsx flutter_app/tools/gen_engine_data.ts\n`;

/** Dart string literal (single quotes). */
const str = (s: string): string =>
  `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n')}'`;

/** Dart double literal that parses to exactly the same value as the JS number. */
const dbl = (n: number): string => {
  const s = String(n);
  return /^-?\d+$/.test(s) ? `${s}.0` : s;
};

// ---------------------------------------------------------------------------------------------------------------------
// units_data.dart  (parsed from the TS source text)
// ---------------------------------------------------------------------------------------------------------------------
function genUnits(): string {
  const text = fs.readFileSync(path.join(srcDir, 'units.ts'), 'utf8');
  const body = text.slice(text.indexOf('export const UNIT_CATEGORIES'), text.indexOf('export function convertUnit'));
  const lines = body.split('\n');

  const unitRe =
    /^\s{6}\{ id: '([^']+)', name: '([^']+)', symbol: '([^']+)', toBase: \(v\) => (.+?), fromBase: \(v\) => (.+?) \},?\s*$/;
  const toDart = (expr: string) => expr.replace(/Math\.PI/g, 'math.pi');

  type Cat = { id: string; name: string; iconName: string; baseUnit: string; units: string[] };
  const cats: Cat[] = [];
  let cur: Cat | null = null;
  let unitCount = 0;
  for (const line of lines) {
    let m: RegExpMatchArray | null;
    if ((m = line.match(/^ {4}id: '([^']+)',\s*$/))) {
      cur = { id: m[1], name: '', iconName: '', baseUnit: '', units: [] };
      cats.push(cur);
    } else if (cur && (m = line.match(/^ {4}name: '([^']+)',\s*$/))) cur.name = m[1];
    else if (cur && (m = line.match(/^ {4}iconName: '([^']+)',\s*$/))) cur.iconName = m[1];
    else if (cur && (m = line.match(/^ {4}baseUnit: '([^']+)',\s*$/))) cur.baseUnit = m[1];
    else if (cur && (m = line.match(unitRe))) {
      unitCount++;
      cur.units.push(
        `      UnitDefinition(id: ${str(m[1])}, name: ${str(m[2])}, symbol: ${str(m[3])}, ` +
          `toBase: (double v) => ${toDart(m[4])}, fromBase: (double v) => ${toDart(m[5])}),`
      );
    } else if (/toBase:/.test(line)) {
      throw new Error(`units.ts: unit line not understood by the generator: ${line.trim()}`);
    }
  }
  const declared = (body.match(/toBase:/g) || []).length;
  if (unitCount !== declared) throw new Error(`units.ts: parsed ${unitCount} units but the source has ${declared}`);
  if (cats.some((c) => !c.name || !c.iconName || !c.baseUnit || c.units.length === 0)) throw new Error('units.ts: incomplete category');

  let out = HEADER('src/engine/units.ts (UNIT_CATEGORIES)');
  out += `\nimport 'dart:math' as math;\n\nimport 'unit_types.dart';\n\n`;
  out += `/// The 13 converter categories, in the same order as the web app.\n`;
  out += `final List<UnitCategory> unitCategories = [\n`;
  for (const c of cats) {
    out += `  UnitCategory(\n    id: ${str(c.id)},\n    name: ${str(c.name)},\n    iconName: ${str(c.iconName)},\n    baseUnit: ${str(c.baseUnit)},\n    units: [\n`;
    out += c.units.join('\n') + '\n    ],\n  ),\n';
  }
  out += `];\n`;
  return out;
}

// ---------------------------------------------------------------------------------------------------------------------
// physics_constants.dart
// ---------------------------------------------------------------------------------------------------------------------
function genPhysicsConstants(): string {
  let out = HEADER('src/engine/physics.ts (PHYSICAL_CONSTANTS)');
  out += `\n/// Same shape as \`PhysicalConstant\` in the web app. The category is one of: 'Universal', 'Mechanics',\n/// 'Electromagnetism', 'Quantum & Atomic', 'Thermodynamics', 'Astrophysics'.\n`;
  out += `class PhysicalConstant {\n  final String id;\n  final String name;\n  final String symbol;\n  final double value;\n  final String unit;\n  final String category;\n  final String description;\n\n`;
  out += `  const PhysicalConstant({\n    required this.id,\n    required this.name,\n    required this.symbol,\n    required this.value,\n    required this.unit,\n    required this.category,\n    required this.description,\n  });\n}\n\n`;
  out += `const List<PhysicalConstant> physicalConstants = [\n`;
  for (const c of PHYSICAL_CONSTANTS) {
    out += `  PhysicalConstant(\n    id: ${str(c.id)},\n    name: ${str(c.name)},\n    symbol: ${str(c.symbol)},\n    value: ${dbl(c.value)},\n    unit: ${str(c.unit)},\n    category: ${str(c.category)},\n    description: ${str(c.description)},\n  ),\n`;
  }
  out += `];\n`;
  return out;
}

// ---------------------------------------------------------------------------------------------------------------------
// currency_data.dart
// ---------------------------------------------------------------------------------------------------------------------
function genCurrencyData(): string {
  let out = HEADER('src/engine/currency.ts (POPULAR_CURRENCIES, DEFAULT_RATES_USD)');
  out += `\nclass CurrencyItem {\n  final String code;\n  final String name;\n  final String symbol;\n  final String flag;\n\n  const CurrencyItem({required this.code, required this.name, required this.symbol, required this.flag});\n}\n\n`;
  out += `const List<CurrencyItem> popularCurrencies = [\n`;
  for (const c of POPULAR_CURRENCIES)
    out += `  CurrencyItem(code: ${str(c.code)}, name: ${str(c.name)}, symbol: ${str(c.symbol)}, flag: ${str(c.flag)}),\n`;
  out += `];\n\n/// Fallback rates relative to USD (USD = 1.0).\nconst Map<String, double> defaultRatesUsd = {\n`;
  for (const [code, v] of Object.entries(DEFAULT_RATES_USD)) out += `  ${str(code)}: ${dbl(v)},\n`;
  out += `};\n`;
  return out;
}

const files: Record<string, string> = {
  'units_data.dart': genUnits(),
  'physics_constants.dart': genPhysicsConstants(),
  'currency_data.dart': genCurrencyData(),
};

let failed = false;
for (const [name, content] of Object.entries(files)) {
  const file = path.join(libDir, name);
  if (check) {
    const same = fs.existsSync(file) && fs.readFileSync(file, 'utf8') === content;
    console.log(`${same ? 'OK     ' : 'DIFFERS'} ${name}`);
    if (!same) failed = true;
  } else {
    fs.writeFileSync(file, content);
    console.log(`wrote ${name}`);
  }
}
if (failed) process.exit(1);
