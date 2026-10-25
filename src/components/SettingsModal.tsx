import React, { useState } from 'react';
import { AppSettings, ThemeId, AngleMode, ColorMode, VibrationIntensity, EdgeEffect, FadeHeight, BarStyle, GlassBlur } from '../types';
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
  RotateCcw,
  ChevronRight,
  Check,
  ExternalLink,
  Sparkles,
} from 'lucide-react';
import { OmniCalcLogo } from './OmniCalcLogo';
import { NavIcon } from './NavIcons';
import { Sheet } from './Sheet';
import { APP_VERSION, REPO_URL, REPO_LABEL } from '../version';
import { AnimatePresence, motion } from 'motion/react';
import { spring } from '../motion';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  settings: AppSettings;
  onUpdateSettings: (newSettings: Partial<AppSettings>) => void;
  onOpenGuide: () => void;
  /** App's back gesture asks this first: closes an open sub-sheet and returns true, or returns false */
  innerBackRef?: React.MutableRefObject<(() => boolean) | null>;
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

const COLOR_MODE_OPTIONS: { id: ColorMode; title: string; desc: string; icon: React.ElementType }[] = [
  { id: 'system', title: 'System default', desc: 'Follows phone dark mode schedule automatically', icon: Laptop },
  { id: 'light', title: 'Light mode', desc: 'Always use clean bright surfaces', icon: Sun },
  { id: 'dark', title: 'Dark mode', desc: 'Always use subdued dark surfaces', icon: Moon },
];

const ANGLE_OPTIONS: { id: AngleMode; title: string; desc: string }[] = [
  { id: 'deg', title: 'Degrees (DEG)', desc: 'Full circle = 360°. Standard for engineering & navigation.' },
  { id: 'rad', title: 'Radians (RAD)', desc: 'Full circle = 2π rad. Standard for calculus & physics.' },
];

const PRECISION_OPTIONS: { id: number; title: string; desc: string }[] = [
  { id: -1, title: 'Auto (Full Precision)', desc: 'Adaptive scientific & fractional display' },
  { id: 2, title: '2 decimal places', desc: 'e.g. 3.14 (Ideal for currency & accounting)' },
  { id: 4, title: '4 decimal places', desc: 'e.g. 3.1416 (Standard scientific accuracy)' },
  { id: 6, title: '6 decimal places', desc: 'e.g. 3.141593 (High accuracy)' },
  { id: 8, title: '8 decimal places', desc: 'e.g. 3.14159265 (Physics & engineering)' },
];

const VIBRATION_OPTIONS: { id: VibrationIntensity; title: string; desc: string }[] = [
  { id: 'light', title: 'Light', desc: 'Subtle micro-tick (10ms)' },
  { id: 'medium', title: 'Medium', desc: 'Standard balanced haptic tap (25ms)' },
  { id: 'strong', title: 'Strong', desc: 'Pronounced firm feedback (45ms)' },
  { id: 'intense', title: 'Intense', desc: 'High intensity mechanical pulse (75ms)' },
];

const getColorModeLabel = (mode: ColorMode) =>
  mode === 'system' ? 'System default (auto)' : mode === 'light' ? 'Light mode' : 'Dark mode';

const getPrecisionLabel = (p: number) => (p === -1 ? 'Auto (Full precision)' : `${p} decimal places`);

/* ------------------------------------------------------------------------- */
/* Building blocks                                                            */
/* ------------------------------------------------------------------------- */

const Section: React.FC<{ title: string; children: React.ReactNode }> = ({ title, children }) => (
  <div>
    <div className="text-xs font-bold tracking-wider uppercase px-4 pb-2" style={{ color: 'var(--m3-primary)' }}>
      {title}
    </div>
    <div className="rounded-[28px] p-1.5 flex flex-col gap-0.5" style={{ backgroundColor: 'var(--m3-surface-container)' }}>
      {children}
    </div>
  </div>
);

interface RowProps {
  /** Leading icon; omit for an empty spacer so the text lines up with the rows above */
  icon?: React.ElementType;
  title: string;
  subtitle?: React.ReactNode;
  onClick?: () => void;
  /** Opens this web address in the browser */
  href?: string;
  trailing?: React.ReactNode;
  /** Chevron on the right (a row that opens a sheet) */
  chevron?: boolean;
  dimmed?: boolean;
  /** Replaces the icon tile (used for the app logo) */
  leading?: React.ReactNode;
}

const Row: React.FC<RowProps> = ({ icon: Icon, title, subtitle, onClick, href, trailing, chevron, dimmed, leading }) => {
  // With an href the whole row is a real link: Android hands it to the browser and the app stays open
  const Tag = (href ? 'a' : 'div') as React.ElementType;
  const linkProps = href ? { href, target: '_blank', rel: 'noopener noreferrer' } : {};
  return (
  <Tag
    {...linkProps}
    onClick={onClick}
    className={`min-h-[64px] px-4 py-3 flex items-center gap-4 rounded-[24px] transition-colors ${
      onClick || href ? 'cursor-pointer hover:bg-[var(--m3-surface-container-high)] active:scale-[0.985]' : ''
    } ${dimmed ? 'opacity-60' : ''}`}
  >
    {leading ?? (
      <div
        className="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0"
        style={Icon ? { backgroundColor: 'var(--m3-surface-container-high)', color: 'var(--m3-primary)' } : undefined}
      >
        {Icon && <Icon className="w-5 h-5" />}
      </div>
    )}
    <div className="min-w-0 flex-1">
      <div className="font-medium text-sm leading-snug">{title}</div>
      {subtitle && (
        <div className="text-xs line-clamp-2 flex items-center gap-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
          {subtitle}
        </div>
      )}
    </div>
    {trailing}
    {chevron && <ChevronRight className="w-5 h-5 shrink-0" style={{ color: 'var(--m3-on-surface-variant)' }} />}
  </Tag>
  );
};

/** Material 3 switch */
const Switch: React.FC<{ on: boolean }> = ({ on }) => (
  <div
    className={`w-13 h-7 rounded-full p-1 transition-colors duration-200 flex items-center shrink-0 ${
      on ? 'bg-[var(--m3-primary)]' : 'bg-[var(--m3-surface-container-highest)]'
    }`}
  >
    <div
      className={`w-5 h-5 rounded-full flex items-center justify-center transition-transform duration-200 ${
        on ? 'translate-x-6 bg-[var(--m3-on-primary)]' : 'translate-x-0 bg-[var(--m3-outline)]'
      }`}
    >
      {on && <Check className="w-3 h-3 text-[var(--m3-primary)]" />}
    </div>
  </div>
);

interface SegmentedProps<T extends string> {
  options: { id: T; label: string }[];
  value: T;
  onChange: (id: T) => void;
  disabled?: boolean;
  label: string;
}

/** Row of pill choices (Off / Fade / Fade + blur ...), same look as Ping's Message Organization options. */
function Segmented<T extends string>({ options, value, onChange, disabled = false, label }: SegmentedProps<T>) {
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className={`flex flex-wrap gap-2 transition-opacity duration-200 ${disabled ? 'opacity-45 pointer-events-none' : ''}`}
    >
      {options.map((o) => {
        const selected = o.id === value;
        return (
          <button
            key={o.id}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(o.id)}
            className="px-4 h-10 rounded-full text-[13px] cursor-pointer active:scale-95 transition-all duration-200"
            style={
              selected
                ? { backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)', fontWeight: 700 }
                : { backgroundColor: 'var(--m3-surface-container-high)', color: 'var(--m3-on-surface-variant)', fontWeight: 500 }
            }
          >
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

const OptionBlock: React.FC<{ title: string; desc: string; dimmed?: boolean; children: React.ReactNode }> = ({ title, desc, dimmed, children }) => (
  <div className={`space-y-2 transition-opacity duration-200 ${dimmed ? 'opacity-45' : ''}`}>
    <div>
      <div className="font-medium text-sm leading-snug">{title}</div>
      <div className="text-xs leading-snug" style={{ color: 'var(--m3-on-surface-variant)' }}>
        {desc}
      </div>
    </div>
    {children}
  </div>
);

const EDGE_OPTIONS: { id: EdgeEffect; label: string }[] = [
  { id: 'off', label: 'Off' },
  { id: 'fade', label: 'Fade' },
  { id: 'blur', label: 'Fade + blur' },
];
const FADE_OPTIONS: { id: FadeHeight; label: string }[] = [
  { id: 'short', label: 'Short' },
  { id: 'medium', label: 'Medium' },
  { id: 'tall', label: 'Tall' },
];
const BAR_OPTIONS: { id: BarStyle; label: string }[] = [
  { id: 'solid', label: 'Solid' },
  { id: 'glass', label: 'Glass' },
];
const GLASS_BLUR_OPTIONS: { id: GlassBlur; label: string }[] = [
  { id: 'soft', label: 'Soft' },
  { id: 'medium', label: 'Medium' },
  { id: 'strong', label: 'Strong' },
];

/** Small live preview: colourful content behind a top and a bottom bar, using the real bar styles. */
const BarPreview: React.FC = () => (
  <div className="relative h-32 rounded-[24px] overflow-hidden" aria-hidden="true">
    <div
      className="absolute inset-0"
      style={{
        background:
          'linear-gradient(115deg, var(--m3-primary) 0%, var(--m3-tertiary) 38%, var(--m3-secondary) 62%, var(--m3-primary-container) 100%)',
      }}
    />
    <div className="absolute -left-4 top-8 w-24 h-24 rounded-full" style={{ backgroundColor: 'var(--m3-tertiary-container)' }} />
    <div className="absolute right-6 top-3 w-20 h-20 rounded-[28px] rotate-12" style={{ backgroundColor: 'var(--m3-primary-container)' }} />
    <div className="absolute left-1/3 bottom-1 w-28 h-14 rounded-full" style={{ backgroundColor: 'var(--m3-secondary-container)' }} />
    <div className="bar-surface absolute left-3 right-3 top-3 h-10 rounded-full flex items-center px-4 text-xs font-semibold">
      Top bar
    </div>
    <div className="bar-surface absolute left-3 right-3 bottom-3 h-10 rounded-full flex items-center px-4 text-xs font-semibold">
      Bottom bar
    </div>
  </div>
);

interface ChoiceOption<T> {
  id: T;
  title: string;
  desc: string;
  leading?: React.ReactNode;
  /** Extra control shown before the radio (e.g. the vibration "Test" button) */
  extra?: React.ReactNode;
}

interface ChoiceSheetProps<T> {
  isOpen: boolean;
  title: string;
  description: string;
  options: ChoiceOption<T>[];
  selected: T;
  onSelect: (id: T) => void;
  onClose: () => void;
  closeLabel?: string;
}

/** Single-choice bottom sheet with radio rows: used for theme, colour mode, angle unit, precision and vibration. */
function ChoiceSheet<T extends string | number>({
  isOpen,
  title,
  description,
  options,
  selected,
  onSelect,
  onClose,
  closeLabel = 'Cancel',
}: ChoiceSheetProps<T>) {
  return (
    <Sheet isOpen={isOpen} onClose={onClose} label={title} widthClass="sm:max-w-md" zClass="z-[60]">
      <div className="px-6 pt-4 pb-1">
        <h2 className="text-lg font-bold">{title}</h2>
        <p className="text-xs mt-0.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
          {description}
        </p>
      </div>
      <div className="overflow-y-auto min-h-0 px-3 py-3 space-y-1">
        {options.map((opt) => {
          const isSelected = selected === opt.id;
          return (
            <button
              key={String(opt.id)}
              onClick={() => onSelect(opt.id)}
              className="w-full min-h-[60px] px-4 py-2.5 rounded-[24px] flex items-center gap-3.5 text-left cursor-pointer active:scale-[0.985] transition-colors"
              style={
                isSelected
                  ? { backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }
                  : { color: 'var(--m3-on-surface)' }
              }
            >
              {opt.leading}
              <div className="min-w-0 flex-1">
                <div className="font-medium text-sm leading-snug">{opt.title}</div>
                <div className="text-[11px] opacity-75 truncate">{opt.desc}</div>
              </div>
              {opt.extra}
              <div
                className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 ${
                  isSelected ? 'border-[var(--m3-primary)] bg-[var(--m3-primary)]' : 'border-[var(--m3-outline)]'
                }`}
              >
                {isSelected && <div className="w-2 h-2 rounded-full bg-[var(--m3-on-primary)]" />}
              </div>
            </button>
          );
        })}
      </div>
      <div className="px-6 py-3 flex justify-end shrink-0">
        <button
          onClick={onClose}
          className="px-5 py-2.5 text-xs font-semibold rounded-full active:scale-95 transition-transform cursor-pointer"
          style={{ color: 'var(--m3-primary)' }}
        >
          {closeLabel}
        </button>
      </div>
    </Sheet>
  );
}

/* ------------------------------------------------------------------------- */

export const SettingsModal: React.FC<SettingsModalProps> = ({ isOpen, onClose, settings, onUpdateSettings, onOpenGuide, innerBackRef }) => {
  const [activeSheet, setActiveSheet] = useState<ActiveSheet>('none');
  const [showResetToast, setShowResetToast] = useState(false);

  const closeSheet = () => setActiveSheet('none');
  if (innerBackRef) {
    innerBackRef.current = () => {
      if (activeSheet === 'none') return false;
      setActiveSheet('none');
      return true;
    };
  }
  const currentThemeObj = THEME_OPTIONS.find((t) => t.id === settings.theme) || THEME_OPTIONS[1];
  const vibration = settings.vibrationIntensity || 'medium';

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
      edgeEffect: 'fade',
      fadeHeight: 'medium',
      barStyle: 'solid',
      glassTransparency: 70,
      glassBlur: 'medium',
      glassEdge: true,
    });
    closeSheet();
    setShowResetToast(true);
    setTimeout(() => setShowResetToast(false), 3000);
  };

  return (
    <>
      <Sheet isOpen={isOpen} onClose={onClose} label="Settings" widthClass="sm:max-w-2xl" className="h-[92vh] sm:h-[88vh] sm:max-h-[880px]">
        {/* Top bar */}
        <div className="px-4 sm:px-5 py-3 flex items-center gap-2 shrink-0">
          <button
            onClick={onClose}
            className="w-11 h-11 rounded-full flex items-center justify-center cursor-pointer active:scale-90 transition-transform"
            aria-label="Back to calculator"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <h1 className="text-xl font-bold tracking-tight">Settings</h1>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto min-h-0 px-4 sm:px-5 pb-4 space-y-5 text-sm">
          {showResetToast && (
            <div
              className="p-3.5 rounded-[24px] flex items-center gap-3"
              style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}
            >
              <Check className="w-4 h-4 shrink-0" style={{ color: 'var(--m3-primary)' }} />
              <span className="text-xs font-semibold">Settings restored to factory defaults</span>
            </div>
          )}

          <Section title="Appearance">
            <Row
              icon={Palette}
              title="Theme"
              chevron
              onClick={() => setActiveSheet('theme')}
              subtitle={
                <>
                  {settings.theme === 'dynamic' && <Sparkles className="w-3 h-3 inline" style={{ color: 'var(--m3-primary)' }} />}
                  <span>{currentThemeObj.name}</span>
                </>
              }
              trailing={<div className="w-6 h-6 rounded-full shrink-0" style={{ background: currentThemeObj.primary }} />}
            />
            <Row
              icon={settings.colorMode === 'light' ? Sun : settings.colorMode === 'dark' ? Moon : Laptop}
              title="Colour mode"
              subtitle={getColorModeLabel(settings.colorMode)}
              chevron
              onClick={() => setActiveSheet('colorMode')}
            />
            <Row
              icon={Moon}
              title="Pure black (AMOLED)"
              subtitle="Pitch black surfaces to save battery on OLED screens"
              trailing={<Switch on={settings.theme === 'm3-amoled'} />}
              onClick={() => {
                // Record that the user picked a theme so the dynamic-colour
                // auto-default never overrides it on the next launch/resume.
                try {
                  localStorage.setItem('omni_calc_settings_theme_user_set', 'true');
                } catch {
                  // ignore
                }
                if (settings.theme === 'm3-amoled') {
                  onUpdateSettings({ theme: 'dynamic' });
                } else {
                  onUpdateSettings({ theme: 'm3-amoled', colorMode: 'dark' });
                }
              }}
            />
          </Section>

          <Section title="Bars & scrolling">
            <div className="px-3.5 py-3.5 space-y-5">
              <BarPreview />

              <OptionBlock
                title="Scroll edge effect"
                desc="What happens to content as it slides under the top bar and the bottom bar. Fade is clean and light; Fade + blur adds a soft blur while it fades."
              >
                <Segmented label="Scroll edge effect" options={EDGE_OPTIONS} value={settings.edgeEffect} onChange={(edgeEffect) => onUpdateSettings({ edgeEffect })} />
              </OptionBlock>

              <OptionBlock title="Fade height" desc="How far from the bars content starts to fade away." dimmed={settings.edgeEffect === 'off'}>
                <Segmented
                  label="Fade height"
                  options={FADE_OPTIONS}
                  value={settings.fadeHeight}
                  disabled={settings.edgeEffect === 'off'}
                  onChange={(fadeHeight) => onUpdateSettings({ fadeHeight })}
                />
              </OptionBlock>

              <OptionBlock title="Bar style" desc="Solid colour, or frosted glass that lets content show through (uses a little more battery).">
                <Segmented label="Bar style" options={BAR_OPTIONS} value={settings.barStyle} onChange={(barStyle) => onUpdateSettings({ barStyle })} />
              </OptionBlock>

              <AnimatePresence initial={false}>
                {settings.barStyle === 'glass' && (
                  <motion.div
                    key="glass-options"
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ height: spring, opacity: { duration: 0.2 } }}
                    style={{ overflow: 'hidden' }}
                  >
                    <div className="rounded-[24px] p-4 space-y-5" style={{ backgroundColor: 'var(--m3-surface-container-high)' }}>
                      <div>
                        <div className="flex items-baseline justify-between">
                          <label htmlFor="glass-transparency" className="font-medium text-sm">
                            Glass transparency
                          </label>
                          <span className="text-sm font-bold" style={{ color: 'var(--m3-primary)' }}>
                            {settings.glassTransparency}%
                          </span>
                        </div>
                        <input
                          id="glass-transparency"
                          type="range"
                          min={0}
                          max={100}
                          step={1}
                          value={settings.glassTransparency}
                          onChange={(e) => onUpdateSettings({ glassTransparency: Number(e.target.value) })}
                          className="m3-slider mt-2"
                          style={{ ['--pct' as string]: `${settings.glassTransparency}%` } as React.CSSProperties}
                        />
                        <div className="flex justify-between text-[11px]" style={{ color: 'var(--m3-on-surface-variant)' }}>
                          <span>Frosted</span>
                          <span>Clear</span>
                        </div>
                      </div>

                      <OptionBlock title="Glass blur" desc="How strongly the glass blurs what is behind it.">
                        <Segmented label="Glass blur" options={GLASS_BLUR_OPTIONS} value={settings.glassBlur} onChange={(glassBlur) => onUpdateSettings({ glassBlur })} />
                      </OptionBlock>

                      <div
                        role="switch"
                        aria-checked={settings.glassEdge}
                        tabIndex={0}
                        onClick={() => onUpdateSettings({ glassEdge: !settings.glassEdge })}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault();
                            onUpdateSettings({ glassEdge: !settings.glassEdge });
                          }
                        }}
                        className="flex items-center gap-4 cursor-pointer active:scale-[0.99] transition-transform"
                      >
                        <div className="min-w-0 flex-1">
                          <div className="font-medium text-sm leading-snug">Glass edge</div>
                          <div className="text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>
                            A thin light rim around the bars.
                          </div>
                        </div>
                        <Switch on={settings.glassEdge} />
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </Section>

          <Section title="Calculator">
            <Row
              icon={Compass}
              title="Angle unit"
              subtitle={settings.angleMode === 'deg' ? 'Degrees (DEG)' : 'Radians (RAD)'}
              chevron
              onClick={() => setActiveSheet('angleMode')}
              trailing={
                <span
                  className="text-xs font-bold font-mono px-2.5 py-0.5 rounded-full"
                  style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}
                >
                  {settings.angleMode.toUpperCase()}
                </span>
              }
            />
            <Row
              icon={Hash}
              title="Decimal precision"
              subtitle={getPrecisionLabel(settings.decimalPrecision)}
              chevron
              onClick={() => setActiveSheet('precision')}
            />
          </Section>

          <Section title="Feedback">
            <Row
              icon={Volume2}
              title="Key click sounds"
              subtitle="Tactile mechanical audio responses on button taps"
              trailing={<Switch on={settings.soundEnabled} />}
              onClick={() => onUpdateSettings({ soundEnabled: !settings.soundEnabled })}
            />
            <Row
              icon={Smartphone}
              title="Haptic vibration"
              subtitle="Physical vibrations on keypad and gesture triggers"
              trailing={<Switch on={settings.hapticEnabled} />}
              onClick={() => {
                const next = !settings.hapticEnabled;
                onUpdateSettings({ hapticEnabled: next });
                if (next) soundFx.triggerHaptic(settings.vibrationIntensity || 'medium');
              }}
            />
            <Row
              title="Vibration strength"
              subtitle={<span className="capitalize">{settings.hapticEnabled ? `${vibration} intensity` : 'Disabled'}</span>}
              chevron
              dimmed={!settings.hapticEnabled}
              onClick={() => {
                if (!settings.hapticEnabled) onUpdateSettings({ hapticEnabled: true });
                setActiveSheet('vibration');
              }}
            />
          </Section>

          <Section title="Features">
            <Row
              icon={LineChart}
              title="Interactive 2D grapher"
              subtitle="Function plotting, zoom and multi-curve tracing workspace"
              trailing={<Switch on={settings.enableGrapher} />}
              onClick={() => onUpdateSettings({ enableGrapher: !settings.enableGrapher })}
            />
          </Section>

          <Section title="About">
            <Row
              leading={
                <div className="w-12 h-12 flex items-center justify-center shrink-0">
                  <OmniCalcLogo theme={settings.theme} className="w-9 h-9" />
                </div>
              }
              title="OmniCalc"
              subtitle={`Version ${APP_VERSION} • By Saketh`}
            />
            <Row
              leading={
                <div
                  className="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0"
                  style={{ backgroundColor: 'var(--m3-surface-container-high)', color: 'var(--m3-primary)' }}
                >
                  <NavIcon id="guide" size={22} />
                </div>
              }
              title="User guide"
              subtitle="How to use differentiation, integration, limits and more"
              chevron
              onClick={() => {
                onClose();
                onOpenGuide();
              }}
            />
            <Row
              leading={
                <div
                  className="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0"
                  style={{ backgroundColor: 'var(--m3-surface-container-high)', color: 'var(--m3-primary)' }}
                >
                  <svg viewBox="0 0 24 24" className="w-6 h-6" fill="currentColor" aria-hidden="true">
                    <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
                  </svg>
                </div>
              }
              title="Source code on GitHub"
              subtitle={`${REPO_LABEL} • Open source (GPL-3.0)`}
              href={REPO_URL}
              trailing={<ExternalLink className="w-4 h-4 shrink-0" style={{ color: 'var(--m3-on-surface-variant)' }} />}
            />
            <Row
              icon={ShieldCheck}
              title="Privacy policy"
              subtitle="100% on-device • Zero telemetry • No permissions"
              chevron
              onClick={() => setActiveSheet('privacy')}
            />
            <Row
              icon={RotateCcw}
              title="Reset settings"
              subtitle="Restore original preferences & themes"
              chevron
              onClick={() => setActiveSheet('resetConfirm')}
            />
          </Section>
        </div>

        {/* Footer */}
        <div className="px-6 py-3 flex justify-end shrink-0">
          <button
            onClick={onClose}
            className="px-7 py-3 text-xs font-semibold rounded-full active:scale-95 transition-transform cursor-pointer"
            style={{ backgroundColor: 'var(--m3-primary)', color: 'var(--m3-on-primary)' }}
          >
            Done
          </button>
        </div>
      </Sheet>

      <ChoiceSheet<ThemeId>
        isOpen={isOpen && activeSheet === 'theme'}
        title="Choose theme"
        description="Select a Material You dynamic scheme or curated accent"
        selected={settings.theme}
        options={THEME_OPTIONS.map((t) => ({
          id: t.id,
          title: t.name,
          desc: t.desc,
          leading: (
            <div className="w-10 h-10 rounded-full shrink-0 flex items-center justify-center" style={{ background: t.primary }}>
              {t.isDynamic && <Sparkles className="w-4 h-4 text-white" />}
            </div>
          ),
        }))}
        onSelect={(id) => {
          onUpdateSettings({ theme: id });
          localStorage.setItem('omni_calc_settings_theme_user_set', 'true');
          closeSheet();
        }}
        onClose={closeSheet}
      />

      <ChoiceSheet<ColorMode>
        isOpen={isOpen && activeSheet === 'colorMode'}
        title="Colour mode"
        description="Choose how the app responds to system lighting"
        selected={settings.colorMode}
        options={COLOR_MODE_OPTIONS.map((o) => {
          const OptIcon = o.icon;
          return {
            id: o.id,
            title: o.title,
            desc: o.desc,
            leading: (
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
                style={{
                  backgroundColor: settings.colorMode === o.id ? 'var(--m3-primary)' : 'var(--m3-surface-container-high)',
                  color: settings.colorMode === o.id ? 'var(--m3-on-primary)' : 'var(--m3-primary)',
                }}
              >
                <OptIcon className="w-4 h-4" />
              </div>
            ),
          };
        })}
        onSelect={(id) => {
          onUpdateSettings({ colorMode: id });
          closeSheet();
        }}
        onClose={closeSheet}
      />

      <ChoiceSheet<AngleMode>
        isOpen={isOpen && activeSheet === 'angleMode'}
        title="Angle unit"
        description="Unit used for sin, cos, tan and inverse trigonometric operations"
        selected={settings.angleMode}
        options={ANGLE_OPTIONS}
        onSelect={(id) => {
          onUpdateSettings({ angleMode: id });
          closeSheet();
        }}
        onClose={closeSheet}
      />

      <ChoiceSheet<number>
        isOpen={isOpen && activeSheet === 'precision'}
        title="Decimal precision"
        description="Number of rounded decimal digits displayed on calculation results"
        selected={settings.decimalPrecision}
        options={PRECISION_OPTIONS}
        onSelect={(id) => {
          onUpdateSettings({ decimalPrecision: id });
          closeSheet();
        }}
        onClose={closeSheet}
      />

      <ChoiceSheet<VibrationIntensity>
        isOpen={isOpen && activeSheet === 'vibration'}
        title="Vibration strength"
        description="Tune tactile pulse strength for key presses"
        selected={vibration}
        closeLabel="Done"
        options={VIBRATION_OPTIONS.map((o) => ({
          ...o,
          extra: (
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                soundFx.triggerHaptic(o.id);
              }}
              className="text-[11px] font-semibold px-3 py-1.5 rounded-full active:scale-90 transition-transform cursor-pointer"
              style={{ color: 'var(--m3-primary)' }}
            >
              Test
            </button>
          ),
        }))}
        onSelect={(id) => {
          onUpdateSettings({ hapticEnabled: true, vibrationIntensity: id });
          soundFx.triggerHaptic(id);
        }}
        onClose={closeSheet}
      />

      <Sheet isOpen={isOpen && activeSheet === 'privacy'} onClose={closeSheet} label="Privacy commitment" widthClass="sm:max-w-lg" zClass="z-[60]">
        <div className="px-6 pt-4 pb-1 flex items-center gap-4">
          <div
            className="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0"
            style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}
          >
            <ShieldCheck className="w-6 h-6" />
          </div>
          <div>
            <h2 className="text-lg font-bold leading-tight">Privacy Commitment</h2>
            <p className="text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Zero telemetry • Local processing • COPPA Compliant
            </p>
          </div>
        </div>
        <div className="overflow-y-auto min-h-0 px-5 py-4 space-y-2 text-xs leading-relaxed">
          {[
            ['Zero Tracking & Telemetry:', 'OmniCalc has no ads, analytics or tracking. We do not track, profile, collect, or transmit your activity or calculations.'],
            ['Local Storage Only:', 'Your calculations, history and preferences stay on your device. The only internet use is the currency converter downloading public exchange rates, which sends none of your data.'],
            ['No Dangerous Permissions:', 'No microphone, camera, contacts, or storage permissions are required. Sound effects are generated mathematically in real time via Web Audio oscillators'],
            ['Open source:', `The full source code is public at ${REPO_LABEL}, so these claims can be checked.`],
            ['Developer Contact:', 'Developed by Saketh (adsaketh@gmail.com).'],
          ].map(([lead, text]) => (
            <div key={lead} className="p-4 rounded-[20px]" style={{ backgroundColor: 'var(--m3-surface-container)' }}>
              <strong>{lead}</strong> {text}
            </div>
          ))}
        </div>
        <div className="px-6 py-3 flex items-center justify-between shrink-0">
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
            onClick={closeSheet}
            className="px-5 py-2.5 text-xs font-semibold rounded-full active:scale-95 transition-transform cursor-pointer"
            style={{ color: 'var(--m3-primary)' }}
          >
            Close
          </button>
        </div>
      </Sheet>

      <Sheet isOpen={isOpen && activeSheet === 'resetConfirm'} onClose={closeSheet} label="Reset all settings" widthClass="sm:max-w-sm" zClass="z-[60]">
        <div className="p-6 flex flex-col">
          <div
            className="w-12 h-12 rounded-2xl flex items-center justify-center mb-3"
            style={{ backgroundColor: 'var(--m3-error-container)', color: 'var(--m3-on-error-container)' }}
          >
            <RotateCcw className="w-5 h-5" />
          </div>
          <h2 className="text-lg font-bold mb-2">Reset all settings?</h2>
          <p className="text-xs mb-6 leading-relaxed" style={{ color: 'var(--m3-on-surface-variant)' }}>
            This will restore all default preferences, enable Dynamic system colours, and reset audio/haptics. Your calculation history will not be erased.
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={closeSheet}
              className="flex-1 py-3 text-xs font-semibold rounded-full active:scale-95 transition-transform cursor-pointer"
              style={{ backgroundColor: 'var(--m3-surface-container-high)', color: 'var(--m3-on-surface-variant)' }}
            >
              Cancel
            </button>
            <button
              onClick={handleResetSettings}
              className="flex-1 py-3 text-xs font-semibold rounded-full active:scale-95 transition-transform cursor-pointer"
              style={{ backgroundColor: 'var(--m3-error)', color: 'var(--m3-on-error)' }}
            >
              Reset
            </button>
          </div>
        </div>
      </Sheet>
    </>
  );
};
