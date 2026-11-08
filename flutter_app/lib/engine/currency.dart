import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'currency_data.dart';

export 'currency_data.dart';

/// Port of `src/engine/currency.ts`: live forex rates (four providers queried in parallel, first valid answer wins),
/// a persisted cache, built-in fallback rates and the conversion helper.

enum RatesStatus {
  live,
  cached,
  builtin;

  static RatesStatus? parse(Object? s) {
    for (final v in RatesStatus.values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

class RatesData {
  final String base;
  final Map<String, double> rates;

  /// Epoch milliseconds.
  final int timestamp;
  final String lastUpdatedStr;
  final bool isLive;

  /// Where the rates came from.
  final RatesStatus? status;

  /// Name of the provider that answered (live rates only).
  final String? provider;

  /// Why live rates were unavailable (fallback rates only).
  final String? error;

  const RatesData({
    required this.base,
    required this.rates,
    required this.timestamp,
    required this.lastUpdatedStr,
    required this.isLive,
    this.status,
    this.provider,
    this.error,
  });

  /// Same JSON shape the web app keeps in localStorage (`omni_calc_live_rates_cache`). Absent values are omitted,
  /// like `undefined` properties in `JSON.stringify`.
  Map<String, Object?> toJson() => {
        'base': base,
        'rates': rates,
        'timestamp': timestamp,
        'lastUpdatedStr': lastUpdatedStr,
        'isLive': isLive,
        if (status != null) 'status': status!.name,
        if (provider != null) 'provider': provider,
        if (error != null) 'error': error,
      };
}

/// The key the web app uses for its rates cache.
const String ratesStorageKey = 'omni_calc_live_rates_cache';

/// Per-provider timeout. Mobile networks routinely need more than a few seconds.
const int requestTimeoutMs = 8000;

/// A provider must return at least this share of [popularCurrencies] to be trusted.
const double minCoverage = 0.9;

class ParsedProvider {
  final Map<String, Object?> rates;

  /// Epoch ms of the rate itself, when the provider reports one.
  final int? timestamp;

  const ParsedProvider(this.rates, [this.timestamp]);
}

class RatesProvider {
  final String name;
  final String url;
  final ParsedProvider? Function(Object? data) parse;

  const RatesProvider({required this.name, required this.url, required this.parse});
}

/// JavaScript truthiness of a JSON number (`d.x ? d.x * 1000 : undefined`).
int? _unixSecondsToMs(Object? v) {
  if (v is num && v != 0 && !v.isNaN) return (v * 1000).round();
  return null;
}

// Shape: { date: "YYYY-MM-DD", usd: { inr: 83.2, eur: 0.92, ... } } with lower-case codes.
ParsedProvider? parseFawazFormat(Object? d) {
  final usd = d is Map ? d['usd'] : null;
  if (usd is! Map) return null;
  final rates = <String, Object?>{};
  usd.forEach((code, value) => rates[code.toString().toUpperCase()] = value);
  return ParsedProvider(rates);
}

// All providers are free, key-less, USD-based. They are queried in parallel and the first
// valid answer wins, so one slow or dead endpoint can no longer break live rates.
final List<RatesProvider> providers = [
  RatesProvider(
    name: 'open.er-api.com',
    url: 'https://open.er-api.com/v6/latest/USD',
    parse: (d) => d is Map && d['result'] == 'success' && d['rates'] is Map
        ? ParsedProvider(
            Map<String, Object?>.from(d['rates'] as Map),
            _unixSecondsToMs(d['time_last_update_unix']),
          )
        : null,
  ),
  RatesProvider(
    name: 'api.exchangerate-api.com',
    url: 'https://api.exchangerate-api.com/v4/latest/USD',
    parse: (d) => d is Map && d['rates'] is Map
        ? ParsedProvider(
            Map<String, Object?>.from(d['rates'] as Map),
            _unixSecondsToMs(d['time_last_updated']),
          )
        : null,
  ),
  const RatesProvider(
    name: 'currency-api (jsdelivr)',
    url: 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
    parse: parseFawazFormat,
  ),
  const RatesProvider(
    name: 'currency-api (pages.dev)',
    url: 'https://latest.currency-api.pages.dev/v1/currencies/usd.json',
    parse: parseFawazFormat,
  ),
];

/// JavaScript `Number(value)` for the JSON values a provider can return.
double _jsNumber(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? double.nan;
  }
  if (v is bool) return v ? 1 : 0;
  if (v == null) return 0;
  return double.nan;
}

/// Keep only finite positive numbers and reject answers that are clearly incomplete or wrong.
Map<String, double>? sanitizeRates(Map<String, Object?> raw) {
  final out = <String, double>{};
  raw.forEach((code, value) {
    final n = _jsNumber(value);
    if (n.isFinite && n > 0) out[code.toUpperCase()] = n;
  });
  out.putIfAbsent('USD', () => 1);
  if ((out['USD']! - 1).abs() > 0.001) return null; // not USD-based
  final present = popularCurrencies.where((c) => out.containsKey(c.code)).length;
  if (present < popularCurrencies.length * minCoverage) return null;
  return out;
}

/// How the "last updated" stamp is written. The web app uses the device locale (`toLocaleTimeString`); the Flutter
/// app lets the UI layer pick. Default: 24-hour `HH:mm`, and `d MMM, HH:mm` for another day.
enum StampStyle { h24, h12 }

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

String formatStamp(int ts, {DateTime? now, StampStyle style = StampStyle.h24}) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final String time;
  if (style == StampStyle.h24) {
    time = '${_two(d.hour)}:${_two(d.minute)}';
  } else {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    time = '${_two(h)}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
  }
  final n = now ?? DateTime.now();
  if (d.year == n.year && d.month == n.month && d.day == n.day) return time;
  return '${d.day} ${_months[d.month - 1]}, $time';
}

// ---------------------------------------------------------------------------------------------------------------------
// Fetching
// ---------------------------------------------------------------------------------------------------------------------

/// A failed provider attempt. [message] is what ends up in `RatesData.error`.
class ProviderError implements Exception {
  final String message;
  const ProviderError(this.message);

  @override
  String toString() => message;
}

class RawResponse {
  final int status;
  final String body;

  const RawResponse(this.status, this.body);
}

/// Performs one GET. [aborted] completes when the request is no longer needed (another provider already won, or the
/// attempt timed out); implementations should then cancel the request.
typedef HttpGetter = Future<RawResponse> Function(String url, Future<void> aborted);

Future<RawResponse> defaultHttpGetter(String url, Future<void> aborted) async {
  final client = http.Client();
  unawaited(aborted.then((_) => client.close()));
  try {
    final res = await client.get(Uri.parse(url));
    return RawResponse(res.statusCode, res.body);
  } finally {
    client.close();
  }
}

class ProviderResult {
  final Map<String, double> rates;
  final int timestamp;
  final String provider;

  const ProviderResult(this.rates, this.timestamp, this.provider);
}

/// Persistence for the rates cache (the web app's localStorage entry).
abstract class RatesCache {
  Future<String?> read();
  Future<void> write(String json);
}

class SharedPreferencesRatesCache implements RatesCache {
  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(ratesStorageKey);

  @override
  Future<void> write(String json) async {
    await (await SharedPreferences.getInstance()).setString(ratesStorageKey, json);
  }
}

class MemoryRatesCache implements RatesCache {
  String? value;

  MemoryRatesCache([this.value]);

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async {
    value = json;
  }
}

String _errorText(Object e) => e is ProviderError ? e.message : e.toString();

class CurrencyService {
  final HttpGetter getter;
  final RatesCache cache;
  final List<RatesProvider> providerList;
  final DateTime Function() clock;
  final StampStyle stampStyle;

  CurrencyService({
    HttpGetter? getter,
    RatesCache? cache,
    List<RatesProvider>? providerList,
    DateTime Function()? clock,
    this.stampStyle = StampStyle.h24,
  })  : getter = getter ?? defaultHttpGetter,
        cache = cache ?? SharedPreferencesRatesCache(),
        providerList = providerList ?? providers,
        clock = clock ?? DateTime.now;

  Future<ProviderResult> _fetchFromProvider(RatesProvider provider, Future<void> outerAborted, int timeoutMs) {
    final aborted = Completer<void>();
    unawaited(outerAborted.then((_) {
      if (!aborted.isCompleted) aborted.complete();
    }));

    Future<ProviderResult> work() async {
      final res = await getter(provider.url, aborted.future);
      if (res.status < 200 || res.status > 299) throw ProviderError('HTTP ${res.status}');
      Object? json;
      try {
        json = jsonDecode(res.body);
      } on FormatException catch (e) {
        throw ProviderError(e.message);
      }
      final parsed = provider.parse(json);
      if (parsed == null) throw const ProviderError('unexpected response shape');
      final rates = sanitizeRates(parsed.rates);
      if (rates == null) throw const ProviderError('incomplete or invalid rates');
      return ProviderResult(rates, parsed.timestamp ?? clock().millisecondsSinceEpoch, provider.name);
    }

    // Race against a timer as well as aborting the request, so a getter that ignores `aborted` still cannot hang.
    return work().timeout(Duration(milliseconds: timeoutMs), onTimeout: () {
      if (!aborted.isCompleted) aborted.complete();
      throw const ProviderError('timeout');
    }).whenComplete(() {
      if (!aborted.isCompleted) aborted.complete();
    });
  }

  /// Query every provider at once; resolve with the first valid answer, or all the errors.
  Future<({ProviderResult? result, List<String> errors})> _raceProviders(int timeoutMs) {
    final outer = Completer<void>();
    final errors = <String>[];
    final done = Completer<({ProviderResult? result, List<String> errors})>();
    var pending = providerList.length;
    var settled = false;
    if (pending == 0) {
      return Future.value((result: null, errors: errors));
    }
    for (final provider in providerList) {
      _fetchFromProvider(provider, outer.future, timeoutMs).then((result) {
        if (settled) return;
        settled = true;
        if (!outer.isCompleted) outer.complete(); // cancel the slower providers
        done.complete((result: result, errors: errors));
      }).catchError((Object e) {
        if (!settled) errors.add('${provider.name}: ${_errorText(e)}');
      }).whenComplete(() {
        pending -= 1;
        if (pending == 0 && !settled) {
          settled = true;
          done.complete((result: null, errors: errors));
        }
      });
    }
    return done.future;
  }

  Future<RatesData> _getCachedOrFallback([String? error]) async {
    try {
      final cached = await cache.read();
      if (cached != null && cached.isNotEmpty) {
        final parsed = jsonDecode(cached);
        if (parsed is Map && parsed['rates'] is Map) {
          final rates = <String, double>{};
          (parsed['rates'] as Map).forEach((k, v) {
            if (v is num) rates[k.toString()] = v.toDouble();
          });
          final tsRaw = parsed['timestamp'];
          final ts = tsRaw is num ? tsRaw.round() : 0;
          return RatesData(
            base: parsed['base'] is String ? parsed['base'] as String : 'USD',
            rates: rates,
            timestamp: ts,
            lastUpdatedStr: ts != 0 ? 'Cached (${formatStamp(ts, now: clock(), style: stampStyle)})' : 'Cached',
            isLive: false,
            status: RatesStatus.cached,
            provider: null,
            error: error,
          );
        }
      }
    } catch (_) {
      // ignore corrupt or unavailable storage
    }

    return RatesData(
      base: 'USD',
      rates: defaultRatesUsd,
      timestamp: clock().millisecondsSinceEpoch,
      lastUpdatedStr: 'Built-in rates (offline)',
      isLive: false,
      status: RatesStatus.builtin,
      error: error,
    );
  }

  /// Fetch live USD-based rates. Never throws: falls back to the cache, then to the built-in rates.
  Future<RatesData> fetchLiveExchangeRates([int timeoutMs = requestTimeoutMs]) async {
    // Deliberately NOT short-circuiting on connectivity checks: they can report offline even when the network works,
    // which would pin the app to fallback rates. Every request is time-limited, so trying while genuinely offline
    // only costs a moment.
    final (:result, :errors) = await _raceProviders(timeoutMs);

    if (result != null) {
      final ratesData = RatesData(
        base: 'USD',
        rates: {...defaultRatesUsd, ...result.rates},
        timestamp: result.timestamp,
        lastUpdatedStr: formatStamp(result.timestamp, now: clock(), style: stampStyle),
        isLive: true,
        status: RatesStatus.live,
        provider: result.provider,
      );
      try {
        await cache.write(jsonEncode(ratesData.toJson()));
      } catch (_) {
        // ignore storage error
      }
      return ratesData;
    }

    return _getCachedOrFallback(errors.isEmpty ? 'no provider responded' : errors.join('; '));
  }
}

/// Convert an amount from one currency to another using USD-based rates.
({double result, double rate, double inverseRate}) convertCurrency(
  double amount,
  String fromCode,
  String toCode,
  Map<String, double> rates,
) {
  if (amount.isNaN || amount == 0) {
    return (result: 0.0, rate: 0.0, inverseRate: 0.0);
  }

  final fromRateUSD = rates[fromCode] ?? defaultRatesUsd[fromCode] ?? 1.0;
  final toRateUSD = rates[toCode] ?? defaultRatesUsd[toCode] ?? 1.0;

  // Amount in USD = amount / fromRateUSD
  // Target amount = amountInUSD * toRateUSD
  final directRate = toRateUSD / fromRateUSD;
  final inverseRate = fromRateUSD / toRateUSD;
  final result = amount * directRate;

  return (result: result, rate: directRate, inverseRate: inverseRate);
}
