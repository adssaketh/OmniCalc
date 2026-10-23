import { BarStyle, EdgeEffect, FadeHeight, GlassBlur } from './types';

/** Same options as Ping's Settings > Message Organization. */
export const FADE_PX: Record<FadeHeight, number> = { short: 40, medium: 72, tall: 112 };
export const GLASS_BLUR_PX: Record<GlassBlur, number> = { soft: 8, medium: 16, strong: 28 };

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
const STEPS = 14;

interface EdgeGeometry {
  topH: number;
  bottomH: number;
  fadePx: number;
}

/** How much of the content stays visible directly under / around a bar. */
function underBarAlpha(effect: EdgeEffect, barStyle: BarStyle): number {
  if (effect === 'blur') return barStyle === 'glass' ? 0.55 : 0.38;
  return barStyle === 'glass' ? 0.3 : 0;
}

/**
 * Mask for the scroll container.
 *  - Content is fully visible in the middle.
 *  - It eases out over `fadePx` as it approaches a bar.
 *  - Around the bar it stays at `underBarAlpha`, but never in the first few pixels of the screen
 *    (the status bar strip), so nothing peeks out above the header.
 */
export function buildEdgeMask(g: EdgeGeometry, effect: EdgeEffect, barStyle: BarStyle): string | undefined {
  if (effect === 'off') return undefined;
  const under = underBarAlpha(effect, barStyle);
  const a = (v: number) => v.toFixed(3);
  const edgeClear = 10; // px at the very top / bottom that are always empty
  const stops: string[] = [];

  // top edge
  stops.push(`rgba(0,0,0,0) 0px`, `rgba(0,0,0,0) ${edgeClear}px`);
  for (let i = 1; i <= 4; i++) {
    const t = i / 4;
    const y = edgeClear + (g.topH * 0.5 - edgeClear) * t;
    stops.push(`rgba(0,0,0,${a(under * ease(t))}) ${y.toFixed(1)}px`);
  }
  stops.push(`rgba(0,0,0,${a(under)}) ${g.topH}px`);
  for (let i = 1; i <= STEPS; i++) {
    const t = i / STEPS;
    stops.push(`rgba(0,0,0,${a(under + (1 - under) * ease(t))}) ${(g.topH + g.fadePx * t).toFixed(1)}px`);
  }

  // bottom edge (positions measured from the bottom of the scroll area)
  for (let i = STEPS - 1; i >= 0; i--) {
    const t = i / STEPS;
    stops.push(`rgba(0,0,0,${a(under + (1 - under) * ease(t))}) calc(100% - ${(g.bottomH + g.fadePx * t).toFixed(1)}px)`);
  }
  if (g.bottomH > 0) {
    for (let i = 3; i >= 0; i--) {
      const t = i / 4;
      const y = edgeClear + (g.bottomH * 0.5 - edgeClear) * t;
      stops.push(`rgba(0,0,0,${a(under * ease(t))}) calc(100% - ${y.toFixed(1)}px)`);
    }
    stops.push(`rgba(0,0,0,0) calc(100% - ${edgeClear}px)`, `rgba(0,0,0,0) 100%`);
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
  const blurs = [1.5, 2.5, 4.5, 7];
  const dir = edge === 'top' ? 'to bottom' : 'to top';
  return blurs.map((blurPx, k) => {
    const reach = total * (1 - (k / blurs.length) * 0.7);
    const solidTo = reach * 0.3;
    const stops: string[] = [`#000 0px`, `#000 ${solidTo.toFixed(1)}px`];
    for (let i = 1; i <= 8; i++) {
      const t = i / 8;
      stops.push(`rgba(0,0,0,${(1 - ease(t)).toFixed(3)}) ${(solidTo + (reach - solidTo) * t).toFixed(1)}px`);
    }
    return { blurPx, height: Math.round(reach), mask: `linear-gradient(${dir}, ${stops.join(', ')})` };
  });
}
