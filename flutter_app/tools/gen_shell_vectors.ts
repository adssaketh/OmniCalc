/**
 * Golden vectors for the shell maths (Phase 3). Imports the REAL src/edgeEffects.ts, records what it returns and
 * writes test/golden/edge_effects.json. Never hand-edit the output.
 *
 *   npx tsx flutter_app/tools/gen_shell_vectors.ts            # regenerate
 *   npx tsx flutter_app/tools/gen_shell_vectors.ts --check    # fail if the committed file differs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { glassFillPercent, glassFillStrongPercent, buildEdgeMask, buildBlurLayers, FADE_PX } from '../../src/edgeEffects';
import type { BarStyle, EdgeEffect, FadeHeight } from '../../src/types';

const here = path.dirname(fileURLToPath(import.meta.url));
const outFile = path.join(here, '..', 'test', 'golden', 'edge_effects.json');
const check = process.argv.includes('--check');

const STOP =
  /rgb\(0 0 0 \/ calc\(1 - ([0-9.]+) \* var\(--(ft|fb), 0\)\)\) (?:calc\(100% - ([0-9.]+)px\)|([0-9.]+)px|100%)/g;

/** [fromBottom, px, 1 - alpha] for each stop of a mask string. */
function parseMask(mask: string): Array<[boolean, number, number]> {
  const out: Array<[boolean, number, number]> = [];
  for (const m of mask.matchAll(STOP)) {
    const fromBottom = m[2] === 'fb';
    const px = m[3] !== undefined ? Number(m[3]) : m[4] !== undefined ? Number(m[4]) : 0;
    out.push([fromBottom, px, Number(m[1])]);
  }
  return out;
}

function parseBlurMask(mask: string): Array<[number, number]> {
  const out: Array<[number, number]> = [];
  for (const m of mask.matchAll(/(#000|rgba\(0,0,0,([0-9.]+)\)) ([0-9.]+)px/g)) {
    out.push([Number(m[3]), m[2] === undefined ? 1 : Number(m[2])]);
  }
  return out;
}

const fills: Array<{ t: number; fill: number; strong: number }> = [];
for (const t of [-20, -1, 0, 1, 5, 10, 15, 20, 25, 30, 33, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 99, 100, 120, 12.5, 37.5, 62.5]) {
  fills.push({ t, fill: glassFillPercent(t), strong: glassFillStrongPercent(t) });
}

const masks: unknown[] = [];
const geoms = [
  { topEdge: 80, topGlow: 50, bottomH: 88 },
  { topEdge: 76, topGlow: 26, bottomH: 0 },
  { topEdge: 190, topGlow: 34, bottomH: 96 },
  { topEdge: 20, topGlow: 34, bottomH: 12 },
  { topEdge: 124.5, topGlow: 31.5, bottomH: 100.25 },
];
for (const g of geoms) {
  for (const fadeHeight of ['short', 'medium', 'tall'] as FadeHeight[]) {
    for (const effect of ['off', 'fade', 'blur'] as EdgeEffect[]) {
      for (const bar of ['solid', 'glass'] as BarStyle[]) {
        const s = buildEdgeMask({ ...g, fadePx: FADE_PX[fadeHeight] }, effect, bar);
        masks.push({ ...g, fadeHeight, effect, bar, stops: s === undefined ? null : parseMask(s) });
      }
    }
  }
}

const blur: unknown[] = [];
for (const [barH, fade] of [[76, 20], [190, 20], [88, 8], [96, 8], [0, 8], [124.5, 20]] as const) {
  const layers = buildBlurLayers(barH, fade, 'top').map((l) => ({
    blurPx: l.blurPx,
    height: l.height,
    stops: parseBlurMask(l.mask),
  }));
  blur.push({ barH, fade, layers });
}

const json = JSON.stringify({ fills, masks, blur }, null, 1) + '\n';
if (check) {
  const cur = fs.existsSync(outFile) ? fs.readFileSync(outFile, 'utf8') : '';
  if (cur !== json) {
    console.error('edge_effects.json is out of date');
    process.exit(1);
  }
  console.log('edge_effects.json up to date');
} else {
  fs.writeFileSync(outFile, json);
  console.log(`wrote ${outFile}: ${fills.length} fills, ${masks.length} masks, ${blur.length} blur sets`);
}
