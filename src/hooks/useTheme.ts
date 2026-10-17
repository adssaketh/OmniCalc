import { useState, useEffect } from 'react';

export interface ThemeColors {
  accent: string;
  accentRgb: string;
  textColor: string;
}

export interface UseThemeReturn {
  currentTheme: ThemeColors;
}

export function useTheme(): UseThemeReturn {
  const [currentTheme, setCurrentTheme] = useState<ThemeColors>({
    accent: '#10b981',
    accentRgb: '16, 185, 129',
    textColor: 'text-emerald-400',
  });

  useEffect(() => {
    // Sync with DOM css variables if available
    try {
      const primary = getComputedStyle(document.documentElement)
        .getPropertyValue('--m3-primary')
        .trim();
      if (primary) {
        let rgb = '16, 185, 129';
        if (primary.startsWith('#')) {
          const hex = primary.replace('#', '');
          if (hex.length === 6) {
            const r = parseInt(hex.substring(0, 2), 16);
            const g = parseInt(hex.substring(2, 4), 16);
            const b = parseInt(hex.substring(4, 6), 16);
            rgb = `${r}, ${g}, ${b}`;
          }
        } else if (primary.startsWith('rgb')) {
          const match = primary.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
          if (match) {
            rgb = `${match[1]}, ${match[2]}, ${match[3]}`;
          }
        }
        setCurrentTheme({
          accent: primary,
          accentRgb: rgb,
          textColor: 'text-emerald-400',
        });
      }
    } catch {
      // ignore in test environments
    }
  }, []);

  return { currentTheme };
}
