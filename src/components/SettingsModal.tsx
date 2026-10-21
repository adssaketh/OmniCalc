import React, { useState, useEffect } from 'react';
import { AppSettings, ThemeId, AngleMode, ColorMode, VibrationIntensity } from '../types';
import { soundFx } from '../utils/audio';
import {
  ArrowLeft,
  Palette,
  Sun,
  Moon,
  Laptop,
  Compass,
  Hash,
  Volume2,
  Smartphone,
  LineChart,
  ShieldCheck,
  Info,
  RotateCcw,
  ChevronRight,
  Check,
  ExternalLink,
  Sparkles,
} from 'lucide-react';
import { PWAInstallButton } from './PWAInstallButton';
import { OmniCalcLogo } from './OmniCalcLogo';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  settings: AppSettings;
  onUpdateSettings: (newSettings: Partial<AppSettings>) => void;
  onClearHistory?: () => void;
}

type ActiveSheet =
  | 'none'
  | 'theme'
  | 'colorMode'
  | 'angleMode'
  | 'precision'
  | 'vibration'
  | 'privacy'
  | 'resetConfirm';

interface ThemeOption {
  id: ThemeId;
  name: string;
  desc: string;
  primary: string;
  container: string;
  isDynamic?: boolean;
}

const THEME_OPTIONS: ThemeOption[] = [
  {
    id: 'dynamic',
    name: 'Dynamic (system colours)',
    desc: 'Matches wallpaper & Android 12+ Monet palette',
    primary: 'linear-gradient(135deg, #a8c7fa 0%, #7bd0ff 50%, #b0c6ff 100%)',
    container: '#264585',
    isDynamic: true,
  },
  {
    id: 'm3-iris',
    name: 'Expressive Iris',
    desc: 'Android Flagship Monet Blue',
    primary: '#a8c7fa',
    container: '#264585',
  },
  {
    id: 'm3-ocean',
    name: 'Dynamic Oceanic',
    desc: 'Teal & Deep Marine Blue',
    primary: '#7bd0ff',
    container: '#004d67',
  },
  {
    id: 'm3-forest',
    name: 'Botanical Sage',
    desc: 'Forest & Mint Flora',
    primary: '#9cd67d',
    container: '#23520e',
  },
  {
    id: 'm3-sunset',
    name: 'Sunset Terracotta',
    desc: 'Warm Coral & Amber Flame',
    primary: '#ffb59d',
    container: '#72351f',
  },
  {
    id: 'm3-amoled',
    name: 'AMOLED / Pure Contrast',
    desc: 'High Contrast Monochrome & Deep Black',
    primary: '#c2c1ff',
    container: '#141220',
  },
  {
    id: 'dark-obsidian',
    name: 'Dark Obsidian',
    desc: 'Deep Slate & Iris Accent',
    primary: '#a8c7fa',
    container: '#1d2024',
  },
  {
    id: 'cyber-emerald',
    name: 'Cyber Emerald',
    desc: 'Luminous Emerald & Night Jade',
    primary: '#00ff9d',
    container: '#003822',
  },
];

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  settings,
  onUpdateSettings,
  onClearHistory,
}) => {
  const [activeSheet, setActiveSheet] = useState<ActiveSheet>('none');
  const [showResetToast, setShowResetToast] = useState(false);

  // Close with Escape key
  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (activeSheet !== 'none') {
          setActiveSheet('none');
        } else {
          onClose();
        }
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, activeSheet, onClose]);

  if (!isOpen) return null;

  const currentThemeObj = THEME_OPTIONS.find((t) => t.id === settings.theme) || THEME_OPTIONS[1];

  const getColorModeLabel = (mode: ColorMode) => {
    switch (mode) {
      case 'system':
        return 'System default (auto)';
      case 'light':
        return 'Light mode';
      case 'dark':
        return 'Dark mode';
    }
  };

  const getPrecisionLabel = (p: number) => {
    if (p === -1) return 'Auto (Full precision)';
    return `${p} decimal places`;
  };

  const handleResetSettings = () => {
    onUpdateSettings({
      soundEnabled: true,
      hapticEnabled: true,
      vibrationIntensity: 'medium',
      angleMode: 'deg',
      decimalPrecision: -1,
      theme: 'dynamic',
      colorMode: 'system',
      enableGrapher: false,
    });
    setActiveSheet('none');
    setShowResetToast(true);
    setTimeout(() => setShowResetToast(false), 3000);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col justify-end sm:justify-center items-center bg-black/60 backdrop-blur-md animate-in fade-in duration-200"
      onClick={() => {
        if (activeSheet !== 'none') {
          setActiveSheet('none');
        } else {
          onClose();
        }
      }}
      role="dialog"
      aria-modal="true"
      aria-label="Settings"
    >
      {/* Main Settings Canvas Container */}
      <div
        className="w-full sm:max-w-2xl h-full sm:h-[90vh] sm:max-h-[880px] sm:rounded-[36px] flex flex-col overflow-hidden shadow-2xl transition-all"
        style={{
          backgroundColor: 'var(--m3-surface)',
          color: 'var(--m3-on-surface)',
          paddingTop: 'env(safe-area-inset-top, 0px)',
          paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Material 3 Large Collapsing Top App Bar */}
        <div
          className="sticky top-0 z-30 px-4 sm:px-6 py-3 border-b flex items-center justify-between backdrop-blur-xl transition-colors"
          style={{
            backgroundColor: 'color-mix(in srgb, var(--m3-surface) 90%, transparent)',
            borderColor: 'var(--m3-outline-variant)/40',
          }}
        >
          <div className="flex items-center gap-3">
            <button
              onClick={onClose}
              className="w-11 h-11 rounded-full flex items-center justify-center transition-all duration-200 active:scale-90 hover:bg-[var(--m3-surface-container-high)] cursor-pointer"
              style={{ color: 'var(--m3-on-surface)' }}
              aria-label="Back to calculator"
            >
              <ArrowLeft className="w-5 h-5" />
            </button>
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight" style={{ color: 'var(--m3-on-surface)' }}>
              Settings
            </h1>
          </div>

          <div className="flex items-center gap-2">
            <span
              className="text-[11px] font-semibold px-2.5 py-1 rounded-full hidden sm:inline-block"
              style={{
                backgroundColor: 'var(--m3-secondary-container)',
                color: 'var(--m3-on-secondary-container)',
              }}
            >
              Material You
            </span>
          </div>
        </div>

        {/* Scrollable Settings Content Body */}
        <div className="flex-1 overflow-y-auto px-4 sm:px-6 py-4 space-y-6 text-sm">
          {/* Reset confirmation banner */}
          {showResetToast && (
            <div
              className="p-3.5 rounded-[20px] flex items-center gap-3 animate-in fade-in duration-200 shadow-md"
              style={{
                backgroundColor: 'var(--m3-primary-container)',
                color: 'var(--m3-on-primary-container)',
              }}
            >
              <Check className="w-4 h-4 shrink-0 text-[var(--m3-primary)]" />
              <span className="text-xs font-semibold">Settings restored to factory defaults</span>
            </div>
          )}

          {/* ========================================================================= */}
          {/* SECTION 1: APPEARANCE */}
          {/* ========================================================================= */}
          <div>
            <div
              className="text-xs font-bold tracking-wider uppercase px-4 pb-2"
              style={{ color: 'var(--m3-primary)' }}
            >
              Appearance
            </div>
            <div
              className="rounded-[28px] overflow-hidden p-1 flex flex-col space-y-[2px] transition-colors"
              style={{ backgroundColor: 'var(--m3-surface-container)' }}
            >
              {/* Row: Theme Picker */}
              <div
                onClick={() => setActiveSheet('theme')}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <Palette className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Theme</div>
                    <div className="text-xs opacity-75 truncate flex items-center gap-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      {settings.theme === 'dynamic' && <Sparkles className="w-3 h-3 text-[var(--m3-primary)] inline" />}
                      <span>{currentThemeObj.name}</span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2.5 shrink-0">
                  {/* Visual theme circle preview */}
                  <div
                    className="w-6 h-6 rounded-full border border-black/10 shadow-xs shrink-0"
                    style={{
                      background: currentThemeObj.primary,
                    }}
                  />
                  <ChevronRight className="w-5 h-5 opacity-60" style={{ color: 'var(--m3-on-surface-variant)' }} />
                </div>
              </div>

              {/* Row: Colour Mode (System / Light / Dark) */}
              <div
                onClick={() => setActiveSheet('colorMode')}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    {settings.colorMode === 'light' ? (
                      <Sun className="w-5 h-5" />
                    ) : settings.colorMode === 'dark' ? (
                      <Moon className="w-5 h-5" />
                    ) : (
                      <Laptop className="w-5 h-5" />
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Colour mode</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      {getColorModeLabel(settings.colorMode)}
                    </div>
                  </div>
                </div>

                <ChevronRight className="w-5 h-5 opacity-60 shrink-0" style={{ color: 'var(--m3-on-surface-variant)' }} />
              </div>

              {/* Row: Quick AMOLED Pure Black Toggle */}
              <div
                onClick={() => {
                  if (settings.theme === 'm3-amoled') {
                    onUpdateSettings({ theme: 'dynamic' });
                  } else {
                    onUpdateSettings({ theme: 'm3-amoled', colorMode: 'dark' });
                  }
                }}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <Moon className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Pure black (AMOLED)</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      Pitch black surfaces to save battery on OLED screens
                    </div>
                  </div>
                </div>

                {/* Material 3 Switch */}
                <div
                  className={`w-13 h-7 rounded-full p-1 transition-colors duration-200 flex items-center shrink-0 border ${
                    settings.theme === 'm3-amoled'
                      ? 'bg-[var(--m3-primary)] border-[var(--m3-primary)]'
                      : 'bg-[var(--m3-surface-container-highest)] border-[var(--m3-outline-variant)]'
                  }`}
                >
                  <div
                    className={`w-5 h-5 rounded-full shadow-sm flex items-center justify-center transform transition-transform duration-200 ${
                      settings.theme === 'm3-amoled'
                        ? 'translate-x-6 bg-[var(--m3-on-primary)]'
                        : 'translate-x-0 bg-[var(--m3-outline)]'
                    }`}
                  >
                    {settings.theme === 'm3-amoled' && <Check className="w-3 h-3 text-[var(--m3-primary)]" />}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* ========================================================================= */}
          {/* SECTION 2: CALCULATOR */}
          {/* ========================================================================= */}
          <div>
            <div
              className="text-xs font-bold tracking-wider uppercase px-4 pb-2"
              style={{ color: 'var(--m3-primary)' }}
            >
              Calculator
            </div>
            <div
              className="rounded-[28px] overflow-hidden p-1 flex flex-col space-y-[2px] transition-colors"
              style={{ backgroundColor: 'var(--m3-surface-container)' }}
            >
              {/* Row: Angle Mode */}
              <div
                onClick={() => setActiveSheet('angleMode')}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <Compass className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Angle unit</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      {settings.angleMode === 'deg' ? 'Degrees (DEG)' : 'Radians (RAD)'}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  <span
                    className="text-xs font-bold font-mono px-2.5 py-0.5 rounded-full"
                    style={{
                      backgroundColor: 'var(--m3-primary-container)',
                      color: 'var(--m3-on-primary-container)',
                    }}
                  >
                    {settings.angleMode.toUpperCase()}
                  </span>
                  <ChevronRight className="w-5 h-5 opacity-60" style={{ color: 'var(--m3-on-surface-variant)' }} />
                </div>
              </div>

              {/* Row: Decimal Precision */}
              <div
                onClick={() => setActiveSheet('precision')}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <Hash className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Decimal precision</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      {getPrecisionLabel(settings.decimalPrecision)}
                    </div>
                  </div>
                </div>

                <ChevronRight className="w-5 h-5 opacity-60 shrink-0" style={{ color: 'var(--m3-on-surface-variant)' }} />
              </div>
            </div>
          </div>

          {/* ========================================================================= */}
          {/* SECTION 3: FEEDBACK */}
          {/* ========================================================================= */}
          <div>
            <div
              className="text-xs font-bold tracking-wider uppercase px-4 pb-2"
              style={{ color: 'var(--m3-primary)' }}
            >
              Feedback
            </div>
            <div
              className="rounded-[28px] overflow-hidden p-1 flex flex-col space-y-[2px] transition-colors"
              style={{ backgroundColor: 'var(--m3-surface-container)' }}
            >
              {/* Row: Key Click Sounds */}
              <div
                onClick={() => onUpdateSettings({ soundEnabled: !settings.soundEnabled })}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <Volume2 className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Key click sounds</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      Tactile mechanical audio responses on button taps
                    </div>
                  </div>
                </div>

                {/* Material 3 Switch */}
                <div
                  className={`w-13 h-7 rounded-full p-1 transition-colors duration-200 flex items-center shrink-0 border ${
                    settings.soundEnabled
                      ? 'bg-[var(--m3-primary)] border-[var(--m3-primary)]'
                      : 'bg-[var(--m3-surface-container-highest)] border-[var(--m3-outline-variant)]'
                  }`}
                >
                  <div
                    className={`w-5 h-5 rounded-full shadow-sm flex items-center justify-center transform transition-transform duration-200 ${
                      settings.soundEnabled
                        ? 'translate-x-6 bg-[var(--m3-on-primary)]'
                        : 'translate-x-0 bg-[var(--m3-outline)]'
                    }`}
                  >
                    {settings.soundEnabled && <Check className="w-3 h-3 text-[var(--m3-primary)]" />}
                  </div>
                </div>
              </div>

              {/* Row: Haptic Micro-Vibrations Toggle */}
              <div
                onClick={() => {
                  const next = !settings.hapticEnabled;
                  onUpdateSettings({ hapticEnabled: next });
                  if (next) soundFx.triggerHaptic(settings.vibrationIntensity || 'medium');
                }}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <Smartphone className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Haptic vibration</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      Physical vibrations on keypad and gesture triggers
                    </div>
                  </div>
                </div>

                {/* Material 3 Switch */}
                <div
                  className={`w-13 h-7 rounded-full p-1 transition-colors duration-200 flex items-center shrink-0 border ${
                    settings.hapticEnabled
                      ? 'bg-[var(--m3-primary)] border-[var(--m3-primary)]'
                      : 'bg-[var(--m3-surface-container-highest)] border-[var(--m3-outline-variant)]'
                  }`}
                >
                  <div
                    className={`w-5 h-5 rounded-full shadow-sm flex items-center justify-center transform transition-transform duration-200 ${
                      settings.hapticEnabled
                        ? 'translate-x-6 bg-[var(--m3-on-primary)]'
                        : 'translate-x-0 bg-[var(--m3-outline)]'
                    }`}
                  >
                    {settings.hapticEnabled && <Check className="w-3 h-3 text-[var(--m3-primary)]" />}
                  </div>
                </div>
              </div>

              {/* Row: Vibration Intensity (active when haptics are enabled) */}
              <div
                onClick={() => {
                  if (!settings.hapticEnabled) {
                    onUpdateSettings({ hapticEnabled: true });
                  }
                  setActiveSheet('vibration');
                }}
                className={`min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer ${
                  !settings.hapticEnabled ? 'opacity-60' : 'opacity-100'
                }`}
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div className="w-10 h-10 flex items-center justify-center shrink-0" />
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Vibration strength</div>
                    <div className="text-xs opacity-75 truncate capitalize" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      {settings.hapticEnabled ? `${settings.vibrationIntensity || 'medium'} intensity` : 'Disabled'}
                    </div>
                  </div>
                </div>

                <ChevronRight className="w-5 h-5 opacity-60 shrink-0" style={{ color: 'var(--m3-on-surface-variant)' }} />
              </div>
            </div>
          </div>

          {/* ========================================================================= */}
          {/* SECTION 4: FEATURES */}
          {/* ========================================================================= */}
          <div>
            <div
              className="text-xs font-bold tracking-wider uppercase px-4 pb-2"
              style={{ color: 'var(--m3-primary)' }}
            >
              Features
            </div>
            <div
              className="rounded-[28px] overflow-hidden p-1 flex flex-col space-y-[2px] transition-colors"
              style={{ backgroundColor: 'var(--m3-surface-container)' }}
            >
              {/* Row: Interactive 2D Grapher */}
              <div
                onClick={() => onUpdateSettings({ enableGrapher: !settings.enableGrapher })}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <LineChart className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Interactive 2D grapher</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      Function plotting, zoom and multi-curve tracing workspace
                    </div>
                  </div>
                </div>

                {/* Material 3 Switch */}
                <div
                  className={`w-13 h-7 rounded-full p-1 transition-colors duration-200 flex items-center shrink-0 border ${
                    settings.enableGrapher
                      ? 'bg-[var(--m3-primary)] border-[var(--m3-primary)]'
                      : 'bg-[var(--m3-surface-container-highest)] border-[var(--m3-outline-variant)]'
                  }`}
                >
                  <div
                    className={`w-5 h-5 rounded-full shadow-sm flex items-center justify-center transform transition-transform duration-200 ${
                      settings.enableGrapher
                        ? 'translate-x-6 bg-[var(--m3-on-primary)]'
                        : 'translate-x-0 bg-[var(--m3-outline)]'
                    }`}
                  >
                    {settings.enableGrapher && <Check className="w-3 h-3 text-[var(--m3-primary)]" />}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* ========================================================================= */}
          {/* SECTION 5: ABOUT */}
          {/* ========================================================================= */}
          <div>
            <div
              className="text-xs font-bold tracking-wider uppercase px-4 pb-2"
              style={{ color: 'var(--m3-primary)' }}
            >
              About
            </div>
            <div
              className="rounded-[28px] overflow-hidden p-1 flex flex-col space-y-[2px] transition-colors"
              style={{ backgroundColor: 'var(--m3-surface-container)' }}
            >
              {/* Row: App Version & Logo */}
              <div className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px]">
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div className="w-10 h-10 flex items-center justify-center shrink-0">
                    <OmniCalcLogo theme={settings.theme} className="w-8 h-8" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">OmniCalc</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      Version 1.0 (Build 1) • By Saketh
                    </div>
                  </div>
                </div>
              </div>

              {/* Row: Privacy Policy */}
              <div
                onClick={() => setActiveSheet('privacy')}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <ShieldCheck className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Privacy policy</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      100% on-device • Zero telemetry • No permissions
                    </div>
                  </div>
                </div>

                <ChevronRight className="w-5 h-5 opacity-60 shrink-0" style={{ color: 'var(--m3-on-surface-variant)' }} />
              </div>

              {/* Row: Progressive Web App Direct Install */}
              <div className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px]">
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <Info className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Web & PWA install</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      Add to home screen for browser access
                    </div>
                  </div>
                </div>

                <PWAInstallButton variant="button" />
              </div>

              {/* Row: Reset Settings to Defaults */}
              <div
                onClick={() => setActiveSheet('resetConfirm')}
                className="min-h-[56px] px-4 py-3 flex items-center justify-between rounded-[24px] hover:bg-[var(--m3-surface-container-high)] active:bg-[var(--m3-surface-container-highest)] transition-colors cursor-pointer"
              >
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-secondary-container)',
                      color: 'var(--m3-on-secondary-container)',
                    }}
                  >
                    <RotateCcw className="w-5 h-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-medium text-sm leading-snug">Reset settings</div>
                    <div className="text-xs opacity-75 truncate" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      Restore original preferences & themes
                    </div>
                  </div>
                </div>

                <ChevronRight className="w-5 h-5 opacity-60 shrink-0" style={{ color: 'var(--m3-on-surface-variant)' }} />
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div
          className="px-6 py-3 border-t flex justify-end"
          style={{ borderColor: 'var(--m3-outline-variant)/40' }}
        >
          <button
            onClick={onClose}
            className="px-6 py-2.5 text-xs font-semibold rounded-full transition-all active:scale-95 shadow-sm cursor-pointer"
            style={{
              backgroundColor: 'var(--m3-primary)',
              color: 'var(--m3-on-primary)',
            }}
          >
            Done
          </button>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* MATERIAL 3 CHOICE BOTTOM SHEETS / DIALOGS */}
      {/* ========================================================================= */}

      {/* 1. Theme Choice Sheet */}
      {activeSheet === 'theme' && (
        <div
          className="fixed inset-0 z-60 flex flex-col justify-end sm:justify-center items-center bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
          onClick={() => setActiveSheet('none')}
        >
          <div
            className="w-full sm:max-w-md max-h-[85vh] rounded-t-[32px] sm:rounded-[32px] p-5 flex flex-col shadow-2xl animate-in slide-in-from-bottom duration-200"
            style={{
              backgroundColor: 'var(--m3-surface-container-high, #24272c)',
              color: 'var(--m3-on-surface, #e2e2e9)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-10 h-1 rounded-full bg-[var(--m3-outline)]/40 mx-auto mb-4" />
            <h2 className="text-lg font-bold px-1 mb-1" style={{ color: 'var(--m3-on-surface)' }}>
              Choose theme
            </h2>
            <p className="text-xs opacity-70 px-1 mb-4" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Select a Material You dynamic scheme or curated accent
            </p>

            <div className="overflow-y-auto max-h-[55vh] space-y-1.5 pr-1">
              {THEME_OPTIONS.map((t) => {
                const isSelected = settings.theme === t.id;
                return (
                  <button
                    key={t.id}
                    onClick={() => {
                      onUpdateSettings({ theme: t.id });
                      localStorage.setItem('omni_calc_settings_theme_user_set', 'true');
                      setActiveSheet('none');
                    }}
                    className={`w-full min-h-[56px] px-3.5 py-2.5 rounded-[20px] flex items-center justify-between text-left transition-all active:scale-98 cursor-pointer ${
                      isSelected
                        ? 'bg-[var(--m3-primary-container)] text-[var(--m3-on-primary-container)]'
                        : 'hover:bg-[var(--m3-surface-container-highest)] text-[var(--m3-on-surface)]'
                    }`}
                  >
                    <div className="flex items-center gap-3 min-w-0 flex-1">
                      {/* Round Color Swatch */}
                      <div
                        className="w-9 h-9 rounded-full shrink-0 flex items-center justify-center shadow-xs border border-white/20"
                        style={{
                          background: t.primary,
                        }}
                      >
                        {t.isDynamic && <Sparkles className="w-4 h-4 text-white drop-shadow-xs" />}
                      </div>

                      <div className="min-w-0 flex-1">
                        <div className="font-medium text-sm leading-snug truncate flex items-center gap-1.5">
                          <span>{t.name}</span>
                        </div>
                        <div className="text-[11px] opacity-75 truncate">{t.desc}</div>
                      </div>
                    </div>

                    {/* Radio Indicator */}
                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 ml-2 ${
                        isSelected
                          ? 'border-[var(--m3-primary)] bg-[var(--m3-primary)]'
                          : 'border-[var(--m3-outline)]'
                      }`}
                    >
                      {isSelected && <div className="w-2 h-2 rounded-full bg-[var(--m3-on-primary)]" />}
                    </div>
                  </button>
                );
              })}
            </div>

            <div className="mt-4 pt-3 border-t border-[var(--m3-outline-variant)]/40 flex justify-end">
              <button
                onClick={() => setActiveSheet('none')}
                className="px-5 py-2 text-xs font-semibold rounded-full hover:bg-[var(--m3-surface-container-highest)] active:scale-95 transition-all cursor-pointer"
                style={{ color: 'var(--m3-primary)' }}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 2. Colour Mode Choice Sheet */}
      {activeSheet === 'colorMode' && (
        <div
          className="fixed inset-0 z-60 flex flex-col justify-end sm:justify-center items-center bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
          onClick={() => setActiveSheet('none')}
        >
          <div
            className="w-full sm:max-w-md rounded-t-[32px] sm:rounded-[32px] p-5 flex flex-col shadow-2xl animate-in slide-in-from-bottom duration-200"
            style={{
              backgroundColor: 'var(--m3-surface-container-high, #24272c)',
              color: 'var(--m3-on-surface, #e2e2e9)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-10 h-1 rounded-full bg-[var(--m3-outline)]/40 mx-auto mb-4" />
            <h2 className="text-lg font-bold px-1 mb-1" style={{ color: 'var(--m3-on-surface)' }}>
              Colour mode
            </h2>
            <p className="text-xs opacity-70 px-1 mb-4" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Choose how the app responds to system lighting
            </p>

            <div className="space-y-1.5">
              {[
                {
                  id: 'system',
                  title: 'System default',
                  desc: 'Follows phone dark mode schedule automatically',
                  icon: Laptop,
                },
                {
                  id: 'light',
                  title: 'Light mode',
                  desc: 'Always use clean bright surfaces',
                  icon: Sun,
                },
                {
                  id: 'dark',
                  title: 'Dark mode',
                  desc: 'Always use subdued dark surfaces',
                  icon: Moon,
                },
              ].map((opt) => {
                const isSelected = settings.colorMode === opt.id;
                const OptIcon = opt.icon;
                return (
                  <button
                    key={opt.id}
                    onClick={() => {
                      onUpdateSettings({ colorMode: opt.id as ColorMode });
                      setActiveSheet('none');
                    }}
                    className={`w-full min-h-[56px] px-3.5 py-3 rounded-[20px] flex items-center justify-between text-left transition-all active:scale-98 cursor-pointer ${
                      isSelected
                        ? 'bg-[var(--m3-primary-container)] text-[var(--m3-on-primary-container)]'
                        : 'hover:bg-[var(--m3-surface-container-highest)] text-[var(--m3-on-surface)]'
                    }`}
                  >
                    <div className="flex items-center gap-3.5 min-w-0 flex-1">
                      <div
                        className="w-9 h-9 rounded-full flex items-center justify-center shrink-0"
                        style={{
                          backgroundColor: isSelected ? 'var(--m3-primary)' : 'var(--m3-secondary-container)',
                          color: isSelected ? 'var(--m3-on-primary)' : 'var(--m3-on-secondary-container)',
                        }}
                      >
                        <OptIcon className="w-4 h-4" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="font-medium text-sm leading-snug">{opt.title}</div>
                        <div className="text-[11px] opacity-75 truncate">{opt.desc}</div>
                      </div>
                    </div>

                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 ml-2 ${
                        isSelected
                          ? 'border-[var(--m3-primary)] bg-[var(--m3-primary)]'
                          : 'border-[var(--m3-outline)]'
                      }`}
                    >
                      {isSelected && <div className="w-2 h-2 rounded-full bg-[var(--m3-on-primary)]" />}
                    </div>
                  </button>
                );
              })}
            </div>

            <div className="mt-4 pt-3 border-t border-[var(--m3-outline-variant)]/40 flex justify-end">
              <button
                onClick={() => setActiveSheet('none')}
                className="px-5 py-2 text-xs font-semibold rounded-full hover:bg-[var(--m3-surface-container-highest)] active:scale-95 transition-all cursor-pointer"
                style={{ color: 'var(--m3-primary)' }}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 3. Angle Mode Choice Sheet */}
      {activeSheet === 'angleMode' && (
        <div
          className="fixed inset-0 z-60 flex flex-col justify-end sm:justify-center items-center bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
          onClick={() => setActiveSheet('none')}
        >
          <div
            className="w-full sm:max-w-md rounded-t-[32px] sm:rounded-[32px] p-5 flex flex-col shadow-2xl animate-in slide-in-from-bottom duration-200"
            style={{
              backgroundColor: 'var(--m3-surface-container-high, #24272c)',
              color: 'var(--m3-on-surface, #e2e2e9)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-10 h-1 rounded-full bg-[var(--m3-outline)]/40 mx-auto mb-4" />
            <h2 className="text-lg font-bold px-1 mb-1" style={{ color: 'var(--m3-on-surface)' }}>
              Angle unit
            </h2>
            <p className="text-xs opacity-70 px-1 mb-4" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Unit used for sin, cos, tan and inverse trigonometric operations
            </p>

            <div className="space-y-1.5">
              {[
                {
                  id: 'deg',
                  title: 'Degrees (DEG)',
                  desc: 'Full circle = 360°. Standard for engineering & navigation.',
                },
                {
                  id: 'rad',
                  title: 'Radians (RAD)',
                  desc: 'Full circle = 2π rad. Standard for calculus & physics.',
                },
              ].map((opt) => {
                const isSelected = settings.angleMode === opt.id;
                return (
                  <button
                    key={opt.id}
                    onClick={() => {
                      onUpdateSettings({ angleMode: opt.id as AngleMode });
                      setActiveSheet('none');
                    }}
                    className={`w-full min-h-[56px] px-4 py-3 rounded-[20px] flex items-center justify-between text-left transition-all active:scale-98 cursor-pointer ${
                      isSelected
                        ? 'bg-[var(--m3-primary-container)] text-[var(--m3-on-primary-container)]'
                        : 'hover:bg-[var(--m3-surface-container-highest)] text-[var(--m3-on-surface)]'
                    }`}
                  >
                    <div className="min-w-0 flex-1">
                      <div className="font-medium text-sm leading-snug">{opt.title}</div>
                      <div className="text-[11px] opacity-75 truncate">{opt.desc}</div>
                    </div>

                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 ml-2 ${
                        isSelected
                          ? 'border-[var(--m3-primary)] bg-[var(--m3-primary)]'
                          : 'border-[var(--m3-outline)]'
                      }`}
                    >
                      {isSelected && <div className="w-2 h-2 rounded-full bg-[var(--m3-on-primary)]" />}
                    </div>
                  </button>
                );
              })}
            </div>

            <div className="mt-4 pt-3 border-t border-[var(--m3-outline-variant)]/40 flex justify-end">
              <button
                onClick={() => setActiveSheet('none')}
                className="px-5 py-2 text-xs font-semibold rounded-full hover:bg-[var(--m3-surface-container-highest)] active:scale-95 transition-all cursor-pointer"
                style={{ color: 'var(--m3-primary)' }}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 4. Decimal Precision Choice Sheet */}
      {activeSheet === 'precision' && (
        <div
          className="fixed inset-0 z-60 flex flex-col justify-end sm:justify-center items-center bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
          onClick={() => setActiveSheet('none')}
        >
          <div
            className="w-full sm:max-w-md rounded-t-[32px] sm:rounded-[32px] p-5 flex flex-col shadow-2xl animate-in slide-in-from-bottom duration-200"
            style={{
              backgroundColor: 'var(--m3-surface-container-high, #24272c)',
              color: 'var(--m3-on-surface, #e2e2e9)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-10 h-1 rounded-full bg-[var(--m3-outline)]/40 mx-auto mb-4" />
            <h2 className="text-lg font-bold px-1 mb-1" style={{ color: 'var(--m3-on-surface)' }}>
              Decimal precision
            </h2>
            <p className="text-xs opacity-70 px-1 mb-4" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Number of rounded decimal digits displayed on calculation results
            </p>

            <div className="space-y-1.5">
              {[
                { val: -1, title: 'Auto (Full Precision)', desc: 'Adaptive scientific & fractional display' },
                { val: 2, title: '2 decimal places', desc: 'e.g. 3.14 (Ideal for currency & accounting)' },
                { val: 4, title: '4 decimal places', desc: 'e.g. 3.1416 (Standard scientific accuracy)' },
                { val: 6, title: '6 decimal places', desc: 'e.g. 3.141593 (High accuracy)' },
                { val: 8, title: '8 decimal places', desc: 'e.g. 3.14159265 (Physics & engineering)' },
              ].map((opt) => {
                const isSelected = settings.decimalPrecision === opt.val;
                return (
                  <button
                    key={opt.val}
                    onClick={() => {
                      onUpdateSettings({ decimalPrecision: opt.val });
                      setActiveSheet('none');
                    }}
                    className={`w-full min-h-[56px] px-4 py-3 rounded-[20px] flex items-center justify-between text-left transition-all active:scale-98 cursor-pointer ${
                      isSelected
                        ? 'bg-[var(--m3-primary-container)] text-[var(--m3-on-primary-container)]'
                        : 'hover:bg-[var(--m3-surface-container-highest)] text-[var(--m3-on-surface)]'
                    }`}
                  >
                    <div className="min-w-0 flex-1">
                      <div className="font-medium text-sm leading-snug">{opt.title}</div>
                      <div className="text-[11px] opacity-75 truncate">{opt.desc}</div>
                    </div>

                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 ml-2 ${
                        isSelected
                          ? 'border-[var(--m3-primary)] bg-[var(--m3-primary)]'
                          : 'border-[var(--m3-outline)]'
                      }`}
                    >
                      {isSelected && <div className="w-2 h-2 rounded-full bg-[var(--m3-on-primary)]" />}
                    </div>
                  </button>
                );
              })}
            </div>

            <div className="mt-4 pt-3 border-t border-[var(--m3-outline-variant)]/40 flex justify-end">
              <button
                onClick={() => setActiveSheet('none')}
                className="px-5 py-2 text-xs font-semibold rounded-full hover:bg-[var(--m3-surface-container-highest)] active:scale-95 transition-all cursor-pointer"
                style={{ color: 'var(--m3-primary)' }}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 5. Vibration Intensity Choice Sheet */}
      {activeSheet === 'vibration' && (
        <div
          className="fixed inset-0 z-60 flex flex-col justify-end sm:justify-center items-center bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
          onClick={() => setActiveSheet('none')}
        >
          <div
            className="w-full sm:max-w-md rounded-t-[32px] sm:rounded-[32px] p-5 flex flex-col shadow-2xl animate-in slide-in-from-bottom duration-200"
            style={{
              backgroundColor: 'var(--m3-surface-container-high, #24272c)',
              color: 'var(--m3-on-surface, #e2e2e9)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-10 h-1 rounded-full bg-[var(--m3-outline)]/40 mx-auto mb-4" />
            <h2 className="text-lg font-bold px-1 mb-1" style={{ color: 'var(--m3-on-surface)' }}>
              Vibration strength
            </h2>
            <p className="text-xs opacity-70 px-1 mb-4" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Tune tactile pulse strength for key presses
            </p>

            <div className="space-y-1.5">
              {[
                { val: 'light', title: 'Light', desc: 'Subtle micro-tick (10ms)' },
                { val: 'medium', title: 'Medium', desc: 'Standard balanced haptic tap (25ms)' },
                { val: 'strong', title: 'Strong', desc: 'Pronounced firm feedback (45ms)' },
                { val: 'intense', title: 'Intense', desc: 'High intensity mechanical pulse (75ms)' },
              ].map((opt) => {
                const isSelected = (settings.vibrationIntensity || 'medium') === opt.val;
                return (
                  <button
                    key={opt.val}
                    onClick={() => {
                      const lvl = opt.val as VibrationIntensity;
                      onUpdateSettings({ hapticEnabled: true, vibrationIntensity: lvl });
                      soundFx.triggerHaptic(lvl);
                    }}
                    className={`w-full min-h-[56px] px-4 py-3 rounded-[20px] flex items-center justify-between text-left transition-all active:scale-98 cursor-pointer ${
                      isSelected
                        ? 'bg-[var(--m3-primary-container)] text-[var(--m3-on-primary-container)]'
                        : 'hover:bg-[var(--m3-surface-container-highest)] text-[var(--m3-on-surface)]'
                    }`}
                  >
                    <div className="min-w-0 flex-1">
                      <div className="font-medium text-sm leading-snug">{opt.title}</div>
                      <div className="text-[11px] opacity-75 truncate">{opt.desc}</div>
                    </div>

                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          soundFx.triggerHaptic(opt.val as VibrationIntensity);
                        }}
                        className="text-[11px] font-semibold px-2.5 py-1 rounded-full border border-[var(--m3-outline-variant)] hover:bg-[var(--m3-surface-container-highest)] active:scale-90 transition-all cursor-pointer"
                        style={{ color: 'var(--m3-primary)' }}
                      >
                        Test
                      </button>
                      <div
                        className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 ml-1 ${
                          isSelected
                            ? 'border-[var(--m3-primary)] bg-[var(--m3-primary)]'
                            : 'border-[var(--m3-outline)]'
                        }`}
                      >
                        {isSelected && <div className="w-2 h-2 rounded-full bg-[var(--m3-on-primary)]" />}
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>

            <div className="mt-4 pt-3 border-t border-[var(--m3-outline-variant)]/40 flex justify-end">
              <button
                onClick={() => setActiveSheet('none')}
                className="px-5 py-2 text-xs font-semibold rounded-full hover:bg-[var(--m3-surface-container-highest)] active:scale-95 transition-all cursor-pointer"
                style={{ color: 'var(--m3-primary)' }}
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 6. Privacy Commitment Sheet */}
      {activeSheet === 'privacy' && (
        <div
          className="fixed inset-0 z-60 flex flex-col justify-end sm:justify-center items-center bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
          onClick={() => setActiveSheet('none')}
        >
          <div
            className="w-full sm:max-w-lg max-h-[85vh] rounded-t-[32px] sm:rounded-[32px] p-5 sm:p-6 flex flex-col shadow-2xl animate-in slide-in-from-bottom duration-200"
            style={{
              backgroundColor: 'var(--m3-surface-container-high, #24272c)',
              color: 'var(--m3-on-surface, #e2e2e9)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-10 h-1 rounded-full bg-[var(--m3-outline)]/40 mx-auto mb-4" />
            <div className="flex items-center gap-2 mb-1">
              <ShieldCheck className="w-5 h-5 text-[var(--m3-primary)]" />
              <h2 className="text-lg font-bold" style={{ color: 'var(--m3-on-surface)' }}>
                Privacy Commitment
              </h2>
            </div>
            <p className="text-xs opacity-70 mb-4" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Zero telemetry • Local processing • COPPA Compliant
            </p>

            <div className="overflow-y-auto max-h-[50vh] space-y-3 text-xs leading-relaxed opacity-90 pr-1">
              <div className="p-3 rounded-[16px] bg-[var(--m3-surface-container)] border border-[var(--m3-outline-variant)]/40">
                <strong>Zero Tracking & Telemetry:</strong> OmniCalc runs 100% on your device. We do not track, profile, collect, or transmit user activity or calculations.
              </div>
              <div className="p-3 rounded-[16px] bg-[var(--m3-surface-container)] border border-[var(--m3-outline-variant)]/40">
                <strong>Local Storage Only:</strong> All calculations and user preferences stay on your device and are never sent to remote databases.
              </div>
              <div className="p-3 rounded-[16px] bg-[var(--m3-surface-container)] border border-[var(--m3-outline-variant)]/40">
                <strong>No Dangerous Permissions:</strong> No microphone, camera, contacts, or storage permissions are required. Sound effects are generated mathematically in real time via Web Audio oscillators.
              </div>
              <div className="p-3 rounded-[16px] bg-[var(--m3-surface-container)] border border-[var(--m3-outline-variant)]/40">
                <strong>Developer Contact:</strong> Developed by Saketh (saketh.adhikarla@gmail.com).
              </div>
            </div>

            <div className="mt-4 pt-3 border-t border-[var(--m3-outline-variant)]/40 flex items-center justify-between">
              <a
                href="/privacy-policy.html"
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs font-semibold flex items-center gap-1.5 underline"
                style={{ color: 'var(--m3-primary)' }}
              >
                <span>Standalone Policy</span>
                <ExternalLink className="w-3.5 h-3.5" />
              </a>
              <button
                onClick={() => setActiveSheet('none')}
                className="px-5 py-2 text-xs font-semibold rounded-full hover:bg-[var(--m3-surface-container-highest)] active:scale-95 transition-all cursor-pointer"
                style={{ color: 'var(--m3-primary)' }}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 7. Reset Confirmation Dialog */}
      {activeSheet === 'resetConfirm' && (
        <div
          className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-150"
          onClick={() => setActiveSheet('none')}
        >
          <div
            className="w-full max-w-sm rounded-[28px] p-6 flex flex-col shadow-2xl animate-in zoom-in-95 duration-200"
            style={{
              backgroundColor: 'var(--m3-surface-container-high, #24272c)',
              color: 'var(--m3-on-surface, #e2e2e9)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="w-10 h-10 rounded-full flex items-center justify-center mb-3 bg-[var(--m3-error-container)] text-[var(--m3-on-error-container)]">
              <RotateCcw className="w-5 h-5" />
            </div>
            <h2 className="text-lg font-bold mb-2">Reset all settings?</h2>
            <p className="text-xs opacity-75 mb-6 leading-relaxed" style={{ color: 'var(--m3-on-surface-variant)' }}>
              This will restore all default preferences, enable Dynamic system colours, and reset audio/haptics. Your calculation history will not be erased.
            </p>

            <div className="flex items-center justify-end gap-2">
              <button
                onClick={() => setActiveSheet('none')}
                className="px-4 py-2 text-xs font-semibold rounded-full hover:bg-[var(--m3-surface-container-highest)] transition-all cursor-pointer"
                style={{ color: 'var(--m3-on-surface-variant)' }}
              >
                Cancel
              </button>
              <button
                onClick={handleResetSettings}
                className="px-5 py-2 text-xs font-semibold rounded-full shadow-sm active:scale-95 transition-all cursor-pointer"
                style={{
                  backgroundColor: 'var(--m3-error)',
                  color: 'var(--m3-on-error)',
                }}
              >
                Reset
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
