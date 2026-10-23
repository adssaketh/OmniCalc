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
    <div className={`w-full max-w-5xl xl:max-w-6xl mx-auto select-none ${className}`}>
      <div className="grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start">
        {/* =========================================================================
            INPUTS SECTION (md:col-span-6)
           ========================================================================= */}
        <div className="md:col-span-6 flex flex-col gap-4">
        {/* 1. Bill Subtotal */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Bill Subtotal
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="50"
              value={Number.isNaN(bill) ? '' : bill}
              onChange={(e) => setBill(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="2,400"
            />
          </div>
        </div>

        {/* 2. Tip Percentage */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="10"
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>%</span>
          </div>

          {/* Tip Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {tipPresets.map((pct) => {
              const isActive = tipPercent === pct;
              return (
                <button
                  key={pct}
                  type="button"
                  onClick={() => setTipPercent(pct)}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {pct}%
                </button>
              );
            })}
          </div>
        </div>

        {/* 3. Split with People */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Split with (People)
            </label>
            <span className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="4"
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>Ppl</span>
          </div>

          {/* People Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {peoplePresets.map((num) => {
              const isActive = people === num;
              return (
                <button
                  key={num}
                  type="button"
                  onClick={() => setPeople(num)}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {num} {num === 1 ? 'Person' : 'Ppl'}
                </button>
              );
            })}
          </div>
        </div>

        {/* 4. Round Up Checkbox */}
        <div
          className="rounded-2xl p-4 flex items-center justify-between transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="flex items-center gap-2.5 cursor-pointer text-xs font-medium" style={{ color: 'var(--m3-on-surface)' }}>
            <input
              type="checkbox"
              checked={roundUp}
              onChange={(e) => setRoundUp(e.target.checked)}
              className="w-4 h-4 rounded cursor-pointer"
              style={{ accentColor: currentTheme.accent }}
            />
            <span>Round up total per person to nearest whole number</span>
          </label>
        </div>
      </div>

      {/* =========================================================================
          RESULTS CARD (md:col-span-6 sticky on tablet)
         ========================================================================= */}
      <div className="md:col-span-6 flex flex-col gap-4 sticky md:top-4">
        <div
          className="relative rounded-3xl p-5 sm:p-6 overflow-hidden transition-colors"
          style={{
            backgroundColor: 'var(--m3-surface-container)',
            color: 'var(--m3-on-surface)',
          }}
        >
        {/* Per Person Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider uppercase mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Per Person Share
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1" style={{ color: 'var(--m3-on-surface)' }}>
            <span className="text-2xl sm:text-3xl font-normal" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <span>{formatMoney(result.perPersonTotal)}</span>
            <span className="text-sm font-normal font-sans ml-1" style={{ color: 'var(--m3-on-surface-variant)' }}>/ each</span>
          </div>
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div
            className="w-full h-3 rounded-full overflow-hidden flex"
            style={{ backgroundColor: 'var(--m3-surface-container-highest)' }}
          >
            {/* Base Bill Share (Neutral M3) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${basePercent}%`,
                backgroundColor: 'var(--m3-outline)',
              }}
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
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: 'var(--m3-outline)' }} />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Base Food/Service:</span>
              <span className="font-mono font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
                {basePercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Tip:</span>
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
          <div
            className="rounded-2xl p-4 flex flex-col justify-between"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Total Bill (incl. Tip)
            </span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: 'var(--m3-on-surface)' }}>
              {currencySymbol}{formatMoney(result.billTotal)}
            </div>
          </div>

          {/* Tile 2: Total Tip (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, ${currentTheme.isDark ? '0.12' : '0.10'})`,
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
        <div className="pt-3 border-t flex items-center justify-between text-xs font-mono" style={{ borderColor: 'var(--m3-outline-variant)', color: 'var(--m3-on-surface-variant)' }}>
          <span>Base per person: {currencySymbol}{formatMoney(result.perPersonBase)}</span>
          <span>Tip per person: {currencySymbol}{formatMoney(result.perPersonTip)}</span>
        </div>
        </div>
      </div>
    </div>
  </div>
);
};
