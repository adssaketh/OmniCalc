import React from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'motion/react';
import { spring, fadeFast } from '../motion';

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
          <div className="fixed inset-0 bg-black/45" onClick={onClose} />
          <motion.div
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
            <div
              className="w-10 h-1.5 rounded-full mx-auto mt-3 shrink-0 sm:hidden"
              style={{ backgroundColor: 'var(--m3-outline-variant)' }}
            />
            {children}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body
  );
};
