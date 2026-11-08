import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/currency.dart';

import 'golden_expect.dart';
import 'golden_loader.dart';

// Vectors produced by running the real TypeScript engine (see tools/gen_vectors.ts). raw doubles: 1e-9 relative.
void main() {
  final vectors = (loadGolden('currency') as List).cast<Map<String, dynamic>>();

  test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(9)));

  for (var i = 0; i < vectors.length; i++) {
    final v = vectors[i];
    final a = v['in'] as List;
    test('#$i convert $a', () {
      final r = convertCurrency(toD(a[0]), a[1] as String, a[2] as String, defaultRatesUsd);
      final want = v['out'] as Map<String, dynamic>;
      expectNum(r.result, want['result'], 'result');
      expectNum(r.rate, want['rate'], 'rate');
      expectNum(r.inverseRate, want['inverseRate'], 'inverseRate');
    });
  }

  group('generated currency data (from currency.ts)', () {
    test('37 currencies, codes unique, INR first, same codes as the fallback rate table', () {
      expect(popularCurrencies.length, 37);
      expect(popularCurrencies.map((c) => c.code).toSet().length, 37);
      expect(popularCurrencies.first.code, 'INR');
      expect(popularCurrencies.last.code, 'NPR');
      expect(defaultRatesUsd.length, 37);
      for (final c in popularCurrencies) {
        expect(defaultRatesUsd.containsKey(c.code), isTrue, reason: c.code);
      }
      expect(defaultRatesUsd['USD'], 1.0);
      expect(defaultRatesUsd['INR'], 86.82);
      expect(defaultRatesUsd['KRW'], 1442.0);
    });

    test('symbols and flags survive generation', () {
      final byCode = {for (final c in popularCurrencies) c.code: c};
      expect(byCode['USD']!.symbol, r'$');
      expect(byCode['INR']!.symbol, '₹');
      expect(byCode['INR']!.flag, '🇮🇳');
      expect(byCode['AED']!.symbol, 'د.إ');
      expect(byCode['AUD']!.symbol, r'A$');
    });
  });
}
