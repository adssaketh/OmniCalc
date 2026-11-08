import 'dart:convert';

import 'package:omnicalc/engine/currency.dart';

/// Fixed clock of the currency tests: 7 Nov 2026, 09:22.
final DateTime currencyTestNow = DateTime(2026, 11, 7, 9, 22);

/// A rates API that is always unreachable: the screen ends on the built-in rates.
CurrencyService offlineCurrencyService({RatesCache? cache}) => CurrencyService(
      getter: (url, aborted) async => throw const ProviderError('offline'),
      cache: cache ?? MemoryRatesCache(),
      clock: () => currencyTestNow,
    );

/// USD-based table with every popular currency (EUR = 3.0, INR = [inr], USD = 1, ...), as the live providers return.
Map<String, Object?> liveRates({double inr = 90.5}) => {
      for (var i = 0; i < popularCurrencies.length; i++) popularCurrencies[i].code: 1.0 + i,
      'INR': inr,
      'USD': 1,
    };

/// The first provider answers with [liveRates] (no timestamp, so the stamp is the clock); the others fail with 503.
CurrencyService liveCurrencyService({double inr = 90.5, RatesCache? cache}) {
  final first = providers.first.url;
  return CurrencyService(
    getter: (url, aborted) async {
      if (url == first) return RawResponse(200, jsonEncode({'result': 'success', 'rates': liveRates(inr: inr)}));
      return const RawResponse(503, '');
    },
    cache: cache ?? MemoryRatesCache(),
    clock: () => currencyTestNow,
  );
}
