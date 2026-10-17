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
    <div className={`w-full max-w-3xl mx-auto flex flex-col gap-6 select-none ${className}`}>
      {/* =========================================================================
          INPUTS SECTION (Dark card style matching InvestmentCalculator)
         ========================================================================= */}
      <div className="flex flex-col gap-4">
        {/* 1. Total Investment (Corpus) */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Total Investment (Corpus)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">₹</span>
            <input
              type="number"
              min="0"
              step="10000"
              value={Number.isNaN(corpus) ? '' : corpus}
              onChange={(e) => setCorpus(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="10,00,000"
            />
          </div>
          {corpus > 0 && (
            <div className="text-xs text-zinc-500 font-mono mt-1">
              ₹{formatINR(corpus)}
            </div>
          )}
        </div>

        {/* 2. Withdrawal per Month */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Withdrawal per Month
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">₹</span>
            <input
              type="number"
              min="0"
              step="500"
              value={Number.isNaN(monthlyWithdrawal) ? '' : monthlyWithdrawal}
              onChange={(e) => setMonthlyWithdrawal(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="8,000"
            />
          </div>
          {withdrawalPctPerYear !== null && (
            <div className="text-xs text-zinc-400 mt-1.5 flex items-center gap-1">
              <span className="font-mono font-medium text-zinc-300">
                {withdrawalPctPerYear}%
              </span>
              <span>of corpus per year</span>
            </div>
          )}
        </div>

        {/* 3. Expected Annual Return Rate */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Expected Annual Return Rate
            </label>
            <span
              className="text-xs font-semibold"
              style={{ color: currentTheme.accent }}
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="8"
            />
            <span className="text-xl font-light text-zinc-400">%</span>
          </div>

          {/* Rate Preset Chips */}
          <div className="flex flex-wrap gap-2 pt-1 border-t border-zinc-800/60">
            {ratePresets.map((preset) => {
              const isActive = rate === preset.value;
              return (
                <button
                  key={preset.value}
                  type="button"
                  onClick={() => setRate(preset.value)}
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
                  {preset.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* 4. Withdrawal Period (Years) */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Withdrawal Period (Years)
            </label>
            <span className="text-xs font-mono text-zinc-400">
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="10"
            />
            <span className="text-xl font-light text-zinc-400">Yr</span>
          </div>

          {/* Duration Preset Chips */}
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

        {/* 5. Yearly Increase in Withdrawal (optional) */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="0"
            />
            <span className="text-xl font-light text-zinc-400">%</span>
          </div>
          <div className="text-xs text-zinc-500 mt-1">
            Annual step-up to counteract inflation
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

        {/* Final Balance Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase mb-1">
            Final Value After {years} Years
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-1">
            <span className="text-2xl sm:text-3xl text-zinc-400 font-normal">₹</span>
            <span>{formatINR(result.finalBalance)}</span>
          </div>
        </div>

        {/* Amber Depletion Warning Box */}
        {result.depletedMonth !== null && depletionText && (
          <div className="mb-5 p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-start gap-2.5 text-amber-300">
            <AlertTriangle className="w-5 h-5 shrink-0 text-amber-400 mt-0.5" />
            <div className="text-xs sm:text-sm font-medium leading-relaxed">
              {depletionText}
            </div>
          </div>
        )}

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div className="w-full h-3 rounded-full bg-zinc-800 overflow-hidden flex">
            {/* Total Withdrawn Share (Grey) */}
            <div
              className="h-full bg-zinc-500 transition-all duration-500"
              style={{ width: `${withdrawnPercent}%` }}
              title={`Total Withdrawn: ${withdrawnPercent}%`}
            />
            {/* Remaining Share (Accent) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${remainingPercent}%`,
                backgroundColor: currentTheme.accent,
              }}
              title={`Remaining Corpus: ${remainingPercent}%`}
            />
          </div>

          {/* Ratio Legend & Percentages */}
          <div className="flex items-center justify-between text-xs pt-1">
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-zinc-500 shrink-0" />
              <span className="text-zinc-400">Total Withdrawn:</span>
              <span className="font-mono font-semibold text-zinc-200">
                {withdrawnPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span className="text-zinc-400">Remaining:</span>
              <span
                className="font-mono font-semibold"
                style={{ color: currentTheme.accent }}
              >
                {remainingPercent}%
              </span>
            </div>
          </div>
        </div>

        {/* Two-Metric Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          {/* Tile 1: Total Withdrawn (Neutral) */}
          <div className="bg-zinc-900/60 rounded-2xl p-4 border border-zinc-800/60 flex flex-col justify-between">
            <span className="text-xs font-medium text-zinc-400 mb-1">
              Total Withdrawn
            </span>
            <div className="text-xl sm:text-2xl font-light text-zinc-200 font-mono">
              ₹{formatINR(result.totalWithdrawn)}
            </div>
          </div>

          {/* Tile 2: Total Returns Earned (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, 0.08)`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.25)`,
            }}
          >
            <span className="text-xs font-medium text-zinc-300 mb-1">
              Total Returns Earned
            </span>
            <div
              className="text-xl sm:text-2xl font-light font-mono"
              style={{ color: currentTheme.accent }}
            >
              {result.totalReturns >= 0 ? '+' : ''}₹{formatINR(result.totalReturns)}
            </div>
          </div>
        </div>

        {/* Small Grey Footnote */}
        <p className="text-[11px] text-zinc-500 leading-relaxed mb-5">
          Estimate only. Each month's withdrawal is taken at the start of the month, and the rest earns the monthly rate (annual rate ÷ 12). Taxes, exit loads and market swings are not included.
        </p>

        {/* Collapsible Year-by-Year Withdrawal Timeline */}
        {result.yearlyRows.length > 0 && (
          <div className="pt-3 border-t border-zinc-800/80">
            <button
              type="button"
              onClick={() => setIsTimelineOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
            >
              <span>Year-by-Year Withdrawal Timeline</span>
              {isTimelineOpen ? (
                <ChevronUp className="w-4 h-4 text-zinc-400" />
              ) : (
                <ChevronDown className="w-4 h-4 text-zinc-400" />
              )}
            </button>

            {isTimelineOpen && (
              <div className="mt-3 overflow-x-auto scrollbar-none animate-fadeIn">
                <table className="w-full text-left text-xs font-mono">
                  <thead>
                    <tr className="border-b border-zinc-800 text-zinc-400">
                      <th className="py-2 px-2.5 font-semibold">Year</th>
                      <th className="py-2 px-2.5 font-semibold">Withdrawn</th>
                      <th className="py-2 px-2.5 font-semibold">Returns</th>
                      <th className="py-2 px-2.5 font-semibold text-right">Balance</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-900/80 text-zinc-300">
                    {result.yearlyRows.map((row) => (
                      <tr key={row.year} className="hover:bg-zinc-900/40">
                        <td className="py-2 px-2.5 text-zinc-400">Yr {row.year}</td>
                        <td className="py-2 px-2.5 text-zinc-300">₹{formatINR(row.withdrawn)}</td>
                        <td className="py-2 px-2.5 text-emerald-400">
                          +{formatINR(row.returns)}
                        </td>
                        <td className="py-2 px-2.5 text-right font-medium text-white">
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
  );
};
