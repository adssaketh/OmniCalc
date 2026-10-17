import React, { useState, useMemo } from 'react';
import { FinanceEngine } from '../engine/finance';
import { useTheme } from '../hooks/useTheme';

interface TipCalculatorProps {
  className?: string;
  currencySymbol?: string;
}

export const TipCalculator: React.FC<TipCalculatorProps> = ({
  className = '',
  currencySymbol = '₹',
}) => {
  const { currentTheme } = useTheme();

  const [bill, setBill] = useState<number>(2400);
  const [tipPercent, setTipPercent] = useState<number>(10);
  const [people, setPeople] = useState<number>(4);
  const [roundUp, setRoundUp] = useState<boolean>(false);

  const formatMoney = (val: number): string => {
    return Math.round(val).toLocaleString('en-IN');
  };

  const result = useMemo(() => {
    return FinanceEngine.calculateTip(bill, tipPercent, people, roundUp);
  }, [bill, tipPercent, people, roundUp]);

  // Ratio Bar Percentages
  const total = result.billTotal;
  const basePercent = total > 0
    ? Math.min(100, Math.max(0, Math.round(((total - result.tipTotal) / total) * 100)))
    : 0;
  const tipRatioPercent = Math.max(0, 100 - basePercent);

  const tipPresets = [5, 10, 12, 15, 18, 20];
  const peoplePresets = [1, 2, 3, 4, 5, 6, 8];

  return (
    <div className={`w-full max-w-3xl mx-auto flex flex-col gap-6 select-none ${className}`}>
      {/* =========================================================================
          INPUTS SECTION (Dark card style matching SWP)
         ========================================================================= */}
      <div className="flex flex-col gap-4">
        {/* 1. Bill Subtotal */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Bill Subtotal
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="50"
              value={Number.isNaN(bill) ? '' : bill}
              onChange={(e) => setBill(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="2,400"
            />
          </div>
        </div>

        {/* 2. Tip Percentage */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Tip Percentage
            </label>
            <span className="text-xs font-semibold" style={{ color: currentTheme.accent }}>
              {tipPercent}%
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="0"
              max="100"
              step="1"
              value={Number.isNaN(tipPercent) ? '' : tipPercent}
              onChange={(e) => setTipPercent(Math.max(0, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="10"
            />
            <span className="text-xl font-light text-zinc-400">%</span>
          </div>

          {/* Tip Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t border-zinc-800/60">
            {tipPresets.map((pct) => {
              const isActive = tipPercent === pct;
              return (
                <button
                  key={pct}
                  type="button"
                  onClick={() => setTipPercent(pct)}
                  className={`px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer ${
                    isActive
                      ? 'bg-zinc-800 text-white border border-zinc-600 shadow-sm'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/60 border border-zinc-800'
                  }`}
                  style={
                    isActive
                      ? { borderColor: currentTheme.accent, color: currentTheme.accent }
                      : {}
                  }
                >
                  {pct}%
                </button>
              );
            })}
          </div>
        </div>

        {/* 3. Split with People */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Split with (People)
            </label>
            <span className="text-xs font-mono text-zinc-400">
              {people} {people === 1 ? 'Person' : 'People'}
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="1"
              max="50"
              step="1"
              value={Number.isNaN(people) ? '' : people}
              onChange={(e) => setPeople(Math.max(1, parseInt(e.target.value) || 1))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="4"
            />
            <span className="text-xl font-light text-zinc-400">Ppl</span>
          </div>

          {/* People Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t border-zinc-800/60">
            {peoplePresets.map((num) => {
              const isActive = people === num;
              return (
                <button
                  key={num}
                  type="button"
                  onClick={() => setPeople(num)}
                  className={`px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer ${
                    isActive
                      ? 'bg-zinc-800 text-white border border-zinc-600 shadow-sm'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/60 border border-zinc-800'
                  }`}
                  style={
                    isActive
                      ? { borderColor: currentTheme.accent, color: currentTheme.accent }
                      : {}
                  }
                >
                  {num} {num === 1 ? 'Person' : 'Ppl'}
                </button>
              );
            })}
          </div>
        </div>

        {/* 4. Round Up Checkbox */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 flex items-center justify-between">
          <label className="flex items-center gap-2.5 cursor-pointer text-xs font-medium text-zinc-300">
            <input
              type="checkbox"
              checked={roundUp}
              onChange={(e) => setRoundUp(e.target.checked)}
              className="w-4 h-4 rounded accent-emerald-500 cursor-pointer"
            />
            <span>Round up total per person to nearest whole number</span>
          </label>
        </div>
      </div>

      {/* =========================================================================
          RESULTS CARD (bg-zinc-950/80, rounded-3xl, corner glow, ratio bar, etc.)
         ========================================================================= */}
      <div className="relative bg-zinc-950/80 rounded-3xl p-5 sm:p-6 border border-zinc-800/90 shadow-2xl overflow-hidden backdrop-blur-xl">
        {/* Subtle Ambient Corner Glow */}
        <div
          className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
          style={{ backgroundColor: currentTheme.accent }}
        />

        {/* Per Person Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase mb-1">
            Per Person Share
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-1">
            <span className="text-2xl sm:text-3xl text-zinc-400 font-normal">{currencySymbol}</span>
            <span>{formatMoney(result.perPersonTotal)}</span>
            <span className="text-sm font-normal text-zinc-500 font-sans ml-1">/ each</span>
          </div>
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div className="w-full h-3 rounded-full bg-zinc-800 overflow-hidden flex">
            {/* Base Bill Share (Grey) */}
            <div
              className="h-full bg-zinc-500 transition-all duration-500"
              style={{ width: `${basePercent}%` }}
              title={`Base Bill: ${basePercent}%`}
            />
            {/* Tip Share (Accent) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${tipRatioPercent}%`,
                backgroundColor: currentTheme.accent,
              }}
              title={`Tip: ${tipRatioPercent}%`}
            />
          </div>

          {/* Ratio Legend & Percentages */}
          <div className="flex items-center justify-between text-xs pt-1">
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-zinc-500 shrink-0" />
              <span className="text-zinc-400">Base Food/Service:</span>
              <span className="font-mono font-semibold text-zinc-200">
                {basePercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span className="text-zinc-400">Tip:</span>
              <span
                className="font-mono font-semibold"
                style={{ color: currentTheme.accent }}
              >
                {tipRatioPercent}%
              </span>
            </div>
          </div>
        </div>

        {/* Two-Metric Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          {/* Tile 1: Total Bill + Tip (Neutral) */}
          <div className="bg-zinc-900/60 rounded-2xl p-4 border border-zinc-800/60 flex flex-col justify-between">
            <span className="text-xs font-medium text-zinc-400 mb-1">
              Total Bill (incl. Tip)
            </span>
            <div className="text-xl sm:text-2xl font-light text-zinc-200 font-mono">
              {currencySymbol}{formatMoney(result.billTotal)}
            </div>
          </div>

          {/* Tile 2: Total Tip (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, 0.08)`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.25)`,
            }}
          >
            <span className="text-xs font-medium text-zinc-300 mb-1">
              Total Tip Amount
            </span>
            <div
              className="text-xl sm:text-2xl font-light font-mono"
              style={{ color: currentTheme.accent }}
            >
              +{currencySymbol}{formatMoney(result.tipTotal)}
            </div>
          </div>
        </div>

        {/* Person Breakdown Details */}
        <div className="pt-3 border-t border-zinc-800/80 flex items-center justify-between text-xs font-mono text-zinc-400">
          <span>Base per person: {currencySymbol}{formatMoney(result.perPersonBase)}</span>
          <span>Tip per person: {currencySymbol}{formatMoney(result.perPersonTip)}</span>
        </div>
      </div>
    </div>
  );
};
