import React from 'react';
import { ThemeId } from '../types';

interface OmniCalcLogoProps {
  className?: string;
  size?: number;
  theme?: ThemeId | string;
}

interface LogoPalette {
  id: string;
  pillGrad: [string, string, string];
  bgGrad: [string, string, string];
  bgStroke: string;
  btnGrad: [string, string];
  btnGlyph: string;
  pillGlyph: string;
  glow: string;
}

function getThemeColors(theme?: ThemeId | string): LogoPalette {
  switch (theme) {
    case 'm3-ocean':
      return {
        id: 'ocean',
        pillGrad: ['#7bd0ff', '#38bdf8', '#0284c7'],
        bgGrad: ['#ffffff', '#e6f7fc', '#c5e8f6'],
        bgStroke: '#7bd0ff',
        btnGrad: ['#1b3545', '#0f2430'],
        btnGlyph: '#c4e7ff',
        pillGlyph: '#ffffff',
        glow: 'rgba(123, 208, 255, 0.5)',
      };
    case 'm3-forest':
    case 'cyber-emerald':
      return {
        id: 'forest',
        pillGrad: ['#9cd67d', '#4ade80', '#15803d'],
        bgGrad: ['#ffffff', '#eef8ee', '#d0e9cf'],
        bgStroke: '#9cd67d',
        btnGrad: ['#1d351d', '#102210'],
        btnGlyph: '#b8f397',
        pillGlyph: '#ffffff',
        glow: 'rgba(156, 214, 125, 0.5)',
      };
    case 'm3-sunset':
      return {
        id: 'sunset',
        pillGrad: ['#ffb59d', '#fb923c', '#c2410c'],
        bgGrad: ['#ffffff', '#fdf0ec', '#f6d5cc'],
        bgStroke: '#ffb59d',
        btnGrad: ['#38241e', '#231410'],
        btnGlyph: '#ffdbcf',
        pillGlyph: '#ffffff',
        glow: 'rgba(255, 181, 157, 0.5)',
      };
    case 'm3-amoled':
    case 'oled-midnight':
      return {
        id: 'amoled',
        pillGrad: ['#e2e0ff', '#c2c1ff', '#7c3aed'],
        bgGrad: ['#282538', '#141220', '#050508'],
        bgStroke: '#c2c1ff',
        btnGrad: ['#1f1d2b', '#100e18'],
        btnGlyph: '#e2e0ff',
        pillGlyph: '#ffffff',
        glow: 'rgba(194, 193, 255, 0.6)',
      };
    case 'warm-paper':
      return {
        id: 'paper',
        pillGrad: ['#e5c18d', '#d97706', '#92400e'],
        bgGrad: ['#fffdfa', '#f5eee3', '#e4d6c1'],
        bgStroke: '#e5c18d',
        btnGrad: ['#383024', '#241f17'],
        btnGlyph: '#ffdfad',
        pillGlyph: '#ffffff',
        glow: 'rgba(229, 193, 141, 0.5)',
      };
    case 'm3-iris':
    case 'dark-obsidian':
    default:
      return {
        id: 'iris',
        pillGrad: ['#a8c7fa', '#669df6', '#264585'],
        bgGrad: ['#ffffff', '#eff3fb', '#d5e0f5'],
        bgStroke: '#a8c7fa',
        btnGrad: ['#252f44', '#151c2e'],
        btnGlyph: '#d3e3fd',
        pillGlyph: '#ffffff',
        glow: 'rgba(168, 199, 250, 0.55)',
      };
  }
}

export const OmniCalcLogo: React.FC<OmniCalcLogoProps> = ({
  className = 'w-8 h-8',
  size,
  theme,
}) => {
  const colors = getThemeColors(theme);
  const style = size ? { width: size, height: size } : undefined;

  return (
    <svg
      viewBox="0 0 512 512"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={`shrink-0 select-none transition-all duration-300 ${className}`}
      style={style}
    >
      <defs>
        {/* Dynamic Theme Metallic Silver / Container Gradient */}
        <radialGradient id={`logoBgGrad_${colors.id}`} cx="45%" cy="35%" r="70%">
          <stop offset="0%" stopColor={colors.bgGrad[0]} />
          <stop offset="60%" stopColor={colors.bgGrad[1]} />
          <stop offset="100%" stopColor={colors.bgGrad[2]} />
        </radialGradient>

        {/* Dynamic Theme Vibrant Hero Equals Pill Gradient */}
        <linearGradient id={`logoPillGrad_${colors.id}`} x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor={colors.pillGrad[0]} />
          <stop offset="50%" stopColor={colors.pillGrad[1]} />
          <stop offset="100%" stopColor={colors.pillGrad[2]} />
        </linearGradient>

        {/* Dynamic Theme Tone Buttons Gradient */}
        <linearGradient id={`logoBtnGrad_${colors.id}`} x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor={colors.btnGrad[0]} />
          <stop offset="100%" stopColor={colors.btnGrad[1]} />
        </linearGradient>

        {/* Soft Drop Glow matching theme primary */}
        <filter id={`logoGlow_${colors.id}`} x="-20%" y="-20%" width="140%" height="140%">
          <feDropShadow dx="0" dy="4" stdDeviation="10" floodColor={colors.glow} floodOpacity="0.45" />
        </filter>
      </defs>

      {/* Base circular icon shape */}
      <circle cx="256" cy="256" r="248" fill={`url(#logoBgGrad_${colors.id})`} />

      {/* Dynamic Theme Accent Ring Stroke */}
      <circle
        cx="256"
        cy="256"
        r="242"
        fill="none"
        stroke={colors.bgStroke}
        strokeWidth="12"
        strokeOpacity="0.55"
      />

      {/* Top Left: Plus Button with theme tone */}
      <circle cx="155" cy="160" r="90" fill={`url(#logoBtnGrad_${colors.id})`} />
      {/* Plus horizontal bar */}
      <rect x="108" y="149" width="94" height="22" rx="11" fill={colors.btnGlyph} />
      {/* Plus vertical bar */}
      <rect x="144" y="113" width="22" height="94" rx="11" fill={colors.btnGlyph} />

      {/* Bottom Left: Minus Button with theme tone */}
      <circle cx="155" cy="352" r="90" fill={`url(#logoBtnGrad_${colors.id})`} />
      {/* Minus horizontal bar */}
      <rect x="110" y="341" width="90" height="22" rx="11" fill={colors.btnGlyph} />

      {/* Right: Dynamic Theme Capsule Equals Hero Button */}
      <rect
        x="266"
        y="65"
        width="182"
        height="382"
        rx="91"
        fill={`url(#logoPillGrad_${colors.id})`}
        filter={`url(#logoGlow_${colors.id})`}
      />
      {/* Equals top bar */}
      <rect x="312" y="232" width="90" height="22" rx="11" fill={colors.pillGlyph} />
      {/* Equals bottom bar */}
      <rect x="312" y="280" width="90" height="22" rx="11" fill={colors.pillGlyph} />
    </svg>
  );
};
