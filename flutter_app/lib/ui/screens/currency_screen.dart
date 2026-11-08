import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../engine/currency.dart';
import '../../engine/js_locale.dart';
import '../../engine/js_number.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../widgets/option_select.dart';
import '../widgets/pressable.dart';
import 'screen_utils.dart';

const List<int> _presets = [10, 50, 100, 500, 1000, 5000];
const List<String> _comparisonCodes = ['EUR', 'GBP', 'JPY', 'AED', 'SGD', 'CAD'];

/// `x.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })`.
String formatRate4(double x) => jsToLocaleString(x, minFrac: 2, maxFrac: 4);

/// `x.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })`.
String formatRate2(double x) => jsToLocaleString(x, minFrac: 2, maxFrac: 2);

/// `POPULAR_CURRENCIES.find(c => c.code === code) || { code, name: code, symbol: code, flag: '🌐' }`.
CurrencyItem currencyFor(String code) {
  for (final c in popularCurrencies) {
    if (c.code == code) return c;
  }
  return CurrencyItem(code: code, name: code, symbol: code, flag: '🌐');
}

/// Text the copy button puts on the clipboard.
String currencyCopyText(double amount, String from, String to, double result) =>
    '${jsToString(amount)} $from = ${formatRate4(result)} $to';

/// Width of [text] on one line. Used as the flex factor of items that CSS lets shrink in proportion to their own width
/// (`flex-shrink: 1`): Flutter's `Flexible` shares the free space equally instead, which would wrap a short text early.
double _textWidth(BuildContext context, String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

int _flexFor(double width) {
  final v = (width * 10).round();
  return v < 1 ? 1 : v;
}

const Color _emeraldDark = Color(0xFF34D399);
const Color _emeraldLight = Color(0xFF047857);
const Color _amberDark = Color(0xFFFBBF24);
const Color _amberLight = Color(0xFFB45309);

/// Port of CurrencyConverter.tsx (the "Currency" tab of the Finance screen).
class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> with WidgetsBindingObserver {
  late RatesData _ratesData;
  bool _isRefreshing = true;
  bool _hasLoaded = false;
  String _from = 'USD';
  String _to = 'INR';
  final TextEditingController _amount = TextEditingController(text: '100');
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ratesData = RatesData(
      base: 'USD',
      rates: defaultRatesUsd,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      lastUpdatedStr: 'Loading...',
      isLive: false,
    );
    _amount.addListener(() => setState(() {}));
    _loadRates(first: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _copyTimer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  /// The web screen retries on the `online` event. Flutter has no such event without an extra package, so coming back
  /// to the app is the moment to retry (a deliberate difference, listed in PHASE5_NOTES.md).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_ratesData.isLive) _loadRates();
  }

  Future<void> _loadRates({bool first = false}) async {
    if (!first) setState(() => _isRefreshing = true);
    final service = context.read<CurrencyService>();
    try {
      final live = await service.fetchLiveExchangeRates();
      if (!mounted) return;
      setState(() => _ratesData = live);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _hasLoaded = true;
        });
      }
    }
  }

  void _swap() {
    setState(() {
      final prev = _from;
      _from = _to;
      _to = prev;
    });
  }

  /// `parseFloat(amount) || 0`
  double get _parsedAmount {
    final v = jsParseFloat(_amount.text);
    return (v.isNaN || v == 0) ? 0.0 : v;
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String get _statusLabel => _ratesData.isLive
      ? 'Live Forex Exchange Rates'
      : _ratesData.status == RatesStatus.builtin
          ? 'Forex Rates (Built-in)'
          : 'Forex Rates (Cached)';

  List<SelectOption> get _options => [
        for (final c in popularCurrencies) SelectOption(value: c.code, label: '${c.flag} ${c.code} - ${c.name}'),
      ];

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final bp = Breakpoints.of(context);
    final amount = _parsedAmount;
    final conversion = convertCurrency(amount, _from, _to, _ratesData.rates);
    final fromCurr = currencyFor(_from);
    final toCurr = currencyFor(_to);
    final gap = bp.pick(20.0, sm: 24.0);

    // `flex flex-col gap-4` with the swap button in `-my-2`: 16 - 8 = 8 px between each card and the 40 px button.
    final inputs = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fromCard(t, bp, fromCurr),
        const SizedBox(height: 8),
        Center(child: _swapButton(t)),
        const SizedBox(height: 8),
        _toCard(t, toCurr),
      ],
    );
    final results = _resultsCard(t, bp, amount, conversion, toCurr);

    final Widget grid = bp.md
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: inputs),
              SizedBox(width: gap),
              Expanded(child: results),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [inputs, SizedBox(height: gap), results],
          );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bp.xl ? 1152 : 1024),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBar(t),
            if (_hasLoaded && !_isRefreshing && !_ratesData.isLive) _notice(t),
            grid,
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Live status bar and notice
  // -------------------------------------------------------------------------------------------------------------------

  Widget _statusBar(M3Tokens t) {
    final statusColor = _ratesData.isLive
        ? (t.isDark ? _emeraldDark : _emeraldLight)
        : (t.isDark ? _amberDark : _amberLight);
    final labelText = _statusLabel.toUpperCase();
    final labelStyle = appText(size: 12, weight: FontWeight.w600, letterSpacingEm: 0.025, color: t.onSurface, height: 16 / 12);
    final updatedText = '• Updated ${_ratesData.lastUpdatedStr}';
    final updatedStyle = appText(size: 11, color: t.onSurfaceVariant, height: 16.5 / 11);
    return Container(
      key: const ValueKey('status-bar'),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.outlineVariant))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusDot(key: const ValueKey('status-dot'), color: statusColor, ping: _ratesData.isLive),
              const SizedBox(width: 8),
              Flexible(
                flex: _flexFor(_textWidth(context, labelText, labelStyle)),
                child: Text(labelText, key: const ValueKey('status-label'), style: labelStyle),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: _flexFor(_textWidth(context, updatedText, updatedStyle)),
                child: Text(updatedText, key: const ValueKey('status-updated'), style: updatedStyle),
              ),
            ],
          ),
          _refreshButton(t),
        ],
      ),
    );
  }

  Widget _refreshButton(M3Tokens t) {
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(12))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Spin(
            active: _isRefreshing,
            child: LucideIcon(LucideIconId.refreshCw, color: t.primary, size: 14),
          ),
          const SizedBox(width: 6),
          Text(
            _isRefreshing ? 'Updating...' : 'Refresh Rates',
            style: appText(size: 12, weight: FontWeight.w500, color: t.onSurface, height: 16 / 12),
          ),
        ],
      ),
    );
    return Pressable(
      key: const ValueKey('refresh-rates'),
      onTap: _isRefreshing ? null : _loadRates,
      child: Opacity(opacity: _isRefreshing ? 0.5 : 1, child: button),
    );
  }

  Widget _notice(M3Tokens t) {
    final which = _ratesData.status == RatesStatus.cached ? 'your last saved rates' : 'built-in approximate rates';
    return Container(
      key: const ValueKey('rates-notice'),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(12))),
      child: Text(
        "Couldn't reach a live rate provider, so these are $which. Check your connection and tap Refresh Rates.",
        style: appText(size: 12, color: t.onSurface, height: 16 / 12),
      ),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Inputs
  // -------------------------------------------------------------------------------------------------------------------

  Widget _labelRow(M3Tokens t, String label, Widget select) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: appText(size: 12, weight: FontWeight.w500, color: t.onSurfaceVariant, height: 16 / 12)),
          const SizedBox(width: 8),
          Flexible(child: select),
        ],
      ),
    );
  }

  Widget _fromCard(M3Tokens t, Breakpoints bp, CurrencyItem fromCurr) {
    final inputSize = bp.sm ? 30.0 : 24.0;
    final inputLh = bp.sm ? 36.0 : 32.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(16))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelRow(
            t,
            'From Currency & Amount',
            OptionSelect(
              key: const ValueKey('from-currency-select'),
              value: _from,
              options: _options,
              dialogTitle: 'From Currency',
              onChanged: (v) => setState(() => _from = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  fromCurr.symbol,
                  key: const ValueKey('from-symbol'),
                  style: appText(size: 24, weight: FontWeight.w300, color: t.onSurfaceVariant, height: 32 / 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    type: MaterialType.transparency,
                    child: TextField(
                      key: const ValueKey('currency-input'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-.]'))],
                      cursorColor: t.onSurface,
                      style: appText(size: inputSize, weight: FontWeight.w300, color: t.onSurface, height: inputLh / inputSize, tabular: true),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: '100',
                        hintStyle: appText(
                          size: inputSize,
                          weight: FontWeight.w300,
                          color: t.onSurface.withValues(alpha: 0.5),
                          height: inputLh / inputSize,
                          tabular: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${fromCurr.flag} ${fromCurr.name} (${fromCurr.code})',
            style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final p in _presets) _presetChip(t, p)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(M3Tokens t, int p) {
    final active = _amount.text == p.toString();
    return Pressable(
      key: ValueKey('preset-$p'),
      onTap: () => _amount.text = p.toString(),
      child: AnimatedContainer(
        duration: kTailwindDuration,
        curve: kTailwindEase,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.primaryContainer : t.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Text(
          jsToLocaleString(p.toDouble()),
          style: appText(
            size: 12,
            weight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? t.onPrimaryContainer : t.onSurfaceVariant,
            height: 16 / 12,
          ),
        ),
      ),
    );
  }

  Widget _swapButton(M3Tokens t) {
    return Pressable(
      pressedScale: 0.9,
      onTap: _swap,
      child: Container(
        key: const ValueKey('swap-currencies'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.surfaceContainerHigh, shape: BoxShape.circle),
        child: LucideIcon(LucideIconId.arrowLeftRight, color: t.onSurface, size: 16),
      ),
    );
  }

  Widget _toCard(M3Tokens t, CurrencyItem toCurr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(16))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelRow(
            t,
            'Target Currency',
            OptionSelect(
              key: const ValueKey('to-currency-select'),
              value: _to,
              options: _options,
              dialogTitle: 'Target Currency',
              onChanged: (v) => setState(() => _to = v),
            ),
          ),
          Text(
            '${toCurr.flag} ${toCurr.name} (${toCurr.code})',
            style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Results
  // -------------------------------------------------------------------------------------------------------------------

  Widget _resultsCard(
    M3Tokens t,
    Breakpoints bp,
    double amount,
    ({double result, double rate, double inverseRate}) conversion,
    CurrencyItem toCurr,
  ) {
    final pad = bp.pick(20.0, sm: 24.0);
    final size = bp.pick(30.0, sm: 36.0, lg: 48.0);
    final lh = bp.pick(36.0, sm: 40.0, lg: 48.0);
    final symbolSize = bp.sm ? 30.0 : 24.0;
    final symbolLh = bp.sm ? 36.0 : 32.0;
    final amountText = formatRate4(conversion.result);
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(24))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'CONVERTED AMOUNT ($_to)',
                        key: const ValueKey('converted-caption'),
                        style: appText(size: 11, weight: FontWeight.w600, letterSpacingEm: 0.05, color: t.onSurfaceVariant, height: 16.5 / 11),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          toCurr.symbol,
                          key: const ValueKey('to-symbol'),
                          style: appText(size: symbolSize, color: t.onSurfaceVariant, height: symbolLh / symbolSize, letterSpacingEm: -0.025, tabular: true),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: _BreakAllText(
                            amountText,
                            textKey: const ValueKey('converted-amount'),
                            style: appText(size: size, weight: FontWeight.w300, letterSpacingEm: -0.025, color: t.onSurface, height: lh / size, tabular: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Pressable(
                key: const ValueKey('copy-result'),
                onTap: () => _copy(currencyCopyText(amount, _from, _to, conversion.result)),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(12))),
                  child: _copied
                      ? LucideIcon(LucideIconId.check, color: t.isDark ? _emeraldDark : _emeraldLight, size: 16)
                      : LucideIcon(LucideIconId.copy, color: t.onSurface, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _rateBadge(
                key: const ValueKey('rate-direct'),
                text: '1 $_from = ${formatRate4(conversion.rate)} $_to',
                background: t.primaryContainer,
                color: t.onPrimaryContainer,
                weight: FontWeight.w600,
              ),
              _rateBadge(
                key: const ValueKey('rate-inverse'),
                text: '1 $_to = ${formatRate4(conversion.inverseRate)} $_from',
                background: t.surfaceContainer,
                color: t.onSurfaceVariant,
                weight: FontWeight.w400,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _watchlist(t, bp, amount),
        ],
      ),
    );
  }

  Widget _rateBadge({Key? key, required String text, required Color background, required Color color, required FontWeight weight}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: const BorderRadius.all(Radius.circular(12))),
      child: Text(text, style: appText(size: 12, weight: weight, color: color, height: 16 / 12, tabular: true)),
    );
  }

  Widget _watchlist(M3Tokens t, Breakpoints bp, double amount) {
    final cols = bp.sm ? 3 : 2;
    const gap = 10.0;
    final rows = <Widget>[];
    for (var i = 0; i < _comparisonCodes.length; i += cols) {
      final slice = _comparisonCodes.skip(i).take(cols).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) const SizedBox(width: gap),
                Expanded(child: j < slice.length ? _watchTile(t, slice[j], amount) : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                LucideIcon(LucideIconId.trendingUp, color: t.primary, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Quick Conversion Watchlist for ${jsToLocaleString(amount)} $_from',
                    key: const ValueKey('watchlist-title'),
                    style: appText(size: 12, weight: FontWeight.w600, color: t.onSurface, height: 16 / 12),
                  ),
                ),
              ],
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _watchTile(M3Tokens t, String code, double amount) {
    final target = currencyFor(code);
    final converted = convertCurrency(amount, _from, code, _ratesData.rates);
    final leftText = '${target.flag} $code';
    final leftStyle = appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12);
    final rateText = '1 $_from = ${jsToFixed(converted.rate, 2)}';
    final rateStyle = appText(size: 10, color: t.onSurfaceVariant, height: 15 / 10, tabular: true);
    return Pressable(
      key: ValueKey('watch-$code'),
      onTap: () => setState(() => _to = code),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: _flexFor(_textWidth(context, leftText, leftStyle)),
                  child: Text(leftText, style: leftStyle),
                ),
                const SizedBox(width: 4),
                Flexible(
                  flex: _flexFor(_textWidth(context, rateText, rateStyle)),
                  child: Opacity(
                    opacity: 0.8,
                    child: Text(rateText, textAlign: TextAlign.end, style: rateStyle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${target.symbol} ${formatRate2(converted.result)}',
              style: appText(size: 14, weight: FontWeight.w500, color: t.onSurface, height: 20 / 14, tabular: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// CSS `break-all`: when the text is wider than the room it has, it may break between any two characters. When it
/// fits, a plain [Text] (so the string itself is untouched).
class _BreakAllText extends StatelessWidget {
  const _BreakAllText(this.text, {required this.textKey, required this.style});

  final String text;

  /// Key of the [Text] that is drawn (tests read its string).
  final Key textKey;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final fits = tp.width <= box.maxWidth;
        tp.dispose();
        return Text(fits ? text : text.split('').join('\u200B'), key: textKey, style: style);
      },
    );
  }
}

/// The status dot: a solid dot, plus (live rates only) Tailwind's `animate-ping` halo around it.
class _StatusDot extends StatefulWidget {
  const _StatusDot({super.key, required this.color, required this.ping});

  final Color color;
  final bool ping;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  static const Cubic _pingEase = Cubic(0, 0, 0.2, 1);

  @override
  void initState() {
    super.initState();
    if (widget.ping) _c.repeat();
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.ping && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.ping && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    return SizedBox(
      width: 10,
      height: 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.ping)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                // `@keyframes ping { 75%, 100% { transform: scale(2); opacity: 0 } }` from scale(1) at opacity .75
                final p = _pingEase.transform((_c.value / 0.75).clamp(0.0, 1.0));
                return Opacity(
                  opacity: 0.75 * (1 - p),
                  child: Transform.scale(
                    scale: 1 + p,
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
                  ),
                );
              },
            ),
          dot,
        ],
      ),
    );
  }
}

/// `animate-spin`: a full turn every second, linear, while [active]; at rest when not.
class _Spin extends StatefulWidget {
  const _Spin({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(_Spin old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: widget.child);
}
