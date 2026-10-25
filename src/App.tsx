/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useLayoutEffect, useRef } from 'react';
import { CalculatorMode, HistoryItem, AppSettings, AngleMode } from './types';
import { Capacitor } from '@capacitor/core';
import { App as CapApp } from '@capacitor/app';
import { StatusBar, Style } from '@capacitor/status-bar';
import { Header } from './components/Header';
import { BottomNavBar } from './components/BottomNavBar';
import { NavigationRail } from './components/NavigationRail';
import { CalculatorScreen } from './components/CalculatorScreen';
import { ConverterScreen } from './components/ConverterScreen';
import { FinanceScreen } from './components/FinanceScreen';
import { PhysicsScreen } from './components/PhysicsScreen';
import { GraphScreen } from './components/GraphScreen';
import { HistoryTapeModal } from './components/HistoryTapeModal';
import { SettingsModal } from './components/SettingsModal';
import { GuideSheet } from './components/GuideSheet';
import { FADE_PX, GLASS_BLUR_PX, glassFillPercent, glassFillStrongPercent, buildEdgeMask, buildBlurLayers } from './edgeEffects';
import { soundFx } from './utils/audio';
import { useOrientation } from './hooks/useOrientation';
import {
  getSystemColors,
  applyDynamicTokens,
  clearDynamicTokens,
  SystemColors,
} from './native/dynamicColor';
import { initDeepLinks } from './native/deepLinks';

const DEFAULT_SETTINGS: AppSettings = {
  soundEnabled: true,
  hapticEnabled: true,
  vibrationIntensity: 'medium',
  angleMode: 'deg',
  decimalPrecision: -1,
  theme: 'dynamic',
  colorMode: 'system',
  currencySymbol: '₹',
  currencyCode: 'INR',
  enableGrapher: false,
  edgeEffect: 'fade',
  fadeHeight: 'medium',
  barStyle: 'solid',
  glassTransparency: 70,
  glassBlur: 'medium',
  glassEdge: true,
};

/** Page background per theme, used for the status bar and the root element. */
const DARK_SURFACES: Record<string, string> = {
  dynamic: '#111318',
  'm3-iris': '#111318',
  'm3-ocean': '#0e1417',
  'm3-forest': '#101510',
  'm3-sunset': '#171210',
  'm3-amoled': '#000000',
  'oled-midnight': '#000000',
  'cyber-emerald': '#101510',
  'dark-obsidian': '#111318',
};

const LIGHT_SURFACES: Record<string, string> = {
  dynamic: '#f8f9fa',
  'm3-iris': '#f8f9fa',
  'm3-ocean': '#f5fbfa',
  'm3-forest': '#f7fbf2',
  'm3-sunset': '#fff8f6',
  'm3-amoled': '#ffffff',
  'oled-midnight': '#ffffff',
  'cyber-emerald': '#f7fbf2',
  'dark-obsidian': '#f8f9fa',
};

/** Value of the data-m3-theme attribute for each theme id (see index.css). */
const THEME_DATA_ATTR: Record<string, string> = {
  'm3-ocean': 'oceanic',
  'm3-forest': 'forest',
  'cyber-emerald': 'forest',
  'm3-sunset': 'sunset',
  'm3-amoled': 'amoled',
  'oled-midnight': 'amoled',
};

export default function App() {
  const [currentMode, setCurrentMode] = useState<CalculatorMode>('standard');
  const [isHistoryOpen, setIsHistoryOpen] = useState<boolean>(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState<boolean>(false);
  const [isGuideOpen, setIsGuideOpen] = useState<boolean>(false);
  const [externalExpression, setExternalExpression] = useState<string>('');
  const [externalSeq, setExternalSeq] = useState<number>(0);
  const [pinnedSlot, setPinnedSlot] = useState<HTMLElement | null>(null);
  const [topH, setTopH] = useState<number>(84);
  const [headerH, setHeaderH] = useState<number>(72);
  const [bottomH, setBottomH] = useState<number>(88);
  const topStackRef = useRef<HTMLDivElement>(null);
  const bottomStackRef = useRef<HTMLDivElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const columnRef = useRef<HTMLDivElement>(null);
  const [systemColors, setSystemColors] = useState<SystemColors | null>(null);

  // Persisted History
  const [history, setHistory] = useState<HistoryItem[]>(() => {
    try {
      const saved = localStorage.getItem('omni_calc_history');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  // Persisted Settings
  const [settings, setSettings] = useState<AppSettings>(() => {
    try {
      const saved = localStorage.getItem('omni_calc_settings');
      return saved ? { ...DEFAULT_SETTINGS, ...JSON.parse(saved) } : DEFAULT_SETTINGS;
    } catch {
      return DEFAULT_SETTINGS;
    }
  });

  // Save history to localStorage
  useEffect(() => {
    try {
      localStorage.setItem('omni_calc_history', JSON.stringify(history));
    } catch {
      // storage full or blocked
    }
  }, [history]);

  // Save settings to localStorage
  useEffect(() => {
    try {
      localStorage.setItem('omni_calc_settings', JSON.stringify(settings));
    } catch {
      // ignore
    }
  }, [settings]);

  // Add calculation to history tape
  const handleAddHistory = (item: Omit<HistoryItem, 'id' | 'timestamp'>) => {
    const newItem: HistoryItem = {
      ...item,
      id: Math.random().toString(36).substring(2, 9),
      timestamp: Date.now(),
    };
    setHistory((prev) => [newItem, ...prev.slice(0, 99)]);
  };

  const handleClearHistory = () => {
    setHistory([]);
  };

  /** Puts text into the calculator display; the sequence number makes loading the same text twice work */
  const loadExpression = (expr: string) => {
    setExternalExpression(expr);
    setExternalSeq((n) => n + 1);
  };

  const handleSelectResult = (val: string) => {
    loadExpression(val);
    setCurrentMode('standard');
  };

  const handleTryExample = (expr: string, angle?: AngleMode) => {
    if (angle) handleUpdateSettings({ angleMode: angle });
    setIsGuideOpen(false);
    setIsHistoryOpen(false);
    setCurrentMode('standard');
    loadExpression(expr);
  };

  const handleUpdateSettings = (partial: Partial<AppSettings>) => {
    setSettings((prev) => ({ ...prev, ...partial }));
  };

  // Sync vibration intensity with soundFx engine
  useEffect(() => {
    if (settings.vibrationIntensity) {
      soundFx.setVibrationIntensity(settings.vibrationIntensity);
    }
  }, [settings.vibrationIntensity]);

  // If grapher is turned off in settings, return to standard calculator
  useEffect(() => {
    if (!settings.enableGrapher && currentMode === 'grapher') {
      setCurrentMode('standard');
    }
  }, [settings.enableGrapher, currentMode]);

  // Launcher Shortcuts and Deep Links (cold start and warm start)
  useEffect(() => {
    return initDeepLinks((targetMode) => {
      setCurrentMode(targetMode);
      setIsHistoryOpen(false);
      setIsSettingsOpen(false);
      setExternalExpression('');
    });
  }, []);

  // Native Dynamic System Colours (Android 12+ Monet)
  useEffect(() => {
    let isMounted = true;
    const refresh = async () => {
      const colors = await getSystemColors();
      if (!isMounted) return;
      if (colors && colors.supported) {
        setSystemColors(colors);
        try {
          const userChosen = localStorage.getItem('omni_calc_settings_theme_user_set');
          // Only auto-default to dynamic colours if the user never picked a
          // theme AND the saved theme isn't already a deliberate non-default
          // (e.g. pure black saved by an older build that didn't set the flag).
          if (!userChosen) {
            setSettings((prev) =>
              prev.theme === 'm3-amoled' || prev.theme === 'dynamic'
                ? prev
                : { ...prev, theme: 'dynamic' },
            );
          }
        } catch {
          // ignore
        }
      }
    };

    refresh();

    // Listen for MainActivity onConfigurationChanged custom event
    const onSystemThemeChanged = () => {
      refresh();
    };
    window.addEventListener('systemThemeChanged', onSystemThemeChanged);

    // Listen for Capacitor App state change (app resuming / becoming active)
    let appStateHandle: Promise<{ remove: () => Promise<void> }> | null = null;
    if (Capacitor.isNativePlatform()) {
      appStateHandle = CapApp.addListener('appStateChange', (state) => {
        if (state.isActive) {
          refresh();
        }
      });
    }

    return () => {
      isMounted = false;
      window.removeEventListener('systemThemeChanged', onSystemThemeChanged);
      if (appStateHandle) {
        appStateHandle.then((h) => h.remove()).catch(() => {});
      }
    };
  }, []);

  const themeDataAttr = THEME_DATA_ATTR[settings.theme] ?? 'iris';

  // Live prefers-color-scheme listener (updates instantly with no reload)
  const [systemIsDark, setSystemIsDark] = useState<boolean>(() => {
    if (typeof window !== 'undefined' && window.matchMedia) {
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    }
    return true;
  });

  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = (e: MediaQueryListEvent | MediaQueryList) => {
      setSystemIsDark(e.matches);
    };

    if (mq.addEventListener) {
      mq.addEventListener('change', handler as (e: MediaQueryListEvent) => void);
      return () => mq.removeEventListener('change', handler as (e: MediaQueryListEvent) => void);
    } else if (typeof (mq as unknown as { addListener?: (fn: unknown) => void }).addListener === 'function') {
      (mq as unknown as { addListener: (fn: unknown) => void }).addListener(handler);
      return () => {
        (mq as unknown as { removeListener: (fn: unknown) => void }).removeListener(handler);
      };
    }
  }, []);

  const isDarkMode =
    settings.colorMode === 'system'
      ? systemIsDark
      : settings.colorMode === 'dark';

  // Dynamically synchronize Android status bar theme-color and root document background
  useEffect(() => {
    let surfaceColor =
      (isDarkMode ? DARK_SURFACES[settings.theme] : LIGHT_SURFACES[settings.theme]) ||
      (isDarkMode ? '#111318' : '#f8f9fa');

    // 1. Dynamic Wallpaper Colors from Android 12+ Monet
    if (settings.theme === 'dynamic' && systemColors?.colors) {
      const dyn = applyDynamicTokens(systemColors.colors, isDarkMode);
      if (dyn?.surfaceColor) {
        surfaceColor = dyn.surfaceColor;
      }
    } else {
      clearDynamicTokens();
    }

        const modeAttr = isDarkMode ? 'dark' : 'light';

    // 2. Set root HTML dataset and background colors
    document.documentElement.setAttribute('data-m3-theme', themeDataAttr);
    document.documentElement.setAttribute('data-m3-mode', modeAttr);
    document.documentElement.style.backgroundColor = surfaceColor;
    document.documentElement.style.colorScheme = isDarkMode ? 'dark' : 'light';
    document.body.style.backgroundColor = surfaceColor;

    // 3. Update Android/Browser system status bar meta tags per scheme
    const lightMeta = document.getElementById('theme-color-light');
    if (lightMeta) {
      lightMeta.setAttribute('content', settings.theme === 'dynamic' ? surfaceColor : (LIGHT_SURFACES[settings.theme] || '#f8f9fa'));
    }
    const darkMeta = document.getElementById('theme-color-dark');
    if (darkMeta) {
      darkMeta.setAttribute('content', settings.theme === 'dynamic' ? surfaceColor : (DARK_SURFACES[settings.theme] || '#111318'));
    }

    // Fallback general meta theme-color
    const metaThemeColor = document.querySelector('meta[name="theme-color"]:not([media])');
    if (metaThemeColor) {
      metaThemeColor.setAttribute('content', surfaceColor);
    }

    // 4. Synchronize native Android status bar in Capacitor
    if (Capacitor.isNativePlatform()) {
      StatusBar.setBackgroundColor({ color: surfaceColor }).catch(() => {});
      StatusBar.setStyle({ style: isDarkMode ? Style.Dark : Style.Light }).catch(() => {});
    }
  }, [settings.theme, settings.colorMode, isDarkMode, systemColors, themeDataAttr]);

  // Screens visited, so the back gesture returns to the previous screen instead of leaving the app
  const modeTrailRef = useRef<CalculatorMode[]>([]);
  const lastModeRef = useRef<CalculatorMode>(currentMode);
  const goingBackRef = useRef<boolean>(false);
  useEffect(() => {
    if (goingBackRef.current) {
      goingBackRef.current = false;
    } else if (lastModeRef.current !== currentMode) {
      const trail = modeTrailRef.current;
      if (trail[trail.length - 1] !== lastModeRef.current) trail.push(lastModeRef.current);
      if (trail.length > 20) trail.shift();
    }
    lastModeRef.current = currentMode;
  }, [currentMode]);

  const innerBackRef = useRef<(() => boolean) | null>(null); // Settings: closes its own sub-sheet first
  const lastBackPressRef = useRef<number>(0);
  const [exitHint, setExitHint] = useState<boolean>(false);

  // Always read the latest state from the back handler, which is registered only once
  const backStateRef = useRef({ isGuideOpen, isSettingsOpen, isHistoryOpen });
  backStateRef.current = { isGuideOpen, isSettingsOpen, isHistoryOpen };

  // Android back button / back gesture:
  // close the top layer first (guide, settings sub-sheet, settings, history), then go back screen by
  // screen. Only from the very first screen does it ask to press back twice to leave the app.
  useEffect(() => {
    if (!Capacitor.isNativePlatform()) return;

    const listenerPromise = CapApp.addListener('backButton', () => {
      const st = backStateRef.current;
      if (st.isGuideOpen) {
        setIsGuideOpen(false);
        return;
      }
      if (st.isSettingsOpen) {
        if (!innerBackRef.current?.()) setIsSettingsOpen(false);
        return;
      }
      if (st.isHistoryOpen) {
        setIsHistoryOpen(false);
        return;
      }
      const trail = modeTrailRef.current;
      if (trail.length > 0) {
        goingBackRef.current = true;
        const previous = trail.pop()!;
        setExternalExpression('');
        setCurrentMode(previous);
        return;
      }
      const now = Date.now();
      if (now - lastBackPressRef.current < 2000) {
        CapApp.exitApp();
        return;
      }
      lastBackPressRef.current = now;
      setExitHint(true);
      setTimeout(() => setExitHint(false), 2000);
    });

    return () => {
      listenerPromise.then((handle: { remove: () => Promise<void> }) => handle.remove()).catch(() => {});
    };
  }, []);

  const { isLandscape, isTablet, width } = useOrientation();
  const isLargeScreen = width >= 960 || (isTablet && isLandscape) || (isTablet && width >= 720);
  // Calculator (phone portrait): the header row is part of the answer display card
  const mergeHeader = currentMode === 'standard' && !isLandscape;

  // Bar style + edge effect: published on <html> so the Settings preview (a portal) sees them too
  useEffect(() => {
    const root = document.documentElement;
    root.setAttribute('data-bars', settings.barStyle);
    root.setAttribute('data-edge', settings.edgeEffect);
    root.setAttribute('data-glass-edge', settings.glassEdge ? 'on' : 'off');
    root.style.setProperty('--glass-fill', `${glassFillPercent(settings.glassTransparency)}%`);
    root.style.setProperty('--glass-blur', `${GLASS_BLUR_PX[settings.glassBlur]}px`);
    root.style.setProperty('--glass-fill-strong', `${glassFillStrongPercent(settings.glassTransparency)}%`);
  }, [settings.barStyle, settings.edgeEffect, settings.glassEdge, settings.glassTransparency, settings.glassBlur]);

  // Measure the floating bars so the scroll area, the fade mask and the keypad all follow their real height
  useLayoutEffect(() => {
    const observe = (el: HTMLElement | null, set: (h: number) => void) => {
      if (!el) {
        set(0);
        return () => {};
      }
      const update = () => set(Math.round(el.getBoundingClientRect().height));
      update();
      const ro = new ResizeObserver(update);
      ro.observe(el);
      return () => ro.disconnect();
    };
    const offTop = observe(topStackRef.current, setTopH);
    const offHeader = observe(topStackRef.current?.firstElementChild as HTMLElement | null, setHeaderH);
    const offBottom = observe(isLargeScreen ? null : bottomStackRef.current, setBottomH);
    return () => {
      offTop();
      offHeader();
      offBottom();
    };
  }, [isLargeScreen, mergeHeader]);

  // Scroll-aware edge fade: --ft (top) and --fb (bottom) go 0 -> 1 as content really slides under a bar.
  // At the top of a page, or at its very end, nothing is hidden, so nothing is faded.
  useEffect(() => {
    const scroller = scrollRef.current;
    const column = columnRef.current;
    if (!scroller || !column) return;
    const span = 48; // px of scrolling over which the edge fade eases in
    let raf = 0;
    let lastTop = -1;
    let lastBottom = -1;
    const q = (v: number) => Math.round(Math.min(1, Math.max(0, v)) * 50) / 50;
    // The header collapses on the screens that scroll; on the calculator it stays full next to the pinned display
    const headerEl = topStackRef.current?.firstElementChild as HTMLElement | null;
    const collapses = currentMode !== 'standard';
    // Collapse / expand with a little hysteresis; the easing itself is a CSS transition on --hc (index.css),
    // so the motion takes the same smooth time however fast you flick.
    let target = 0;
    let lastHc = -1;

    const update = () => {
      raf = 0;
      if (!collapses) target = 0;
      else if (scroller.scrollTop > 36) target = 1;
      else if (scroller.scrollTop < 10) target = 0;
      const hc = target;
      if (headerEl && hc !== lastHc) {
        headerEl.style.setProperty('--hc', String(hc));
        headerEl.style.setProperty('--hl', String(hc));
        headerEl.style.setProperty('--hr', String(hc));
        headerEl.style.setProperty('--hn', String(hc));
        if (lastHc !== -1) headerEl.dataset.move = hc ? 'in' : 'out'; // restarts the rubber-band animation
        lastHc = hc;
      }
      const t = q(scroller.scrollTop / span);
      const b = q((scroller.scrollHeight - scroller.clientHeight - scroller.scrollTop) / span);
      if (t !== lastTop) {
        column.style.setProperty('--ft', String(t));
        lastTop = t;
      }
      if (b !== lastBottom) {
        column.style.setProperty('--fb', String(b));
        lastBottom = b;
      }
    };
    const schedule = () => {
      if (!raf) raf = requestAnimationFrame(update);
    };

    update();
    scroller.addEventListener('scroll', schedule, { passive: true });
    const ro = new ResizeObserver(schedule); // content grows or shrinks (drawer, tables, screens)
    ro.observe(scroller);
    if (scroller.firstElementChild) ro.observe(scroller.firstElementChild);
    return () => {
      scroller.removeEventListener('scroll', schedule);
      ro.disconnect();
      if (raf) cancelAnimationFrame(raf);
    };
  }, [settings.edgeEffect, currentMode, isLargeScreen]);

  // Each screen starts at the top
  useEffect(() => {
    scrollRef.current?.scrollTo({ top: 0 });
  }, [currentMode]);

  // Global Keyboard Shortcuts for accessories and PC navigation
  useEffect(() => {
    const handleGlobalKeyDown = (e: KeyboardEvent) => {
      // If modal is open and user presses Escape, close modal
      if (e.key === 'Escape') {
        if (isGuideOpen) {
          setIsGuideOpen(false);
          return;
        }
        if (isSettingsOpen) {
          setIsSettingsOpen(false);
          return;
        }
        if (isHistoryOpen) {
          setIsHistoryOpen(false);
          return;
        }
      }

      // Check if user is typing in an input, textarea, or select
      const target = e.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.tagName === 'SELECT' ||
          target.isContentEditable)
      ) {
        return;
      }

      // Alt + Number / Letter navigation shortcuts
      if (e.altKey && !e.ctrlKey && !e.metaKey) {
        if (e.key === '1') {
          e.preventDefault();
          setCurrentMode('standard');
          setIsHistoryOpen(false);
        } else if (e.key === '2') {
          e.preventDefault();
          setCurrentMode('converter');
          setIsHistoryOpen(false);
        } else if (e.key === '3') {
          e.preventDefault();
          setCurrentMode('physics');
          setIsHistoryOpen(false);
        } else if (e.key === '4') {
          e.preventDefault();
          setCurrentMode('finance');
          setIsHistoryOpen(false);
        } else if (e.key === '5' && settings.enableGrapher) {
          e.preventDefault();
          setCurrentMode('grapher');
          setIsHistoryOpen(false);
        } else if (e.key.toLowerCase() === 'h' || e.key.toLowerCase() === 'r') {
          e.preventDefault();
          setIsHistoryOpen((prev) => !prev);
        } else if (e.key.toLowerCase() === 's' || e.key === ',') {
          e.preventDefault();
          setIsSettingsOpen((prev) => !prev);
        }
      }
    };

    window.addEventListener('keydown', handleGlobalKeyDown);
    return () => window.removeEventListener('keydown', handleGlobalKeyDown);
  }, [isSettingsOpen, isHistoryOpen, isGuideOpen, settings.enableGrapher]);

  const headerProps = {
    soundEnabled: settings.soundEnabled,
    onToggleSound: () => handleUpdateSettings({ soundEnabled: !settings.soundEnabled }),
    onOpenSettings: () => setIsSettingsOpen(true),
    onOpenGuide: () => setIsGuideOpen(true),
    onLogoTap: () => scrollRef.current?.scrollTo({ top: 0, behavior: 'smooth' }),
    theme: settings.theme,
  };
  const fadePx = FADE_PX[settings.fadeHeight];
  // With the answer display pinned under the header the bars are tall: only its lower part is see-through.
  const hasPinned = mergeHeader || topH - headerH > 8;
  const topEdge = topH - (hasPinned ? 8 : 4);
  const topGlow = hasPinned ? 34 : Math.max(26, headerH - 22);
  const edgeMask = buildEdgeMask(
    { topEdge, topGlow, bottomH: isLargeScreen ? 0 : bottomH, fadePx },
    settings.edgeEffect,
    settings.barStyle
  );
  const bottomBars = isLargeScreen ? 0 : bottomH;

  return (
    <div
      data-m3-theme={themeDataAttr}
      className="app-shell font-sans flex"
      style={
        {
          flexDirection: isLargeScreen ? 'row' : 'column',
          backgroundColor: 'var(--m3-surface)',
          color: 'var(--m3-on-surface)',
          '--top-stack-h': `${topH}px`,
          '--bottom-stack-h': `${bottomBars}px`,
        } as React.CSSProperties
      }
    >
      {/* 1. Large Screen Navigation Rail (Tablets in landscape & Desktop PCs) */}
      {isLargeScreen && (
        <NavigationRail
          currentMode={currentMode}
          onSelectMode={(mode) => {
            setIsHistoryOpen(false);
            setCurrentMode(mode);
            setExternalExpression('');
          }}
          soundEnabled={settings.soundEnabled}
          hapticEnabled={settings.hapticEnabled}
          onToggleSound={() => handleUpdateSettings({ soundEnabled: !settings.soundEnabled })}
          onOpenSettings={() => setIsSettingsOpen(true)}
          onOpenGuide={() => setIsGuideOpen(true)}
          onOpenHistory={() => setIsHistoryOpen((prev) => !prev)}
          isHistoryOpen={isHistoryOpen}
          historyCount={history.length}
          enableGrapher={settings.enableGrapher}
          theme={settings.theme}
        />
      )}

      {/* 2. Content column: scroll area underneath, floating bars on top */}
      <div ref={columnRef} className="relative flex-1 min-w-0 min-h-0">
        {/* Scroll area. The mask fades content out as it slides under the bars (Settings > Bars & scrolling). */}
        <div
          id="app-scroll"
          ref={scrollRef}
          style={{
            maskImage: edgeMask,
            WebkitMaskImage: edgeMask,
          }}
        >
          <div
            className="min-h-full flex flex-col"
            style={{
              paddingTop: 'calc(var(--top-stack-h) + 6px)',
              paddingBottom: isLargeScreen ? '24px' : 'calc(var(--bottom-stack-h) + 12px)',
            }}
          >
            <main className="flex-1 w-full max-w-[1650px] mx-auto px-2 sm:px-6 lg:px-8 py-1.5 sm:py-3 flex flex-col min-h-0">
              {/* Animated Screen Container */}
              <div key={currentMode} className="w-full flex-1 flex flex-col min-h-0 animate-m3-screen-enter">
                {currentMode === 'standard' && (
                  <CalculatorScreen
                    angleMode={settings.angleMode}
                    onToggleAngleMode={() =>
                      handleUpdateSettings({ angleMode: settings.angleMode === 'deg' ? 'rad' : 'deg' })
                    }
                    decimalPrecision={settings.decimalPrecision}
                    soundEnabled={settings.soundEnabled}
                    hapticEnabled={settings.hapticEnabled}
                    onAddHistory={handleAddHistory}
                    externalExpression={externalExpression}
                    externalSeq={externalSeq}
                    pinnedSlot={pinnedSlot}
                    headerRow={mergeHeader ? <Header embedded {...headerProps} /> : undefined}
                    history={history}
                    onOpenHistory={() => setIsHistoryOpen(true)}
                    onSelectHistoryItem={(expr) => loadExpression(expr)}
                  />
                )}

                {currentMode === 'converter' && (
                  <ConverterScreen
                    soundEnabled={settings.soundEnabled}
                    hapticEnabled={settings.hapticEnabled}
                    decimalPrecision={settings.decimalPrecision}
                  />
                )}

                {currentMode === 'finance' && (
                  <FinanceScreen
                    soundEnabled={settings.soundEnabled}
                    hapticEnabled={settings.hapticEnabled}
                    currencySymbol={settings.currencySymbol || '₹'}
                  />
                )}

                {currentMode === 'physics' && (
                  <PhysicsScreen
                    soundEnabled={settings.soundEnabled}
                    hapticEnabled={settings.hapticEnabled}
                    onInsertToCalculator={handleSelectResult}
                  />
                )}

                {settings.enableGrapher && currentMode === 'grapher' && (
                  <GraphScreen soundEnabled={settings.soundEnabled} hapticEnabled={settings.hapticEnabled} />
                )}
              </div>
            </main>
          </div>
        </div>

        {/* Progressive blur toward the edges ("Fade + blur") */}
        {settings.edgeEffect === 'blur' && (
          <>
            {buildBlurLayers(topEdge, 20, 'top').map((layer, i) => (
              <div
                key={`blur-top-${i}`}
                className="edge-blur"
                style={{
                  top: 0,
                  height: layer.height,
                  opacity: 'var(--ft, 0)' as unknown as number,
                  backdropFilter: `blur(${layer.blurPx}px)`,
                  WebkitBackdropFilter: `blur(${layer.blurPx}px)`,
                  maskImage: layer.mask,
                  WebkitMaskImage: layer.mask,
                }}
              />
            ))}
            {!isLargeScreen &&
              buildBlurLayers(bottomH, 8, 'bottom').map((layer, i) => (
                <div
                  key={`blur-bottom-${i}`}
                  className="edge-blur"
                  style={{
                    bottom: 0,
                    height: layer.height,
                    opacity: 'var(--fb, 0)' as unknown as number,
                    backdropFilter: `blur(${layer.blurPx}px)`,
                    WebkitBackdropFilter: `blur(${layer.blurPx}px)`,
                    maskImage: layer.mask,
                    WebkitMaskImage: layer.mask,
                  }}
                />
              ))}
          </>
        )}

        {/* Top bars: header pill, plus the answer display pinned beneath it on the calculator */}
        <div ref={topStackRef} className="absolute top-0 inset-x-0 z-40 pointer-events-none">
          {!mergeHeader && <Header {...headerProps} />}
          <div
            ref={setPinnedSlot}
            className="px-3 pb-2 empty:hidden"
            style={{ paddingTop: mergeHeader ? 'max(env(safe-area-inset-top, 0px), 8px)' : undefined }}
          />
        </div>

        {/* 3. Mobile / Compact Floating Bottom Navigation Dock */}
        {!isLargeScreen && (
          <div ref={bottomStackRef} className="absolute bottom-0 inset-x-0 z-40 pointer-events-none">
            <BottomNavBar
              currentMode={currentMode}
              onSelectMode={(mode) => {
                setIsHistoryOpen(false);
                setCurrentMode(mode);
                setExternalExpression('');
              }}
              soundEnabled={settings.soundEnabled}
              hapticEnabled={settings.hapticEnabled}
              onToggleHistory={() => setIsHistoryOpen((prev) => !prev)}
              isHistoryOpen={isHistoryOpen}
              historyCount={history.length}
              enableGrapher={settings.enableGrapher}
            />
          </div>
        )}
      </div>

      {/* History Tape Modal */}
      <HistoryTapeModal
        isOpen={isHistoryOpen}
        onClose={() => setIsHistoryOpen(false)}
        history={history}
        onSelectResult={handleSelectResult}
        onSelectExpression={(expr) => {
          loadExpression(expr);
          setCurrentMode('standard');
        }}
        onClearHistory={handleClearHistory}
      />

      {/* Settings & Preferences Modal */}
      <SettingsModal
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
        settings={settings}
        onUpdateSettings={handleUpdateSettings}
        onOpenGuide={() => setIsGuideOpen(true)}
        innerBackRef={innerBackRef}
      />

      {/* "Press back again to exit" hint */}
      {exitHint && (
        <div
          className="fixed left-0 right-0 z-[70] flex justify-center pointer-events-none animate-fadeIn"
          style={{ bottom: 'calc(var(--bottom-stack-h) + 16px)' }}
        >
          <div
            className="px-4 py-2.5 rounded-full text-xs font-semibold shadow-lg"
            style={{ backgroundColor: 'var(--m3-inverse-surface, var(--m3-on-surface))', color: 'var(--m3-surface)' }}
          >
            Press back again to exit
          </div>
        </div>
      )}

      {/* User guide */}
      <GuideSheet
        isOpen={isGuideOpen}
        onClose={() => setIsGuideOpen(false)}
        angleMode={settings.angleMode}
        onTryExample={handleTryExample}
      />
    </div>
  );
}
