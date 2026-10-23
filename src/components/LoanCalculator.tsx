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
  const [gstRateInterest] = useState<number>(18);
  const [includeProcessingFee, setIncludeProcessingFee] = useState<boolean>(false);
  const [processingFeeType] = useState<'percent' | 'flat'>('percent');
  const [processingFeeValue] = useState<number>(1.0);
  const [applyGstOnProcessingFee] = useState<boolean>(true);
  const [gstRateProcessingFee] = useState<number>(18);

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
    <div className={`w-full max-w-5xl xl:max-w-6xl mx-auto select-none ${className}`}>
      <div className="grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start">
        {/* =========================================================================
            INPUTS SECTION (md:col-span-6)
           ========================================================================= */}
        <div className="md:col-span-6 flex flex-col gap-4">
        {/* 1. Loan Principal */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Loan Amount (Principal)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <input
              type="number"
              min="0"
              step="50000"
              value={Number.isNaN(principal) ? '' : principal}
              onChange={(e) => setPrincipal(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="25,00,000"
            />
          </div>
          {principal > 0 && (
            <div className="text-xs font-mono mt-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              {currencySymbol}{formatMoney(principal)}
            </div>
          )}

          {/* Principal Presets */}
          <div className="flex flex-wrap gap-2 pt-2.5 mt-2 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {principalPresets.map((p) => {
              const isActive = principal === p.value;
              return (
                <button
                  key={p.value}
                  type="button"
                  onClick={() => setPrincipal(p.value)}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
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

        {/* 2. Interest Rate */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="8.5"
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

        {/* 3. Loan Tenure */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Loan Tenure (Years)
            </label>
            <span className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="15"
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

        {/* 4. Optional Bank Charges & GST Accordion */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <button
            type="button"
            onClick={() => setShowTaxes((prev) => !prev)}
            className="w-full flex items-center justify-between text-xs font-semibold transition-colors cursor-pointer"
            style={{ color: 'var(--m3-on-surface)' }}
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
            {showTaxes ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>

          {showTaxes && (
            <div className="mt-4 pt-3 border-t flex flex-col gap-3.5 text-xs" style={{ borderColor: 'var(--m3-outline-variant)' }}>
              {/* GST on Interest */}
              <div className="flex items-center justify-between flex-wrap gap-2">
                <label className="flex items-center gap-2 cursor-pointer" style={{ color: 'var(--m3-on-surface)' }}>
                  <input
                    type="checkbox"
                    checked={applyGstOnInterest}
                    onChange={(e) => setApplyGstOnInterest(e.target.checked)}
                    className="w-4 h-4 rounded cursor-pointer"
                    style={{ accentColor: currentTheme.accent }}
                  />
                  <span>GST on Monthly Interest (18%)</span>
                </label>
                {applyGstOnInterest && (
                  <span className="font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    +{currencySymbol}{formatMoney(result.totalGstOnInterest || 0)}
                  </span>
                )}
              </div>

              {/* Processing Fee */}
              <div className="flex items-center justify-between flex-wrap gap-2">
                <label className="flex items-center gap-2 cursor-pointer" style={{ color: 'var(--m3-on-surface)' }}>
                  <input
                    type="checkbox"
                    checked={includeProcessingFee}
                    onChange={(e) => setIncludeProcessingFee(e.target.checked)}
                    className="w-4 h-4 rounded cursor-pointer"
                    style={{ accentColor: currentTheme.accent }}
                  />
                  <span>Loan Origination / Processing Fee (1%)</span>
                </label>
                {includeProcessingFee && (
                  <span className="font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    {currencySymbol}{formatMoney(result.totalProcessingFeeWithGst || 0)} (incl. 18% GST)
                  </span>
                )}
              </div>
            </div>
          )}
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
        {/* Monthly EMI Metric */}
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider uppercase mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Monthly EMI (Repayment)
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1" style={{ color: 'var(--m3-on-surface)' }}>
            <span className="text-2xl sm:text-3xl font-normal" style={{ color: 'var(--m3-on-surface-variant)' }}>{currencySymbol}</span>
            <span>{formatMoney(result.monthlyPayment)}</span>
            <span className="text-sm font-normal font-sans ml-1" style={{ color: 'var(--m3-on-surface-variant)' }}>/ month</span>
          </div>
          {applyGstOnInterest && (
            <div className="text-xs mt-1 font-mono" style={{ color: currentTheme.isDark ? '#fcd34d' : '#b45309' }}>
              Effective with GST: {currencySymbol}{formatMoney(result.effectiveMonthlyPayment || 0)}/mo
            </div>
          )}
        </div>

        {/* Ratio Bar */}
        <div className="flex flex-col gap-2 mb-6">
          <div
            className="w-full h-3 rounded-full overflow-hidden flex"
            style={{ backgroundColor: 'var(--m3-surface-container-highest)' }}
          >
            {/* Principal Share (Neutral M3) */}
            <div
              className="h-full transition-all duration-500"
              style={{
                width: `${principalPercent}%`,
                backgroundColor: 'var(--m3-outline)',
              }}
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
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: 'var(--m3-outline)' }} />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Principal:</span>
              <span className="font-mono font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
                {principalPercent}%
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: currentTheme.accent }}
              />
              <span style={{ color: 'var(--m3-on-surface-variant)' }}>Interest:</span>
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
                <span style={{ color: 'var(--m3-on-surface-variant)' }}>Taxes/Fees:</span>
                <span className="font-mono font-semibold" style={{ color: currentTheme.isDark ? '#fcd34d' : '#b45309' }}>
                  {taxesFeesPercent}%
                </span>
              </div>
            )}
          </div>
        </div>

        {/* Two-Metric Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          {/* Tile 1: Total Interest (Neutral) */}
          <div
            className="rounded-2xl p-4 flex flex-col justify-between"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Total Interest Payable
            </span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: 'var(--m3-on-surface)' }}>
              {currencySymbol}{formatMoney(result.totalInterest)}
            </div>
          </div>

          {/* Tile 2: Total Loan Outflow (Accent-tinted) */}
          <div
            className="rounded-2xl p-4 flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, ${currentTheme.isDark ? '0.12' : '0.10'})`,
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
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
          <div
            className="mb-5 p-3.5 rounded-2xl flex items-center justify-between text-xs font-mono"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
            }}
          >
            <span style={{ color: 'var(--m3-on-surface-variant)' }}>Net Loan Disbursed:</span>
            <span className="font-semibold" style={{ color: currentTheme.isDark ? '#34d399' : '#047857' }}>
              {currencySymbol}{formatMoney(result.netDisbursedAmount || 0)}
            </span>
          </div>
        )}

        {/* Small Footnote */}
        <p className="text-[11px] leading-relaxed mb-5" style={{ color: 'var(--m3-on-surface-variant)' }}>
          Estimate only based on standard monthly reducing balance method. Actual bank terms, prepayment penalties, and processing schedules may differ.
        </p>

        {/* Collapsible Year-by-Year Amortization Schedule */}
        {result.schedule.length > 0 && (
          <div className="pt-3 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            <button
              type="button"
              onClick={() => setIsScheduleOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold transition-colors cursor-pointer"
              style={{ color: 'var(--m3-on-surface-variant)' }}
            >
              <span>Annual Amortization Schedule ({result.schedule.length} Years)</span>
              {isScheduleOpen ? (
                <ChevronUp className="w-4 h-4" />
              ) : (
                <ChevronDown className="w-4 h-4" />
              )}
            </button>

            {isScheduleOpen && (
              <div className="mt-3 table-wrap no-scrollbar animate-fadeIn">
                <table className="w-full text-left text-[11.5px] sm:text-xs font-mono">
                  <thead>
                    <tr className="border-b" style={{ borderColor: 'var(--m3-outline-variant)', color: 'var(--m3-on-surface-variant)' }}>
                      <th className="py-2 px-1.5 sm:px-2.5 font-semibold">Year</th>
                      <th className="py-2 px-1.5 sm:px-2.5 font-semibold">Principal</th>
                      <th className="py-2 px-1.5 sm:px-2.5 font-semibold">Interest</th>
                      <th className="py-2 px-1.5 sm:px-2.5 font-semibold text-right">Balance</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y" style={{ borderColor: 'var(--m3-outline-variant)' }}>
                    {result.schedule.map((row) => (
                      <tr key={row.period} className="transition-colors hover:opacity-90">
                        <td className="py-2 px-1.5 sm:px-2.5" style={{ color: 'var(--m3-on-surface-variant)' }}>Yr {row.period}</td>
                        <td className="py-2 px-1.5 sm:px-2.5" style={{ color: 'var(--m3-on-surface)' }}>{currencySymbol}{formatMoney(row.principal)}</td>
                        <td className="py-2 px-1.5 sm:px-2.5 font-medium" style={{ color: currentTheme.isDark ? '#fbbf24' : '#b45309' }}>
                          {currencySymbol}{formatMoney(row.interest)}
                        </td>
                        <td className="py-2 px-1.5 sm:px-2.5 text-right font-medium" style={{ color: 'var(--m3-on-surface)' }}>
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
