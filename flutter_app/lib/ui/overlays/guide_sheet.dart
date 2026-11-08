import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../editor/expr_doc.dart';
import '../../editor/nodes.dart';
import '../../editor/rich_expression_view.dart';
import '../../engine/calc_error.dart';
import '../../engine/evaluator.dart';
import '../../engine/types.dart';
import '../../state/navigation_state.dart';
import '../../state/settings_store.dart';
import '../../theme/motion.dart';
import '../../theme/spring_value.dart';
import '../../theme/tokens.dart';
import '../calculator/calc_style.dart';
import '../icons/lucide_icon.dart';
import '../icons/nav_icon.dart';
import '../widgets/m3_sheet.dart';
import '../widgets/pressable.dart';
import 'guide_content.dart';
import 'guide_content_extra.dart';
import 'history_tape_sheet.dart' show pillRadiusAll;

/// `ExampleResult` of GuideSheet.tsx.
class GuideResult {
  const GuideResult(this.text, this.isError, {this.plain = false});

  final String text;
  final bool isError;

  /// Show the text as is, without the "= " in front.
  final bool plain;

  @override
  bool operator ==(Object other) =>
      other is GuideResult && other.text == text && other.isError == isError && other.plain == plain;

  @override
  int get hashCode => Object.hash(text, isError, plain);

  @override
  String toString() => 'GuideResult($text, error: $isError, plain: $plain)';
}

/// `runExample`: the answer is computed by the real calculator engine, so the guide always matches the calculator.
GuideResult runGuideExample(GuideExample ex) {
  // Defining an equation is not a calculation: just show what will be saved
  if (RegExp(r'^y\s*=', caseSensitive: false).hasMatch(ex.expr)) {
    return const GuideResult('Saved. Now type an x value and press =', false, plain: true);
  }
  // Examples that call y(x) use their own equation, then put the user's saved one back
  final previous = MathEvaluator.getYDefinition();
  final setup = ex.setup;
  try {
    if (setup != null && setup.isNotEmpty) MathEvaluator.setYDefinition(setup);
    final value = MathEvaluator.evaluate(ex.expr, ex.angle ?? AngleMode.deg);
    return GuideResult(MathEvaluator.formatResult(value, -1), false);
  } on CalcError catch (e) {
    return GuideResult(e.message, true);
  } catch (_) {
    return const GuideResult('Error', true);
  } finally {
    if (setup != null && setup.isNotEmpty) MathEvaluator.setYDefinition(previous);
  }
}

/// Port of `GuideSheet.tsx`: the "How to use OmniCalc" sheet (the book icon in the header).
class GuideSheet extends StatefulWidget {
  const GuideSheet({super.key});

  @override
  State<GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<GuideSheet> {
  // stays mounted while closed, like the web component: the open topic is remembered
  String? _openId = 'diff';

  void _try(NavigationState nav, SettingsStore store, String expr, AngleMode? angle) {
    // `handleTryExample`
    if (angle != null) store.update((c) => c.copyWith(angleMode: angle));
    nav.tryExample(expr);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final nav = context.watch<NavigationState>();
    final store = context.watch<SettingsStore>();
    final sm = MediaQuery.sizeOf(context).width >= 640;
    final px = sm ? 20.0 : 16.0;
    final angleMode = store.settings.angleMode;

    return M3Sheet(
      isOpen: nav.isGuideOpen,
      onClose: () => nav.setGuideOpen(false),
      label: 'User guide',
      maxWidth: 672,
      fixedHeight: true,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: px, vertical: 12),
          child: Row(
            children: [
              Pressable(
                key: const ValueKey('guide-back'),
                onTap: () => nav.setGuideOpen(false),
                pressedScale: 0.9,
                child: Semantics(
                  button: true,
                  label: 'Close guide',
                  excludeSemantics: true,
                  child: SizedBox(width: 44, height: 44, child: Center(child: LucideIcon(LucideIconId.arrowLeft, color: t.onSurface, size: 20))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How to use OmniCalc',
                        style: calcText(size: 20, weight: FontWeight.w700, color: t.onSurface, lineHeight: 25, letterSpacingEm: -0.025)),
                    Text('Tap a topic. Every example has a Try button.',
                        style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.primaryContainer, borderRadius: const BorderRadius.all(Radius.circular(16))),
                child: NavIcon(id: NavIconId.guide, color: t.onPrimaryContainer, active: true, size: 22),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight;
              // `mask-image: linear-gradient(to bottom, transparent 0, #000 12px, #000 calc(100% - 22px), transparent 100%)`
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                  stops: [0, math.min(12 / h, 1), math.max(0, (h - 22) / h), 1],
                ).createShader(rect),
                child: SingleChildScrollView(
                  key: const ValueKey('guide-scroll'),
                  padding: EdgeInsets.fromLTRB(px, 4, px, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: t.primaryContainer, borderRadius: const BorderRadius.all(Radius.circular(28))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Opacity(
                              opacity: 0.8,
                              child: Text('QUICK START',
                                  style: calcText(size: 12, weight: FontWeight.w700, color: t.onPrimaryContainer, lineHeight: 16, letterSpacingEm: 0.05)),
                            ),
                            const SizedBox(height: 8),
                            for (final (i, line) in kGuideQuickStart.indexed) ...[
                              if (i > 0) const SizedBox(height: 6),
                              _Bullet(text: line, dot: t.onPrimaryContainer, dotOpacity: 0.6, textColor: t.onPrimaryContainer, size: 13, lineHeight: 17.875),
                            ],
                          ],
                        ),
                      ),
                      for (final section in [...kGuideSections, ...kGuideSectionsExtra]) ...[
                        const SizedBox(height: 12),
                        _SectionCard(
                          key: ValueKey('guide-section-${section.id}'),
                          section: section,
                          open: _openId == section.id,
                          angleMode: angleMode,
                          onToggle: () => setState(() => _openId = _openId == section.id ? null : section.id),
                          onTry: (expr, angle) => _try(nav, store, expr, angle),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(28))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('GOOD TO KNOW',
                                style: calcText(size: 12, weight: FontWeight.w700, color: t.primary, lineHeight: 16, letterSpacingEm: 0.05)),
                            const SizedBox(height: 8),
                            for (final (i, tip) in kGuideTips.indexed) ...[
                              if (i > 0) const SizedBox(height: 6),
                              _Bullet(text: tip, dot: t.tertiary, textColor: t.onSurfaceVariant, size: 13, lineHeight: 17.875),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// `● text` row: the dot and the text side by side, 8 px apart.
class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.text,
    required this.dot,
    required this.textColor,
    required this.size,
    required this.lineHeight,
    this.dotOpacity = 1,
  });

  final String text;
  final Color dot;
  final Color textColor;
  final double size;
  final double lineHeight;
  final double dotOpacity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: dotOpacity,
          child: Text('●', style: calcText(size: size, weight: FontWeight.w400, color: dot, lineHeight: lineHeight)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: calcText(size: size, weight: FontWeight.w400, color: textColor, lineHeight: lineHeight))),
      ],
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.open,
    required this.angleMode,
    required this.onToggle,
    required this.onTry,
  });

  final GuideSection section;
  final bool open;
  final AngleMode angleMode;
  final VoidCallback onToggle;
  final void Function(String expr, AngleMode? angle) onTry;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  // `useMemo(() => (open ? examples.map(runExample) : []), [open, section])`: only evaluated once the card is opened
  List<GuideResult> _results = const [];

  @override
  void initState() {
    super.initState();
    if (widget.open) _results = widget.section.examples.map(runGuideExample).toList();
  }

  @override
  void didUpdateWidget(_SectionCard old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open || widget.section != old.section) {
      _results = widget.open ? widget.section.examples.map(runGuideExample).toList() : const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final section = widget.section;
    final open = widget.open;
    final instant = reduceMotion(context);

    return DecoratedBox(
      decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(28))),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Pressable(
              key: ValueKey('guide-toggle-${section.id}'),
              onTap: widget.onToggle,
              pressedScale: 0.99,
              child: Semantics(
                button: true,
                expanded: open,
                label: section.title,
                excludeSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: instant ? Duration.zero : const Duration(milliseconds: 250),
                          curve: M3Curves.emphasized,
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: open ? t.primary : t.surfaceContainerHigh,
                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                          ),
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: open ? t.onPrimary : t.primary),
                            duration: instant ? Duration.zero : const Duration(milliseconds: 250),
                            curve: M3Curves.emphasized,
                            builder: (context, color, _) => Text(
                              section.badge,
                              style: calcText(size: 15, weight: FontWeight.w700, color: color ?? t.primary, lineHeight: 22.5, letterSpacingEm: -0.025),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(section.title, style: calcText(size: 14, weight: FontWeight.w600, color: t.onSurface, lineHeight: 19.25)),
                              if (!open)
                                Text(
                                  section.summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: calcText(size: 11.5, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 17.25),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _SpringChevron(open: open, color: t.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SpringReveal(
              show: open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _SectionBody(section: section, results: _results, angleMode: widget.angleMode, onTry: widget.onTry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chevron that turns over with the sheet spring.
class _SpringChevron extends StatefulWidget {
  const _SpringChevron({required this.open, required this.color});

  final bool open;
  final Color color;

  @override
  State<_SpringChevron> createState() => _SpringChevronState();
}

class _SpringChevronState extends State<_SpringChevron> with SingleTickerProviderStateMixin {
  late final SpringValue _turn;

  @override
  void initState() {
    super.initState();
    _turn = SpringValue(vsync: this, spring: M3Springs.spring, initial: widget.open ? 1 : 0);
  }

  @override
  void didUpdateWidget(_SpringChevron old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      _turn.instant = reduceMotion(context);
      _turn.animateTo(widget.open ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, _) => Transform.rotate(
        key: const ValueKey('guide-chevron'),
        angle: _turn.value * math.pi,
        child: LucideIcon(LucideIconId.chevronDown, color: widget.color, size: 20),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section, required this.results, required this.angleMode, required this.onTry});

  final GuideSection section;
  final List<GuideResult> results;
  final AngleMode angleMode;
  final void Function(String expr, AngleMode? angle) onTry;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final children = <Widget>[
      Text(section.summary, style: calcText(size: 13, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 21.125)),
      if (section.where != null || section.syntax != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (section.where != null)
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Find it: ', style: TextStyle(fontWeight: FontWeight.w700, color: t.primary)),
                  TextSpan(text: section.where),
                ]),
                style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurface, lineHeight: 16),
              ),
            if (section.where != null && section.syntax != null) const SizedBox(height: 6),
            if (section.syntax != null)
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Pattern: ', style: TextStyle(fontWeight: FontWeight.w700, color: t.primary)),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(8))),
                      child: Text(
                        section.syntax!,
                        style: calcText(size: 12, weight: FontWeight.w600, color: t.onSurface, lineHeight: 16),
                      ),
                    ),
                  ),
                ]),
                style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurface, lineHeight: 16),
              ),
          ],
        ),
      if (section.steps != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, step) in section.steps!.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              GuideStepIn(
                delay: Duration(milliseconds: i * 45),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.primaryContainer, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: calcText(size: 11, weight: FontWeight.w700, color: t.onPrimaryContainer, lineHeight: 16.5)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step, style: calcText(size: 13, weight: FontWeight.w400, color: t.onSurface, lineHeight: 17.875))),
                  ],
                ),
              ),
            ],
          ],
        ),
      if (section.examples.isNotEmpty)
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EXAMPLES', style: calcText(size: 11, weight: FontWeight.w700, color: t.primary, lineHeight: 16.5, letterSpacingEm: 0.05)),
          for (final (i, ex) in section.examples.indexed) ...[
            const SizedBox(height: 8),
            _ExampleRow(
              key: ValueKey('guide-example-${section.id}-$i'),
              example: ex,
              result: i < results.length ? results[i] : const GuideResult('', false),
              angleMode: angleMode,
              onTry: () => onTry(ex.load ?? ex.expr, ex.angle),
            ),
          ],
        ],
      ),
      if (section.tips != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, tip) in section.tips!.indexed) ...[
              if (i > 0) const SizedBox(height: 6),
              _Bullet(text: tip, dot: t.tertiary, textColor: t.onSurfaceVariant, size: 12, lineHeight: 16.5),
            ],
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          c,
        ],
      ],
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({super.key, required this.example, required this.result, required this.angleMode, required this.onTry});

  final GuideExample example;
  final GuideResult result;
  final AngleMode angleMode;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final ex = example;
    final switches = ex.angle != null && ex.angle != angleMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: const BorderRadius.all(Radius.circular(20))),
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (ex.load != null && ExprDoc.fromExample(ex.load!).root.any((n) => n is StructNode))
                          // the example as it looks on the calculator's display: the boxes filled in
                          RichExpressionView(
                            key: const ValueKey('guide-example-structure'),
                            doc: ExprDoc.fromExample(ex.load!),
                            max: 20,
                            min: 20,
                            fit: false,
                            color: t.onSurface,
                            weight: FontWeight.w600,
                          )
                        else
                          Text(ex.expr, style: calcText(size: 15, weight: FontWeight.w600, color: t.onSurface, lineHeight: 22.5)),
                        if (ex.angle != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: t.tertiaryContainer, borderRadius: pillRadiusAll),
                            child: Text(
                              ex.angle!.id.toUpperCase(),
                              style: calcText(size: 10, weight: FontWeight.w700, color: t.onTertiaryContainer, lineHeight: 15),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        result.isError || result.plain ? result.text : '= ${result.text}',
                        key: const ValueKey('guide-result'),
                        style: calcText(size: 14, weight: FontWeight.w700, color: result.isError ? t.error : t.primary, lineHeight: 20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(ex.note, style: calcText(size: 11.5, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 15.8125)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                key: const ValueKey('guide-try'),
                onTap: onTry,
                pressedScale: 0.9,
                child: Semantics(
                  button: true,
                  label: switches ? 'Try, loads this example and switches to ${ex.angle!.id.toUpperCase()}' : 'Try, load this example into the calculator',
                  excludeSemantics: true,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.only(left: 10, right: 12),
                    decoration: BoxDecoration(color: t.primary, borderRadius: pillRadiusAll),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LucideIcon(LucideIconId.play, color: t.onPrimary, size: 14, filled: true),
                        const SizedBox(width: 4),
                        Text('Try', style: calcText(size: 12, weight: FontWeight.w600, color: t.onPrimary, lineHeight: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (switches)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Switches the calculator to ${ex.angle!.id.toUpperCase()}.',
                style: calcText(size: 10.5, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 15.75),
              ),
            ),
        ],
      ),
    );
  }
}
