import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/js_number.dart';
import '../../engine/units.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../shell/intrinsic_cache.dart';
import '../shell/swipeable_tab_container.dart';
import '../widgets/option_select.dart';
import '../widgets/pressable.dart';
import 'screen_utils.dart';

/// The lucide icon each converter category shows beside its tab label (`UnitCategory.iconName`).
///
/// The web app has the name on every category but never draws it; the Flutter app does, as requested for Phase 2
/// ("except the converter screen everything has logos beside the labels").
LucideIconId converterIconFor(String iconName) => switch (iconName) {
      'Ruler' => LucideIconId.ruler,
      'Scale' => LucideIconId.scale,
      'Thermometer' => LucideIconId.thermometer,
      'Square' => LucideIconId.square,
      'Box' => LucideIconId.box,
      'Gauge' => LucideIconId.gauge,
      'HardDrive' => LucideIconId.hardDrive,
      'Clock' => LucideIconId.clock,
      'Activity' => LucideIconId.activity,
      'Zap' => LucideIconId.zap,
      'Compass' => LucideIconId.compass,
      'Magnet' => LucideIconId.magnet,
      _ => LucideIconId.ruler,
    };

/// `formattedResult` of ConverterScreen.tsx.
String formatConverted(double result) {
  return result.abs() >= 1e9 || (result.abs() <= 1e-4 && result != 0)
      ? jsToExponential(result, 4)
      : jsToString(jsParseFloat(jsToPrecision(result, 7)));
}

/// The number in a comparison tile.
String formatComparison(double result) {
  return result.abs() >= 1e7 || (result.abs() <= 1e-4 && result != 0)
      ? jsToExponential(result, 3)
      : jsToString(jsParseFloat(jsToPrecision(result, 5)));
}

/// Port of ConverterScreen.tsx.
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  static const List<int> _presets = [1, 5, 10, 50, 100];

  String _categoryId = 'length';
  late String _fromId;
  late String _toId;
  final TextEditingController _input = TextEditingController(text: '1');
  bool _copied = false;
  bool _swapping = false;
  Timer? _copyTimer;
  Timer? _swapTimer;

  UnitCategory get _category =>
      unitCategories.firstWhere((c) => c.id == _categoryId, orElse: () => unitCategories.first);

  @override
  void initState() {
    super.initState();
    _fromId = _category.units[0].id;
    _toId = _category.units[1].id;
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _swapTimer?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _sound(ClickType type) => playScreenSound(context, type);

  void _selectCategory(String id) {
    _sound(ClickType.toggle);
    setState(() {
      _categoryId = id;
      final cat = _category;
      if (cat.units.length >= 2) {
        _fromId = cat.units[0].id;
        _toId = cat.units[1].id;
      }
    });
  }

  void _swap() {
    _sound(ClickType.op);
    setState(() {
      _swapping = true;
      final prev = _fromId;
      _fromId = _toId;
      _toId = prev;
    });
    _swapTimer?.cancel();
    _swapTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _swapping = false);
    });
  }

  /// `parseFloat(inputValue) || 0`
  double get _numericInput {
    final v = jsParseFloat(_input.text);
    return (v.isNaN || v == 0) ? 0.0 : v;
  }

  void _copy(String text) {
    _sound(ClickType.op);
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  UnitDefinition _unit(String id, int fallbackIndex) {
    final units = _category.units;
    return units.firstWhere((u) => u.id == id, orElse: () => units[fallbackIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final bp = Breakpoints.of(context);
    final category = _category;
    final numeric = _numericInput;
    final conversion = convertUnit(numeric, category, _fromId, _toId);
    final formatted = formatConverted(conversion.result);
    final fromUnit = _unit(_fromId, 0);
    final toUnit = _unit(_toId, 1);

    final tabs = [
      for (final c in unitCategories)
        TabItem(
          id: c.id,
          label: c.name,
          iconBuilder: (color, size) => LucideIcon(converterIconFor(c.iconName), color: color, size: size),
        ),
    ];

    final gap = bp.pick(16.0, sm: 20.0);
    final inputCard = _inputCard(context, t, bp, fromUnit);
    final resultCard = _resultCard(context, t, bp, conversion.formula, formatted, toUnit);

    final Widget cards;
    if (bp.md) {
      // grid-cols-2 with a swap button centred on the grid
      cards = Stack(
        alignment: Alignment.center,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: inputCard),
                SizedBox(width: gap),
                Expanded(child: resultCard),
              ],
            ),
          ),
          _swapButton(t),
        ],
      );
    } else {
      // grid-cols-1: the swap button sits between the cards with `-my-2`
      cards = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          inputCard,
          SizedBox(height: gap),
          SizedBox(
            height: 24,
            child: OverflowBox(maxHeight: 40, child: Center(child: _swapButton(t))),
          ),
          SizedBox(height: gap),
          resultCard,
        ],
      );
    }

    final comparison = _comparisonCard(context, t, bp, category, numeric, fromUnit);

    return CachedIntrinsicHeight(
      estimate: 760,
      measureNatural: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: bp.xl ? 1152 : 1024),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SwipeableTabContainer(
              tabs: tabs,
              activeTabId: _categoryId,
              onSelectTab: _selectCategory,
              showNavButtons: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cards,
                    const SizedBox(height: 20),
                    comparison,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _swapButton(M3Tokens t) {
    return Pressable(
      pressedScale: 0.9,
      onTap: _swap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _swapping ? 1 : 0),
        duration: kTailwindDuration,
        curve: kTailwindEase,
        builder: (context, p, child) => Transform.rotate(
          angle: math.pi * p,
          child: Transform.scale(scale: 1 - 0.08 * p, child: child),
        ),
        child: Container(
          key: const ValueKey('swap-units'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.surfaceContainerHigh, shape: BoxShape.circle),
          child: LucideIcon(LucideIconId.arrowLeftRight, color: t.onSurface, size: 16),
        ),
      ),
    );
  }

  List<SelectOption> get _options => [
        for (final u in _category.units) SelectOption(value: u.id, label: '${u.name} (${u.symbol})'),
      ];

  Widget _inputCard(BuildContext context, M3Tokens t, Breakpoints bp, UnitDefinition fromUnit) {
    final pad = bp.pick(16.0, sm: 20.0);
    final big = bp.sm;
    final fontSize = big ? 36.0 : 30.0;
    final lineHeight = big ? 40.0 : 36.0;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(16))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bp.md ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FROM UNIT',
                    style: appText(size: 12, weight: FontWeight.w600, letterSpacingEm: 0.05, color: t.onSurfaceVariant, height: 16 / 12),
                  ),
                  Flexible(
                    child: OptionSelect(
                      key: const ValueKey('from-unit-select'),
                      value: _fromId,
                      options: _options,
                      dialogTitle: 'From Unit',
                      onChanged: (v) {
                        _sound(ClickType.toggle);
                        setState(() => _fromId = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: TextField(
                    key: const ValueKey('converter-input'),
                    controller: _input,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-.]'))],
                    cursorColor: t.onSurface,
                    style: appText(size: fontSize, weight: FontWeight.w300, color: t.onSurface, height: lineHeight / fontSize, tabular: true),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(right: 32),
                      hintText: '0',
                      hintStyle: appText(
                        size: fontSize,
                        weight: FontWeight.w300,
                        color: t.onSurface.withValues(alpha: 0.3),
                        height: lineHeight / fontSize,
                        tabular: true,
                      ),
                    ),
                  ),
                  ),
                  if (_input.text.isNotEmpty)
                    GestureDetector(
                      key: const ValueKey('clear-input'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _sound(ClickType.clear);
                        _input.clear();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: LucideIcon(LucideIconId.rotateCcw, color: t.onSurfaceVariant, size: 16),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${fromUnit.name} (${fromUnit.symbol})',
                style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('Presets:', style: appText(size: 11, weight: FontWeight.w500, color: t.onSurfaceVariant, height: 16.5 / 11)),
                ),
                for (final p in _presets) _presetChip(t, p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(M3Tokens t, int p) {
    final active = _input.text == p.toString();
    return Pressable(
      key: ValueKey('preset-$p'),
      onTap: () {
        _sound(ClickType.num);
        _input.text = p.toString();
      },
      child: AnimatedContainer(
        duration: kTailwindDuration,
        curve: kTailwindEase,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.primaryContainer : t.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Text(
          '$p',
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

  Widget _resultCard(BuildContext context, M3Tokens t, Breakpoints bp, String formula, String formatted, UnitDefinition toUnit) {
    final pad = bp.pick(20.0, sm: 24.0);
    final radius = bp.sm ? 24.0 : 16.0;
    final size = bp.pick(30.0, sm: 36.0, lg: 48.0);
    final lh = bp.pick(36.0, sm: 40.0, lg: 48.0);
    final symbolSize = bp.sm ? 24.0 : 20.0;
    final symbolLh = bp.sm ? 32.0 : 28.0;
    return Container(
      clipBehavior: Clip.hardEdge,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: BorderRadius.all(Radius.circular(radius))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bp.md ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CONVERTED VALUE',
                    style: appText(size: 11, weight: FontWeight.w600, letterSpacingEm: 0.05, color: t.onSurfaceVariant, height: 16.5 / 11),
                  ),
                  Flexible(
                    child: OptionSelect(
                      key: const ValueKey('to-unit-select'),
                      value: _toId,
                      options: _options,
                      dialogTitle: 'Converted Value',
                      onChanged: (v) {
                        _sound(ClickType.toggle);
                        setState(() => _toId = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      key: const ValueKey('converted-value'),
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatted,
                            style: appText(size: size, weight: FontWeight.w300, letterSpacingEm: -0.025, color: t.onSurface, height: lh / size, tabular: true),
                          ),
                          const WidgetSpan(child: SizedBox(width: 8)),
                          TextSpan(
                            text: toUnit.symbol,
                            style: appText(size: symbolSize, color: t.onSurfaceVariant, height: symbolLh / symbolSize),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Pressable(
                    key: const ValueKey('copy-result'),
                    onTap: () => _copy(formatted),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(12))),
                      child: _copied
                          ? LucideIcon(LucideIconId.check, color: t.isDark ? const Color(0xFF34D399) : const Color(0xFF047857), size: 16)
                          : LucideIcon(LucideIconId.copy, color: t.onSurface, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
          if (formula.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(12))),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Formula:', style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true)),
                        const WidgetSpan(child: SizedBox(width: 6)),
                        TextSpan(
                          text: formula,
                          style: appText(size: 12, weight: FontWeight.w600, color: t.primary, height: 16 / 12, tabular: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _comparisonCard(
    BuildContext context,
    M3Tokens t,
    Breakpoints bp,
    UnitCategory category,
    double numeric,
    UnitDefinition fromUnit,
  ) {
    final pad = bp.pick(20.0, sm: 24.0);
    final radius = bp.sm ? 24.0 : 16.0;
    final cols = bp.pick(2, sm: 3, md: 4, lg: 5);
    const gap = 10.0;
    final others = [for (final u in category.units) if (u.id != _fromId) u];
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: BorderRadius.all(Radius.circular(radius))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'All Units Comparison for ${jsToString(numeric)} ${fromUnit.symbol}'.toUpperCase(),
            key: const ValueKey('comparison-title'),
            style: appText(size: 12, weight: FontWeight.w600, letterSpacingEm: 0.05, color: t.onSurfaceVariant, height: 16 / 12),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final u in others)
                    SizedBox(
                      width: w,
                      child: _comparisonTile(t, category, numeric, u),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _comparisonTile(M3Tokens t, UnitCategory category, double numeric, UnitDefinition u) {
    final res = convertUnit(numeric, category, _fromId, u.id);
    final str = formatComparison(res.result);
    final selected = _toId == u.id;
    final nameColor = selected ? t.onPrimaryContainer : t.onSurfaceVariant;
    final valueColor = selected ? t.onPrimaryContainer : t.onSurface;
    return Pressable(
      key: ValueKey('compare-${u.id}'),
      onTap: () => setState(() => _toId = u.id),
      child: AnimatedContainer(
        duration: kTailwindDuration,
        curve: kTailwindEase,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? t.primaryContainer : t.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              u.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(size: 11, color: nameColor, height: 16.5 / 11, tabular: true),
            ),
            const SizedBox(height: 2),
            Text.rich(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              TextSpan(
                children: [
                  TextSpan(text: '$str ', style: appText(size: 14, weight: FontWeight.w500, color: valueColor, height: 20 / 14, tabular: true)),
                  TextSpan(
                    text: u.symbol,
                    style: appText(size: 14, weight: FontWeight.w400, color: valueColor.withValues(alpha: 0.75), height: 20 / 14, tabular: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
