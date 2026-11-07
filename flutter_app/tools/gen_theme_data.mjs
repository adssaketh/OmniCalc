/**
 * Generates lib/theme/theme_data_generated.dart mechanically from the web app, so no colour is typed by hand.
 *
 *   node flutter_app/tools/gen_theme_data.mjs            # (re)write the generated Dart file
 *   node flutter_app/tools/gen_theme_data.mjs --check    # fail if the committed file differs from a fresh generation
 *
 * Sources:
 *   src/index.css  - every --m3-* colour role per theme and mode (parsed from the CSS text)
 *   src/App.tsx    - DARK_SURFACES, LIGHT_SURFACES, THEME_DATA_ATTR, DEFAULT_SETTINGS
 *
 * Plain Node (no dependencies) so it runs with `node` alone.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..', '..');
const outFile = path.join(here, '..', 'lib', 'theme', 'theme_data_generated.dart');
const check = process.argv.includes('--check');

const css = fs.readFileSync(path.join(root, 'src', 'index.css'), 'utf8').replace(/\/\*[\s\S]*?\*\//g, '');
const app = fs.readFileSync(path.join(root, 'src', 'App.tsx'), 'utf8');

/** '#rrggbb' or 'rgba(r, g, b, a)' -> 0xAARRGGBB (alpha rounded like a browser does). */
function parseColor(raw) {
  const v = raw.trim();
  let m = /^#([0-9a-fA-F]{6})$/.exec(v);
  if (m) return 0xff000000 + parseInt(m[1], 16);
  m = /^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)$/.exec(v);
  if (m) {
    const a = Math.round(parseFloat(m[4]) * 255);
    return ((a << 24) >>> 0) + (parseInt(m[1]) << 16) + (parseInt(m[2]) << 8) + parseInt(m[3]);
  }
  throw new Error(`Unsupported colour value: ${v}`);
}
const hex8 = (n) => `0x${n.toString(16).toUpperCase().padStart(8, '0')}`;

// ---- parse the CSS blocks that define --m3-* roles ----------------------------------------------------------------
const blocks = [];
const blockRe = /([^{}]+)\{([^{}]*)\}/g;
let bm;
while ((bm = blockRe.exec(css))) {
  const selector = bm[1].trim().replace(/\s+/g, ' ');
  const decls = {};
  for (const d of bm[2].split(';')) {
    const dm = /^\s*--m3-([a-z-]+)\s*:\s*(.+?)\s*$/s.exec(d);
    if (dm) decls[dm[1]] = parseColor(dm[2]);
  }
  if (Object.keys(decls).length) blocks.push({ selector, decls });
}

let darkBase = null;
let lightBase = null;
const darkOverrides = {};
const lightOverrides = {};
for (const { selector, decls } of blocks) {
  let m;
  if (selector === ':root') darkBase = decls;
  else if (selector === '[data-m3-mode="light"]') lightBase = decls;
  else if ((m = /^\[data-m3-theme="([a-z]+)"\]:not\(\[data-m3-mode="light"\]\)$/.exec(selector))) darkOverrides[m[1]] = decls;
  else if ((m = /^\[data-m3-mode="light"\]\[data-m3-theme="([a-z]+)"\]$/.exec(selector))) lightOverrides[m[1]] = decls;
  else throw new Error(`Unrecognised selector with --m3 roles: ${selector}`);
}
if (!darkBase || !lightBase) throw new Error('Could not find the :root or light base colour blocks');

// ---- parse the small maps out of App.tsx -------------------------------------------------------------------------
function parseRecord(name) {
  const re = new RegExp(`const ${name}[^=]*=\\s*\\{([\\s\\S]*?)\\};`);
  const m = re.exec(app);
  if (!m) throw new Error(`Could not find ${name} in App.tsx`);
  const out = [];
  for (const line of m[1].split('\n')) {
    const lm = /^\s*(?:'([^']+)'|([A-Za-z0-9_-]+))\s*:\s*'([^']*)'/.exec(line);
    if (lm) out.push([lm[1] ?? lm[2], lm[3]]);
  }
  return out;
}
const darkSurfaces = parseRecord('DARK_SURFACES');
const lightSurfaces = parseRecord('LIGHT_SURFACES');
const themeAttr = parseRecord('THEME_DATA_ATTR');

const q = (s) => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
const mapLit = (obj) =>
  `{\n${Object.entries(obj)
    .map(([k, v]) => `  ${q(k)}: ${hex8(v)},`)
    .join('\n')}\n}`;
const nested = (obj) =>
  `{\n${Object.entries(obj)
    .map(([k, v]) => `  ${q(k)}: ${mapLit(v).replace(/\n/g, '\n  ')},`)
    .join('\n')}\n}`;
const strMap = (pairs, asColor) =>
  `{\n${pairs.map(([k, v]) => `  ${q(k)}: ${asColor ? hex8(parseColor(v)) : q(v)},`).join('\n')}\n}`;

const text = `// GENERATED FILE - DO NOT EDIT.
// Source of truth: src/index.css (colour roles) and src/App.tsx (surface and attribute maps).
// Regenerate with: node flutter_app/tools/gen_theme_data.mjs

/// :root - the dark Iris roles (the base every dark theme starts from). Keys are the CSS names without the --m3- prefix.
const Map<String, int> kDarkBase = ${mapLit(darkBase)};

/// [data-m3-mode="light"] - the light Iris roles (the base every light theme starts from).
const Map<String, int> kLightBase = ${mapLit(lightBase)};

/// Per-theme overrides of kDarkBase, keyed by the data-m3-theme value (oceanic, forest, sunset, amoled).
const Map<String, Map<String, int>> kDarkOverrides = ${nested(darkOverrides)};

/// Per-theme overrides of kLightBase, keyed by the data-m3-theme value.
const Map<String, Map<String, int>> kLightOverrides = ${nested(lightOverrides)};

/// DARK_SURFACES in App.tsx: page background per theme id (status bar and root).
const Map<String, int> kDarkSurfaces = ${strMap(darkSurfaces, true)};

/// LIGHT_SURFACES in App.tsx.
const Map<String, int> kLightSurfaces = ${strMap(lightSurfaces, true)};

/// THEME_DATA_ATTR in App.tsx: theme id -> data-m3-theme value (any id not listed uses 'iris').
const Map<String, String> kThemeDataAttr = ${strMap(themeAttr, false)};
`;

if (check) {
  const current = fs.existsSync(outFile) ? fs.readFileSync(outFile, 'utf8') : '';
  if (current !== text) {
    console.error('theme_data_generated.dart is out of date. Run: node flutter_app/tools/gen_theme_data.mjs');
    process.exit(1);
  }
  console.log(
    `OK: theme data matches the web source (${Object.keys(darkOverrides).length} dark and ${Object.keys(lightOverrides).length} light theme overrides).`,
  );
} else {
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, text);
  console.log(
    `Wrote ${path.relative(root, outFile)}: base roles ${Object.keys(darkBase).length}/${Object.keys(lightBase).length}, ` +
      `dark overrides ${Object.keys(darkOverrides).join(', ')}, light overrides ${Object.keys(lightOverrides).join(', ')}.`,
  );
}
