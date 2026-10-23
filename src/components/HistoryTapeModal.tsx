import React, { useState } from 'react';
import { Sheet } from './Sheet';
import { HistoryItem } from '../types';
import { X, Trash2, Download, Copy, Check, CornerDownLeft, RotateCcw, Calculator, Atom, FileText } from 'lucide-react';

interface HistoryTapeModalProps {
  isOpen: boolean;
  onClose: () => void;
  history: HistoryItem[];
  onSelectResult: (val: string) => void;
  onSelectExpression?: (expr: string) => void;
  onClearHistory: () => void;
}

export const HistoryTapeModal: React.FC<HistoryTapeModalProps> = ({
  isOpen,
  onClose,
  history,
  onSelectResult,
  onSelectExpression,
  onClearHistory,
}) => {
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [activeFilter, setActiveFilter] = useState<'all' | 'calc' | 'physics'>('all');
  const [showClearConfirm, setShowClearConfirm] = useState<boolean>(false);

  const handleCopy = (item: HistoryItem, e?: React.MouseEvent) => {
    e?.stopPropagation();
    navigator.clipboard.writeText(`${item.expression} = ${item.result}`);
    setCopiedId(item.id);
    setTimeout(() => setCopiedId(null), 1800);
  };

  const handleExport = () => {
    const textContent = history
      .map(
        (h) =>
          `[${new Date(h.timestamp).toLocaleTimeString()}] ${h.expression} = ${h.result} (${h.mode || 'calc'})`
      )
      .join('\n');

    const blob = new Blob([textContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `omnicalc-history-${Date.now()}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleUseItem = (val: string, e?: React.MouseEvent) => {
    e?.stopPropagation();
    onSelectResult(val);
    onClose();
  };

  const handleUseFormula = (expr: string, e?: React.MouseEvent) => {
    e?.stopPropagation();
    if (onSelectExpression) {
      onSelectExpression(expr);
    } else {
      onSelectResult(expr);
    }
    onClose();
  };

  // Filter categories with complete coverage (including scientific mode)
  const isCalcItem = (h: HistoryItem) =>
    h.mode === 'calc' || h.mode === 'standard' || h.mode === 'scientific' || !h.mode;
  const isPhysicsItem = (h: HistoryItem) => h.mode === 'physics';

  const calcCount = history.filter(isCalcItem).length;
  const physicsCount = history.filter(isPhysicsItem).length;

  const displayedHistory = history.filter((item) => {
    if (activeFilter === 'all') return true;
    if (activeFilter === 'calc') return isCalcItem(item);
    if (activeFilter === 'physics') return isPhysicsItem(item);
    return true;
  });

  const filters: { id: 'all' | 'calc' | 'physics'; label: string; count: number; icon: React.ElementType }[] = [
    { id: 'all', label: 'All', count: history.length, icon: RotateCcw },
    { id: 'calc', label: 'Calculator', count: calcCount, icon: Calculator },
    { id: 'physics', label: 'Physics', count: physicsCount, icon: Atom },
  ];

  const iconButton = 'w-10 h-10 rounded-full flex items-center justify-center cursor-pointer active:scale-90 transition-transform';

  return (
    <Sheet isOpen={isOpen} onClose={onClose} label="Recent calculations" widthClass="sm:max-w-xl">
      {/* Header */}
      <div className="px-6 pt-4 pb-2 flex items-center gap-4">
        <div
          className="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0"
          style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}
        >
          <RotateCcw className="w-6 h-6" />
        </div>
        <div className="min-w-0 flex-1">
          <h2 className="text-lg font-bold leading-tight">Recent Calculations</h2>
          <p className="text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>
            {history.length} saved on this device
          </p>
        </div>
        <div className="flex items-center gap-1 shrink-0">
          {history.length > 0 && (
            <>
              <button
                onClick={handleExport}
                title="Export history as text"
                className={iconButton}
                style={{ color: 'var(--m3-on-surface-variant)' }}
              >
                <Download className="w-5 h-5" />
              </button>
              {showClearConfirm ? (
                <button
                  onClick={() => {
                    onClearHistory();
                    setShowClearConfirm(false);
                  }}
                  title="Confirm Clear All"
                  className="px-3 h-10 rounded-full flex items-center gap-1.5 text-xs font-bold cursor-pointer active:scale-95 transition-transform"
                  style={{ backgroundColor: 'var(--m3-error-container)', color: 'var(--m3-on-error-container)' }}
                >
                  <Trash2 className="w-4 h-4" />
                  <span>Clear All?</span>
                </button>
              ) : (
                <button
                  onClick={() => setShowClearConfirm(true)}
                  title="Clear history tape"
                  className={iconButton}
                  style={{ color: 'var(--m3-on-surface-variant)' }}
                >
                  <Trash2 className="w-5 h-5" />
                </button>
              )}
            </>
          )}
          <button onClick={onClose} title="Close Recents" className={iconButton} style={{ color: 'var(--m3-on-surface-variant)' }}>
            <X className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Category filter chips */}
      <div className="px-6 pt-2 pb-2 flex items-center gap-2 overflow-x-auto no-scrollbar shrink-0">
        {filters.map((f) => {
          const active = activeFilter === f.id;
          const Icon = f.icon;
          return (
            <button
              key={f.id}
              onClick={() => setActiveFilter(f.id)}
              aria-pressed={active}
              className="px-4 py-2.5 rounded-full text-xs font-semibold flex items-center gap-1.5 cursor-pointer whitespace-nowrap"
              style={{
                backgroundColor: active ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                color: active ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
              }}
            >
              <Icon className="w-3.5 h-3.5" />
              <span>
                {f.label} ({f.count})
              </span>
            </button>
          );
        })}
      </div>

      {/* History list */}
      <div className="flex-1 overflow-y-auto min-h-0 px-4 py-2 space-y-2">
        {displayedHistory.length === 0 ? (
          <div
            className="py-14 text-center flex flex-col items-center justify-center gap-2"
            style={{ color: 'var(--m3-on-surface-variant)' }}
          >
            <div
              className="w-14 h-14 rounded-2xl flex items-center justify-center mb-1"
              style={{ backgroundColor: 'var(--m3-surface-container)' }}
            >
              <RotateCcw className="w-6 h-6 opacity-60" />
            </div>
            <span className="text-sm font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
              No calculations here yet
            </span>
            <span className="text-xs max-w-xs text-center">
              Calculate expressions in the Calculator or Physics Lab and your recent history will appear here instantly.
            </span>
          </div>
        ) : (
          displayedHistory.map((item) => (
            <div
              key={item.id}
              onClick={() => handleUseItem(item.result)}
              className="p-4 rounded-[24px] flex flex-col gap-2 cursor-pointer active:scale-[0.985] transition-transform"
              style={{ backgroundColor: 'var(--m3-surface-container)' }}
              title="Tap to load this result into calculator"
            >
              <div
                className="flex items-center justify-between text-[11px] font-mono"
                style={{ color: 'var(--m3-on-surface-variant)' }}
              >
                <span>
                  {new Date(item.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}
                </span>
                <span
                  className="uppercase text-[10px] tracking-wider px-2.5 py-0.5 rounded-full font-semibold"
                  style={{ backgroundColor: 'var(--m3-surface-container-high)', color: 'var(--m3-primary)' }}
                >
                  {item.mode || 'calc'}
                </span>
              </div>

              <div
                className="text-sm font-mono tracking-wide overflow-x-auto whitespace-nowrap no-scrollbar py-0.5"
                style={{ color: 'var(--m3-on-surface)' }}
              >
                {item.expression}
              </div>

              <div className="flex items-center justify-between pt-1">
                <span className="text-base sm:text-lg font-mono font-bold tracking-tight" style={{ color: 'var(--m3-primary)' }}>
                  = {item.result}
                </span>

                <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
                  <button
                    onClick={(e) => handleCopy(item, e)}
                    title="Copy calculation"
                    className="w-9 h-9 rounded-full flex items-center justify-center active:scale-90 transition-transform cursor-pointer"
                    style={{ backgroundColor: 'var(--m3-surface-container-high)', color: 'var(--m3-on-surface-variant)' }}
                  >
                    {copiedId === item.id ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                  </button>

                  <button
                    onClick={(e) => handleUseFormula(item.expression, e)}
                    title="Load entire formula into calculator"
                    className="px-3.5 h-9 rounded-full flex items-center gap-1.5 text-[11px] font-semibold active:scale-95 transition-transform cursor-pointer"
                    style={{ backgroundColor: 'var(--m3-surface-container-highest)', color: 'var(--m3-on-surface)' }}
                  >
                    <FileText className="w-3.5 h-3.5 opacity-70" />
                    <span>Formula</span>
                  </button>

                  <button
                    onClick={(e) => handleUseItem(item.result, e)}
                    title="Load result value into calculator"
                    className="px-4 h-9 rounded-full flex items-center gap-1.5 text-xs font-bold active:scale-95 transition-transform cursor-pointer"
                    style={{ backgroundColor: 'var(--m3-primary)', color: 'var(--m3-on-primary)' }}
                  >
                    <CornerDownLeft className="w-3.5 h-3.5" />
                    <span>Use</span>
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Footer */}
      <div
        className="px-6 py-3 flex items-center justify-between text-xs shrink-0"
        style={{ color: 'var(--m3-on-surface-variant)' }}
      >
        <span>Tap any item to load into calculator</span>
        <button
          onClick={onClose}
          className="px-5 py-2.5 text-xs font-semibold rounded-full active:scale-95 transition-transform cursor-pointer"
          style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}
        >
          Close
        </button>
      </div>
    </Sheet>
  );
};
