import { Capacitor, registerPlugin } from '@capacitor/core';

export interface DynamicColorPluginInterface {
  getColors(): Promise<{
    supported: boolean;
    isDark: boolean;
    colors?: Record<string, string>;
  }>;
}

const DynamicColor = registerPlugin<DynamicColorPluginInterface>('DynamicColor');

export interface SystemColors {
  supported: boolean;
  isDark: boolean;
  colors: Record<string, string>;
}

/**
 * Returns system dynamic colors if available (Android 12+), or null if unsupported/web.
 */
export async function getSystemColors(): Promise<SystemColors | null> {
  if (!Capacitor.isNativePlatform()) {
    return null;
  }
  try {
    const res = await DynamicColor.getColors();
    if (res && res.supported && res.colors) {
      return {
        supported: true,
        isDark: !!res.isDark,
        colors: res.colors,
      };
    }
  } catch {
    // DynamicColor plugin not available or error occurred
  }
  return null;
}

/**
 * Maps system palette tokens (accent1, accent2, accent3, neutral1, neutral2)
 * to standard Material 3 Expressive CSS variables on document.documentElement.
 */
export function applyDynamicTokens(
  colors: Record<string, string>,
  isDark: boolean
): { surfaceColor: string } {
  const get = (key: string, fallback: string): string => {
    return colors[key] || fallback;
  };

  const tokens = isDark
    ? {
        '--m3-primary': get('system_accent1_200', '#a8c7fa'),
        '--m3-on-primary': get('system_accent1_800', '#062e6f'),
        '--m3-primary-container': get('system_accent1_700', '#264585'),
        '--m3-on-primary-container': get('system_accent1_100', '#d3e3fd'),

        '--m3-secondary': get('system_accent2_200', '#bdc7dc'),
        '--m3-on-secondary': get('system_accent2_800', '#273142'),
        '--m3-secondary-container': get('system_accent2_700', '#334460'),
        '--m3-on-secondary-container': get('system_accent2_100', '#dce2f9'),

        '--m3-tertiary': get('system_accent3_200', '#efb8c8'),
        '--m3-on-tertiary': get('system_accent3_800', '#492532'),
        '--m3-tertiary-container': get('system_accent3_700', '#493344'),
        '--m3-on-tertiary-container': get('system_accent3_100', '#ffd8e4'),

        '--m3-surface': get('system_neutral1_900', '#111318'),
        '--m3-surface-dim': get('system_neutral1_900', '#0b0d12'),
        '--m3-surface-bright': get('system_neutral1_800', '#37393e'),
        '--m3-surface-container-lowest': 'color-mix(in srgb, var(--m3-surface) 82%, black)',
        // Was the same colour as the page, so cards disappeared in dark mode. Now one clear step lighter.
        '--m3-surface-container-low': 'color-mix(in srgb, var(--m3-surface) 93%, var(--m3-on-surface))',
        '--m3-surface-container': get('system_neutral1_800', '#1d2024'),
        '--m3-surface-container-high': get('system_neutral1_700', '#282a2f'),
        '--m3-surface-container-highest': get('system_neutral1_600', '#33353a'),

        '--m3-on-surface': get('system_neutral1_100', '#e2e2e9'),
        '--m3-surface-variant': get('system_neutral2_700', '#43474e'),
        '--m3-on-surface-variant': get('system_neutral2_200', '#c3c7cf'),
        '--m3-outline': get('system_neutral2_400', '#8c9199'),
        '--m3-outline-variant': get('system_neutral2_700', '#43474e'),

        '--m3-error': '#ffb4ab',
        '--m3-on-error': '#690005',
        '--m3-error-container': '#93000a',
        '--m3-on-error-container': '#ffdad6',

        '--m3-scrim': 'rgba(0, 0, 0, 0.75)',
      }
    : {
        '--m3-primary': get('system_accent1_600', '#0b57d0'),
        '--m3-on-primary': get('system_accent1_0', '#ffffff'),
        '--m3-primary-container': get('system_accent1_100', '#d3e3fd'),
        '--m3-on-primary-container': get('system_accent1_900', '#041e49'),

        '--m3-secondary': get('system_accent2_600', '#4f607c'),
        '--m3-on-secondary': '#ffffff',
        '--m3-secondary-container': get('system_accent2_100', '#d7e3ff'),
        '--m3-on-secondary-container': get('system_accent2_900', '#091b35'),

        '--m3-tertiary': get('system_accent3_600', '#6f5575'),
        '--m3-on-tertiary': '#ffffff',
        '--m3-tertiary-container': get('system_accent3_100', '#f9d8fe'),
        '--m3-on-tertiary-container': get('system_accent3_900', '#28132e'),

        '--m3-surface': get('system_neutral1_10', '#f8f9fa'),
        '--m3-surface-dim': get('system_neutral1_50', '#dadce0'),
        '--m3-surface-bright': '#ffffff',
        '--m3-surface-container-lowest': '#ffffff',
        '--m3-surface-container-low': get('system_neutral1_50', '#f0f4f9'),
        '--m3-surface-container': get('system_neutral1_100', '#e9eef6'),
        '--m3-surface-container-high': get('system_neutral1_200', '#e1e7f0'),
        '--m3-surface-container-highest': get('system_neutral1_300', '#d8e0ec'),

        '--m3-on-surface': get('system_neutral1_900', '#1f1f1f'),
        '--m3-surface-variant': get('system_neutral2_100', '#e1e2ec'),
        '--m3-on-surface-variant': get('system_neutral2_700', '#444746'),
        '--m3-outline': get('system_neutral2_500', '#747775'),
        '--m3-outline-variant': get('system_neutral2_200', '#c4c7c5'),

        '--m3-error': '#ba1a1a',
        '--m3-on-error': '#ffffff',
        '--m3-error-container': '#ffdad6',
        '--m3-on-error-container': '#410002',

        '--m3-scrim': 'rgba(0, 0, 0, 0.4)',
      };

  const root = document.documentElement;
  for (const [key, value] of Object.entries(tokens)) {
    root.style.setProperty(key, value);
  }

  const surfaceColor = tokens['--m3-surface'];
  return { surfaceColor };
}

/**
 * Removes custom dynamic CSS variables from document.documentElement
 * so that standard theme classes ([data-m3-theme]) take effect.
 */
export function clearDynamicTokens(): void {
  const root = document.documentElement;
  const tokenNames = [
    '--m3-primary',
    '--m3-on-primary',
    '--m3-primary-container',
    '--m3-on-primary-container',
    '--m3-secondary',
    '--m3-on-secondary',
    '--m3-secondary-container',
    '--m3-on-secondary-container',
    '--m3-tertiary',
    '--m3-on-tertiary',
    '--m3-tertiary-container',
    '--m3-on-tertiary-container',
    '--m3-surface',
    '--m3-surface-dim',
    '--m3-surface-bright',
    '--m3-surface-container-lowest',
    '--m3-surface-container-low',
    '--m3-surface-container',
    '--m3-surface-container-high',
    '--m3-surface-container-highest',
    '--m3-on-surface',
    '--m3-surface-variant',
    '--m3-on-surface-variant',
    '--m3-outline',
    '--m3-outline-variant',
    '--m3-error',
    '--m3-on-error',
    '--m3-error-container',
    '--m3-on-error-container',
    '--m3-scrim',
  ];
  for (const name of tokenNames) {
    root.style.removeProperty(name);
  }
}
