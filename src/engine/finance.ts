import { LoanResult, CompoundResult } from '../types';
import { calculateSWP, SWPInput, SWPResult } from '../services/swp';

export interface LoanCalculationOptions {
  includeProcessingFee?: boolean;
  processingFeeType?: 'percent' | 'flat';
  processingFeeValue?: number;
  applyGstOnProcessingFee?: boolean;
  gstRateProcessingFee?: number;
  applyGstOnInterest?: boolean;
  gstRateInterest?: number;
}

export class FinanceEngine {
  /**
   * Loan / Mortgage EMI calculation with optional GST and Processing Fees
   * @param principal Total loan amount
   * @param annualInterestRate Annual interest rate in percent (e.g., 8.5)
   * @param termYears Term in years
   * @param options Optional GST and processing fee configuration
   */
  public static calculateLoan(
    principal: number,
    annualInterestRate: number,
    termYears: number,
    options?: LoanCalculationOptions
  ): LoanResult {
    if (principal <= 0 || termYears <= 0) {
      return {
        monthlyPayment: 0,
        totalPayment: 0,
        totalInterest: 0,
        processingFeeAmount: 0,
        gstOnProcessingFee: 0,
        totalProcessingFeeWithGst: 0,
        netDisbursedAmount: 0,
        totalGstOnInterest: 0,
        monthlyGstAvg: 0,
        effectiveMonthlyPayment: 0,
        grandTotalOutflow: 0,
        schedule: [],
      };
    }

    const totalMonths = Math.round(termYears * 12);
    const monthlyRate = annualInterestRate / 100 / 12;

    let monthlyPayment = 0;
    if (monthlyRate === 0) {
      monthlyPayment = principal / totalMonths;
    } else {
      const factor = Math.pow(1 + monthlyRate, totalMonths);
      monthlyPayment = (principal * monthlyRate * factor) / (factor - 1);
    }

    const totalPayment = monthlyPayment * totalMonths;
    const totalInterest = Math.max(0, totalPayment - principal);

    // 1. Processing Fee calculations
    const includePF = options?.includeProcessingFee ?? false;
    const pfType = options?.processingFeeType ?? 'percent';
    const pfVal = options?.processingFeeValue ?? 1.0;
    let processingFeeAmount = 0;
    if (includePF) {
      processingFeeAmount = pfType === 'percent' ? (principal * pfVal) / 100 : pfVal;
    }

    // 2. GST on Processing Fee (typically 18%)
    const applyGstPF = options?.applyGstOnProcessingFee ?? true;
    const gstRatePF = options?.gstRateProcessingFee ?? 18;
    const gstOnProcessingFee = includePF && applyGstPF ? (processingFeeAmount * gstRatePF) / 100 : 0;
    const totalProcessingFeeWithGst = processingFeeAmount + gstOnProcessingFee;
    const netDisbursedAmount = Math.max(0, principal - totalProcessingFeeWithGst);

    // 3. GST on Interest (typically 18%)
    const applyGstInterest = options?.applyGstOnInterest ?? false;
    const gstRateInterest = options?.gstRateInterest ?? 18;
    const totalGstOnInterest = applyGstInterest ? (totalInterest * gstRateInterest) / 100 : 0;
    const monthlyGstAvg = totalMonths > 0 ? totalGstOnInterest / totalMonths : 0;
    const effectiveMonthlyPayment = monthlyPayment + monthlyGstAvg;

    // 4. Grand Total Outflow
    const grandTotalOutflow = principal + totalInterest + totalGstOnInterest + totalProcessingFeeWithGst;

    // Build amortization schedule (yearly aggregated)
    let balance = principal;
    const schedule: LoanResult['schedule'] = [];

    for (let year = 1; year <= Math.ceil(termYears); year++) {
      let yearlyPrincipal = 0;
      let yearlyInterest = 0;
      let yearlyPayment = 0;

      const monthsInThisYear = Math.min(12, totalMonths - (year - 1) * 12);
      for (let m = 0; m < monthsInThisYear; m++) {
        if (balance <= 0) break;
        const interestForMonth = balance * monthlyRate;
        const principalForMonth = Math.min(balance, monthlyPayment - interestForMonth);
        yearlyInterest += interestForMonth;
        yearlyPrincipal += principalForMonth;
        yearlyPayment += principalForMonth + interestForMonth;
        balance -= principalForMonth;
      }

      const yearlyGstInterest = applyGstInterest ? (yearlyInterest * gstRateInterest) / 100 : 0;

      schedule.push({
        period: year,
        payment: yearlyPayment,
        principal: yearlyPrincipal,
        interest: yearlyInterest,
        gstOnInterest: yearlyGstInterest,
        balance: Math.max(0, balance),
      });
    }

    return {
      monthlyPayment,
      totalPayment,
      totalInterest,
      processingFeeAmount,
      gstOnProcessingFee,
      totalProcessingFeeWithGst,
      netDisbursedAmount,
      totalGstOnInterest,
      monthlyGstAvg,
      effectiveMonthlyPayment,
      grandTotalOutflow,
      schedule,
    };
  }

  /**
   * Compound Interest with monthly contribution and annual step-up percentage
   * @param principal Initial investment
   * @param monthlyDeposit Starting monthly savings
   * @param annualRate Annual interest rate %
   * @param years Number of years
   * @param annualStepUpPercent Annual increase % in monthly contribution (e.g. 10%)
   * @param compoundFrequency Times compounded per year (default 12 for monthly)
   */
  public static calculateCompoundInterest(
    principal: number,
    monthlyDeposit: number,
    annualRate: number,
    years: number,
    annualStepUpPercent: number = 0,
    compoundFrequency: number = 12
  ): CompoundResult {
    const r = annualRate / 100;
    const n = compoundFrequency;
    let currentBalance = principal;
    let totalDeposited = principal;
    let currentMonthlyDeposit = monthlyDeposit;

    const yearlyBreakdown: CompoundResult['yearlyBreakdown'] = [
      {
        year: 0,
        monthlyContribution: monthlyDeposit,
        balance: principal,
        deposits: principal,
        interestAccrued: 0,
      },
    ];

    for (let yr = 1; yr <= years; yr++) {
      // In year 2+, step-up the monthly deposit by annualStepUpPercent
      if (yr > 1 && annualStepUpPercent > 0) {
        currentMonthlyDeposit = currentMonthlyDeposit * (1 + annualStepUpPercent / 100);
      }

      // Simulate month-by-month for accurate interest compounding with monthly deposits
      for (let m = 1; m <= 12; m++) {
        const monthlyRate = r / n;
        currentBalance += currentMonthlyDeposit;
        totalDeposited += currentMonthlyDeposit;
        currentBalance += currentBalance * (monthlyRate * (n / 12));
      }

      const totalInterestSoFar = Math.max(0, currentBalance - totalDeposited);
      yearlyBreakdown.push({
        year: yr,
        monthlyContribution: currentMonthlyDeposit,
        balance: currentBalance,
        deposits: totalDeposited,
        interestAccrued: totalInterestSoFar,
      });
    }

    return {
      endBalance: currentBalance,
      totalInvested: totalDeposited,
      totalInterest: Math.max(0, currentBalance - totalDeposited),
      yearlyBreakdown,
    };
  }

  /**
   * Tip and Bill Split calculation
   */
  public static calculateTip(
    billAmount: number,
    tipPercent: number,
    peopleCount: number,
    roundUp: boolean = false
  ): {
    tipTotal: number;
    billTotal: number;
    perPersonTotal: number;
    perPersonTip: number;
    perPersonBase: number;
  } {
    const validPeople = Math.max(1, Math.floor(peopleCount || 1));
    const tipTotal = (billAmount * (tipPercent || 0)) / 100;
    let billTotal = billAmount + tipTotal;

    if (roundUp && billTotal > 0) {
      billTotal = Math.ceil(billTotal);
    }

    const perPersonTotal = billTotal / validPeople;
    const perPersonTip = tipTotal / validPeople;
    const perPersonBase = billAmount / validPeople;

    return {
      tipTotal,
      billTotal,
      perPersonTotal,
      perPersonTip,
      perPersonBase,
    };
  }

  /**
   * Return on Investment (ROI) and Compound Annual Growth Rate (CAGR)
   */
  public static calculateROI(
    initialInvestment: number,
    finalValue: number,
    years: number
  ): {
    gainLoss: number;
    roiPercent: number;
    cagrPercent: number;
  } {
    if (initialInvestment <= 0) {
      return { gainLoss: 0, roiPercent: 0, cagrPercent: 0 };
    }

    const gainLoss = finalValue - initialInvestment;
    const roiPercent = (gainLoss / initialInvestment) * 100;

    let cagrPercent = 0;
    if (years > 0 && finalValue > 0) {
      cagrPercent = (Math.pow(finalValue / initialInvestment, 1 / years) - 1) * 100;
    }

    return { gainLoss, roiPercent, cagrPercent };
  }

  /**
   * Straight-line Asset Depreciation
   */
  public static calculateDepreciation(
    cost: number,
    salvageValue: number,
    usefulYears: number
  ): Array<{ year: number; depreciation: number; bookValue: number }> {
    if (usefulYears <= 0 || cost <= 0) return [];
    const annualDepreciation = Math.max(0, cost - salvageValue) / usefulYears;
    const schedule: Array<{ year: number; depreciation: number; bookValue: number }> = [];

    let currentBookValue = cost;
    for (let yr = 1; yr <= usefulYears; yr++) {
      const dep = Math.min(annualDepreciation, Math.max(0, currentBookValue - salvageValue));
      currentBookValue -= dep;
      schedule.push({
        year: yr,
        depreciation: dep,
        bookValue: Math.max(salvageValue, currentBookValue),
      });
    }

    return schedule;
  }

  /**
   * Systematic Withdrawal Plan (SWP) Calculation
   */
  public static calculateSWP(
    corpusOrInput: number | SWPInput,
    monthlyWithdrawal?: number,
    annualRate?: number,
    years?: number,
    stepUp?: number
  ): SWPResult {
    return calculateSWP(corpusOrInput, monthlyWithdrawal, annualRate, years, stepUp);
  }
}
