import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../services/feedback_service.dart';
import '../../state/app_settings.dart';
import '../../state/history_store.dart';
import '../../state/navigation_state.dart';
import '../../state/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/edge_effects.dart';
import '../../theme/glass.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'bottom_nav_bar.dart';
import 'header.dart';
import 'measure_size.dart';
import 'navigation_rail.dart';
import 'pinned_slot.dart';

/// Builds the screen of a mode.
typedef ScreenBuilder = Widget Function(BuildContext context, CalculatorMode mode);

/// Layer above the shell (History tape, Settings, Guide): shown on top of everything, driven by [NavigationState].
typedef OverlayBuilder = List<Widget> Function(BuildContext context, NavigationState nav);

/// No layers: the shell on its own (tests of the shell itself). The app passes `appOverlays`.
List<Widget> noOverlays(BuildContext context, NavigationState nav) => const <Widget>[];

/// Screen sizing of `useOrientation` + `isLargeScreen` (App.tsx).
class ShellLayout {
  const ShellLayout({required this.isLandscape, required this.isTablet, required this.isLargeScreen});

  factory ShellLayout.of(Size size) {
    final width = size.width;
    final height = size.height;
    final minDim = math.min(width, height);
    final maxDim = math.max(width, height);
    final isLandscape = width > height && width >= 540;
    final isTablet = minDim >= 600 || (maxDim >= 900 && minDim >= 540);
    final isLarge = width >= 960 || (isTablet && isLandscape) || (isTablet && width >= 720);
    return ShellLayout(isLandscape: isLandscape, isTablet: isTablet, isLargeScreen: isLarge);
  }

  final bool isLandscape;
  final bool isTablet;
  final bool isLargeScreen;
}

/// Port of the layout and behaviour of App.tsx: the scroll area under floating bars, the edge mask, the collapsing
/// header, the bottom bar or navigation rail, back handling, keyboard shortcuts and the exit hint.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.feedback,
    this.screenBuilder = placeholderScreen,
    this.overlayBuilder = noOverlays,
  });

  final FeedbackService feedback;
  final ScreenBuilder screenBuilder;
  final OverlayBuilder overlayBuilder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ScrollController _scroll = ScrollController();
  final EdgeFade _fade = EdgeFade();
  final FocusNode _focus = FocusNode(debugLabel: 'AppShell');

  double _topH = 84;
  double _headerH = 72;
  double _bottomH = 88;
  bool _collapsed = false;
  bool _collapseTarget = false;
  CalculatorMode? _lastMode;

  @override
  void dispose() {
    _scroll.dispose();
    _fade.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  void _onMeasure({double? top, double? header, double? bottom}) {
    final t = top?.roundToDouble() ?? _topH;
    final h = header?.roundToDouble() ?? _headerH;
    final b = bottom?.roundToDouble() ?? _bottomH;
    if (t == _topH && h == _headerH && b == _bottomH) return;
    _setStateSafe(() {
      _topH = t;
      _headerH = h;
      _bottomH = b;
    });
  }

  /// The scroll listener of App.tsx: edge fade strengths and the header hysteresis (collapse past 36 px, expand under 10 px).
  void _onScrollMetrics(ScrollMetrics m, CalculatorMode mode) {
    final collapses = mode != CalculatorMode.standard;
    if (!collapses) {
      _collapseTarget = false;
    } else if (m.pixels > 36) {
      _collapseTarget = true;
    } else if (m.pixels < 10) {
      _collapseTarget = false;
    }
    if (_collapseTarget != _collapsed) {
      _setStateSafe(() => _collapsed = _collapseTarget);
    }
    _fade.updateFromScroll(pixels: m.pixels, maxScrollExtent: m.maxScrollExtent);
  }

  /// Each screen starts at the top.
  void _onModeChanged(CalculatorMode mode) {
    _collapseTarget = false;
    if (_collapsed) setState(() => _collapsed = false);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _fade.updateFromScroll(pixels: 0, maxScrollExtent: _scroll.hasClients ? _scroll.position.maxScrollExtent : 0);
  }

  void _logoTap() {
    if (!_scroll.hasClients) return;
    if (reduceMotion(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void _toggleSound(SettingsStore store) {
    store.update((s) => s.copyWith(soundEnabled: !s.soundEnabled));
  }

  bool _typingInField() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, NavigationState nav, AppSettings settings) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (nav.isGuideOpen) {
        nav.setGuideOpen(false);
        return KeyEventResult.handled;
      }
      if (nav.isSettingsOpen) {
        nav.setSettingsOpen(false);
        return KeyEventResult.handled;
      }
      if (nav.isHistoryOpen) {
        nav.setHistoryOpen(false);
        return KeyEventResult.handled;
      }
    }
    if (_typingInField()) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed && !keyboard.isControlPressed && !keyboard.isMetaPressed) {
      void go(CalculatorMode m) {
        nav.setHistoryOpen(false);
        nav.setMode(m);
      }

      if (key == LogicalKeyboardKey.digit1) {
        go(CalculatorMode.standard);
      } else if (key == LogicalKeyboardKey.digit2) {
        go(CalculatorMode.converter);
      } else if (key == LogicalKeyboardKey.digit3 && settings.enablePhysics) {
        go(CalculatorMode.physics);
      } else if (key == LogicalKeyboardKey.digit4) {
        go(CalculatorMode.finance);
      } else if (key == LogicalKeyboardKey.digit5 && settings.enableGrapher) {
        go(CalculatorMode.grapher);
      } else if (key == LogicalKeyboardKey.keyH || key == LogicalKeyboardKey.keyR) {
        nav.toggleHistory();
      } else if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.comma) {
        nav.toggleSettings();
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final nav = context.watch<NavigationState>();
    final settingsStore = context.watch<SettingsStore>();
    final settings = settingsStore.settings;
    final history = context.watch<HistoryStore>();
    final pinned = context.watch<PinnedSlotController>();
    final mq = MediaQuery.of(context);
    final layout = ShellLayout.of(mq.size);
    final mode = nav.mode;
    final mergeHeader = mode == CalculatorMode.standard && !layout.isLandscape;
    final large = layout.isLargeScreen;

    if (_lastMode != mode) {
      final first = _lastMode == null;
      _lastMode = mode;
      if (!first) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onModeChanged(mode);
        });
      }
    }

    // effects that App.tsx runs in useEffect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.feedback.setVibrationIntensity(settings.vibrationIntensity);
      nav.enforceEnabledModes(enableGrapher: settings.enableGrapher, enablePhysics: settings.enablePhysics);
    });

    final style = ShellStyle.fromSettings(settings);
    final fadePxValue = fadePx[settings.fadeHeight]!;
    final hasPinned = mergeHeader || _topH - _headerH > 8;
    final topEdge = _topH - (hasPinned ? 8 : 4);
    final topGlow = hasPinned ? 34.0 : math.max(26.0, _headerH - 22);
    final bottomBars = large ? 0.0 : _bottomH;
    final spec = EdgeMaskSpec.build(
      EdgeGeometry(topEdge: topEdge, topGlow: topGlow, bottomH: bottomBars, fadePx: fadePxValue),
      settings.edgeEffect,
      settings.barStyle,
    );

    final wide = mq.size.width >= 640;
    final huge = mq.size.width >= 1024;
    final hPad = huge ? 32.0 : (wide ? 24.0 : 8.0);
    final vPad = wide ? 12.0 : 6.0;

    final headerProps = (
      soundEnabled: settings.soundEnabled,
      toggle: () => _toggleSound(settingsStore),
      settings: () => nav.setSettingsOpen(true),
      guide: () => nav.setGuideOpen(true),
    );

    final scrollArea = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) {
          _onScrollMetrics(n.metrics, mode);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0 && n.metrics.axis == Axis.vertical) _onScrollMetrics(n.metrics, mode);
            return false;
          },
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: _topH + 6)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1650),
                    child: Padding(
                      // The web's `min-h-full` column carries `padding-bottom: bottom-stack + 12px` itself (border-box), so
                      // the space under the bars is taken out of the height the screen fills, not added after it.
                      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad + (large ? 24 : bottomBars + 12)),
                      child: Column(
                        children: [
                          Expanded(
                            child: M3ScreenEnter(
                              key: ValueKey(mode),
                              child: widget.screenBuilder(context, mode),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final column = Stack(
      children: [
        Positioned.fill(child: EdgeMaskBox(spec: spec, fade: _fade, child: scrollArea)),
        if (settings.edgeEffect == EdgeEffect.blur) ...[
          EdgeBlur(layers: buildBlurLayers(topEdge, 20), strength: _fade, atTop: true),
          if (!large) EdgeBlur(layers: buildBlurLayers(_bottomH, 8), strength: _fade, atTop: false),
        ],
        // top bars: header pill, plus the answer display pinned beneath it on the calculator
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: MeasureSize(
            onChange: (s) => _onMeasure(top: s.height),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!mergeHeader)
                  MeasureSize(
                    onChange: (s) => _onMeasure(header: s.height),
                    child: Header(
                      soundEnabled: headerProps.soundEnabled,
                      onToggleSound: headerProps.toggle,
                      onOpenSettings: headerProps.settings,
                      onOpenGuide: headerProps.guide,
                      onLogoTap: _logoTap,
                      collapsed: _collapsed,
                    ),
                  ),
                if (pinned.widget != null)
                  Padding(
                    padding: // inside the top SafeArea the inset is 0, so max(env(safe-area-inset-top), 8px) is 8
                    EdgeInsets.fromLTRB(12, mergeHeader ? 8.0 : 0, 12, 8),
                    child: pinned.widget,
                  ),
              ],
            ),
          ),
        ),
        // floating bottom navigation dock
        if (!large)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MeasureSize(
              onChange: (s) => _onMeasure(bottom: s.height),
              child: BottomNavBar(
                currentMode: mode,
                onSelectMode: nav.selectMode,
                soundEnabled: settings.soundEnabled,
                hapticEnabled: settings.hapticEnabled,
                onToggleHistory: nav.toggleHistory,
                feedback: widget.feedback,
                isHistoryOpen: nav.isHistoryOpen,
                historyCount: history.count,
                enableGrapher: settings.enableGrapher,
                enablePhysics: settings.enablePhysics,
              ),
            ),
          ),
      ],
    );

    final body = large
        ? Row(
            children: [
              ShellNavigationRail(
                currentMode: mode,
                onSelectMode: nav.selectMode,
                soundEnabled: settings.soundEnabled,
                hapticEnabled: settings.hapticEnabled,
                onToggleSound: headerProps.toggle,
                onOpenSettings: headerProps.settings,
                onOpenGuide: headerProps.guide,
                onOpenHistory: nav.toggleHistory,
                feedback: widget.feedback,
                isHistoryOpen: nav.isHistoryOpen,
                historyCount: history.count,
                enableGrapher: settings.enableGrapher,
                enablePhysics: settings.enablePhysics,
              ),
              Expanded(child: column),
            ],
          )
        : column;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (nav.handleBack() == BackAction.exitApp) SystemNavigator.pop();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, event) => _onKey(node, event, nav, settings),
        child: ShellStyleScope(
          style: style,
          child: DefaultTextStyle(
            style: appText(size: 14, color: t.onSurface),
            child: ColoredBox(
              color: t.surface,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SafeArea(top: true, bottom: false, left: false, right: false, child: body),
                  ),
                  ...widget.overlayBuilder(context, nav),
                  if (nav.exitHint)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: bottomBars + 16,
                      child: IgnorePointer(
                        child: M3FadeIn(
                          child: Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: t.inverseSurface,
                                borderRadius: const BorderRadius.all(Radius.circular(9999)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x1A000000), offset: Offset(0, 10), blurRadius: 15, spreadRadius: -3),
                                  BoxShadow(color: Color(0x1A000000), offset: Offset(0, 4), blurRadius: 6, spreadRadius: -4),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Text(
                                  'Press back again to exit',
                                  style: appText(size: 12, weight: FontWeight.w600, color: t.surface, height: 16 / 12),
                                ),
                              ),
                            ),
                          ),
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
  }
}

/// Stand-in for the screens that arrive in Phases 4 and 5, so the shell can be run and compared on its own.
Widget placeholderScreen(BuildContext context, CalculatorMode mode) {
  final t = M3Theme.of(context);
  final label = switch (mode) {
    CalculatorMode.standard || CalculatorMode.scientific => 'Calculator (Phase 4)',
    CalculatorMode.converter => 'Converter (Phase 5)',
    CalculatorMode.finance => 'Finance (Phase 5)',
    CalculatorMode.physics => 'Physics Lab (Phase 5)',
    CalculatorMode.grapher => 'Grapher (Phase 5)',
  };
  return SizedBox(
    height: 1400,
    child: Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(label, style: appText(size: 16, weight: FontWeight.w600, color: t.onSurfaceVariant)),
      ),
    ),
  );
}
