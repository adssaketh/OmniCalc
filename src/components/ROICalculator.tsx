import React, { useState, useMemo } from 'react';
import { FinanceEngine } from '../engine/finance';
import { useTheme } from '../hooks/useTheme';

interface ROICalculatorProps {
  className?: string;
  currencySymbol?: string;
}

export const ROICalculator: React.FC<ROICalculatorProps> = ({
  className = '',
  currencySymbol = '₹',
}) => {
  const { currentTheme } = useTheme();

  const [initialCapital, setInitialCapital] = useState<number>(200000);
  const [finalValue, setFinalValue] = useState<number>(550000);
  const [years, setYears] = useState<number>(5);

  const formatMoney = (val: number): string => {
    return Math.round(val).toLocaleString('en-IN');
  };

  const result = useMemo(() => {
    return FinanceEngine.calculateROI(initialCapital, finalValue, years);
  }, [initialCapital, finalValue, years]);

  // Ratio Bar Percentages
  const pool = Math.max(initialCapital, finalValue);
  const capitalPercent = pool > 0
    ? Math.min(100, Math.max(0, Math.round((initialCapital / pool) * 100)))
    : 0;
  const gainPercent = 100 - capitalPercent;

  const yearPresets = [1, 2, 3, 5, 7, 10, 15];

  return (
    <div className={`w-full max-w-3xl mx-auto flex flex-col gap-6 select-none ${className}`}>
      {/* =========================================================================
          INPUTS SECTION (Dark card style matching SWP)
         ========================================================================= */}
      <div className="flex flex-col gap-4">
        {/* 1. Initial Capital */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Initial Investment (Principal Capital)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="10000"
              value={Number.isNaN(initialCapital) ? '' : initialCapital}
              onChange={(e) => setInitialCapital(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="2,00,000"
            />
          </div>
          {initialCapital > 0 && (
            <div className="text-xs text-zinc-500 font-mono mt-1">
              {currencySymbol}{formatMoney(initialCapital)}
            </div>
          )}
        </div>

        {/* 2. Final Value */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Final Investment Value (or Current Net Worth)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="10000"
              value={Number.isNaN(finalValue) ? '' : finalValue}
              onChange={(e) => setFinalValue(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="5,50,000"
            />
          </div>
          {finalValue > 0 && (
            <div className="text-xs text-zinc-500 font-mono mt-1">
              {currencySymbol}{formatMoney(finalValue)}
            </div>
          )}
        </div>

        {/* 3. Investment Period (Years) */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Holding Period (Years)
            </label>
            <span className="text-xs font-mono text-zinc-400">
              {years} Years
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="0.1"
              max="60"
              step="0.5"
              value={Number.isNaN(years) ? '' : years}
              onChange={(e) => setYears(Math.max(0.1, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="5"
            />
            <span className="text-xl font-light text-zinc-400">Yr</span>
          </div>

          {/* Year Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t border-zinc-800/60">
            {yearPresets.map((y) => {
              const isActive = years === y;
              return (
                <button
                  key={y}
                  type="button"
                  onClick={() => setYears(y)}
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
                  {y}Y
                </button>
              );
            })}
          </div>
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

        {/* Annualized CAGR Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase mb-1">
            Annualized Compounded Growth (CAGR)
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-1">
            <span style={{ color: currentTheme.accent }}>
              {result.cagrPercent.toFixed(2)}%
            </span>
            <span className="text-base sm:text-lg font-normal text-zinc-400 font-sans ml-1.5">
              per year
            </span>
          </div>
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div className="w-full h-3 rounded-full bg-zinc-800 overflow-hidden flex">
            {/* Capital Share (Grey) */}
            <div
              className="h-full bg-zinc-500 transition-all duration-500"
              style={{ width: `${capitalPercent}%` }}
              title={`Initial Capital: ${capitalPercent}%`}
            />
            {/* Profit Share (Accent) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${gainPercent}%`,
                backgroundColor: currentTheme.accent,
              }}
              title={`Gain / Profit: ${gainPercent}%`}
            />
          </div>

          {/* Ratio Legend & Percentages */}
          <div className="flex items-center justify-between text-xs pt-1">
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-zinc-500 shrink-0" />
              <span className="text-zinc-400">Principal Capital:</span>
              <span className="font-mono font-semibold text-zinc-200">
                {capitalPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span className="text-zinc-400">Net Return:</span>
              <span
                className="font-mono font-semibold"
                style={{ color: currentTheme.accent }}
              >
                {gainPercent}%
              </span>
            </div>
          </div>
        </div>

        {/* Two-Metric Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          {/* Tile 1: Total Simple ROI % (Neutral) */}
          <div className="bg-zinc-900/60 rounded-2xl p-4 border border-zinc-800/60 flex flex-col justify-between">
            <span className="text-xs font-medium text-zinc-400 mb-1">
              Total Absolute ROI
            </span>
            <div className="text-xl sm:text-2xl font-light text-zinc-200 font-mono">
              {result.roiPercent >= 0 ? '+' : ''}{result.roiPercent.toFixed(2)}%
            </div>
          </div>

          {/* Tile 2: Absolute Gain / Profit (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, 0.08)`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.25)`,
            }}
          >
            <span className="text-xs font-medium text-zinc-300 mb-1">
              Net Profit / Wealth Gain
            </span>
            <div
              className="text-xl sm:text-2xl font-light font-mono"
              style={{ color: currentTheme.accent }}
            >
              {result.gainLoss >= 0 ? '+' : ''}{currencySymbol}{formatMoney(result.gainLoss)}
            </div>
          </div>
        </div>

        {/* Small Grey Footnote */}
        <p className="text-[11px] text-zinc-500 leading-relaxed">
          Compound Annual Growth Rate (CAGR) measures the geometric progression ratio over multi-year holding periods. Absolute ROI represents aggregate capital growth.
        </p>
      </div>
    </div>
  );
};
