import React, { useRef, useState, useEffect, useCallback } from 'react';
import { CalculatorMode } from '../types';
import { soundFx } from '../utils/audio';
import { NavIcon } from './NavIcons';

interface BottomNavBarProps {
  currentMode: CalculatorMode;
  onSelectMode: (mode: CalculatorMode) => void;
  soundEnabled: boolean;
  hapticEnabled: boolean;
  onToggleHistory: () => void;
  isHistoryOpen?: boolean;
  historyCount?: number;
  enableGrapher?: boolean;
}

interface NavSection {
  id: CalculatorMode | 'recents';
  label: string;
  iconName: string;
  isRecents?: boolean;
}

export const BottomNavBar: React.FC<BottomNavBarProps> = ({
  currentMode,
  onSelectMode,
  soundEnabled,
  hapticEnabled,
  onToggleHistory,
  isHistoryOpen = false,
  historyCount = 0,
  enableGrapher = false,
}) => {
  // Navigation sections list - Physics Lab placed directly in the center:
  // Calculator -> Converter -> Physics Lab (Center) -> Finance -> Recents
  const sections: NavSection[] = [
    { id: 'standard', label: 'Calculator', iconName: 'calculate' },
    { id: 'converter', label: 'Converter', iconName: 'swap_horiz' },
    { id: 'physics', label: 'Physics Lab', iconName: 'science' },
    { id: 'finance', label: 'Finance', iconName: 'payments' },
    { id: 'recents', label: 'Recents', iconName: 'history', isRecents: true },
  ];

  if (enableGrapher) {
    sections.push({ id: 'grapher', label: 'Grapher', iconName: 'show_chart' });
  }

  // Active section index
  const activeIndex = sections.findIndex((section) => {
    if (section.isRecents) return isHistoryOpen;
    return (
      !isHistoryOpen &&
      (currentMode === section.id || (currentMode === 'scientific' && section.id === 'standard'))
    );
  });
  const safeActiveIndex = activeIndex >= 0 ? activeIndex : 0;

  const dockRef = useRef<HTMLDivElement | null>(null);
  const iconWrapperRefs = useRef<Map<number, HTMLDivElement>>(new Map());

  // Pill layout geometry (centered strictly behind the active icon)
  const [pillGeometry, setPillGeometry] = useState<{
    width: number;
    height: number;
    top: number;
    left: number;
  }>({ width: 56, height: 32, top: 8, left: 0 });

  const calculateIconPosition = useCallback((index: number) => {
    const iconEl = iconWrapperRefs.current.get(index);
    const dockEl = dockRef.current;
    if (iconEl && dockEl) {
      const iconRect = iconEl.getBoundingClientRect();
      const dockRect = dockEl.getBoundingClientRect();
      return {
        width: iconRect.width,
        height: iconRect.height,
        left: iconRect.left - dockRect.left,
        top: iconRect.top - dockRect.top,
      };
    }
    return null;
  }, []);

  const updatePillToActive = useCallback(() => {
    const pos = calculateIconPosition(safeActiveIndex);
    if (pos) {
      setPillGeometry(pos);
    }
  }, [safeActiveIndex, calculateIconPosition]);

  useEffect(() => {
    updatePillToActive();
    const handleResize = () => updatePillToActive();
    window.addEventListener('resize', handleResize);
    const timer = setTimeout(updatePillToActive, 60);
    return () => {
      window.removeEventListener('resize', handleResize);
      clearTimeout(timer);
    };
  }, [updatePillToActive]);

  const selectSection = (index: number) => {
    const targetSection = sections[index];
    if (!targetSection) return;

    if (soundEnabled) soundFx.playClick('toggle');
    if (hapticEnabled) soundFx.triggerHaptic();

    if (targetSection.isRecents) {
      onToggleHistory();
    } else {
      onSelectMode(targetSection.id as CalculatorMode);
    }
  };

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-40 select-none pb-safe pointer-events-auto transition-transform duration-300"
      style={{
        paddingBottom: 'max(env(safe-area-inset-bottom, 0px), 8px)',
      }}
      aria-label="Bottom Navigation Bar"
    >
      {/* Floating dock container with dark M3 surface container */}
      <div className="max-w-xl sm:max-w-2xl mx-auto px-2 sm:px-4">
        <div
          ref={dockRef}
          className="relative rounded-[28px] sm:rounded-full px-2 py-2 flex items-center justify-around backdrop-blur-2xl shadow-xl border border-[var(--m3-outline-variant)]"
          style={{
            backgroundColor: 'color-mix(in srgb, var(--m3-surface-container) 95%, transparent)',
          }}
        >
          {/* M3 Expressive Fluid Moving Pill Indicator (Centered strictly over the Icon) */}
          <div
            className="absolute pointer-events-none z-0 rounded-full transition-all duration-300 ease-[cubic-bezier(0.34,1.4,0.64,1)]"
            style={{
              top: `${pillGeometry.top}px`,
              left: `${pillGeometry.left}px`,
              width: `${pillGeometry.width}px`,
              height: `${pillGeometry.height}px`,
              backgroundColor: 'var(--m3-primary-container)',
              boxShadow: '0 2px 10px color-mix(in srgb, var(--m3-primary) 25%, transparent)',
              willChange: 'left, top, width, height',
            }}
          />

          {sections.map((section, idx) => {
            const isActive = section.isRecents
              ? isHistoryOpen
              : !isHistoryOpen &&
                (currentMode === section.id || (currentMode === 'scientific' && section.id === 'standard'));

            return (
              <button
                key={section.id}
                type="button"
                onClick={() => selectSection(idx)}
                className="group flex flex-col items-center justify-center flex-1 min-h-[48px] py-1 px-1 rounded-2xl outline-none active:scale-95 relative z-10 cursor-pointer"
                title={section.isRecents ? `Recent Calculations (${historyCount})` : section.label}
                aria-pressed={isActive}
              >
                {/* M3 Expressive Icon Pill Wrapper (Target for Centered Pill) */}
                <div
                  ref={(el) => {
                    if (el) iconWrapperRefs.current.set(idx, el);
                    else iconWrapperRefs.current.delete(idx);
                  }}
                  className="w-12 sm:w-16 h-8 rounded-full flex items-center justify-center relative transition-all duration-200"
                  style={{
                    color: isActive
                      ? 'var(--m3-on-primary-container)'
                      : 'var(--m3-on-surface-variant)',
                  }}
                >
                  <NavIcon
                    id={section.id}
                    active={isActive}
                    size={22}
                    className={`transition-transform duration-200 ease-out ${
                      isActive
                        ? 'scale-105'
                        : 'opacity-75 group-hover:opacity-100 group-hover:scale-105'
                    }`}
                  />

                  {/* Recents counter badge */}
                  {section.isRecents && historyCount > 0 && (
                    <span
                      className="absolute -top-1 -right-1 min-w-[16px] h-4 px-1 rounded-full text-[9px] font-bold flex items-center justify-center leading-none border border-black/30 shadow-xs"
                      style={{
                        backgroundColor: 'var(--m3-primary)',
                        color: 'var(--m3-on-primary)',
                      }}
                    >
                      {historyCount > 99 ? '99+' : historyCount}
                    </span>
                  )}
                </div>

                {/* M3 Expressive Typography Label - Positioned below pill */}
                <span
                  className={`text-[10px] sm:text-[11px] tracking-tight mt-0.5 leading-tight truncate max-w-[68px] sm:max-w-none text-center transition-all duration-200 ${
                    isActive
                      ? 'font-bold'
                      : 'font-medium opacity-80 group-hover:opacity-100'
                  }`}
                  style={{
                    color: isActive ? 'var(--m3-on-surface)' : 'var(--m3-on-surface-variant)',
                  }}
                >
                  {section.label}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </nav>
  );
};
