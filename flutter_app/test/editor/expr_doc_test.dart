import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/editor/expr_doc.dart';
import 'package:omnicalc/editor/nodes.dart';

const List<String> tokens = ['sin(', 'cos(', 'y=', 'log2(', 'sqrt('];

void main() {
  group('typing a superscript', () {
    test('characters go into the superscript until it is left', () {
      final d = ExprDoc.plain('')..insertChars('2');
      expect(d.insertGroup(sup: true), isTrue);
      d
        ..insertChars('3')
        ..insertChars('+4');
      expect(d.linear, '2^(3+4)');
      expect(d.inGroup, isTrue);
    });

    test('leaving the superscript continues in the line', () {
      final d = ExprDoc.plain('')..insertChars('2');
      d
        ..insertGroup(sup: true)
        ..insertChars('3');
      expect(d.exitGroup(), isTrue);
      d.insertChars('+4');
      expect(d.linear, '2^3+4');
      expect(d.atRootEnd, isTrue);
    });

    test('insertLinear with an unfinished group puts the caret inside', () {
      final d = ExprDoc.plain('')..insertChars('x');
      d.insertLinear('^');
      expect(d.path, [1]);
      d.insertChars('2');
      expect(d.linear, 'x^2');
      d.exitGroup();
      d.insertLinear('^2'); // a finished group: the caret stays after it
      expect(d.inGroup, isFalse);
      expect(d.linear, 'x^2^2');
    });

    test('a prefilled group such as 10^( leaves the caret inside after the parenthesis', () {
      final d = ExprDoc.plain('')..insertLinear('10^(');
      expect(d.path, [2]);
      expect(d.offset, 1);
      d.insertChars('3)');
      expect(d.linear, '10^(3)');
    });

    test('three levels at most', () {
      final d = ExprDoc.plain('');
      expect(d.insertGroup(sup: true), isTrue);
      expect(d.insertGroup(sup: true), isTrue);
      expect(d.insertGroup(sup: false), isTrue);
      expect(d.depth, 3);
      expect(d.insertGroup(sup: true), isFalse);
      expect(d.depth, 3);
    });
  });

  group('moving the caret', () {
    ExprDoc sample() => ExprDoc.fromLinear('2^3+4')..setCaret(const [], 0);

    test('right steps over characters and into groups, left does the reverse', () {
      final d = sample();
      expect(d.moveRight(), isTrue); // over 2
      expect(d.offset, 1);
      expect(d.moveRight(), isTrue); // into the superscript
      expect(d.path, [1]);
      expect(d.offset, 0);
      expect(d.moveRight(), isTrue); // over 3
      expect(d.moveRight(), isTrue); // out at the end: after the superscript
      expect(d.path, isEmpty);
      expect(d.offset, 2);
      expect(d.moveLeft(), isTrue); // back into the superscript from its end
      expect(d.path, [1]);
      expect(d.offset, 1);
      expect(d.moveLeft(), isTrue);
      expect(d.moveLeft(), isTrue); // out at the start: before the superscript
      expect(d.path, isEmpty);
      expect(d.offset, 1);
    });

    test('nothing moves at the ends', () {
      final d = ExprDoc.plain('ab');
      expect(d.moveRight(), isFalse);
      d.setCaret(const [], 0);
      expect(d.moveLeft(), isFalse);
    });

    test('exitGroup jumps out from the middle of a group and does nothing in the root', () {
      final d = ExprDoc.fromLinear('2^(3+x)');
      d.setCaret(const [1], 2);
      expect(d.exitGroup(), isTrue);
      expect(d.path, isEmpty);
      expect(d.offset, 2);
      expect(d.exitGroup(), isFalse);
    });

    test('setCaret refuses places that do not exist', () {
      final d = ExprDoc.fromLinear('2^3');
      expect(d.setCaret(const [0], 0), isFalse); // node 0 is a character
      expect(d.setCaret(const [5], 0), isFalse);
      expect(d.setCaret(const [1], 9), isFalse);
      expect(d.setCaret(const [], -1), isFalse);
      expect(d.setCaret(const [1], 1), isTrue);
    });

    test('version changes with every move and edit', () {
      final d = ExprDoc.plain('ab');
      final v0 = d.version;
      d.setCaret(const [], 1);
      expect(d.version, isNot(v0));
      final v1 = d.version;
      d.insertChars('c');
      expect(d.version, isNot(v1));
    });
  });

  group('backspace', () {
    test('removes one character, or the token that ends at the caret', () {
      final d = ExprDoc.plain('2+sin(');
      d.backspace(tokens);
      expect(d.linear, '2+');
      d.backspace(tokens);
      expect(d.linear, '2');
    });

    test('an empty group goes away, a group with content is entered first', () {
      final d = ExprDoc.fromLinear('x^23')..setCaret(const [], 2);
      d.backspace(tokens); // into the superscript at its end
      expect(d.path, [1]);
      expect(d.linear, 'x^23');
      d.backspace(tokens);
      d.backspace(tokens);
      expect(d.linear, 'x^');
      d.backspace(tokens); // at the start of the empty group: it is removed
      expect(d.linear, 'x');
      expect(d.path, isEmpty);
      expect(d.offset, 1);
    });

    test('at the start of a group with content the caret steps out in front of it', () {
      final d = ExprDoc.fromLinear('x^23');
      d.setCaret(const [1], 0);
      d.backspace(tokens);
      expect(d.linear, 'x^23');
      expect(d.path, isEmpty);
      expect(d.offset, 1);
    });

    test('in the middle of the line', () {
      final d = ExprDoc.plain('abc')..setCaret(const [], 2);
      d.backspace(tokens);
      expect(d.linear, 'ac');
      expect(d.offset, 1);
    });
  });

  group('reading the caret', () {
    test('prevChar', () {
      final d = ExprDoc.fromLinear('x^2');
      expect(d.prevChar, '\u0000'); // a group is before the caret
      d.setCaret(const [], 1);
      expect(d.prevChar, 'x');
      d.setCaret(const [], 0);
      expect(d.prevChar, '');
    });

    test('textBeforeCaret stops at a group', () {
      final d = ExprDoc.fromLinear('3.5+x^2+1.2');
      expect(d.textBeforeCaret, '+1.2');
    });

    test('atRootEnd and hasGroups', () {
      final d = ExprDoc.fromLinear('x^2');
      expect(d.atRootEnd, isTrue);
      expect(d.hasGroups, isTrue);
      expect(ExprDoc.plain('x').hasGroups, isFalse);
    });
  });

  group('spoken form', () {
    test('squared, to the power of, subscript', () {
      expect(ExprDoc.fromLinear('x^2').semanticsLabel, 'x squared');
      expect(ExprDoc.fromLinear('x^3+1').semanticsLabel, 'x to the power of 3 +1');
      expect(ExprDoc.fromLinear('H_2O').semanticsLabel, 'H subscript 2 O');
    });
  });

  group('json', () {
    test('round trip keeps the tree, not just the text', () {
      final d = ExprDoc.fromLinear('2^(3+x)');
      final back = ExprDoc.fromJson(d.toJson())!;
      expect(back.root, d.root);
      expect(back.linear, '2^(3+x)');
    });

    test('junk gives null', () {
      expect(ExprDoc.fromJson('x'), isNull);
      expect(ExprDoc.fromJson([3]), isNull);
    });
  });

  group('plain and clear', () {
    test('plain does not read ^ as a group', () {
      final d = ExprDoc.plain('a^b');
      expect(d.hasGroups, isFalse);
      expect(d.root.every((n) => n is CharNode), isTrue);
      expect(d.linear, 'a^b');
    });

    test('clearAll empties the tree', () {
      final d = ExprDoc.fromLinear('2^3')..clearAll();
      expect(d.root, isEmpty);
      expect(d.atRootEnd, isTrue);
    });
  });
}
