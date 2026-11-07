/**
 * Golden-vector generator. Imports the REAL TypeScript engine and records what it returns for the inputs in
 * tools/vector_inputs/*.json, writing test/golden/<name>.json. Never hand-edit the output vectors.
 *
 *   npx tsx flutter_app/tools/gen_vectors.ts            # regenerate test/golden/{evaluator,evaluate_function,format,round}.json
 *   npx tsx flutter_app/tools/gen_vectors.ts --check    # regenerate in memory and fail if it differs from the committed files
 *
 * To add coverage, append inputs to the matching tools/vector_inputs file and re-run. Run again whenever
 * src/engine/evaluator.ts changes. Phase 2 extends this to units, finance, swp, currency and physics.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import { MathEvaluator } from '../../src/engine/evaluator';
import { UNIT_CATEGORIES, convertUnit } from '../../src/engine/units';
import { FinanceEngine } from '../../src/engine/finance';
import { PhysicsSolver } from '../../src/engine/physics';
import { convertCurrency, DEFAULT_RATES_USD } from '../../src/engine/currency';

const here = path.dirname(fileURLToPath(import.meta.url));
const inputsDir = path.join(here, 'vector_inputs');
const outDir = path.join(here, '..', 'test', 'golden');
const check = process.argv.includes('--check');

/** String(v), except negative zero which is written "-0" so the Dart tests can check the sign. */
const num = (v: number): string => (Object.is(v, -0) ? '-0' : String(v));
const parse = (s: string): number =>
  s === 'NaN' ? NaN : s === 'Infinity' ? Infinity : s === '-Infinity' ? -Infinity : Number(s);
const readInputs = (name: string) => JSON.parse(fs.readFileSync(path.join(inputsDir, `${name}.json`), 'utf8'));

type Mode = 'deg' | 'rad';

function genEvaluator() {
  return readInputs('evaluator').map((i: { expr: string; mode: Mode; yDef?: string }) => {
    MathEvaluator.setYDefinition(i.yDef ?? null);
    const base: Record<string, unknown> = { expr: i.expr, mode: i.mode };
    try {
      const v = MathEvaluator.evaluate(i.expr, i.mode);
      base.value = num(v);
      // Vectors that save a y = f(x) equation only record the automatic format (as in the original golden.zip).
      base.fmt =
        i.yDef !== undefined
          ? { auto: MathEvaluator.formatResult(v, -1) }
          : {
              auto: MathEvaluator.formatResult(v, -1),
              p2: MathEvaluator.formatResult(v, 2),
              p4: MathEvaluator.formatResult(v, 4),
              p6: MathEvaluator.formatResult(v, 6),
              p8: MathEvaluator.formatResult(v, 8),
            };
    } catch (e) {
      base.error = e instanceof Error ? e.message : String(e);
    }
    if (i.yDef !== undefined) base.yDef = i.yDef;
    MathEvaluator.setYDefinition(null);
    return base;
  });
}

function genEvaluateFunction() {
  return readInputs('evaluate_function').map((i: { expr: string; x: string; mode: Mode }) => ({
    expr: i.expr,
    x: i.x,
    mode: i.mode,
    value: num(MathEvaluator.evaluateFunction(i.expr, parse(i.x), i.mode)),
  }));
}

function genFormat() {
  const orNull = (v: number, f: (n: number) => string) => (Number.isFinite(v) ? f(v) : null);
  return readInputs('format').map((s: string) => {
    const v = parse(s);
    const fmt: Record<string, string> = {};
    for (const p of [0, 1, 2, 4, 6, 8, -1]) fmt[String(p)] = MathEvaluator.formatResult(v, p);
    return {
      v: num(v),
      tostr: String(v),
      prec12: orNull(v, (n) => n.toPrecision(12)),
      prec6: orNull(v, (n) => n.toPrecision(6)),
      fixed2: orNull(v, (n) => n.toFixed(2)),
      fixed4: orNull(v, (n) => n.toFixed(4)),
      fixed8: orNull(v, (n) => n.toFixed(8)),
      exp4: orNull(v, (n) => n.toExponential(4)),
      exp6: orNull(v, (n) => n.toExponential(6)),
      round: num(Math.round(v)),
      fmt,
    };
  });
}

function genRound() {
  return readInputs('round').map((s: string) => ({ v: s, r: num(Math.round(parse(s))) }));
}

// ---------------------------------------------------------------------------------------------------------------------
// Phase 2 engines. Numbers are written as { n: "<JS String(v)>" } (so NaN, Infinity and -0 survive JSON); null stays null.
// ---------------------------------------------------------------------------------------------------------------------
function enc(v: unknown): unknown {
  if (typeof v === 'number') return { n: num(v) };
  if (Array.isArray(v)) return v.map(enc);
  if (v !== null && typeof v === 'object') {
    const o: Record<string, unknown> = {};
    for (const [k, x] of Object.entries(v as Record<string, unknown>)) o[k] = enc(x);
    return o;
  }
  return v;
}

function genUnits() {
  const { values, extra } = readInputs('units') as { values: string[]; extra: { c: string; a: string; b: string; v: string }[] };
  const one = (c: string, a: string, b: string, v: string) => {
    const cat = UNIT_CATEGORIES.find((x) => x.id === c)!;
    const { result, formula } = convertUnit(parse(v), cat, a, b);
    return { c, a, b, v, r: num(result), f: formula };
  };
  const out: ReturnType<typeof one>[] = [];
  for (const cat of UNIT_CATEGORIES)
    for (const a of cat.units) for (const b of cat.units) for (const v of values) out.push(one(cat.id, a.id, b.id, v));
  for (const e of extra) out.push(one(e.c, e.a, e.b, e.v));
  return out;
}

function genUnitCatalog() {
  return UNIT_CATEGORIES.map((c) => ({
    id: c.id,
    name: c.name,
    iconName: c.iconName,
    baseUnit: c.baseUnit,
    units: c.units.map((u) => ({ id: u.id, name: u.name, symbol: u.symbol })),
  }));
}

function genLoan() {
  return readInputs('loan').map((i: { p: number; r: number; t: number; o: unknown }) => ({
    in: i,
    out: enc(FinanceEngine.calculateLoan(i.p, i.r, i.t, (i.o ?? undefined) as never)),
  }));
}

const withOut = (name: string, f: (...a: any[]) => unknown) =>
  readInputs(name).map((i: unknown[]) => ({ in: i, out: enc(f(...i)) }));

function genTip() {
  return readInputs('tip').map((i: [string, string, string, boolean?]) => ({
    in: i,
    out: enc(FinanceEngine.calculateTip(parse(i[0]), parse(i[1]), parse(i[2]), i[3])),
  }));
}

function genSwp() {
  return readInputs('swp').map((i: unknown) => {
    const out = Array.isArray(i)
      ? FinanceEngine.calculateSWP(...((i as string[]).map(parse) as [number, number?, number?, number?, number?]))
      : FinanceEngine.calculateSWP(i as never);
    return { in: i, out: enc(out) };
  });
}

function genCurrency() {
  return readInputs('currency').map((i: [string, string, string]) => ({
    in: i,
    out: enc(convertCurrency(parse(i[0]), i[1], i[2], DEFAULT_RATES_USD)),
  }));
}

const outputs: Record<string, unknown> = {
  evaluator: genEvaluator(),
  evaluate_function: genEvaluateFunction(),
  format: genFormat(),
  round: genRound(),
  units: genUnits(),
  unit_catalog: genUnitCatalog(),
  loan: genLoan(),
  compound: withOut('compound', (...a) => FinanceEngine.calculateCompoundInterest(...(a as [number, number, number, number]))),
  tip: genTip(),
  roi: withOut('roi', (...a) => FinanceEngine.calculateROI(...(a as [number, number, number]))),
  depreciation: withOut('depreciation', (...a) => FinanceEngine.calculateDepreciation(...(a as [number, number, number]))),
  swp: genSwp(),
  currency: genCurrency(),
  projectile: withOut('projectile', (...a) => PhysicsSolver.solveProjectile(...(a as [number, number]))),
  relativity: withOut('relativity', (...a) => PhysicsSolver.solveRelativity(...(a as [number]))),
  electromagnetism: withOut('electromagnetism', (...a) => PhysicsSolver.solveElectromagnetism(...(a as [number, number, number]))),
  photon: withOut('photon', (...a) => PhysicsSolver.solvePhotonWave(...(a as ['wavelength', number]))),
};

let failed = false;
for (const [name, data] of Object.entries(outputs)) {
  const file = path.join(outDir, `${name}.json`);
  if (check) {
    const same = isDeepStrictEqual(JSON.parse(fs.readFileSync(file, 'utf8')), JSON.parse(JSON.stringify(data)));
    console.log(`${same ? 'OK     ' : 'DIFFERS'} ${name}.json (${(data as unknown[]).length} vectors)`);
    if (!same) failed = true;
  } else {
    fs.writeFileSync(file, JSON.stringify(data));
    console.log(`wrote ${name}.json (${(data as unknown[]).length} vectors)`);
  }
}
if (failed) process.exit(1);
