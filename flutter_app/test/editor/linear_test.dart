import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/linear.dart';
import 'package:omnicalc/editor/nodes.dart';

import '../golden/golden_loader.dart';

List<Node> chars(String s) => [for (final u in s.codeUnits) CharNode(String.fromCharCode(u))];

String roundTrip(String s) => serializeNodes(parseLinear(s).nodes);

void main() {
  group('parse and serialize are lossless', () {
    test('every expression of the golden vectors reaches the engine unchanged', () {
      final exprs = <String>{
        for (final e in loadGolden('evaluator') as List) (e as Map)['expr'] as String,
        for (final e in loadGolden('evaluate_function') as List) (e as Map)['expr'] as String,
      };
      expect(exprs.length, greaterThan(300));
      for (final s in exprs) {
        expect(roundTrip(s), s, reason: 'expression: $s');
      }
    });

    test('awkward strings', () {
      for (final s in [
        '',
        '^',
        '_',
        '^^3',
        '2^',
        '2^-3',
        '0^−1',
        '2^(3',
        '2^(3+x^(2',
        '2^3^2',
        '2^(1+1)^2',
        'x^2(3)',
        'x^y(3)',
        'x^sin(x)',
        'x^sin(x',
        '10^(',
        'N_A',
        'H_2SO_4',
        '(1)^(2))',
        'a^b_c^d',
        '3.5^2.5.1',
        'y=x^2−5x+6',
        'integrate(x^2, 0, 1)',
      ]) {
        expect(roundTrip(s), s, reason: 'string: "$s"');
      }
    });

    test('random strings', () {
      final rng = math.Random(20261107);
      const alphabet = ['0', '1', '2', '.', '+', '−', '×', '(', ')', '^', '_', 'x', 'y', 'sin(', 'PI', ' ', ','];
      for (var n = 0; n < 4000; n++) {
        final s = [for (var i = 0, len = rng.nextInt(18); i < len; i++) alphabet[rng.nextInt(alphabet.length)]].join();
        expect(roundTrip(s), s, reason: 'string: "$s"');
      }
    });
  });

  group('parseLinear builds the groups', () {
    test('a number after ^ is the exponent, the rest stays in the line', () {
      expect(parseLinear('2^3+x').nodes, [
        const CharNode('2'),
        SupNode(chars('3')),
        const CharNode('+'),
        const CharNode('x'),
      ]);
    });

    test('a parenthesised exponent keeps its parentheses and nested groups', () {
      final nodes = parseLinear('2^(3+x^2)').nodes;
      expect(nodes.length, 2);
      final sup = nodes[1] as SupNode;
      expect(sup.children, [
        const CharNode('('),
        const CharNode('3'),
        const CharNode('+'),
        const CharNode('x'),
        SupNode(chars('2')),
        const CharNode(')'),
      ]);
    });

    test('a word and a call are one operand', () {
      expect(parseLinear('x^y').nodes[1], SupNode(chars('y')));
      expect(parseLinear('x^sin(x)').nodes[1], SupNode(chars('sin(x)')));
    });

    test('a sign is not part of the operand', () {
      expect(parseLinear('0^−1').nodes, [const CharNode('0'), SupNode(), ...chars('−1')]);
    });

    test('_ makes a subscript', () {
      expect(parseLinear('N_A').nodes, [const CharNode('N'), SubNode(chars('A'))]);
    });
  });

  group('where the caret goes after typing a string', () {
    test('inside an empty group', () {
      final p = parseLinear('2^');
      expect(p.path, [1]);
      expect(p.offset, 0);
    });

    test('inside a group with an unclosed parenthesis, at its end', () {
      final p = parseLinear('10^(');
      expect(p.path, [2]);
      expect(p.offset, 1);
    });

    test('after a finished group', () {
      final p = parseLinear('x^2');
      expect(p.path, isEmpty);
      expect(p.offset, 2);
    });

    test('in the deepest unfinished group', () {
      final p = parseLinear('2^(x^');
      expect(p.path, [1, 2]);
      expect(p.offset, 0);
    });
  });

  group('serializeNodes of trees made with the editor', () {
    test('bare operand for a number or word, parentheses otherwise', () {
      expect(serializeNodes([const CharNode('x'), SupNode(chars('2'))]), 'x^2');
      expect(serializeNodes([const CharNode('x'), SupNode(chars('n'))]), 'x^n');
      expect(serializeNodes([const CharNode('x'), SupNode(chars('3+x'))]), 'x^(3+x)');
      expect(serializeNodes([const CharNode('x'), SupNode(chars('-1'))]), 'x^(-1)');
      expect(serializeNodes([const CharNode('x'), SupNode(chars('(1+1)'))]), 'x^(1+1)');
    });

    test('nested groups', () {
      final tree = [
        const CharNode('2'),
        SupNode([...chars('3+x'), SupNode(chars('2'))]),
      ];
      expect(serializeNodes(tree), '2^(3+x^2)');
    });

    test('a bare exponent is closed off from a character that follows it', () {
      expect(serializeNodes([const CharNode('x'), SupNode(chars('2')), const CharNode('3')]), 'x^(2)3');
      expect(serializeNodes([const CharNode('x'), SupNode(chars('n')), const CharNode('y')]), 'x^(n)y');
      expect(serializeNodes([const CharNode('x'), SupNode(chars('n')), const CharNode('(')]), 'x^(n)(');
      // these do not run together, so they stay bare
      expect(serializeNodes([const CharNode('x'), SupNode(chars('2')), const CharNode('+')]), 'x^2+');
      expect(serializeNodes([const CharNode('x'), SupNode(chars('2')), const CharNode('x')]), 'x^2x');
    });

    test('an unclosed parenthesis in a group that is not last is closed', () {
      expect(serializeNodes([const CharNode('1'), SupNode(chars('(3')), ...chars('+4')]), '1^(3)+4');
      // last in its list it stays as typed (the evaluator closes it when = is pressed)
      expect(serializeNodes([const CharNode('1'), SupNode(chars('(3'))]), '1^(3');
    });

    test('the result reads back to the same text', () {
      for (final tree in <List<Node>>[
        [const CharNode('2'), SupNode(chars('3')), ...chars('+4')],
        [const CharNode('x'), SupNode(chars('2')), const CharNode('3')],
        [const CharNode('1'), SupNode(chars('(3')), ...chars('+4')],
        [
          const CharNode('x'),
          SupNode([...chars('a'), SubNode(chars('1'))]),
        ],
      ]) {
        final s = serializeNodes(tree);
        expect(roundTrip(s), s);
      }
    });

    test('simple trees come back as the same tree', () {
      final tree = <Node>[const CharNode('2'), SupNode(chars('3')), const CharNode('+'), const CharNode('x')];
      expect(parseLinear(serializeNodes(tree)).nodes, tree);
      final withParens = <Node>[const CharNode('2'), SupNode(chars('(3+x)'))];
      expect(parseLinear(serializeNodes(withParens)).nodes, withParens);
    });
  });

  group('json', () {
    test('runs of characters are one string', () {
      final nodes = parseLinear('2^(3+x^2)+1').nodes;
      expect(nodesToJson(nodes), [
        '2',
        {
          'sup': [
            '(3+x',
            {
              'sup': ['2'],
            },
            ')',
          ],
        },
        '+1',
      ]);
    });

    test('round trip', () {
      for (final s in ['2^(3+x^2)+1', 'H_2SO_4', 'x', '', '2^']) {
        final nodes = parseLinear(s).nodes;
        expect(nodesFromJson(nodesToJson(nodes)), nodes, reason: s);
      }
    });

    test('rejects what the editor did not write', () {
      expect(nodesFromJson('x'), isNull);
      expect(nodesFromJson([1]), isNull);
      expect(nodesFromJson([{'foo': []}]), isNull);
      expect(nodesFromJson([{'sup': 'x'}]), isNull);
    });
  });

  group('normalizeUnicodeScripts (paste)', () {
    test('superscripts', () {
      expect(normalizeUnicodeScripts('x²'), 'x^2');
      expect(normalizeUnicodeScripts('x¹²'), 'x^12');
      expect(normalizeUnicodeScripts('x⁻¹'), 'x^(-1)');
      expect(normalizeUnicodeScripts('2⁺³'), '2^(+3)');
    });

    test('subscripts', () {
      expect(normalizeUnicodeScripts('H₂SO₄'), 'H_2SO_4');
      expect(normalizeUnicodeScripts('a₋₁'), 'a_(-1)');
    });

    test('plain text is left alone', () {
      expect(normalizeUnicodeScripts('2+3×x^2'), '2+3×x^2');
    });
  });

  group('log base subscript (log₂, log_b)', () {
    test('log2( and logb( get a lowered base and still read back unchanged', () {
      for (final s in ['log2(8)', 'logb(8,2)', '2×log2(x)', 'log2(log2(4))', '2^log2(8)', 'sin(logb(x,3))', 'xlog2(3)', 'log2', 'logb']) {
        expect(serializeNodes(parseLinear(s).nodes), s, reason: s);
      }
    });

    test('the base is a bare subscript between log and the parenthesis', () {
      final nodes = parseLinear('log2(8)').nodes;
      expect(nodes.length, 7); // l o g <base> ( 8 )
      final base = nodes[3] as SubNode;
      expect(base.bare, isTrue);
      expect(base.children, [const CharNode('2')]);
      expect(serializeNodes(nodes).contains('_'), isFalse);
    });

    test('a word that merely ends in log is not split', () {
      expect(parseLinear('xlog2(3)').nodes.whereType<GroupNode>(), isEmpty);
      expect(parseLinear('log2').nodes.whereType<GroupNode>(), isEmpty);
    });

    test('as an exponent it stays one operand', () {
      final sup = parseLinear('2^log2(8)').nodes.whereType<SupNode>().single;
      expect(sup.children.whereType<SubNode>().single.bare, isTrue);
    });

    test('JSON keeps the bare flag', () {
      final nodes = parseLinear('log2(8)').nodes;
      expect(nodesFromJson(nodesToJson(nodes)), nodes);
      expect(nodesToJson(nodes), [
        'log',
        {'bsub': ['2']},
        '(8)',
      ]);
    });
  });
}
