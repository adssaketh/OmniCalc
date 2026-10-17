import React, { useState } from 'react';
import { UNIT_CATEGORIES, convertUnit } from '../engine/units';
import { UnitCategory } from '../types';
import { soundFx } from '../utils/audio';
import { useTheme } from '../hooks/useTheme';
import { ArrowLeftRight, Copy, Check, RotateCcw } from 'lucide-react';
import { SwipeableTabContainer, TabItem } from './SwipeableTabContainer';

interface ConverterScreenProps {
  soundEnabled: boolean;
  hapticEnabled: boolean;
  decimalPrecision?: number;
}

export const ConverterScreen: React.FC<ConverterScreenProps> = ({
  soundEnabled,
  hapticEnabled,
}) => {
  const { currentTheme } = useTheme();

  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('length');
  const activeCategory: UnitCategory =
    UNIT_CATEGORIES.find((c: UnitCategory) => c.id === selectedCategoryId) || UNIT_CATEGORIES[0];

  const [fromUnitId, setFromUnitId] = useState<string>(activeCategory.units[0].id);
  const [toUnitId, setToUnitId] = useState<string>(activeCategory.units[1].id);
  const [inputValue, setInputValue] = useState<string>('1');
  const [copied, setCopied] = useState<boolean>(false);
  const [isSwapping, setIsSwapping] = useState<boolean>(false);

  // Audio helper
  const playSound = (type: 'num' | 'op' | 'clear' | 'toggle' = 'num') => {
    if (soundEnabled) soundFx.playClick(type);
    if (hapticEnabled) soundFx.triggerHaptic();
  };

  // Change category
  const handleSelectCategory = (catId: string) => {
    playSound('toggle');
    setSelectedCategoryId(catId);
    const cat = UNIT_CATEGORIES.find((c: UnitCategory) => c.id === catId);
    if (cat && cat.units.length >= 2) {
      setFromUnitId(cat.units[0].id);
      setToUnitId(cat.units[1].id);
    }
  };

  // Swap units
  const handleSwap = () => {
    playSound('op');
    setIsSwapping(true);
    const prevFrom = fromUnitId;
    setFromUnitId(toUnitId);
    setToUnitId(prevFrom);
    setTimeout(() => setIsSwapping(false), 300);
  };

  // Calculation
  const numericInput = parseFloat(inputValue) || 0;
  const conversion = convertUnit(
    numericInput,
    activeCategory,
    fromUnitId,
    toUnitId
  );

  const formattedResult =
    Math.abs(conversion.result) >= 1e9 || (Math.abs(conversion.result) <= 1e-4 && conversion.result !== 0)
      ? conversion.result.toExponential(4)
      : parseFloat(conversion.result.toPrecision(7)).toString();

  // Copy result
  const handleCopy = () => {
    playSound('op');
    navigator.clipboard.writeText(formattedResult);
    setCopied(true);
    setTimeout(() => setCopied(false), 1800);
  };

  const presets = [1, 5, 10, 50, 100];

  const categoryTabs: TabItem[] = UNIT_CATEGORIES.map((c: UnitCategory) => ({
    id: c.id,
    label: c.name,
  }));

  const fromUnitObj = activeCategory.units.find((u) => u.id === fromUnitId) || activeCategory.units[0];
  const toUnitObj = activeCategory.units.find((u) => u.id === toUnitId) || activeCategory.units[1];

  return (
    <div className="w-full max-w-3xl mx-auto flex flex-col items-center select-none pb-6">
      <SwipeableTabContainer
        tabs={categoryTabs}
        activeTabId={selectedCategoryId}
        onSelectTab={handleSelectCategory}
        showNavButtons={true}
      >
        <div className="w-full flex flex-col gap-5 pt-2">
          {/* =========================================================================
              INPUT CARD (Dark card style matching SWP)
             ========================================================================= */}
          <div className="bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-4 transition-all focus-within:border-zinc-700">
            <div className="flex items-center justify-between mb-2">
              <label className="block text-xs font-medium text-zinc-400">
                From Unit
              </label>
              <select
                value={fromUnitId}
                onChange={(e) => {
                  playSound('toggle');
                  setFromUnitId(e.target.value);
                }}
                className="bg-zinc-800 border border-zinc-700 text-xs font-medium rounded-xl px-2.5 py-1 text-white focus:outline-none cursor-pointer"
              >
                {activeCategory.units.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.name} ({u.symbol})
                  </option>
                ))}
              </select>
            </div>

            <div className="relative flex items-center gap-2 mb-2">
              <input
                type="number"
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                placeholder="0"
                className="w-full bg-transparent text-2xl sm:text-3xl font-light text-white outline-none font-mono pr-8 placeholder:opacity-30"
              />
              {inputValue && (
                <button
                  type="button"
                  onClick={() => {
                    playSound('clear');
                    setInputValue('');
                  }}
                  className="absolute right-0 top-1/2 -translate-y-1/2 p-1.5 text-zinc-400 hover:text-white transition-colors cursor-pointer"
                  title="Clear input"
                >
                  <RotateCcw className="w-4 h-4" />
                </button>
              )}
            </div>

            <div className="text-xs text-zinc-500 font-mono">
              Unit: {fromUnitObj.name} ({fromUnitObj.symbol})
            </div>

            {/* Value Presets */}
            <div className="flex flex-wrap gap-2 pt-2.5 mt-2 border-t border-zinc-800/60">
              {presets.map((p) => {
                const isActive = inputValue === p.toString();
                return (
                  <button
                    key={p}
                    type="button"
                    onClick={() => {
                      playSound('num');
                      setInputValue(p.toString());
                    }}
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
                    {p}
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
              style={{
                transform: isSwapping ? 'rotate(180deg) scale(0.92)' : 'rotate(0deg) scale(1)',
              }}
              title="Swap units"
            >
              <ArrowLeftRight className="w-4 h-4" />
            </button>
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

            {/* Target Unit Picker */}
            <div className="flex items-center justify-between mb-4">
              <span className="text-[11px] font-semibold tracking-wider text-zinc-400 uppercase">
                Converted Value
              </span>
              <select
                value={toUnitId}
                onChange={(e) => {
                  playSound('toggle');
                  setToUnitId(e.target.value);
                }}
                className="bg-zinc-800 border border-zinc-700 text-xs font-medium rounded-xl px-2.5 py-1 text-white focus:outline-none cursor-pointer"
              >
                {activeCategory.units.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.name} ({u.symbol})
                  </option>
                ))}
              </select>
            </div>

            {/* Result Value */}
            <div className="flex items-start justify-between gap-3 mb-4">
              <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight text-white font-mono flex items-baseline gap-2 break-all">
                <span>{formattedResult}</span>
                <span className="text-xl sm:text-2xl text-zinc-400 font-sans">
                  {toUnitObj.symbol}
                </span>
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

            {/* Formula / Relation Tag */}
            {conversion.formula && (
              <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-900/80 border border-zinc-800 text-xs font-mono text-zinc-400">
                <span>Formula:</span>
                <span style={{ color: currentTheme.accent }}>{conversion.formula}</span>
              </div>
            )}

            {/* Other Units in Category Quick Comparison */}
            <div className="mt-5 pt-4 border-t border-zinc-800/80">
              <span className="text-xs font-semibold text-zinc-400 block mb-2.5">
                All Units Comparison ({numericInput} {fromUnitObj.symbol})
              </span>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {activeCategory.units.map((u) => {
                  if (u.id === fromUnitId) return null;
                  const res = convertUnit(numericInput, activeCategory, fromUnitId, u.id);
                  const str =
                    Math.abs(res.result) >= 1e7 || (Math.abs(res.result) <= 1e-4 && res.result !== 0)
                      ? res.result.toExponential(3)
                      : parseFloat(res.result.toPrecision(5)).toString();
                  return (
                    <button
                      key={u.id}
                      type="button"
                      onClick={() => setToUnitId(u.id)}
                      className={`p-2.5 rounded-xl border text-left transition-colors cursor-pointer ${
                        toUnitId === u.id
                          ? 'bg-zinc-800/90 border-zinc-600'
                          : 'bg-zinc-900/60 hover:bg-zinc-900 border-zinc-800/80'
                      }`}
                      style={toUnitId === u.id ? { borderColor: currentTheme.accent } : {}}
                    >
                      <div className="text-[10px] text-zinc-500 font-mono">{u.name}</div>
                      <div className="text-xs font-mono font-medium text-white truncate">
                        {str} <span className="text-zinc-400 font-normal">{u.symbol}</span>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      </SwipeableTabContainer>
    </div>
  );
};

export default ConverterScreen;
