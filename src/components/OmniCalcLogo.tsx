import React, { useId } from 'react';
import { ThemeId } from '../types';

interface OmniCalcLogoProps {
  className?: string;
  size?: number;
  theme?: ThemeId | string;
  shape?: 'squircle' | 'circle';
}

export const OmniCalcLogo: React.FC<OmniCalcLogoProps> = ({
  className = 'w-8 h-8',
  size,
  shape = 'squircle',
}) => {
  const rawId = useId();
  const id = rawId.replace(/[^a-zA-Z0-9_-]/g, '_');
  const style = size ? { width: size, height: size } : undefined;

  return (
    <svg
      viewBox="0 0 1024 1024"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={`shrink-0 select-none transition-all duration-200 ${className}`}
      style={style}
      aria-label="OmniCalc Logo"
    >
      <defs>
        {/* Background subtle soft silver vignette */}
        <radialGradient id={`${id}-bgVignette`} cx="50%" cy="45%" r="65%">
          <stop offset="0%" stopColor="#f4f6f9" />
          <stop offset="60%" stopColor="#edf0f4" />
          <stop offset="100%" stopColor="#e2e6ec" />
        </radialGradient>

        {/* Dark button 3D rim stroke gradient */}
        <linearGradient id={`${id}-darkRim`} x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#555966" />
          <stop offset="35%" stopColor="#363942" />
          <stop offset="85%" stopColor="#1e2025" />
          <stop offset="100%" stopColor="#121316" />
        </linearGradient>

        {/* Dark button face radial gradient */}
        <radialGradient id={`${id}-darkFace`} cx="38%" cy="32%" r="65%">
          <stop offset="0%" stopColor="#3c3f49" />
          <stop offset="45%" stopColor="#2a2c33" />
          <stop offset="80%" stopColor="#212227" />
          <stop offset="100%" stopColor="#18191d" />
        </radialGradient>

        {/* Vibrant Emerald-to-Lime Pill Gradient */}
        <linearGradient id={`${id}-greenPill`} x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#059e4e" />
          <stop offset="25%" stopColor="#08b85b" />
          <stop offset="55%" stopColor="#11cb65" />
          <stop offset="80%" stopColor="#3fe078" />
          <stop offset="100%" stopColor="#6ee787" />
        </linearGradient>

        {/* Green Pill Rim Specular Stroke */}
        <linearGradient id={`${id}-pillRim`} x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="rgba(255, 255, 255, 0.75)" />
          <stop offset="30%" stopColor="rgba(255, 255, 255, 0.35)" />
          <stop offset="70%" stopColor="rgba(255, 255, 255, 0.05)" />
          <stop offset="100%" stopColor="rgba(255, 255, 255, 0.45)" />
        </linearGradient>

        {/* Green Pill Inner Specular Curved Sheen */}
        <linearGradient id={`${id}-glassSheen`} x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="rgba(255, 255, 255, 0.65)" />
          <stop offset="45%" stopColor="rgba(255, 255, 255, 0.15)" />
          <stop offset="100%" stopColor="rgba(255, 255, 255, 0.0)" />
        </linearGradient>

        {/* White 3D Symbol Capsule Gradient */}
        <linearGradient id={`${id}-whiteSymbol`} x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#ffffff" />
          <stop offset="60%" stopColor="#fdfdfd" />
          <stop offset="100%" stopColor="#eaedf2" />
        </linearGradient>

        {/* Ambient Shadow for Dark Buttons */}
        <filter id={`${id}-darkShadow`} x="-25%" y="-25%" width="160%" height="160%">
          <feDropShadow dx="0" dy="14" stdDeviation="16" floodColor="#000000" floodOpacity="0.28" />
        </filter>

        {/* Green Pill Shadow & Glow */}
        <filter id={`${id}-greenShadow`} x="-30%" y="-20%" width="170%" height="150%">
          <feDropShadow dx="0" dy="18" stdDeviation="22" floodColor="#047337" floodOpacity="0.35" />
          <feDropShadow dx="0" dy="8" stdDeviation="10" floodColor="#000000" floodOpacity="0.2" />
        </filter>

        {/* Symbol Drop Shadow */}
        <filter id={`${id}-symbolShadow`} x="-30%" y="-30%" width="170%" height="170%">
          <feDropShadow dx="0" dy="4" stdDeviation="4" floodColor="#000000" floodOpacity="0.35" />
        </filter>

        {/* Squircle and Circle Clip Paths */}
        <clipPath id={`${id}-squircleClip`}>
          <rect width="1024" height="1024" rx="224" ry="224" />
        </clipPath>
        <clipPath id={`${id}-circleClip`}>
          <circle cx="512" cy="512" r="500" />
        </clipPath>
      </defs>

      <g clipPath={shape === 'circle' ? `url(#${id}-circleClip)` : `url(#${id}-squircleClip)`}>
        {/* Base background plate */}
        {shape === 'circle' ? (
          <circle cx="512" cy="512" r="500" fill={`url(#${id}-bgVignette)`} stroke="#d5dce6" strokeWidth="8" />
        ) : (
          <rect width="1024" height="1024" rx="224" ry="224" fill={`url(#${id}-bgVignette)`} stroke="#d5dce6" strokeWidth="8" />
        )}

      {/* 1. TOP LEFT BUTTON: MINUS (-) */}
      <g filter={`url(#${id}-darkShadow)`}>
        <circle
          cx="328"
          cy="314"
          r="158"
          fill={`url(#${id}-darkFace)`}
          stroke={`url(#${id}-darkRim)`}
          strokeWidth="4"
        />
        <path
          d="M 180 300 A 150 150 0 0 1 476 300 A 154 146 0 0 0 180 300 Z"
          fill="rgba(255, 255, 255, 0.16)"
        />
      </g>
      {/* Minus bar */}
      <g filter={`url(#${id}-symbolShadow)`}>
        <rect x="244" y="293" width="168" height="42" rx="21" fill={`url(#${id}-whiteSymbol)`} />
        <rect x="248" y="294" width="160" height="10" rx="5" fill="rgba(255, 255, 255, 0.7)" />
      </g>

      {/* 2. BOTTOM LEFT BUTTON: PLUS (+) */}
      <g filter={`url(#${id}-darkShadow)`}>
        <circle
          cx="328"
          cy="710"
          r="158"
          fill={`url(#${id}-darkFace)`}
          stroke={`url(#${id}-darkRim)`}
          strokeWidth="4"
        />
        <path
          d="M 180 696 A 150 150 0 0 1 476 696 A 154 146 0 0 0 180 696 Z"
          fill="rgba(255, 255, 255, 0.16)"
        />
      </g>
      {/* Plus bars */}
      <g filter={`url(#${id}-symbolShadow)`}>
        <rect x="244" y="689" width="168" height="42" rx="21" fill={`url(#${id}-whiteSymbol)`} />
        <rect x="307" y="626" width="42" height="168" rx="21" fill={`url(#${id}-whiteSymbol)`} />
        <rect x="248" y="690" width="160" height="9" rx="4.5" fill="rgba(255, 255, 255, 0.7)" />
        <rect x="310" y="628" width="36" height="12" rx="6" fill="rgba(255, 255, 255, 0.7)" />
      </g>

      {/* 3. RIGHT BUTTON: TALL GREEN EQUALS CAPSULE (=) */}
      <g filter={`url(#${id}-greenShadow)`}>
        <rect
          x="536"
          y="157"
          width="320"
          height="710"
          rx="160"
          fill={`url(#${id}-greenPill)`}
          stroke={`url(#${id}-pillRim)`}
          strokeWidth="3.5"
        />
        <path
          d="M 548 310 C 548 200, 620 166, 696 166 C 772 166, 844 200, 844 310 C 844 240, 780 190, 696 190 C 612 190, 548 240, 548 310 Z"
          fill={`url(#${id}-glassSheen)`}
        />
        <path
          d="M 566 740 C 600 810, 650 850, 696 850 C 742 850, 792 810, 826 740 C 786 790, 742 815, 696 815 C 650 815, 606 790, 566 740 Z"
          fill="rgba(255, 255, 255, 0.28)"
        />
      </g>
      {/* Equals bars */}
      <g filter={`url(#${id}-symbolShadow)`}>
        <rect x="612" y="464" width="168" height="42" rx="21" fill={`url(#${id}-whiteSymbol)`} />
        <rect x="616" y="465" width="160" height="9" rx="4.5" fill="rgba(255, 255, 255, 0.75)" />
        <rect x="612" y="534" width="168" height="42" rx="21" fill={`url(#${id}-whiteSymbol)`} />
        <rect x="616" y="535" width="160" height="9" rx="4.5" fill="rgba(255, 255, 255, 0.75)" />
      </g>
    </g>
  </svg>
);
};
