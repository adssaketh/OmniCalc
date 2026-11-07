import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/currency.dart';

// Behaviour of the live-rates logic in src/engine/currency.ts that the golden vectors cannot cover:
// provider parsing, sanitising, the first-valid-answer race, timeouts, cache and fallback. Network and storage are faked.

/// A USD-based rate table covering every popular currency (+ one extra code).
Map<String, Object?> fullRates({double inr = 90.5}) => {
      for (var i = 0; i < popularCurrencies.length; i++) popularCurrencies[i].code: 1.0 + i,
      'INR': inr,
      'USD': 1,
      'XAU': 0.0004,
    };

String erApi({double inr = 90.5, int unix = 1762500000}) =>
    jsonEncode({'result': 'success', 'rates': fullRates(inr: inr), 'time_last_update_unix': unix});

String fawaz({double inr = 91.0}) =>
    jsonEncode({'date': '2026-11-07', 'usd': {for (final e in fullRates(inr: inr).entries) e.key.toLowerCase(): e.value}});

final DateTime fixedNow = DateTime(2026, 11, 7, 9, 22);

/// url -> (delay, response). Anything not listed fails with HTTP 503.
HttpGetter fakeGetter(Map<String, (Duration, RawResponse)> table, {List<String>? log}) {
  return (url, aborted) async {
    log?.add(url);
    final entry = table[url];
    if (entry == null) return const RawResponse(503, '');
    await Future<void>.delayed(entry.$1);
    return entry.$2;
  };
}

const Duration none = Duration.zero;
final String urlEr = providers[0].url;
final String urlExApi = providers[1].url;
final String urlJsd = providers[2].url;
final String urlPages = providers[3].url;

CurrencyService service(HttpGetter g, {RatesCache? cache}) =>
    CurrencyService(getter: g, cache: cache ?? MemoryRatesCache(), clock: () => fixedNow);

void main() {
  group('providers', () {
    test('four providers with the web app urls, in order', () {
      expect(providers.map((p) => p.name), [
        'open.er-api.com',
        'api.exchangerate-api.com',
        'currency-api (jsdelivr)',
        'currency-api (pages.dev)',
      ]);
      expect(urlEr, 'https://open.er-api.com/v6/latest/USD');
      expect(urlExApi, 'https://api.exchangerate-api.com/v4/latest/USD');
      expect(urlJsd, 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json');
      expect(urlPages, 'https://latest.currency-api.pages.dev/v1/currencies/usd.json');
    });

    test('open.er-api.com: needs result == success; timestamp is unix seconds * 1000', () {
      final ok = providers[0].parse(jsonDecode(erApi()))!;
      expect(ok.timestamp, 1762500000 * 1000);
      expect(ok.rates['INR'], 90.5);
      expect(providers[0].parse({'result': 'error', 'rates': {}}), isNull);
      expect(providers[0].parse({'rates': {}}), isNull);
      expect(providers[0].parse(null), isNull);
      expect(providers[0].parse({'result': 'success', 'rates': {'INR': 1}})!.timestamp, isNull);
    });

    test('api.exchangerate-api.com: timestamp from time_last_updated', () {
      final p = providers[1].parse({'rates': {'INR': 90}, 'time_last_updated': 1762500000})!;
      expect(p.timestamp, 1762500000 * 1000);
      expect(providers[1].parse({'base': 'USD'}), isNull);
    });

    test('currency-api format: lower-case codes become upper-case, no timestamp', () {
      final p = parseFawazFormat({'usd': {'inr': 83.2, 'eur': 0.92}})!;
      expect(p.rates, {'INR': 83.2, 'EUR': 0.92});
      expect(p.timestamp, isNull);
      expect(parseFawazFormat({'usd': 'nope'}), isNull);
      expect(parseFawazFormat({}), isNull);
    });
  });

  group('sanitizeRates', () {
    test('keeps finite positive numbers (numeric strings too), upper-cases codes, adds USD', () {
      final raw = fullRates()..remove('USD');
      raw['eur'] = '0.95';
      raw['bad1'] = -1;
      raw['bad2'] = 0;
      raw['bad3'] = 'abc';
      raw['bad4'] = double.infinity;
      final out = sanitizeRates(raw)!;
      expect(out['USD'], 1.0);
      expect(out['EUR'], 0.95);
      expect(out.containsKey('BAD1'), isFalse);
      expect(out.containsKey('BAD2'), isFalse);
      expect(out.containsKey('BAD3'), isFalse);
      expect(out.containsKey('BAD4'), isFalse);
      expect(out['XAU'], 0.0004);
    });

    test('rejects a table that is not USD-based', () {
      final raw = fullRates();
      raw['USD'] = 1.5;
      expect(sanitizeRates(raw), isNull);
    });

    test('needs at least 90% of the popular currencies', () {
      // 37 * 0.9 = 33.3 -> 33 present is rejected, 34 present is accepted
      Map<String, Object?> only(int n) => {for (final c in popularCurrencies.take(n)) c.code: c.code == 'USD' ? 1.0 : 2.0};
      expect(sanitizeRates(only(33)), isNull);
      expect(sanitizeRates(only(34)), isNotNull);
    });
  });

  group('formatStamp', () {
    final ts = DateTime(2026, 11, 7, 9, 5).millisecondsSinceEpoch;
    final yesterday = DateTime(2026, 11, 6, 21, 40).millisecondsSinceEpoch;
    test('same day: time only', () {
      expect(formatStamp(ts, now: fixedNow), '09:05');
      expect(formatStamp(ts, now: fixedNow, style: StampStyle.h12), '09:05 AM');
    });
    test('other day: date, then time', () {
      expect(formatStamp(yesterday, now: fixedNow), '6 Nov, 21:40');
      expect(formatStamp(yesterday, now: fixedNow, style: StampStyle.h12), '6 Nov, 09:40 PM');
    });
    test('12-hour edge cases', () {
      expect(formatStamp(DateTime(2026, 11, 7, 0, 3).millisecondsSinceEpoch, now: fixedNow, style: StampStyle.h12), '12:03 AM');
      expect(formatStamp(DateTime(2026, 11, 7, 12, 3).millisecondsSinceEpoch, now: fixedNow, style: StampStyle.h12), '12:03 PM');
    });
  });

  group('fetchLiveExchangeRates', () {
    test('the fastest valid provider wins; rates are merged over the built-in table; cache is written', () async {
      final cache = MemoryRatesCache();
      final g = fakeGetter({
        urlEr: (const Duration(milliseconds: 80), RawResponse(200, erApi(inr: 90.5))),
        urlJsd: (const Duration(milliseconds: 5), RawResponse(200, fawaz(inr: 91.0))),
      });
      final r = await service(g, cache: cache).fetchLiveExchangeRates();
      expect(r.isLive, isTrue);
      expect(r.status, RatesStatus.live);
      expect(r.provider, 'currency-api (jsdelivr)');
      expect(r.base, 'USD');
      expect(r.rates['INR'], 91.0);
      expect(r.rates['XAU'], 0.0004);
      expect(r.rates.length, greaterThanOrEqualTo(defaultRatesUsd.length));
      expect(r.error, isNull);
      // no timestamp from this provider -> "now"
      expect(r.timestamp, fixedNow.millisecondsSinceEpoch);
      expect(r.lastUpdatedStr, '09:22');

      final saved = jsonDecode(cache.value!) as Map<String, dynamic>;
      expect(saved['status'], 'live');
      expect(saved['provider'], 'currency-api (jsdelivr)');
      expect((saved['rates'] as Map)['INR'], 91.0);
      expect(saved.containsKey('error'), isFalse);
    });

    test('a provider that answers with garbage is skipped in favour of a valid one', () async {
      final g = fakeGetter({
        urlEr: (none, const RawResponse(200, 'not json')),
        urlExApi: (none, RawResponse(200, jsonEncode({'rates': {'INR': 90}}))), // too few currencies
        urlPages: (const Duration(milliseconds: 20), RawResponse(200, fawaz(inr: 92.0))),
      });
      final r = await service(g).fetchLiveExchangeRates();
      expect(r.provider, 'currency-api (pages.dev)');
      expect(r.rates['INR'], 92.0);
    });

    test('uses the timestamp reported by the provider', () async {
      final unix = DateTime(2026, 11, 7, 4, 30).millisecondsSinceEpoch ~/ 1000;
      final g = fakeGetter({urlEr: (none, RawResponse(200, erApi(unix: unix)))});
      final r = await service(g).fetchLiveExchangeRates();
      expect(r.timestamp, unix * 1000);
      expect(r.lastUpdatedStr, '04:30');
    });

    test('all providers fail, no cache: built-in rates with every error listed', () async {
      final g = fakeGetter({
        urlEr: (none, const RawResponse(500, '')),
        urlExApi: (none, const RawResponse(200, '{"nope":1}')),
        urlJsd: (none, RawResponse(200, jsonEncode({'usd': {'inr': 1}}))),
      });
      final r = await service(g).fetchLiveExchangeRates();
      expect(r.isLive, isFalse);
      expect(r.status, RatesStatus.builtin);
      expect(r.lastUpdatedStr, 'Built-in rates (offline)');
      expect(r.rates, defaultRatesUsd);
      expect(r.provider, isNull);
      expect(r.timestamp, fixedNow.millisecondsSinceEpoch);
      final e = r.error!;
      expect(e, contains('open.er-api.com: HTTP 500'));
      expect(e, contains('api.exchangerate-api.com: unexpected response shape'));
      expect(e, contains('currency-api (jsdelivr): incomplete or invalid rates'));
      expect(e, contains('currency-api (pages.dev): HTTP 503'));
      expect(e.split('; ').length, 4);
    });

    test('all providers fail, with a cache: cached rates, labelled', () async {
      final cache = MemoryRatesCache(jsonEncode({
        'base': 'USD',
        'rates': {'USD': 1, 'INR': 88.25},
        'timestamp': DateTime(2026, 11, 6, 18, 0).millisecondsSinceEpoch,
        'lastUpdatedStr': '18:00',
        'isLive': true,
        'status': 'live',
        'provider': 'open.er-api.com',
      }));
      final r = await service(fakeGetter({}), cache: cache).fetchLiveExchangeRates();
      expect(r.isLive, isFalse);
      expect(r.status, RatesStatus.cached);
      expect(r.provider, isNull);
      expect(r.rates, {'USD': 1.0, 'INR': 88.25});
      expect(r.lastUpdatedStr, 'Cached (6 Nov, 18:00)');
      expect(r.error, isNotNull);
    });

    test('a corrupt cache falls through to the built-in rates', () async {
      final r = await service(fakeGetter({}), cache: MemoryRatesCache('{{{')).fetchLiveExchangeRates();
      expect(r.status, RatesStatus.builtin);
    });

    test('a cache entry without rates falls through to the built-in rates', () async {
      final r = await service(fakeGetter({}), cache: MemoryRatesCache('{"base":"USD"}')).fetchLiveExchangeRates();
      expect(r.status, RatesStatus.builtin);
    });

    test('a request that never answers times out and the error says so', () async {
      final hang = Completer<RawResponse>();
      final svc = CurrencyService(
        getter: (url, aborted) => hang.future,
        cache: MemoryRatesCache(),
        providerList: [providers[0]],
        clock: () => fixedNow,
      );
      final r = await svc.fetchLiveExchangeRates(30);
      expect(r.status, RatesStatus.builtin);
      expect(r.error, 'open.er-api.com: timeout');
    });

    test('slower providers are told to abort once one has won', () async {
      final aborted = <String, bool>{};
      final svc = CurrencyService(
        getter: (url, abortFuture) async {
          if (url == urlEr) return RawResponse(200, erApi());
          unawaited(abortFuture.then((_) => aborted[url] = true));
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return const RawResponse(500, '');
        },
        cache: MemoryRatesCache(),
        clock: () => fixedNow,
      );
      final r = await svc.fetchLiveExchangeRates();
      expect(r.provider, 'open.er-api.com');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(aborted.keys.toSet(), {urlExApi, urlJsd, urlPages});
    });

    test('all four providers are queried', () async {
      final log = <String>[];
      await service(fakeGetter({}, log: log)).fetchLiveExchangeRates();
      expect(log.toSet(), {urlEr, urlExApi, urlJsd, urlPages});
    });
  });
}
