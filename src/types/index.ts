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
  | 'dynamic'
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

/** How content behaves as it slides under the floating bars. */
export type EdgeEffect = 'off' | 'fade' | 'blur';
export type FadeHeight = 'short' | 'medium' | 'tall';
export type BarStyle = 'solid' | 'glass';
export type GlassBlur = 'soft' | 'medium' | 'strong';

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
  /** Show the Physics Lab screen (off by default) */
  enablePhysics: boolean;
  /** Scroll edge effect: Off / Fade / Fade + blur */
  edgeEffect: EdgeEffect;
  /** How far from the bars content starts to fade */
  fadeHeight: FadeHeight;
  /** Solid colour bars or frosted glass */
  barStyle: BarStyle;
  /** Glass transparency, 0 = frosted ... 100 = clear */
  glassTransparency: number;
  glassBlur: GlassBlur;
  /** Thin light rim around the glass bars */
  glassEdge: boolean;
}
