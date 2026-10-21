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
    <div className={`w-full max-w-5xl xl:max-w-6xl mx-auto select-none ${className}`}>
      <div className="grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start">
        {/* =========================================================================
            INPUTS SECTION (md:col-span-6)
           ========================================================================= */}
        <div className="md:col-span-6 flex flex-col gap-4">
        {/* 1. Monthly SIP Amount */}
        <div
          className="rounded-2xl border p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
            borderColor: 'var(--m3-outline-variant)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Monthly SIP Amount
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="500"
              value={Number.isNaN(monthlySIP) ? '' : monthlySIP}
              onChange={(e) => setMonthlySIP(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="5,000"
            />
          </div>
          {monthlySIP > 0 && (
            <div className="text-xs font-mono mt-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              {currencySymbol}{formatMoney(monthlySIP)} / month
            </div>
          )}

          {/* SIP Presets */}
          <div className="flex flex-wrap gap-2 pt-2.5 mt-2 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {sipPresets.map((p) => {
              const isActive = monthlySIP === p.value;
              return (
                <button
                  key={p.value}
                  type="button"
                  onClick={() => setMonthlySIP(p.value)}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl border transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    borderColor: isActive ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {p.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* 2. Initial Lump Sum (Optional) */}
        <div
          className="rounded-2xl border p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
            borderColor: 'var(--m3-outline-variant)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Initial Lump Sum (Optional Deposit)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="5000"
              value={Number.isNaN(initialDeposit) ? '' : initialDeposit}
              onChange={(e) => setInitialDeposit(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="50,000"
            />
          </div>
          {initialDeposit > 0 && (
            <div className="text-xs font-mono mt-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Starting corpus: {currencySymbol}{formatMoney(initialDeposit)}
            </div>
          )}
        </div>

        {/* 3. Expected Annual Return Rate */}
        <div
          className="rounded-2xl border p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
            borderColor: 'var(--m3-outline-variant)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="12"
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
                  className="px-3 py-1.5 text-xs font-medium rounded-xl border transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    borderColor: isActive ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
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

        {/* 4. Duration (Years) */}
        <div
          className="rounded-2xl border p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
            borderColor: 'var(--m3-outline-variant)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Investment Horizon (Years)
            </label>
            <span className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
                  className="px-3 py-1.5 text-xs font-medium rounded-xl border transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    borderColor: isActive ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
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

        {/* 5. Annual Step-Up */}
        <div
          className="rounded-2xl border p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
            borderColor: 'var(--m3-outline-variant)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Annual Step-Up (% / year)
            </label>
            <span className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="10"
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>%</span>
          </div>

          {/* Step-up Presets */}
          <div className="flex flex-wrap gap-2 pt-1 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {stepUpPresets.map((pct) => {
              const isActive = stepUp === pct;
              return (
                <button
                  key={pct}
                  type="button"
                  onClick={() => setStepUp(pct)}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl border transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    borderColor: isActive ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {pct === 0 ? 'No Step-Up' : `+${pct}% / yr`}
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
          className="relative rounded-3xl p-5 sm:p-6 border shadow-2xl overflow-hidden backdrop-blur-xl transition-colors"
          style={{
            backgroundColor: 'var(--m3-surface-container)',
            borderColor: 'var(--m3-outline-variant)',
            color: 'var(--m3-on-surface)',
          }}
        >
        {/* Subtle Ambient Corner Glow */}
        <div
          className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
          style={{ backgroundColor: currentTheme.accent }}
        />

        {/* Final Corpus Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider uppercase mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Total Expected Wealth After {years} Years
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1" style={{ color: 'var(--m3-on-surface)' }}>
            <span className="text-2xl sm:text-3xl font-normal" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <span>{formatMoney(result.endBalance)}</span>
          </div>
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div
            className="w-full h-3 rounded-full overflow-hidden flex"
            style={{ backgroundColor: 'var(--m3-surface-container-highest)' }}
          >
            {/* Total Invested Share (Neutral M3) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${investedPercent}%`,
                backgroundColor: 'var(--m3-outline)',
              }}
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
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: 'var(--m3-outline)' }} />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Amount Invested:</span>
              <span className="font-mono font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
                {investedPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Wealth Gain:</span>
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
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Total Amount Invested
            </span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: 'var(--m3-on-surface)' }}>
              {currencySymbol}{formatMoney(result.totalInvested)}
            </div>
          </div>

          {/* Tile 2: Total Returns / Interest Earned (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, ${currentTheme.isDark ? '0.12' : '0.10'})`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.28)`,
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
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

        {/* Small Footnote */}
        <p className="text-[11px] leading-relaxed mb-5" style={{ color: 'var(--m3-on-surface-variant)' }}>
          Estimate only. Assumes regular monthly compounding with annual step-up. Mutual fund investments are subject to market risks; past performance does not guarantee future results.
        </p>

        {/* Collapsible Year-by-Year Growth Timeline */}
        {result.yearlyBreakdown.length > 0 && (
          <div className="pt-3 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            <button
              type="button"
              onClick={() => setIsTimelineOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold transition-colors cursor-pointer"
              style={{ color: 'var(--m3-on-surface-variant)' }}
            >
              <span>Year-by-Year Wealth Progression</span>
              {isTimelineOpen ? (
                <ChevronUp className="w-4 h-4" />
              ) : (
                <ChevronDown className="w-4 h-4" />
              )}
            </button>

            {isTimelineOpen && (
              <div className="mt-3 overflow-x-auto scrollbar-none animate-fadeIn">
                <table className="w-full text-left text-xs font-mono">
                  <thead>
                    <tr className="border-b" style={{ borderColor: 'var(--m3-outline-variant)', color: 'var(--m3-on-surface-variant)' }}>
                      <th className="py-2 px-2.5 font-semibold">Year</th>
                      <th className="py-2 px-2.5 font-semibold">Monthly SIP</th>
                      <th className="py-2 px-2.5 font-semibold">Invested</th>
                      <th className="py-2 px-2.5 font-semibold">Growth</th>
                      <th className="py-2 px-2.5 font-semibold text-right">Corpus</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y" style={{ borderColor: 'var(--m3-outline-variant)' }}>
                    {result.yearlyBreakdown.map((row) => (
                      <tr key={row.year} className="transition-colors hover:opacity-90">
                        <td className="py-2 px-2.5" style={{ color: 'var(--m3-on-surface-variant)' }}>Yr {row.year}</td>
                        <td className="py-2 px-2.5" style={{ color: 'var(--m3-on-surface)' }}>
                          {row.year === 0 ? '-' : `${currencySymbol}${formatMoney(row.monthlyContribution)}/m`}
                        </td>
                        <td className="py-2 px-2.5" style={{ color: 'var(--m3-on-surface)' }}>{currencySymbol}{formatMoney(row.deposits)}</td>
                        <td className="py-2 px-2.5 font-medium" style={{ color: currentTheme.isDark ? '#34d399' : '#047857' }}>
                          +{currencySymbol}{formatMoney(row.interestAccrued)}
                        </td>
                        <td className="py-2 px-2.5 text-right font-medium" style={{ color: 'var(--m3-on-surface)' }}>
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
    </div>
  </div>
);
};
