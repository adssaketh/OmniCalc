import React, { useState, useMemo } from 'react';
import { FinanceEngine, LoanCalculationOptions } from '../engine/finance';
import { useTheme } from '../hooks/useTheme';
import { ChevronDown, ChevronUp } from 'lucide-react';

interface LoanCalculatorProps {
  className?: string;
  currencySymbol?: string;
}

export const LoanCalculator: React.FC<LoanCalculatorProps> = ({
  className = '',
  currencySymbol = '₹',
}) => {
  const { currentTheme } = useTheme();

  // Inputs calibrated for Indian Home/Personal Loan
  const [principal, setPrincipal] = useState<number>(2500000);
  const [rate, setRate] = useState<number>(8.5);
  const [years, setYears] = useState<number>(15);

  // Optional Bank Charges & GST
  const [showTaxes, setShowTaxes] = useState<boolean>(false);
  const [applyGstOnInterest, setApplyGstOnInterest] = useState<boolean>(false);
  const [gstRateInterest, setGstRateInterest] = useState<number>(18);
  const [includeProcessingFee, setIncludeProcessingFee] = useState<boolean>(false);
  const [processingFeeType, setProcessingFeeType] = useState<'percent' | 'flat'>('percent');
  const [processingFeeValue, setProcessingFeeValue] = useState<number>(1.0);
  const [applyGstOnProcessingFee, setApplyGstOnProcessingFee] = useState<boolean>(true);
  const [gstRateProcessingFee, setGstRateProcessingFee] = useState<number>(18);

  // Collapsible Amortization Schedule
  const [isScheduleOpen, setIsScheduleOpen] = useState<boolean>(false);

  // Indian currency formatter
  const formatMoney = (val: number): string => {
    return Math.round(val).toLocaleString('en-IN');
  };

  const options: LoanCalculationOptions = useMemo(() => ({
    applyGstOnInterest,
    gstRateInterest,
    includeProcessingFee,
    processingFeeType,
    processingFeeValue,
    applyGstOnProcessingFee,
    gstRateProcessingFee,
  }), [
    applyGstOnInterest,
    gstRateInterest,
    includeProcessingFee,
    processingFeeType,
    processingFeeValue,
    applyGstOnProcessingFee,
    gstRateProcessingFee,
  ]);

  const result = useMemo(() => {
    return FinanceEngine.calculateLoan(principal, rate, years, options);
  }, [principal, rate, years, options]);

  // Ratio Bar Percentages
  const totalOutflow = result.grandTotalOutflow || result.totalPayment;
  const principalPercent = totalOutflow > 0
    ? Math.min(100, Math.max(0, Math.round((principal / totalOutflow) * 100)))
    : 0;
  const interestPercent = totalOutflow > 0
    ? Math.min(100, Math.max(0, Math.round((result.totalInterest / totalOutflow) * 100)))
    : 0;
  const taxesFeesPercent = Math.max(0, 100 - principalPercent - interestPercent);

  // Preset chips
  const principalPresets = [
    { label: '₹10 L', value: 1000000 },
    { label: '₹25 L', value: 2500000 },
    { label: '₹50 L', value: 5000000 },
    { label: '₹75 L', value: 7500000 },
    { label: '₹1 Cr', value: 10000000 },
  ];

  const ratePresets = [
    { label: '8.5% Home', value: 8.5 },
    { label: '9.5% Auto', value: 9.5 },
    { label: '12% Personal', value: 12 },
    { label: '14% Business', value: 14 },
  ];

  const yearPresets = [5, 10, 15, 20, 25, 30];

  return (
    <div className={`w-full max-w-3xl mx-auto flex flex-col gap-6 select-none ${className}`}>
      {/* =========================================================================
          INPUTS SECTION (Dark card style matching SWP & Investment)
         ========================================================================= */}
      <div className="flex flex-col gap-4">
        {/* 1. Loan Principal */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Loan Amount (Principal)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="50000"
              value={Number.isNaN(principal) ? '' : principal}
              onChange={(e) => setPrincipal(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="25,00,000"
            />
          </div>
          {principal > 0 && (
            <div className="text-xs text-zinc-500 font-mono mt-1">
              {currencySymbol}{formatMoney(principal)}
            </div>
          )}

          {/* Principal Presets */}
          <div className="flex flex-wrap gap-2 pt-2.5 mt-2 border-t border-zinc-800/60">
            {principalPresets.map((p) => {
              const isActive = principal === p.value;
              return (
                <button
                  key={p.value}
                  type="button"
                  onClick={() => setPrincipal(p.value)}
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

        {/* 2. Interest Rate */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Interest Rate (% p.a.)
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
              max="40"
              step="0.1"
              value={Number.isNaN(rate) ? '' : rate}
              onChange={(e) => setRate(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="8.5"
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

        {/* 3. Loan Tenure */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Loan Tenure (Years)
            </label>
            <span className="text-xs font-mono text-zinc-400">
              {years} Years ({years * 12} Months)
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              min="1"
              max="40"
              step="1"
              value={Number.isNaN(years) ? '' : years}
              onChange={(e) => setYears(Math.max(1, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="15"
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

        {/* 4. Optional Bank Charges & GST Accordion */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all">
          <button
            type="button"
            onClick={() => setShowTaxes((prev) => !prev)}
            className="w-full flex items-center justify-between text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
          >
            <div className="flex items-center gap-2">
              <span>Taxes & Bank Charges (Optional)</span>
              {(applyGstOnInterest || includeProcessingFee) && (
                <span
                  className="px-2 py-0.5 rounded-full text-[10px] font-mono"
                  style={{
                    backgroundColor: `rgba(${currentTheme.accentRgb}, 0.15)`,
                    color: currentTheme.accent,
                  }}
                >
                  Active
                </span>
              )}
            </div>
            {showTaxes ? <ChevronUp className="w-4 h-4 text-zinc-400" /> : <ChevronDown className="w-4 h-4 text-zinc-400" />}
          </button>

          {showTaxes && (
            <div className="mt-4 pt-3 border-t border-zinc-800/80 flex flex-col gap-3.5 text-xs">
              {/* GST on Interest */}
              <div className="flex items-center justify-between flex-wrap gap-2">
                <label className="flex items-center gap-2 cursor-pointer text-zinc-300">
                  <input
                    type="checkbox"
                    checked={applyGstOnInterest}
                    onChange={(e) => setApplyGstOnInterest(e.target.checked)}
                    className="w-4 h-4 rounded accent-emerald-500 cursor-pointer"
                  />
                  <span>GST on Monthly Interest (18%)</span>
                </label>
                {applyGstOnInterest && (
                  <span className="font-mono text-zinc-400">
                    +{currencySymbol}{formatMoney(result.totalGstOnInterest || 0)}
                  </span>
                )}
              </div>

              {/* Processing Fee */}
              <div className="flex items-center justify-between flex-wrap gap-2">
                <label className="flex items-center gap-2 cursor-pointer text-zinc-300">
                  <input
                    type="checkbox"
                    checked={includeProcessingFee}
                    onChange={(e) => setIncludeProcessingFee(e.target.checked)}
                    className="w-4 h-4 rounded accent-emerald-500 cursor-pointer"
                  />
                  <span>Loan Origination / Processing Fee (1%)</span>
                </label>
                {includeProcessingFee && (
                  <span className="font-mono text-zinc-400">
                    {currencySymbol}{formatMoney(result.totalProcessingFeeWithGst || 0)} (incl. 18% GST)
                  </span>
                )}
              </div>
            </div>
          )}
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

        {/* Monthly EMI Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase mb-1">
            Monthly EMI (Repayment)
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-1">
            <span className="text-2xl sm:text-3xl text-zinc-400 font-normal">{currencySymbol}</span>
            <span>{formatMoney(result.monthlyPayment)}</span>
            <span className="text-sm font-normal text-zinc-500 font-sans ml-1">/ month</span>
          </div>
          {applyGstOnInterest && (
            <div className="text-xs text-amber-300 mt-1 font-mono">
              Effective with GST: {currencySymbol}{formatMoney(result.effectiveMonthlyPayment || 0)}/mo
            </div>
          )}
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div className="w-full h-3 rounded-full bg-zinc-800 overflow-hidden flex">
            {/* Principal Share (Grey) */}
            <div
              className="h-full bg-zinc-500 transition-all duration-500"
              style={{ width: `${principalPercent}%` }}
              title={`Principal: ${principalPercent}%`}
            />
            {/* Interest Share (Accent) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${interestPercent}%`,
                backgroundColor: currentTheme.accent,
              }}
              title={`Interest: ${interestPercent}%`}
            />
            {/* Taxes & Fees (Amber) */}
            {taxesFeesPercent > 0 && (
              <div
                className="h-full bg-amber-500 transition-all duration-500"
                style={{ width: `${taxesFeesPercent}%` }}
                title={`Taxes & Fees: ${taxesFeesPercent}%`}
              />
            )}
          </div>

          {/* Ratio Legend & Percentages */}
          <div className="flex items-center justify-between text-xs pt-1 flex-wrap gap-2">
            <div className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-zinc-500 shrink-0" />
              <span className="text-zinc-400">Principal:</span>
              <span className="font-mono font-semibold text-zinc-200">
                {principalPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span className="text-zinc-400">Interest:</span>
              <span
                className="font-mono font-semibold"
                style={{ color: currentTheme.accent }}
              >
                {interestPercent}%
              </span>
            </div>
            {taxesFeesPercent > 0 && (
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500 shrink-0" />
                <span className="text-zinc-400">Taxes/Fees:</span>
                <span className="font-mono font-semibold text-amber-300">
                  {taxesFeesPercent}%
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Two-Metric Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          {/* Tile 1: Total Interest (Neutral) */}
          <div className="bg-zinc-900/60 rounded-2xl p-4 border border-zinc-800/60 flex flex-col justify-between">
            <span className="text-xs font-medium text-zinc-400 mb-1">
              Total Interest Payable
            </span>
            <div className="text-xl sm:text-2xl font-light text-zinc-200 font-mono">
              {currencySymbol}{formatMoney(result.totalInterest)}
            </div>
          </div>

          {/* Tile 2: Total Loan Outflow (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, 0.08)`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.25)`,
            }}
          >
            <span className="text-xs font-medium text-zinc-300 mb-1">
              Total Loan Outflow
            </span>
            <div
              className="text-xl sm:text-2xl font-light font-mono"
              style={{ color: currentTheme.accent }}
            >
              {currencySymbol}{formatMoney(totalOutflow)}
            </div>
          </div>
        </div>

        {/* Upfront Disbursement Breakdown if Fee enabled */}
        {includeProcessingFee && (
          <div className="mb-5 p-3.5 rounded-2xl bg-zinc-900/40 border border-zinc-800/80 flex items-center justify-between text-xs font-mono">
            <span className="text-zinc-400">Net Loan Disbursed:</span>
            <span className="font-semibold text-emerald-400">
              {currencySymbol}{formatMoney(result.netDisbursedAmount || 0)}
            </span>
          </div>
        )}

        {/* Small Grey Footnote */}
        <p className="text-[11px] text-zinc-500 leading-relaxed mb-5">
          Estimate only based on standard monthly reducing balance method. Actual bank terms, prepayment penalties, and processing schedules may differ.
        </p>

        {/* Collapsible Year-by-Year Amortization Schedule */}
        {result.schedule.length > 0 && (
          <div className="pt-3 border-t border-zinc-800/80">
            <button
              type="button"
              onClick={() => setIsScheduleOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
            >
              <span>Annual Amortization Schedule ({result.schedule.length} Years)</span>
              {isScheduleOpen ? (
                <ChevronUp className="w-4 h-4 text-zinc-400" />
              ) : (
                <ChevronDown className="w-4 h-4 text-zinc-400" />
              )}
            </button>

            {isScheduleOpen && (
              <div className="mt-3 overflow-x-auto scrollbar-none animate-fadeIn">
                <table className="w-full text-left text-xs font-mono">
                  <thead>
                    <tr className="border-b border-zinc-800 text-zinc-400">
                      <th className="py-2 px-2.5 font-semibold">Year</th>
                      <th className="py-2 px-2.5 font-semibold">Principal</th>
                      <th className="py-2 px-2.5 font-semibold">Interest</th>
                      <th className="py-2 px-2.5 font-semibold text-right">Balance</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-900/80 text-zinc-300">
                    {result.schedule.map((row) => (
                      <tr key={row.period} className="hover:bg-zinc-900/40">
                        <td className="py-2 px-2.5 text-zinc-400">Yr {row.period}</td>
                        <td className="py-2 px-2.5 text-zinc-300">{currencySymbol}{formatMoney(row.principal)}</td>
                        <td className="py-2 px-2.5 text-amber-400/90">
                          {currencySymbol}{formatMoney(row.interest)}
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
