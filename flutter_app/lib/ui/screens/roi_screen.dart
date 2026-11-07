import 'package:flutter/widgets.dart';

import '../../engine/finance.dart';
import '../../engine/js_number.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'finance_widgets.dart';
import 'screen_utils.dart';

const List<double> _yearPresets = [1, 2, 3, 5, 7, 10, 15];

/// Port of ROICalculator.tsx (the "ROI & CAGR" tab of the Finance screen).
class RoiScreen extends StatefulWidget {
  const RoiScreen({super.key, this.currencySymbol = kRupee});

  final String currencySymbol;

  @override
  State<RoiScreen> createState() => _RoiScreenState();
}

class _RoiScreenState extends State<RoiScreen> {
  double _initialCapital = 200000;
  double _finalValue = 550000;
  double _years = 5;

  String get _sym => widget.currencySymbol;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final result = FinanceEngine.calculateROI(_initialCapital, _finalValue, _years);

    // Ratio bar percentages
    final pool = _initialCapital > _finalValue ? _initialCapital : _finalValue;
    final capitalPercent = pool > 0 ? clampPct(jsRound((_initialCapital / pool) * 100)) : 0.0;
    final gainPercent = 100 - capitalPercent;

    return FinanceLayout(
      inputs: [
        _capitalCard(),
        _finalCard(),
        _yearsCard(),
      ],
      results: _resultsCard(t, result, capitalPercent, gainPercent),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------------------------------------------------

  Widget _capitalCard() {
    return InputCard(
      children: [
        const CardLabel('Initial Investment (Principal Capital)'),
        FinanceNumberInput(
          inputKey: const ValueKey('roi-initial-input'),
          value: _initialCapital,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _initialCapital = v),
          placeholder: '2,00,000',
          prefix: _sym,
        ),
        if (_initialCapital > 0) MonoHelper('$_sym${formatMoney(_initialCapital)}', helperKey: const ValueKey('roi-initial-helper')),
      ],
    );
  }

  Widget _finalCard() {
    return InputCard(
      children: [
        const CardLabel('Final Investment Value (or Current Net Worth)'),
        FinanceNumberInput(
          inputKey: const ValueKey('roi-final-input'),
          value: _finalValue,
          parse: parseFloatOr0,
          onChanged: (v) => setState(() => _finalValue = v),
          placeholder: '5,50,000',
          prefix: _sym,
        ),
        if (_finalValue > 0) MonoHelper('$_sym${formatMoney(_finalValue)}', helperKey: const ValueKey('roi-final-helper')),
      ],
    );
  }

  Widget _yearsCard() {
    return InputCard(
      children: [
        CardHeader(
          label: 'Holding Period (Years)',
          value: '${jsToString(_years)} Years',
          valueKey: const ValueKey('roi-years-badge'),
        ),
        FinanceNumberInput(
          inputKey: const ValueKey('roi-years-input'),
          value: _years,
          parse: (s) {
            final v = parseFloatOr0(s);
            return v < 0.1 ? 0.1 : v; // Math.max(0.1, ...)
          },
          onChanged: (v) => setState(() => _years = v),
          placeholder: '5',
          suffix: 'Yr',
          bottomGap: 12,
        ),
        PresetChips(
          chips: [
            for (final y in _yearPresets)
              (
                key: ValueKey('roi-years-preset-${jsToString(y)}'),
                label: '${jsToString(y)}Y',
                active: _years == y,
                onTap: () => setState(() => _years = y),
              ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Results
  // -------------------------------------------------------------------------------------------------------------------

  Widget _resultsCard(M3Tokens t, RoiResult result, double capitalPercent, double gainPercent) {
    final bp = Breakpoints.of(context);
    final hs = headlineStyles(context, t, bigColor: t.primary);
    final accentTint = t.primary.withValues(alpha: t.isDark ? 0.12 : 0.10);
    // `text-base sm:text-lg font-normal font-sans ml-1.5`
    final unitSize = bp.sm ? 18.0 : 16.0;
    final unitLh = bp.sm ? 28.0 : 24.0;
    return ResultsCard(
      background: t.surfaceContainer,
      children: [
        // Annualized CAGR metric
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MetricCaption('Annualized Compounded Growth (CAGR)'),
              HeadlineRow(
                parts: [
                  (text: '${jsToFixed(result.cagrPercent, 2)}%', key: const ValueKey('roi-cagr'), style: hs.big, extraGap: 0.0),
                  (
                    text: 'per year',
                    key: null,
                    style: appText(size: unitSize, weight: FontWeight.w400, color: t.onSurfaceVariant, height: unitLh / unitSize),
                    extraGap: 2.0,
                  ),
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
                  (key: const ValueKey('roi-bar-capital'), percent: capitalPercent, color: t.outline),
                  (key: const ValueKey('roi-bar-gain'), percent: gainPercent, color: t.primary),
                ],
              ),
              const SizedBox(height: 8),
              RatioLegend(
                entries: [
                  (
                    dot: t.outline,
                    label: 'Principal Capital:',
                    value: '${jsToString(capitalPercent)}%',
                    valueColor: t.onSurface,
                    valueKey: const ValueKey('roi-pct-capital'),
                  ),
                  (
                    dot: t.primary,
                    label: 'Net Return:',
                    value: '${jsToString(gainPercent)}%',
                    valueColor: t.primary,
                    valueKey: const ValueKey('roi-pct-gain'),
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
            valueKey: const ValueKey('roi-total-roi'),
            background: t.surfaceContainerLow,
            caption: 'Total Absolute ROI',
            captionColor: t.onSurfaceVariant,
            value: '${result.roiPercent >= 0 ? '+' : ''}${jsToFixed(result.roiPercent, 2)}%',
            valueColor: t.onSurface,
            valueWeight: FontWeight.w300,
          ),
          right: (
            key: null,
            valueKey: const ValueKey('roi-net-profit'),
            background: accentTint,
            caption: 'Net Profit / Wealth Gain',
            captionColor: t.onSurfaceVariant,
            value: '${result.gainLoss >= 0 ? '+' : ''}$_sym${formatMoney(result.gainLoss)}',
            valueColor: t.primary,
            valueWeight: FontWeight.w300,
          ),
        ),

        const Footnote(
          'Compound Annual Growth Rate (CAGR) measures the geometric progression ratio over multi-year holding periods. Absolute ROI represents aggregate capital growth.',
          bottom: 0,
        ),
      ],
    );
  }
}
