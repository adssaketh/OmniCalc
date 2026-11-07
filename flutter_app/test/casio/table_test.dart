import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/table.dart';

CVal num_(num v) => v == v.roundToDouble() ? CVal.int(v.toInt()) : CVal.dec(v.toDouble());

List<CasioTableRow> gen(String f,
    {String? g,
    bool fg = false,
    num start = 1,
    num end = 5,
    num step = 1,
    CasioMemory? memory,
    CasioConfig config = const CasioConfig()}) {
  return CasioTable.generate(
    f: f,
    g: g,
    fg: fg,
    start: num_(start),
    end: num_(end),
    step: num_(step),
    config: config,
    memory: memory ?? CasioMemory(),
  );
}

CasioErrorKind kindOf(void Function() f) {
  try {
    f();
  } on CasioError catch (e) {
    return e.kind;
  }
  fail('no error');
}

void main() {
  test('defaults are Start 1, End 5, Step 1 (manual p.77)', () {
    expect((kTableDefaultStart, kTableDefaultEnd, kTableDefaultStep), (1, 5, 1));
    final rows = gen('X²');
    expect([for (final r in rows) r.x.v], [1, 2, 3, 4, 5]);
    expect([for (final r in rows) r.f!.v], [1, 4, 9, 16, 25]);
  });

  test('manual example: f(x) = x² + 1/2, g(x) = x² − 1/2 for −1 ≤ x ≤ 1, step 0.5', () {
    final rows = gen('X²+1÷2', g: 'X²−1÷2', fg: true, start: -1, end: 1, step: 0.5);
    expect(rows.length, 5);
    expect([for (final r in rows) r.x.v], [-1, -0.5, 0, 0.5, 1]);
    expect([for (final r in rows) r.f!.v], [1.5, 0.75, 0.5, 0.75, 1.5]);
    expect([for (final r in rows) r.g!.v], [0.5, -0.25, -0.5, -0.25, 0.5]);
  });

  test('without g(x) the table is based on f(x) only', () {
    final rows = gen('X²+1÷2', g: '', fg: true, start: -1, end: 1, step: 0.5);
    expect(rows.every((r) => r.g == null), isTrue);
  });

  test('f(x) only setting ignores g(x)', () {
    final rows = gen('X', g: 'X²', fg: false, start: 1, end: 3);
    expect(rows.every((r) => r.g == null), isTrue);
  });

  test('exact steps stay exact', () {
    final rows = gen('X÷3', start: 1, end: 3);
    expect(rows.first.f!.ex, isNotNull);
  });

  test('30 rows with f(x), 31 is Insufficient MEM', () {
    expect(gen('X', start: 1, end: 30).length, 30);
    expect(kindOf(() => gen('X', start: 1, end: 31)), CasioErrorKind.insufficientMem);
  });

  test('20 rows with f(x),g(x), 21 is Insufficient MEM', () {
    expect(gen('X', g: 'X', fg: true, start: 1, end: 20).length, 20);
    expect(kindOf(() => gen('X', g: 'X', fg: true, start: 1, end: 21)), CasioErrorKind.insufficientMem);
  });

  test('End must be greater than Start; Step must be positive', () {
    expect(kindOf(() => gen('X', start: 5, end: 5)), CasioErrorKind.argument);
    expect(kindOf(() => gen('X', start: 5, end: 1)), CasioErrorKind.argument);
    expect(kindOf(() => gen('X', step: 0)), CasioErrorKind.argument);
    expect(kindOf(() => gen('X', step: -1)), CasioErrorKind.argument);
  });

  test('Pol, Rec, ∫, d/dx, Σ, ∏ are not allowed in the function', () {
    for (final bad in ['Pol(X,1)', 'Rec(X,1)', '∫(X,0,1)', 'd/dx(X,1)', 'Σ(X,1,3)', '∏(X,1,3)']) {
      expect(kindOf(() => gen(bad)), CasioErrorKind.syntax, reason: bad);
    }
    expect(kindOf(() => gen('X', g: '∫(X,0,1)', fg: true)), CasioErrorKind.syntax);
  });

  test('other variables are constants', () {
    final mem = CasioMemory()..vars['A'] = CVal.int(10);
    final rows = gen('A+X', memory: mem, start: 1, end: 3);
    expect([for (final r in rows) r.f!.v], [11, 12, 13]);
  });

  test('generating a table changes the value of X to the last X', () {
    final mem = CasioMemory()..vars['X'] = CVal.int(99);
    gen('X', memory: mem, start: 1, end: 4);
    expect(mem.vars['X']!.v, 4);
  });

  test('a cell that cannot be calculated shows ERROR, the others stay', () {
    final rows = gen('1÷X', start: -1, end: 1);
    expect(rows[0].f!.v, -1);
    expect(rows[1].f, isNull);
    expect(CasioTable.cellText(rows[1].f, rows[1].fError, const CasioConfig()), 'ERROR');
    expect(rows[2].f!.v, 1);
  });

  test('an empty f(x) is a Syntax ERROR', () {
    expect(kindOf(() => gen('  ')), CasioErrorKind.syntax);
  });

  test('works with the legacy calculation style setting', () {
    final rows = gen('X²', config: const CasioConfig(useCasio: false));
    expect(rows.last.f!.v, 25);
  });

  test('angle unit applies inside f(x)', () {
    final rows = gen('sin(X)', start: 30, end: 90, step: 30);
    expect([for (final r in rows) r.f!.v], [0.5, closeTo(0.866025403784439, 1e-12), 1]);
  });
}
