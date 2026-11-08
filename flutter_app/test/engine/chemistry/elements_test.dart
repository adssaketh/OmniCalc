import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/chemistry/element_types.dart';
import 'package:omnicalc/engine/chemistry/elements.dart';
import 'package:omnicalc/engine/chemistry/elements_lookup.dart';

void main() {
  test('exactly 118 elements, atomic numbers 1..118 in order, unique symbols and names', () {
    expect(chemElements.length, 118);
    for (var i = 0; i < 118; i++) {
      expect(chemElements[i].z, i + 1);
    }
    expect({for (final e in chemElements) e.symbol}.length, 118);
    expect({for (final e in chemElements) e.name}.length, 118);
  });

  test('anchor values from the master prompt Appendix A', () {
    expect(ChemElements.bySymbol('H')!.mass, 1.008);
    expect(ChemElements.bySymbol('C')!.mass, 12.011);
    expect(ChemElements.bySymbol('Fe')!.mass, 55.84);
    expect(ChemElements.bySymbol('Og')!.mass, 295.216);
    expect(ChemElements.byNumber(26)!.symbol, 'Fe');
    expect(ChemElements.byNumber(0), isNull);
    expect(ChemElements.byNumber(119), isNull);
  });

  test('period, group and block follow the layout', () {
    final h = ChemElements.bySymbol('H')!;
    expect((h.period, h.group, h.block), (1, 1, 's'));
    final he = ChemElements.bySymbol('He')!;
    expect((he.period, he.group, he.block), (1, 18, 's'));
    final fe = ChemElements.bySymbol('Fe')!;
    expect((fe.period, fe.group, fe.block), (4, 8, 'd'));
    final la = ChemElements.bySymbol('La')!;
    expect((la.group, la.block), (null, 'f'));
    final hf = ChemElements.bySymbol('Hf')!;
    expect((hf.period, hf.group), (6, 4));
    final og = ChemElements.bySymbol('Og')!;
    expect((og.period, og.group, og.block), (7, 18, 'p'));
    for (final e in chemElements) {
      expect(elementCategories, contains(e.category), reason: e.symbol);
      expect(['s', 'p', 'd', 'f'], contains(e.block), reason: e.symbol);
    }
  });

  test('missing data is null, never invented', () {
    final og = ChemElements.bySymbol('Og')!;
    expect(og.meltingPointK, isNull);
    expect(og.densityGcm3, isNull);
    expect(og.electronegativity, isNull);
    final he = ChemElements.bySymbol('He')!;
    expect(he.electronAffinityEv, isNull); // unbound anion
    expect(he.densityGcm3, isNull); // gas: depends on T and P
    final fe = ChemElements.bySymbol('Fe')!;
    expect(fe.densityGcm3, closeTo(7.87, 0.01));
    expect(fe.electronConfig, '[Ar] 3d⁶ 4s²');
    expect(fe.standardState, 'solid');
    expect(ChemElements.bySymbol('Hg')!.standardState, 'liquid');
    expect(ChemElements.bySymbol('Br')!.standardState, 'liquid');
    expect(ChemElements.bySymbol('N')!.standardState, 'gas');
  });

  test('lenient lookup and search', () {
    expect(ChemElements.find('fe')!.z, 26);
    expect(ChemElements.find(' Iron ')!.z, 26);
    expect(ChemElements.find('aluminium')!.z, 13);
    expect(ChemElements.find('26')!.symbol, 'Fe');
    expect(ChemElements.find('Xx'), isNull);
    expect(ChemElements.search('iron').map((e) => e.symbol), contains('Fe'));
    expect(ChemElements.search('26').single.symbol, 'Fe');
    expect(ChemElements.search('Na').first.symbol, 'Na');
    expect(ChemElements.search('').length, 118);
    expect(ChemElements.search('zzz'), isEmpty);
  });
}
