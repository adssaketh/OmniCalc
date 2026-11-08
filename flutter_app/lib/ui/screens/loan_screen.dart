import 'package:flutter/widgets.dart';

import '../../engine/finance.dart';
import '../../engine/js_number.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import 'finance_widgets.dart';

const List<({String label, double value})> _principalPresets = [
  (label: '₹10 L', value: 1000000.0),
  (label: '₹25 L', value: 2500000.0),
  (label: '₹50 L', value: 5000000.0),
  (label: '₹75 L', value: 7500000.0),
  (label: '₹1 Cr', value: 10000000.0),
];

const List<({String label, double value})> _ratePresets = [
  (label: '8.5% Home', value: 8.5),
  (label: '9.5% Auto', value: 9.5),
  (label: '12% Personal', value: 12.0),
  (label: '14% Business', value: 14.0),
];

const List<double> _yearPresets = [5, 10, 15, 20, 25, 30];

/// Port of LoanCalculator.tsx (the "Loan / EMI" tab of the Finance screen).
class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key, this.currencySymbol = kRupee});

  final String currencySymbol;

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  // Inputs calibrated for an Indian home / personal loan
  double _principal = 2500000;
  double _rate = 8.5;
  double _years = 15;

  bool _showTaxes = false;
  bool _applyGstOnInterest = false;
  bool _includeProcessingFee = false;

  // Not editable in the web screen either: the constants of its useState calls.
  static const double _gstRateInterest = 18;
  static const String _processingFeeType = 'percent';
  static const double _processingFeeValue = 1.0;
  static const bool _applyGstOnProcessingFee = true;
  static const double _gstRateProcessingFee = 18;

  String get _sym => widget.currencySymbol;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final result = FinanceEngine.calculateLoan(
      _principal,
      _rate,
      _years,
      LoanCalculationOptions(
        applyGstOnInterest: _applyGstOnInterest,
        gstRateInterest: _gstRateInterest,
        includeProcessingFee: _includeProcessingFee,
        processingFeeType: _processingFeeType,
        processingFeeValue: _processingFeeValue,
        applyGstOnProcessingFee: _applyGstOnProcessingFee,
        gstRateProcessingFee: _gstRateProcessingFee,
      ),
    );

    // Ratio bar percentages
    final totalOutflow = orElse(result.grandTotalOutflow, result.totalPayment);
    final principalPercent = totalOutflow > 0 ? clampPct(jsRound((_principal / totalOutflow) * 100)) : 0.0;
    final interestPercent = totalOutflow > 0 ? clampPct(jsRound((result.totalInterest / totalOutflow) * 100)) : 0.0;
    final rawTaxes = 100 - principalPercent - interestPercent;
    final taxesFeesPercent = rawTaxes > 0 ? rawTaxes : 0.0;

    return FinanceLayout(
      inputs: [
        _principalCard(),
        _rateCard(),
        _tenureCard(),
        _taxesCard(t, result),
      ],
      results: _resultsCard(t, result, totalOutflow, principalPercent, interestPercent, taxesFeesPercent),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------------------------------------------------

  Widget _principalCard() {
    return InputCard(
      children: [
        const CardLabel('Loan Amount (Principal)'),
        FinanceNumberInput(
          inputKey: const ValueKey('loan-principal-input'),
          value: _principal,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _principal = v),
          placeholder: '25,00,000',
          prefix: _sym,
        ),
        if (_principal > 0) MonoHelper('$_sym${formatMoney(_principal)}', helperKey: const ValueKey('loan-principal-helper')),
        PresetChips(
          afterHelper: true,
          chips: [
            for (final p in _principalPresets)
              (
                key: ValueKey('loan-principal-preset-${jsToString(p.value)}'),
                label: p.label,
                active: _principal == p.value,
                onTap: () => setState(() => _principal = p.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _rateCard() {
    return InputCard(
      children: [
        CardHeader(
          label: 'Interest Rate (% p.a.)',
          value: '${jsToString(_rate)}% p.a.',
          accent: true,
          valueKey: const ValueKey('loan-rate-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('loan-rate-input'),
          value: _rate,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _rate = v),
          placeholder: '8.5',
          suffix: '%',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final p in _ratePresets)
              (
                key: ValueKey('loan-rate-preset-${jsToString(p.value)}'),
                label: p.label,
                active: _rate == p.value,
                onTap: () => setState(() => _rate = p.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tenureCard() {
    return InputCard(
      children: [
        CardHeader(
          label: 'Loan Tenure (Years)',
          value: '${jsToString(_years)} Years (${jsToString(_years * 12)} Months)',
          valueKey: const ValueKey('loan-years-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('loan-years-input'),
          value: _years,
          parse: (s) {
            final v = parseFloatOr0(s);
            return v < 1 ? 1.0 : v; // Math.max(1, ...)
          },
          onChanged: (v) => setState(() => _years = v),
          placeholder: '15',
          suffix: 'Yr',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final y in _yearPresets)
              (
                key: ValueKey('loan-years-preset-${jsToString(y)}'),
                label: '${jsToString(y)}Y',
                active: _years == y,
                onTap: () => setState(() => _years = y),
              ),
          ],
        ),
      ],
    );
  }

  Widget _taxesCard(M3Tokens t, LoanResult result) {
    final anyActive = _applyGstOnInterest || _includeProcessingFee;
    final textStyle = appText(size: 12, color: t.onSurface, height: 16 / 12);
    final monoMuted = appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true);
    return InputCard(
      children: [
        GestureDetector(
          key: const ValueKey('loan-taxes-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showTaxes = !_showTaxes),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Taxes & Bank Charges (Optional)',
                        style: appText(size: 12, weight: FontWeight.w600, color: t.onSurface, height: 16 / 12),
                      ),
                    ),
                    if (anyActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: const ValueKey('loan-taxes-active'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.primary.withValues(alpha: 0.15),
                          borderRadius: const BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text('Active', style: appText(size: 10, color: t.primary, height: 15 / 10, tabular: true)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LucideIcon(_showTaxes ? LucideIconId.chevronUp : LucideIconId.chevronDown, color: t.onSurface, size: 16),
            ],
          ),
        ),
        if (_showTaxes)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // GST on interest
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CheckLine(
                      checkKey: const ValueKey('loan-gst-check'),
                      checked: _applyGstOnInterest,
                      onChanged: (v) => setState(() => _applyGstOnInterest = v),
                      label: 'GST on Monthly Interest (18%)',
                      labelStyle: textStyle,
                    ),
                    if (_applyGstOnInterest)
                      Text(
                        '+$_sym${formatMoney(orElse(result.totalGstOnInterest, 0))}',
                        key: const ValueKey('loan-gst-amount'),
                        style: monoMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Processing fee
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CheckLine(
                      checkKey: const ValueKey('loan-fee-check'),
                      checked: _includeProcessingFee,
                      onChanged: (v) => setState(() => _includeProcessingFee = v),
                      label: 'Loan Origination / Processing Fee (1%)',
                      labelStyle: textStyle,
                    ),
                    if (_includeProcessingFee)
                      Text(
                        '$_sym${formatMoney(orElse(result.totalProcessingFeeWithGst, 0))} (incl. 18% GST)',
                        key: const ValueKey('loan-fee-amount'),
                        style: monoMuted,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Results
  // -------------------------------------------------------------------------------------------------------------------

  Widget _resultsCard(
    M3Tokens t,
    LoanResult result,
    double totalOutflow,
    double principalPercent,
    double interestPercent,
    double taxesFeesPercent,
  ) {
    final hs = headlineStyles(context, t);
    final accentTint = t.primary.withValues(alpha: t.isDark ? 0.12 : 0.10);
    return ResultsCard(
      background: t.surfaceContainer,
      children: [
        // Monthly EMI metric
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MetricCaption('Monthly EMI (Repayment)'),
              HeadlineRow(
                parts: [
                  (text: _sym, key: null, style: hs.symbol, extraGap: 0.0),
                  (text: formatMoney(result.monthlyPayment), key: const ValueKey('loan-emi'), style: hs.big, extraGap: 0.0),
                  (text: '/ month', key: null, style: headlineUnitStyle(t), extraGap: 4.0),
                ],
              ),
              if (_applyGstOnInterest)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Effective with GST: $_sym${formatMoney(orElse(result.effectiveMonthlyPayment, 0))}/mo',
                    key: const ValueKey('loan-effective-emi'),
                    style: appText(size: 12, color: amberNoteColor(t), height: 16 / 12, tabular: true),
                  ),
                ),
            ],
          ),
        ),

        // Ratio bar
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RatioBar(
                segments: [
                  (key: const ValueKey('loan-bar-principal'), percent: principalPercent, color: t.outline),
                  (key: const ValueKey('loan-bar-interest'), percent: interestPercent, color: t.primary),
                  if (taxesFeesPercent > 0) (key: const ValueKey('loan-bar-taxes'), percent: taxesFeesPercent, color: finAmber500),
                ],
              ),
              const SizedBox(height: 8),
              RatioLegend(
                wrap: true,
                entries: [
                  (
                    dot: t.outline,
                    label: 'Principal:',
                    value: '${jsToString(principalPercent)}%',
                    valueColor: t.onSurface,
                    valueKey: const ValueKey('loan-pct-principal'),
                  ),
                  (
                    dot: t.primary,
                    label: 'Interest:',
                    value: '${jsToString(interestPercent)}%',
                    valueColor: t.primary,
                    valueKey: const ValueKey('loan-pct-interest'),
                  ),
                  if (taxesFeesPercent > 0)
                    (
                      dot: finAmber500,
                      label: 'Taxes/Fees:',
                      value: '${jsToString(taxesFeesPercent)}%',
                      valueColor: amberNoteColor(t),
                      valueKey: const ValueKey('loan-pct-taxes'),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Two-metric grid
        MetricGrid(
          left: (
            key: null,
            valueKey: const ValueKey('loan-total-interest'),
            background: t.surfaceContainerLow,
            caption: 'Total Interest Payable',
            captionColor: t.onSurfaceVariant,
            value: '$_sym${formatMoney(result.totalInterest)}',
            valueColor: t.onSurface,
            valueWeight: FontWeight.w300,
          ),
          right: (
            key: null,
            valueKey: const ValueKey('loan-total-outflow'),
            background: accentTint,
            caption: 'Total Loan Outflow',
            captionColor: t.onSurfaceVariant,
            value: '$_sym${formatMoney(totalOutflow)}',
            valueColor: t.primary,
            valueWeight: FontWeight.w300,
          ),
        ),

        // Upfront disbursement breakdown if the fee is on
        if (_includeProcessingFee)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text('Net Loan Disbursed:', style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true)),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_sym${formatMoney(orElse(result.netDisbursedAmount, 0))}',
                  key: const ValueKey('loan-net-disbursed'),
                  style: appText(size: 12, weight: FontWeight.w600, color: emeraldColor(t), height: 16 / 12, tabular: true),
                ),
              ],
            ),
          ),

        const Footnote(
          'Estimate only based on standard monthly reducing balance method. Actual bank terms, prepayment penalties, and processing schedules may differ.',
        ),

        // Collapsible year-by-year amortization schedule
        if (result.schedule.isNotEmpty)
          CollapsibleTable(
            toggleKey: const ValueKey('loan-schedule-toggle'),
            title: 'Annual Amortization Schedule (${result.schedule.length} Years)',
            titleColor: t.onSurfaceVariant,
            headers: const ['Year', 'Principal', 'Interest', 'Balance'],
            rows: [
              for (final row in result.schedule)
                [
                  (text: 'Yr ${jsToString(row.period)}', color: t.onSurfaceVariant, weight: FontWeight.w400),
                  (text: '$_sym${formatMoney(row.principal)}', color: t.onSurface, weight: FontWeight.w400),
                  (text: '$_sym${formatMoney(row.interest)}', color: amberCellColor(t), weight: FontWeight.w500),
                  (text: '$_sym${formatMoney(row.balance)}', color: t.onSurface, weight: FontWeight.w500),
                ],
            ],
          ),
      ],
    );
  }
}
