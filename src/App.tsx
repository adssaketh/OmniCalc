/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect } from 'react';
import { CalculatorMode, HistoryItem, AppSettings } from './types';
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
};

export default function App() {
  const [currentMode, setCurrentMode] = useState<CalculatorMode>('standard');
  const [isHistoryOpen, setIsHistoryOpen] = useState<boolean>(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState<boolean>(false);
  const [externalExpression, setExternalExpression] = useState<string>('');
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

  const handleSelectResult = (val: string) => {
    setExternalExpression(val);
    setCurrentMode('standard');
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
          if (!userChosen) {
            setSettings((prev) => ({ ...prev, theme: 'dynamic' }));
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

  // Theme styling wrapper
  const getM3ThemeDataAttr = (): string => {
    switch (settings.theme) {
      case 'm3-ocean':
        return 'oceanic';
      case 'm3-forest':
        return 'forest';
      case 'm3-sunset':
        return 'sunset';
      case 'm3-amoled':
      case 'oled-midnight':
        return 'amoled';
      case 'cyber-emerald':
        return 'forest';
      case 'dynamic':
      case 'm3-iris':
      case 'dark-obsidian':
      default:
        return 'iris';
    }
  };

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
    const darkSurfaces: Record<string, string> = {
      'dynamic': '#111318',
      'm3-iris': '#111318',
      'm3-ocean': '#0e1417',
      'm3-forest': '#101510',
      'm3-sunset': '#171210',
      'm3-amoled': '#000000',
      'oled-midnight': '#000000',
      'cyber-emerald': '#101510',
      'dark-obsidian': '#111318',
    };

    const lightSurfaces: Record<string, string> = {
      'dynamic': '#f8f9fa',
      'm3-iris': '#f8f9fa',
      'm3-ocean': '#f5fbfa',
      'm3-forest': '#f7fbf2',
      'm3-sunset': '#fff8f6',
      'm3-amoled': '#ffffff',
      'oled-midnight': '#ffffff',
      'cyber-emerald': '#f7fbf2',
      'dark-obsidian': '#f8f9fa',
    };

    let surfaceColor =
      (isDarkMode ? darkSurfaces[settings.theme] : lightSurfaces[settings.theme]) ||
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

    const dataAttr = getM3ThemeDataAttr();
    const modeAttr = isDarkMode ? 'dark' : 'light';

    // 2. Set root HTML dataset and background colors
    document.documentElement.setAttribute('data-m3-theme', dataAttr);
    document.documentElement.setAttribute('data-m3-mode', modeAttr);
    document.documentElement.style.backgroundColor = surfaceColor;
    document.documentElement.style.colorScheme = isDarkMode ? 'dark' : 'light';
    document.body.style.backgroundColor = surfaceColor;

    // 3. Update Android/Browser system status bar meta tags per scheme
    const lightMeta = document.getElementById('theme-color-light');
    if (lightMeta) {
      lightMeta.setAttribute('content', settings.theme === 'dynamic' ? surfaceColor : (lightSurfaces[settings.theme] || '#f8f9fa'));
    }
    const darkMeta = document.getElementById('theme-color-dark');
    if (darkMeta) {
      darkMeta.setAttribute('content', settings.theme === 'dynamic' ? surfaceColor : (darkSurfaces[settings.theme] || '#111318'));
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
  }, [settings.theme, settings.colorMode, isDarkMode, systemColors]);

  // Android Native Back Button: dismiss modals first, then exit application
  useEffect(() => {
    if (!Capacitor.isNativePlatform()) return;

    let listenerPromise = CapApp.addListener('backButton', () => {
      if (isSettingsOpen) {
        setIsSettingsOpen(false);
      } else if (isHistoryOpen) {
        setIsHistoryOpen(false);
      } else {
        CapApp.exitApp();
      }
    });

    return () => {
      listenerPromise.then((handle) => handle.remove()).catch(() => {});
    };
  }, [isSettingsOpen, isHistoryOpen]);

  const { isLandscape, isTablet, width } = useOrientation();
  const isLargeScreen = width >= 960 || (isTablet && isLandscape) || (isTablet && width >= 720);

  // Global Keyboard Shortcuts for accessories and PC navigation
  useEffect(() => {
    const handleGlobalKeyDown = (e: KeyboardEvent) => {
      // If modal is open and user presses Escape, close modal
      if (e.key === 'Escape') {
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
  }, [isSettingsOpen, isHistoryOpen, settings.enableGrapher]);

  return (
    <div
      data-m3-theme={getM3ThemeDataAttr()}
      className={`min-h-screen font-sans transition-colors duration-300 ${
        isLargeScreen ? 'flex flex-row' : 'flex flex-col'
      }`}
      style={{
        backgroundColor: 'var(--m3-surface)',
        color: 'var(--m3-on-surface)',
      }}
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
          onOpenHistory={() => setIsHistoryOpen((prev) => !prev)}
          isHistoryOpen={isHistoryOpen}
          historyCount={history.length}
          enableGrapher={settings.enableGrapher}
          theme={settings.theme}
        />
      )}

      {/* 2. Main Content Workspace */}
      <div className="flex-1 flex flex-col min-w-0">
        <Header
          soundEnabled={settings.soundEnabled}
          onToggleSound={() => handleUpdateSettings({ soundEnabled: !settings.soundEnabled })}
          onOpenSettings={() => setIsSettingsOpen(true)}
          theme={settings.theme}
        />

        {/* Main Workspace Area with adaptive responsive padding and viewport utilization */}
        <main
          className={`flex-1 w-full max-w-[1650px] mx-auto px-2 sm:px-6 lg:px-8 py-1.5 sm:py-3 flex flex-col min-h-0 ${
            isLargeScreen ? 'pb-4 lg:pb-6' : 'pb-[76px] sm:pb-24'
          }`}
        >
          {/* Animated Screen Container */}
          <div key={currentMode} className="w-full flex-1 flex flex-col h-full min-h-0 animate-m3-screen-enter">
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
                history={history}
                onOpenHistory={() => setIsHistoryOpen(true)}
                onSelectHistoryItem={(expr) => setExternalExpression(expr)}
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
              <GraphScreen
                soundEnabled={settings.soundEnabled}
                hapticEnabled={settings.hapticEnabled}
              />
            )}
          </div>
        </main>

        {/* 3. Mobile / Compact Floating Bottom Navigation Dock */}
        {!isLargeScreen && (
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
        )}
      </div>

      {/* History Tape Modal */}
      <HistoryTapeModal
        isOpen={isHistoryOpen}
        onClose={() => setIsHistoryOpen(false)}
        history={history}
        onSelectResult={handleSelectResult}
        onSelectExpression={(expr) => {
          setExternalExpression(expr);
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
        onClearHistory={handleClearHistory}
      />
    </div>
  );
}
