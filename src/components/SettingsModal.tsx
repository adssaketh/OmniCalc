import React from 'react';
import { AppSettings, ThemeId, AngleMode, ColorMode, VibrationIntensity } from '../types';
import { soundFx } from '../utils/audio';
import {
  X,
  Volume2,
  Smartphone,
  Compass,
  Hash,
  Palette,
  Check,
  LineChart,
  ShieldCheck,
  ExternalLink,
  ChevronDown,
  ChevronUp,
  Lock,
  Sun,
  Moon,
  Laptop,
  Minus,
  Plus,
} from 'lucide-react';
import { PWAInstallButton } from './PWAInstallButton';
import { OmniCalcLogo } from './OmniCalcLogo';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  settings: AppSettings;
  onUpdateSettings: (newSettings: Partial<AppSettings>) => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  settings,
  onUpdateSettings,
}) => {
  const [showPrivacyPolicy, setShowPrivacyPolicy] = React.useState(false);

  React.useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const themes: { id: ThemeId; name: string; desc: string; primary: string; secondary: string }[] = [
    {
      id: 'm3-iris',
      name: 'Expressive Iris',
      desc: 'Android Flagship Monet',
      primary: '#a8c7fa',
      secondary: '#264585',
    },
    {
      id: 'm3-ocean',
      name: 'Dynamic Oceanic',
      desc: 'Teal & Deep Blue',
      primary: '#7bd0ff',
      secondary: '#004d67',
    },
    {
      id: 'm3-forest',
      name: 'Botanical Sage',
      desc: 'Forest & Mint Green',
      primary: '#9cd67d',
      secondary: '#23520e',
    },
    {
      id: 'm3-sunset',
      name: 'Sunset Terracotta',
      desc: 'Warm Coral & Amber',
      primary: '#ffb59d',
      secondary: '#72351f',
    },
    {
      id: 'm3-amoled',
      name: 'AMOLED / Pure Contrast',
      desc: 'Crisp Monochrome & Violet',
      primary: '#c2c1ff',
      secondary: '#222228',
    },
  ];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 backdrop-blur-md animate-in fade-in duration-200"
      style={{ backgroundColor: 'var(--m3-scrim)' }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg rounded-[32px] sm:rounded-[36px] border shadow-2xl overflow-hidden flex flex-col max-h-[90vh] transition-all"
        style={{
          backgroundColor: 'var(--m3-surface-container-low)',
          borderColor: 'var(--m3-outline-variant)',
          color: 'var(--m3-on-surface)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* M3 Expressive Drag Pill Handle */}
        <div className="pt-3 pb-1 flex justify-center">
          <div className="w-10 h-1 rounded-full opacity-40" style={{ backgroundColor: 'var(--m3-outline)' }} />
        </div>

        {/* Header */}
        <div
          className="px-6 py-3.5 flex items-center justify-between border-b"
          style={{ borderColor: 'var(--m3-outline-variant)' }}
        >
          <div className="flex flex-col">
            <h3 className="font-bold text-lg leading-tight" style={{ color: 'var(--m3-on-surface)' }}>
              Settings & Themes
            </h3>
            <span className="text-xs opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Material 3 Expressive System
            </span>
          </div>
          <button
            onClick={onClose}
            className="w-9 h-9 rounded-full flex items-center justify-center transition-all active:scale-90 border cursor-pointer"
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              borderColor: 'var(--m3-outline-variant)',
              color: 'var(--m3-on-surface-variant)',
            }}
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Settings Body */}
        <div className="p-5 sm:p-6 space-y-4 text-sm overflow-y-auto">
          {/* 1. M3 Color Theme Mode (System Auto / Light / Dark) */}
          <div
            className="p-3.5 rounded-[22px] border flex flex-col gap-2.5 transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div
                  className="w-9 h-9 rounded-full flex items-center justify-center shrink-0"
                  style={{
                    backgroundColor: 'var(--m3-primary-container)',
                    color: 'var(--m3-on-primary-container)',
                  }}
                >
                  {settings.colorMode === 'light' ? (
                    <Sun className="w-4 h-4" />
                  ) : settings.colorMode === 'dark' ? (
                    <Moon className="w-4 h-4" />
                  ) : (
                    <Laptop className="w-4 h-4" />
                  )}
                </div>
                <div>
                  <div className="font-semibold text-sm">Theme Mode</div>
                  <div className="text-xs opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    {settings.colorMode === 'system'
                      ? 'Follows device theme automatically'
                      : settings.colorMode === 'light'
                      ? 'Material 3 Expressive Light'
                      : 'Material 3 Expressive Dark'}
                  </div>
                </div>
              </div>
            </div>

            {/* Segmented control for System / Light / Dark */}
            <div
              className="grid grid-cols-3 gap-1 p-1 rounded-full border transition-colors"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              {[
                { id: 'system', label: 'System', icon: Laptop },
                { id: 'light', label: 'Light', icon: Sun },
                { id: 'dark', label: 'Dark', icon: Moon },
              ].map((mode) => {
                const isActive = settings.colorMode === mode.id;
                const ModeIcon = mode.icon;
                return (
                  <button
                    key={mode.id}
                    onClick={() => onUpdateSettings({ colorMode: mode.id as ColorMode })}
                    className="py-1.5 px-2 rounded-full text-xs font-semibold flex items-center justify-center gap-1.5 transition-all duration-150 active:scale-95 cursor-pointer"
                    style={{
                      backgroundColor: isActive ? 'var(--m3-primary)' : 'transparent',
                      color: isActive ? 'var(--m3-on-primary)' : 'var(--m3-on-surface-variant)',
                    }}
                  >
                    <ModeIcon className="w-3.5 h-3.5" />
                    <span>{mode.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* 2. M3 Audio Feedback Switch */}
          <div
            className="flex items-center justify-between p-3.5 rounded-[22px] border transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <div className="flex items-center gap-3.5">
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-primary)',
                }}
              >
                <Volume2 className="w-5 h-5" />
              </div>
              <div>
                <div className="font-semibold text-sm">Key Click Sounds</div>
                <div className="text-xs opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Tactile mechanical audio responses
                </div>
              </div>
            </div>
            {/* M3 Expressive Toggle Switch */}
            <button
              onClick={() => onUpdateSettings({ soundEnabled: !settings.soundEnabled })}
              className="w-14 h-8 rounded-full p-1 transition-all duration-200 flex items-center relative border cursor-pointer"
              style={{
                backgroundColor: settings.soundEnabled
                  ? 'var(--m3-primary)'
                  : 'var(--m3-surface-container-highest)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div
                className={`w-6 h-6 rounded-full shadow-md flex items-center justify-center transform transition-transform duration-200 ${
                  settings.soundEnabled ? 'translate-x-6' : 'translate-x-0'
                }`}
                style={{
                  backgroundColor: settings.soundEnabled
                    ? 'var(--m3-on-primary)'
                    : 'var(--m3-outline)',
                }}
              >
                {settings.soundEnabled && <Check className="w-3.5 h-3.5 text-[var(--m3-primary)]" />}
              </div>
            </button>
          </div>

          {/* 3. M3 Haptic Vibration Switch & Intensity Controller */}
          <div
            className="p-3.5 rounded-[22px] border flex flex-col gap-3 transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3.5">
                <div
                  className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-high)',
                    color: 'var(--m3-primary)',
                  }}
                >
                  <Smartphone className="w-5 h-5" />
                </div>
                <div>
                  <div className="font-semibold text-sm">Haptic Micro-Vibrations</div>
                  <div className="text-xs opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    Tactile physical pulses on keypad taps
                  </div>
                </div>
              </div>
              {/* M3 Expressive Toggle Switch */}
              <button
                onClick={() => {
                  const nextState = !settings.hapticEnabled;
                  onUpdateSettings({ hapticEnabled: nextState });
                  if (nextState) {
                    soundFx.triggerHaptic(settings.vibrationIntensity || 'medium');
                  }
                }}
                className="w-14 h-8 rounded-full p-1 transition-all duration-200 flex items-center relative border cursor-pointer"
                style={{
                  backgroundColor: settings.hapticEnabled
                    ? 'var(--m3-primary)'
                    : 'var(--m3-surface-container-highest)',
                  borderColor: 'var(--m3-outline-variant)',
                }}
              >
                <div
                  className={`w-6 h-6 rounded-full shadow-md flex items-center justify-center transform transition-transform duration-200 ${
                    settings.hapticEnabled ? 'translate-x-6' : 'translate-x-0'
                  }`}
                  style={{
                    backgroundColor: settings.hapticEnabled
                      ? 'var(--m3-on-primary)'
                      : 'var(--m3-outline)',
                  }}
                >
                  {settings.hapticEnabled && <Check className="w-3.5 h-3.5 text-[var(--m3-primary)]" />}
                </div>
              </button>
            </div>

            {/* Vibration Intensity Selector & Stepper Controller */}
            <div
              className={`pt-3 border-t flex flex-col gap-2.5 transition-opacity duration-200 ${
                settings.hapticEnabled ? 'opacity-100' : 'opacity-50'
              }`}
              style={{ borderColor: 'var(--m3-outline-variant)/40' }}
            >
              <div className="flex items-center justify-between">
                <div className="flex flex-col">
                  <span className="text-xs font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
                    Vibration Intensity
                  </span>
                  <span className="text-[11px] opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    Decrease or increase haptic pulse strength
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <span
                    className="text-xs font-mono font-bold capitalize px-2.5 py-0.5 rounded-full"
                    style={{
                      backgroundColor: 'var(--m3-primary-container)',
                      color: 'var(--m3-on-primary-container)',
                    }}
                  >
                    {settings.hapticEnabled ? (settings.vibrationIntensity || 'medium') : 'Off'}
                  </span>
                  <button
                    type="button"
                    onClick={() => {
                      if (!settings.hapticEnabled) {
                        onUpdateSettings({ hapticEnabled: true });
                      }
                      soundFx.triggerHaptic(settings.vibrationIntensity || 'medium');
                    }}
                    className="text-[11px] font-semibold px-2.5 py-0.5 rounded-full border border-[var(--m3-outline-variant)] hover:bg-[var(--m3-surface-container-high)] active:scale-95 transition-all cursor-pointer"
                    style={{ color: 'var(--m3-primary)' }}
                    title="Test current vibration intensity"
                  >
                    Test
                  </button>
                </div>
              </div>

              {/* Stepper Buttons + Range Slider */}
              <div className="flex items-center gap-2.5 px-0.5">
                <button
                  type="button"
                  onClick={() => {
                    const levels: VibrationIntensity[] = ['light', 'medium', 'strong', 'intense'];
                    const currentIdx = levels.indexOf(settings.vibrationIntensity || 'medium');
                    const nextIdx = Math.max(0, currentIdx - 1);
                    const nextLvl = levels[nextIdx];
                    onUpdateSettings({ hapticEnabled: true, vibrationIntensity: nextLvl });
                    soundFx.triggerHaptic(nextLvl);
                  }}
                  disabled={settings.vibrationIntensity === 'light' && settings.hapticEnabled}
                  className="w-8 h-8 rounded-full flex items-center justify-center border border-[var(--m3-outline-variant)] bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface)] disabled:opacity-30 active:scale-90 transition-all cursor-pointer shrink-0"
                  title="Decrease vibration intensity"
                >
                  <Minus className="w-3.5 h-3.5" />
                </button>

                <div className="flex-1 flex flex-col gap-1">
                  <input
                    type="range"
                    min="1"
                    max="4"
                    step="1"
                    value={
                      settings.vibrationIntensity === 'light'
                        ? 1
                        : settings.vibrationIntensity === 'medium'
                        ? 2
                        : settings.vibrationIntensity === 'strong'
                        ? 3
                        : 4
                    }
                    onChange={(e) => {
                      const val = parseInt(e.target.value, 10);
                      const mapping: Record<number, VibrationIntensity> = {
                        1: 'light',
                        2: 'medium',
                        3: 'strong',
                        4: 'intense',
                      };
                      const intensity = mapping[val] || 'medium';
                      onUpdateSettings({ hapticEnabled: true, vibrationIntensity: intensity });
                      soundFx.triggerHaptic(intensity);
                    }}
                    className="w-full accent-[var(--m3-primary)] cursor-pointer"
                  />
                  <div className="flex justify-between text-[10px] opacity-70 px-0.5 font-mono">
                    <span>Soft (10ms)</span>
                    <span>Max (75ms)</span>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={() => {
                    const levels: VibrationIntensity[] = ['light', 'medium', 'strong', 'intense'];
                    const currentIdx = levels.indexOf(settings.vibrationIntensity || 'medium');
                    const nextIdx = Math.min(levels.length - 1, currentIdx + 1);
                    const nextLvl = levels[nextIdx];
                    onUpdateSettings({ hapticEnabled: true, vibrationIntensity: nextLvl });
                    soundFx.triggerHaptic(nextLvl);
                  }}
                  disabled={settings.vibrationIntensity === 'intense' && settings.hapticEnabled}
                  className="w-8 h-8 rounded-full flex items-center justify-center border border-[var(--m3-outline-variant)] bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface)] disabled:opacity-30 active:scale-90 transition-all cursor-pointer shrink-0"
                  title="Increase vibration intensity"
                >
                  <Plus className="w-3.5 h-3.5" />
                </button>
              </div>

              {/* Segmented Preset Buttons */}
              <div className="grid grid-cols-4 gap-1.5 pt-1">
                {(['light', 'medium', 'strong', 'intense'] as const).map((lvl) => {
                  const isSelected = settings.hapticEnabled && (settings.vibrationIntensity || 'medium') === lvl;
                  return (
                    <button
                      key={lvl}
                      onClick={() => {
                        onUpdateSettings({ hapticEnabled: true, vibrationIntensity: lvl });
                        soundFx.triggerHaptic(lvl);
                      }}
                      className={`py-1.5 px-1 rounded-[14px] text-xs font-semibold capitalize transition-all border cursor-pointer active:scale-95 ${
                        isSelected
                          ? 'bg-[var(--m3-primary)] text-[var(--m3-on-primary)] border-[var(--m3-primary)] shadow-sm'
                          : 'bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface-variant)] border-[var(--m3-outline-variant)]/40 hover:bg-[var(--m3-surface-container-highest)]'
                      }`}
                    >
                      {lvl}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* 4. Angle Mode Segmented Buttons */}
          <div
            className="flex items-center justify-between p-3.5 rounded-[22px] border transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <div className="flex items-center gap-3.5">
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-primary)',
                }}
              >
                <Compass className="w-5 h-5" />
              </div>
              <div>
                <div className="font-semibold text-sm">Angle Mode</div>
                <div className="text-xs opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Trigonometric units
                </div>
              </div>
            </div>
            {/* Connected Segmented Pill */}
            <div
              className="flex items-center p-1 rounded-full border"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              {(['deg', 'rad'] as AngleMode[]).map((mode) => (
                <button
                  key={mode}
                  onClick={() => onUpdateSettings({ angleMode: mode })}
                  className="px-3.5 py-1 text-xs font-semibold rounded-full transition-all duration-150 cursor-pointer"
                  style={{
                    backgroundColor:
                      settings.angleMode === mode ? 'var(--m3-primary)' : 'transparent',
                    color:
                      settings.angleMode === mode
                        ? 'var(--m3-on-primary)'
                        : 'var(--m3-on-surface-variant)',
                  }}
                >
                  {mode.toUpperCase()}
                </button>
              ))}
            </div>
          </div>

          {/* 5. Decimal Precision */}
          <div
            className="flex items-center justify-between p-3.5 rounded-[22px] border transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <div className="flex items-center gap-3.5">
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-primary)',
                }}
              >
                <Hash className="w-5 h-5" />
              </div>
              <div>
                <div className="font-semibold text-sm">Decimal Precision</div>
                <div className="text-xs opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Number of rounded fractional places
                </div>
              </div>
            </div>
            <select
              value={settings.decimalPrecision}
              onChange={(e) => onUpdateSettings({ decimalPrecision: parseInt(e.target.value) })}
              className="text-xs rounded-full px-3 py-1.5 focus:outline-none font-mono cursor-pointer border transition-colors"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                borderColor: 'var(--m3-outline-variant)',
                color: 'var(--m3-on-surface)',
              }}
            >
              <option value="-1">Auto (Full)</option>
              <option value="2">2 places</option>
              <option value="4">4 places</option>
              <option value="6">6 places</option>
              <option value="8">8 places</option>
            </select>
          </div>

          {/* 6. Enable 2D Grapher Screen */}
          <div
            className="flex items-center justify-between p-3.5 rounded-[22px] border transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <div className="flex items-center gap-3.5">
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-primary)',
                }}
              >
                <LineChart className="w-5 h-5" />
              </div>
              <div>
                <div className="font-semibold text-sm">Interactive 2D Grapher</div>
                <div className="text-xs opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Function plotting and zoom workspace
                </div>
              </div>
            </div>
            <button
              onClick={() => onUpdateSettings({ enableGrapher: !settings.enableGrapher })}
              className="w-14 h-8 rounded-full p-1 transition-all duration-200 flex items-center relative border cursor-pointer"
              style={{
                backgroundColor: settings.enableGrapher
                  ? 'var(--m3-primary)'
                  : 'var(--m3-surface-container-highest)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div
                className={`w-6 h-6 rounded-full shadow-md flex items-center justify-center transform transition-transform duration-200 ${
                  settings.enableGrapher ? 'translate-x-6' : 'translate-x-0'
                }`}
                style={{
                  backgroundColor: settings.enableGrapher
                    ? 'var(--m3-on-primary)'
                    : 'var(--m3-outline)',
                }}
              >
                {settings.enableGrapher && <Check className="w-3.5 h-3.5 text-[var(--m3-primary)]" />}
              </div>
            </button>
          </div>

          {/* 7. Material 3 Expressive Dynamic Theme Palettes */}
          <div className="pt-2">
            <div className="flex items-center gap-2 mb-3">
              <Palette className="w-4 h-4" style={{ color: 'var(--m3-primary)' }} />
              <div className="font-bold text-sm">Material 3 Expressive Color Themes</div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {themes.map((t) => {
                const isSelected = settings.theme === t.id;
                return (
                  <button
                    key={t.id}
                    onClick={() => onUpdateSettings({ theme: t.id })}
                    className="p-3 rounded-[20px] text-left border transition-all duration-150 flex items-center gap-3 relative group active:scale-98 cursor-pointer"
                    style={{
                      backgroundColor: isSelected
                        ? 'var(--m3-surface-container-high)'
                        : 'var(--m3-surface-container)',
                      borderColor: isSelected ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
                    }}
                  >
                    {/* Dynamic Theme Logo Preview */}
                    <OmniCalcLogo theme={t.id} className="w-6 h-6 shrink-0 drop-shadow-xs" />

                    <div className="flex flex-col min-w-0 flex-1">
                      <span className="text-xs font-semibold leading-tight truncate">{t.name}</span>
                      <span className="text-[10px] opacity-60 leading-tight truncate">{t.desc}</span>
                    </div>

                    {isSelected && (
                      <span
                        className="w-5 h-5 rounded-full flex items-center justify-center shrink-0"
                        style={{
                          backgroundColor: 'var(--m3-primary)',
                          color: 'var(--m3-on-primary)',
                        }}
                      >
                        <Check className="w-3 h-3" />
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* 8. Privacy Policy & PWA Section */}
          <div className="pt-2 space-y-3">
            {/* Privacy Policy Card */}
            <div
              className="p-4 rounded-[24px] border flex flex-col gap-3 transition-colors"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-2.5 min-w-0">
                  <div
                    className="w-8 h-8 rounded-full flex items-center justify-center shrink-0"
                    style={{
                      backgroundColor: 'var(--m3-primary-container)',
                      color: 'var(--m3-on-primary-container)',
                    }}
                  >
                    <ShieldCheck className="w-4 h-4" />
                  </div>
                  <div className="min-w-0">
                    <div className="font-semibold text-xs flex items-center gap-1.5 flex-wrap">
                      <span>Privacy Policy</span>
                      <span
                        className="px-1.5 py-0.5 rounded-full text-[9px] font-bold"
                        style={{
                          backgroundColor: 'var(--m3-primary)',
                          color: 'var(--m3-on-primary)',
                        }}
                      >
                        100% On-Device
                      </span>
                    </div>
                    <div
                      className="text-[11px] opacity-70 truncate"
                      style={{ color: 'var(--m3-on-surface-variant)' }}
                    >
                      Zero data collection • Local storage only
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-1.5 shrink-0">
                  <button
                    onClick={() => setShowPrivacyPolicy(!showPrivacyPolicy)}
                    className="px-2.5 py-1 text-[11px] font-medium rounded-full transition-all active:scale-95 border flex items-center gap-1 cursor-pointer"
                    style={{
                      backgroundColor: 'var(--m3-surface-container-high)',
                      borderColor: 'var(--m3-outline-variant)',
                      color: 'var(--m3-primary)',
                    }}
                  >
                    <span>{showPrivacyPolicy ? 'Hide' : 'Read'}</span>
                    {showPrivacyPolicy ? (
                      <ChevronUp className="w-3 h-3" />
                    ) : (
                      <ChevronDown className="w-3 h-3" />
                    )}
                  </button>
                  <a
                    href="/privacy-policy.html"
                    target="_blank"
                    rel="noopener noreferrer"
                    title="Open standalone Privacy Policy page"
                    className="p-1 rounded-full opacity-70 hover:opacity-100 transition-opacity"
                    style={{ color: 'var(--m3-primary)' }}
                  >
                    <ExternalLink className="w-3.5 h-3.5" />
                  </a>
                </div>
              </div>

              {/* In-App Expandable Privacy Policy Content */}
              {showPrivacyPolicy && (
                <div
                  className="p-3.5 rounded-[18px] text-xs space-y-2.5 border animate-in fade-in duration-200"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-low)',
                    borderColor: 'var(--m3-outline-variant)',
                  }}
                >
                  <div
                    className="flex items-center justify-between pb-1.5 border-b"
                    style={{ borderColor: 'var(--m3-outline-variant)' }}
                  >
                    <span className="font-bold text-[11px] flex items-center gap-1.5" style={{ color: 'var(--m3-primary)' }}>
                      <Lock className="w-3 h-3" />
                      OmniCalc By Saketh Privacy Commitment
                    </span>
                    <span className="text-[10px] opacity-60">Effective Oct 2026</span>
                  </div>

                  <div className="space-y-2 text-[11px] leading-relaxed opacity-90">
                    <div className="flex items-start gap-2">
                      <span className="font-semibold text-emerald-500 shrink-0">•</span>
                      <div>
                        <strong>Zero Data Collection:</strong> We do not collect, transmit, sell, or profile any personally identifiable information (PII) or telemetry. No account or login is required.
                      </div>
                    </div>

                    <div className="flex items-start gap-2">
                      <span className="font-semibold text-emerald-500 shrink-0">•</span>
                      <div>
                        <strong>On-Device Storage:</strong> All calculation history, angle settings, grapher preferences, and financial SIP values are stored exclusively in your device's local storage. You can delete all history anytime with "Clear All".
                      </div>
                    </div>

                    <div className="flex items-start gap-2">
                      <span className="font-semibold text-emerald-500 shrink-0">•</span>
                      <div>
                        <strong>No Third-Party Trackers:</strong> No advertising SDKs, behavioral analytics, or third-party cookies are included in this app.
                      </div>
                    </div>

                    <div className="flex items-start gap-2">
                      <span className="font-semibold text-emerald-500 shrink-0">•</span>
                      <div>
                        <strong>Device Permissions:</strong> Sound feedback uses procedural client-side Web Audio oscillators. No microphone, camera, contacts, or location access is requested.
                      </div>
                    </div>

                    <div className="flex items-start gap-2">
                      <span className="font-semibold text-emerald-500 shrink-0">•</span>
                      <div>
                        <strong>Children & Families Safe:</strong> Fully compliant with COPPA and Google Play Developer Program policies for all ages.
                      </div>
                    </div>

                    <div
                      className="pt-2 border-t flex flex-wrap items-center justify-between gap-2 text-[10px]"
                      style={{ borderColor: 'var(--m3-outline-variant)' }}
                    >
                      <span className="opacity-70">
                        Contact: <strong className="font-medium">saketh.adhikarla@gmail.com</strong>
                      </span>
                      <a
                        href="/privacy-policy.html"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="font-semibold underline flex items-center gap-1"
                        style={{ color: 'var(--m3-primary)' }}
                      >
                        <span>Full Web Policy</span>
                        <ExternalLink className="w-2.5 h-2.5" />
                      </a>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Progressive Web App Direct Install */}
            <div
              className="p-4 rounded-[24px] border flex flex-col gap-2.5"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div>
                <div className="font-semibold text-xs">Progressive Web App</div>
                <div className="text-[11px] opacity-70" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Install OmniCalc By Saketh as a standalone home-screen app
                </div>
              </div>
              <PWAInstallButton variant="button" />
            </div>
          </div>
        </div>

        {/* Footer */}
        <div
          className="px-6 py-3.5 border-t flex justify-end"
          style={{ borderColor: 'var(--m3-outline-variant)' }}
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
    </div>
  );
};
