import 'element_types.dart';
import 'elements.dart';

/// Lookups over the 118-element table (Part 3.1).
class ChemElements {
  ChemElements._();

  static final Map<String, ChemElement> _bySymbol = {for (final e in chemElements) e.symbol: e};
  static final Map<String, ChemElement> _byName = {for (final e in chemElements) e.name.toLowerCase(): e};

  /// Element with this exact symbol (`Fe`, case-sensitive), or null.
  static ChemElement? bySymbol(String symbol) => _bySymbol[symbol];

  static ChemElement? byNumber(int z) => (z >= 1 && z <= chemElements.length) ? chemElements[z - 1] : null;

  /// Lenient lookup used by `atomic("fe")` and `amass("Iron")`: symbol (any case), English name (any case, plus the
  /// IUPAC spellings aluminium / caesium / sulphur), or an atomic number written as text.
  static ChemElement? find(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;
    final asInt = int.tryParse(q);
    if (asInt != null) return byNumber(asInt);
    final sym = q[0].toUpperCase() + q.substring(1).toLowerCase();
    final bySym = _bySymbol[sym];
    if (bySym != null) return bySym;
    final lower = q.toLowerCase();
    final named = _byName[lower];
    if (named != null) return named;
    return switch (lower) {
      'aluminium' => _bySymbol['Al'],
      'caesium' => _bySymbol['Cs'],
      'sulphur' => _bySymbol['S'],
      _ => null,
    };
  }

  /// Periodic-table search box: matches atomic number, symbol or name (case-insensitive, substring on the name).
  static List<ChemElement> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return chemElements;
    return [
      for (final e in chemElements)
        if (e.symbol.toLowerCase() == q ||
            e.z.toString() == q ||
            e.name.toLowerCase().contains(q) ||
            (q.length >= 2 && e.symbol.toLowerCase().startsWith(q)))
          e,
    ];
  }
}
