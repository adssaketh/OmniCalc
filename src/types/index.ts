export type CalculatorMode = 'standard' | 'scientific' | 'converter' | 'finance' | 'physics' | 'grapher';

export type AngleMode = 'deg' | 'rad';

export interface HistoryItem {
  id: string;
  expression: string;
  result: string;
  timestamp: number;
  mode?: string;
}

export interface UnitCategory {
  id: string;
  name: string;
  iconName: string;
  baseUnit: string;
  units: UnitDefinition[];
}

export interface UnitDefinition {
  id: string;
  name: string;
  symbol: string;
  toBase: (val: number) => number;
  fromBase: (val: number) => number;
}

export type VibrationIntensity = 'light' | 'medium' | 'strong' | 'intense';

export interface LoanResult {
  monthlyPayment: number;
  totalPayment: number;
  totalInterest: number;
  // Extended fields for GST & Processing fee
  processingFeeAmount?: number;
  gstOnProcessingFee?: number;
  totalProcessingFeeWithGst?: number;
  netDisbursedAmount?: number;
  totalGstOnInterest?: number;
  monthlyGstAvg?: number;
  effectiveMonthlyPayment?: number;
  grandTotalOutflow?: number;
  schedule: Array<{
    period: number;
    payment: number;
    principal: number;
    interest: number;
    gstOnInterest?: number;
    balance: number;
  }>;
}

export interface CompoundResult {
  endBalance: number;
  totalInvested: number;
  totalInterest: number;
  yearlyBreakdown: Array<{
    year: number;
    monthlyContribution: number;
    balance: number;
    deposits: number;
    interestAccrued: number;
  }>;
}

export type ThemeId =
  | 'm3-iris'
  | 'm3-ocean'
  | 'm3-forest'
  | 'm3-sunset'
  | 'm3-amoled'
  | 'dark-obsidian'
  | 'oled-midnight'
  | 'warm-paper'
  | 'cyber-emerald';

export type ColorMode = 'system' | 'light' | 'dark';

export interface AppSettings {
  soundEnabled: boolean;
  hapticEnabled: boolean;
  vibrationIntensity: VibrationIntensity; // 'light' | 'medium' | 'strong' | 'intense'
  angleMode: AngleMode;
  decimalPrecision: number; // 2, 4, 6, 8, -1 for auto
  theme: ThemeId;
  colorMode: ColorMode; // 'system' (default), 'light', 'dark'
  currencySymbol: string;
  currencyCode: string;
  enableGrapher: boolean;
}
