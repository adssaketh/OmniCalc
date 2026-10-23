import React, { useState } from 'react';
import { soundFx } from '../utils/audio';
import {
  Globe,
  Wallet,
  Landmark,
  PiggyBank,
  Receipt,
  LineChart,
} from 'lucide-react';
import { SwipeableTabContainer, TabItem } from './SwipeableTabContainer';
import { SWPCalculator } from './SWPCalculator';
import { LoanCalculator } from './LoanCalculator';
import { CompoundCalculator } from './CompoundCalculator';
import { CurrencyConverter } from './CurrencyConverter';
import { TipCalculator } from './TipCalculator';
import { ROICalculator } from './ROICalculator';

interface FinanceScreenProps {
  soundEnabled: boolean;
  hapticEnabled: boolean;
  currencySymbol?: string;
}

export type FinanceTab = 'currency' | 'loan' | 'compound' | 'swp' | 'tip' | 'roi';

export const FinanceScreen: React.FC<FinanceScreenProps> = ({
  soundEnabled,
  hapticEnabled,
  currencySymbol = '₹',
}) => {
  const [activeTab, setActiveTab] = useState<FinanceTab>('currency');

  // Audio / Haptic helper
  const playSound = (type: 'num' | 'op' | 'toggle' = 'num') => {
    if (soundEnabled) soundFx.playClick(type);
    if (hapticEnabled) soundFx.triggerHaptic();
  };

  // Tab switch
  const handleTabSwitch = (tab: FinanceTab) => {
    playSound('toggle');
    setActiveTab(tab);
  };

  // Finance tools tabs with dedicated logos matching SWP
  const financeTabs: TabItem[] = [
    { id: 'currency', label: 'Currency', icon: Globe },
    { id: 'loan', label: 'Loan / EMI', icon: Landmark },
    { id: 'compound', label: 'SIP & Compound', icon: PiggyBank },
    { id: 'swp', label: 'SWP', icon: Wallet },
    { id: 'tip', label: 'Tip & Bill', icon: Receipt },
    { id: 'roi', label: 'ROI & CAGR', icon: LineChart },
  ];

  return (
    <div className="w-full max-w-5xl xl:max-w-6xl mx-auto flex flex-col items-center select-none pb-6">
      <SwipeableTabContainer
        tabs={financeTabs}
        activeTabId={activeTab}
        onSelectTab={(tabId) => handleTabSwitch(tabId as FinanceTab)}
        showNavButtons={true}
      >
        <div className="w-full pt-2">
          {activeTab === 'currency' && <CurrencyConverter />}
          {activeTab === 'loan' && <LoanCalculator currencySymbol={currencySymbol} />}
          {activeTab === 'compound' && <CompoundCalculator currencySymbol={currencySymbol} />}
          {activeTab === 'swp' && <SWPCalculator />}
          {activeTab === 'tip' && <TipCalculator currencySymbol={currencySymbol} />}
          {activeTab === 'roi' && <ROICalculator currencySymbol={currencySymbol} />}
        </div>
      </SwipeableTabContainer>
    </div>
  );
};

export default FinanceScreen;
