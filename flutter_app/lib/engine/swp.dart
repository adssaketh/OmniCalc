import 'js_number.dart';

/// Port of `src/services/swp.ts`.
class SwpInput {
  final double corpus;
  final double monthlyWithdrawal;
  final double annualRate;
  final double years;

  /// annual % increase in withdrawal, default 0
  final double stepUp;

  const SwpInput({
    required this.corpus,
    required this.monthlyWithdrawal,
    required this.annualRate,
    required this.years,
    this.stepUp = 0,
  });
}

class SwpYearlyRow {
  final double year;
  final double withdrawn;
  final double returns;
  final double balance;

  const SwpYearlyRow({
    required this.year,
    required this.withdrawn,
    required this.returns,
    required this.balance,
  });
}

class SwpResult {
  final double finalBalance;
  final double totalWithdrawn;
  final double totalReturns;

  /// 1-based index of the month when money ran out, or null.
  final int? depletedMonth;
  final List<SwpYearlyRow> yearlyRows;

  const SwpResult({
    required this.finalBalance,
    required this.totalWithdrawn,
    required this.totalReturns,
    required this.depletedMonth,
    required this.yearlyRows,
  });
}

/// Positional form of `calculateSWP(corpus, monthlyWithdrawal, annualRate, years, stepUp)`.
/// Missing arguments default to 0, like `argX ?? 0` in the TypeScript.
SwpResult calculateSwpPositional(
  double corpus, [
  double? monthlyWithdrawal,
  double? annualRate,
  double? years,
  double? stepUp,
]) {
  return calculateSwp(SwpInput(
    corpus: corpus,
    monthlyWithdrawal: monthlyWithdrawal ?? 0,
    annualRate: annualRate ?? 0,
    years: years ?? 0,
    stepUp: stepUp ?? 0,
  ));
}

/// Pure calculation for a Systematic Withdrawal Plan.
SwpResult calculateSwp(SwpInput input) {
  final corpus = input.corpus;
  final monthlyWithdrawal = input.monthlyWithdrawal;
  final annualRate = input.annualRate;
  final years = input.years;
  final stepUp = input.stepUp;

  // Return all zeros and empty table for invalid input
  // (NaN, corpus <= 0, years <= 0, negative withdrawal)
  if (corpus.isNaN ||
      monthlyWithdrawal.isNaN ||
      annualRate.isNaN ||
      years.isNaN ||
      stepUp.isNaN ||
      corpus <= 0 ||
      years <= 0 ||
      monthlyWithdrawal < 0) {
    return const SwpResult(
      finalBalance: 0,
      totalWithdrawn: 0,
      totalReturns: 0,
      depletedMonth: null,
      yearlyRows: [],
    );
  }

  final totalMonths = (years * 12).floorToDouble();
  final monthlyRate = (annualRate / 100) / 12;

  var balance = corpus;
  var totalWithdrawn = 0.0;
  int? depletedMonth;
  final yearlyRows = <SwpYearlyRow>[];

  var currentYearWithdrawn = 0.0;
  var currentYearGrowth = 0.0;

  for (var m = 1; m <= totalMonths; m++) {
    final yearIndex = (m - 1) ~/ 12;
    final scheduledWithdrawal = monthlyWithdrawal * jsPow(1 + stepUp / 100, yearIndex.toDouble());

    var actualWithdrawal = 0.0;

    if (balance <= 0) {
      depletedMonth ??= m;
      actualWithdrawal = 0;
    } else if (balance < scheduledWithdrawal) {
      depletedMonth ??= m;
      actualWithdrawal = balance;
      balance = 0;
    } else {
      actualWithdrawal = scheduledWithdrawal;
      balance -= scheduledWithdrawal;
    }

    totalWithdrawn += actualWithdrawal;
    currentYearWithdrawn += actualWithdrawal;

    // Monthly growth applied to remaining balance after withdrawal
    final growthThisMonth = balance > 0 ? balance * monthlyRate : 0.0;
    balance += growthThisMonth;
    currentYearGrowth += growthThisMonth;

    // End of year or final month tracking
    if (m % 12 == 0 || m == totalMonths) {
      final yearNum = (m / 12).ceilToDouble();
      final exists = yearlyRows.any((r) => r.year == yearNum);
      if (!exists) {
        yearlyRows.add(SwpYearlyRow(
          year: yearNum,
          withdrawn: jsRound(currentYearWithdrawn),
          returns: jsRound(currentYearGrowth),
          balance: jsMax([0, jsRound(balance)]),
        ));
        currentYearWithdrawn = 0;
        currentYearGrowth = 0;
      }
    }
  }

  final finalBalance = jsMax([0, jsRound(balance)]);
  final roundedTotalWithdrawn = jsRound(totalWithdrawn);
  final totalReturns = jsRound(finalBalance + roundedTotalWithdrawn - corpus);

  return SwpResult(
    finalBalance: finalBalance,
    totalWithdrawn: roundedTotalWithdrawn,
    totalReturns: totalReturns,
    depletedMonth: depletedMonth,
    yearlyRows: yearlyRows,
  );
}
