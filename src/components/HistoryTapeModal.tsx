import React, { useState } from 'react';
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

  React.useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

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

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 backdrop-blur-md animate-in fade-in duration-200"
      style={{ backgroundColor: 'var(--m3-scrim)' }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg sm:max-w-xl md:max-w-2xl rounded-[32px] sm:rounded-[36px] border shadow-2xl overflow-hidden flex flex-col max-h-[88vh] transition-all"
        style={{
          backgroundColor: 'var(--m3-surface-container-low)',
          borderColor: 'var(--m3-outline-variant)',
          color: 'var(--m3-on-surface)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* M3 Expressive Drag Pill Handle */}
        <div className="pt-3 pb-1 flex justify-center">
          <div className="w-10 h-1 rounded-full opacity-40" style={{ backgroundColor: 'var(--m3-outline)' }} />
        </div>

        {/* Header */}
        <div
          className="px-5 sm:px-6 py-3 border-b flex items-center justify-between"
          style={{ borderColor: 'var(--m3-outline-variant)' }}
        >
          <div className="flex items-center gap-2.5">
            <h3 className="font-bold text-base sm:text-lg leading-tight" style={{ color: 'var(--m3-on-surface)' }}>
              Recent Calculations
            </h3>
            <span
              className="text-xs px-2.5 py-0.5 rounded-full font-mono font-bold"
              style={{
                backgroundColor: 'var(--m3-primary-container)',
                color: 'var(--m3-on-primary-container)',
              }}
            >
              {history.length}
            </span>
          </div>

          <div className="flex items-center gap-1.5">
            {history.length > 0 && (
              <>
                <button
                  onClick={handleExport}
                  title="Export history as text"
                  className="w-9 h-9 rounded-full flex items-center justify-center transition-all active:scale-90 border cursor-pointer"
                  style={{
                    backgroundColor: 'var(--m3-surface-container)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface-variant)',
                  }}
                >
                  <Download className="w-4 h-4" />
                </button>
                {showClearConfirm ? (
                  <button
                    onClick={() => {
                      onClearHistory();
                      setShowClearConfirm(false);
                    }}
                    title="Confirm Clear All"
                    className="px-2.5 h-9 rounded-full flex items-center gap-1 text-xs font-bold transition-all active:scale-95 border cursor-pointer animate-in zoom-in-95"
                    style={{
                      backgroundColor: 'var(--m3-error-container)',
                      borderColor: 'var(--m3-error)',
                      color: 'var(--m3-on-error-container)',
                    }}
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    <span>Clear All?</span>
                  </button>
                ) : (
                  <button
                    onClick={() => setShowClearConfirm(true)}
                    title="Clear history tape"
                    className="w-9 h-9 rounded-full flex items-center justify-center transition-all active:scale-90 border cursor-pointer"
                    style={{
                      backgroundColor: 'var(--m3-surface-container)',
                      borderColor: 'var(--m3-outline-variant)',
                      color: 'var(--m3-on-surface-variant)',
                    }}
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                )}
              </>
            )}
            <button
              onClick={onClose}
              className="w-9 h-9 rounded-full flex items-center justify-center transition-all active:scale-90 border cursor-pointer"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                borderColor: 'var(--m3-outline-variant)',
                color: 'var(--m3-on-surface-variant)',
              }}
              title="Close Recents"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Category Filter Chips */}
        <div className="px-5 pt-3 pb-2 flex items-center gap-2 overflow-x-auto scrollbar-none">
          <button
            onClick={() => setActiveFilter('all')}
            className={`px-3.5 py-1.5 rounded-full text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer ${
              activeFilter === 'all'
                ? 'shadow-xs font-bold'
                : 'opacity-75 hover:opacity-100'
            }`}
            style={{
              backgroundColor:
                activeFilter === 'all'
                  ? 'var(--m3-primary)'
                  : 'var(--m3-surface-container)',
              color:
                activeFilter === 'all'
                  ? 'var(--m3-on-primary)'
                  : 'var(--m3-on-surface)',
              border: '1px solid var(--m3-outline-variant)',
            }}
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>All ({history.length})</span>
          </button>

          <button
            onClick={() => setActiveFilter('calc')}
            className={`px-3.5 py-1.5 rounded-full text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer ${
              activeFilter === 'calc'
                ? 'shadow-xs font-bold'
                : 'opacity-75 hover:opacity-100'
            }`}
            style={{
              backgroundColor:
                activeFilter === 'calc'
                  ? 'var(--m3-primary)'
                  : 'var(--m3-surface-container)',
              color:
                activeFilter === 'calc'
                  ? 'var(--m3-on-primary)'
                  : 'var(--m3-on-surface)',
              border: '1px solid var(--m3-outline-variant)',
            }}
          >
            <Calculator className="w-3.5 h-3.5" />
            <span>Calculator ({calcCount})</span>
          </button>

          <button
            onClick={() => setActiveFilter('physics')}
            className={`px-3.5 py-1.5 rounded-full text-xs font-semibold flex items-center gap-1.5 transition-all cursor-pointer ${
              activeFilter === 'physics'
                ? 'shadow-xs font-bold'
                : 'opacity-75 hover:opacity-100'
            }`}
            style={{
              backgroundColor:
                activeFilter === 'physics'
                  ? 'var(--m3-primary)'
                  : 'var(--m3-surface-container)',
              color:
                activeFilter === 'physics'
                  ? 'var(--m3-on-primary)'
                  : 'var(--m3-on-surface)',
              border: '1px solid var(--m3-outline-variant)',
            }}
          >
            <Atom className="w-3.5 h-3.5" />
            <span>Physics ({physicsCount})</span>
          </button>
        </div>

        {/* History List */}
        <div className="flex-1 overflow-y-auto max-h-[55vh] px-5 py-2 space-y-2.5">
          {displayedHistory.length === 0 ? (
            <div
              className="py-14 text-center flex flex-col items-center justify-center gap-2"
              style={{ color: 'var(--m3-on-surface-variant)' }}
            >
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center mb-1"
                style={{ backgroundColor: 'var(--m3-surface-container)' }}
              >
                <RotateCcw className="w-6 h-6 opacity-60" />
              </div>
              <span className="text-sm font-semibold">No calculations here yet</span>
              <span className="text-xs opacity-75 max-w-xs text-center">
                Calculate expressions in the Calculator or Physics Lab and your recent history will appear here instantly.
              </span>
            </div>
          ) : (
            displayedHistory.map((item) => (
              <div
                key={item.id}
                onClick={() => handleUseItem(item.result)}
                className="group p-3.5 sm:p-4 rounded-[22px] border transition-all flex flex-col gap-2 cursor-pointer hover:border-[var(--m3-primary)] hover:shadow-md active:scale-[0.99]"
                style={{
                  backgroundColor: 'var(--m3-surface-container)',
                  borderColor: 'var(--m3-outline-variant)',
                }}
                title="Tap to load this result into calculator"
              >
                <div
                  className="flex items-center justify-between text-[11px] font-mono"
                  style={{ color: 'var(--m3-on-surface-variant)' }}
                >
                  <span>{new Date(item.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
                  <span
                    className="uppercase text-[10px] tracking-wider px-2 py-0.5 rounded-full font-semibold"
                    style={{
                      backgroundColor: 'var(--m3-surface-container-high)',
                      color: 'var(--m3-primary)',
                    }}
                  >
                    {item.mode || 'calc'}
                  </span>
                </div>

                {/* Expression Formula */}
                <div
                  className="text-sm font-mono tracking-wide overflow-x-auto whitespace-nowrap scrollbar-none py-0.5"
                  style={{ color: 'var(--m3-on-surface)' }}
                >
                  {item.expression}
                </div>

                {/* Result & Action Buttons */}
                <div className="flex items-center justify-between pt-1 border-t border-[var(--m3-outline-variant)]/30">
                  <span
                    className="text-base sm:text-lg font-mono font-bold tracking-tight"
                    style={{ color: 'var(--m3-primary)' }}
                  >
                    = {item.result}
                  </span>

                  <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
                    {/* Copy Button */}
                    <button
                      onClick={(e) => handleCopy(item, e)}
                      title="Copy calculation"
                      className="w-8 h-8 rounded-full flex items-center justify-center transition-all active:scale-90 border cursor-pointer"
                      style={{
                        backgroundColor: 'var(--m3-surface-container-high)',
                        borderColor: 'var(--m3-outline-variant)',
                        color: 'var(--m3-on-surface-variant)',
                      }}
                    >
                      {copiedId === item.id ? (
                        <Check className="w-3.5 h-3.5 text-emerald-500" />
                      ) : (
                        <Copy className="w-3.5 h-3.5" />
                      )}
                    </button>

                    {/* Use Formula Button */}
                    <button
                      onClick={(e) => handleUseFormula(item.expression, e)}
                      title="Load entire formula into calculator"
                      className="px-2.5 h-8 rounded-full flex items-center gap-1 text-[11px] font-semibold transition-all active:scale-95 border cursor-pointer"
                      style={{
                        backgroundColor: 'var(--m3-surface-container-highest)',
                        borderColor: 'var(--m3-outline-variant)',
                        color: 'var(--m3-on-surface)',
                      }}
                    >
                      <FileText className="w-3 h-3 opacity-70" />
                      <span>Formula</span>
                    </button>

                    {/* Use Result Button */}
                    <button
                      onClick={(e) => handleUseItem(item.result, e)}
                      title="Load result value into calculator"
                      className="px-3 h-8 rounded-full flex items-center gap-1 text-xs font-bold transition-all active:scale-95 border cursor-pointer shadow-xs"
                      style={{
                        backgroundColor: 'var(--m3-primary)',
                        borderColor: 'var(--m3-primary)',
                        color: 'var(--m3-on-primary)',
                      }}
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
          className="px-5 sm:px-6 py-3 border-t flex items-center justify-between text-xs"
          style={{
            borderColor: 'var(--m3-outline-variant)',
            color: 'var(--m3-on-surface-variant)',
          }}
        >
          <span className="opacity-70">Tap any item to load into calculator</span>
          <button
            onClick={onClose}
            className="px-4 py-1.5 text-xs font-semibold rounded-full transition-all active:scale-95 shadow-xs cursor-pointer border border-[var(--m3-outline-variant)]"
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
