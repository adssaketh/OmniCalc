import React from 'react';
import { motion } from 'motion/react';
import { CalculatorMode } from '../types';
import { NavIcon } from './NavIcons';
import { getNavItems, isNavItemActive, navFeedback } from '../navigation';
import { spring, springBouncy } from '../motion';

interface BottomNavBarProps {
  currentMode: CalculatorMode;
  onSelectMode: (mode: CalculatorMode) => void;
  soundEnabled: boolean;
  hapticEnabled: boolean;
  onToggleHistory: () => void;
  isHistoryOpen?: boolean;
  historyCount?: number;
  enableGrapher?: boolean;
  enablePhysics?: boolean;
}

/**
 * Material 3 navigation bar floating at the bottom, easy to reach with your thumb (same look as Ping's tabs).
 * App.tsx positions it; its surface (solid or glass) comes from the `bar-surface` class.
 */
export const BottomNavBar: React.FC<BottomNavBarProps> = ({
  currentMode,
  onSelectMode,
  soundEnabled,
  hapticEnabled,
  onToggleHistory,
  isHistoryOpen = false,
  historyCount = 0,
  enableGrapher = false,
  enablePhysics = false,
}) => {
  const items = getNavItems(enableGrapher, enablePhysics);

  return (
    <motion.nav
      aria-label="Bottom Navigation Bar"
      className="select-none pointer-events-none px-3 pt-1"
      style={{ paddingBottom: 'max(env(safe-area-inset-bottom, 0px), 8px)' }}
      initial={{ y: 90, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={spring}
    >
      <div
        className="bar-surface pointer-events-auto flex items-stretch justify-between gap-1 max-w-xl sm:max-w-2xl mx-auto rounded-[32px] px-1.5 py-1.5"
      >
        {items.map((item) => {
          const active = isNavItemActive(item, currentMode, isHistoryOpen);
          const isRecents = item.id === 'recents';
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => {
                navFeedback(soundEnabled, hapticEnabled);
                if (isRecents) onToggleHistory();
                else onSelectMode(item.id as CalculatorMode);
              }}
              title={isRecents ? `Recent Calculations (${historyCount})` : item.label}
              aria-pressed={active}
              className="flex-1 min-w-0 flex flex-col items-center gap-0.5 py-0.5 rounded-2xl cursor-pointer"
            >
              <span className="relative flex items-center justify-center w-14 h-8 rounded-full">
                {active && (
                  <motion.span
                    layoutId="bottom-nav-pill"
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
                className={`text-[10.5px] truncate max-w-full ${active ? 'font-bold' : 'font-medium'}`}
                style={{ color: active ? 'var(--m3-on-surface)' : 'var(--m3-on-surface-variant)' }}
              >
                {item.label}
              </span>
            </button>
          );
        })}
      </div>
    </motion.nav>
  );
};
