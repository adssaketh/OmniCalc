import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/expr_doc.dart';
import 'package:omnicalc/editor/linear.dart';
import 'package:omnicalc/editor/nodes.dart';

// Phase 8a: the natural-display structures (Part 9, section 9.2) at the level of the document and the caret.

List<Node> chars(String s) => [for (final u in s.codeUnits) CharNode(String.fromCharCode(u))];

SlotNode slot(String s) => SlotNode(chars(s));

void main() {
  group('serialization (legacy engine dialect)', () {
    test('fraction', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('2')])]);
      expect(doc.linear, '((1)÷(2))');
    });

    test('the video expression (X²−6)/(X+3)', () {
      final doc = ExprDoc.fromNodes([
        FracNode([
          SlotNode([const CharNode('X'), SupNode(chars('2')), ...chars('−6')]),
          slot('X+3'),
        ]),
        ...chars('=10'),
      ]);
      expect(doc.linear, '((X^2−6)÷(X+3))=10');
    });

    test('mixed fraction', () {
      final doc = ExprDoc.fromNodes([MixedFracNode([slot('3'), slot('1'), slot('2')])]);
      expect(doc.linear, '((3)+((1)÷(2)))');
    });

    test('sqrt, root, abs, log with a base', () {
      expect(ExprDoc.fromNodes([SqrtNode([slot('2')])]).linear, 'sqrt(2)');
      expect(ExprDoc.fromNodes([RootNode([slot('3'), slot('8')])]).linear, 'root(3,8)');
      expect(ExprDoc.fromNodes([AbsNode([slot('x−1')])]).linear, 'abs(x−1)');
      expect(ExprDoc.fromNodes([LogBaseNode([slot('2'), slot('8')])]).linear, 'logb(2,8)');
    });

    test('a structure next to something it multiplies gets an explicit ×', () {
      expect(ExprDoc.fromNodes([...chars('2'), SqrtNode([slot('3')])]).linear, '2×sqrt(3)');
      expect(ExprDoc.fromNodes([SqrtNode([slot('3')]), ...chars('2')]).linear, 'sqrt(3)×2');
      expect(ExprDoc.fromNodes([SqrtNode([slot('2')]), SqrtNode([slot('3')])]).linear, 'sqrt(2)×sqrt(3)');
      // an operator needs none
      expect(ExprDoc.fromNodes([...chars('2+'), SqrtNode([slot('3')])]).linear, '2+sqrt(3)');
    });

    test('a parenthesis left open inside a slot is closed so it cannot swallow what follows', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('(1+2'), slot('3')]), ...chars('+4')]);
      expect(doc.linear, '(((1+2))÷(3))+4');
    });

    test('a structure inside a superscript is parenthesised', () {
      final doc = ExprDoc.fromNodes([...chars('2'), SupNode([FracNode([slot('1'), slot('2')])])]);
      expect(doc.linear, '2^((1)÷(2))', reason: 'the fraction text is already one parenthesised unit');
    });

    test('an empty slot is empty text (the controller blocks the calculation before it gets this far)', () {
      expect(ExprDoc.fromNodes([FracNode()]).linear, '(()÷())');
    });

    test('text without structures serializes exactly as before', () {
      for (final s in ['2+3', 'sin(30)', '2^3+x', 'log2(8)', '5!', '10%']) {
        expect(serializeNodes(parseLinear(s).nodes), s);
      }
    });
  });

  group('JSON', () {
    test('every structure round-trips', () {
      final nodes = <Node>[
        FracNode([slot('1'), SlotNode([const CharNode('x'), SupNode(chars('2'))])]),
        MixedFracNode([slot('1'), slot('2'), slot('3')]),
        SqrtNode([slot('2')]),
        RootNode([slot('3'), slot('8')]),
        AbsNode([slot('x')]),
        LogBaseNode([slot('2'), SlotNode([FracNode([slot('1'), slot('2')])])]),
      ];
      final doc = ExprDoc.fromNodes(nodes);
      final back = ExprDoc.fromJson(doc.toJson());
      expect(back, isNotNull);
      expect(back!.root, nodes);
      expect(back.linear, doc.linear);
    });

    test('a structure with the wrong number of slots is not a tree this editor wrote', () {
      expect(ExprDoc.fromJson([{'frac': [['1']]}]), isNull);
      expect(ExprDoc.fromJson([{'sqrt': 'x'}]), isNull);
      expect(ExprDoc.fromJson([{'nope': [[]]}]), isNull);
    });

    test('trees from before 8a (only sup / sub) still load', () {
      final doc = ExprDoc.fromJson([
        '2',
        {'sup': ['3']},
        '+x',
        {'sub': ['1']},
      ]);
      expect(doc, isNotNull);
      expect(doc!.linear, '2^3+x_1');
    });
  });

  group('inserting and the caret', () {
    test('a new fraction puts the caret in the numerator', () {
      final doc = ExprDoc.fromNodes(const []);
      expect(doc.insertStruct(FracNode()), isTrue);
      expect(doc.path, [0, 0]);
      expect(doc.offset, 0);
      expect(doc.inSlot, isTrue);
      expect(doc.structDepth, 1);
      expect(doc.scriptDepth, 0);
    });

    test('the caret never stands between the slots of a structure', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('2')])]);
      expect(doc.setCaret(const [0], 0), isFalse);
      expect(doc.setCaret(const [0], 1), isFalse);
      expect(doc.setCaret(const [0, 1], 1), isTrue);
      expect(doc.path, [0, 1]);
      expect(doc.setCaret(const [0, 2], 0), isFalse, reason: 'there is no third slot');
    });

    test('→ at the end of the numerator goes to the denominator, at the end of the denominator it leaves', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('2')]), ...chars('+3')]);
      doc.setCaret(const [0, 0], 1);
      expect(doc.moveRight(), isTrue);
      expect(doc.path, [0, 1]);
      expect(doc.offset, 0);
      doc.moveRight(); // over the 2
      expect(doc.offset, 1);
      expect(doc.moveRight(), isTrue); // out of the fraction
      expect(doc.path, isEmpty);
      expect(doc.offset, 1);
    });

    test('← mirrors it: into the end of the denominator, back to the numerator, out in front of the fraction', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('23')])]);
      doc.setCaret(const [], 1);
      expect(doc.moveLeft(), isTrue);
      expect(doc.path, [0, 1]);
      expect(doc.offset, 2);
      doc.setCaret(const [0, 1], 0);
      expect(doc.moveLeft(), isTrue);
      expect(doc.path, [0, 0]);
      expect(doc.offset, 1);
      doc.setCaret(const [0, 0], 0);
      expect(doc.moveLeft(), isTrue);
      expect(doc.path, isEmpty);
      expect(doc.offset, 0);
    });

    test('→ steps into a fraction in front of the caret, at its numerator', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('2')])]);
      doc.setCaret(const [], 0);
      expect(doc.moveRight(), isTrue);
      expect(doc.path, [0, 0]);
      expect(doc.offset, 0);
    });

    test('exit leaves the whole structure from any slot and lands after it', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('2')]), ...chars('+3')]);
      doc.setCaret(const [0, 0], 0);
      expect(doc.exitGroup(), isTrue);
      expect(doc.path, isEmpty);
      expect(doc.offset, 1);
    });

    test('exit from a superscript inside a numerator only leaves the superscript', () {
      final doc = ExprDoc.fromNodes([
        FracNode([SlotNode([const CharNode('X'), SupNode(chars('2'))]), slot('1')]),
      ]);
      doc.setCaret(const [0, 0, 1], 1);
      expect(doc.exitGroup(), isTrue);
      expect(doc.path, [0, 0]);
      expect(doc.offset, 2);
    });

    test('▼ goes numerator → denominator, ▲ back; from inside a superscript it goes to the start of the denominator', () {
      final doc = ExprDoc.fromNodes([
        FracNode([SlotNode([const CharNode('X'), SupNode(chars('2'))]), slot('ab')]),
      ]);
      doc.setCaret(const [0, 0], 1);
      expect(doc.moveDown(), isTrue);
      expect(doc.path, [0, 1]);
      expect(doc.offset, 1, reason: 'same offset, as far as the denominator reaches');
      expect(doc.moveUp(), isTrue);
      expect(doc.path, [0, 0]);
      doc.setCaret(const [0, 0, 1], 1);
      expect(doc.moveDown(), isTrue);
      expect(doc.path, [0, 1]);
      expect(doc.offset, 0);
    });

    test('▲ / ▼ do nothing where there is no fraction to go through', () {
      final doc = ExprDoc.fromNodes([...chars('12'), SqrtNode([slot('3')])]);
      expect(doc.moveDown(), isFalse);
      expect(doc.moveUp(), isFalse);
      doc.setCaret(const [2, 0], 1);
      expect(doc.moveDown(), isFalse);
    });

    test('mixed fraction: ▼ from the numerator, never from the whole part', () {
      final doc = ExprDoc.fromNodes([MixedFracNode([slot('3'), slot('1'), slot('2')])]);
      doc.setCaret(const [0, 0], 1);
      expect(doc.moveDown(), isFalse);
      doc.setCaret(const [0, 1], 1);
      expect(doc.moveDown(), isTrue);
      expect(doc.path, [0, 2]);
      expect(doc.moveUp(), isTrue);
      expect(doc.path, [0, 1]);
    });

    test('structures nest up to kMaxStructDepth levels and then refuse', () {
      final doc = ExprDoc.fromNodes(const []);
      for (var i = 0; i < kMaxStructDepth; i++) {
        expect(doc.insertStruct(FracNode()), isTrue, reason: 'level ${i + 1}');
      }
      expect(doc.structDepth, kMaxStructDepth);
      expect(doc.insertStruct(FracNode()), isFalse);
      expect(doc.insertStruct(SqrtNode()), isFalse);
    });

    test('the superscript limit counts only superscripts and subscripts', () {
      final doc = ExprDoc.fromNodes(const []);
      doc.insertStruct(FracNode());
      expect(doc.insertGroup(sup: true), isTrue);
      expect(doc.insertGroup(sup: true), isTrue);
      expect(doc.insertGroup(sup: true), isTrue);
      expect(doc.scriptDepth, 3);
      expect(doc.insertGroup(sup: true), isFalse);
    });
  });

  group('Backspace', () {
    test('after an empty fraction removes it', () {
      final doc = ExprDoc.fromNodes([...chars('2'), FracNode()]);
      doc.setCaret(const [], 2);
      doc.backspace(const []);
      expect(doc.root, chars('2'));
      expect(doc.offset, 1);
    });

    test('after a fraction with content steps into its last slot first', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('2')])]);
      doc.setCaret(const [], 1);
      doc.backspace(const []);
      expect(doc.path, [0, 1]);
      expect(doc.offset, 1);
      doc.backspace(const []);
      expect((doc.root.single as FracNode).slots[1].children, isEmpty);
    });

    test('at the start of the denominator goes to the end of the numerator without deleting', () {
      final doc = ExprDoc.fromNodes([FracNode([slot('1'), slot('2')])]);
      doc.setCaret(const [0, 1], 0);
      doc.backspace(const []);
      expect(doc.path, [0, 0]);
      expect(doc.offset, 1);
      expect((doc.root.single as FracNode).slots.map((s) => s.children.length), [1, 1]);
    });

    test('at the start of the numerator removes an all-empty fraction, or steps out of one that has content', () {
      final empty = ExprDoc.fromNodes([...chars('7'), FracNode()]);
      empty.setCaret(const [1, 0], 0);
      empty.backspace(const []);
      expect(empty.root, chars('7'));
      expect(empty.path, isEmpty);
      expect(empty.offset, 1);

      final filled = ExprDoc.fromNodes([...chars('7'), FracNode([SlotNode(), slot('2')])]);
      filled.setCaret(const [1, 0], 0);
      filled.backspace(const []);
      expect(filled.root.length, 2, reason: 'the fraction stays');
      expect(filled.path, isEmpty);
      expect(filled.offset, 1);
    });

    test('typing then Backspacing a whole video expression leaves nothing behind', () {
      final doc = ExprDoc.fromNodes(const []);
      doc.insertStruct(FracNode());
      doc.insertChars('X');
      doc.moveDown();
      doc.insertChars('1');
      for (var i = 0; i < 8; i++) {
        doc.backspace(const []);
      }
      expect(doc.root, isEmpty);
    });
  });

  group('placeholders', () {
    test('the first empty slot in reading order', () {
      expect(ExprDoc.fromNodes([FracNode()]).firstPlaceholderPath, [0, 0]);
      expect(ExprDoc.fromNodes([FracNode([slot('1'), SlotNode()])]).firstPlaceholderPath, [0, 1]);
      expect(ExprDoc.fromNodes([...chars('2+'), SqrtNode([SlotNode([FracNode([slot('1'), SlotNode()])])])])
          .firstPlaceholderPath, [2, 0, 0, 1]);
      expect(ExprDoc.fromNodes([FracNode([slot('1'), slot('2')])]).firstPlaceholderPath, isNull);
      expect(ExprDoc.fromNodes(chars('2+3')).firstPlaceholderPath, isNull);
    });

    test('an empty superscript is not a placeholder (legacy behaviour is kept)', () {
      expect(ExprDoc.fromNodes([...chars('2'), SupNode()]).firstPlaceholderPath, isNull);
    });
  });

  group('INS: the value to the right becomes the argument', () {
    test('1 + 7/6 with INS then √ gives 1 + √(7/6)', () {
      final doc = ExprDoc.fromNodes([...chars('1+'), FracNode([slot('7'), slot('6')])]);
      doc.setCaret(const [], 2);
      expect(doc.insertStructWrapping(SqrtNode(), argSlot: 0), isTrue);
      expect(doc.root.length, 3);
      final sqrt = doc.root[2] as SqrtNode;
      expect(sqrt.slots.single.children.single, isA<FracNode>());
      expect(doc.linear, '1+sqrt(((7)÷(6)))');
      expect(doc.path, [2, 0], reason: 'the caret is at the end of what was wrapped');
      expect(doc.offset, 1);
    });

    test('the argument stops at the first open parenthesis', () {
      final doc = ExprDoc.fromNodes(chars('12+3(4+5)'));
      doc.setCaret(const [], 0);
      expect(doc.wrapEnd, 4, reason: '12+3 stops in front of the (');
    });

    test('the argument stops at the first function', () {
      final doc = ExprDoc.fromNodes(chars('2×3sin(30)'));
      doc.setCaret(const [], 0);
      expect(doc.wrapEnd, 3, reason: '2×3 stops in front of sin(');
      doc.setCaret(const [], 3);
      expect(doc.wrapEnd, 3, reason: 'nothing to take when a function starts right there');
    });

    test('a plain variable letter is not a function', () {
      final doc = ExprDoc.fromNodes(chars('x+y'));
      doc.setCaret(const [], 0);
      expect(doc.wrapEnd, 3);
    });

    test('with nothing to the right it is a normal insert', () {
      final doc = ExprDoc.fromNodes(chars('1+'));
      expect(doc.insertStructWrapping(AbsNode(), argSlot: 0), isTrue);
      expect(doc.path, [2, 0]);
      expect(doc.offset, 0);
      expect((doc.root[2] as AbsNode).allEmpty, isTrue);
    });

    test('root wraps into the radicand, index stays empty', () {
      final doc = ExprDoc.fromNodes(chars('27'));
      doc.setCaret(const [], 0);
      doc.insertStructWrapping(RootNode(), argSlot: 1);
      final r = doc.root.single as RootNode;
      expect(r.slots[0].children, isEmpty);
      expect(r.slots[1].children, chars('27'));
      expect(doc.path, [0, 1]);
    });
  });

  test('spoken form names every structure and calls an empty slot empty', () {
    final doc = ExprDoc.fromNodes([
      FracNode([slot('1'), SlotNode()]),
      ...chars('+'),
      SqrtNode([slot('2')]),
    ]);
    expect(doc.semanticsLabel, 'fraction 1 over empty end fraction + square root of 2 end root');
  });
}
