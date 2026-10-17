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

  const loadRates = useCallback(async () => {
    setIsRefreshing(true);
    try {
      const live = await fetchLiveExchangeRates();
      setRatesData(live);
    } catch {
      // ignore
    } finally {
      setIsRefreshing(false);
    }
  }, []);

  useEffect(() => {
    loadRates();
  }, [loadRates]);

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
    <div className={`w-full max-w-3xl mx-auto flex flex-col gap-6 select-none ${className}`}>
      {/* Live Status Bar */}
      <div className="flex flex-wrap items-center justify-between gap-2.5 pb-2 border-b border-zinc-800/80">
        <div className="flex items-center gap-2">
          <span className="relative flex h-2.5 w-2.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
          </span>
          <span className="text-xs font-semibold tracking-wide uppercase text-zinc-300">
            {ratesData.isLive ? 'Live Forex Exchange Rates' : 'Forex Rates (Cached)'}
          </span>
          <span className="text-[11px] text-zinc-500">
            • Updated {ratesData.lastUpdatedStr}
          </span>
        </div>

        <button
          type="button"
          onClick={loadRates}
          disabled={isRefreshing}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium bg-zinc-900 border border-zinc-800 text-zinc-300 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-50 cursor-pointer"
          title="Fetch latest forex exchange rates"
        >
          <RefreshCw
            className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`}
            style={{ color: currentTheme.accent }}
          />
          <span>{isRefreshing ? 'Updating...' : 'Refresh Rates'}</span>
        </button>
      </div>

      {/* =========================================================================
          INPUTS & SELECTION (Dark card style matching SWP)
         ========================================================================= */}
      <div className="flex flex-col gap-4">
        {/* From Currency Input Card */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
          <div className="flex items-center justify-between mb-2">
            <label className="block text-xs font-medium text-zinc-400">
              From Currency & Amount
            </label>
            <select
              value={currencyFrom}
              onChange={(e) => setCurrencyFrom(e.target.value)}
              className="bg-zinc-800 border border-zinc-700 text-xs font-medium rounded-xl px-2.5 py-1 text-white focus:outline-none cursor-pointer"
            >
              {POPULAR_CURRENCIES.map((c) => (
                <option key={c.code} value={c.code}>
                  {c.flag} {c.code} - {c.name}
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-2 mb-2">
            <span className="text-2xl font-light text-zinc-400">{fromCurrObj.symbol}</span>
            <input
              type="number"
              step="any"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono"
              placeholder="100"
            />
          </div>

          <div className="text-xs text-zinc-500 font-mono">
            {fromCurrObj.flag} {fromCurrObj.name} ({fromCurrObj.code})
          </div>

          {/* Quick Presets */}
          <div className="flex flex-wrap gap-2 pt-2.5 mt-2 border-t border-zinc-800/60">
            {presets.map((val) => {
              const isActive = amount === val.toString();
              return (
                <button
                  key={val}
                  type="button"
                  onClick={() => setAmount(val.toString())}
                  className={`px-3 py-1.5 text-xs font-medium rounded-xl transition-all cursor-pointer ${
                    isActive
                      ? 'bg-zinc-800 text-white border border-zinc-600 shadow-sm'
                      : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/60 border border-zinc-800'
                  }`}
                  style={
                    isActive
                      ? { borderColor: currentTheme.accent, color: currentTheme.accent }
                      : {}
                  }
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
            className="p-3 rounded-full bg-zinc-800 border border-zinc-700 text-zinc-200 hover:text-white hover:bg-zinc-700 shadow-lg transition-transform active:scale-90 cursor-pointer"
            aria-label="Swap currencies"
            title="Swap currencies"
          >
            <ArrowLeftRight className="w-4 h-4" />
          </button>
        </div>

        {/* To Currency Selection */}
        <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all">
          <div className="flex items-center justify-between mb-2">
            <label className="block text-xs font-medium text-zinc-400">
              Target Currency
            </label>
            <select
              value={currencyTo}
              onChange={(e) => setCurrencyTo(e.target.value)}
              className="bg-zinc-800 border border-zinc-700 text-xs font-medium rounded-xl px-2.5 py-1 text-white focus:outline-none cursor-pointer"
            >
              {POPULAR_CURRENCIES.map((c) => (
                <option key={c.code} value={c.code}>
                  {c.flag} {c.code} - {c.name}
                </option>
              ))}
            </select>
          </div>
          <div className="text-xs text-zinc-500 font-mono">
            {toCurrObj.flag} {toCurrObj.name} ({toCurrObj.code})
          </div>
        </div>
      </div>

      {/* =========================================================================
          RESULTS CARD (bg-zinc-950/80, rounded-3xl, corner glow, ratio bar, etc.)
         ========================================================================= */}
      <div className="relative bg-zinc-950/80 rounded-3xl p-5 sm:p-6 border border-zinc-800/90 shadow-2xl overflow-hidden backdrop-blur-xl">
        {/* Subtle Ambient Corner Glow */}
        <div
          className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
          style={{ backgroundColor: currentTheme.accent }}
        />

        {/* Converted Amount Metric */}
        <div className="flex items-start justify-between gap-3 mb-5">
          <div className="flex flex-col">
            <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase mb-1">
              Converted Amount ({currencyTo})
            </span>
            <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-1 break-all">
              <span className="text-2xl sm:text-3xl text-zinc-400 font-normal">{toCurrObj.symbol}</span>
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
            className="p-2.5 rounded-xl bg-zinc-900 border border-zinc-800 text-zinc-300 hover:text-white transition-colors cursor-pointer shrink-0"
            title="Copy converted value"
          >
            {copied ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
          </button>
        </div>

        {/* Live Conversion Rate Badges */}
        <div className="flex flex-wrap gap-2 text-xs font-mono mb-5">
          <span
            className="px-3 py-1 rounded-xl border"
            style={{
              backgroundColor: `rgba(${currentTheme.accentRgb}, 0.1)`,
              borderColor: `rgba(${currentTheme.accentRgb}, 0.3)`,
              color: currentTheme.accent,
            }}
          >
            1 {currencyFrom} = {conversion.rate.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {currencyTo}
          </span>
          <span className="px-3 py-1 rounded-xl bg-zinc-900 border border-zinc-800 text-zinc-400">
            1 {currencyTo} = {conversion.inverseRate.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })} {currencyFrom}
          </span>
        </div>

        {/* Multi-Currency Comparison Grid */}
        <div className="pt-4 border-t border-zinc-800/80">
          <div className="flex items-center gap-1.5 text-xs font-semibold text-zinc-300 mb-3">
            <TrendingUp className="w-3.5 h-3.5" style={{ color: currentTheme.accent }} />
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
                  className="bg-zinc-900/60 hover:bg-zinc-900 p-3 rounded-2xl border border-zinc-800/80 flex flex-col items-start gap-1 transition-colors cursor-pointer text-left group"
                >
                  <div className="flex items-center justify-between w-full text-xs text-zinc-400">
                    <span>{targetObj.flag} {code}</span>
                    <span className="text-[10px] text-zinc-500 font-mono">1 {currencyFrom} = {converted.rate.toFixed(2)}</span>
                  </div>
                  <div className="font-mono font-medium text-white text-sm group-hover:text-emerald-400 transition-colors">
                    {targetObj.symbol} {converted.result.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
