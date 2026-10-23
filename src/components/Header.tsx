import React from 'react';
import { OmniCalcLogo } from './OmniCalcLogo';
import { NavIcon } from './NavIcons';
import { ThemeId } from '../types';

interface HeaderProps {
  soundEnabled: boolean;
  onToggleSound: () => void;
  onOpenSettings: () => void;
  onOpenGuide: () => void;
  /** Tapping the round logo (shown when the header is collapsed) scrolls back to the top */
  onLogoTap?: () => void;
  theme?: ThemeId;
}

/**
 * Floating glass pill at the top, like Ping's search bar. On the screens that scroll (Converter, Physics,
 * Finance ...) it collapses as you scroll down: the pill shrinks to a round logo button, the name moves to
 * the centre and the three actions keep a small pill of their own on the right.
 * App.tsx drives it with one CSS variable, --hc (0 = full pill, 1 = collapsed), so scrolling never re-renders React.
 * Only one set of buttons exists: they sit inside the big pill at rest and inside their own small pill when collapsed.
 */
export const Header: React.FC<HeaderProps> = ({
  soundEnabled,
  onToggleSound,
  onOpenSettings,
  onOpenGuide,
  onLogoTap,
  theme,
}) => {
  return (
    <header
      className="px-3 pb-1 select-none pointer-events-none"
      style={{ paddingTop: 'max(env(safe-area-inset-top, 0px), 8px)' }}
    >
      <div className="relative w-full max-w-[1650px] mx-auto h-14">
        {/* The big pill: shrinks to a circle that holds the logo */}
        <div className="bar-surface hdr-pill pointer-events-auto absolute left-0 top-0 h-14 rounded-full overflow-hidden">
          <button
            type="button"
            onClick={onLogoTap}
            aria-label="OmniCalc, back to top"
            className="absolute left-2.5 top-1/2 -translate-y-1/2 w-9 h-9 flex items-center justify-center cursor-pointer active:scale-90 transition-transform"
          >
            <OmniCalcLogo key={theme} theme={theme} className="w-9 h-9 shrink-0" />
          </button>
          <span
            className="hdr-title absolute left-[58px] top-0 h-14 flex items-center text-lg font-bold tracking-tight whitespace-nowrap"
            style={{ color: 'var(--m3-on-surface)' }}
          >
            OmniCalc
          </span>
        </div>

        {/* Name in the middle once collapsed */}
        <span
          className="hdr-ctitle absolute top-0 h-14 flex items-center justify-center text-xl font-extrabold tracking-tight whitespace-nowrap pointer-events-none"
          style={{ color: 'var(--m3-primary)' }}
          aria-hidden="true"
        >
          OmniCalc
        </span>

        {/* Actions: transparent inside the big pill, their own small glass pill when collapsed */}
        <div className="hdr-icons pointer-events-auto absolute right-0 top-0 h-14 flex items-center gap-0.5 pl-1.5 pr-1.5">
          <span className="bar-surface hdr-icons-bg absolute inset-0 rounded-full" aria-hidden="true" />
          <button
            onClick={onOpenGuide}
            aria-label="How to use OmniCalc"
            title="User guide: how to use the advanced functions"
            className="relative w-11 h-11 rounded-full flex items-center justify-center shrink-0 cursor-pointer active:scale-90 transition-transform"
            style={{ color: 'var(--m3-primary)' }}
          >
            <NavIcon id="guide" size={22} />
          </button>

          <button
            onClick={onToggleSound}
            aria-label={soundEnabled ? 'Mute key clicks' : 'Enable key clicks'}
            title={soundEnabled ? 'Key click audio enabled' : 'Key click audio muted'}
            className="relative w-11 h-11 rounded-full flex items-center justify-center shrink-0 cursor-pointer active:scale-90 transition-transform"
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
            className="relative w-11 h-11 rounded-full flex items-center justify-center shrink-0 cursor-pointer active:scale-90 transition-transform"
            style={{ color: 'var(--m3-on-surface)' }}
          >
            <NavIcon id="settings" size={20} />
          </button>
        </div>
      </div>
    </header>
  );
};
