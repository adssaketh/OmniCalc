import React, { useState, useMemo } from 'react';
import { FinanceEngine } from '../engine/finance';
import { useTheme } from '../hooks/useTheme';
import { ChevronDown, ChevronUp } from 'lucide-react';

interface CompoundCalculatorProps {
  className?: string;
  currencySymbol?: string;
}

export const CompoundCalculator: React.FC<CompoundCalculatorProps> = ({
  className = '',
  currencySymbol = '₹',
}) => {
  const { currentTheme } = useTheme();

  // Inputs: monthly SIP, initial deposit, rate, years, stepUp
  const [monthlySIP, setMonthlySIP] = useState<number>(5000);
  const [initialDeposit, setInitialDeposit] = useState<number>(50000);
  const [rate, setRate] = useState<number>(12);
  const [years, setYears] = useState<number>(10);
  const [stepUp, setStepUp] = useState<number>(10);

  // Table collapse
  const [isTimelineOpen, setIsTimelineOpen] = useState<boolean>(false);

  // Indian number formatting
  const formatMoney = (val: number): string => {
    return Math.round(val).toLocaleString('en-IN');
  };

  const result = useMemo(() => {
    return FinanceEngine.calculateCompoundInterest(
      initialDeposit,
      monthlySIP,
      rate,
      years,
      stepUp
    );
  }, [initialDeposit, monthlySIP, rate, years, stepUp]);

  // Ratio Bar Percentages
  const totalWealth = result.endBalance;
  const investedPercent = totalWealth > 0
    ? Math.min(100, Math.max(0, Math.round((result.totalInvested / totalWealth) * 100)))
    : 0;
  const gainsPercent = Math.max(0, 100 - investedPercent);

  // Presets
  const sipPresets = [
    { label: '₹2,000', value: 2000 },
    { label: '₹5,000', value: 5000 },
    { label: '₹10,000', value: 10000 },
    { label: '₹25,000', value: 25000 },
  ];

  const ratePresets = [
    { label: '8% Debt', value: 8 },
    { label: '10% Balanced', value: 10 },
    { label: '12% Equity', value: 12 },
    { label: '15% Aggressive', value: 15 },
  ];

  const yearPresets = [5, 10, 15, 20, 25, 30];
  const stepUpPresets = [0, 5, 10, 15, 20];

  return (
    <div className={`w-full max-w-3xl mx-auto flex flex-col gap-6 select-none ${className}`}>
      {/* =========================================================================
          INPUTS SECTION (Dark card style matching SWP)
         ========================================================================= */}
      <div className="flex flex-col gap-4">
        {/* 1. Monthly SIP Amount */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Monthly SIP Amount
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="500"
              value={Number.isNaN(monthlySIP) ? '' : monthlySIP}
              onChange={(e) => setMonthlySIP(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="5,000"
            />
          </div>
          {monthlySIP > 0 && (
            <div className="text-xs text-zinc-500 font-mono mt-1">
              {currencySymbol}{formatMoney(monthlySIP)} / month
            </div>
          )}

          {/* SIP Presets */}
          <div className="flex flex-wrap gap-2 pt-2.5 mt-2 border-t border-zinc-800/60">
            {sipPresets.map((p) => {
              const isActive = monthlySIP === p.value;
              return (
                <button
                  key={p.value}
                  type="button"
                  onClick={() => setMonthlySIP(p.value)}
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
                  {p.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* 2. Initial Lump Sum (Optional) */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Initial Lump Sum (Optional Deposit)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="5000"
              value={Number.isNaN(initialDeposit) ? '' : initialDeposit}
              onChange={(e) => setInitialDeposit(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="50,000"
            />
          </div>
          {initialDeposit > 0 && (
            <div className="text-xs text-zinc-500 font-mono mt-1">
              Starting corpus: {currencySymbol}{formatMoney(initialDeposit)}
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
              placeholder="12"
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

        {/* 4. Duration (Years) */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Investment Horizon (Years)
            </label>
            <span className="text-xs font-mono text-zinc-400">
              {years} Years ({years * 12} Installments)
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="1"
              max="50"
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

        {/* 5. Annual Step-Up */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Annual Step-Up (% / year)
            </label>
            <span className="text-xs font-mono text-zinc-400">
              {stepUp > 0 ? `+${stepUp}% every year` : 'Flat SIP'}
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="0"
              max="50"
              step="1"
              value={Number.isNaN(stepUp) ? '' : stepUp}
              onChange={(e) => setStepUp(Math.max(0, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="10"
            />
            <span className="text-xl font-light text-zinc-400">%</span>
          </div>

          {/* Step-up Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t border-zinc-800/60">
            {stepUpPresets.map((pct) => {
              const isActive = stepUp === pct;
              return (
                <button
                  key={pct}
                  type="button"
                  onClick={() => setStepUp(pct)}
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
                  {pct === 0 ? 'No Step-Up' : `+${pct}% / yr`}
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

        {/* Final Corpus Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase mb-1">
            Total Expected Wealth After {years} Years
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-1">
            <span className="text-2xl sm:text-3xl text-zinc-400 font-normal">{currencySymbol}</span>
            <span>{formatMoney(result.endBalance)}</span>
          </div>
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div className="w-full h-3 rounded-full bg-zinc-800 overflow-hidden flex">
            {/* Total Invested Share (Grey) */}
            <div
              className="h-full bg-zinc-500 transition-all duration-500"
              style={{ width: `${investedPercent}%` }}
              title={`Total Invested: ${investedPercent}%`}
            />
            {/* Wealth Gain Share (Accent) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${gainsPercent}%`,
                backgroundColor: currentTheme.accent,
              }}
              title={`Wealth Gain: ${gainsPercent}%`}
            />
          </div>

          {/* Ratio Legend & Percentages */}
          <div className="flex items-center justify-between text-xs pt-1">
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-zinc-500 shrink-0" />
              <span className="text-zinc-400">Amount Invested:</span>
              <span className="font-mono font-semibold text-zinc-200">
                {investedPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span className="text-zinc-400">Wealth Gain:</span>
              <span
                className="font-mono font-semibold"
                style={{ color: currentTheme.accent }}
              >
                {gainsPercent}%
              </span>
            </div>
          </div>
        </div>

        {/* Two-Metric Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          {/* Tile 1: Total Invested (Neutral) */}
          <div className="bg-zinc-900/60 rounded-2xl p-4 border border-zinc-800/60 flex flex-col justify-between">
            <span className="text-xs font-medium text-zinc-400 mb-1">
              Total Amount Invested
            </span>
            <div className="text-xl sm:text-2xl font-light text-zinc-200 font-mono">
              {currencySymbol}{formatMoney(result.totalInvested)}
            </div>
          </div>

          {/* Tile 2: Total Returns / Interest Earned (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, 0.08)`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.25)`,
            }}
          >
            <span className="text-xs font-medium text-zinc-300 mb-1">
              Estimated Wealth Gain
            </span>
            <div
              className="text-xl sm:text-2xl font-light font-mono"
              style={{ color: currentTheme.accent }}
            >
              +{currencySymbol}{formatMoney(result.totalInterest)}
            </div>
          </div>
        </div>

        {/* Small Grey Footnote */}
        <p className="text-[11px] text-zinc-500 leading-relaxed mb-5">
          Estimate only. Assumes regular monthly compounding with annual step-up. Mutual fund investments are subject to market risks; past performance does not guarantee future results.
        </p>

        {/* Collapsible Year-by-Year Growth Timeline */}
        {result.yearlyBreakdown.length > 0 && (
          <div className="pt-3 border-t border-zinc-800/80">
            <button
              type="button"
              onClick={() => setIsTimelineOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
            >
              <span>Year-by-Year Wealth Progression</span>
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
                      <th className="py-2 px-2.5 font-semibold">Monthly SIP</th>
                      <th className="py-2 px-2.5 font-semibold">Invested</th>
                      <th className="py-2 px-2.5 font-semibold">Growth</th>
                      <th className="py-2 px-2.5 font-semibold text-right">Corpus</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-900/80 text-zinc-300">
                    {result.yearlyBreakdown.map((row) => (
                      <tr key={row.year} className="hover:bg-zinc-900/40">
                        <td className="py-2 px-2.5 text-zinc-400">Yr {row.year}</td>
                        <td className="py-2 px-2.5 text-zinc-300">
                          {row.year === 0 ? '-' : `${currencySymbol}${formatMoney(row.monthlyContribution)}/m`}
                        </td>
                        <td className="py-2 px-2.5 text-zinc-300">{currencySymbol}{formatMoney(row.deposits)}</td>
                        <td className="py-2 px-2.5 text-emerald-400">
                          +{currencySymbol}{formatMoney(row.interestAccrued)}
                        </td>
                        <td className="py-2 px-2.5 text-right font-medium text-white">
                          {currencySymbol}{formatMoney(row.balance)}
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
