import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'engine/currency.dart';
import 'services/feedback_service.dart';
import 'services/link_service.dart';
import 'state/app_settings.dart';
import 'state/history_store.dart';
import 'state/navigation_state.dart';
import 'state/settings_store.dart';
import 'theme/app_theme.dart';
import 'theme/dynamic_colors.dart';
import 'theme/tokens.dart';
import 'state/casio_settings.dart';
import 'state/drawer_layout.dart';
import 'ui/overlays/overlays.dart';
import 'ui/screens/screens.dart';
import 'ui/shell/app_shell.dart';
import 'ui/shell/pinned_slot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.load();
  await CasioRuntime.instance.load();
  await DrawerLayout.instance.load();
  final history = await HistoryStore.load();
  runApp(OmniCalcApp(
    settings: settings,
    history: history,
    systemColorsSource: const PlatformSystemColorsSource(),
    feedback: PlatformFeedbackService(),
  ));
}

/// Root of the app: the stores, the resolved theme (settings + system brightness + Material You colours) and the shell.
class OmniCalcApp extends StatefulWidget {
  const OmniCalcApp({
    super.key,
    required this.settings,
    required this.history,
    required this.systemColorsSource,
    required this.feedback,
    this.currencyService,
    this.linkService = const PlatformLinkService(),
  });

  final SettingsStore settings;
  final HistoryStore history;
  final SystemColorsSource systemColorsSource;
  final FeedbackService feedback;

  /// Live forex rates for the Currency tab. Null: the real service (network + `shared_preferences` cache). Tests pass a
  /// fake so no request leaves the test.
  final CurrencyService? currencyService;

  /// Opens the links of Settings > About and the privacy sheet in the browser. Tests pass a [RecordingLinkService].
  final LinkService linkService;

  @override
  State<OmniCalcApp> createState() => _OmniCalcAppState();
}

class _OmniCalcAppState extends State<OmniCalcApp> with WidgetsBindingObserver {
  final NavigationState _nav = NavigationState();
  final PinnedSlotController _pinned = PinnedSlotController();
  late final CurrencyService _currency = widget.currencyService ?? CurrencyService();
  SystemColors? _systemColors;
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    widget.settings.addListener(_onSettings);
    _refreshSystemColors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettings);
    _nav.dispose();
    _pinned.dispose();
    super.dispose();
  }

  void _onSettings() => setState(() {});

  /// `matchMedia('(prefers-color-scheme: dark)')` change.
  @override
  void didChangePlatformBrightness() {
    setState(() => _platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness);
    _refreshSystemColors();
  }

  /// `appStateChange` (the app became active again).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSystemColors();
  }

  Future<void> _refreshSystemColors() async {
    final colors = await widget.systemColorsSource.getSystemColors();
    if (!mounted || colors == null) return;
    setState(() => _systemColors = colors);
    widget.settings.applyDynamicAutoDefault();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings.settings;
    final isDark = switch (settings.colorMode) {
      ColorMode.system => _platformBrightness == Brightness.dark,
      ColorMode.dark => true,
      ColorMode.light => false,
    };
    final resolved = resolveTheme(themeId: settings.theme, isDark: isDark, system: _systemColors);

    // Status bar: page colour behind it; Capacitor's `Style.Dark` means light icons.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: resolved.pageSurface,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsStore>.value(value: widget.settings),
        ChangeNotifierProvider<HistoryStore>.value(value: widget.history),
        ChangeNotifierProvider<NavigationState>.value(value: _nav),
        ChangeNotifierProvider<PinnedSlotController>.value(value: _pinned),
        Provider<FeedbackService>.value(value: widget.feedback),
        Provider<CurrencyService>.value(value: _currency),
        Provider<LinkService>.value(value: widget.linkService),
      ],
      child: M3Theme(
        tokens: resolved.tokens,
        child: MaterialApp(
          title: 'OmniCalc',
          debugShowCheckedModeBanner: false,
          theme: buildThemeData(resolved.tokens),
          home: AppShell(feedback: widget.feedback, screenBuilder: appScreenBuilder, overlayBuilder: appOverlays),
        ),
      ),
    );
  }
}
