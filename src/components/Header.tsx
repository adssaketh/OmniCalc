import React from 'react';
import { PWAInstallButton } from './PWAInstallButton';
import { OmniCalcLogo } from './OmniCalcLogo';
import { NavIcon } from './NavIcons';
import { ThemeId } from '../types';

interface HeaderProps {
  soundEnabled: boolean;
  onToggleSound: () => void;
  onOpenSettings: () => void;
  theme?: ThemeId;
}

/** Floating pill bar at the top, like Ping's search bar: logo and name on the left, actions on the right. */
export const Header: React.FC<HeaderProps> = ({ soundEnabled, onToggleSound, onOpenSettings, theme }) => {
  return (
    <header
      className="sticky top-0 z-40 px-3 pb-1 select-none"
      style={{
        backgroundColor: 'var(--m3-surface)',
        paddingTop: 'max(env(safe-area-inset-top, 0px), 8px)',
      }}
    >
      <div
        className="w-full max-w-[1650px] mx-auto h-14 pl-3 pr-1.5 rounded-full flex items-center gap-2 shadow-md shadow-black/5"
        style={{ backgroundColor: 'var(--m3-surface-container)' }}
      >
        <OmniCalcLogo key={theme} theme={theme} className="w-8 h-8 shrink-0" />
        <span className="text-lg font-bold tracking-tight whitespace-nowrap" style={{ color: 'var(--m3-on-surface)' }}>
          OmniCalc
        </span>

        <div className="flex-1" />

        <PWAInstallButton variant="header" />

        <button
          onClick={onToggleSound}
          aria-label={soundEnabled ? 'Mute key clicks' : 'Enable key clicks'}
          title={soundEnabled ? 'Key click audio enabled' : 'Key click audio muted'}
          className="w-11 h-11 rounded-full flex items-center justify-center shrink-0 cursor-pointer active:scale-90 transition-transform"
          style={{
            backgroundColor: soundEnabled ? 'var(--m3-secondary-container)' : 'transparent',
            color: soundEnabled ? 'var(--m3-on-secondary-container)' : 'var(--m3-on-surface-variant)',
          }}
        >
          <NavIcon id="sound" active={soundEnabled} size={20} />
        </button>

        <button
          onClick={onOpenSettings}
          aria-label="Settings"
          title="Calculator preferences and theme"
          className="w-11 h-11 rounded-full flex items-center justify-center shrink-0 cursor-pointer active:scale-90 transition-transform"
          style={{ color: 'var(--m3-on-surface)' }}
        >
          <NavIcon id="settings" size={20} />
        </button>
      </div>
    </header>
  );
};
