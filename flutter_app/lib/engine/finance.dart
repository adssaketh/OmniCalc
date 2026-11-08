import 'js_number.dart';
import 'swp.dart';

export 'swp.dart';

/// Port of `LoanCalculationOptions` (every field optional, same defaults as the TypeScript).
class LoanCalculationOptions {
  final bool? includeProcessingFee;

  /// 'percent' | 'flat'
  final String? processingFeeType;
  final double? processingFeeValue;
  final bool? applyGstOnProcessingFee;
  final double? gstRateProcessingFee;
  final bool? applyGstOnInterest;
  final double? gstRateInterest;

  const LoanCalculationOptions({
    this.includeProcessingFee,
    this.processingFeeType,
    this.processingFeeValue,
    this.applyGstOnProcessingFee,
    this.gstRateProcessingFee,
    this.applyGstOnInterest,
    this.gstRateInterest,
  });
}

class LoanScheduleRow {
  final double period;
  final double payment;
  final double principal;
  final double interest;
  final double gstOnInterest;
  final double balance;

  const LoanScheduleRow({
    required this.period,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.gstOnInterest,
    required this.balance,
  });
}

/// `LoanResult` in `src/types/index.ts`. The extended fields are always filled by the engine.
class LoanResult {
  final double monthlyPayment;
  final double totalPayment;
  final double totalInterest;
  final double processingFeeAmount;
  final double gstOnProcessingFee;
  final double totalProcessingFeeWithGst;
  final double netDisbursedAmount;
  final double totalGstOnInterest;
  final double monthlyGstAvg;
  final double effectiveMonthlyPayment;
  final double grandTotalOutflow;
  final List<LoanScheduleRow> schedule;

  const LoanResult({
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.processingFeeAmount,
    required this.gstOnProcessingFee,
    required this.totalProcessingFeeWithGst,
    required this.netDisbursedAmount,
    required this.totalGstOnInterest,
    required this.monthlyGstAvg,
    required this.effectiveMonthlyPayment,
    required this.grandTotalOutflow,
    required this.schedule,
  });
}

class CompoundYearRow {
  final double year;
  final double monthlyContribution;
  final double balance;
  final double deposits;
  final double interestAccrued;

  const CompoundYearRow({
    required this.year,
    required this.monthlyContribution,
    required this.balance,
    required this.deposits,
    required this.interestAccrued,
  });
}

class CompoundResult {
  final double endBalance;
  final double totalInvested;
  final double totalInterest;
  final List<CompoundYearRow> yearlyBreakdown;

  const CompoundResult({
    required this.endBalance,
    required this.totalInvested,
    required this.totalInterest,
    required this.yearlyBreakdown,
  });
}

class TipResult {
  final double tipTotal;
  final double billTotal;
  final double perPersonTotal;
  final double perPersonTip;
  final double perPersonBase;

  const TipResult({
    required this.tipTotal,
    required this.billTotal,
    required this.perPersonTotal,
    required this.perPersonTip,
    required this.perPersonBase,
  });
}

class RoiResult {
  final double gainLoss;
  final double roiPercent;
  final double cagrPercent;

  const RoiResult({required this.gainLoss, required this.roiPercent, required this.cagrPercent});
}

class DepreciationRow {
  final double year;
  final double depreciation;
  final double bookValue;

  const DepreciationRow({required this.year, required this.depreciation, required this.bookValue});
}

/// Port of `FinanceEngine` in `src/engine/finance.ts`. Every `Math.max/min/round/pow` goes through the js_number
/// helpers so NaN, -0 and rounding behave exactly like JavaScript.
class FinanceEngine {
  FinanceEngine._();

  /// Loan / Mortgage EMI calculation with optional GST and Processing Fees.
  /// [annualInterestRate] is in percent (e.g. 8.5), [termYears] in years.
  static LoanResult calculateLoan(
    double principal,
    double annualInterestRate,
    double termYears, [
    LoanCalculationOptions? options,
  ]) {
    if (principal <= 0 || termYears <= 0) {
      return const LoanResult(
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
      );
    }

    final totalMonths = jsRound(termYears * 12);
    final monthlyRate = annualInterestRate / 100 / 12;

    double monthlyPayment = 0;
    if (monthlyRate == 0) {
      monthlyPayment = principal / totalMonths;
    } else {
      final factor = jsPow(1 + monthlyRate, totalMonths);
      monthlyPayment = (principal * monthlyRate * factor) / (factor - 1);
    }

    final totalPayment = monthlyPayment * totalMonths;
    final totalInterest = jsMax([0, totalPayment - principal]);

    // 1. Processing Fee calculations
    final includePF = options?.includeProcessingFee ?? false;
    final pfType = options?.processingFeeType ?? 'percent';
    final pfVal = options?.processingFeeValue ?? 1.0;
    double processingFeeAmount = 0;
    if (includePF) {
      processingFeeAmount = pfType == 'percent' ? (principal * pfVal) / 100 : pfVal;
    }

    // 2. GST on Processing Fee (typically 18%)
    final applyGstPF = options?.applyGstOnProcessingFee ?? true;
    final gstRatePF = options?.gstRateProcessingFee ?? 18;
    final gstOnProcessingFee = includePF && applyGstPF ? (processingFeeAmount * gstRatePF) / 100 : 0.0;
    final totalProcessingFeeWithGst = processingFeeAmount + gstOnProcessingFee;
    final netDisbursedAmount = jsMax([0, principal - totalProcessingFeeWithGst]);

    // 3. GST on Interest (typically 18%)
    final applyGstInterest = options?.applyGstOnInterest ?? false;
    final gstRateInterest = options?.gstRateInterest ?? 18;
    final totalGstOnInterest = applyGstInterest ? (totalInterest * gstRateInterest) / 100 : 0.0;
    final monthlyGstAvg = totalMonths > 0 ? totalGstOnInterest / totalMonths : 0.0;
    final effectiveMonthlyPayment = monthlyPayment + monthlyGstAvg;

    // 4. Grand Total Outflow
    final grandTotalOutflow = principal + totalInterest + totalGstOnInterest + totalProcessingFeeWithGst;

    // Build amortization schedule (yearly aggregated)
    var balance = principal;
    final schedule = <LoanScheduleRow>[];

    final lastYear = termYears.ceilToDouble();
    for (var year = 1; year <= lastYear; year++) {
      double yearlyPrincipal = 0;
      double yearlyInterest = 0;
      double yearlyPayment = 0;

      final monthsInThisYear = jsMin([12, totalMonths - (year - 1) * 12]);
      for (var m = 0; m < monthsInThisYear; m++) {
        if (balance <= 0) break;
        final interestForMonth = balance * monthlyRate;
        final principalForMonth = jsMin([balance, monthlyPayment - interestForMonth]);
        yearlyInterest += interestForMonth;
        yearlyPrincipal += principalForMonth;
        yearlyPayment += principalForMonth + interestForMonth;
        balance -= principalForMonth;
      }

      final yearlyGstInterest = applyGstInterest ? (yearlyInterest * gstRateInterest) / 100 : 0.0;

      schedule.add(LoanScheduleRow(
        period: year.toDouble(),
        payment: yearlyPayment,
        principal: yearlyPrincipal,
        interest: yearlyInterest,
        gstOnInterest: yearlyGstInterest,
        balance: jsMax([0, balance]),
      ));
    }

    return LoanResult(
      monthlyPayment: monthlyPayment,
      totalPayment: totalPayment,
      totalInterest: totalInterest,
      processingFeeAmount: processingFeeAmount,
      gstOnProcessingFee: gstOnProcessingFee,
      totalProcessingFeeWithGst: totalProcessingFeeWithGst,
      netDisbursedAmount: netDisbursedAmount,
      totalGstOnInterest: totalGstOnInterest,
      monthlyGstAvg: monthlyGstAvg,
      effectiveMonthlyPayment: effectiveMonthlyPayment,
      grandTotalOutflow: grandTotalOutflow,
      schedule: schedule,
    );
  }

  /// Compound interest with a monthly contribution and an annual step-up percentage.
  /// [compoundFrequency] is the number of times compounded per year (12 = monthly).
  static CompoundResult calculateCompoundInterest(
    double principal,
    double monthlyDeposit,
    double annualRate,
    double years, [
    double annualStepUpPercent = 0,
    double compoundFrequency = 12,
  ]) {
    final r = annualRate / 100;
    final n = compoundFrequency;
    var currentBalance = principal;
    var totalDeposited = principal;
    var currentMonthlyDeposit = monthlyDeposit;

    final yearlyBreakdown = <CompoundYearRow>[
      CompoundYearRow(
        year: 0,
        monthlyContribution: monthlyDeposit,
        balance: principal,
        deposits: principal,
        interestAccrued: 0,
      ),
    ];

    for (var yr = 1; yr <= years; yr++) {
      // In year 2+, step-up the monthly deposit by annualStepUpPercent
      if (yr > 1 && annualStepUpPercent > 0) {
        currentMonthlyDeposit = currentMonthlyDeposit * (1 + annualStepUpPercent / 100);
      }

      // Simulate month-by-month for accurate interest compounding with monthly deposits
      for (var m = 1; m <= 12; m++) {
        final monthlyRate = r / n;
        currentBalance += currentMonthlyDeposit;
        totalDeposited += currentMonthlyDeposit;
        currentBalance += currentBalance * (monthlyRate * (n / 12));
      }

      final totalInterestSoFar = jsMax([0, currentBalance - totalDeposited]);
      yearlyBreakdown.add(CompoundYearRow(
        year: yr.toDouble(),
        monthlyContribution: currentMonthlyDeposit,
        balance: currentBalance,
        deposits: totalDeposited,
        interestAccrued: totalInterestSoFar,
      ));
    }

    return CompoundResult(
      endBalance: currentBalance,
      totalInvested: totalDeposited,
      totalInterest: jsMax([0, currentBalance - totalDeposited]),
      yearlyBreakdown: yearlyBreakdown,
    );
  }

  /// Tip and bill split.
  static TipResult calculateTip(
    double billAmount,
    double tipPercent,
    double peopleCount, [
    bool roundUp = false,
  ]) {
    // `peopleCount || 1` and `tipPercent || 0`: 0 and NaN are falsy in JavaScript.
    final people = (peopleCount == 0 || peopleCount.isNaN) ? 1.0 : peopleCount;
    final validPeople = jsMax([1, people.floorToDouble()]);
    final tip = (tipPercent == 0 || tipPercent.isNaN) ? 0.0 : tipPercent;
    final tipTotal = (billAmount * tip) / 100;
    var billTotal = billAmount + tipTotal;

    if (roundUp && billTotal > 0) {
      billTotal = billTotal.ceilToDouble();
    }

    final perPersonTotal = billTotal / validPeople;
    final perPersonTip = tipTotal / validPeople;
    final perPersonBase = billAmount / validPeople;

    return TipResult(
      tipTotal: tipTotal,
      billTotal: billTotal,
      perPersonTotal: perPersonTotal,
      perPersonTip: perPersonTip,
      perPersonBase: perPersonBase,
    );
  }

  /// Return on Investment (ROI) and Compound Annual Growth Rate (CAGR).
  static RoiResult calculateROI(double initialInvestment, double finalValue, double years) {
    if (initialInvestment <= 0) {
      return const RoiResult(gainLoss: 0, roiPercent: 0, cagrPercent: 0);
    }

    final gainLoss = finalValue - initialInvestment;
    final roiPercent = (gainLoss / initialInvestment) * 100;

    double cagrPercent = 0;
    if (years > 0 && finalValue > 0) {
      cagrPercent = (jsPow(finalValue / initialInvestment, 1 / years) - 1) * 100;
    }

    return RoiResult(gainLoss: gainLoss, roiPercent: roiPercent, cagrPercent: cagrPercent);
  }

  /// Straight-line asset depreciation.
  static List<DepreciationRow> calculateDepreciation(double cost, double salvageValue, double usefulYears) {
    if (usefulYears <= 0 || cost <= 0) return [];
    final annualDepreciation = jsMax([0, cost - salvageValue]) / usefulYears;
    final schedule = <DepreciationRow>[];

    var currentBookValue = cost;
    for (var yr = 1; yr <= usefulYears; yr++) {
      final dep = jsMin([annualDepreciation, jsMax([0, currentBookValue - salvageValue])]);
      currentBookValue -= dep;
      schedule.add(DepreciationRow(
        year: yr.toDouble(),
        depreciation: dep,
        bookValue: jsMax([salvageValue, currentBookValue]),
      ));
    }

    return schedule;
  }

  /// Systematic Withdrawal Plan (SWP). Same as `calculateSwpPositional` (the object form is `calculateSwp`).
  static SwpResult calculateSWP(
    double corpus, [
    double? monthlyWithdrawal,
    double? annualRate,
    double? years,
    double? stepUp,
  ]) =>
      calculateSwpPositional(corpus, monthlyWithdrawal, annualRate, years, stepUp);

  /// Object form of `calculateSWP`.
  static SwpResult calculateSWPInput(SwpInput input) => calculateSwp(input);
}
