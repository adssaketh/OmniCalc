import React, { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'motion/react';
import { spring, fadeFast } from '../motion';
import { attachSheetDrag, shouldDismiss } from '../utils/sheetDrag';

interface SheetProps {
  isOpen: boolean;
  onClose: () => void;
  /** Accessible name of the dialog */
  label: string;
  /** Tailwind max-width for the centred (tablet / desktop) layout */
  widthClass?: string;
  /** Stacking level; nested sheets use a higher one */
  zClass?: string;
  /** Extra classes for the panel, e.g. padding */
  className?: string;
  children: React.ReactNode;
}

/**
 * Bottom sheet that becomes a centred card on wider screens: dimmed scrim, drag handle, spring slide.
 * The pill at the top is a real handle: drag it down (or flick) to close, or tap it.
 * Same pattern as Ping's action sheets.
 */
export const Sheet: React.FC<SheetProps> = ({
  isOpen,
  onClose,
  label,
  widthClass = 'sm:max-w-lg',
  zClass = 'z-50',
  className = '',
  children,
}) => {
  const panelRef = useRef<HTMLDivElement>(null);
  const scrimRef = useRef<HTMLDivElement>(null);
  const [handleEl, setHandleEl] = useState<HTMLDivElement | null>(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  // Drag handle: move the panel with the finger, close past a distance or on a flick, otherwise spring back
  useEffect(() => {
    if (!handleEl) return;
    const panel = panelRef.current;
    const scrim = scrimRef.current;
    if (!panel) return;
    let resetTimer = 0;

    const springBack = () => {
      panel.style.transition = 'translate 260ms cubic-bezier(0.2, 0, 0, 1)';
      panel.style.translate = '0 0';
      if (scrim) {
        scrim.style.transition = 'opacity 260ms linear';
        scrim.style.opacity = '1';
      }
    };

    const detach = attachSheetDrag(handleEl, {
      onMove: (dy) => {
        panel.style.transition = 'none';
        panel.style.translate = `0 ${dy}px`;
        if (scrim) {
          scrim.style.transition = 'none';
          scrim.style.opacity = String(Math.max(0.15, 1 - dy / 420));
        }
      },
      onRelease: (dy, velocity) => {
        if (shouldDismiss(dy, velocity)) {
          onCloseRef.current();
          // if the owner decides to keep the sheet open, bring it back instead of leaving it half-way down
          resetTimer = window.setTimeout(springBack, 450);
        } else {
          springBack();
        }
      },
      onTap: () => onCloseRef.current(),
    });
    return () => {
      detach();
      window.clearTimeout(resetTimer);
    };
  }, [handleEl]);

  if (typeof document === 'undefined') return null;

  return createPortal(
    <AnimatePresence>
      {isOpen && (
        <motion.div
          key="sheet"
          className={`fixed inset-0 ${zClass} flex items-end sm:items-center justify-center`}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={fadeFast}
        >
          <div ref={scrimRef} className="fixed inset-0 bg-black/45" onClick={onClose} />
          <motion.div
            ref={panelRef}
            role="dialog"
            aria-modal="true"
            aria-label={label}
            className={`will-change-transform relative w-full ${widthClass} max-h-[88vh] overflow-hidden flex flex-col rounded-t-[32px] sm:rounded-[32px] shadow-2xl ${className}`}
            style={{ backgroundColor: 'var(--m3-surface-container-low)', color: 'var(--m3-on-surface)' }}
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={spring}
          >
            {/* Drag handle. The pill keeps its look and spacing; the touch area behind it is taller (30 px) */}
            <div className="relative h-[18px] shrink-0 sm:hidden">
              <div
                ref={setHandleEl}
                role="button"
                aria-label="Drag down or tap to close"
                className="absolute inset-x-0 top-0 z-10 h-[30px] cursor-grab touch-none select-none"
              >
                <div
                  className="w-10 h-1.5 rounded-full mx-auto mt-3"
                  style={{ backgroundColor: 'var(--m3-outline-variant)' }}
                />
              </div>
            </div>
            {children}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body
  );
};
