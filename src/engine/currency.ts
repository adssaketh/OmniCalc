/**
 * Real-time Currency Exchange Engine
 * Provides live forex rates, conversion helpers, and multi-currency data.
 */

export interface CurrencyItem {
  code: string;
  name: string;
  symbol: string;
  flag: string;
}

export const POPULAR_CURRENCIES: CurrencyItem[] = [
  { code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳' },
  { code: 'USD', name: 'US Dollar', symbol: '$', flag: '🇺🇸' },
  { code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺' },
  { code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧' },
  { code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪' },
  { code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵' },
  { code: 'CAD', name: 'Canadian Dollar', symbol: 'C$', flag: '🇨🇦' },
  { code: 'AUD', name: 'Australian Dollar', symbol: 'A$', flag: '🇦🇺' },
  { code: 'SGD', name: 'Singapore Dollar', symbol: 'S$', flag: '🇸🇬' },
  { code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', flag: '🇨🇭' },
  { code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳' },
  { code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', flag: '🇸🇦' },
  { code: 'QAR', name: 'Qatari Riyal', symbol: 'ر.ق', flag: '🇶🇦' },
  { code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'د.ك', flag: '🇰🇼' },
  { code: 'BHD', name: 'Bahraini Dinar', symbol: '.د.ب', flag: '🇧🇭' },
  { code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع.', flag: '🇴🇲' },
  { code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ$', flag: '🇳🇿' },
  { code: 'THB', name: 'Thai Baht', symbol: '฿', flag: '🇹🇭' },
  { code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flag: '🇲🇾' },
  { code: 'KRW', name: 'South Korean Won', symbol: '₩', flag: '🇰🇷' },
  { code: 'BRL', name: 'Brazilian Real', symbol: 'R$', flag: '🇧🇷' },
  { code: 'ZAR', name: 'South African Rand', symbol: 'R', flag: '🇿🇦' },
  { code: 'SEK', name: 'Swedish Krona', symbol: 'kr', flag: '🇸🇪' },
  { code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', flag: '🇳🇴' },
  { code: 'DKK', name: 'Danish Krone', symbol: 'kr', flag: '🇩🇰' },
  { code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK$', flag: '🇭🇰' },
  { code: 'TRY', name: 'Turkish Lira', symbol: '₺', flag: '🇹🇷' },
  { code: 'RUB', name: 'Russian Ruble', symbol: '₽', flag: '🇷🇺' },
  { code: 'MXN', name: 'Mexican Peso', symbol: 'Mex$', flag: '🇲🇽' },
  { code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp', flag: '🇮🇩' },
  { code: 'PHP', name: 'Philippine Peso', symbol: '₱', flag: '🇵🇭' },
  { code: 'VND', name: 'Vietnamese Dong', symbol: '₫', flag: '🇻🇳' },
  { code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', flag: '🇪🇬' },
  { code: 'PKR', name: 'Pakistani Rupee', symbol: '₨', flag: '🇵🇰' },
  { code: 'BDT', name: 'Bangladeshi Taka', symbol: '৳', flag: '🇧🇩' },
  { code: 'LKR', name: 'Sri Lankan Rupee', symbol: 'Rs', flag: '🇱🇰' },
  { code: 'NPR', name: 'Nepalese Rupee', symbol: 'रू', flag: '🇳🇵' },
];

// Fallback rates relative to USD (USD = 1.0)
export const DEFAULT_RATES_USD: Record<string, number> = {
  USD: 1.0,
  INR: 86.82,
  EUR: 0.952,
  GBP: 0.794,
  AED: 3.6725,
  JPY: 154.3,
  CAD: 1.412,
  AUD: 1.583,
  SGD: 1.352,
  CHF: 0.908,
  CNY: 7.285,
  SAR: 3.751,
  QAR: 3.641,
  KWD: 0.309,
  BHD: 0.377,
  OMR: 0.385,
  NZD: 1.745,
  THB: 34.6,
  MYR: 4.46,
  KRW: 1442.0,
  BRL: 6.08,
  ZAR: 18.25,
  SEK: 10.82,
  NOK: 11.15,
  DKK: 7.10,
  HKD: 7.78,
  TRY: 35.8,
  RUB: 98.5,
  MXN: 20.4,
  IDR: 16250.0,
  PHP: 58.6,
  VND: 25400.0,
  EGP: 50.4,
  PKR: 278.5,
  BDT: 121.0,
  LKR: 292.0,
  NPR: 138.9,
};

export type RatesStatus = 'live' | 'cached' | 'builtin';

export interface RatesData {
  base: string;
  rates: Record<string, number>;
  timestamp: number;
  lastUpdatedStr: string;
  isLive: boolean;
  /** Where the rates came from. Optional so older callers keep compiling. */
  status?: RatesStatus;
  /** Name of the provider that answered (live rates only). */
  provider?: string;
  /** Why live rates were unavailable (fallback rates only). */
  error?: string;
}

const STORAGE_KEY = 'omni_calc_live_rates_cache';

/** Per-provider timeout. Mobile networks routinely need more than a few seconds. */
export const REQUEST_TIMEOUT_MS = 8000;

/** A provider must return at least this share of POPULAR_CURRENCIES to be trusted. */
const MIN_COVERAGE = 0.9;

interface ParsedProvider {
  rates: Record<string, unknown>;
  /** Epoch ms of the rate itself, when the provider reports one. */
  timestamp?: number;
}

interface Provider {
  name: string;
  url: string;
  parse: (data: any) => ParsedProvider | null;
}

// All providers are free, key-less, USD-based. They are queried in parallel and the first
// valid answer wins, so one slow or dead endpoint can no longer break live rates.
const PROVIDERS: Provider[] = [
  {
    name: 'open.er-api.com',
    url: 'https://open.er-api.com/v6/latest/USD',
    parse: (d) =>
      d && d.result === 'success' && d.rates
        ? {
            rates: d.rates,
            timestamp: d.time_last_update_unix ? d.time_last_update_unix * 1000 : undefined,
          }
        : null,
  },
  {
    name: 'api.exchangerate-api.com',
    url: 'https://api.exchangerate-api.com/v4/latest/USD',
    parse: (d) =>
      d && d.rates
        ? {
            rates: d.rates,
            timestamp: d.time_last_updated ? d.time_last_updated * 1000 : undefined,
          }
        : null,
  },
  {
    name: 'currency-api (jsdelivr)',
    url: 'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
    parse: parseFawazFormat,
  },
  {
    name: 'currency-api (pages.dev)',
    url: 'https://latest.currency-api.pages.dev/v1/currencies/usd.json',
    parse: parseFawazFormat,
  },
];

// Shape: { date: "YYYY-MM-DD", usd: { inr: 83.2, eur: 0.92, ... } } with lower-case codes.
function parseFawazFormat(d: any): ParsedProvider | null {
  const usd = d && d.usd;
  if (!usd || typeof usd !== 'object') return null;
  const rates: Record<string, unknown> = {};
  for (const [code, value] of Object.entries(usd)) rates[code.toUpperCase()] = value;
  return { rates };
}

/** Keep only finite positive numbers and reject answers that are clearly incomplete or wrong. */
function sanitizeRates(raw: Record<string, unknown>): Record<string, number> | null {
  const out: Record<string, number> = {};
  for (const [code, value] of Object.entries(raw)) {
    const n = typeof value === 'number' ? value : Number(value);
    if (Number.isFinite(n) && n > 0) out[code.toUpperCase()] = n;
  }
  if (out.USD === undefined) out.USD = 1;
  if (Math.abs(out.USD - 1) > 0.001) return null; // not USD-based
  const present = POPULAR_CURRENCIES.filter((c) => c.code in out).length;
  if (present < POPULAR_CURRENCIES.length * MIN_COVERAGE) return null;
  return out;
}

function formatStamp(ts: number): string {
  const d = new Date(ts);
  const time = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  if (d.toDateString() === new Date().toDateString()) return time;
  return `${d.toLocaleDateString([], { day: 'numeric', month: 'short' })}, ${time}`;
}

async function fetchFromProvider(
  provider: Provider,
  outerSignal: AbortSignal,
  timeoutMs: number
): Promise<{ rates: Record<string, number>; timestamp: number; provider: string }> {
  const controller = new AbortController();
  const onOuterAbort = () => controller.abort();
  outerSignal.addEventListener('abort', onOuterAbort);

  let timer: ReturnType<typeof setTimeout> | undefined;
  // Race against a timer as well as aborting the request, so a runtime that ignores
  // AbortSignal (some native fetch shims do) still cannot hang forever.
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      reject(new Error('timeout'));
    }, timeoutMs);
  });

  try {
    const work = (async () => {
      const res = await fetch(provider.url, { signal: controller.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const parsed = provider.parse(await res.json());
      if (!parsed) throw new Error('unexpected response shape');
      const rates = sanitizeRates(parsed.rates);
      if (!rates) throw new Error('incomplete or invalid rates');
      return { rates, timestamp: parsed.timestamp ?? Date.now(), provider: provider.name };
    })();
    work.catch(() => {}); // avoid an unhandled rejection if the timeout wins the race
    return await Promise.race([work, timeout]);
  } finally {
    if (timer) clearTimeout(timer);
    outerSignal.removeEventListener('abort', onOuterAbort);
  }
}

type ProviderResult = Awaited<ReturnType<typeof fetchFromProvider>>;

/** Query every provider at once; resolve with the first valid answer, or all the errors. */
function raceProviders(timeoutMs: number): Promise<{ result?: ProviderResult; errors: string[] }> {
  const outer = new AbortController();
  const errors: string[] = [];
  return new Promise((resolve) => {
    let pending = PROVIDERS.length;
    let settled = false;
    for (const provider of PROVIDERS) {
      fetchFromProvider(provider, outer.signal, timeoutMs)
        .then((result) => {
          if (settled) return;
          settled = true;
          outer.abort(); // cancel the slower providers
          resolve({ result, errors });
        })
        .catch((e) => {
          if (!settled) errors.push(`${provider.name}: ${e instanceof Error ? e.message : String(e)}`);
        })
        .finally(() => {
          pending -= 1;
          if (pending === 0 && !settled) {
            settled = true;
            resolve({ errors });
          }
        });
    }
  });
}

function getCachedOrFallback(error?: string): RatesData {
  try {
    const cached = localStorage.getItem(STORAGE_KEY);
    if (cached) {
      const parsed = JSON.parse(cached) as RatesData;
      if (parsed && parsed.rates && typeof parsed.rates === 'object') {
        return {
          ...parsed,
          lastUpdatedStr: parsed.timestamp ? `Cached (${formatStamp(parsed.timestamp)})` : 'Cached',
          isLive: false,
          status: 'cached',
          provider: undefined,
          error,
        };
      }
    }
  } catch {
    // ignore corrupt or unavailable storage
  }

  return {
    base: 'USD',
    rates: DEFAULT_RATES_USD,
    timestamp: Date.now(),
    lastUpdatedStr: 'Built-in rates (offline)',
    isLive: false,
    status: 'builtin',
    error,
  };
}

export async function fetchLiveExchangeRates(timeoutMs: number = REQUEST_TIMEOUT_MS): Promise<RatesData> {
  // Deliberately NOT short-circuiting on navigator.onLine: it can report false on some
  // mobile WebViews even when the network works, which would pin the app to fallback rates.
  // Every request is time-limited, so trying while genuinely offline only costs a moment.
  const { result, errors } = await raceProviders(timeoutMs);

  if (result) {
    const ratesData: RatesData = {
      base: 'USD',
      rates: { ...DEFAULT_RATES_USD, ...result.rates },
      timestamp: result.timestamp,
      lastUpdatedStr: formatStamp(result.timestamp),
      isLive: true,
      status: 'live',
      provider: result.provider,
    };
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(ratesData));
    } catch {
      // ignore storage error
    }
    return ratesData;
  }

  return getCachedOrFallback(errors.join('; ') || 'no provider responded');
}

/**
 * Convert an amount from one currency to another using USD-based rates.
 */
export function convertCurrency(
  amount: number,
  fromCode: string,
  toCode: string,
  rates: Record<string, number>
): { result: number; rate: number; inverseRate: number } {
  if (isNaN(amount) || amount === 0) {
    return { result: 0, rate: 0, inverseRate: 0 };
  }

  const fromRateUSD = rates[fromCode] ?? DEFAULT_RATES_USD[fromCode] ?? 1.0;
  const toRateUSD = rates[toCode] ?? DEFAULT_RATES_USD[toCode] ?? 1.0;

  // Amount in USD = amount / fromRateUSD
  // Target amount = amountInUSD * toRateUSD
  const directRate = toRateUSD / fromRateUSD;
  const inverseRate = fromRateUSD / toRateUSD;
  const result = amount * directRate;

  return {
    result,
    rate: directRate,
    inverseRate,
  };
}
