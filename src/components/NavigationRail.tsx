import React, { useRef, useState, useEffect, useCallback } from 'react';
import { CalculatorMode, ThemeId } from '../types';
import { soundFx } from '../utils/audio';
import { OmniCalcLogo } from './OmniCalcLogo';
import { NavIcon } from './NavIcons';

interface NavigationRailProps {
  currentMode: CalculatorMode;
  onSelectMode: (mode: CalculatorMode) => void;
  soundEnabled: boolean;
  hapticEnabled: boolean;
  onToggleSound: () => void;
  onOpenSettings: () => void;
  onOpenHistory: () => void;
  isHistoryOpen?: boolean;
  historyCount?: number;
  enableGrapher?: boolean;
  theme?: ThemeId;
}

interface RailDestination {
  id: CalculatorMode | 'recents';
  label: string;
  iconName: string;
  isRecents?: boolean;
}

/**
 * Google Material 3 Navigation Rail for Landscape and Tablet displays
 * Features vertical M3 active gliding indicator pill, filled/outlined Material Symbols,
 * edge-to-edge safe area insets, and integrated sound/settings actions.
 */
export const NavigationRail: React.FC<NavigationRailProps> = ({
  currentMode,
  onSelectMode,
  soundEnabled,
  hapticEnabled,
  onToggleSound,
  onOpenSettings,
  onOpenHistory,
  isHistoryOpen = false,
  historyCount = 0,
  enableGrapher = false,
  theme,
}) => {
  const destinations: RailDestination[] = [
    { id: 'standard', label: 'Calc', iconName: 'calculate' },
    { id: 'converter', label: 'Convert', iconName: 'swap_horiz' },
    { id: 'physics', label: 'Physics', iconName: 'science' },
    { id: 'finance', label: 'Finance', iconName: 'payments' },
    { id: 'recents', label: 'Recents', iconName: 'history', isRecents: true },
  ];

  if (enableGrapher) {
    destinations.push({ id: 'grapher', label: 'Graph', iconName: 'show_chart' });
  }

  const activeIndex = destinations.findIndex((dest) => {
    if (dest.isRecents) return isHistoryOpen;
    return (
      !isHistoryOpen &&
      (currentMode === dest.id || (currentMode === 'scientific' && dest.id === 'standard'))
    );
  });
  const safeActiveIndex = activeIndex >= 0 ? activeIndex : 0;

  const railRef = useRef<HTMLDivElement | null>(null);
  const iconWrapperRefs = useRef<Map<number, HTMLDivElement>>(new Map());

  const [pillGeometry, setPillGeometry] = useState<{
    width: number;
    height: number;
    top: number;
    left: number;
  }>({ width: 56, height: 32, top: 0, left: 14 });

  const calculatePillPosition = useCallback((index: number) => {
    const iconEl = iconWrapperRefs.current.get(index);
    const railEl = railRef.current;
    if (iconEl && railEl) {
      const iconRect = iconEl.getBoundingClientRect();
      const railRect = railEl.getBoundingClientRect();
      return {
        width: iconRect.width,
        height: iconRect.height,
        left: iconRect.left - railRect.left,
        top: iconRect.top - railRect.top,
      };
    }
    return null;
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      const pos = calculatePillPosition(safeActiveIndex);
      if (pos) {
        setPillGeometry(pos);
      }
    }, 40);
    return () => clearTimeout(timer);
  }, [safeActiveIndex, calculatePillPosition]);

  const handleDestinationClick = (dest: RailDestination) => {
    if (soundEnabled) soundFx.playClick('toggle');
    if (hapticEnabled) soundFx.triggerHaptic();

    if (dest.isRecents) {
      onOpenHistory();
    } else {
      onSelectMode(dest.id as CalculatorMode);
    }
  };

  return (
    <aside
      className="sticky top-0 h-screen z-40 flex flex-col justify-between items-center py-3 select-none border-r transition-colors shrink-0"
      style={{
        width: 'calc(80px + env(safe-area-inset-left, 0px))',
        paddingLeft: 'max(env(safe-area-inset-left, 0px), 8px)',
        paddingRight: '8px',
        paddingTop: 'max(env(safe-area-inset-top, 0px), 12px)',
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px), 12px)',
        backgroundColor: 'var(--m3-surface-container-low)',
        borderColor: 'var(--m3-outline-variant)',
      }}
      aria-label="Navigation Rail"
    >
      {/* 1. Brand Logo Header */}
      <div className="flex flex-col items-center gap-1 shrink-0 mb-2">
        <div className="relative group cursor-pointer" onClick={() => onSelectMode('standard')}>
          <OmniCalcLogo
            key={theme}
            theme={theme}
            className="w-9 h-9 drop-shadow-md transition-transform duration-200 active:scale-95"
          />
        </div>
      </div>

      {/* 2. Destination Items with Fluid Gliding Active Pill */}
      <div ref={railRef} className="relative flex flex-col items-center gap-2.5 my-auto w-full">
        {/* Active Gliding Pill with Spring curve */}
        {pillGeometry.height > 0 && (
          <div
            className="absolute rounded-full pointer-events-none z-0 transition-all duration-300 ease-[cubic-bezier(0.34,1.4,0.64,1)]"
            style={{
              top: `${pillGeometry.top}px`,
              left: `${pillGeometry.left}px`,
              width: `${pillGeometry.width}px`,
              height: `${pillGeometry.height}px`,
              backgroundColor: 'var(--m3-primary-container)',
              boxShadow: '0 2px 8px color-mix(in srgb, var(--m3-primary) 25%, transparent)',
            }}
          />
        )}

        {destinations.map((dest, idx) => {
          const isActive = idx === safeActiveIndex;
          return (
            <button
              key={dest.id}
              onClick={() => handleDestinationClick(dest)}
              className="group relative z-10 w-full min-h-[48px] py-1 flex flex-col items-center justify-center gap-0.5 rounded-full cursor-pointer transition-transform duration-150 active:scale-95 focus-visible:outline-2 focus-visible:outline-[var(--m3-primary)]"
              aria-label={dest.label}
              title={dest.label}
            >
              {/* Icon Container with Pill Dimensions */}
              <div
                ref={(el) => {
                  if (el) iconWrapperRefs.current.set(idx, el);
                  else iconWrapperRefs.current.delete(idx);
                }}
                className="w-14 h-8 rounded-full flex items-center justify-center transition-colors relative"
              >
                <NavIcon
                  id={dest.id}
                  active={isActive}
                  size={22}
                  className="transition-colors duration-200"
                  style={{
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                  }}
                />

                {/* Recents Badge */}
                {dest.isRecents && historyCount > 0 && (
                  <span
                    className="absolute -top-0.5 -right-0.5 min-w-[16px] h-4 px-1 rounded-full text-[9px] font-mono font-bold flex items-center justify-center"
                    style={{
                      backgroundColor: 'var(--m3-primary)',
                      color: 'var(--m3-on-primary)',
                    }}
                  >
                    {historyCount > 99 ? '99+' : historyCount}
                  </span>
                )}
              </div>

              {/* Destination Text Label */}
              <span
                className="text-[10px] tracking-tight transition-colors whitespace-nowrap"
                style={{
                  color: isActive ? 'var(--m3-on-surface)' : 'var(--m3-on-surface-variant)',
                  fontWeight: isActive ? 700 : 500,
                }}
              >
                {dest.label}
              </span>
            </button>
          );
        })}
      </div>

      {/* 3. Bottom Utility Actions (Sound & Settings) */}
      <div className="flex flex-col items-center gap-2 shrink-0 mt-2">
        <button
          onClick={onToggleSound}
          aria-label={soundEnabled ? 'Mute key clicks' : 'Enable key clicks'}
          title={soundEnabled ? 'Key clicks enabled' : 'Key clicks muted'}
          className="w-10 h-10 rounded-full flex items-center justify-center transition-all duration-150 active:scale-90 border cursor-pointer"
          style={{
            backgroundColor: soundEnabled
              ? 'var(--m3-secondary-container)'
              : 'var(--m3-surface-container)',
            borderColor: 'var(--m3-outline-variant)',
            color: soundEnabled
              ? 'var(--m3-on-secondary-container)'
              : 'var(--m3-on-surface-variant)',
          }}
        >
          <NavIcon
            id="sound"
            active={soundEnabled}
            size={18}
          />
        </button>

        <button
          onClick={onOpenSettings}
          aria-label="Settings"
          title="Calculator preferences and theme"
          className="w-10 h-10 rounded-full flex items-center justify-center transition-all duration-150 active:scale-90 border cursor-pointer"
          style={{
            backgroundColor: 'var(--m3-surface-container)',
            borderColor: 'var(--m3-outline-variant)',
            color: 'var(--m3-on-surface)',
          }}
        >
          <NavIcon id="settings" size={18} />
        </button>
      </div>
    </aside>
  );
};
