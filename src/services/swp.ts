export interface SWPInput {
  corpus: number;
  monthlyWithdrawal: number;
  annualRate: number;
  years: number;
  stepUp?: number; // annual % increase in withdrawal, default 0
}

export interface SWPYearlyRow {
  year: number;
  withdrawn: number;
  returns: number;
  balance: number;
}

export interface SWPResult {
  finalBalance: number;
  totalWithdrawn: number;
  totalReturns: number;
  depletedMonth: number | null; // 1-based index of the month when money ran out, or null
  yearlyRows: SWPYearlyRow[];
}

/**
 * Pure calculation function for Systematic Withdrawal Plan (SWP).
 * Can be called with an object `calculateSWP({ corpus, ... })`
 * or positional arguments `calculateSWP(corpus, monthlyWithdrawal, annualRate, years, stepUp)`.
 */
export function calculateSWP(
  corpusOrInput: number | SWPInput,
  argMonthlyWithdrawal?: number,
  argAnnualRate?: number,
  argYears?: number,
  argStepUp?: number
): SWPResult {
  let corpus: number;
  let monthlyWithdrawal: number;
  let annualRate: number;
  let years: number;
  let stepUp: number;

  if (typeof corpusOrInput === 'object' && corpusOrInput !== null) {
    corpus = corpusOrInput.corpus;
    monthlyWithdrawal = corpusOrInput.monthlyWithdrawal;
    annualRate = corpusOrInput.annualRate;
    years = corpusOrInput.years;
    stepUp = corpusOrInput.stepUp ?? 0;
  } else {
    corpus = corpusOrInput;
    monthlyWithdrawal = argMonthlyWithdrawal ?? 0;
    annualRate = argAnnualRate ?? 0;
    years = argYears ?? 0;
    stepUp = argStepUp ?? 0;
  }

  // Return all zeros and empty table for invalid input
  // (NaN, corpus <= 0, years <= 0, negative withdrawal)
  if (
    Number.isNaN(corpus) ||
    Number.isNaN(monthlyWithdrawal) ||
    Number.isNaN(annualRate) ||
    Number.isNaN(years) ||
    Number.isNaN(stepUp) ||
    corpus <= 0 ||
    years <= 0 ||
    monthlyWithdrawal < 0
  ) {
    return {
      finalBalance: 0,
      totalWithdrawn: 0,
      totalReturns: 0,
      depletedMonth: null,
      yearlyRows: [],
    };
  }

  const totalMonths = Math.floor(years * 12);
  const monthlyRate = (annualRate / 100) / 12;

  let balance = corpus;
  let totalWithdrawn = 0;
  let depletedMonth: number | null = null;
  const yearlyRows: SWPYearlyRow[] = [];

  let currentYearWithdrawn = 0;
  let currentYearGrowth = 0;

  for (let m = 1; m <= totalMonths; m++) {
    const yearIndex = Math.floor((m - 1) / 12);
    const scheduledWithdrawal =
      monthlyWithdrawal * Math.pow(1 + stepUp / 100, yearIndex);

    let actualWithdrawal = 0;

    if (balance <= 0) {
      if (depletedMonth === null) {
        depletedMonth = m;
      }
      actualWithdrawal = 0;
    } else if (balance < scheduledWithdrawal) {
      if (depletedMonth === null) {
        depletedMonth = m;
      }
      actualWithdrawal = balance;
      balance = 0;
    } else {
      actualWithdrawal = scheduledWithdrawal;
      balance -= scheduledWithdrawal;
    }

    totalWithdrawn += actualWithdrawal;
    currentYearWithdrawn += actualWithdrawal;

    // Monthly growth applied to remaining balance after withdrawal
    const growthThisMonth = balance > 0 ? balance * monthlyRate : 0;
    balance += growthThisMonth;
    currentYearGrowth += growthThisMonth;

    // End of year or final month tracking
    if (m % 12 === 0 || m === totalMonths) {
      const yearNum = Math.ceil(m / 12);
      const existing = yearlyRows.find((r) => r.year === yearNum);
      if (!existing) {
        yearlyRows.push({
          year: yearNum,
          withdrawn: Math.round(currentYearWithdrawn),
          returns: Math.round(currentYearGrowth),
          balance: Math.max(0, Math.round(balance)),
        });
        currentYearWithdrawn = 0;
        currentYearGrowth = 0;
      }
    }
  }

  const finalBalance = Math.max(0, Math.round(balance));
  const roundedTotalWithdrawn = Math.round(totalWithdrawn);
  const totalReturns = Math.round(finalBalance + roundedTotalWithdrawn - corpus);

  return {
    finalBalance,
    totalWithdrawn: roundedTotalWithdrawn,
    totalReturns,
    depletedMonth,
    yearlyRows,
  };
}
