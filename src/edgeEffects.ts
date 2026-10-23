import { BarStyle, EdgeEffect, FadeHeight, GlassBlur } from './types';

/** Same options and defaults as Ping's Settings > Message Organization. */
export const FADE_PX: Record<FadeHeight, number> = { short: 28, medium: 52, tall: 84 };
export const GLASS_BLUR_PX: Record<GlassBlur, number> = { soft: 8, medium: 16, strong: 28 };
export const EDGE_BLUR_PX = 10;

/** Glass transparency slider (0 = frosted ... 100 = clear) -> how opaque the bar colour is, in percent. */
export function glassFillPercent(transparency: number): number {
  const t = Math.min(100, Math.max(0, transparency));
  return Math.round(90 - t * 0.82);
}

/** Smooth ease-in-out so the fade has no visible "start line". */
const smooth = (t: number) => t * t * (3 - 2 * t);
const STEPS = 8;

interface EdgeGeometry {
  topH: number;
  bottomH: number;
  fadePx: number;
}

/**
 * CSS mask for the scroll container. Content is fully visible in the middle, fades out over `fadePx`
 * before it reaches a bar, and stays at `underBarAlpha` underneath the bar itself (0 for solid bars,
 * partly visible for glass bars so the glass has something to blur).
 */
export function buildEdgeMask(g: EdgeGeometry, effect: EdgeEffect, barStyle: BarStyle): string | undefined {
  if (effect === 'off') return undefined;
  const under = barStyle === 'glass' ? 0.5 : 0;
  const alpha = (t: number) => (under + (1 - under) * smooth(t)).toFixed(3);

  const stops: string[] = [`rgba(0,0,0,${under}) 0px`, `rgba(0,0,0,${under}) ${g.topH}px`];
  for (let i = 1; i <= STEPS; i++) {
    const t = i / STEPS;
    stops.push(`rgba(0,0,0,${alpha(t)}) ${(g.topH + g.fadePx * t).toFixed(1)}px`);
  }
  for (let i = STEPS - 1; i >= 0; i--) {
    const t = i / STEPS;
    stops.push(`rgba(0,0,0,${alpha(t)}) calc(100% - ${(g.bottomH + g.fadePx * t).toFixed(1)}px)`);
  }
  stops.push(`rgba(0,0,0,${under}) 100%`);
  return `linear-gradient(to bottom, ${stops.join(', ')})`;
}

/** Mask for the blur layers: full blur at the screen edge, tapering to nothing at the end of the fade. */
export function buildBlurMask(barH: number, fadePx: number, edge: 'top' | 'bottom'): string {
  const dir = edge === 'top' ? 'to bottom' : 'to top';
  const stops: string[] = [`#000 0px`, `#000 ${barH}px`];
  for (let i = 1; i <= STEPS; i++) {
    const t = i / STEPS;
    stops.push(`rgba(0,0,0,${(1 - smooth(t)).toFixed(3)}) ${(barH + fadePx * t).toFixed(1)}px`);
  }
  return `linear-gradient(${dir}, ${stops.join(', ')})`;
}
