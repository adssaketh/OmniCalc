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
    <div className={`w-full max-w-5xl xl:max-w-6xl mx-auto select-none ${className}`}>
      <div className="grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start">
        {/* =========================================================================
            INPUTS SECTION (md:col-span-6)
           ========================================================================= */}
        <div className="md:col-span-6 flex flex-col gap-4">
        {/* 1. Initial Capital */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Initial Investment (Principal Capital)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="10000"
              value={Number.isNaN(initialCapital) ? '' : initialCapital}
              onChange={(e) => setInitialCapital(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="2,00,000"
            />
          </div>
          {initialCapital > 0 && (
            <div className="text-xs font-mono mt-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              {currencySymbol}{formatMoney(initialCapital)}
            </div>
          )}
        </div>

        {/* 2. Final Value */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Final Investment Value (or Current Net Worth)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="10000"
              value={Number.isNaN(finalValue) ? '' : finalValue}
              onChange={(e) => setFinalValue(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="5,50,000"
            />
          </div>
          {finalValue > 0 && (
            <div className="text-xs font-mono mt-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              {currencySymbol}{formatMoney(finalValue)}
            </div>
          )}
        </div>

        {/* 3. Investment Period (Years) */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Holding Period (Years)
            </label>
            <span className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="5"
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>Yr</span>
          </div>

          {/* Year Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {yearPresets.map((y) => {
              const isActive = years === y;
              return (
                <button
                  key={y}
                  type="button"
                  onClick={() => setYears(y)}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {y}Y
                </button>
              );
            })}
          </div>
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
        {/* Annualized CAGR Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider uppercase mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Annualized Compounded Growth (CAGR)
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1" style={{ color: 'var(--m3-on-surface)' }}>
            <span style={{ color: currentTheme.accent }}>
              {result.cagrPercent.toFixed(2)}%
            </span>
            <span className="text-base sm:text-lg font-normal font-sans ml-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
              per year
            </span>
          </div>
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div
            className="w-full h-3 rounded-full overflow-hidden flex"
            style={{ backgroundColor: 'var(--m3-surface-container-highest)' }}
          >
            {/* Capital Share (Neutral M3) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${capitalPercent}%`,
                backgroundColor: 'var(--m3-outline)',
              }}
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
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: 'var(--m3-outline)' }} />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Principal Capital:</span>
              <span className="font-mono font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
                {capitalPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Net Return:</span>
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
          <div
            className="rounded-2xl p-4 flex flex-col justify-between"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Total Absolute ROI
            </span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: 'var(--m3-on-surface)' }}>
              {result.roiPercent >= 0 ? '+' : ''}{result.roiPercent.toFixed(2)}%
            </div>
          </div>

          {/* Tile 2: Absolute Gain / Profit (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, ${currentTheme.isDark ? '0.12' : '0.10'})`,
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
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

        {/* Small Footnote */}
        <p className="text-[11px] leading-relaxed" style={{ color: 'var(--m3-on-surface-variant)' }}>
          Compound Annual Growth Rate (CAGR) measures the geometric progression ratio over multi-year holding periods. Absolute ROI represents aggregate capital growth.
        </p>
        </div>
      </div>
    </div>
  </div>
);
};
