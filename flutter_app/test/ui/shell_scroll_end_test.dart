import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens/finance_tabs_test.dart' show pumpFinanceTab;

/// Regression: on Loan / EMI the amortization table is built in a LayoutBuilder, which has no intrinsic height. The shell
/// used to size the page from intrinsic heights, so once the schedule was opened the page stopped scrolling short of the
/// table and the last rows stayed under the bottom bar.
void main() {
  testWidgets('the opened amortization schedule can be scrolled fully into view', (tester) async {
    await pumpFinanceTab(tester, 'Loan / EMI', size: const Size(400, 3600));
    // A phone-height window, then the Loan tab again (a layout change remounts the screen on its first tab).
    tester.view.physicalSize = const Size(400, 800);
    await tester.pump(const Duration(milliseconds: 1500));
    final tab = find.text('Loan / EMI');
    if (tab.evaluate().isNotEmpty) {
      await tester.ensureVisible(tab);
      await tester.tap(tab, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('Loan Amount (Principal)'), findsOneWidget, reason: 'Loan / EMI tab open');

    final scrollable = find.descendant(of: find.byType(CustomScrollView).first, matching: find.byType(Scrollable)).first;
    await tester.ensureVisible(find.byKey(const ValueKey('loan-schedule-toggle')));
    await tester.drag(scrollable, const Offset(0, -250)); // lift it clear of the bottom bar
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('loan-schedule-toggle')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Year'), findsOneWidget, reason: 'schedule opened');
    await tester.drag(scrollable, const Offset(0, -8000));
    await tester.pump(const Duration(milliseconds: 600));

    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, position.maxScrollExtent, reason: 'scrolled to the end');
    // the last year's row ends above the bottom bar (the bar is the lowest ~100 px of the 800 px window)
    final rows = find.textContaining('Yr ');
    expect(rows, findsWidgets);
    expect(tester.getBottomLeft(rows.last).dy, lessThan(800 - 70), reason: 'the last row is above the bottom bar');
  });
}
