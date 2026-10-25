import React from 'react';
import { motion } from 'motion/react';
import { CalculatorMode, ThemeId } from '../types';
import { OmniCalcLogo } from './OmniCalcLogo';
import { NavIcon } from './NavIcons';
import { getNavItems, isNavItemActive, navFeedback } from '../navigation';
import { springBouncy } from '../motion';

interface NavigationRailProps {
  currentMode: CalculatorMode;
  onSelectMode: (mode: CalculatorMode) => void;
  soundEnabled: boolean;
  hapticEnabled: boolean;
  onToggleSound: () => void;
  onOpenSettings: () => void;
  onOpenGuide: () => void;
  onOpenHistory: () => void;
  isHistoryOpen?: boolean;
  historyCount?: number;
  enableGrapher?: boolean;
  enablePhysics?: boolean;
  theme?: ThemeId;
}

/** Material 3 navigation rail for tablets and desktop: same destinations and pill indicator as the bottom bar. */
export const NavigationRail: React.FC<NavigationRailProps> = ({
  currentMode,
  onSelectMode,
  soundEnabled,
  hapticEnabled,
  onToggleSound,
  onOpenSettings,
  onOpenGuide,
  onOpenHistory,
  isHistoryOpen = false,
  historyCount = 0,
  enableGrapher = false,
  enablePhysics = false,
  theme,
}) => {
  const items = getNavItems(enableGrapher, enablePhysics);

  return (
    <aside
      className="h-full z-40 flex flex-col justify-between items-center py-3 select-none shrink-0"
      style={{
        width: 'calc(88px + env(safe-area-inset-left, 0px))',
        paddingLeft: 'max(env(safe-area-inset-left, 0px), 8px)',
        paddingRight: '8px',
        paddingTop: 'max(env(safe-area-inset-top, 0px), 12px)',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px), 12px)',
        backgroundColor: 'var(--m3-surface-container-low)',
      }}
      aria-label="Navigation Rail"
    >
      <button type="button" className="cursor-pointer active:scale-95 transition-transform" onClick={() => onSelectMode('standard')} aria-label="OmniCalc">
        <OmniCalcLogo key={theme} theme={theme} className="w-10 h-10" />
      </button>

      <div className="flex flex-col items-center gap-2.5 my-auto w-full">
        {items.map((item) => {
          const active = isNavItemActive(item, currentMode, isHistoryOpen);
          const isRecents = item.id === 'recents';
          return (
            <button
              key={item.id}
              onClick={() => {
                navFeedback(soundEnabled, hapticEnabled);
                if (isRecents) onOpenHistory();
                else onSelectMode(item.id as CalculatorMode);
              }}
              className="w-full min-h-[48px] py-1 flex flex-col items-center justify-center gap-0.5 rounded-2xl cursor-pointer"
              aria-label={item.railLabel}
              title={item.railLabel}
            >
              <span className="relative flex items-center justify-center w-14 h-8 rounded-full">
                {active && (
                  <motion.span
                    layoutId="rail-pill"
                    className="absolute inset-0 rounded-full"
                    style={{ backgroundColor: 'var(--m3-primary-container)' }}
                    transition={springBouncy}
                  />
                )}
                <span
                  className="relative z-10"
                  style={{ color: active ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)' }}
                >
                  <NavIcon id={item.id} active={active} size={22} />
                </span>
                {isRecents && historyCount > 0 && (
                  <span
                    className="absolute -top-1 right-0.5 z-10 min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold flex items-center justify-center"
                    style={{ backgroundColor: 'var(--m3-primary)', color: 'var(--m3-on-primary)' }}
                  >
                    {historyCount > 99 ? '99+' : historyCount}
                  </span>
                )}
              </span>
              <span
                className={`text-[10.5px] whitespace-nowrap ${active ? 'font-bold' : 'font-medium'}`}
                style={{ color: active ? 'var(--m3-on-surface)' : 'var(--m3-on-surface-variant)' }}
              >
                {item.railLabel}
              </span>
            </button>
          );
        })}
      </div>

      <div className="flex flex-col items-center gap-2 shrink-0">
        <button
          onClick={onOpenGuide}
          aria-label="How to use OmniCalc"
          title="User guide"
          className="w-11 h-11 rounded-full flex items-center justify-center cursor-pointer active:scale-90 transition-transform"
          style={{ color: 'var(--m3-primary)' }}
        >
          <NavIcon id="guide" size={22} />
        </button>
        <button
          onClick={onToggleSound}
          aria-label={soundEnabled ? 'Mute key clicks' : 'Enable key clicks'}
          title={soundEnabled ? 'Key clicks enabled' : 'Key clicks muted'}
          className="w-11 h-11 rounded-full flex items-center justify-center cursor-pointer active:scale-90 transition-transform"
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
          className="w-11 h-11 rounded-full flex items-center justify-center cursor-pointer active:scale-90 transition-transform"
          style={{ color: 'var(--m3-on-surface)' }}
        >
          <NavIcon id="settings" size={20} />
        </button>
      </div>
    </aside>
  );
};
