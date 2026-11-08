/**
 * Guide generator (Phase 5f). Reads the in-app user guide from src/guideContent.ts and writes, mechanically:
 *
 *   lib/ui/overlays/guide_content.dart   the guide text as Dart constants (no sentence is typed by hand)
 *   test/golden/guide.json               what the REAL TypeScript engine shows for every example, computed exactly the way
 *                                        GuideSheet.tsx `runExample` does it (the Dart tests compare the Dart engine to it)
 *
 *   npx tsx flutter_app/tools/gen_guide.ts            # (re)write both files
 *   npx tsx flutter_app/tools/gen_guide.ts --check    # fail if the committed files differ from a fresh generation
 *
 * Run again whenever src/guideContent.ts or src/engine/evaluator.ts changes.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MathEvaluator } from '../../src/engine/evaluator';
import { GUIDE_QUICK_START, GUIDE_SECTIONS, GUIDE_TIPS, GuideExample } from '../../src/guideContent';

const here = path.dirname(fileURLToPath(import.meta.url));
const dartFile = path.join(here, '..', 'lib', 'ui', 'overlays', 'guide_content.dart');
const jsonFile = path.join(here, '..', 'test', 'golden', 'guide.json');
const check = process.argv.includes('--check');

/** A Dart single-quoted string literal. */
const q = (s: string): string =>
  `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n')}'`;
const opt = (v: string | undefined): string => (v === undefined ? 'null' : q(v));
const optAngle = (v: string | undefined): string => (v === undefined ? 'null' : v === 'rad' ? 'AngleMode.rad' : 'AngleMode.deg');
/** A list literal; `const` only at the top level (inside a const list it would be redundant). */
const list = (items: string[], indent: string, constant = false): string => {
  const kw = constant ? 'const ' : '';
  return items.length === 0 ? `${kw}<String>[]` : `${kw}<String>[\n${items.map((i) => `${indent}  ${q(i)},`).join('\n')}\n${indent}]`;
};

/** GuideSheet.tsx `runExample`, line for line. */
function runExample(ex: GuideExample) {
  if (/^y\s*=/i.test(ex.expr)) return { text: 'Saved. Now type an x value and press =', isError: false, plain: true };
  const previous = MathEvaluator.getYDefinition();
  try {
    if (ex.setup) MathEvaluator.setYDefinition(ex.setup);
    const value = MathEvaluator.evaluate(ex.expr, ex.angle ?? 'deg');
    return { text: MathEvaluator.formatResult(value, -1), isError: false, plain: false };
  } catch (err) {
    return { text: err instanceof Error ? err.message : 'Error', isError: true, plain: false };
  } finally {
    if (ex.setup) MathEvaluator.setYDefinition(previous);
  }
}

const dart = `// GENERATED FILE - DO NOT EDIT.
// Source of truth: src/guideContent.ts (GUIDE_QUICK_START, GUIDE_SECTIONS, GUIDE_TIPS).
// Regenerate with: npx tsx flutter_app/tools/gen_guide.ts

import '../../engine/types.dart';

/// \`GuideExample\`.
class GuideExample {
  const GuideExample({required this.expr, required this.note, this.angle, this.setup, this.load});

  /// Exactly what is typed into the calculator (uses the keypad symbols × ÷ −).
  final String expr;
  final String note;

  /// Angle unit the example needs; "Try" switches to it.
  final AngleMode? angle;

  /// Equation (written in x) saved before this example is evaluated, for examples that call y(x).
  final String? setup;

  /// What the Try button types instead of [expr].
  final String? load;
}

/// \`GuideSection\`.
class GuideSection {
  const GuideSection({
    required this.id,
    required this.badge,
    required this.title,
    required this.summary,
    this.where,
    this.syntax,
    this.steps,
    required this.examples,
    this.tips,
  });

  final String id;
  final String badge;
  final String title;
  final String summary;
  final String? where;
  final String? syntax;
  final List<String>? steps;
  final List<GuideExample> examples;
  final List<String>? tips;
}

const List<String> kGuideQuickStart = ${list(GUIDE_QUICK_START, '')};

const List<GuideSection> kGuideSections = <GuideSection>[
${GUIDE_SECTIONS.map(
  (s) => `  GuideSection(
    id: ${q(s.id)},
    badge: ${q(s.badge)},
    title: ${q(s.title)},
    summary: ${q(s.summary)},
    where: ${opt(s.where)},
    syntax: ${opt(s.syntax)},
    steps: ${s.steps ? list(s.steps, '    ') : 'null'},
    examples: <GuideExample>[
${s.examples
  .map(
    (e) =>
      `      GuideExample(expr: ${q(e.expr)}, note: ${q(e.note)}, angle: ${optAngle(e.angle)}, setup: ${opt(e.setup)}, load: ${opt(e.load)}),`,
  )
  .join('\n')}
    ],
    tips: ${s.tips ? list(s.tips, '    ') : 'null'},
  ),`,
).join('\n')}
];

const List<String> kGuideTips = ${list(GUIDE_TIPS, '')};
`;

const json = JSON.stringify(
  GUIDE_SECTIONS.flatMap((s) =>
    s.examples.map((e) => {
      MathEvaluator.setYDefinition(null);
      return { section: s.id, expr: e.expr, angle: e.angle ?? null, setup: e.setup ?? null, ...runExample(e) };
    }),
  ),
);

const files: [string, string][] = [
  [dartFile, dart],
  [jsonFile, json],
];

if (check) {
  let bad = false;
  for (const [f, text] of files) {
    const current = fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : '';
    if (current !== text) {
      console.error(`${path.relative(process.cwd(), f)} is out of date. Run: npx tsx flutter_app/tools/gen_guide.ts`);
      bad = true;
    }
  }
  if (bad) process.exit(1);
  console.log(`OK: guide content (${GUIDE_SECTIONS.length} sections) and vectors match the web source.`);
} else {
  fs.mkdirSync(path.dirname(dartFile), { recursive: true });
  for (const [f, text] of files) fs.writeFileSync(f, text);
  console.log(`Wrote guide_content.dart and guide.json: ${GUIDE_SECTIONS.length} sections, ${JSON.parse(json).length} examples.`);
}
