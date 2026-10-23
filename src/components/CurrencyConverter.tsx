import React, { useState, useEffect, useCallback } from 'react';
import {
  POPULAR_CURRENCIES,
  fetchLiveExchangeRates,
  convertCurrency,
  RatesData,
  DEFAULT_RATES_USD,
} from '../engine/currency';
import { useTheme } from '../hooks/useTheme';
import { ArrowLeftRight, Copy, Check, RefreshCw, TrendingUp } from 'lucide-react';

interface CurrencyConverterProps {
  className?: string;
}

export const CurrencyConverter: React.FC<CurrencyConverterProps> = ({ className = '' }) => {
  const { currentTheme } = useTheme();

  const [ratesData, setRatesData] = useState<RatesData>({
    base: 'USD',
    rates: DEFAULT_RATES_USD,
    timestamp: Date.now(),
    lastUpdatedStr: 'Loading...',
    isLive: false,
  });
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);
  const [currencyFrom, setCurrencyFrom] = useState<string>('USD');
  const [currencyTo, setCurrencyTo] = useState<string>('INR');
  const [amount, setAmount] = useState<string>('100');
  const [copied, setCopied] = useState<boolean>(false);
  const [hasLoaded, setHasLoaded] = useState<boolean>(false);

  const loadRates = useCallback(async () => {
    setIsRefreshing(true);
    try {
      const live = await fetchLiveExchangeRates();
      setRatesData(live);
    } catch {
      // ignore
    } finally {
      setIsRefreshing(false);
      setHasLoaded(true);
    }
  }, []);

  useEffect(() => {
    loadRates();
  }, [loadRates]);

  // Retry automatically when the device regains connectivity.
  useEffect(() => {
    window.addEventListener('online', loadRates);
    return () => window.removeEventListener('online', loadRates);
  }, [loadRates]);

  const statusColor = ratesData.isLive
    ? currentTheme.isDark ? '#34d399' : '#047857'
    : currentTheme.isDark ? '#fbbf24' : '#b45309';

  const handleSwap = () => {
    const prevFrom = currencyFrom;
    setCurrencyFrom(currencyTo);
    setCurrencyTo(prevFrom);
  };

  const parsedAmount = parseFloat(amount) || 0;
  const conversion = convertCurrency(
    parsedAmount,
    currencyFrom,
    currencyTo,
    ratesData.rates
  );

  const fromCurrObj = POPULAR_CURRENCIES.find((c) => c.code === currencyFrom) || {
    code: currencyFrom,
    name: currencyFrom,
    symbol: currencyFrom,
    flag: '🌐',
  };

  const toCurrObj = POPULAR_CURRENCIES.find((c) => c.code === currencyTo) || {
    code: currencyTo,
    name: currencyTo,
    symbol: currencyTo,
    flag: '🌐',
  };

  const handleCopy = () => {
    const txt = `${parsedAmount} ${currencyFrom} = ${conversion.result.toLocaleString(
      undefined,
      { minimumFractionDigits: 2, maximumFractionDigits: 4 }
    )} ${currencyTo}`;
    navigator.clipboard.writeText(txt);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const presets = [10, 50, 100, 500, 1000, 5000];
  const comparisonCodes = ['EUR', 'GBP', 'JPY', 'AED', 'SGD', 'CAD'];

  return (
    <div className={`w-full max-w-5xl xl:max-w-6xl mx-auto select-none ${className}`}>
      {/* Live Status Bar */}
      <div
        className="flex flex-wrap items-center justify-between gap-2.5 pb-2 border-b mb-5"
        style={{ borderColor: 'var(--m3-outline-variant)' }}
      >
        <div className="flex items-center gap-2">
          <span className="relative flex h-2.5 w-2.5">
            <span
              className={`${ratesData.isLive ? 'animate-ping ' : ''}absolute inline-flex h-full w-full rounded-full opacity-75`}
              style={{ backgroundColor: statusColor }}
            />
            <span
              className="relative inline-flex rounded-full h-2.5 w-2.5"
              style={{ backgroundColor: statusColor }}
            />
          </span>
          <span className="text-xs font-semibold tracking-wide uppercase" style={{ color: 'var(--m3-on-surface)' }}>
            {ratesData.isLive
              ? 'Live Forex Exchange Rates'
              : ratesData.status === 'builtin'
                ? 'Forex Rates (Built-in)'
                : 'Forex Rates (Cached)'}
          </span>
          <span className="text-[11px]" style={{ color: 'var(--m3-on-surface-variant)' }}>
            • Updated {ratesData.lastUpdatedStr}
          </span>
        </div>

        <button
          type="button"
          onClick={loadRates}
          disabled={isRefreshing}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium transition-colors disabled:opacity-50 cursor-pointer active:scale-95"
          style={{
            backgroundColor: 'var(--m3-surface-container)',
            color: 'var(--m3-on-surface)',
          }}
          title="Fetch latest forex exchange rates"
        >
          <RefreshCw
            className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`}
            style={{ color: 'var(--m3-primary)' }}
          />
          <span>{isRefreshing ? 'Updating...' : 'Refresh Rates'}</span>
        </button>
      </div>

      {hasLoaded && !isRefreshing && !ratesData.isLive && (
        <div
          role="status"
          className="mb-5 px-3 py-2 rounded-xl text-xs"
          style={{
            backgroundColor: 'var(--m3-surface-container)',
            color: 'var(--m3-on-surface)',
          }}
          title={ratesData.error}
        >
          Couldn't reach a live rate provider, so these are{' '}
          {ratesData.status === 'cached' ? 'your last saved rates' : 'built-in approximate rates'}.
          Check your connection and tap Refresh Rates.
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-12 gap-5 sm:gap-6 items-start">
        {/* =========================================================================
            INPUTS & SELECTION (md:col-span-6)
           ========================================================================= */}
        <div className="md:col-span-6 flex flex-col gap-4">
        {/* From Currency Input Card */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-2">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              From Currency & Amount
            </label>
            <select
              value={currencyFrom}
              onChange={(e) => setCurrencyFrom(e.target.value)}
              className=" text-xs font-medium rounded-xl px-2.5 py-1 focus:outline-none cursor-pointer"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                color: 'var(--m3-on-surface)',
              }}
            >
              {POPULAR_CURRENCIES.map((c) => (
                <option key={c.code} value={c.code}>
                  {c.flag} {c.code} - {c.name}
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-2 mb-2">
            <span className="text-2xl font-light" style={{ color: 'var(--m3-on-surface-variant)' }}>{fromCurrObj.symbol}</span>
            <input
              type="number"
              step="any"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light outline-none font-mono"
              style={{ color: 'var(--m3-on-surface)' }}
              placeholder="100"
            />
          </div>

          <div className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
            {fromCurrObj.flag} {fromCurrObj.name} ({fromCurrObj.code})
          </div>

          {/* Quick Presets */}
          <div
            className="flex flex-wrap gap-2 pt-2.5 mt-2 border-t"
            style={{ borderColor: 'var(--m3-outline-variant)' }}
          >
            {presets.map((val) => {
              const isActive = amount === val.toString();
              return (
                <button
                  key={val}
                  type="button"
                  onClick={() => setAmount(val.toString())}
                  className="px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer active:scale-95"
                  style={{
                    backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                    color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {val.toLocaleString()}
                </button>
              );
            })}
          </div>
        </div>

        {/* Swap Button */}
        <div className="flex justify-center -my-2 z-10">
          <button
            type="button"
            onClick={handleSwap}
            className="p-3 rounded-full transition-transform active:scale-90 cursor-pointer"
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
            aria-label="Swap currencies"
            title="Swap currencies"
          >
            <ArrowLeftRight className="w-4 h-4" />
          </button>
        </div>

        {/* To Currency Selection */}
        <div
          className="rounded-2xl p-4 transition-all"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          <div className="flex items-center justify-between mb-2">
            <label className="block text-xs font-medium" style={{ color: 'var(--m3-on-surface-variant)' }}>
              Target Currency
            </label>
            <select
              value={currencyTo}
              onChange={(e) => setCurrencyTo(e.target.value)}
              className=" text-xs font-medium rounded-xl px-2.5 py-1 focus:outline-none cursor-pointer"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                color: 'var(--m3-on-surface)',
              }}
            >
              {POPULAR_CURRENCIES.map((c) => (
                <option key={c.code} value={c.code}>
                  {c.flag} {c.code} - {c.name}
                </option>
              ))}
            </select>
          </div>
          <div className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
            {toCurrObj.flag} {toCurrObj.name} ({toCurrObj.code})
          </div>
        </div>
      </div>

      {/* =========================================================================
          RESULTS CARD (md:col-span-6 sticky on tablet)
         ========================================================================= */}
      <div className="md:col-span-6 flex flex-col gap-4 sticky md:top-4">
        <div
          className="relative rounded-3xl p-5 sm:p-6 overflow-hidden transition-colors"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
        {/* Converted Amount Metric */}
        <div className="flex items-start justify-between gap-3 mb-5">
          <div className="flex flex-col">
            <span
              className="text-[11px] font-semibold tracking-wider uppercase mb-1"
              style={{ color: 'var(--m3-on-surface-variant)' }}
            >
              Converted Amount ({currencyTo})
            </span>
            <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-1 break-all" style={{ color: 'var(--m3-on-surface)' }}>
              <span className="text-2xl sm:text-3xl font-normal" style={{ color: 'var(--m3-on-surface-variant)' }}>{toCurrObj.symbol}</span>
              <span>
                {conversion.result.toLocaleString(undefined, {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 4,
                })}
              </span>
            </div>
          </div>

          <button
            type="button"
            onClick={handleCopy}
            className="p-2.5 rounded-xl transition-colors cursor-pointer shrink-0 active:scale-95"
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
            title="Copy converted value"
          >
            {copied ? (
              <Check className="w-4 h-4" style={{ color: currentTheme.isDark ? '#34d399' : '#047857' }} />
            ) : (
              <Copy className="w-4 h-4" />
            )}
          </button>
        </div>

        {/* Live Conversion Rate Badges */}
        <div className="flex flex-wrap gap-2 text-xs font-mono mb-5">
          <span
            className="px-3 py-1 rounded-xl "
            style={{
              backgroundColor: 'var(--m3-primary-container)',
              color: 'var(--m3-on-primary-container)',
              fontWeight: 600,
            }}
          >
            1 {currencyFrom} = {conversion.rate.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {currencyTo}
          </span>
          <span
            className="px-3 py-1 rounded-xl "
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              color: 'var(--m3-on-surface-variant)',
            }}
          >
            1 {currencyTo} = {conversion.inverseRate.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {currencyFrom}
          </span>
        </div>

        {/* Multi-Currency Comparison Grid */}
        <div
          className="pt-4 border-t"
          style={{ borderColor: 'var(--m3-outline-variant)' }}
        >
          <div className="flex items-center gap-1.5 text-xs font-semibold mb-3" style={{ color: 'var(--m3-on-surface)' }}>
            <TrendingUp className="w-3.5 h-3.5" style={{ color: 'var(--m3-primary)' }} />
            <span>Quick Conversion Watchlist for {parsedAmount.toLocaleString()} {currencyFrom}</span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
            {comparisonCodes.map((code) => {
              const targetObj = POPULAR_CURRENCIES.find((c) => c.code === code) || {
                code,
                name: code,
                symbol: code,
                flag: '🌐',
              };
              const converted = convertCurrency(
                parsedAmount,
                currencyFrom,
                code,
                ratesData.rates
              );
              return (
                <button
                  key={code}
                  type="button"
                  onClick={() => setCurrencyTo(code)}
                  className="p-3 rounded-2xl flex flex-col items-start gap-1 transition-colors cursor-pointer text-left group active:scale-95"
                  style={{
                    backgroundColor: 'var(--m3-surface-container)',
                  }}
                >
                  <div className="flex items-center justify-between w-full text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    <span>{targetObj.flag} {code}</span>
                    <span className="text-[10px] font-mono opacity-80">1 {currencyFrom} = {converted.rate.toFixed(2)}</span>
                  </div>
                  <div className="font-mono font-medium text-sm transition-colors" style={{ color: 'var(--m3-on-surface)' }}>
                    {targetObj.symbol} {converted.result.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </div>
                </button>
              );
            })}
          </div>
        </div>
        </div>
      </div>
    </div>
  </div>
);
};
