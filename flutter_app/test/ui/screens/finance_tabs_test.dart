import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/js_locale.dart';
import 'package:omnicalc/main.dart';
import 'package:omnicalc/services/feedback_service.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:omnicalc/state/navigation_state.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/ui/screens/finance_widgets.dart';
import 'package:omnicalc/ui/screens/swp_screen.dart';
import 'package:omnicalc/ui/shell/app_shell.dart';
import 'package:provider/provider.dart';

import '../../support/fake_currency.dart';

/// Opens the Finance screen, switches to [tabLabel] (the tab strip needs a wide window to show every tab), then goes
/// to a tall phone-sized window so the whole page is laid out.
Future<SilentFeedbackService> pumpFinanceTab(
  WidgetTester tester,
  String tabLabel, {
  Size size = const Size(400, 3600),
}) async {
  tester.view.physicalSize = const Size(1300, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final feedback = SilentFeedbackService();
  await tester.pumpWidget(OmniCalcApp(
    settings: SettingsStore.memory(const AppSettings(), true),
    history: HistoryStore.memory(),
    systemColorsSource: const FakeSystemColorsSource(null),
    feedback: feedback,
    currencyService: offlineCurrencyService(),
  ));
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  Provider.of<NavigationState>(tester.element(find.byType(AppShell)), listen: false).setMode(CalculatorMode.finance);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.tap(find.text(tabLabel));
  await tester.pump(const Duration(milliseconds: 600));
  tester.view.physicalSize = size;
  await tester.pump(const Duration(milliseconds: 600));
  feedback.log.clear();
  return feedback;
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String fieldText(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

Future<void> typeInto(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump(const Duration(milliseconds: 600));
}

bool isChecked(WidgetTester tester, String key) => tester
    .widget<FinanceCheckbox>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(FinanceCheckbox)))
    .checked;

/// Width share of a ratio bar segment, after its 500 ms transition.
double barShare(WidgetTester tester, String key, List<String> all) {
  var total = 0.0;
  for (final k in all) {
    total += tester.getSize(find.byKey(ValueKey(k))).width;
  }
  return tester.getSize(find.byKey(ValueKey(key))).width / total;
}

void main() {
  group('en-IN number formatting (checked against Number#toLocaleString in Node)', () {
    test('rounded money', () {
      expect(formatMoney(0), '0');
      expect(formatMoney(5), '5');
      expect(formatMoney(999), '999');
      expect(formatMoney(1000), '1,000');
      expect(formatMoney(12345), '12,345');
      expect(formatMoney(123456), '1,23,456');
      expect(formatMoney(1234567), '12,34,567');
      expect(formatMoney(12345678), '1,23,45,678');
      expect(formatMoney(123456789), '12,34,56,789');
      expect(formatMoney(1e9), '1,00,00,00,000');
      expect(formatMoney(2500000), '25,00,000');
      expect(formatMoney(-12345), '-12,345');
      expect(formatMoney(0.5), '1'); // Math.round: halves go up
      expect(formatMoney(0.4), '0');
      expect(formatMoney(-0.4), '-0'); // Math.round gives -0 and Intl prints its sign
    });

    test('toLocaleString("en-IN") with its default 0 to 3 fraction digits', () {
      expect(jsToLocaleStringEnIN(1234.5678), '1,234.568');
      expect(jsToLocaleStringEnIN(1234567.891), '12,34,567.891');
      expect(jsToLocaleStringEnIN(5), '5');
      expect(jsToLocaleStringEnIN(0), '0');
      expect(jsToLocaleStringEnIN(-1234567.5), '-12,34,567.5');
      expect(jsToLocaleStringEnIN(100000), '1,00,000');
      expect(jsToLocaleStringEnIN(double.nan), 'NaN');
      expect(jsToLocaleStringEnIN(double.infinity), '∞');
    });

    test('number parsing helpers', () {
      expect(parseFloatOr0(''), 0);
      expect(parseFloatOr0('12.5'), 12.5);
      expect(parseFloatOr0('abc'), 0);
      expect(jsParseInt('2.7'), 2);
      expect(jsParseInt('  -3x'), -3);
      expect(jsParseInt('abc').isNaN, isTrue);
      expect(jsParseInt('').isNaN, isTrue);
    });

    test('percentage helpers', () {
      expect(clampPct(-3), 0);
      expect(clampPct(104), 100);
      expect(clampPct(56), 56);
      expect(orElse(0, 7), 7);
      expect(orElse(double.nan, 7), 7);
      expect(orElse(3, 7), 3);
    });
  });

  group('SWP text rules', () {
    test('depletion text', () {
      expect(swpDepletionText(null), isNull);
      expect(swpDepletionText(1), startsWith('Your corpus runs out after about 0 mo.'));
      expect(swpDepletionText(6), startsWith('Your corpus runs out after about 5 mo.'));
      expect(swpDepletionText(13), startsWith('Your corpus runs out after about 1 yr.'));
      expect(swpDepletionText(14), startsWith('Your corpus runs out after about 1 yr 1 mo.'));
      expect(swpDepletionText(25), startsWith('Your corpus runs out after about 2 yr.'));
      expect(swpDepletionText(6), endsWith('Lower the withdrawal or raise the return rate to last longer.'));
    });

    test('withdrawal share of the corpus per year', () {
      expect(swpWithdrawalPctPerYear(1000000, 8000), '9.6');
      expect(swpWithdrawalPctPerYear(0, 8000), isNull);
      expect(swpWithdrawalPctPerYear(1000000, -1), isNull);
      expect(swpWithdrawalPctPerYear(3, 1), '400.0');
    });
  });

  testWidgets('all five tabs are real screens, and none of them plays a sound', (tester) async {
    final fb = await pumpFinanceTab(tester, 'Loan / EMI', size: const Size(1300, 2400));
    expect(find.byKey(const ValueKey('loan-principal-input')), findsOneWidget);
    fb.log.clear();
    final tabs = {
      'SIP & Compound': 'compound-sip-input',
      'SWP': 'swp-corpus-input',
      'Tip & Bill': 'tip-bill-input',
      'ROI & CAGR': 'roi-initial-input',
      'Loan / EMI': 'loan-principal-input',
    };
    for (final e in tabs.entries) {
      await tester.tap(find.text(e.key));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(ValueKey(e.value)), findsOneWidget, reason: e.key);
    }
    // the tab strip's toggle click is the only sound: the calculators themselves are silent
    expect(fb.log.where((l) => l.startsWith('click:') && l != 'click:toggle'), isEmpty);
  });

  group('number fields follow the web inputs', () {
    testWidgets('clearing reads 0, a lone minus reads 0, a trailing point and an exponent stay as typed', (tester) async {
      final fb = await pumpFinanceTab(tester, 'Loan / EMI');
      await typeInto(tester, 'loan-rate-input', '');
      expect(fieldText(tester, 'loan-rate-input'), '0');
      expect(textOf(tester, 'loan-rate-badge'), '0% p.a.');
      await typeInto(tester, 'loan-rate-input', '-');
      expect(fieldText(tester, 'loan-rate-input'), '0');
      await typeInto(tester, 'loan-rate-input', '5.');
      expect(fieldText(tester, 'loan-rate-input'), '5.');
      expect(textOf(tester, 'loan-rate-badge'), '5% p.a.');
      await typeInto(tester, 'loan-rate-input', '1e1');
      expect(fieldText(tester, 'loan-rate-input'), '1e1');
      expect(textOf(tester, 'loan-rate-badge'), '10% p.a.');
      expect(fb.log, isEmpty);
    });

    testWidgets('a preset rewrites the text of its field', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      await typeInto(tester, 'loan-rate-input', '7.25');
      expect(textOf(tester, 'loan-rate-badge'), '7.25% p.a.');
      await tapKey(tester, 'loan-rate-preset-12');
      expect(fieldText(tester, 'loan-rate-input'), '12');
      expect(textOf(tester, 'loan-rate-badge'), '12% p.a.');
    });

    testWidgets('a minimum is applied to the text too (tenure of at least 1 year)', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      await typeInto(tester, 'loan-years-input', '0');
      expect(fieldText(tester, 'loan-years-input'), '1');
      expect(textOf(tester, 'loan-years-badge'), '1 Years (12 Months)');
    });
  });

  group('Loan / EMI', () {
    testWidgets('first render matches the TypeScript engine (25 L, 8.5%, 15 years)', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      expect(textOf(tester, 'loan-emi'), '24,618');
      expect(textOf(tester, 'loan-total-interest'), '₹19,31,328');
      expect(textOf(tester, 'loan-total-outflow'), '₹44,31,328');
      expect(textOf(tester, 'loan-pct-principal'), '56%');
      expect(textOf(tester, 'loan-pct-interest'), '44%');
      expect(find.byKey(const ValueKey('loan-pct-taxes')), findsNothing);
      expect(find.byKey(const ValueKey('loan-bar-taxes')), findsNothing);
      expect(textOf(tester, 'loan-principal-helper'), '₹25,00,000');
      expect(textOf(tester, 'loan-rate-badge'), '8.5% p.a.');
      expect(textOf(tester, 'loan-years-badge'), '15 Years (180 Months)');
      expect(fieldText(tester, 'loan-principal-input'), '2500000');
      expect(find.text('MONTHLY EMI (REPAYMENT)'), findsOneWidget);
      expect(find.text('/ month'), findsOneWidget);
      expect(find.text('Annual Amortization Schedule (15 Years)'), findsOneWidget);
      expect(barShare(tester, 'loan-bar-principal', ['loan-bar-principal', 'loan-bar-interest']), closeTo(0.56, 0.002));
    });

    testWidgets('presets: 10 L at 12% for 5 years', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      await tapKey(tester, 'loan-principal-preset-1000000');
      await tapKey(tester, 'loan-rate-preset-12');
      await tapKey(tester, 'loan-years-preset-5');
      expect(textOf(tester, 'loan-emi'), '22,244');
      expect(textOf(tester, 'loan-total-interest'), '₹3,34,667');
      expect(textOf(tester, 'loan-total-outflow'), '₹13,34,667');
      expect(textOf(tester, 'loan-principal-helper'), '₹10,00,000');
      expect(find.text('Annual Amortization Schedule (5 Years)'), findsOneWidget);
    });

    testWidgets('typing a principal, and clearing it drops the helper line', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      await typeInto(tester, 'loan-principal-input', '1000000');
      expect(textOf(tester, 'loan-principal-helper'), '₹10,00,000');
      await typeInto(tester, 'loan-principal-input', '');
      expect(find.byKey(const ValueKey('loan-principal-helper')), findsNothing);
      expect(textOf(tester, 'loan-emi'), '0');
    });

    testWidgets('taxes and fees: GST on interest, then the processing fee', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      expect(find.byKey(const ValueKey('loan-gst-check')), findsNothing);
      await tapKey(tester, 'loan-taxes-toggle');
      expect(find.byKey(const ValueKey('loan-gst-check')), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      expect(isChecked(tester, 'loan-gst-check'), isFalse);

      await tapKey(tester, 'loan-gst-check');
      expect(isChecked(tester, 'loan-gst-check'), isTrue);
      expect(find.text('Active'), findsOneWidget);
      expect(textOf(tester, 'loan-gst-amount'), '+₹3,47,639');
      expect(textOf(tester, 'loan-effective-emi'), 'Effective with GST: ₹26,550/mo');

      await tapKey(tester, 'loan-fee-check');
      expect(textOf(tester, 'loan-fee-amount'), '₹29,500 (incl. 18% GST)');
      expect(textOf(tester, 'loan-net-disbursed'), '₹24,70,500');
      expect(textOf(tester, 'loan-total-outflow'), '₹48,08,467');
      expect(textOf(tester, 'loan-pct-principal'), '52%');
      expect(textOf(tester, 'loan-pct-interest'), '40%');
      expect(textOf(tester, 'loan-pct-taxes'), '8%');
      const all = ['loan-bar-principal', 'loan-bar-interest', 'loan-bar-taxes'];
      expect(barShare(tester, 'loan-bar-principal', all), closeTo(0.52, 0.002));
      expect(barShare(tester, 'loan-bar-interest', all), closeTo(0.40, 0.002));
      expect(barShare(tester, 'loan-bar-taxes', all), closeTo(0.08, 0.002));

      // closing the section keeps the choices (and the "Active" pill)
      await tapKey(tester, 'loan-taxes-toggle');
      expect(find.byKey(const ValueKey('loan-gst-check')), findsNothing);
      expect(find.text('Active'), findsOneWidget);
      expect(textOf(tester, 'loan-effective-emi'), 'Effective with GST: ₹26,550/mo');
    });

    testWidgets('the schedule opens and lists every year', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      expect(find.text('Yr 1'), findsNothing);
      await tapKey(tester, 'loan-schedule-toggle');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Yr 1'), findsOneWidget);
      expect(find.text('₹86,230'), findsOneWidget);
      expect(find.text('₹2,09,192'), findsOneWidget);
      expect(find.text('₹24,13,770'), findsOneWidget);
      expect(find.text('Yr 15'), findsOneWidget);
      expect(find.text('₹2,82,258'), findsOneWidget);
      expect(find.text('₹13,164'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);
      await tapKey(tester, 'loan-schedule-toggle');
      expect(find.text('Yr 1'), findsNothing);
    });

    testWidgets('one column on a phone, two columns from 768 px', (tester) async {
      await pumpFinanceTab(tester, 'Loan / EMI');
      final input = tester.getRect(find.byKey(const ValueKey('loan-principal-input')));
      final emi = tester.getRect(find.byKey(const ValueKey('loan-emi')));
      expect(emi.top, greaterThan(input.top + 300));
      tester.view.physicalSize = const Size(1000, 3600);
      await tester.pump(const Duration(milliseconds: 600));
      final input2 = tester.getRect(find.byKey(const ValueKey('loan-principal-input')));
      final emi2 = tester.getRect(find.byKey(const ValueKey('loan-emi')));
      expect(emi2.left, greaterThan(input2.right));
      expect((emi2.top - input2.top).abs(), lessThan(150));
    });
  });

  group('SIP & Compound', () {
    testWidgets('first render matches the TypeScript engine (5,000 a month, 50,000 lump sum, 12%, 10 years, +10%)', (tester) async {
      await pumpFinanceTab(tester, 'SIP & Compound');
      expect(find.text('TOTAL EXPECTED WEALTH AFTER 10 YEARS'), findsOneWidget);
      expect(textOf(tester, 'compound-end-balance'), '18,52,182');
      expect(textOf(tester, 'compound-total-invested'), '₹10,06,245');
      expect(textOf(tester, 'compound-total-gain'), '+₹8,45,937');
      expect(textOf(tester, 'compound-pct-invested'), '54%');
      expect(textOf(tester, 'compound-pct-gains'), '46%');
      expect(textOf(tester, 'compound-sip-helper'), '₹5,000 / month');
      expect(textOf(tester, 'compound-initial-helper'), 'Starting corpus: ₹50,000');
      expect(textOf(tester, 'compound-rate-badge'), '12% p.a.');
      expect(textOf(tester, 'compound-years-badge'), '10 Years (120 Installments)');
      expect(textOf(tester, 'compound-stepup-badge'), '+10% every year');
      expect(barShare(tester, 'compound-bar-invested', ['compound-bar-invested', 'compound-bar-gains']), closeTo(0.54, 0.002));
      for (final label in ['₹2,000', '₹5,000', '₹10,000', '₹25,000', '8% Debt', '10% Balanced', '12% Equity', '15% Aggressive', 'No Step-Up', '+15% / yr']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('no step-up: the badge reads Flat SIP and the corpus matches the engine', (tester) async {
      await pumpFinanceTab(tester, 'SIP & Compound');
      await tapKey(tester, 'compound-stepup-preset-0');
      expect(textOf(tester, 'compound-stepup-badge'), 'Flat SIP');
      expect(textOf(tester, 'compound-end-balance'), '13,26,715');
      expect(textOf(tester, 'compound-total-invested'), '₹6,50,000');
      expect(textOf(tester, 'compound-total-gain'), '+₹6,76,715');
      await typeInto(tester, 'compound-stepup-input', '');
      expect(fieldText(tester, 'compound-stepup-input'), '0');
      expect(textOf(tester, 'compound-stepup-badge'), 'Flat SIP');
    });

    testWidgets('the wealth progression table', (tester) async {
      await pumpFinanceTab(tester, 'SIP & Compound');
      expect(find.text('Yr 0'), findsNothing);
      await tapKey(tester, 'compound-timeline-toggle');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Yr 0'), findsOneWidget);
      expect(find.text('-'), findsOneWidget); // the monthly SIP of year 0
      expect(find.text('Yr 1'), findsOneWidget);
      expect(find.text('₹5,000/m'), findsOneWidget); // year 1; year 2 steps up to 5,500
      expect(find.text('₹1,10,000'), findsOneWidget);
      expect(find.text('+₹10,388'), findsOneWidget);
      expect(find.text('₹1,20,388'), findsOneWidget);
      expect(find.text('Yr 10'), findsOneWidget);
      expect(find.text('₹11,790/m'), findsOneWidget);
    });

    testWidgets('years of at least 1', (tester) async {
      await pumpFinanceTab(tester, 'SIP & Compound');
      await typeInto(tester, 'compound-years-input', '0');
      expect(fieldText(tester, 'compound-years-input'), '1');
      expect(textOf(tester, 'compound-years-badge'), '1 Years (12 Installments)');
      expect(find.text('TOTAL EXPECTED WEALTH AFTER 1 YEARS'), findsOneWidget);
    });
  });

  group('SWP', () {
    testWidgets('first render matches the TypeScript engine (10 L, 8,000 a month, 8%, 10 years)', (tester) async {
      await pumpFinanceTab(tester, 'SWP');
      expect(find.text('FINAL VALUE AFTER 10 YEARS'), findsOneWidget);
      expect(textOf(tester, 'swp-final-balance'), '7,46,315');
      expect(textOf(tester, 'swp-total-withdrawn'), '₹9,60,000');
      expect(textOf(tester, 'swp-total-returns'), '+₹7,06,315');
      expect(textOf(tester, 'swp-pct-withdrawn'), '56%');
      expect(textOf(tester, 'swp-pct-remaining'), '44%');
      expect(textOf(tester, 'swp-withdrawal-pct'), '9.6%');
      expect(find.text('of corpus per year'), findsOneWidget);
      expect(textOf(tester, 'swp-corpus-helper'), '₹10,00,000');
      expect(find.byKey(const ValueKey('swp-depletion-warning')), findsNothing);
      expect(find.text('Annual step-up to counteract inflation'), findsOneWidget);
    });

    testWidgets('a corpus that runs out shows the amber warning', (tester) async {
      await pumpFinanceTab(tester, 'SWP');
      await typeInto(tester, 'swp-corpus-input', '100000');
      await typeInto(tester, 'swp-withdrawal-input', '20000');
      expect(find.byKey(const ValueKey('swp-depletion-warning')), findsOneWidget);
      expect(
        textOf(tester, 'swp-depletion-text'),
        'Your corpus runs out after about 5 mo. Lower the withdrawal or raise the return rate to last longer.',
      );
      expect(textOf(tester, 'swp-final-balance'), '0');
      expect(textOf(tester, 'swp-total-withdrawn'), '₹1,01,360');
      expect(textOf(tester, 'swp-total-returns'), '+₹1,360');
      expect(textOf(tester, 'swp-withdrawal-pct'), '240.0%');
    });

    testWidgets('yearly increase in the withdrawal', (tester) async {
      await pumpFinanceTab(tester, 'SWP');
      await typeInto(tester, 'swp-stepup-input', '10');
      expect(textOf(tester, 'swp-final-balance'), '13,306');
      expect(textOf(tester, 'swp-total-withdrawn'), '₹15,29,993');
      expect(textOf(tester, 'swp-total-returns'), '+₹5,43,299');
    });

    testWidgets('the withdrawal timeline', (tester) async {
      await pumpFinanceTab(tester, 'SWP');
      await tapKey(tester, 'swp-timeline-toggle');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Yr 1'), findsOneWidget);
      expect(find.text('₹96,000'), findsOneWidget);
      expect(find.text('+78,736'), findsOneWidget); // no rupee sign on the returns column
      expect(find.text('₹9,82,736'), findsOneWidget);
      expect(find.text('Yr 10'), findsOneWidget);
    });
  });

  group('Tip & Bill', () {
    testWidgets('first render matches the TypeScript engine (2,400, 10%, 4 people)', (tester) async {
      await pumpFinanceTab(tester, 'Tip & Bill');
      expect(find.text('PER PERSON SHARE'), findsOneWidget);
      expect(textOf(tester, 'tip-per-person'), '660');
      expect(find.text('/ each'), findsOneWidget);
      expect(textOf(tester, 'tip-bill-total'), '₹2,640');
      expect(textOf(tester, 'tip-tip-total'), '+₹240');
      expect(textOf(tester, 'tip-base-per-person'), 'Base per person: ₹600');
      expect(textOf(tester, 'tip-tip-per-person'), 'Tip per person: ₹60');
      expect(textOf(tester, 'tip-pct-base'), '91%');
      expect(textOf(tester, 'tip-pct-tip'), '9%');
      expect(textOf(tester, 'tip-percent-badge'), '10%');
      expect(textOf(tester, 'tip-people-badge'), '4 People');
      expect(isChecked(tester, 'tip-roundup-check'), isFalse);
      for (final label in ['5%', '12%', '15%', '18%', '20%', '1 Person', '2 Ppl', '8 Ppl']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('18% tip split three ways', (tester) async {
      await pumpFinanceTab(tester, 'Tip & Bill');
      await tapKey(tester, 'tip-percent-preset-18');
      await tapKey(tester, 'tip-people-preset-3');
      expect(textOf(tester, 'tip-per-person'), '944');
      expect(textOf(tester, 'tip-bill-total'), '₹2,832');
      expect(textOf(tester, 'tip-tip-total'), '+₹432');
      expect(textOf(tester, 'tip-people-badge'), '3 People');
    });

    testWidgets('one person, whole numbers only, and amounts that do not divide evenly', (tester) async {
      await pumpFinanceTab(tester, 'Tip & Bill');
      await tapKey(tester, 'tip-people-preset-1');
      expect(textOf(tester, 'tip-people-badge'), '1 Person');
      await typeInto(tester, 'tip-people-input', '2.7');
      expect(fieldText(tester, 'tip-people-input'), '2');
      expect(textOf(tester, 'tip-people-badge'), '2 People');
      expect(textOf(tester, 'tip-per-person'), '1,320');
      await typeInto(tester, 'tip-people-input', '');
      expect(fieldText(tester, 'tip-people-input'), '1');

      await typeInto(tester, 'tip-bill-input', '1000');
      await tapKey(tester, 'tip-people-preset-3');
      expect(textOf(tester, 'tip-per-person'), '367');
      expect(textOf(tester, 'tip-bill-total'), '₹1,100');
      expect(textOf(tester, 'tip-tip-total'), '+₹100');
      expect(textOf(tester, 'tip-base-per-person'), 'Base per person: ₹333');
      expect(textOf(tester, 'tip-tip-per-person'), 'Tip per person: ₹33');
    });

    testWidgets('the round-up box toggles', (tester) async {
      await pumpFinanceTab(tester, 'Tip & Bill');
      await tapKey(tester, 'tip-roundup-check');
      expect(isChecked(tester, 'tip-roundup-check'), isTrue);
      await tapKey(tester, 'tip-roundup-check');
      expect(isChecked(tester, 'tip-roundup-check'), isFalse);
    });
  });

  group('ROI & CAGR', () {
    testWidgets('first render matches the TypeScript engine (2 L to 5.5 L in 5 years)', (tester) async {
      await pumpFinanceTab(tester, 'ROI & CAGR');
      expect(find.text('ANNUALIZED COMPOUNDED GROWTH (CAGR)'), findsOneWidget);
      expect(textOf(tester, 'roi-cagr'), '22.42%');
      expect(find.text('per year'), findsOneWidget);
      expect(textOf(tester, 'roi-total-roi'), '+175.00%');
      expect(textOf(tester, 'roi-net-profit'), '+₹3,50,000');
      expect(textOf(tester, 'roi-pct-capital'), '36%');
      expect(textOf(tester, 'roi-pct-gain'), '64%');
      expect(textOf(tester, 'roi-initial-helper'), '₹2,00,000');
      expect(textOf(tester, 'roi-final-helper'), '₹5,50,000');
      expect(textOf(tester, 'roi-years-badge'), '5 Years');
      expect(barShare(tester, 'roi-bar-capital', ['roi-bar-capital', 'roi-bar-gain']), closeTo(0.36, 0.002));
    });

    testWidgets('a loss', (tester) async {
      await pumpFinanceTab(tester, 'ROI & CAGR');
      await typeInto(tester, 'roi-final-input', '150000');
      expect(textOf(tester, 'roi-cagr'), '-5.59%');
      expect(textOf(tester, 'roi-total-roi'), '-25.00%');
      expect(textOf(tester, 'roi-net-profit'), '₹-50,000'); // the sign sits inside the number, as on the web
      expect(textOf(tester, 'roi-pct-capital'), '100%');
      expect(textOf(tester, 'roi-pct-gain'), '0%');
    });

    testWidgets('ten years, and a holding period of at least 0.1', (tester) async {
      await pumpFinanceTab(tester, 'ROI & CAGR');
      await tapKey(tester, 'roi-years-preset-10');
      expect(textOf(tester, 'roi-cagr'), '10.65%');
      expect(textOf(tester, 'roi-years-badge'), '10 Years');
      await typeInto(tester, 'roi-years-input', '0.05');
      expect(fieldText(tester, 'roi-years-input'), '0.1');
      expect(textOf(tester, 'roi-years-badge'), '0.1 Years');
    });
  });
}
