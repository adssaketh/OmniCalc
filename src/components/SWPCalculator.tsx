import React, { useState, useMemo } from 'react';
import { calculateSWP } from '../services/swp';
import { useTheme } from '../hooks/useTheme';
import { ChevronDown, ChevronUp, AlertTriangle } from 'lucide-react';

interface SWPCalculatorProps {
  className?: string;
}

export const SWPCalculator: React.FC<SWPCalculatorProps> = ({ className = '' }) => {
  const { currentTheme } = useTheme();

  // Inputs
  const [corpus, setCorpus] = useState<number>(1000000);
  const [monthlyWithdrawal, setMonthlyWithdrawal] = useState<number>(8000);
  const [rate, setRate] = useState<number>(8);
  const [years, setYears] = useState<number>(10);
  const [stepUp, setStepUp] = useState<number>(0);

  // Table collapse state
  const [isTimelineOpen, setIsTimelineOpen] = useState<boolean>(false);

  // Format Indian currency without decimals
  const formatINR = (val: number): string => {
    return Math.round(val).toLocaleString('en-IN');
  };

  // Perform calculation
  const result = useMemo(() => {
    return calculateSWP({
      corpus,
      monthlyWithdrawal,
      annualRate: rate,
      years,
      stepUp,
    });
  }, [corpus, monthlyWithdrawal, rate, years, stepUp]);

  // Withdrawal % of corpus per year
  const withdrawalPctPerYear = useMemo(() => {
    if (corpus > 0 && monthlyWithdrawal >= 0) {
      return ((monthlyWithdrawal * 12 / corpus) * 100).toFixed(1);
    }
    return null;
  }, [corpus, monthlyWithdrawal]);

  // Depletion timing string
  const depletionText = useMemo(() => {
    if (result.depletedMonth === null) return null;
    const months = result.depletedMonth - 1;
    const y = Math.floor(months / 12);
    const m = months % 12;

    let timeStr = '';
    if (y > 0 && m > 0) {
      timeStr = `${y} yr ${m} mo`;
    } else if (y > 0) {
      timeStr = `${y} yr`;
    } else {
      timeStr = `${m} mo`;
    }

    return `Your corpus runs out after about ${timeStr}. Lower the withdrawal or raise the return rate to last longer.`;
  }, [result.depletedMonth]);

  // Ratio Bar Percentages
  const totalPool = result.totalWithdrawn + result.finalBalance;
  const withdrawnPercent = totalPool > 0
    ? Math.min(100, Math.max(0, Math.round((result.totalWithdrawn / totalPool) * 100)))
    : 0;
  const remainingPercent = 100 - withdrawnPercent;

  // Rate presets
  const ratePresets = [
    { label: '6% Safe', value: 6 },
    { label: '8% Hybrid', value: 8 },
    { label: '10% Balanced', value: 10 },
    { label: '12% Equity', value: 12 },
  ];

  // Duration presets
  const yearPresets = [5, 10, 15, 20, 25, 30];

  return (
    <div className={`w-full max-w-5xl xl:max-w-6xl mx-auto select-none ${className}`}>
      <div className="grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start">
        {/* =========================================================================
            INPUTS SECTION (md:col-span-6)
           ========================================================================= */}
        <div className="md:col-span-6 flex flex-col gap-4">
        {/* 1. Total Investment (Corpus) */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Total Investment (Corpus)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>₹</span>
            <input
              type="number"
              min="0"
              step="10000"
              value={Number.isNaN(corpus) ? '' : corpus}
              onChange={(e) => setCorpus(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="10,00,000"
            />
          </div>
          {corpus > 0 && (
            <div className="text-xs font-mono mt-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              ₹{formatINR(corpus)}
            </div>
          )}
        </div>

        {/* 2. Withdrawal per Month */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Withdrawal per Month
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>₹</span>
            <input
              type="number"
              min="0"
              step="500"
              value={Number.isNaN(monthlyWithdrawal) ? '' : monthlyWithdrawal}
              onChange={(e) => setMonthlyWithdrawal(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="8,000"
            />
          </div>
          {withdrawalPctPerYear !== null && (
            <div className="text-xs mt-1.5 flex items-center gap-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              <span className="font-mono font-medium" style={{ color: 'var(--m3-on-surface)' }}>
                {withdrawalPctPerYear}%
              </span>
              <span>of corpus per year</span>
            </div>
          )}
        </div>

        {/* 3. Expected Annual Return Rate */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Expected Annual Return Rate
            </label>
            <span
              className="text-xs font-semibold"
              style={{ color: 'var(--m3-primary)' }}
            >
              {rate}% p.a.
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="0"
              max="50"
              step="0.5"
              value={Number.isNaN(rate) ? '' : rate}
              onChange={(e) => setRate(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="8"
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>%</span>
          </div>

          {/* Rate Preset Chips */}
          <div className="flex flex-wrap gap-2 pt-1 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {ratePresets.map((preset) => {
              const isActive = rate === preset.value;
              return (
                <button
                  key={preset.value}
                  type="button"
                  onClick={() => setRate(preset.value)}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {preset.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* 4. Withdrawal Period (Years) */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Withdrawal Period (Years)
            </label>
            <span className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
              {years} Years ({years * 12} Months)
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="1"
              max="60"
              step="1"
              value={Number.isNaN(years) ? '' : years}
              onChange={(e) => setYears(Math.max(1, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="10"
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>Yr</span>
          </div>

          {/* Duration Preset Chips */}
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

        {/* 5. Yearly Increase in Withdrawal (optional) */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Yearly Increase in Withdrawal (optional)
          </label>
          <div className="flex items-center gap-1.5">
            <input
              type="number"
              min="0"
              max="50"
              step="1"
              value={Number.isNaN(stepUp) ? '' : stepUp}
              onChange={(e) => setStepUp(Math.max(0, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="0"
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>%</span>
          </div>
          <div className="text-xs mt-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Annual step-up to counteract inflation
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
              backgroundColor: 'var(--m3-surface-container-low)',
            }}
          >
        {/* Final Balance Metric */}
        <div className="flex flex-col mb-5">
          <span
            className="text-[11px] font-semibold tracking-wider uppercase mb-1"
            style={{ color: 'var(--m3-on-surface-variant)' }}
          >
            Final Value After {years} Years
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1" style={{ color: 'var(--m3-on-surface)' }}>
            <span className="text-2xl sm:text-3xl font-normal" style={{ color: 'var(--m3-on-surface-variant)' }}>₹</span>
            <span>{formatINR(result.finalBalance)}</span>
          </div>
        </div>

        {/* Amber Depletion Warning Box */}
        {result.depletedMonth !== null && depletionText && (
          <div className="mb-5 p-3.5 rounded-2xl bg-amber-500/10 border-amber-500/30 flex items-start gap-2.5 text-amber-500">
            <AlertTriangle className="w-5 h-5 shrink-0 text-amber-500 mt-0.5" />
            <div className="text-xs sm:text-sm font-medium leading-relaxed">
              {depletionText}
            </div>
          </div>
        )}

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div
            className="w-full h-3 rounded-full overflow-hidden flex"
            style={{ backgroundColor: 'var(--m3-surface-container-highest)' }}
          >
            {/* Total Withdrawn Share (Grey/Outline) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${withdrawnPercent}%`,
                backgroundColor: 'var(--m3-outline)',
              }}
              title={`Total Withdrawn: ${withdrawnPercent}%`}
            />
            {/* Remaining Share (Primary) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${remainingPercent}%`,
                backgroundColor: 'var(--m3-primary)',
              }}
              title={`Remaining Corpus: ${remainingPercent}%`}
            />
          </div>

          {/* Ratio Legend & Percentages */}
          <div className="flex items-center justify-between text-xs pt-1">
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: 'var(--m3-outline)' }} />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Total Withdrawn:</span>
              <span className="font-mono font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
                {withdrawnPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: 'var(--m3-primary)' }}
              />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Remaining:</span>
              <span
                className="font-mono font-semibold"
                style={{ color: 'var(--m3-primary)' }}
              >
                {remainingPercent}%
              </span>
            </div>
          </div>
        </div>

        {/* Two-Metric Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          {/* Tile 1: Total Withdrawn (Neutral) */}
          <div
            className="rounded-2xl p-4 flex flex-col justify-between transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Total Withdrawn
            </span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: 'var(--m3-on-surface)' }}>
              ₹{formatINR(result.totalWithdrawn)}
            </div>
          </div>

          {/* Tile 2: Total Returns Earned (Primary Container) */}
          <div
            className="rounded-2xl p-4 flex flex-col justify-between transition-colors"
            style={{
              backgroundColor: 'var(--m3-primary-container)',
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-primary-container)' }}>
              Total Returns Earned
            </span>
            <div
              className="text-xl sm:text-2xl font-light font-mono font-bold"
              style={{ color: 'var(--m3-on-primary-container)' }}
            >
              {result.totalReturns >= 0 ? '+' : ''}₹{formatINR(result.totalReturns)}
            </div>
          </div>
        </div>

        {/* Small Grey Footnote */}
        <p className="text-[11px] leading-relaxed mb-5" style={{ color: 'var(--m3-on-surface-variant)' }}>
          Estimate only. Each month's withdrawal is taken at the start of the month, and the rest earns the monthly rate (annual rate ÷ 12). Taxes, exit loads and market swings are not included.
        </p>

        {/* Collapsible Year-by-Year Withdrawal Timeline */}
        {result.yearlyRows.length > 0 && (
          <div className="pt-3 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            <button
              type="button"
              onClick={() => setIsTimelineOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold transition-colors cursor-pointer"
              style={{ color: 'var(--m3-on-surface)' }}
            >
              <span>Year-by-Year Withdrawal Timeline</span>
              {isTimelineOpen ? (
                <ChevronUp className="w-4 h-4" style={{ color: 'var(--m3-on-surface-variant)' }} />
              ) : (
                <ChevronDown className="w-4 h-4" style={{ color: 'var(--m3-on-surface-variant)' }} />
              )}
            </button>

            {isTimelineOpen && (
              <div className="mt-3 overflow-x-auto no-scrollbar animate-fadeIn">
                <table className="w-full text-left text-xs font-mono">
                  <thead>
                    <tr className="border-b" style={{ borderColor: 'var(--m3-outline-variant)', color: 'var(--m3-on-surface-variant)' }}>
                      <th className="py-2 px-2.5 font-semibold">Year</th>
                      <th className="py-2 px-2.5 font-semibold">Withdrawn</th>
                      <th className="py-2 px-2.5 font-semibold">Returns</th>
                      <th className="py-2 px-2.5 font-semibold text-right">Balance</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y" style={{ borderColor: 'var(--m3-outline-variant)', color: 'var(--m3-on-surface)' }}>
                    {result.yearlyRows.map((row) => (
                      <tr key={row.year} className="hover:opacity-80 transition-opacity">
                        <td className="py-2 px-2.5" style={{ color: 'var(--m3-on-surface-variant)' }}>Yr {row.year}</td>
                        <td className="py-2 px-2.5" style={{ color: 'var(--m3-on-surface)' }}>₹{formatINR(row.withdrawn)}</td>
                        <td className="py-2 px-2.5" style={{ color: currentTheme.isDark ? '#34d399' : '#047857' }}>
                          +{formatINR(row.returns)}
                        </td>
                        <td className="py-2 px-2.5 text-right font-medium" style={{ color: 'var(--m3-on-surface)' }}>
                          ₹{formatINR(row.balance)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  </div>
</div>
  );
};
