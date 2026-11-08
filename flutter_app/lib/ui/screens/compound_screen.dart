import 'package:flutter/widgets.dart';

import '../../engine/finance.dart';
import '../../engine/js_number.dart';
import '../../theme/tokens.dart';
import 'finance_widgets.dart';

const List<({String label, double value})> _sipPresets = [
  (label: '₹2,000', value: 2000.0),
  (label: '₹5,000', value: 5000.0),
  (label: '₹10,000', value: 10000.0),
  (label: '₹25,000', value: 25000.0),
];

const List<({String label, double value})> _ratePresets = [
  (label: '8% Debt', value: 8.0),
  (label: '10% Balanced', value: 10.0),
  (label: '12% Equity', value: 12.0),
  (label: '15% Aggressive', value: 15.0),
];

const List<double> _yearPresets = [5, 10, 15, 20, 25, 30];
const List<double> _stepUpPresets = [0, 5, 10, 15, 20];

/// Port of CompoundCalculator.tsx (the "SIP & Compound" tab of the Finance screen).
class CompoundScreen extends StatefulWidget {
  const CompoundScreen({super.key, this.currencySymbol = kRupee});

  final String currencySymbol;

  @override
  State<CompoundScreen> createState() => _CompoundScreenState();
}

class _CompoundScreenState extends State<CompoundScreen> {
  double _monthlySip = 5000;
  double _initialDeposit = 50000;
  double _rate = 12;
  double _years = 10;
  double _stepUp = 10;

  String get _sym => widget.currencySymbol;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final result = FinanceEngine.calculateCompoundInterest(_initialDeposit, _monthlySip, _rate, _years, _stepUp);

    // Ratio bar percentages
    final totalWealth = result.endBalance;
    final investedPercent = totalWealth > 0 ? clampPct(jsRound((result.totalInvested / totalWealth) * 100)) : 0.0;
    final rawGains = 100 - investedPercent;
    final gainsPercent = rawGains > 0 ? rawGains : 0.0;

    return FinanceLayout(
      inputs: [
        _sipCard(),
        _initialCard(),
        _rateCard(),
        _yearsCard(),
        _stepUpCard(),
      ],
      results: _resultsCard(t, result, investedPercent, gainsPercent),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------------------------------------------------

  Widget _sipCard() {
    return InputCard(
      children: [
        const CardLabel('Monthly SIP Amount'),
        FinanceNumberInput(
          inputKey: const ValueKey('compound-sip-input'),
          value: _monthlySip,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _monthlySip = v),
          placeholder: '5,000',
          prefix: _sym,
        ),
        if (_monthlySip > 0) MonoHelper('$_sym${formatMoney(_monthlySip)} / month', helperKey: const ValueKey('compound-sip-helper')),
        PresetChips(
          afterHelper: true,
          chips: [
            for (final p in _sipPresets)
              (
                key: ValueKey('compound-sip-preset-${jsToString(p.value)}'),
                label: p.label,
                active: _monthlySip == p.value,
                onTap: () => setState(() => _monthlySip = p.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _initialCard() {
    return InputCard(
      children: [
        const CardLabel('Initial Lump Sum (Optional Deposit)'),
        FinanceNumberInput(
          inputKey: const ValueKey('compound-initial-input'),
          value: _initialDeposit,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _initialDeposit = v),
          placeholder: '50,000',
          prefix: _sym,
        ),
        if (_initialDeposit > 0)
          MonoHelper('Starting corpus: $_sym${formatMoney(_initialDeposit)}', helperKey: const ValueKey('compound-initial-helper')),
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
          valueKey: const ValueKey('compound-rate-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('compound-rate-input'),
          value: _rate,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _rate = v),
          placeholder: '12',
          suffix: '%',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final p in _ratePresets)
              (
                key: ValueKey('compound-rate-preset-${jsToString(p.value)}'),
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
          label: 'Investment Horizon (Years)',
          value: '${jsToString(_years)} Years (${jsToString(_years * 12)} Installments)',
          valueKey: const ValueKey('compound-years-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('compound-years-input'),
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
                key: ValueKey('compound-years-preset-${jsToString(y)}'),
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
        CardHeader(
          label: 'Annual Step-Up (% / year)',
          value: _stepUp > 0 ? '+${jsToString(_stepUp)}% every year' : 'Flat SIP',
          valueKey: const ValueKey('compound-stepup-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('compound-stepup-input'),
          value: _stepUp,
          parse: (s) {
            final v = parseFloatOr0(s);
            return v < 0 ? 0.0 : v; // Math.max(0, ...)
          },
          onChanged: (v) => setState(() => _stepUp = v),
          placeholder: '10',
          suffix: '%',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final pct in _stepUpPresets)
              (
                key: ValueKey('compound-stepup-preset-${jsToString(pct)}'),
                label: pct == 0 ? 'No Step-Up' : '+${jsToString(pct)}% / yr',
                active: _stepUp == pct,
                onTap: () => setState(() => _stepUp = pct),
              ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Results
  // -------------------------------------------------------------------------------------------------------------------

  Widget _resultsCard(M3Tokens t, CompoundResult result, double investedPercent, double gainsPercent) {
    final hs = headlineStyles(context, t);
    final accentTint = t.primary.withValues(alpha: t.isDark ? 0.12 : 0.10);
    return ResultsCard(
      background: t.surfaceContainer,
      children: [
        // Final corpus metric
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricCaption('Total Expected Wealth After ${jsToString(_years)} Years', captionKey: const ValueKey('compound-caption')),
              HeadlineRow(
                parts: [
                  (text: _sym, key: null, style: hs.symbol, extraGap: 0.0),
                  (text: formatMoney(result.endBalance), key: const ValueKey('compound-end-balance'), style: hs.big, extraGap: 0.0),
                ],
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
                  (key: const ValueKey('compound-bar-invested'), percent: investedPercent, color: t.outline),
                  (key: const ValueKey('compound-bar-gains'), percent: gainsPercent, color: t.primary),
                ],
              ),
              const SizedBox(height: 8),
              RatioLegend(
                entries: [
                  (
                    dot: t.outline,
                    label: 'Amount Invested:',
                    value: '${jsToString(investedPercent)}%',
                    valueColor: t.onSurface,
                    valueKey: const ValueKey('compound-pct-invested'),
                  ),
                  (
                    dot: t.primary,
                    label: 'Wealth Gain:',
                    value: '${jsToString(gainsPercent)}%',
                    valueColor: t.primary,
                    valueKey: const ValueKey('compound-pct-gains'),
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
            valueKey: const ValueKey('compound-total-invested'),
            background: t.surfaceContainerLow,
            caption: 'Total Amount Invested',
            captionColor: t.onSurfaceVariant,
            value: '$_sym${formatMoney(result.totalInvested)}',
            valueColor: t.onSurface,
            valueWeight: FontWeight.w300,
          ),
          right: (
            key: null,
            valueKey: const ValueKey('compound-total-gain'),
            background: accentTint,
            caption: 'Estimated Wealth Gain',
            captionColor: t.onSurfaceVariant,
            value: '+$_sym${formatMoney(result.totalInterest)}',
            valueColor: t.primary,
            valueWeight: FontWeight.w300,
          ),
        ),

        const Footnote(
          'Estimate only. Assumes regular monthly compounding with annual step-up. Mutual fund investments are subject to market risks; past performance does not guarantee future results.',
        ),

        // Collapsible year-by-year growth timeline
        if (result.yearlyBreakdown.isNotEmpty)
          CollapsibleTable(
            toggleKey: const ValueKey('compound-timeline-toggle'),
            title: 'Year-by-Year Wealth Progression',
            titleColor: t.onSurfaceVariant,
            headers: const ['Year', 'Monthly SIP', 'Invested', 'Growth', 'Corpus'],
            rows: [
              for (final row in result.yearlyBreakdown)
                [
                  (text: 'Yr ${jsToString(row.year)}', color: t.onSurfaceVariant, weight: FontWeight.w400),
                  (
                    text: row.year == 0 ? '-' : '$_sym${formatMoney(row.monthlyContribution)}/m',
                    color: t.onSurface,
                    weight: FontWeight.w400,
                  ),
                  (text: '$_sym${formatMoney(row.deposits)}', color: t.onSurface, weight: FontWeight.w400),
                  (text: '+$_sym${formatMoney(row.interestAccrued)}', color: emeraldColor(t), weight: FontWeight.w500),
                  (text: '$_sym${formatMoney(row.balance)}', color: t.onSurface, weight: FontWeight.w500),
                ],
            ],
          ),
      ],
    );
  }
}
