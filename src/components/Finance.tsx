import React, { useState } from 'react';
import {
  Wallet,
  TrendingUp,
  ArrowLeft,
  PiggyBank,
  Landmark,
  Globe,
  Receipt,
  LineChart,
} from 'lucide-react';
import { SWPCalculator } from './SWPCalculator';
import { InvestmentCalculator } from './InvestmentCalculator';
import { LoanCalculator } from './LoanCalculator';
import { CompoundCalculator } from './CompoundCalculator';
import { CurrencyConverter } from './CurrencyConverter';
import { TipCalculator } from './TipCalculator';
import { ROICalculator } from './ROICalculator';

export interface FinanceToolItem {
  id: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  description?: string;
}

export const FINANCE_TOOLS: FinanceToolItem[] = [
  { id: 'investment', label: 'Investment', icon: TrendingUp, description: 'Lump sum investment & growth' },
  { id: 'swp', label: 'SWP', icon: Wallet, description: 'Systematic Withdrawal Plan calculator' },
  { id: 'compound', label: 'SIP & Compound', icon: PiggyBank, description: 'Systematic Investment & compounding' },
  { id: 'loan', label: 'Loan / EMI', icon: Landmark, description: 'Loan EMI & amortization breakdown' },
  { id: 'currency', label: 'Currency Exchange', icon: Globe, description: 'Live forex conversion rates' },
  { id: 'tip', label: 'Tip & Bill', icon: Receipt, description: 'Tip calculator & group bill splitting' },
  { id: 'roi', label: 'ROI & CAGR', icon: LineChart, description: 'Return on investment & annualized CAGR' },
];

interface FinanceProps {
  initialToolId?: string | null;
  onBack?: () => void;
  className?: string;
  currencySymbol?: string;
}

export const Finance: React.FC<FinanceProps> = ({
  initialToolId = null,
  onBack,
  className = '',
  currencySymbol = '₹',
}) => {
  const [activeToolId, setActiveToolId] = useState<string | null>(initialToolId);

  const currentTool = FINANCE_TOOLS.find((t) => t.id === activeToolId);

  // If a tool is active, render header with back arrow and scrollable container
  if (activeToolId && currentTool) {
    return (
      <div className={`w-full flex flex-col h-full ${className}`}>
        {/* Header with back arrow and tool title */}
        <div className="flex items-center gap-3 px-4 py-3 border-b border-zinc-800/80 bg-zinc-950/60 sticky top-0 z-20 backdrop-blur-md">
          <button
            type="button"
            onClick={() => {
              setActiveToolId(null);
              if (onBack) onBack();
            }}
            className="p-2 rounded-xl text-zinc-400 hover:text-white hover:bg-zinc-800/60 transition-colors cursor-pointer"
            aria-label="Back to tools"
            title="Back to Finance tools"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div className="flex items-center gap-2">
            <currentTool.icon className="w-5 h-5 text-emerald-400" />
            <h1 className="text-base sm:text-lg font-semibold text-white">
              {currentTool.label}
            </h1>
          </div>
        </div>

        {/* Scrollable Container with exact SWP design language */}
        <div className="flex-1 overflow-y-auto px-4 py-6 scrollbar-none">
          {activeToolId === 'swp' && <SWPCalculator />}
          {activeToolId === 'investment' && <InvestmentCalculator />}
          {activeToolId === 'loan' && <LoanCalculator currencySymbol={currencySymbol} />}
          {activeToolId === 'compound' && <CompoundCalculator currencySymbol={currencySymbol} />}
          {activeToolId === 'currency' && <CurrencyConverter />}
          {activeToolId === 'tip' && <TipCalculator currencySymbol={currencySymbol} />}
          {activeToolId === 'roi' && <ROICalculator currencySymbol={currencySymbol} />}
        </div>
      </div>
    );
  }

  // Grid view of all Finance Tools
  return (
    <div className={`w-full max-w-4xl mx-auto px-4 py-6 flex flex-col gap-6 ${className}`}>
      <div className="flex flex-col gap-1">
        <h2 className="text-xl sm:text-2xl font-bold text-white">Finance Tools</h2>
        <p className="text-xs sm:text-sm text-zinc-400">
          Calculate investments, loans, systematic withdrawals, compounding returns, and live forex.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3.5 sm:gap-4">
        {FINANCE_TOOLS.map((tool) => {
          const Icon = tool.icon;
          return (
            <button
              key={tool.id}
              type="button"
              onClick={() => setActiveToolId(tool.id)}
              className="bg-zinc-900/80 hover:bg-zinc-800/80 border border-zinc-800/80 hover:border-zinc-700/80 rounded-2xl p-4 sm:p-5 flex flex-col items-start gap-3 transition-all cursor-pointer text-left group"
            >
              <div className="p-2.5 rounded-xl bg-zinc-800/80 group-hover:bg-zinc-700/80 text-emerald-400 transition-colors">
                <Icon className="w-5 h-5" />
              </div>
              <div className="flex flex-col">
                <span className="font-semibold text-white text-sm sm:text-base group-hover:text-emerald-300 transition-colors">
                  {tool.label}
                </span>
                {tool.description && (
                  <span className="text-xs text-zinc-400 mt-0.5 line-clamp-2">
                    {tool.description}
                  </span>
                )}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default Finance;
