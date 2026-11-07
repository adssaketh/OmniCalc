import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/finance.dart';

import 'golden_expect.dart';
import 'golden_loader.dart';

// Vectors produced by running the real TypeScript engine (see tools/gen_vectors.ts). raw doubles: 1e-9 relative.
void main() {
  group('loan', () {
    final vectors = (loadGolden('loan') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(20)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final inp = v['in'] as Map<String, dynamic>;
      test('#$i ${inp['p']} @ ${inp['r']}% for ${inp['t']}y ${inp['o'] ?? ''}', () {
        final o = inp['o'] as Map<String, dynamic>?;
        final options = o == null
            ? null
            : LoanCalculationOptions(
                includeProcessingFee: o['includeProcessingFee'] as bool?,
                processingFeeType: o['processingFeeType'] as String?,
                processingFeeValue: o.containsKey('processingFeeValue') ? toD(o['processingFeeValue']) : null,
                applyGstOnProcessingFee: o['applyGstOnProcessingFee'] as bool?,
                gstRateProcessingFee: o.containsKey('gstRateProcessingFee') ? toD(o['gstRateProcessingFee']) : null,
                applyGstOnInterest: o['applyGstOnInterest'] as bool?,
                gstRateInterest: o.containsKey('gstRateInterest') ? toD(o['gstRateInterest']) : null,
              );
        final r = FinanceEngine.calculateLoan(toD(inp['p']), toD(inp['r']), toD(inp['t']), options);
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.monthlyPayment, want['monthlyPayment'], 'monthlyPayment');
        expectNum(r.totalPayment, want['totalPayment'], 'totalPayment');
        expectNum(r.totalInterest, want['totalInterest'], 'totalInterest');
        expectNum(r.processingFeeAmount, want['processingFeeAmount'], 'processingFeeAmount');
        expectNum(r.gstOnProcessingFee, want['gstOnProcessingFee'], 'gstOnProcessingFee');
        expectNum(r.totalProcessingFeeWithGst, want['totalProcessingFeeWithGst'], 'totalProcessingFeeWithGst');
        expectNum(r.netDisbursedAmount, want['netDisbursedAmount'], 'netDisbursedAmount');
        expectNum(r.totalGstOnInterest, want['totalGstOnInterest'], 'totalGstOnInterest');
        expectNum(r.monthlyGstAvg, want['monthlyGstAvg'], 'monthlyGstAvg');
        expectNum(r.effectiveMonthlyPayment, want['effectiveMonthlyPayment'], 'effectiveMonthlyPayment');
        expectNum(r.grandTotalOutflow, want['grandTotalOutflow'], 'grandTotalOutflow');
        final rows = (want['schedule'] as List).cast<Map<String, dynamic>>();
        expect(r.schedule.length, rows.length, reason: 'schedule length');
        for (var k = 0; k < rows.length; k++) {
          expectNum(r.schedule[k].period, rows[k]['period'], 'schedule[$k].period');
          expectNum(r.schedule[k].payment, rows[k]['payment'], 'schedule[$k].payment');
          expectNum(r.schedule[k].principal, rows[k]['principal'], 'schedule[$k].principal');
          expectNum(r.schedule[k].interest, rows[k]['interest'], 'schedule[$k].interest');
          expectNum(r.schedule[k].gstOnInterest, rows[k]['gstOnInterest'], 'schedule[$k].gstOnInterest');
          expectNum(r.schedule[k].balance, rows[k]['balance'], 'schedule[$k].balance');
        }
      });
    }
  });

  group('compound', () {
    final vectors = (loadGolden('compound') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(10)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = (v['in'] as List).map(toD).toList();
      test('#$i ${v['in']}', () {
        final r = switch (a.length) {
          4 => FinanceEngine.calculateCompoundInterest(a[0], a[1], a[2], a[3]),
          5 => FinanceEngine.calculateCompoundInterest(a[0], a[1], a[2], a[3], a[4]),
          _ => FinanceEngine.calculateCompoundInterest(a[0], a[1], a[2], a[3], a[4], a[5]),
        };
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.endBalance, want['endBalance'], 'endBalance');
        expectNum(r.totalInvested, want['totalInvested'], 'totalInvested');
        expectNum(r.totalInterest, want['totalInterest'], 'totalInterest');
        final rows = (want['yearlyBreakdown'] as List).cast<Map<String, dynamic>>();
        expect(r.yearlyBreakdown.length, rows.length, reason: 'yearlyBreakdown length');
        for (var k = 0; k < rows.length; k++) {
          expectNum(r.yearlyBreakdown[k].year, rows[k]['year'], 'row[$k].year');
          expectNum(r.yearlyBreakdown[k].monthlyContribution, rows[k]['monthlyContribution'], 'row[$k].monthlyContribution');
          expectNum(r.yearlyBreakdown[k].balance, rows[k]['balance'], 'row[$k].balance');
          expectNum(r.yearlyBreakdown[k].deposits, rows[k]['deposits'], 'row[$k].deposits');
          expectNum(r.yearlyBreakdown[k].interestAccrued, rows[k]['interestAccrued'], 'row[$k].interestAccrued');
        }
      });
    }
  });

  group('tip', () {
    final vectors = (loadGolden('tip') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(10)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = v['in'] as List;
      test('#$i $a', () {
        final r = a.length > 3
            ? FinanceEngine.calculateTip(toD(a[0]), toD(a[1]), toD(a[2]), a[3] as bool)
            : FinanceEngine.calculateTip(toD(a[0]), toD(a[1]), toD(a[2]));
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.tipTotal, want['tipTotal'], 'tipTotal');
        expectNum(r.billTotal, want['billTotal'], 'billTotal');
        expectNum(r.perPersonTotal, want['perPersonTotal'], 'perPersonTotal');
        expectNum(r.perPersonTip, want['perPersonTip'], 'perPersonTip');
        expectNum(r.perPersonBase, want['perPersonBase'], 'perPersonBase');
      });
    }
  });

  group('roi', () {
    final vectors = (loadGolden('roi') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(7)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = (v['in'] as List).map(toD).toList();
      test('#$i ${v['in']}', () {
        final r = FinanceEngine.calculateROI(a[0], a[1], a[2]);
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.gainLoss, want['gainLoss'], 'gainLoss');
        expectNum(r.roiPercent, want['roiPercent'], 'roiPercent');
        expectNum(r.cagrPercent, want['cagrPercent'], 'cagrPercent');
      });
    }
  });

  group('depreciation', () {
    final vectors = (loadGolden('depreciation') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(6)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = (v['in'] as List).map(toD).toList();
      test('#$i ${v['in']}', () {
        final r = FinanceEngine.calculateDepreciation(a[0], a[1], a[2]);
        final rows = (v['out'] as List).cast<Map<String, dynamic>>();
        expect(r.length, rows.length, reason: 'row count');
        for (var k = 0; k < rows.length; k++) {
          expectNum(r[k].year, rows[k]['year'], 'row[$k].year');
          expectNum(r[k].depreciation, rows[k]['depreciation'], 'row[$k].depreciation');
          expectNum(r[k].bookValue, rows[k]['bookValue'], 'row[$k].bookValue');
        }
      });
    }
  });

  group('swp', () {
    final vectors = (loadGolden('swp') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(14)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final inp = v['in'];
      test('#$i $inp', () {
        final SwpResult r;
        if (inp is List) {
          final a = inp.map(toD).toList();
          r = FinanceEngine.calculateSWP(
            a[0],
            a.length > 1 ? a[1] : null,
            a.length > 2 ? a[2] : null,
            a.length > 3 ? a[3] : null,
            a.length > 4 ? a[4] : null,
          );
        } else {
          final m = inp as Map<String, dynamic>;
          r = FinanceEngine.calculateSWPInput(SwpInput(
            corpus: toD(m['corpus']),
            monthlyWithdrawal: toD(m['monthlyWithdrawal']),
            annualRate: toD(m['annualRate']),
            years: toD(m['years']),
            stepUp: m.containsKey('stepUp') ? toD(m['stepUp']) : 0,
          ));
        }
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.finalBalance, want['finalBalance'], 'finalBalance');
        expectNum(r.totalWithdrawn, want['totalWithdrawn'], 'totalWithdrawn');
        expectNum(r.totalReturns, want['totalReturns'], 'totalReturns');
        if (want['depletedMonth'] == null) {
          expect(r.depletedMonth, isNull, reason: 'depletedMonth');
        } else {
          expect(r.depletedMonth, isNotNull, reason: 'depletedMonth');
          expectNum(r.depletedMonth!.toDouble(), want['depletedMonth'], 'depletedMonth');
        }
        final rows = (want['yearlyRows'] as List).cast<Map<String, dynamic>>();
        expect(r.yearlyRows.length, rows.length, reason: 'yearlyRows length');
        for (var k = 0; k < rows.length; k++) {
          expectNum(r.yearlyRows[k].year, rows[k]['year'], 'row[$k].year');
          expectNum(r.yearlyRows[k].withdrawn, rows[k]['withdrawn'], 'row[$k].withdrawn');
          expectNum(r.yearlyRows[k].returns, rows[k]['returns'], 'row[$k].returns');
          expectNum(r.yearlyRows[k].balance, rows[k]['balance'], 'row[$k].balance');
        }
      });
    }
  });
}
