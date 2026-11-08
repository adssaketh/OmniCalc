/**
 * Turns the SVG path strings of the web app's navigation icons and logo into Dart `Path` building code,
 * mechanically, so no path is retyped by hand and no SVG parser has to run on the phone.
 *
 *   node flutter_app/tools/gen_svg_paths.mjs            # (re)write lib/ui/icons/svg_paths_generated.dart
 *   node flutter_app/tools/gen_svg_paths.mjs --check    # fail if the committed file differs from a fresh generation
 *
 * Sources: src/components/NavIcons.tsx, OmniCalcLogo.tsx and SettingsModal.tsx (every d="..." attribute, in file order).
 * The order is pinned by EXPECTED_* below: if someone reorders or adds a path in the TSX the script fails loudly
 * instead of silently drawing the wrong shape.
 *
 * Supported commands: M L H V C Q T A Z, absolute and relative (lower case). Anything else (S, for one) throws.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
const outFile = path.join(here, '..', 'lib', 'ui', 'icons', 'svg_paths_generated.dart');
const check = process.argv.includes('--check');

// Index -> what the path must start with (and what it is, for the constants in nav_icon.dart / omnicalc_logo.dart).
const EXPECTED_NAV = [
  'M 18.5 8 H 5.5', // 0  converter, top arrow
  'M 5.5 16 H 18.5', // 1  converter, bottom arrow
  'M 12 2.5 C 13.5', // 2  finance, scalloped medallion
  'M 12 6.5 V 17.5', // 3  finance, dollar sign
  'M 12 3.2 C 7.14', // 4  recents, rewind track
  'M 11.5 1.2 L 7.2', // 5  recents, arrow tip
  'M 12 6.2 V 7.4', // 6  recents, quadrant ticks
  'M 12 8.2 V 12 L', // 7  recents, clock hands
  'M 19.4 13 C', // 8  settings, filled gear (active, even-odd)
  'M 19.4 13 C', // 9  settings, gear outline
  'M 4 10 H 7.5', // 10 sound, speaker (on)
  'M 15.5 8.5 C', // 11 sound, small wave
  'M 18.5 5.5 C', // 12 sound, big wave
  'M 4 10 H 7.5', // 13 sound, speaker (muted)
  'M 16 9.5 L 21', // 14 sound, mute cross
  'M 12 8.2 C 10.3', // 15 guide, open book
  'M 12 8.4 V 20', // 16 guide, spine
  'M 12 1.8 L 12.9', // 17 guide, spark
  'M 3.5 4 V 20', // 18 grapher, axes
  'M 4 15.5 Q 7.5', // 19 grapher, curve
];
const EXPECTED_LOGO = [
  'M 180 300 A 150', // 0 minus button highlight
  'M 180 696 A 150', // 1 plus button highlight
  'M 548 310 C 548', // 2 equals pill sheen
  'M 566 740 C 600', // 3 equals pill bottom glow
];

const EXPECTED_SETTINGS = [
  'M12 .297c-6.63', // 0  GitHub mark (Settings > About > Source code), filled
];

function extract(file) {
  const t = fs.readFileSync(path.join(root, 'src', 'components', file), 'utf8');
  return [...t.matchAll(/\bd="([^"]+)"/g)].map((m) => m[1].replace(/\s+/g, ' ').trim());
}

const num = (s) => {
  const n = Number(s);
  if (!Number.isFinite(n)) throw new Error(`Bad number ${s}`);
  return n;
};
const fmt = (n) => {
  const s = String(n);
  return /^-?\d+$/.test(s) ? `${s}.0` : s;
};

function toDart(d, name) {
  const tokens = d.match(/[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?/g);
  if (!tokens) throw new Error(`Empty path ${name}`);
  const lines = ['  final p = Path();'];
  let i = 0;
  let cx = 0;
  let cy = 0;
  let sx = 0;
  let sy = 0;
  let lastQ = null; // last quadratic control point, for T
  let cmd = null;
  const isCmd = (t) => /^[A-Za-z]$/.test(t);
  // Lower-case commands are relative to the current point: every x / y read below is shifted by it.
  let rel = false;
  const nextX = () => num(tokens[i++]) + (rel ? cx : 0);
  const nextY = () => num(tokens[i++]) + (rel ? cy : 0);
  const next = () => num(tokens[i++]); // plain number (arc radii, rotation and flags are never relative)
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    else if (cmd === 'M') cmd = 'L'; // extra coordinate pairs after a moveto are lineto
    else if (cmd === 'm') cmd = 'l';
    if (!'MLHVCQTAZmlhvcqtaz'.includes(cmd)) throw new Error(`Unsupported command ${cmd} in ${name}`);
    rel = cmd === cmd.toLowerCase();
    cmd = cmd.toUpperCase();
    switch (cmd) {
      case 'M': {
        const x = nextX();
        const y = nextY();
        lines.push(`  p.moveTo(${fmt(x)}, ${fmt(y)});`);
        cx = sx = x;
        cy = sy = y;
        lastQ = null;
        break;
      }
      case 'L': {
        const x = nextX();
        const y = nextY();
        lines.push(`  p.lineTo(${fmt(x)}, ${fmt(y)});`);
        cx = x;
        cy = y;
        lastQ = null;
        break;
      }
      case 'H': {
        const x = nextX();
        lines.push(`  p.lineTo(${fmt(x)}, ${fmt(cy)});`);
        cx = x;
        lastQ = null;
        break;
      }
      case 'V': {
        const y = nextY();
        lines.push(`  p.lineTo(${fmt(cx)}, ${fmt(y)});`);
        cy = y;
        lastQ = null;
        break;
      }
      case 'C': {
        const [x1, y1, x2, y2, x, y] = [nextX(), nextY(), nextX(), nextY(), nextX(), nextY()];
        lines.push(`  p.cubicTo(${fmt(x1)}, ${fmt(y1)}, ${fmt(x2)}, ${fmt(y2)}, ${fmt(x)}, ${fmt(y)});`);
        cx = x;
        cy = y;
        lastQ = null;
        break;
      }
      case 'Q': {
        const [x1, y1, x, y] = [nextX(), nextY(), nextX(), nextY()];
        lines.push(`  p.quadraticBezierTo(${fmt(x1)}, ${fmt(y1)}, ${fmt(x)}, ${fmt(y)});`);
        lastQ = [x1, y1];
        cx = x;
        cy = y;
        break;
      }
      case 'T': {
        const [x, y] = [nextX(), nextY()];
        const [qx, qy] = lastQ ? [2 * cx - lastQ[0], 2 * cy - lastQ[1]] : [cx, cy];
        lines.push(`  p.quadraticBezierTo(${fmt(qx)}, ${fmt(qy)}, ${fmt(x)}, ${fmt(y)});`);
        lastQ = [qx, qy];
        cx = x;
        cy = y;
        break;
      }
      case 'A': {
        const [rx, ry, rot, large, sweep] = [next(), next(), next(), next(), next()];
        const x = nextX();
        const y = nextY();
        lines.push(
          `  p.arcToPoint(const Offset(${fmt(x)}, ${fmt(y)}), radius: const Radius.elliptical(${fmt(rx)}, ${fmt(ry)}), ` +
            `rotation: ${fmt(rot)}, largeArc: ${large === 1}, clockwise: ${sweep === 1});`,
        );
        cx = x;
        cy = y;
        lastQ = null;
        break;
      }
      case 'Z':
        lines.push('  p.close();');
        cx = sx;
        cy = sy;
        lastQ = null;
        break;
    }
  }
  lines.push('  return p;');
  return lines.join('\n');
}

function build(listName, paths, expected, file) {
  if (paths.length !== expected.length) {
    throw new Error(`${file}: found ${paths.length} path strings, expected ${expected.length}. Update EXPECTED_* in gen_svg_paths.mjs.`);
  }
  expected.forEach((prefix, idx) => {
    if (!paths[idx].startsWith(prefix)) {
      throw new Error(`${file}: path #${idx} should start with "${prefix}" but starts with "${paths[idx].slice(0, 20)}"`);
    }
  });
  const fns = paths.map((d, idx) => `/// ${file} path #${idx}\nPath _${listName}${idx}() {\n${toDart(d, `${file}#${idx}`)}\n}`);
  const list = `/// Builders in source order (see EXPECTED_* in tools/gen_svg_paths.mjs for what each index is).\nfinal List<Path Function()> ${listName} = <Path Function()>[\n${paths
    .map((_, idx) => `  _${listName}${idx},`)
    .join('\n')}\n];`;
  return `${fns.join('\n\n')}\n\n${list}`;
}

const nav = extract('NavIcons.tsx');
const logo = extract('OmniCalcLogo.tsx');
const settingsPaths = extract('SettingsModal.tsx');
const text = `// GENERATED FILE - DO NOT EDIT.
// Source of truth: src/components/NavIcons.tsx, OmniCalcLogo.tsx and SettingsModal.tsx (the d="..." path strings).
// Regenerate with: node flutter_app/tools/gen_svg_paths.mjs
// ignore_for_file: prefer_const_constructors

import 'dart:ui';

${build('kNavIconPathBuilders', nav, EXPECTED_NAV, 'NavIcons.tsx')}

${build('kLogoPathBuilders', logo, EXPECTED_LOGO, 'OmniCalcLogo.tsx')}

${build('kSettingsPathBuilders', settingsPaths, EXPECTED_SETTINGS, 'SettingsModal.tsx')}
`;

if (check) {
  const current = fs.existsSync(outFile) ? fs.readFileSync(outFile, 'utf8') : '';
  if (current !== text) {
    console.error('svg_paths_generated.dart is out of date. Run: node flutter_app/tools/gen_svg_paths.mjs');
    process.exit(1);
  }
  console.log(`OK: ${nav.length} icon paths, ${logo.length} logo paths and ${settingsPaths.length} settings path match the web source.`);
} else {
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, text);
  console.log(`Wrote ${path.relative(root, outFile)}: ${nav.length} icon paths, ${logo.length} logo paths, ${settingsPaths.length} settings path.`);
}
