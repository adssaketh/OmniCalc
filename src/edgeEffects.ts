import { BarStyle, EdgeEffect, FadeHeight, GlassBlur } from './types';

/** Same options as Ping's Settings > Message Organization. */
export const FADE_PX: Record<FadeHeight, number> = { short: 56, medium: 96, tall: 140 };
/** Glass blur is strong on purpose: whatever slides under a glass bar becomes soft colour, never readable ghost text. */
export const GLASS_BLUR_PX: Record<GlassBlur, number> = { soft: 14, medium: 22, strong: 32 };

/** Glass transparency slider (0 = frosted ... 100 = clear) -> how opaque the bar colour is, in percent. */
export function glassFillPercent(transparency: number): number {
  const t = Math.min(100, Math.max(0, transparency));
  return Math.round(90 - t * 0.82);
}

/** Display card on glass bars: always clearly more opaque than the bars, so the numbers stay readable. */
export function glassFillStrongPercent(transparency: number): number {
  return Math.min(94, Math.max(62, glassFillPercent(transparency) + 36));
}

/** Cosine ease: starts and ends flat, so a fade has no visible "start line" or "end line". */
const ease = (t: number) => 0.5 - 0.5 * Math.cos(Math.PI * Math.min(1, Math.max(0, t)));
const STEPS = 16;

interface EdgeGeometry {
  topH: number;
  bottomH: number;
  fadePx: number;
}

/** How much of the content stays visible *inside* the bar area (only matters for glass bars). */
function underBarAlpha(effect: EdgeEffect, barStyle: BarStyle): number {
  if (barStyle !== 'glass') return 0;
  return effect === 'blur' ? 0.5 : 0.22;
}

/**
 * Mask for the scroll container, built the way Ping's fade behaves:
 *  1. Inside the bar area the content is hidden (solid bars) or only a soft colour hint (glass bars).
 *  2. Right where the bar ends the content is still completely hidden, for a short "hold". This is what
 *     removes half-cut, half-transparent ghost rows directly under a bar.
 *  3. After the hold it dissolves in with a long, smooth ease.
 *  4. Nothing ever shows in the first pixels of the screen (status bar strip).
 *  The whole top fade is multiplied by --ft and the bottom fade by --fb (0..1), set from the scroll position
 *  by App.tsx: no fade at the very top / bottom of a page, a smooth ease-in as soon as content slides under a bar.
 */
export function buildEdgeMask(g: EdgeGeometry, effect: EdgeEffect, barStyle: BarStyle): string | undefined {
  if (effect === 'off') return undefined;
  const under = underBarAlpha(effect, barStyle);
  const edgeClear = 10;
  const gap = 16; // bar shadow / gap between the bar and the end of its stack
  const hold = g.fadePx * 0.14;
  const ramp = g.fadePx - hold;

  const top = (a: number) => `rgb(0 0 0 / calc(1 - ${(1 - a).toFixed(3)} * var(--ft, 0)))`;
  const bottom = (a: number) => `rgb(0 0 0 / calc(1 - ${(1 - a).toFixed(3)} * var(--fb, 0)))`;
  const stops: string[] = [];

  // top edge
  stops.push(`${top(0)} 0px`, `${top(0)} ${edgeClear}px`);
  if (under > 0) {
    stops.push(`${top(under)} ${Math.max(edgeClear + 8, g.topH * 0.45).toFixed(1)}px`);
    stops.push(`${top(under)} ${Math.max(g.topH - gap - 6, edgeClear + 9).toFixed(1)}px`);
  }
  stops.push(`${top(0)} ${(g.topH - 2).toFixed(1)}px`, `${top(0)} ${(g.topH + hold).toFixed(1)}px`);
  for (let i = 1; i <= STEPS; i++) {
    const t = i / STEPS;
    stops.push(`${top(ease(t))} ${(g.topH + hold + ramp * t).toFixed(1)}px`);
  }

  // bottom edge (positions measured from the bottom of the scroll area)
  for (let i = STEPS; i >= 1; i--) {
    const t = i / STEPS;
    stops.push(`${bottom(ease(t))} calc(100% - ${(g.bottomH + hold + ramp * t).toFixed(1)}px)`);
  }
  stops.push(`${bottom(0)} calc(100% - ${(g.bottomH + hold).toFixed(1)}px)`);
  if (g.bottomH > 0) {
    stops.push(`${bottom(0)} calc(100% - ${(g.bottomH - 2).toFixed(1)}px)`);
    if (under > 0) {
      stops.push(`${bottom(under)} calc(100% - ${Math.max(g.bottomH - gap - 6, edgeClear + 9).toFixed(1)}px)`);
      stops.push(`${bottom(under)} calc(100% - ${Math.max(g.bottomH * 0.45, edgeClear + 8).toFixed(1)}px)`);
    }
    stops.push(`${bottom(0)} calc(100% - ${edgeClear}px)`, `${bottom(0)} 100%`);
  }
  return `linear-gradient(to bottom, ${stops.join(', ')})`;
}

export interface BlurLayer {
  blurPx: number;
  /** Height of the layer, measured from the screen edge */
  height: number;
  mask: string;
}

/**
 * Progressive blur ("Fade + blur"): several backdrop-blur layers stacked on each other. Every layer
 * reaches a bit less far from the screen edge than the one below it, so the blur grows smoothly
 * from nothing (far from the bar) to strong (at the bar), instead of one flat smudge.
 */
export function buildBlurLayers(barH: number, fadePx: number, edge: 'top' | 'bottom'): BlurLayer[] {
  const total = barH + fadePx;
  const blurs = [2.5, 4.5, 8, 13];
  const dir = edge === 'top' ? 'to bottom' : 'to top';
  return blurs.map((blurPx, k) => {
    const reach = total * (1 - (k / blurs.length) * 0.6);
    const solidTo = Math.min(reach * 0.35, barH + 4);
    const stops: string[] = [`#000 0px`, `#000 ${solidTo.toFixed(1)}px`];
    for (let i = 1; i <= 10; i++) {
      const t = i / 10;
      stops.push(`rgba(0,0,0,${(1 - ease(t)).toFixed(3)}) ${(solidTo + (reach - solidTo) * t).toFixed(1)}px`);
    }
    return { blurPx, height: Math.round(reach), mask: `linear-gradient(${dir}, ${stops.join(', ')})` };
  });
}
