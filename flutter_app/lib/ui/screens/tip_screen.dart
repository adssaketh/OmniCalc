import 'package:flutter/widgets.dart';

import '../../engine/finance.dart';
import '../../engine/js_number.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'finance_widgets.dart';

const List<double> _tipPresets = [5, 10, 12, 15, 18, 20];
const List<double> _peoplePresets = [1, 2, 3, 4, 5, 6, 8];

/// Port of TipCalculator.tsx (the "Tip & Bill" tab of the Finance screen).
class TipScreen extends StatefulWidget {
  const TipScreen({super.key, this.currencySymbol = kRupee});

  final String currencySymbol;

  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends State<TipScreen> {
  double _bill = 2400;
  double _tipPercent = 10;
  double _people = 4;
  bool _roundUp = false;

  String get _sym => widget.currencySymbol;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final result = FinanceEngine.calculateTip(_bill, _tipPercent, _people, _roundUp);

    // Ratio bar percentages
    final total = result.billTotal;
    final basePercent = total > 0 ? clampPct(jsRound(((total - result.tipTotal) / total) * 100)) : 0.0;
    final rawTip = 100 - basePercent;
    final tipRatioPercent = rawTip > 0 ? rawTip : 0.0;

    return FinanceLayout(
      inputs: [
        _billCard(),
        _tipCard(),
        _peopleCard(),
        _roundUpCard(t),
      ],
      results: _resultsCard(t, result, basePercent, tipRatioPercent),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------------------------------------------------

  Widget _billCard() {
    return InputCard(
      children: [
        const CardLabel('Bill Subtotal'),
        FinanceNumberInput(
          inputKey: const ValueKey('tip-bill-input'),
          value: _bill,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _bill = v),
          placeholder: '2,400',
          prefix: _sym,
        ),
      ],
    );
  }

  Widget _tipCard() {
    return InputCard(
      children: [
        CardHeader(
          label: 'Tip Percentage',
          value: '${jsToString(_tipPercent)}%',
          accent: true,
          valueKey: const ValueKey('tip-percent-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('tip-percent-input'),
          value: _tipPercent,
          parse: (s) {
            final v = parseFloatOr0(s);
            return v < 0 ? 0.0 : v; // Math.max(0, ...)
          },
          onChanged: (v) => setState(() => _tipPercent = v),
          placeholder: '10',
          suffix: '%',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final pct in _tipPresets)
              (
                key: ValueKey('tip-percent-preset-${jsToString(pct)}'),
                label: '${jsToString(pct)}%',
                active: _tipPercent == pct,
                onTap: () => setState(() => _tipPercent = pct),
              ),
          ],
        ),
      ],
    );
  }

  Widget _peopleCard() {
    return InputCard(
      children: [
        CardHeader(
          label: 'Split with (People)',
          value: '${jsToString(_people)} ${_people == 1 ? 'Person' : 'People'}',
          valueKey: const ValueKey('tip-people-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('tip-people-input'),
          value: _people,
          parse: (s) {
            // Math.max(1, parseInt(value) || 1)
            final p = jsParseInt(s);
            final v = (p.isNaN || p == 0) ? 1.0 : p;
            return v < 1 ? 1.0 : v;
          },
          onChanged: (v) => setState(() => _people = v),
          placeholder: '4',
          suffix: 'Ppl',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final n in _peoplePresets)
              (
                key: ValueKey('tip-people-preset-${jsToString(n)}'),
                label: '${jsToString(n)} ${n == 1 ? 'Person' : 'Ppl'}',
                active: _people == n,
                onTap: () => setState(() => _people = n),
              ),
          ],
        ),
      ],
    );
  }

  Widget _roundUpCard(M3Tokens t) {
    return InputCard(
      row: true,
      children: [
        Flexible(
          child: CheckLine(
            checkKey: const ValueKey('tip-roundup-check'),
            checked: _roundUp,
            onChanged: (v) => setState(() => _roundUp = v),
            label: 'Round up total per person to nearest whole number',
            gap: 10,
            labelStyle: appText(size: 12, weight: FontWeight.w500, color: t.onSurface, height: 16 / 12),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Results
  // -------------------------------------------------------------------------------------------------------------------

  Widget _resultsCard(M3Tokens t, TipResult result, double basePercent, double tipRatioPercent) {
    final hs = headlineStyles(context, t);
    final accentTint = t.primary.withValues(alpha: t.isDark ? 0.12 : 0.10);
    final detailStyle = appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true);
    return ResultsCard(
      background: t.surfaceContainer,
      children: [
        // Per-person metric
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MetricCaption('Per Person Share'),
              HeadlineRow(
                parts: [
                  (text: _sym, key: null, style: hs.symbol, extraGap: 0.0),
                  (text: formatMoney(result.perPersonTotal), key: const ValueKey('tip-per-person'), style: hs.big, extraGap: 0.0),
                  (text: '/ each', key: null, style: headlineUnitStyle(t), extraGap: 4.0),
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
                  (key: const ValueKey('tip-bar-base'), percent: basePercent, color: t.outline),
                  (key: const ValueKey('tip-bar-tip'), percent: tipRatioPercent, color: t.primary),
                ],
              ),
              const SizedBox(height: 8),
              RatioLegend(
                entries: [
                  (
                    dot: t.outline,
                    label: 'Base Food/Service:',
                    value: '${jsToString(basePercent)}%',
                    valueColor: t.onSurface,
                    valueKey: const ValueKey('tip-pct-base'),
                  ),
                  (
                    dot: t.primary,
                    label: 'Tip:',
                    value: '${jsToString(tipRatioPercent)}%',
                    valueColor: t.primary,
                    valueKey: const ValueKey('tip-pct-tip'),
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
            valueKey: const ValueKey('tip-bill-total'),
            background: t.surfaceContainerLow,
            caption: 'Total Bill (incl. Tip)',
            captionColor: t.onSurfaceVariant,
            value: '$_sym${formatMoney(result.billTotal)}',
            valueColor: t.onSurface,
            valueWeight: FontWeight.w300,
          ),
          right: (
            key: null,
            valueKey: const ValueKey('tip-tip-total'),
            background: accentTint,
            caption: 'Total Tip Amount',
            captionColor: t.onSurfaceVariant,
            value: '+$_sym${formatMoney(result.tipTotal)}',
            valueColor: t.primary,
            valueWeight: FontWeight.w300,
          ),
        ),

        // Person breakdown details
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                flex: flexFor(measureText(context, 'Base per person: $_sym${formatMoney(result.perPersonBase)}', detailStyle)),
                child: Text(
                  'Base per person: $_sym${formatMoney(result.perPersonBase)}',
                  key: const ValueKey('tip-base-per-person'),
                  style: detailStyle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: flexFor(measureText(context, 'Tip per person: $_sym${formatMoney(result.perPersonTip)}', detailStyle)),
                child: Text(
                  'Tip per person: $_sym${formatMoney(result.perPersonTip)}',
                  key: const ValueKey('tip-tip-per-person'),
                  textAlign: TextAlign.end,
                  style: detailStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
