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

export interface RatesData {
  base: string;
  rates: Record<string, number>;
  timestamp: number;
  lastUpdatedStr: string;
  isLive: boolean;
}

const STORAGE_KEY = 'omni_calc_live_rates_cache';

export async function fetchLiveExchangeRates(): Promise<RatesData> {
  const getCachedOrFallback = (): RatesData => {
    try {
      const cached = localStorage.getItem(STORAGE_KEY);
      if (cached) {
        const parsed = JSON.parse(cached) as RatesData;
        const timeAgo = parsed.timestamp ? new Date(parsed.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'Offline';
        return {
          ...parsed,
          lastUpdatedStr: `Cached (${timeAgo})`,
          isLive: false,
        };
      }
    } catch {
      // ignore
    }

    return {
      base: 'USD',
      rates: DEFAULT_RATES_USD,
      timestamp: Date.now(),
      lastUpdatedStr: 'Offline rates',
      isLive: false,
    };
  };

  // If navigator is explicitly offline, skip network instantly
  if (typeof navigator !== 'undefined' && 'onLine' in navigator && !navigator.onLine) {
    return getCachedOrFallback();
  }

  // Try Open Exchange Rates public endpoint (USD base) with 3.5s timeout
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3500);

    const res = await fetch('https://open.er-api.com/v6/latest/USD', {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    }).finally(() => clearTimeout(timeoutId));

    if (res.ok) {
      const data = await res.json();
      if (data && data.rates && data.result === 'success') {
        const ratesData: RatesData = {
          base: 'USD',
          rates: { ...DEFAULT_RATES_USD, ...data.rates },
          timestamp: data.time_last_update_unix ? data.time_last_update_unix * 1000 : Date.now(),
          lastUpdatedStr: new Date(
            data.time_last_update_unix ? data.time_last_update_unix * 1000 : Date.now()
          ).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          isLive: true,
        };
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(ratesData));
        } catch {
          // ignore storage error
        }
        return ratesData;
      }
    }
  } catch {
    // Offline, timeout, or network blocked
  }

  // Backup free API with 3.5s timeout
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3500);

    const res2 = await fetch('https://api.exchangerate-api.com/v4/latest/USD', {
      signal: controller.signal,
    }).finally(() => clearTimeout(timeoutId));

    if (res2.ok) {
      const data2 = await res2.json();
      if (data2 && data2.rates) {
        const ratesData: RatesData = {
          base: 'USD',
          rates: { ...DEFAULT_RATES_USD, ...data2.rates },
          timestamp: Date.now(),
          lastUpdatedStr: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          isLive: true,
        };
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(ratesData));
        } catch {
          // ignore
        }
        return ratesData;
      }
    }
  } catch {
    // Backup failed
  }

  // Graceful offline fallback to last-known cached or default rates
  return getCachedOrFallback();
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
