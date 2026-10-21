import React from 'react';
import { PWAInstallButton } from './PWAInstallButton';
import { OmniCalcLogo } from './OmniCalcLogo';
import { NavIcon } from './NavIcons';
import { ThemeId } from '../types';

interface HeaderProps {
  soundEnabled: boolean;
  onToggleSound: () => void;
  onOpenHistory?: () => void;
  onOpenSettings: () => void;
  historyCount?: number;
  theme?: ThemeId;
}

export const Header: React.FC<HeaderProps> = ({
  soundEnabled,
  onToggleSound,
  onOpenSettings,
  theme,
}) => {
  return (
    <header
      className="sticky top-0 z-40 backdrop-blur-xl border-b border-[var(--m3-outline-variant)]/40 transition-colors select-none"
      style={{
        backgroundColor: 'var(--m3-surface)',
        paddingTop: 'env(safe-area-inset-top, 0px)',
      }}
    >
      <div className="w-full px-4 sm:px-6 lg:px-8 h-14 sm:h-16 flex items-center justify-between gap-4">
        {/* Zone 1: Material 3 Expressive Brand Header */}
        <div className="flex items-center gap-2.5 sm:gap-3 shrink-0">
          <div className="relative group">
            <OmniCalcLogo
              key={theme}
              theme={theme}
              className="w-8 h-8 sm:w-9 sm:h-9 drop-shadow-md transition-all duration-300 ease-out transform group-hover:rotate-6 group-hover:scale-105 active:scale-95 animate-in zoom-in-90"
            />
          </div>
          <div className="flex flex-col">
            <div className="flex items-baseline gap-1.5 leading-tight">
              <span
                className="text-base sm:text-lg font-bold tracking-tight whitespace-nowrap"
                style={{ color: 'var(--m3-on-surface)' }}
              >
                OmniCalc
              </span>
              <span
                className="text-[10px] sm:text-[11px] font-medium tracking-normal whitespace-nowrap opacity-65"
                style={{ color: 'var(--m3-on-surface-variant)' }}
              >
                By Saketh
              </span>
            </div>
            <span
              className="text-[10px] font-medium tracking-wider uppercase opacity-60 hidden sm:block"
              style={{ color: 'var(--m3-on-surface-variant)' }}
            >
              Material 3 Expressive
            </span>
          </div>
        </div>

        {/* Zone 2: Primary Expressive Action Pills */}
        <div className="flex items-center gap-1.5 sm:gap-2 shrink-0">
          {/* PWA In-App Install Button */}
          <PWAInstallButton variant="header" />

          {/* Audio toggle button with M3 state layer */}
          <button
            onClick={onToggleSound}
            aria-label={soundEnabled ? 'Mute key clicks' : 'Enable key clicks'}
            title={soundEnabled ? 'Key click audio enabled' : 'Key click audio muted'}
            className="w-12 h-12 rounded-full flex items-center justify-center transition-all duration-150 active:scale-90 border border-[var(--m3-outline-variant)]/40 cursor-pointer"
            style={{
              backgroundColor: soundEnabled
                ? 'var(--m3-secondary-container)'
                : 'var(--m3-surface-container)',
              color: soundEnabled
                ? 'var(--m3-on-secondary-container)'
                : 'var(--m3-on-surface-variant)',
            }}
          >
            <NavIcon
              id="sound"
              active={soundEnabled}
              size={20}
            />
          </button>

          {/* Settings Button */}
          <button
            onClick={onOpenSettings}
            aria-label="Settings"
            title="Calculator preferences and theme"
            className="w-12 h-12 rounded-full flex items-center justify-center transition-all duration-150 active:scale-90 border border-[var(--m3-outline-variant)]/40 cursor-pointer"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              color: 'var(--m3-on-surface)',
            }}
          >
            <NavIcon id="settings" size={20} />
          </button>
        </div>
      </div>
    </header>
  );
};
