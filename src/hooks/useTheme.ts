import { useState, useEffect } from 'react';

export interface ThemeColors {
  accent: string;
  accentRgb: string;
  accentContainer: string;
  onAccentContainer: string;
  textColor: string;
  isDark: boolean;
}

export interface UseThemeReturn {
  currentTheme: ThemeColors;
}

export function useTheme(): UseThemeReturn {
  const getThemeState = (): ThemeColors => {
    if (typeof document === 'undefined') {
      return {
        accent: '#10b981',
        accentRgb: '16, 185, 129',
        accentContainer: '#d3e3fd',
        onAccentContainer: '#041e49',
        textColor: 'text-emerald-400',
        isDark: true,
      };
    }

    const isLight = document.documentElement.getAttribute('data-m3-mode') === 'light';
    const isDark = !isLight;
    const compStyle = getComputedStyle(document.documentElement);
    const primary = compStyle.getPropertyValue('--m3-primary').trim() || (isDark ? '#a8c7fa' : '#0b57d0');
    const primaryContainer = compStyle.getPropertyValue('--m3-primary-container').trim() || (isDark ? '#264585' : '#d3e3fd');
    const onPrimaryContainer = compStyle.getPropertyValue('--m3-on-primary-container').trim() || (isDark ? '#d3e3fd' : '#041e49');

    let rgb = isDark ? '168, 199, 250' : '11, 87, 208';
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

    return {
      accent: primary,
      accentRgb: rgb,
      accentContainer: primaryContainer,
      onAccentContainer: onPrimaryContainer,
      textColor: isDark ? 'text-emerald-400' : 'text-emerald-700',
      isDark,
    };
  };

  const [currentTheme, setCurrentTheme] = useState<ThemeColors>(getThemeState);

  useEffect(() => {
    const update = () => {
      setCurrentTheme(getThemeState());
    };

    update();

    const observer = new MutationObserver((mutations) => {
      for (const m of mutations) {
        if (m.type === 'attributes' && (m.attributeName === 'data-m3-mode' || m.attributeName === 'data-m3-theme' || m.attributeName === 'style')) {
          update();
          break;
        }
      }
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-m3-mode', 'data-m3-theme', 'style'],
    });

    const mq = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
    const mediaHandler = () => update();
    if (mq?.addEventListener) {
      mq.addEventListener('change', mediaHandler);
    }

    return () => {
      observer.disconnect();
      if (mq?.removeEventListener) {
        mq.removeEventListener('change', mediaHandler);
      }
    };
  }, []);

  return { currentTheme };
}

