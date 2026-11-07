import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/expr_doc.dart';
import 'package:omnicalc/editor/rich_expression_view.dart';
import 'package:omnicalc/editor/rich_layout.dart';
import 'package:omnicalc/ui/calculator/auto_fit_text.dart';

const Color black = Color(0xFF000000);

Widget host(Widget child, {double width = 300}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    );

void main() {
  group('plain text looks like the old AutoFitText', () {
    for (final text in ['0', '123', '7+3', '123456789×987654321+55555', 'sin(cos(tan(0.5))))×12345678']) {
      testWidgets('"$text"', (tester) async {
        await tester.pumpWidget(host(AutoFitText(text: text, max: 72, min: 26, color: black)));
        final old = tester.renderObject<RenderAutoFitText>(find.byType(AutoFitText));
        final oldSize = tester.getSize(find.byType(AutoFitText));
        final oldFont = old.fontSize;

        await tester.pumpWidget(host(RichExpressionView(doc: ExprDoc.plain(text), max: 72, min: 26, color: black)));
        final rich = tester.renderObject<RenderRichExpression>(find.byType(RichExpressionLeaf));
        final size = tester.getSize(find.byType(RichExpressionLeaf));
        expect(size.width, closeTo(oldSize.width, 1e-9));
        expect(size.height, closeTo(oldSize.height, 1e-9));
        expect(rich.fontSize, oldFont);
        expect(rich.text, text);
      });
    }
  });

  testWidgets('a superscript makes the line taller than the same text without one', (tester) async {
    await tester.pumpWidget(host(RichExpressionView(doc: ExprDoc.plain('x2'), max: 40, min: 20, color: black)));
    final plainHeight = tester.getSize(find.byType(RichExpressionLeaf)).height;
    await tester.pumpWidget(host(RichExpressionView(doc: ExprDoc.fromLinear('x^2'), max: 40, min: 20, color: black)));
    expect(tester.getSize(find.byType(RichExpressionLeaf)).height, greaterThan(plainHeight));
  });

  testWidgets('long text shrinks, a group counts in the width', (tester) async {
    await tester.pumpWidget(
      host(RichExpressionView(doc: ExprDoc.fromLinear('12345678^(12345)+98765432'), max: 72, min: 26, color: black)),
    );
    final rich = tester.renderObject<RenderRichExpression>(find.byType(RichExpressionLeaf));
    expect(rich.fontSize, lessThan(72));
    expect(rich.fontSize, greaterThanOrEqualTo(26));
  });

  testWidgets('fixed mode is as wide as the text', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RichExpressionView(doc: ExprDoc.plain('abc'), fit: false, max: 20, color: black),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RichExpressionLeaf)).width, closeTo(58.5, 1e-9)); // Ahem: 1 em per glyph, less the -0.025 em tracking of the display text
  });

  testWidgets('a tap reports the caret place', (tester) async {
    final hits = <CaretHit>[];
    await tester.pumpWidget(
      host(
        RichExpressionView(
          doc: ExprDoc.plain('abc'),
          fit: false,
          max: 20,
          color: black,
          onCaretHit: hits.add,
        ),
      ),
    );
    final box = tester.getRect(find.byType(RichExpressionLeaf));
    await tester.tapAt(Offset(box.left + 1, box.top + 10));
    expect(hits.single.offset, 0);
    expect(hits.single.path, isEmpty);
  });

  testWidgets('the caret blinks and the widget disposes cleanly', (tester) async {
    final doc = ExprDoc.fromLinear('x^');
    await tester.pumpWidget(
      host(RichExpressionView(doc: doc, max: 40, min: 20, color: black, showCaret: true)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); // dispose: the blink timer must be cancelled
  });

  testWidgets('screen readers get the spoken form', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(RichExpressionView(doc: ExprDoc.fromLinear('x^2'), max: 40, min: 20, color: black)),
    );
    expect(find.bySemanticsLabel('x squared'), findsOneWidget);
    handle.dispose();
  });
}
