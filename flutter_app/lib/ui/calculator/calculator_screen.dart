import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../editor/expr_doc.dart';
import '../../editor/rich_expression_view.dart';
import '../../engine/types.dart';
import '../../services/feedback_service.dart';
import '../../state/casio_settings.dart';
import '../../state/history_store.dart';
import '../../state/navigation_state.dart';
import '../../state/settings_store.dart';
import '../../theme/glass.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../icons/omnicalc_logo.dart';
import '../shell/app_shell.dart' show ShellLayout, placeholderScreen;
import '../shell/header.dart';
import '../shell/intrinsic_cache.dart';
import '../shell/pinned_slot.dart';
import '../shell/swipeable_tab_container.dart';
import 'advanced_keys.dart';
import 'calc_style.dart';
import 'calculator_controller.dart';
import 'data_sheets.dart';
import 'mode_menu.dart';

/// Screen builder of the shell: the calculator for `standard`, the Phase 5 stand-ins for the other modes.
Widget calculatorOrPlaceholder(BuildContext context, CalculatorMode mode) {
  if (mode == CalculatorMode.standard) return const CalculatorScreen();
  return placeholderScreen(context, mode);
}

/// Port of CalculatorScreen.tsx: portrait (answer card pinned under the header, keys scroll underneath) and landscape
/// (display pane plus keypad pane).
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late final CalculatorController _c;
  PinnedSlotController? _pinned;
  int _loadedSeq = -1;
  bool _pinnedShown = false;
  Widget? _pinnedWidget;

  @override
  void initState() {
    super.initState();
    final history = context.read<HistoryStore>();
    _c = CalculatorController(
      feedback: context.read<FeedbackService>(),
      engine: CasioRuntime.instance.engine,
      onAddHistoryRich: (
              {required expression, required result, required mode, rich}) =>
          history.add(
              expression: expression, result: result, mode: mode, rich: rich),
    );
    _c.onOpenModeMenu = () => showModeMenu(context, _c);
    _c.onOpenStatTypeMenu = () => showStatTypeDialog(context, _c);
    _c.onOpenStatEditor = () => showStatEditor(context, _c);
    _c.onOpenMatrixEditor = () => showMatrixEditor(context, _c);
    _c.onOpenVectorEditor = () => showVectorEditor(context, _c);
    _c.onOpenTable = () => showTableSheet(context, _c);
    _c.onShowMatVecResult = () => showMatVecResult(context, _c);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    CasioRuntime.instance.addListener(_casioChanged);
  }

  void _casioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pinned = context.read<PinnedSlotController>();
    // The `useEffect` on externalExpression / externalSeq: runs once on mount and whenever a new expression arrives.
    final nav = context.read<NavigationState>();
    if (nav.externalSeq != _loadedSeq) {
      _loadedSeq = nav.externalSeq;
      final expr = nav.externalExpression;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.loadExternal(expr);
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    CasioRuntime.instance.removeListener(_casioChanged);
    final pinned = _pinned;
    final shown = _pinnedShown;
    if (pinned != null && shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pinned.clear());
    }
    _c.dispose();
    super.dispose();
  }

  bool _typingInField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  /// The window `keydown` and `paste` listeners. Like the web listeners, this never stops other handlers.
  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (_typingInField()) return false;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed;
    final meta = keyboard.isMetaPressed;
    final logical = event.logicalKey;

    String? key;
    if ((ctrl || meta) && logical.keyLabel.length == 1) {
      // with Ctrl held, event.character is a control code; the key label is what KeyboardEvent.key reports
      key = logical.keyLabel.toLowerCase();
    } else if (logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter) {
      key = 'Enter';
    } else if (logical == LogicalKeyboardKey.backspace) {
      key = 'Backspace';
    } else if (logical == LogicalKeyboardKey.escape) {
      key = 'Escape';
    } else if (logical == LogicalKeyboardKey.delete) {
      key = 'Delete';
    } else if (logical == LogicalKeyboardKey.arrowLeft) {
      key = 'ArrowLeft';
    } else if (logical == LogicalKeyboardKey.arrowRight) {
      key = 'ArrowRight';
    } else if (logical == LogicalKeyboardKey.arrowUp) {
      key = 'ArrowUp';
    } else if (logical == LogicalKeyboardKey.arrowDown) {
      key = 'ArrowDown';
    } else if (event.character != null && event.character!.isNotEmpty) {
      key = event.character;
    } else if (logical.keyLabel.length == 1) {
      key = logical.keyLabel.toLowerCase();
    }
    // numpad keys keep working when the platform reports no character for them
    if (key == null && event.physicalKey == PhysicalKeyboardKey.numpadMultiply)
      key = '*';
    if (key == null && event.physicalKey == PhysicalKeyboardKey.numpadDivide)
      key = '/';
    if (key == null) return false;

    if ((ctrl || meta) && (key == 'v' || key == 'V')) {
      Clipboard.getData(Clipboard.kTextPlain).then((data) {
        if (mounted) _c.handlePaste(data?.text);
      });
      return false;
    }

    final physical = event.physicalKey;
    _c.handleKeyDown(
      key,
      ctrl: ctrl,
      meta: meta,
      numpadMultiply: physical == PhysicalKeyboardKey.numpadMultiply,
      numpadDivide: physical == PhysicalKeyboardKey.numpadDivide,
    );
    return false;
  }

  void _toggleAngle(SettingsStore store) {
    store.update((s) => s.copyWith(
        angleMode:
            s.angleMode == AngleMode.deg ? AngleMode.rad : AngleMode.deg));
  }

  void _syncPinned(bool portrait) {
    final pinned = _pinned;
    if (pinned == null) return;
    if (portrait) {
      _pinnedWidget ??= _PortraitDisplay(controller: _c);
      if (!_pinnedShown || !identical(pinned.widget, _pinnedWidget)) {
        _pinnedShown = true;
        final w = _pinnedWidget;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) pinned.set(w);
        });
      }
    } else if (_pinnedShown) {
      _pinnedShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pinned.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsStore = context.watch<SettingsStore>();
    final settings = settingsStore.settings;
    final history = context.watch<HistoryStore>();
    _c.updateProps(
      angleMode: settings.angleMode,
      decimalPrecision: settings.decimalPrecision,
      soundEnabled: settings.soundEnabled,
      hapticEnabled: settings.hapticEnabled,
      history: history.items,
      casio: CasioRuntime.instance.configFor(settings),
    );

    final size = MediaQuery.sizeOf(context);
    final layout = ShellLayout.of(size);
    _syncPinned(!layout.isLandscape);

    // New widget instances on every controller change, so the keys and the display rebuild.
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => layout.isLandscape
          ? _Landscape(
              controller: _c, onToggleAngle: () => _toggleAngle(settingsStore))
          : _PortraitKeys(
              controller: _c, onToggleAngle: () => _toggleAngle(settingsStore)),
    );
  }
}

// ======================================================================================================================
// Shared pieces
// ======================================================================================================================

/// Line box of Tailwind's `text-2xl` .. `text-6xl` (px): 24 -> 32, 30 -> 36, 36 -> 40, 48 -> 48, 60 -> 60.
double _tailwindLineHeight(double size) => switch (size) {
      24 => 32,
      30 => 36,
      36 => 40,
      _ => size,
    };

/// `h-full w-full m3-key` key with a centred label.
class _Key extends StatelessWidget {
  const _Key({
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.radius,
    required this.child,
    this.semanticLabel,
  });

  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final double radius;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return M3Key(
      foreground: foreground,
      background: background,
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Center(child: child),
    );
  }
}

Widget _label(String s, double size, FontWeight weight, Color color,
    {bool mono = false, double? letterSpacingEm}) {
  return Text(
    s,
    maxLines: 1,
    softWrap: false,
    style: calcText(
        size: size,
        weight: weight,
        color: color,
        lineHeight: size * 1.5,
        mono: mono,
        letterSpacingEm: letterSpacingEm),
  );
}

/// The `=` key: springs smaller, brightens and glows while a hardware Enter / = is flashing it.
class _EqualsKey extends StatelessWidget {
  const _EqualsKey(
      {required this.controller, required this.radius, required this.child});

  final CalculatorController controller;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final pressed = controller.isEqualsPressed;
    final instant = reduceMotion(context);
    Color bright(Color c) {
      int ch(double v) => (v * 255 * 1.25).clamp(0, 255).round();
      return Color.fromARGB((c.a * 255).round(), ch(c.r), ch(c.g), ch(c.b));
    }

    return AnimatedScale(
      scale: pressed ? 0.93 : 1.0,
      duration: instant ? Duration.zero : const Duration(milliseconds: 150),
      curve: M3Curves.tailwind,
      child: AnimatedContainer(
        duration: instant ? Duration.zero : const Duration(milliseconds: 150),
        curve: M3Curves.tailwind,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: pressed
              ? [
                  BoxShadow(
                      color: withAlphaFraction(t.primary, 0.85),
                      blurRadius: 32,
                      spreadRadius: 6)
                ]
              : const [],
        ),
        child: _Key(
          onTap: controller.handleEvaluate,
          background: pressed ? bright(t.primary) : t.primary,
          foreground: t.onPrimary,
          radius: radius,
          semanticLabel: 'Equals',
          child: child,
        ),
      ),
    );
  }
}

/// Memory ribbon button (MC, MR, M+, M-).
String _memoryLabel(MemoryAction a) => switch (a) {
      MemoryAction.mc => 'MC',
      MemoryAction.mr => 'MR',
      MemoryAction.mPlus => 'M+',
      MemoryAction.mMinus => 'M-',
      MemoryAction.ms => 'MS',
    };

const List<MemoryAction> _ribbon = [
  MemoryAction.mc,
  MemoryAction.mr,
  MemoryAction.mPlus,
  MemoryAction.mMinus
];

/// Round icon button of the display card (history, copy).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton(
      {required this.onTap,
      required this.child,
      required this.t,
      this.semanticLabel});

  final VoidCallback onTap;
  final Widget child;
  final M3Tokens t;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return M3Key(
      foreground: t.onSurfaceVariant,
      background: t.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton(
      {required this.t, required this.count, required this.onTap});

  final M3Tokens t;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundIconButton(
      t: t,
      onTap: onTap,
      semanticLabel: 'History tape',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LucideIcon(LucideIconId.rotateCcw,
              color: t.onSurfaceVariant, size: 16),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: t.primary, borderRadius: BorderRadius.circular(9999)),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: calcText(
                    size: 10,
                    weight: FontWeight.w700,
                    color: t.onPrimary,
                    lineHeight: 15,
                    mono: true),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.t, required this.controller});

  final M3Tokens t;
  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return _RoundIconButton(
      t: t,
      onTap: controller.handleCopy,
      semanticLabel: 'Copy result',
      child: controller.copied
          ? const LucideIcon(LucideIconId.check,
              color: Color(0xFF22C55E), size: 16)
          : LucideIcon(LucideIconId.copy, color: t.onSurfaceVariant, size: 16),
    );
  }
}

/// Leaves the superscript / subscript the caret is in (the "exit" key of the rich editor). Shown only while the
/// caret is inside a group, in the badge row, so the keypad and the layout stay as they were.
class _ExitGroupChip extends StatelessWidget {
  const _ExitGroupChip(
      {required this.t, required this.size, required this.onTap});

  final M3Tokens t;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return M3Key(
      foreground: t.primary,
      background: t.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      semanticLabel: 'Exit power or subscript',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          '→',
          style: calcText(
              size: size,
              weight: FontWeight.w700,
              color: t.primary,
              lineHeight: size * (size == 12 ? 16 / 12 : 20 / 14),
              mono: true),
        ),
      ),
    );
  }
}

/// The status-bar annunciators of the natural display (Part 9, section 9.2): S, A, INS, M, Math, and the Syntax ERROR
/// line. Nothing is drawn while none is on, so plain arithmetic keeps the badge row it always had.
class _AnnunciatorChips extends StatelessWidget {
  const _AnnunciatorChips(
      {required this.t, required this.controller, required this.size});

  final M3Tokens t;
  final CalculatorController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    final names = controller.annunciators;
    final error = controller.syntaxError;
    if (names.isEmpty && error == null) return const SizedBox.shrink();
    final line = size * (size == 12 ? 16 / 12 : 20 / 14);
    Widget chip(String text, {required Color fg, required Color bg}) =>
        Flexible(
          child: Container(
            key: ValueKey('annunciator-$text'),
            padding: EdgeInsets.symmetric(
                horizontal: 8, vertical: size == 12 ? 2 : 3),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(9999)),
            child: Semantics(
              label: 'Annunciator $text',
              excludeSemantics: true,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: calcText(
                    size: size - 2,
                    weight: FontWeight.w700,
                    color: fg,
                    lineHeight: line,
                    mono: true),
              ),
            ),
          ),
        );
    // a Flexible so a long line ("Syntax ERROR" beside S, A, Math) shrinks instead of overflowing the badge row
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in names) ...[
            const SizedBox(width: 6),
            chip(n, fg: t.onSecondaryContainer, bg: t.secondaryContainer),
          ],
          if (error != null) ...[
            const SizedBox(width: 6),
            chip(error, fg: t.onErrorContainer, bg: t.errorContainer),
          ],
        ],
      ),
    );
  }
}

class _AngleBadge extends StatelessWidget {
  const _AngleBadge(
      {required this.t,
      required this.controller,
      required this.onTap,
      required this.size,
      required this.vPad});

  final M3Tokens t;
  final CalculatorController controller;
  final VoidCallback onTap;
  final double size;
  final double vPad;

  @override
  Widget build(BuildContext context) {
    return M3Key(
      foreground: t.primary,
      background: t.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(9999),
      onTap: onTap,
      semanticLabel: 'Angle mode',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: vPad),
        child: Text(
          // from the store, not the controller: the controller only learns the new mode when the screen rebuilds
          context.watch<SettingsStore>().settings.angleMode.id.toUpperCase(),
          style: calcText(
              size: size,
              weight: FontWeight.w700,
              color: t.primary,
              lineHeight: size * (size == 12 ? 16 / 12 : 20 / 14),
              mono: true),
        ),
      ),
    );
  }
}

// ======================================================================================================================
// Portrait
// ======================================================================================================================

/// The answer card pinned under the header on phones (`portraitDisplay`).
class _PortraitDisplay extends StatelessWidget {
  const _PortraitDisplay({required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: controller, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final t = M3Theme.of(context);
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final c = controller;
    final settingsStore = context.watch<SettingsStore>();
    final nav = context.read<NavigationState>();
    final history = context.watch<HistoryStore>();
    final settings = settingsStore.settings;
    final instant = reduceMotion(context);

    final maxW = tw(w, 576, sm: 672, md: 768, lg: 896);
    final radius = tw(w, 28, sm: 32);
    final pad = tw(w, 14, sm: 20);
    final minH = (mq.size.height * 0.30).clamp(214.0, 330.0);
    final smallText = w >= 640;

    final headerRow = Header(
      embedded: true,
      soundEnabled: settings.soundEnabled,
      onToggleSound: () => settingsStore
          .update((s) => s.copyWith(soundEnabled: !s.soundEnabled)),
      onOpenSettings: () => nav.setSettingsOpen(true),
      onOpenGuide: () => nav.setGuideOpen(true),
    );

    final Widget answer;
    if (c.isErrorResult) {
      answer = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 120),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: M3ResultUpdate(
              trigger: c.expression,
              child: Text(
                c.expression,
                textAlign: TextAlign.right,
                style: calcText(
                  size: smallText ? 18 : 16,
                  weight: FontWeight.w600,
                  color: t.error,
                  lineHeight: (smallText ? 18 : 16) * 1.375,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      final fit = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichExpressionView(
          doc: c.hasEvaluated ? c.resultDoc : c.doc,
          max: 72,
          min: 26,
          color: c.hasEvaluated ? t.primary : t.onSurface,
          showCaret: c.caretVisible,
          caretColor: t.primary,
          onCaretHit: c.placeCaret,
        ),
      );
      answer = c.hasEvaluated
          ? M3ResultUpdate(
              trigger: '${c.expression}|${c.lastQuestion}', child: fit)
          : fit;
    }

    final card = Container(
      constraints: BoxConstraints(maxWidth: maxW, minHeight: minH),
      child: BarSurface(
        borderRadius: BorderRadius.circular(radius),
        tone: t.surfaceContainerHighest,
        strong: true,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: IntrinsicHeight(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minH - 2 * pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App header row, part of this card
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: withAlphaFraction(t.onSurface, 0.10))),
                    ),
                    child: headerRow,
                  ),
                  // Angle badge, open parentheses counter, history and copy
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                            child: Row(
                          children: [
                            _AngleBadge(
                              t: t,
                              controller: c,
                              onTap: () =>
                                  _toggleAngleFrom(context, settingsStore),
                              size: smallText ? 14 : 12,
                              vPad: 4,
                            ),
                            _AnnunciatorChips(
                                t: t, controller: c, size: smallText ? 14 : 12),
                            if (c.caretInGroup) ...[
                              const SizedBox(width: 8),
                              _ExitGroupChip(
                                t: t,
                                size: smallText ? 14 : 12,
                                onTap: c.exitGroup,
                              ),
                            ],
                            if (c.openParensCount > 0) ...[
                              const SizedBox(width: 8),
                              _PulsingBadge(
                                text: '${c.openParensCount} unclosed (',
                                t: t,
                                size: smallText ? 14 : 12,
                                animate: !instant,
                              ),
                            ],
                          ],
                        )),
                        Row(
                          children: [
                            _HistoryButton(
                                t: t,
                                count: history.count,
                                onTap: () => nav.setHistoryOpen(true)),
                            const SizedBox(width: 8),
                            _CopyButton(t: t, controller: c),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Expression and answer: big, and it shrinks smoothly instead of getting cut off
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (c.hasEquation)
                            _EquationLine(
                                controller: c, t: t, size: smallText ? 14 : 12),
                          if (c.questionLine.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                c.questionLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: calcText(
                                  size: smallText ? 16 : 14,
                                  weight: FontWeight.w400,
                                  color: t.outline,
                                  lineHeight: smallText ? 24 : 20,
                                  letterSpacingEm: 0.025,
                                  opacity: 0.7,
                                ),
                              ),
                            ),
                          answer,
                          // Small live answer; turns into the big answer when = is pressed. Fixed height so keys never jump.
                          if (!c.hasEvaluated || c.sessionExtra.isNotEmpty)
                            SizedBox(
                              height: smallText ? 32 : 28,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  c.hasEvaluated
                                      ? c.sessionExtra
                                      : (c.livePreview.isEmpty
                                          ? ''
                                          : '= ${c.livePreview}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: calcText(
                                    size: smallText ? 20 : 18,
                                    weight: FontWeight.w600,
                                    color: t.primary,
                                    lineHeight: smallText ? 28 : 28,
                                    letterSpacingEm: -0.025,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // motion: initial opacity 0, y -10 -> in, spring
    return Align(
      alignment: Alignment.topCenter,
      child: instant
          ? card
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: M3Curves.emphasizedDecelerate,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.translate(
                    offset: Offset(0, -10 * (1 - v)), child: child),
              ),
              child: card,
            ),
    );
  }

  void _toggleAngleFrom(BuildContext context, SettingsStore store) {
    store.update((s) => s.copyWith(
        angleMode:
            s.angleMode == AngleMode.deg ? AngleMode.rad : AngleMode.deg));
  }
}

/// `animate-pulse` badge with the number of unclosed parentheses.
class _PulsingBadge extends StatefulWidget {
  const _PulsingBadge(
      {required this.text,
      required this.t,
      required this.size,
      required this.animate});

  final String text;
  final M3Tokens t;
  final double size;
  final bool animate;

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _ctl.repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, child) {
        // Tailwind animate-pulse: opacity 1 -> 0.5 at 50% -> 1, cubic-bezier(0.4, 0, 0.6, 1), 2 s
        final p = _ctl.value;
        final phase = p < 0.5 ? p * 2 : (1 - p) * 2;
        final eased = const Cubic(0.4, 0, 0.6, 1).transform(phase);
        return Opacity(
            opacity: widget.animate ? 1 - 0.5 * eased : 1, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
            color: t.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(9999)),
        child: Text(
          widget.text,
          style: calcText(
            size: widget.size,
            weight: FontWeight.w400,
            color: t.tertiary,
            lineHeight: widget.size == 12 ? 16 : 20,
            mono: true,
          ),
        ),
      ),
    );
  }
}

class _EquationLine extends StatelessWidget {
  const _EquationLine(
      {required this.controller, required this.t, required this.size});

  final CalculatorController controller;
  final M3Tokens t;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final hint = (c.lastQuestion.isNotEmpty || c.expression != '0')
        ? ''
        : '· type x, then =';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'y = ${c.equation} '),
            TextSpan(
              text: hint,
              style: calcText(
                  size: size,
                  weight: FontWeight.w400,
                  color: t.tertiary,
                  lineHeight: size == 12 ? 16 : 20,
                  opacity: 0.8),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: calcText(
            size: size,
            weight: FontWeight.w600,
            color: t.tertiary,
            lineHeight: size == 12 ? 16 : 20),
      ),
    );
  }
}

/// The keys card of the portrait layout (memory ribbon, advanced drawer, main keypad).
class _PortraitKeys extends StatelessWidget {
  const _PortraitKeys({required this.controller, required this.onToggleAngle});

  final CalculatorController controller;
  final VoidCallback onToggleAngle;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final c = controller;
    final maxW = tw(w, 576, sm: 672, md: 768, lg: 896, xl: 1024);
    final radius = tw(w, 28, sm: 36, md: 44);
    final pad = tw(w, 10, sm: 20, md: 24, lg: 28);
    final instant = reduceMotion(context);

    final ribbon = Padding(
      padding: EdgeInsets.only(bottom: tw(w, 8, sm: 12)),
      child: Row(
        children: [
          for (var i = 0; i < _ribbon.length; i++) ...[
            if (i > 0) SizedBox(width: tw(w, 6, sm: 10)),
            Expanded(
              child: SizedBox(
                height: tw(w, 32, sm: 40, md: 44),
                child: _Key(
                  onTap: () => c.handleMemory(_ribbon[i]),
                  background: (_ribbon[i] == MemoryAction.mr && c.memory != 0)
                      ? t.secondaryContainer
                      : t.surfaceContainer,
                  foreground: (_ribbon[i] == MemoryAction.mr && c.memory != 0)
                      ? t.onSecondaryContainer
                      : t.onSurfaceVariant,
                  radius: 9999,
                  child: _label(
                    _memoryLabel(_ribbon[i]),
                    tw(w, 12, sm: 14),
                    FontWeight.w700,
                    (_ribbon[i] == MemoryAction.mr && c.memory != 0)
                        ? t.onSecondaryContainer
                        : t.onSurfaceVariant,
                    mono: true,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final drawer = AnimatedSize(
      duration: instant ? Duration.zero : const Duration(milliseconds: 320),
      curve: M3Curves.spring,
      alignment: Alignment.topCenter,
      child: c.isScientific
          ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CachedIntrinsicHeight(
                estimate: 300,
                child: _AdvancedDrawer(
                    controller: c, onToggleAngle: onToggleAngle, width: w),
              ),
            )
          : const SizedBox(width: double.infinity),
    );

    final card = Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: withAlphaFraction(t.surfaceContainerLow, 0.96),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ribbon,
          drawer,
          Expanded(child: _PortraitKeypad(controller: c, width: w)),
        ],
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW), child: card),
    );
  }
}

class _AdvancedDrawer extends StatelessWidget {
  const _AdvancedDrawer(
      {required this.controller,
      required this.onToggleAngle,
      required this.width});

  final CalculatorController controller;
  final VoidCallback onToggleAngle;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final c = controller;
    final sm = width >= 640;
    final tabs = [
      for (final d in advancedTabDefs)
        TabItem(id: d.id.name, label: d.label, badge: d.badge)
    ];
    return Container(
      padding: EdgeInsets.all(sm ? 16 : 12),
      decoration: BoxDecoration(
          color: t.surfaceContainer, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: withAlphaFraction(t.outlineVariant, 0.4)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OmniCalcLogo(size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Advanced Scientific Operations',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: calcText(
                            size: sm ? 14 : 12,
                            weight: FontWeight.w600,
                            color: t.onSurface,
                            lineHeight: sm ? 20 : 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                M3Key(
                  foreground: t.primary,
                  background: t.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                  onTap: c.hideScientific,
                  semanticLabel: 'Hide advanced keys',
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Hide',
                            style: calcText(
                                size: 12,
                                weight: FontWeight.w600,
                                color: t.primary,
                                lineHeight: 16)),
                        const SizedBox(width: 6),
                        LucideIcon(LucideIconId.chevronUp,
                            color: t.primary, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SwipeableTabContainer(
            tabs: tabs,
            activeTabId: c.advancedTab.name,
            onSelectTab: (id) => c.selectTab(AdvancedTab.values.byName(id)),
            compact: true,
            showNavButtons: true,
            tabBarBottomPadding: 4,
            tabBarBottomMargin: 8,
            tabPillColor: t.surfaceContainerHigh,
            child: KeyedSubtree(
              key: ValueKey(c.advancedTab),
              child: AdvancedTabContent(
                  controller: c,
                  onToggleAngleMode: onToggleAngle,
                  width: width,
                  landscape: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitKeypad extends StatelessWidget {
  const _PortraitKeypad({required this.controller, required this.width});

  final CalculatorController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final c = controller;
    final w = width;
    final sci = c.isScientific;

    final rowMin = sci ? 58.0 : 44.0;
    final keyMinH = tw(w, 40, sm: 64, md: 78, lg: 92, xl: 105);
    final gap = tw(w, 6, sm: 10, md: 14, lg: 16);
    final rowH = math.max(rowMin, keyMinH);
    final minHeight = math.max(5 * rowMin + 32, 5 * rowH + 4 * gap);
    final r = tw(w, 16, sm: 24, md: 32);
    final big = tw(w, 24, sm: 30, md: 36);

    Widget digit(String d) => _Key(
          onTap: () => c.handleInput(d),
          background: t.surfaceContainerHigh,
          foreground: t.onSurface,
          radius: r,
          child: _label(d, big, FontWeight.w500, t.onSurface, mono: true),
        );
    Widget op(String o) => _Key(
          onTap: () => c.handleInput(o),
          background: t.secondaryContainer,
          foreground: t.onSecondaryContainer,
          radius: r,
          child: _label(o, big, FontWeight.w600, t.onSecondaryContainer),
        );
    final smallFn = tw(w, 16, sm: 20, md: 24);

    final eqRadius = w >= 768 ? 32.0 : (w >= 640 ? 9999.0 : 16.0);

    final rows = <List<Widget>>[
      [
        _Key(
          onTap: c.handleClear,
          background: t.surfaceContainer,
          foreground: t.tertiary,
          radius: r,
          child: _label('AC', smallFn, FontWeight.w700, t.tertiary),
        ),
        _Key(
          onTap: c.handleBackspace,
          background: t.surfaceContainer,
          foreground: t.onSurfaceVariant,
          radius: r,
          semanticLabel: 'Backspace',
          child: LucideIcon(LucideIconId.delete,
              color: t.onSurfaceVariant, size: tw(w, 20, sm: 24, md: 28)),
        ),
        _Key(
          onTap: () => c.handleInput('%'),
          background: t.surfaceContainer,
          foreground: t.onSurfaceVariant,
          radius: r,
          child: _label('%', smallFn, FontWeight.w600, t.onSurfaceVariant),
        ),
        op('÷'),
      ],
      [digit('7'), digit('8'), digit('9'), op('×')],
      [digit('4'), digit('5'), digit('6'), op('−')],
      [digit('1'), digit('2'), digit('3'), op('+')],
      [
        _Key(
          onTap: c.toggleScientific,
          background: sci ? t.tertiaryContainer : t.surfaceContainer,
          foreground: sci ? t.onTertiaryContainer : t.primary,
          radius: r,
          semanticLabel:
              sci ? 'Hide advanced symbols keys' : 'Show advanced symbols keys',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            // scaleDown only acts when the content is wider than the key (narrow phones, fallback fonts)
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FxTurn(
                      key: ValueKey(sci),
                      child: OmniCalcLogo(size: tw(w, 16, sm: 20))),
                  const SizedBox(width: 6),
                  _label(sci ? 'fx ON' : 'fx ADV', tw(w, 12, sm: 16),
                      FontWeight.w700, sci ? t.onTertiaryContainer : t.primary,
                      mono: true, letterSpacingEm: -0.025),
                ],
              ),
            ),
          ),
        ),
        digit('0'),
        _Key(
          onTap: () => c.handleInput('.'),
          background: t.surfaceContainerHigh,
          foreground: t.onSurface,
          radius: r,
          child: _label('.', big, FontWeight.w700, t.onSurface, mono: true),
        ),
        _EqualsKey(
          controller: c,
          radius: eqRadius,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _label('=', big, FontWeight.w700, t.onPrimary),
              const SizedBox(width: 8),
              Opacity(
                  opacity: 0.75,
                  child: LucideIcon(LucideIconId.cornerDownLeft,
                      color: t.onPrimary, size: tw(w, 20, sm: 24))),
            ],
          ),
        ),
      ],
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: rowH),
                child: Row(
                  children: [
                    for (var k = 0; k < rows[i].length; k++) ...[
                      if (k > 0) SizedBox(width: gap),
                      Expanded(child: rows[i][k]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================================================================
// Landscape
// ======================================================================================================================

class _Landscape extends StatelessWidget {
  const _Landscape({required this.controller, required this.onToggleAngle});

  final CalculatorController controller;
  final VoidCallback onToggleAngle;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final gap = tw(w, 14, sm: 20);
    final leftW = tw(w, 320, sm: 360, md: 400, lg: 440, xl: 480);

    return CachedIntrinsicHeight(
      estimate: 500,
      child: LayoutBuilder(
        builder: (context, box) {
          final height =
              math.max(500.0, box.hasBoundedHeight ? box.maxHeight : 500.0);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        width: leftW,
                        child: _LandscapeDisplay(
                            controller: controller,
                            onToggleAngle: onToggleAngle)),
                    SizedBox(width: gap),
                    Expanded(
                        child: _LandscapeKeys(
                            controller: controller,
                            onToggleAngle: onToggleAngle)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LandscapeDisplay extends StatelessWidget {
  const _LandscapeDisplay(
      {required this.controller, required this.onToggleAngle});

  final CalculatorController controller;
  final VoidCallback onToggleAngle;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final c = controller;
    final nav = context.read<NavigationState>();
    final history = context.watch<HistoryStore>();
    final items = history.items;
    final pad = tw(w, 16, sm: 24);
    final sm = w >= 640;

    final len = c.expression.length;
    final double exprSize = len > 14
        ? tw(w, 24, sm: 30)
        : len > 8
            ? tw(w, 30, sm: 36, lg: 48)
            : tw(w, 36, sm: 48, lg: 60);

    final tape = items.isEmpty
        ? const SizedBox.shrink()
        : Opacity(
            opacity: 0.6,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in items.take(2).toList().reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => nav.loadExpression(h.expression),
                        child: h.rich != null
                            // entries with superscripts / subscripts keep their look; older entries are plain text
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: RichExpressionView(
                                      doc: ExprDoc.fromJson(h.rich) ??
                                          ExprDoc.plain(h.expression),
                                      fit: false,
                                      max: 12,
                                      lineHeightPx: 16,
                                      weight: FontWeight.w400,
                                      letterSpacingEm: 0,
                                      color: withAlphaFraction(
                                          t.onSurfaceVariant, 0.7),
                                    ),
                                  ),
                                  Text(
                                    ' = ${h.result}',
                                    maxLines: 1,
                                    style: calcText(
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: t.onSurfaceVariant,
                                        lineHeight: 16,
                                        mono: true),
                                  ),
                                ],
                              )
                            : Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                      text: h.expression,
                                      style: TextStyle(
                                          color: withAlphaFraction(
                                              t.onSurfaceVariant, 0.7))),
                                  const TextSpan(text: ' = '),
                                  TextSpan(
                                      text: h.result,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: calcText(
                                    size: 12,
                                    weight: FontWeight.w400,
                                    color: t.onSurfaceVariant,
                                    lineHeight: 16,
                                    mono: true),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          );

    final display = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        tape,
        if (c.hasEquation)
          _EquationLine(controller: c, t: t, size: sm ? 14 : 12),
        if (c.questionLine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              c.questionLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: calcText(
                  size: 14,
                  weight: FontWeight.w400,
                  color: t.outline,
                  lineHeight: 20,
                  mono: true,
                  letterSpacingEm: 0.025,
                  opacity: 0.7),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: RichExpressionView(
              doc: c.doc,
              fit: false,
              max: exprSize,
              lineHeightPx: _tailwindLineHeight(exprSize),
              color: t.onSurface,
              showCaret: c.caretVisible,
              caretColor: t.primary,
              onCaretHit: c.placeCaret,
            ),
          ),
        ),
        if (!c.hasEvaluated || c.sessionExtra.isNotEmpty)
          SizedBox(
            height: 28,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  c.hasEvaluated ? c.sessionExtra : (c.livePreview.isEmpty ? '' : '= ${c.livePreview}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: calcText(
                      size: sm ? 18 : 16,
                      weight: FontWeight.w600,
                      color: t.primary,
                      lineHeight: sm ? 28 : 24,
                      mono: true,
                      letterSpacingEm: -0.025),
                ),
              ),
            ),
          ),
        if (c.lastAnswer.isNotEmpty && c.hasEvaluated)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: M3ResultUpdate(
              trigger: c.lastAnswer,
              child: Text(
                '= ${c.lastAnswer}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: calcText(
                  size: tw(w, 24, sm: 30, lg: 36),
                  weight: FontWeight.w700,
                  color: t.primary,
                  lineHeight: tw(w, 32, sm: 36, lg: 40),
                  mono: true,
                  letterSpacingEm: -0.025,
                ),
              ),
            ),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
          color: t.surfaceContainerLow,
          borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    _AngleBadge(
                        t: t,
                        controller: c,
                        onTap: onToggleAngle,
                        size: 12,
                        vPad: 6),
                    _AnnunciatorChips(t: t, controller: c, size: 12),
                  ],
                ),
              ),
              Row(
                children: [
                  _HistoryButton(
                      t: t,
                      count: history.count,
                      onTap: () => nav.setHistoryOpen(true)),
                  const SizedBox(width: 8),
                  _CopyButton(t: t, controller: c),
                ],
              ),
            ],
          ),
          Expanded(
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: SizedBox(width: double.infinity, child: display)),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: withAlphaFraction(t.outlineVariant, 0.3)))),
            child: Row(
              children: [
                for (var i = 0; i < _ribbon.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: sm ? 44 : 40,
                      child: _Key(
                        onTap: () => c.handleMemory(_ribbon[i]),
                        background: t.surfaceContainer,
                        foreground: t.onSurfaceVariant,
                        radius: 16,
                        child: _label(_memoryLabel(_ribbon[i]), 12,
                            FontWeight.w700, t.onSurfaceVariant,
                            mono: true),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeKeys extends StatelessWidget {
  const _LandscapeKeys({required this.controller, required this.onToggleAngle});

  final CalculatorController controller;
  final VoidCallback onToggleAngle;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final c = controller;
    final pad = tw(w, 14, sm: 20);
    final colGap = tw(w, 10, sm: 12);
    final keyGap = tw(w, 8, sm: 10);
    final minKey = tw(w, 46, sm: 54, md: 62);
    final r = tw(w, 22, sm: 26);
    final sm = w >= 640;
    final tabs = [
      for (final d in advancedTabDefs)
        TabItem(id: d.id.name, label: d.label, badge: d.badge)
    ];

    Widget digit(String d) => _Key(
          onTap: () => c.handleInput(d),
          background: t.surfaceContainerHigh,
          foreground: t.onSurface,
          radius: r,
          child:
              _label(d, sm ? 24 : 20, FontWeight.w500, t.onSurface, mono: true),
        );
    Widget op(String o) => _Key(
          onTap: () => c.handleInput(o),
          background: t.secondaryContainer,
          foreground: t.onSecondaryContainer,
          radius: r,
          child: _label(o, 24, FontWeight.w700, t.onSecondaryContainer),
        );
    Widget fnKey(VoidCallback onTap, Widget child) => _Key(
        onTap: onTap,
        background: t.surfaceContainer,
        foreground: t.onSurface,
        radius: r,
        child: child);

    final rows = <List<(int span, Widget child)>>[
      [
        (
          1,
          _Key(
              onTap: c.handleClear,
              background: t.tertiaryContainer,
              foreground: t.onTertiaryContainer,
              radius: r,
              child: _label('AC', 16, FontWeight.w700, t.onTertiaryContainer))
        ),
        (
          1,
          fnKey(c.handleBackspace,
              LucideIcon(LucideIconId.delete, color: t.onSurface, size: 20))
        ),
        (
          1,
          fnKey(() => c.handleInput('%'),
              _label('%', 16, FontWeight.w600, t.onSurface))
        ),
        (1, op('÷')),
      ],
      [(1, digit('7')), (1, digit('8')), (1, digit('9')), (1, op('×'))],
      [(1, digit('4')), (1, digit('5')), (1, digit('6')), (1, op('−'))],
      [(1, digit('1')), (1, digit('2')), (1, digit('3')), (1, op('+'))],
      [
        (2, digit('0')),
        (
          1,
          _Key(
            onTap: () => c.handleInput('.'),
            background: t.surfaceContainerHigh,
            foreground: t.onSurface,
            radius: r,
            child: _label('.', sm ? 24 : 20, FontWeight.w700, t.onSurface,
                mono: true),
          ),
        ),
        (
          1,
          _EqualsKey(
            controller: c,
            radius: r,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _label('=', 24, FontWeight.w700, t.onPrimary),
                  const SizedBox(width: 6),
                  Opacity(
                      opacity: 0.8,
                      child: LucideIcon(LucideIconId.cornerDownLeft,
                          color: t.onPrimary, size: 16)),
                ],
              ),
            ),
          ),
        ),
      ],
    ];

    final keypad = Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: keyGap),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minKey),
              child: Row(
                children: [
                  for (var k = 0; k < rows[i].length; k++) ...[
                    if (k > 0) SizedBox(width: keyGap),
                    Expanded(
                        flex: rows[i][k].$1 == 2 ? 2 : 1, child: rows[i][k].$2),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
          color: t.surfaceContainerLow,
          borderRadius: BorderRadius.circular(32)),
      child: ClipRect(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SwipeableTabContainer(
                tabs: tabs,
                activeTabId: c.advancedTab.name,
                onSelectTab: (id) => c.selectTab(AdvancedTab.values.byName(id)),
                compact: true,
                showNavButtons: true,
                tabBarBottomPadding: 4,
                tabBarBottomMargin: 8,
                fillHeight: true,
                child: KeyedSubtree(
                  key: ValueKey(c.advancedTab),
                  child: AdvancedTabContent(
                      controller: c,
                      onToggleAngleMode: onToggleAngle,
                      width: w,
                      landscape: true),
                ),
              ),
            ),
            SizedBox(width: colGap),
            Expanded(child: keypad),
          ],
        ),
      ),
    );
  }
}
