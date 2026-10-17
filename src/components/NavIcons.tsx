import React from 'react';
import { CalculatorMode } from '../types';

export type NavIconId = CalculatorMode | 'recents' | 'settings' | 'sound';

interface NavIconProps {
  id: NavIconId;
  active?: boolean;
  size?: number;
  className?: string;
  style?: React.CSSProperties;
}

/**
 * Modern Vector Navigation Icons crafted to match Google Material 3 Expressive guidelines
 * and user specifications:
 * - Calculator: squircle body with rectangular screen and 3x2 dot keypad
 * - Physics Lab: quantum atom with circular nucleus and intersecting elliptical orbits
 * - Converter: opposing horizontal reciprocal arrows (top left ←, bottom right →)
 * - Finance: scalloped rosette medallion badge with dollar currency symbol ($)
 * - Recents: counter-clockwise circular rewind arrow with clock hands at center
 * - Settings: authentic Google Material 3 rounded gear cog with circular center
 */
export const NavIcon: React.FC<NavIconProps> = ({
  id,
  active = false,
  size = 24,
  className = '',
  style = {},
}) => {
  const commonProps = {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    xmlns: 'http://www.w3.org/2000/svg',
    className: `transition-transform duration-200 ease-out ${className}`,
    style,
    'aria-hidden': true,
  };

  switch (id) {
    case 'standard':
    case 'scientific':
      // Calculator: Squircle outline, screen display bar, 3x2 dot keypad
      return (
        <svg {...commonProps}>
          {/* Outer calculator squircle body */}
          <rect
            x="4"
            y="2.5"
            width="16"
            height="19"
            rx="4.5"
            stroke="currentColor"
            strokeWidth={active ? 2 : 1.8}
          />
          {/* Top screen display viewport */}
          <rect
            x="7"
            y="5.5"
            width="10"
            height="3.2"
            rx="1.1"
            stroke="currentColor"
            strokeWidth={active ? 1.6 : 1.4}
          />
          {/* Keypad: 3 rows x 2 columns of tactile keys */}
          <circle cx="8.5" cy="11.8" r="1.1" fill="currentColor" />
          <circle cx="15.5" cy="11.8" r="1.1" fill="currentColor" />
          <circle cx="8.5" cy="15" r="1.1" fill="currentColor" />
          <circle cx="15.5" cy="15" r="1.1" fill="currentColor" />
          <circle cx="8.5" cy="18.2" r="1.1" fill="currentColor" />
          <circle cx="15.5" cy="18.2" r="1.1" fill="currentColor" />
        </svg>
      );

    case 'physics':
      // Physics Lab: Quantum atom with nucleus and intersecting diagonal orbits
      return (
        <svg {...commonProps}>
          {/* Central atomic nucleus */}
          <circle cx="12" cy="12" r="1.9" fill="currentColor" />
          {/* Orbit 1: Tilted -35° */}
          <ellipse
            cx="12"
            cy="12"
            rx="9.2"
            ry="4"
            transform="rotate(-35 12 12)"
            stroke="currentColor"
            strokeWidth={active ? 2 : 1.8}
          />
          {/* Orbit 2: Tilted +35° */}
          <ellipse
            cx="12"
            cy="12"
            rx="9.2"
            ry="4"
            transform="rotate(35 12 12)"
            stroke="currentColor"
            strokeWidth={active ? 2 : 1.8}
          />
        </svg>
      );

    case 'converter':
      // Converter: Opposing horizontal reciprocal arrows (top points LEFT, bottom points RIGHT)
      return (
        <svg {...commonProps}>
          {/* Top Arrow: pointing LEFT */}
          <path
            d="M 18.5 8 H 5.5 M 9.5 4.5 L 5.5 8 L 9.5 11.5"
            stroke="currentColor"
            strokeWidth={active ? 2.2 : 1.9}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {/* Bottom Arrow: pointing RIGHT */}
          <path
            d="M 5.5 16 H 18.5 M 14.5 12.5 L 18.5 16 L 14.5 19.5"
            stroke="currentColor"
            strokeWidth={active ? 2.2 : 1.9}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      );

    case 'finance':
      // Finance: 8-lobed scalloped rosette / flower medallion badge with dollar currency symbol ($)
      return (
        <svg {...commonProps}>
          {/* Scalloped 8-lobe circular medallion body */}
          <path
            d="M 12 2.5 C 13.5 2.5 14.6 3.6 15.7 4.1 C 17 4.3 18.2 5.2 18.6 6.5 C 19 7.8 18.6 9.1 19.4 10.3 C 20 11.4 20 12.6 19.4 13.7 C 18.6 14.9 19 16.2 18.6 17.5 C 18.2 18.8 17 19.7 15.7 19.9 C 14.6 20.4 13.5 21.5 12 21.5 C 10.5 21.5 9.4 20.4 8.3 19.9 C 7 19.7 5.8 18.8 5.4 17.5 C 5 16.2 5.4 14.9 4.6 13.7 C 4 12.6 4 11.4 4.6 10.3 C 5.4 9.1 5 7.8 5.4 6.5 C 5.8 5.2 7 4.3 8.3 4.1 C 9.4 3.6 10.5 2.5 12 2.5 Z"
            stroke="currentColor"
            strokeWidth={active ? 2 : 1.8}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {/* Dollar symbol ($) inside medallion */}
          <path
            d="M 12 6.5 V 17.5 M 14.2 9.2 C 14.2 8 13.2 7.2 12 7.2 C 10.6 7.2 9.8 8 9.8 9.2 C 9.8 11.4 14.2 11 14.2 13.2 C 14.2 14.4 13.3 15.2 12 15.2 C 10.5 15.2 9.6 14.4 9.6 13.2"
            stroke="currentColor"
            strokeWidth={active ? 2 : 1.8}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      );

    case 'recents':
      // Brand New Recents: Modern Chronometer & Calculation Time-Tape Glyph
      // Features a sleek dynamic rewind arc, precision watchmaker hands, central hub, and chronometer quadrant ticks
      return (
        <svg {...commonProps}>
          {/* Outer dynamic rewind orbital track */}
          <path
            d="M 12 3.2 C 7.14 3.2 3.2 7.14 3.2 12 C 3.2 16.86 7.14 20.8 12 20.8 C 16.86 20.8 20.8 16.86 20.8 12 C 20.8 9.3 19.6 6.9 17.65 5.3"
            stroke="currentColor"
            strokeWidth={active ? 2.1 : 1.85}
            strokeLinecap="round"
          />
          {/* Modern aerodynamic rewind arrow tip */}
          <path
            d="M 11.5 1.2 L 7.2 3.5 L 11.5 5.8"
            stroke="currentColor"
            strokeWidth={active ? 2.1 : 1.85}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {/* Subtle chronometer quadrant index ticks */}
          <path
            d="M 12 6.2 V 7.4 M 17.8 12 H 16.6 M 12 17.8 V 16.6 M 6.2 12 H 7.4"
            stroke="currentColor"
            strokeWidth={active ? 1.5 : 1.3}
            strokeLinecap="round"
            opacity={0.6}
          />
          {/* Precision clock center hub */}
          <circle cx="12" cy="12" r={active ? 1.9 : 1.6} fill="currentColor" />
          {/* Precision clock hands: 10:10 / 9:00 angled trajectory */}
          <path
            d="M 12 8.2 V 12 L 15.2 13.6"
            stroke="currentColor"
            strokeWidth={active ? 2.1 : 1.85}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      );

    case 'settings':
      // Settings: Official Material 3 cog gear with rounded teeth and circular center
      return (
        <svg {...commonProps}>
          {active ? (
            <path
              fillRule="evenodd"
              clipRule="evenodd"
              d="M 19.4 13 C 19.45 12.67 19.5 12.34 19.5 12 C 19.5 11.66 19.45 11.33 19.4 11 L 21.54 9.33 C 21.73 9.18 21.79 8.91 21.66 8.69 L 19.66 5.23 C 19.53 5.01 19.27 4.93 19.04 5.02 L 16.53 6.03 C 16 5.62 15.43 5.29 14.8 5.03 L 14.42 2.37 C 14.39 2.12 14.18 1.93 13.92 1.93 H 9.92 C 9.66 1.93 9.45 2.12 9.42 2.37 L 9.04 5.03 C 8.41 5.29 7.84 5.62 7.31 6.03 L 4.8 5.02 C 4.57 4.93 4.31 5.01 4.18 5.23 L 2.18 8.69 C 2.05 8.91 2.11 9.18 2.3 9.33 L 4.44 11 C 4.39 11.33 4.34 11.66 4.34 12 C 4.34 12.34 4.39 12.67 4.44 13 L 2.3 14.67 C 2.11 14.82 2.05 15.09 2.18 15.31 L 4.18 18.77 C 4.31 18.99 4.57 19.07 4.8 18.98 L 7.31 17.97 C 7.84 18.38 8.41 18.71 9.04 18.97 L 9.42 21.63 C 9.45 21.88 9.66 22.07 9.92 22.07 H 13.92 C 14.18 22.07 14.39 21.88 14.42 21.63 L 14.8 18.97 C 15.43 18.71 16 18.38 16.53 17.97 L 19.04 18.98 C 19.27 19.07 19.53 18.99 19.66 18.77 L 21.66 15.31 C 21.79 15.09 21.73 14.82 21.54 14.67 L 19.4 13 Z M 12 15.5 C 13.93 15.5 15.5 13.93 15.5 12 C 15.5 10.07 13.93 8.5 12 8.5 C 10.07 8.5 8.5 10.07 8.5 12 C 8.5 13.93 10.07 15.5 12 15.5 Z"
              fill="currentColor"
            />
          ) : (
            <>
              {/* Circular gear center */}
              <circle cx="12" cy="12" r="3.3" stroke="currentColor" strokeWidth="1.9" />
              {/* Material 3 Gear Teeth Profile */}
              <path
                d="M 19.4 13 C 19.45 12.67 19.5 12.34 19.5 12 C 19.5 11.66 19.45 11.33 19.4 11 L 21.54 9.33 C 21.73 9.18 21.79 8.91 21.66 8.69 L 19.66 5.23 C 19.53 5.01 19.27 4.93 19.04 5.02 L 16.53 6.03 C 16 5.62 15.43 5.29 14.8 5.03 L 14.42 2.37 C 14.39 2.12 14.18 1.93 13.92 1.93 H 9.92 C 9.66 1.93 9.45 2.12 9.42 2.37 L 9.04 5.03 C 8.41 5.29 7.84 5.62 7.31 6.03 L 4.8 5.02 C 4.57 4.93 4.31 5.01 4.18 5.23 L 2.18 8.69 C 2.05 8.91 2.11 9.18 2.3 9.33 L 4.44 11 C 4.39 11.33 4.34 11.66 4.34 12 C 4.34 12.34 4.39 12.67 4.44 13 L 2.3 14.67 C 2.11 14.82 2.05 15.09 2.18 15.31 L 4.18 18.77 C 4.31 18.99 4.57 19.07 4.8 18.98 L 7.31 17.97 C 7.84 18.38 8.41 18.71 9.04 18.97 L 9.42 21.63 C 9.45 21.88 9.66 22.07 9.92 22.07 H 13.92 C 14.18 22.07 14.39 21.88 14.42 21.63 L 14.8 18.97 C 15.43 18.71 16 18.38 16.53 17.97 L 19.04 18.98 C 19.27 19.07 19.53 18.99 19.66 18.77 L 21.66 15.31 C 21.79 15.09 21.73 14.82 21.54 14.67 L 19.4 13 Z"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </>
          )}
        </svg>
      );

    case 'sound':
      return active ? (
        <svg {...commonProps}>
          <path
            d="M 4 10 H 7.5 L 12 6 V 18 L 7.5 14 H 4 C 3.45 14 3 13.55 3 13 V 11 C 3 10.45 3.45 10 4 10 Z"
            fill="currentColor"
          />
          <path
            d="M 15.5 8.5 C 16.8 9.8 17.5 11.5 17.5 12 C 17.5 12.5 16.8 14.2 15.5 15.5"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
          />
          <path
            d="M 18.5 5.5 C 20.5 7.5 21.5 10 21.5 12 C 21.5 14 20.5 16.5 18.5 18.5"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
          />
        </svg>
      ) : (
        <svg {...commonProps}>
          <path
            d="M 4 10 H 7.5 L 12 6 V 18 L 7.5 14 H 4 C 3.45 14 3 13.55 3 13 V 11 C 3 10.45 3.45 10 4 10 Z"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinejoin="round"
          />
          <path
            d="M 16 9.5 L 21 14.5 M 21 9.5 L 16 14.5"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          />
        </svg>
      );

    case 'grapher':
      return (
        <svg {...commonProps}>
          <path
            d="M 3.5 4 V 20 H 19.5"
            stroke="currentColor"
            strokeWidth="1.9"
            strokeLinecap="round"
          />
          <path
            d="M 4 15.5 Q 7.5 6.5, 11 12 T 18 8.5"
            stroke="currentColor"
            strokeWidth="1.9"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <circle cx="8" cy="8.5" r="1.3" fill="currentColor" />
          <circle cx="14.5" cy="14" r="1.3" fill="currentColor" />
        </svg>
      );

    default:
      return null;
  }
};
