import 'dart:async';

import 'package:flutter/material.dart' show TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/currency.dart';
import 'package:omnicalc/engine/js_locale.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/ui/icons/lucide_icon.dart';
import 'package:omnicalc/ui/screens/currency_screen.dart';
import 'package:omnicalc/ui/screens/finance_screen.dart';
import 'package:omnicalc/ui/shell/app_shell.dart';
import 'package:provider/provider.dart';

import '../../support/fake_currency.dart';

Future<SilentFeedbackService> pumpCurrency(
  WidgetTester tester, {
  CurrencyService? service,
  Size size = const Size(400, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final feedback = SilentFeedbackService();
  await tester.pumpWidget(OmniCalcApp(
    settings: SettingsStore.memory(const AppSettings(), true),
    history: HistoryStore.memory(),
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: feedback,
    currencyService: service ?? offlineCurrencyService(),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  Provider.of<NavigationState>(tester.element(find.byType(AppShell)), listen: false).setMode(CalculatorMode.finance);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  feedback.log.clear();
  return feedback;
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// The converted amount. The test font (Ahem) is as wide as it is tall, so on a narrow card the amount may legitimately
/// be split with zero-width spaces (CSS `break-all`); the value is what is compared.
String amountText(WidgetTester tester) => textOf(tester, 'converted-amount').replaceAll('\u200B', '');

void main() {
  group('number formatting', () {
    test('toLocaleString with fraction digit limits (en-US)', () {
      expect(jsToLocaleString(1234.5, minFrac: 2, maxFrac: 4), '1,234.50');
      expect(jsToLocaleString(0, minFrac: 2, maxFrac: 4), '0.00');
      expect(jsToLocaleString(86.82, minFrac: 2, maxFrac: 4), '86.82');
      expect(jsToLocaleString(12.3456789, minFrac: 2, maxFrac: 4), '12.3457');
      expect(jsToLocaleString(1234567.5, minFrac: 2, maxFrac: 4), '1,234,567.50');
      expect(jsToLocaleString(-1234.5, minFrac: 2, maxFrac: 4), '-1,234.50');
      expect(jsToLocaleString(1000), '1,000');
      expect(jsToLocaleString(100), '100');
      expect(jsToLocaleString(1234.56789), '1,234.568');
      expect(jsToLocaleString(1000000), '1,000,000');
      expect(jsToLocaleString(2.5, maxFrac: 0), '3'); // half expands
      expect(jsToLocaleString(double.nan), 'NaN');
    });

    test('currency helpers', () {
      expect(currencyFor('INR').symbol, '₹');
      expect(currencyFor('XXX').flag, '🌐');
      expect(currencyFor('XXX').name, 'XXX');
      expect(currencyCopyText(100, 'USD', 'INR', 8682), '100 USD = 8,682.00 INR');
      expect(currencyCopyText(0.5, 'EUR', 'JPY', 80.12345), '0.5 EUR = 80.1235 JPY');
    });
  });

  group('finance screen', () {
    testWidgets('has the six tabs with icons, Currency first', (tester) async {
      await pumpCurrency(tester, size: const Size(1300, 1400));
      for (final label in ['Currency', 'Loan / EMI', 'SIP & Compound', 'SWP', 'Tip & Bill', 'ROI & CAGR']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final ids = tester.widgetList<LucideIcon>(find.byType(LucideIcon)).map((i) => i.id).toList();
      for (final f in financeTabs) {
        expect(ids, contains(f.icon), reason: f.label);
      }
    });

    testWidgets('switching tab plays the toggle click and shows that tab', (tester) async {
      final fb = await pumpCurrency(tester, size: const Size(1300, 1400));
      await tester.tap(find.text('SWP'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(fb.log.take(2), ['click:toggle', 'haptic:medium']);
      expect(find.byKey(const ValueKey('swp-corpus-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency-input')), findsNothing);
    });
  });

  group('offline (built-in rates)', () {
    testWidgets('first render: 100 USD to INR with the built-in table', (tester) async {
      await pumpCurrency(tester);
      expect(textOf(tester, 'status-label'), 'FOREX RATES (BUILT-IN)');
      expect(textOf(tester, 'status-updated'), '• Updated Built-in rates (offline)');
      expect(find.byKey(const ValueKey('rates-notice')), findsOneWidget);
      expect(
        find.text("Couldn't reach a live rate provider, so these are built-in approximate rates. Check your connection and tap Refresh Rates."),
        findsOneWidget,
      );
      expect(find.text('From Currency & Amount'), findsOneWidget);
      expect(find.text('Target Currency'), findsOneWidget);
      expect(textOf(tester, 'from-symbol'), '\$');
      expect(textOf(tester, 'to-symbol'), '₹');
      expect(amountText(tester), '8,682.00');
      expect(textOf(tester, 'converted-caption'), 'CONVERTED AMOUNT (INR)');
      expect(find.text('1 USD = 86.82 INR'), findsOneWidget);
      expect(find.text('1 INR = 0.0115 USD'), findsOneWidget);
      expect(find.text('🇺🇸 US Dollar (USD)'), findsOneWidget);
      expect(find.text('🇮🇳 Indian Rupee (INR)'), findsOneWidget);
      expect(textOf(tester, 'watchlist-title'), 'Quick Conversion Watchlist for 100 USD');
    });

    testWidgets('the watchlist has the six currencies', (tester) async {
      await pumpCurrency(tester);
      for (final code in ['EUR', 'GBP', 'JPY', 'AED', 'SGD', 'CAD']) {
        expect(find.byKey(ValueKey('watch-$code')), findsOneWidget, reason: code);
      }
      expect(find.text('€ 95.20'), findsOneWidget);
      expect(find.text('£ 79.40'), findsOneWidget);
      expect(find.text('1 USD = 0.95'), findsOneWidget);
    });

    testWidgets('typing an amount and a preset', (tester) async {
      final fb = await pumpCurrency(tester);
      await tester.enterText(find.byKey(const ValueKey('currency-input')), '250');
      await tester.pump();
      expect(amountText(tester), '21,705.00');
      expect(textOf(tester, 'watchlist-title'), 'Quick Conversion Watchlist for 250 USD');
      expect(find.text('1,000'), findsOneWidget); // preset labels are localised
      expect(find.text('5,000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('preset-1000')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<TextField>(find.byKey(const ValueKey('currency-input'))).controller!.text, '1000');
      expect(amountText(tester), '86,820.00');
      expect(textOf(tester, 'watchlist-title'), 'Quick Conversion Watchlist for 1,000 USD');
      expect(fb.log, isEmpty); // the web screen plays no sound of its own
    });

    testWidgets('empty or invalid input converts as 0', (tester) async {
      await pumpCurrency(tester);
      await tester.enterText(find.byKey(const ValueKey('currency-input')), '');
      await tester.pump();
      expect(amountText(tester), '0.00');
      expect(find.text('1 USD = 0.00 INR'), findsOneWidget);
      expect(textOf(tester, 'watchlist-title'), 'Quick Conversion Watchlist for 0 USD');
      await tester.enterText(find.byKey(const ValueKey('currency-input')), '.');
      await tester.pump();
      expect(amountText(tester), '0.00');
    });

    testWidgets('swap exchanges the currencies and keeps the amount', (tester) async {
      final fb = await pumpCurrency(tester);
      await tester.tap(find.byKey(const ValueKey('swap-currencies')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(textOf(tester, 'from-symbol'), '₹');
      expect(textOf(tester, 'to-symbol'), '\$');
      expect(textOf(tester, 'converted-caption'), 'CONVERTED AMOUNT (USD)');
      expect(amountText(tester), '1.1518');
      expect(find.text('1 INR = 0.0115 USD'), findsOneWidget);
      expect(fb.log, isEmpty);
    });

    testWidgets('tapping a watchlist tile makes it the target', (tester) async {
      await pumpCurrency(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('watch-EUR')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('watch-EUR')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(textOf(tester, 'converted-caption'), 'CONVERTED AMOUNT (EUR)');
      expect(amountText(tester), '95.20');
      expect(textOf(tester, 'to-symbol'), '€');
    });

    testWidgets('the currency pickers list every currency and apply the choice', (tester) async {
      await pumpCurrency(tester);
      await tester.tap(find.byKey(const ValueKey('to-currency-select')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Target Currency'), findsNWidgets(2)); // the card label and the dialog title
      await tester.tap(find.byKey(const ValueKey('option-GBP')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(textOf(tester, 'converted-caption'), 'CONVERTED AMOUNT (GBP)');
      expect(amountText(tester), '79.40');

      await tester.tap(find.byKey(const ValueKey('from-currency-select')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('From Currency'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('option-EUR')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(textOf(tester, 'from-symbol'), '€');
      expect(find.text('1 EUR = 0.834 GBP'), findsOneWidget); // 0.794 / 0.952 = 0.83403...
      expect(find.text('1 GBP = 1.199 EUR'), findsOneWidget); // 0.952 / 0.794 = 1.19899...
      expect(amountText(tester), '83.4034');
    });

    testWidgets('copy puts "amount FROM = result TO" on the clipboard and shows the tick', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final fb = await pumpCurrency(tester);
      await tester.tap(find.byKey(const ValueKey('copy-result')));
      await tester.pump();
      expect(copied, '100 USD = 8,682.00 INR');
      expect(fb.log, isEmpty);
      final during = tester.widgetList<LucideIcon>(find.byType(LucideIcon)).map((i) => i.id);
      expect(during, contains(LucideIconId.check));
      await tester.pump(const Duration(milliseconds: 2100));
      final after = tester.widgetList<LucideIcon>(find.byType(LucideIcon)).map((i) => i.id);
      expect(after, isNot(contains(LucideIconId.check)));
    });

    testWidgets('two columns on a tablet, one swap button', (tester) async {
      await pumpCurrency(tester, size: const Size(900, 1200));
      expect(find.byKey(const ValueKey('swap-currencies')), findsOneWidget);
      final inputX = tester.getTopLeft(find.byKey(const ValueKey('from-currency-select'))).dx;
      final resultX = tester.getTopLeft(find.byKey(const ValueKey('converted-caption'))).dx;
      expect(resultX, greaterThan(inputX));
      expect(amountText(tester), '8,682.00');
    });

    testWidgets('a phone has one column: results under the inputs', (tester) async {
      await pumpCurrency(tester);
      final inputY = tester.getTopLeft(find.byKey(const ValueKey('to-currency-select'))).dy;
      final resultY = tester.getTopLeft(find.byKey(const ValueKey('converted-caption'))).dy;
      expect(resultY, greaterThan(inputY));
    });
  });

  group('live rates', () {
    testWidgets('live status, no notice, stamp from the clock', (tester) async {
      await pumpCurrency(tester, service: liveCurrencyService());
      expect(textOf(tester, 'status-label'), 'LIVE FOREX EXCHANGE RATES');
      expect(textOf(tester, 'status-updated'), '• Updated 09:22');
      expect(find.byKey(const ValueKey('rates-notice')), findsNothing);
      expect(amountText(tester), '9,050.00'); // 100 USD x 90.5
      expect(find.text('1 USD = 90.50 INR'), findsOneWidget);
      expect(find.text('€ 300.00'), findsOneWidget); // EUR is the third popular currency: 1 + 2 = 3 per USD in the fake table
    });

    testWidgets('live rates were cached for the next start', (tester) async {
      final cache = MemoryRatesCache();
      await pumpCurrency(tester, service: liveCurrencyService(cache: cache));
      expect(cache.value, isNotNull);
      expect(cache.value, contains('"isLive":true'));
      expect(cache.value, contains('"status":"live"'));
    });

    testWidgets('saved rates are used, and labelled, when the network is down', (tester) async {
      final cache = MemoryRatesCache();
      // first run: live, which fills the cache
      await pumpCurrency(tester, service: liveCurrencyService(cache: cache));
      await tester.pumpWidget(const SizedBox.shrink());
      // second run: every provider fails
      await pumpCurrency(tester, service: offlineCurrencyService(cache: cache));
      expect(textOf(tester, 'status-label'), 'FOREX RATES (CACHED)');
      expect(textOf(tester, 'status-updated'), startsWith('• Updated Cached ('));
      expect(find.textContaining('your last saved rates', findRichText: true), findsOneWidget);
      expect(amountText(tester), '9,050.00');
    });
  });

  group('refresh', () {
    testWidgets('the button is disabled while updating and the label changes', (tester) async {
      var gate = Completer<void>();
      var calls = 0;
      final service = CurrencyService(
        getter: (url, aborted) async {
          calls++;
          await gate.future;
          return const RawResponse(503, '');
        },
        cache: MemoryRatesCache(),
        clock: () => currencyTestNow,
      );
      await pumpCurrency(tester, service: service);

      // the first load is still running
      expect(find.text('Updating...'), findsOneWidget);
      expect(calls, providers.length);
      expect(find.byKey(const ValueKey('rates-notice')), findsNothing); // not shown while loading
      expect(textOf(tester, 'status-label'), 'FOREX RATES (CACHED)'); // the initial "Loading..." state, as on the web
      expect(textOf(tester, 'status-updated'), '• Updated Loading...');
      await tester.tap(find.byKey(const ValueKey('refresh-rates')), warnIfMissed: false);
      await tester.pump();
      expect(calls, providers.length); // disabled: no second fetch

      gate.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Refresh Rates'), findsOneWidget);
      expect(find.byKey(const ValueKey('rates-notice')), findsOneWidget);

      // tapping again fetches again
      gate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('refresh-rates')));
      await tester.pump();
      expect(find.text('Updating...'), findsOneWidget);
      expect(calls, providers.length * 2);
      gate.complete();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Refresh Rates'), findsOneWidget);
    });
  });
}
