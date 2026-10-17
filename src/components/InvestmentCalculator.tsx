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
    <div className={`w-full max-w-3xl mx-auto flex flex-col gap-6 select-none ${className}`}>
      <div className="flex flex-col gap-4">
        {/* Principal */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <label className="block text-xs font-medium text-zinc-400 mb-1">
            Total Investment (Lump Sum)
          </label>
          <div className="flex items-center gap-1.5">
            <span className="text-2xl font-light text-zinc-400">₹</span>
            <input
              type="number"
              min="0"
              value={Number.isNaN(principal) ? '' : principal}
              onChange={(e) => setPrincipal(parseFloat(e.target.value) || 0)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="5,00,000"
            />
          </div>
        </div>

        {/* Rate */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
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
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
            />
            <span className="text-xl font-light text-zinc-400">%</span>
          </div>
          <div className="flex flex-wrap gap-2 pt-1 border-t border-zinc-800/60">
            {ratePresets.map((p) => (
              <button
                key={p.value}
                type="button"
                onClick={() => setRate(p.value)}
                className={`px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer ${
                  rate === p.value
                    ? 'bg-zinc-800 text-white border border-zinc-600'
                    : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                }`}
                style={rate === p.value ? { borderColor: currentTheme.accent, color: currentTheme.accent } : {}}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>

        {/* Duration */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-1">
            <label className="block text-xs font-medium text-zinc-400">
              Investment Period (Years)
            </label>
            <span className="text-xs font-mono text-zinc-400">{years} Years</span>
          </div>
          <div className="flex items-center gap-1.5 mb-3">
            <input
              type="number"
              value={Number.isNaN(years) ? '' : years}
              onChange={(e) => setYears(Math.max(1, parseFloat(e.target.value) || 0))}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
            />
            <span className="text-xl font-light text-zinc-400">Yr</span>
          </div>
          <div className="flex flex-wrap gap-2 pt-1 border-t border-zinc-800/60">
            {yearPresets.map((y) => (
              <button
                key={y}
                type="button"
                onClick={() => setYears(y)}
                className={`px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer ${
                  years === y
                    ? 'bg-zinc-800 text-white border border-zinc-600'
                    : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 border border-zinc-800'
                }`}
                style={years === y ? { borderColor: currentTheme.accent, color: currentTheme.accent } : {}}
              >
                {y}Y
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Results Card */}
      <div className="relative bg-zinc-950/80 rounded-3xl p-5 sm:p-6 border border-zinc-800/90 shadow-2xl overflow-hidden backdrop-blur-xl">
        <div
          className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
          style={{ backgroundColor: currentTheme.accent }}
        />
        <div className="flex flex-col mb-5">
          <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase mb-1">
            Final Value After {years} Years
          </span>
          <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-1">
            <span className="text-2xl sm:text-3xl text-zinc-400 font-normal">₹</span>
            <span>{formatINR(finalBalance)}</span>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          <div className="bg-zinc-900/60 rounded-2xl p-4 border border-zinc-800/60 flex flex-col justify-between">
            <span className="text-xs font-medium text-zinc-400 mb-1">Total Invested</span>
            <div className="text-xl sm:text-2xl font-light text-zinc-200 font-mono">
              ₹{formatINR(principal)}
            </div>
          </div>
          <div
            className="rounded-2xl p-4 border flex flex-col justify-between"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, 0.08)`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.25)`,
            }}
          >
            <span className="text-xs font-medium text-zinc-300 mb-1">Total Returns Earned</span>
            <div className="text-xl sm:text-2xl font-light font-mono" style={{ color: currentTheme.accent }}>
              +₹{formatINR(totalReturns)}
            </div>
          </div>
        </div>

        {/* Timeline */}
        {yearlyRows.length > 0 && (
          <div className="pt-3 border-t border-zinc-800/80">
            <button
              type="button"
              onClick={() => setIsTimelineOpen((prev) => !prev)}
              className="w-full flex items-center justify-between py-2 text-xs font-semibold text-zinc-300 hover:text-white transition-colors cursor-pointer"
            >
              <span>Year-by-Year Growth Timeline</span>
              {isTimelineOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
            </button>
            {isTimelineOpen && (
              <div className="mt-3 overflow-x-auto scrollbar-none">
                <table className="w-full text-left text-xs font-mono">
                  <thead>
                    <tr className="border-b border-zinc-800 text-zinc-400">
                      <th className="py-2 px-2.5">Year</th>
                      <th className="py-2 px-2.5">Returns</th>
                      <th className="py-2 px-2.5 text-right">Balance</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-zinc-900/80 text-zinc-300">
                    {yearlyRows.map((r) => (
                      <tr key={r.year}>
                        <td className="py-2 px-2.5 text-zinc-400">Yr {r.year}</td>
                        <td className="py-2 px-2.5 text-emerald-400">+{formatINR(r.returns)}</td>
                        <td className="py-2 px-2.5 text-right font-medium text-white">₹{formatINR(r.balance)}</td>
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
