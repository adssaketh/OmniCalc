import { BarStyle, EdgeEffect, FadeHeight, GlassBlur } from './types';

/**
 * Same options as Ping's Settings > Message Organization.
 * Studying Ping on a device: content is crisp right up to the bars (nothing fades *outside* a bar), and it
 * slides *under* the glass, where it is softly blurred, tinted and fades toward the screen edge. Fade height
 * is therefore only the short softening right at the bar edge.
 */
export const FADE_PX: Record<FadeHeight, number> = { short: 8, medium: 16, tall: 28 };
/** Glass blur: content under a glass bar becomes soft colour, never readable ghost text. */
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
const STEPS = 12;

interface EdgeGeometry {
  /** Where the top bars visually end (distance from the top of the screen) */
  topEdge: number;
  /** How far content stays visible *under* the top bars, measured up from their lower edge */
  topGlow: number;
  /** Height of the bottom bar stack (bar + padding) */
  bottomH: number;
  fadePx: number;
}

/**
 * Mask for the scroll container, modelled on Ping:
 *  - top: hidden at the very top of the screen, rising smoothly so the content is visible *through* the bar
 *    (this is what the glass blurs and tints), and fully crisp right at / beyond the bar's lower edge.
 *  - bottom: crisp right up to the nav bar's top edge, then softly fading under the bar toward the screen edge,
 *    so a little colour shows through the glass.
 *  Whole top fade is multiplied by --ft and the bottom fade by --fb (0..1), set from the scroll position by
 *  App.tsx: nothing is faded at the very top / bottom of a page where nothing slides under a bar.
 */
export function buildEdgeMask(g: EdgeGeometry, effect: EdgeEffect, barStyle: BarStyle): string | undefined {
  if (effect === 'off') return undefined;
  const glass = barStyle === 'glass';
  const edgeClear = 10;
  const top = (a: number) => `rgb(0 0 0 / calc(1 - ${(1 - a).toFixed(3)} * var(--ft, 0)))`;
  const bottom = (a: number) => `rgb(0 0 0 / calc(1 - ${(1 - a).toFixed(3)} * var(--fb, 0)))`;
  const stops: string[] = [];

  // ---- top: 0 at the screen edge -> 1 a little below the bar's lower edge
  const rampStart = Math.max(edgeClear + 2, g.topEdge - g.topGlow);
  const rampEnd = g.topEdge + g.fadePx;
  stops.push(`${top(0)} 0px`, `${top(0)} ${rampStart.toFixed(1)}px`);
  for (let i = 1; i <= STEPS; i++) {
    const t = i / STEPS;
    stops.push(`${top(ease(t))} ${(rampStart + (rampEnd - rampStart) * t).toFixed(1)}px`);
  }

  // ---- bottom (positions measured from the bottom of the scroll area)
  if (g.bottomH > 0) {
    const pillTop = Math.max(g.bottomH - 4, 0);
    const underBar = glass ? (effect === 'blur' ? 0.5 : 0.38) : 0;
    const farEnd = pillTop + g.fadePx; // crisp above this
    const start = Math.max(pillTop - 46, edgeClear + 10);
    stops.push(`${bottom(1)} calc(100% - ${farEnd.toFixed(1)}px)`);
    for (let i = 1; i <= STEPS; i++) {
      const t = i / STEPS;
      const d = farEnd - (farEnd - start) * t;
      stops.push(`${bottom(1 - (1 - underBar) * ease(t))} calc(100% - ${d.toFixed(1)}px)`);
    }
    stops.push(`${bottom(underBar)} calc(100% - ${Math.max(g.bottomH * 0.4, edgeClear + 9).toFixed(1)}px)`);
    stops.push(`${bottom(0)} calc(100% - ${edgeClear}px)`, `${bottom(0)} 100%`);
  } else {
    stops.push(`${bottom(1)} 100%`);
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
