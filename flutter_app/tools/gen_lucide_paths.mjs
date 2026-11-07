/**
 * Turns the lucide icons the calculator screen uses into Dart `Path` building code, mechanically, from the exact
 * lucide-react version the web app depends on (package.json: ^0.546.0). No shape is typed by hand.
 *
 *   node flutter_app/tools/gen_lucide_paths.mjs            # (re)write lib/ui/icons/lucide_icons_generated.dart
 *   node flutter_app/tools/gen_lucide_paths.mjs --check    # fail if the committed file differs from a fresh generation
 *
 * Where lucide-react is read from: $LUCIDE_DIR, else <repo>/node_modules/lucide-react. It must be version 0.546.x
 * (the script refuses anything else, so the file cannot silently drift from what the web app draws).
 *
 * Elements: path, rect (with rx / ry), line, polyline, circle. Path commands: all of M L H V C S Q T A Z, absolute
 * and relative. Every icon is a 24 x 24 stroke icon (stroke 2, round caps and joins, no fill): the painter in
 * lucide_icon.dart draws it that way.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
const outFile = path.join(here, '..', 'lib', 'ui', 'icons', 'lucide_icons_generated.dart');
const check = process.argv.includes('--check');

const ICONS = [
  ['copy', 'Copy'],
  ['check', 'Check'],
  ['delete', 'Delete'],
  ['corner-down-left', 'CornerDownLeft'],
  ['chevron-up', 'ChevronUp'],
  ['rotate-ccw', 'RotateCcw'],
  // Phase 5: converter category tabs (UnitCategory.iconName) and the swap button.
  ['ruler', 'Ruler'],
  ['scale', 'Scale'],
  ['thermometer', 'Thermometer'],
  ['square', 'Square'],
  ['box', 'Box'],
  ['gauge', 'Gauge'],
  ['hard-drive', 'HardDrive'],
  ['clock', 'Clock'],
  ['activity', 'Activity'],
  ['zap', 'Zap'],
  ['compass', 'Compass'],
  ['magnet', 'Magnet'],
  ['arrow-left-right', 'ArrowLeftRight'],
  ['chevron-down', 'ChevronDown'],
];
const WANT_VERSION = /^0\.546\./;

const libDir = process.env.LUCIDE_DIR || path.join(root, 'node_modules', 'lucide-react');
const pkgFile = path.join(libDir, 'package.json');
if (!fs.existsSync(pkgFile)) {
  console.error(`lucide-react not found at ${libDir}. Run "npm ci" in the repo root, or set LUCIDE_DIR.`);
  process.exit(2);
}
const version = JSON.parse(fs.readFileSync(pkgFile, 'utf8')).version;
if (!WANT_VERSION.test(version)) {
  console.error(`lucide-react ${version} found; this generator is pinned to 0.546.x (the web app's version).`);
  process.exit(2);
}

const num = (s) => {
  const n = Number(s);
  if (!Number.isFinite(n)) throw new Error(`Bad number ${s}`);
  return n;
};
const fmt = (n) => {
  const r = Math.round(n * 1e6) / 1e6;
  const s = String(r);
  return /^-?\d+$/.test(s) ? `${s}.0` : s;
};

/** SVG path data -> Dart statements on a Path called `p` (relative commands are resolved to absolute). */
function pathToDart(d, name) {
  const lines = [];
  let i = 0;
  const skip = () => {
    while (i < d.length && /[\s,]/.test(d[i])) i++;
  };
  const readNumber = () => {
    skip();
    const m = /^[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?/.exec(d.slice(i));
    if (!m) throw new Error(`${name}: expected a number at "${d.slice(i, i + 12)}"`);
    i += m[0].length;
    return num(m[0]);
  };
  const readFlag = () => {
    skip();
    const c = d[i];
    if (c !== '0' && c !== '1') throw new Error(`${name}: bad arc flag at "${d.slice(i, i + 12)}"`);
    i++;
    return c === '1';
  };
  let cx = 0;
  let cy = 0;
  let sx = 0;
  let sy = 0;
  let lastC = null; // last cubic control point 2, for S
  let lastQ = null; // last quadratic control point, for T
  let cmd = null;
  while (true) {
    skip();
    if (i >= d.length) break;
    if (/[A-Za-z]/.test(d[i])) cmd = d[i++];
    else if (cmd === 'M') cmd = 'L';
    else if (cmd === 'm') cmd = 'l';
    const rel = cmd === cmd.toLowerCase();
    const C = cmd.toUpperCase();
    const ox = rel ? cx : 0;
    const oy = rel ? cy : 0;
    switch (C) {
      case 'M': {
        const x = ox + readNumber();
        const y = oy + readNumber();
        lines.push(`p.moveTo(${fmt(x)}, ${fmt(y)});`);
        cx = sx = x;
        cy = sy = y;
        lastC = lastQ = null;
        break;
      }
      case 'L': {
        const x = ox + readNumber();
        const y = oy + readNumber();
        lines.push(`p.lineTo(${fmt(x)}, ${fmt(y)});`);
        cx = x;
        cy = y;
        lastC = lastQ = null;
        break;
      }
      case 'H': {
        const x = ox + readNumber();
        lines.push(`p.lineTo(${fmt(x)}, ${fmt(cy)});`);
        cx = x;
        lastC = lastQ = null;
        break;
      }
      case 'V': {
        const y = oy + readNumber();
        lines.push(`p.lineTo(${fmt(cx)}, ${fmt(y)});`);
        cy = y;
        lastC = lastQ = null;
        break;
      }
      case 'C': {
        const x1 = ox + readNumber();
        const y1 = oy + readNumber();
        const x2 = ox + readNumber();
        const y2 = oy + readNumber();
        const x = ox + readNumber();
        const y = oy + readNumber();
        lines.push(`p.cubicTo(${fmt(x1)}, ${fmt(y1)}, ${fmt(x2)}, ${fmt(y2)}, ${fmt(x)}, ${fmt(y)});`);
        lastC = [x2, y2];
        lastQ = null;
        cx = x;
        cy = y;
        break;
      }
      case 'S': {
        const x2 = ox + readNumber();
        const y2 = oy + readNumber();
        const x = ox + readNumber();
        const y = oy + readNumber();
        const [x1, y1] = lastC ? [2 * cx - lastC[0], 2 * cy - lastC[1]] : [cx, cy];
        lines.push(`p.cubicTo(${fmt(x1)}, ${fmt(y1)}, ${fmt(x2)}, ${fmt(y2)}, ${fmt(x)}, ${fmt(y)});`);
        lastC = [x2, y2];
        lastQ = null;
        cx = x;
        cy = y;
        break;
      }
      case 'Q': {
        const x1 = ox + readNumber();
        const y1 = oy + readNumber();
        const x = ox + readNumber();
        const y = oy + readNumber();
        lines.push(`p.quadraticBezierTo(${fmt(x1)}, ${fmt(y1)}, ${fmt(x)}, ${fmt(y)});`);
        lastQ = [x1, y1];
        lastC = null;
        cx = x;
        cy = y;
        break;
      }
      case 'T': {
        const x = ox + readNumber();
        const y = oy + readNumber();
        const [qx, qy] = lastQ ? [2 * cx - lastQ[0], 2 * cy - lastQ[1]] : [cx, cy];
        lines.push(`p.quadraticBezierTo(${fmt(qx)}, ${fmt(qy)}, ${fmt(x)}, ${fmt(y)});`);
        lastQ = [qx, qy];
        lastC = null;
        cx = x;
        cy = y;
        break;
      }
      case 'A': {
        const rx = readNumber();
        const ry = readNumber();
        const rot = readNumber();
        const large = readFlag();
        const sweep = readFlag();
        const x = ox + readNumber();
        const y = oy + readNumber();
        lines.push(
          `p.arcToPoint(const Offset(${fmt(x)}, ${fmt(y)}), radius: const Radius.elliptical(${fmt(rx)}, ${fmt(ry)}), ` +
            `rotation: ${fmt(rot)}, largeArc: ${large}, clockwise: ${sweep});`,
        );
        lastC = lastQ = null;
        cx = x;
        cy = y;
        break;
      }
      case 'Z':
        lines.push('p.close();');
        cx = sx;
        cy = sy;
        lastC = lastQ = null;
        break;
      default:
        throw new Error(`${name}: unsupported path command ${cmd}`);
    }
  }
  return lines;
}

function elementToDart(tag, a, name) {
  switch (tag) {
    case 'path':
      return pathToDart(a.d, name);
    case 'rect': {
      const x = num(a.x ?? 0);
      const y = num(a.y ?? 0);
      const w = num(a.width);
      const h = num(a.height);
      const rx = a.rx !== undefined ? num(a.rx) : a.ry !== undefined ? num(a.ry) : 0;
      const ry = a.ry !== undefined ? num(a.ry) : rx;
      return [
        `p.addRRect(RRect.fromRectXY(Rect.fromLTWH(${fmt(x)}, ${fmt(y)}, ${fmt(w)}, ${fmt(h)}), ${fmt(rx)}, ${fmt(ry)}));`,
      ];
    }
    case 'line':
      return [`p.moveTo(${fmt(num(a.x1))}, ${fmt(num(a.y1))});`, `p.lineTo(${fmt(num(a.x2))}, ${fmt(num(a.y2))});`];
    case 'polyline': {
      const pts = String(a.points)
        .trim()
        .split(/[\s,]+/)
        .map(num);
      const out = [];
      for (let k = 0; k < pts.length; k += 2) {
        out.push(`p.${k === 0 ? 'moveTo' : 'lineTo'}(${fmt(pts[k])}, ${fmt(pts[k + 1])});`);
      }
      return out;
    }
    case 'circle':
      return [
        `p.addOval(Rect.fromCircle(center: const Offset(${fmt(num(a.cx))}, ${fmt(num(a.cy))}), radius: ${fmt(num(a.r))}));`,
      ];
    default:
      throw new Error(`${name}: unsupported element <${tag}>`);
  }
}

function loadNode(file) {
  const src = fs.readFileSync(path.join(libDir, 'dist', 'esm', 'icons', `${file}.js`), 'utf8');
  const m = /const __iconNode = (\[[\s\S]*?\]);\s*\nconst /.exec(src);
  if (!m) throw new Error(`${file}: __iconNode not found`);
  // The literal is plain data (strings and numbers), so evaluating it as an expression is safe here.
  return new Function(`return ${m[1]};`)();
}

const parts = [];
const entries = [];
for (const [file, dartName] of ICONS) {
  const node = loadNode(file);
  const body = [];
  node.forEach(([tag, attrs], idx) => {
    for (const l of elementToDart(tag, attrs, `${file}#${idx}`)) body.push(`  ${l}`);
  });
  parts.push(`/// lucide "${file}"\nPath _lucide${dartName}() {\n  final p = Path();\n${body.join('\n')}\n  return p;\n}`);
  entries.push(`  LucideIconId.${dartName[0].toLowerCase()}${dartName.slice(1)}: _lucide${dartName},`);
}

const enumNames = ICONS.map(([, n]) => `${n[0].toLowerCase()}${n.slice(1)}`).join(', ');
const text = `// GENERATED FILE - DO NOT EDIT.
// Source of truth: lucide-react ${version} (the web app's icon library), icons: ${ICONS.map(([f]) => f).join(', ')}.
// Regenerate with: node flutter_app/tools/gen_lucide_paths.mjs
// ignore_for_file: prefer_const_constructors

import 'dart:ui';

enum LucideIconId { ${enumNames} }

${parts.join('\n\n')}

/// Builders of the 24 x 24 stroke icons.
final Map<LucideIconId, Path Function()> kLucideIconBuilders = <LucideIconId, Path Function()>{
${entries.join('\n')}
};
`;

if (check) {
  const current = fs.existsSync(outFile) ? fs.readFileSync(outFile, 'utf8') : '';
  if (current !== text) {
    console.error('lucide_icons_generated.dart is out of date. Run: node flutter_app/tools/gen_lucide_paths.mjs');
    process.exit(1);
  }
  console.log(`OK: ${ICONS.length} lucide icons match lucide-react ${version}.`);
} else {
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, text);
  console.log(`Wrote ${path.relative(root, outFile)}: ${ICONS.length} icons from lucide-react ${version}.`);
}
