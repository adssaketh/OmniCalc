import 'package:flutter/widgets.dart';

import '../../engine/finance.dart';
import '../../engine/js_number.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import 'finance_widgets.dart';
import 'screen_utils.dart';

const List<({String label, double value})> _ratePresets = [
  (label: '6% Safe', value: 6.0),
  (label: '8% Hybrid', value: 8.0),
  (label: '10% Balanced', value: 10.0),
  (label: '12% Equity', value: 12.0),
];

const List<double> _yearPresets = [5, 10, 15, 20, 25, 30];

/// `Your corpus runs out after about ...` (SWPCalculator.tsx `depletionText`), or null when the money lasts.
String? swpDepletionText(int? depletedMonth) {
  if (depletedMonth == null) return null;
  final months = depletedMonth - 1;
  final y = months ~/ 12;
  final m = months % 12;
  final String timeStr;
  if (y > 0 && m > 0) {
    timeStr = '$y yr $m mo';
  } else if (y > 0) {
    timeStr = '$y yr';
  } else {
    timeStr = '$m mo';
  }
  return 'Your corpus runs out after about $timeStr. Lower the withdrawal or raise the return rate to last longer.';
}

/// `((monthlyWithdrawal * 12 / corpus) * 100).toFixed(1)`, or null when it is not shown.
String? swpWithdrawalPctPerYear(double corpus, double monthlyWithdrawal) {
  if (corpus > 0 && monthlyWithdrawal >= 0) {
    return jsToFixed((monthlyWithdrawal * 12 / corpus) * 100, 1);
  }
  return null;
}

/// Port of SWPCalculator.tsx (the "SWP" tab of the Finance screen). The rupee sign is fixed in the web component.
class SwpScreen extends StatefulWidget {
  const SwpScreen({super.key});

  @override
  State<SwpScreen> createState() => _SwpScreenState();
}

class _SwpScreenState extends State<SwpScreen> {
  double _corpus = 1000000;
  double _monthlyWithdrawal = 8000;
  double _rate = 8;
  double _years = 10;
  double _stepUp = 0;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final result = calculateSwp(
      SwpInput(corpus: _corpus, monthlyWithdrawal: _monthlyWithdrawal, annualRate: _rate, years: _years, stepUp: _stepUp),
    );

    // Ratio bar percentages
    final totalPool = result.totalWithdrawn + result.finalBalance;
    final withdrawnPercent = totalPool > 0 ? clampPct(jsRound((result.totalWithdrawn / totalPool) * 100)) : 0.0;
    final remainingPercent = 100 - withdrawnPercent;

    return FinanceLayout(
      inputs: [
        _corpusCard(t),
        _withdrawalCard(t),
        _rateCard(),
        _yearsCard(),
        _stepUpCard(),
      ],
      results: _resultsCard(t, result, withdrawnPercent, remainingPercent),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------------------------------------------------

  Widget _corpusCard(M3Tokens t) {
    return InputCard(
      children: [
        const CardLabel('Total Investment (Corpus)'),
        FinanceNumberInput(
          inputKey: const ValueKey('swp-corpus-input'),
          value: _corpus,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _corpus = v),
          placeholder: '10,00,000',
          prefix: kRupee,
        ),
        if (_corpus > 0) MonoHelper('$kRupee${formatMoney(_corpus)}', helperKey: const ValueKey('swp-corpus-helper')),
      ],
    );
  }

  Widget _withdrawalCard(M3Tokens t) {
    final pct = swpWithdrawalPctPerYear(_corpus, _monthlyWithdrawal);
    return InputCard(
      children: [
        const CardLabel('Withdrawal per Month'),
        FinanceNumberInput(
          inputKey: const ValueKey('swp-withdrawal-input'),
          value: _monthlyWithdrawal,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _monthlyWithdrawal = v),
          placeholder: '8,000',
          prefix: kRupee,
        ),
        if (pct != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$pct%',
                  key: const ValueKey('swp-withdrawal-pct'),
                  style: appText(size: 12, weight: FontWeight.w500, color: t.onSurface, height: 16 / 12, tabular: true),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text('of corpus per year', style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rateCard() {
    return InputCard(
      children: [
        CardHeader(
          label: 'Expected Annual Return Rate',
          value: '${jsToString(_rate)}% p.a.',
          accent: true,
          valueKey: const ValueKey('swp-rate-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('swp-rate-input'),
          value: _rate,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _rate = v),
          placeholder: '8',
          suffix: '%',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final p in _ratePresets)
              (
                key: ValueKey('swp-rate-preset-${jsToString(p.value)}'),
                label: p.label,
                active: _rate == p.value,
                onTap: () => setState(() => _rate = p.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _yearsCard() {
    return InputCard(
      children: [
        CardHeader(
          label: 'Withdrawal Period (Years)',
          value: '${jsToString(_years)} Years (${jsToString(_years * 12)} Months)',
          valueKey: const ValueKey('swp-years-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('swp-years-input'),
          value: _years,
          parse: (s) {
            final v = parseFloatOr0(s);
            return v < 1 ? 1.0 : v; // Math.max(1, ...)
          },
          onChanged: (v) => setState(() => _years = v),
          placeholder: '10',
          suffix: 'Yr',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final y in _yearPresets)
              (
                key: ValueKey('swp-years-preset-${jsToString(y)}'),
                label: '${jsToString(y)}Y',
                active: _years == y,
                onTap: () => setState(() => _years = y),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepUpCard() {
    return InputCard(
      children: [
        const CardLabel('Yearly Increase in Withdrawal (optional)'),
        FinanceNumberInput(
          inputKey: const ValueKey('swp-stepup-input'),
          value: _stepUp,
          parse: (s) {
            final v = parseFloatOr0(s);
            return v < 0 ? 0.0 : v; // Math.max(0, ...)
          },
          onChanged: (v) => setState(() => _stepUp = v),
          placeholder: '0',
          suffix: '%',
        ),
        const PlainHelper('Annual step-up to counteract inflation'),
      ],
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Results
  // -------------------------------------------------------------------------------------------------------------------

  Widget _resultsCard(M3Tokens t, SwpResult result, double withdrawnPercent, double remainingPercent) {
    final bp = Breakpoints.of(context);
    final hs = headlineStyles(context, t);
    final depletion = swpDepletionText(result.depletedMonth);
    return ResultsCard(
      background: t.surfaceContainerLow,
      children: [
        // Final balance metric
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricCaption('Final Value After ${jsToString(_years)} Years', captionKey: const ValueKey('swp-caption')),
              HeadlineRow(
                parts: [
                  (text: kRupee, key: null, style: hs.symbol, extraGap: 0.0),
                  (text: formatMoney(result.finalBalance), key: const ValueKey('swp-final-balance'), style: hs.big, extraGap: 0.0),
                ],
              ),
            ],
          ),
        ),

        // Amber depletion warning
        if (result.depletedMonth != null && depletion != null)
          Container(
            key: const ValueKey('swp-depletion-warning'),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: finAmber500.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: LucideIcon(LucideIconId.alertTriangle, color: finAmber500, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    depletion,
                    key: const ValueKey('swp-depletion-text'),
                    style: appText(
                      size: bp.sm ? 14 : 12,
                      weight: FontWeight.w500,
                      color: finAmber500,
                      height: 1.625,
                    ),
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
                  (key: const ValueKey('swp-bar-withdrawn'), percent: withdrawnPercent, color: t.outline),
                  (key: const ValueKey('swp-bar-remaining'), percent: remainingPercent, color: t.primary),
                ],
              ),
              const SizedBox(height: 8),
              RatioLegend(
                entries: [
                  (
                    dot: t.outline,
                    label: 'Total Withdrawn:',
                    value: '${jsToString(withdrawnPercent)}%',
                    valueColor: t.onSurface,
                    valueKey: const ValueKey('swp-pct-withdrawn'),
                  ),
                  (
                    dot: t.primary,
                    label: 'Remaining:',
                    value: '${jsToString(remainingPercent)}%',
                    valueColor: t.primary,
                    valueKey: const ValueKey('swp-pct-remaining'),
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
            valueKey: const ValueKey('swp-total-withdrawn'),
            background: t.surfaceContainer,
            caption: 'Total Withdrawn',
            captionColor: t.onSurfaceVariant,
            value: '$kRupee${formatMoney(result.totalWithdrawn)}',
            valueColor: t.onSurface,
            valueWeight: FontWeight.w300,
          ),
          right: (
            key: null,
            valueKey: const ValueKey('swp-total-returns'),
            background: t.primaryContainer,
            caption: 'Total Returns Earned',
            captionColor: t.onPrimaryContainer,
            value: '${result.totalReturns >= 0 ? '+' : ''}$kRupee${formatMoney(result.totalReturns)}',
            valueColor: t.onPrimaryContainer,
            valueWeight: FontWeight.w700, // font-light and font-bold are both on the element; bold comes later in the CSS
          ),
        ),

        const Footnote(
          "Estimate only. Each month's withdrawal is taken at the start of the month, and the rest earns the monthly rate (annual rate ÷ 12). Taxes, exit loads and market swings are not included.",
        ),

        // Collapsible year-by-year withdrawal timeline
        if (result.yearlyRows.isNotEmpty)
          CollapsibleTable(
            toggleKey: const ValueKey('swp-timeline-toggle'),
            title: 'Year-by-Year Withdrawal Timeline',
            titleColor: t.onSurface,
            chevronColor: t.onSurfaceVariant,
            headers: const ['Year', 'Withdrawn', 'Returns', 'Balance'],
            rows: [
              for (final row in result.yearlyRows)
                [
                  (text: 'Yr ${jsToString(row.year)}', color: t.onSurfaceVariant, weight: FontWeight.w400),
                  (text: '$kRupee${formatMoney(row.withdrawn)}', color: t.onSurface, weight: FontWeight.w400),
                  (text: '+${formatMoney(row.returns)}', color: emeraldColor(t), weight: FontWeight.w400),
                  (text: '$kRupee${formatMoney(row.balance)}', color: t.onSurface, weight: FontWeight.w500),
                ],
            ],
          ),
      ],
    );
  }
}
