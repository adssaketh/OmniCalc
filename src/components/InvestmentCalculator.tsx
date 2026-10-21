import React, { useState, useMemo } from 'react';
import { useTheme } from '../hooks/useTheme';
import { ChevronDown, ChevronUp } from 'lucide-react';

interface InvestmentCalculatorProps {
  className?: string;
}

export const InvestmentCalculator: React.FC<InvestmentCalculatorProps> = ({ className = '' }) => {
  const { currentTheme } = useTheme();

  const [principal, setPrincipal] = useState<number>(500000);
  const [rate, setRate] = useState<number>(12);
  const [years, setYears] = useState<number>(10);
  const [isTimelineOpen, setIsTimelineOpen] = useState<boolean>(false);

  const formatINR = (val: number): string => Math.round(val).toLocaleString('en-IN');

  const { finalBalance, totalReturns, yearlyRows } = useMemo(() => {
    let balance = principal;
    const r = rate / 100;
    const rows = [];

    for (let y = 1; y <= years; y++) {
      const startBal = balance;
      balance = balance * (1 + r);
      const yearReturn = balance - startBal;
      rows.push({
        year: y,
        withdrawn: 0,
        returns: Math.round(yearReturn),
        balance: Math.round(balance),
      });
    }

    return {
      finalBalance: Math.round(balance),
      totalReturns: Math.round(balance - principal),
      yearlyRows: rows,
    };
  }, [principal, rate, years]);

  const ratePresets = [
    { label: '6% Safe', value: 6 },
    { label: '8% Hybrid', value: 8 },
    { label: '10% Balanced', value: 10 },
    { label: '12% Equity', value: 12 },
  ];

  const yearPresets = [5, 10, 15, 20, 25, 30];

  return (
    <div className={`w-full max-w-5xl xl:max-w-6xl mx-auto select-none ${className}`}>
      <div className="grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start">
        <div className="md:col-span-6 flex flex-col gap-4">
        {/* Principal */}
        <div
          className="rounded-2xl border p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
            borderColor: 'var(--m3-outline-variant)',
          }}
        >
          <label className="block text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Total Investment (Lump Sum)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>₹</span>
            <input
              type="number"
              min="0"
              value={Number.isNaN(principal) ? '' : principal}
              onChange={(e) => setPrincipal(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="5,00,000"
            />
          </div>
        </div>

        {/* Rate */}
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
            <span className="text-xs font-semibold" style={{ color: currentTheme.accent }}>
              {rate}% p.a.
            </span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              value={Number.isNaN(rate) ? '' : rate}
              onChange={(e) => setRate(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>%</span>
          </div>
          <div className="flex flex-wrap gap-2 pt-1 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            {ratePresets.map((p) => {
              const isActive = rate === p.value;
              return (
                <button
                  key={p.value}
                  type="button"
                  onClick={() => setRate(p.value)}
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

        {/* Duration */}
        <div
          className="rounded-2xl border p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
            borderColor: 'var(--m3-outline-variant)',
          }}
        >
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Investment Period (Years)
            </label>
            <span className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>{years} Years</span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              value={Number.isNaN(years) ? '' : years}
              onChange={(e) => setYears(Math.max(1, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
            />
            <span className="text-xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>Yr</span>
          </div>
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
      </div>

      {/* Results Card (md:col-span-6 sticky on tablet) */}
      <div className="md:col-span-6 flex flex-col gap-4 sticky md:top-4">
        <div
          className="relative rounded-3xl p-5 sm:p-6 border shadow-2xl overflow-hidden backdrop-blur-xl transition-colors"
          style={{
            backgroundColor: 'var(--m3-surface-container)',
            borderColor: 'var(--m3-outline-variant)',
            color: 'var(--m3-on-surface)',
          }}
        >
        <div
          className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
          style={{ backgroundColor: currentTheme.accent }}
        />
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider uppercase mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Final Value After {years} Years
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1" style={{ color: 'var(--m3-on-surface)' }}>
            <span className="text-2xl sm:text-3xl font-normal" style={{ color: 'var(--m3-on-surface-variant)' }}>₹</span>
            <span>{formatINR(finalBalance)}</span>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>Total Invested</span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: 'var(--m3-on-surface)' }}>
              ₹{formatINR(principal)}
            </div>
          </div>
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, ${currentTheme.isDark ? '0.12' : '0.10'})`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.28)`,
            }}
          >
            <span className="text-xs font-medium mb-1" style={{ color: 'var(--m3-on-surface-variant)' }}>Total Returns Earned</span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: currentTheme.accent }}>
              +₹{formatINR(totalReturns)}
            </div>
          </div>
        </div>

        {/* Timeline */}
        {yearlyRows.length > 0 && (
          <div className="pt-3 border-t" style={{ borderColor: 'var(--m3-outline-variant)' }}>
            <button
              type="button"
              onClick={() => setIsTimelineOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold transition-colors cursor-pointer"
              style={{ color: 'var(--m3-on-surface-variant)' }}
            >
              <span>Year-by-Year Growth Timeline</span>
              {isTimelineOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
            </button>
            {isTimelineOpen && (
              <div className="mt-3 overflow-x-auto scrollbar-none">
                <table className="w-full text-left text-xs font-mono">
                  <thead>
                    <tr className="border-b" style={{ borderColor: 'var(--m3-outline-variant)', color: 'var(--m3-on-surface-variant)' }}>
                      <th className="py-2 px-2.5">Year</th>
                      <th className="py-2 px-2.5">Returns</th>
                      <th className="py-2 px-2.5 text-right">Balance</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y" style={{ borderColor: 'var(--m3-outline-variant)' }}>
                    {yearlyRows.map((r) => (
                      <tr key={r.year}>
                        <td className="py-2 px-2.5" style={{ color: 'var(--m3-on-surface-variant)' }}>Yr {r.year}</td>
                        <td className="py-2 px-2.5 font-medium" style={{ color: currentTheme.isDark ? '#34d399' : '#047857' }}>+{formatINR(r.returns)}</td>
                        <td className="py-2 px-2.5 text-right font-medium" style={{ color: 'var(--m3-on-surface)' }}>₹{formatINR(r.balance)}</td>
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
