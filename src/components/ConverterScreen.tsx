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
    <div className="w-full max-w-5xl xl:max-w-6xl mx-auto flex flex-col items-center select-none pb-6">
      <SwipeableTabContainer
        tabs={categoryTabs}
        activeTabId={selectedCategoryId}
        onSelectTab={handleSelectCategory}
        showNavButtons={true}
      >
        <div className="w-full flex flex-col gap-5 pt-2">
          {/* Responsive Dual Column for Tablets / Stacked for Mobile */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-5 items-stretch relative">
            {/* =========================================================================
                INPUT CARD (Adaptive M3 surface container)
               ========================================================================= */}
            <div
              className="rounded-2xl border p-4 sm:p-5 flex flex-col justify-between transition-all"
              style={{
                backgroundColor: 'var(--m3-surface-container-low)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <label
                    className="block text-xs font-semibold tracking-wider uppercase"
                    style={{ color: 'var(--m3-on-surface-variant)' }}
                  >
                    From Unit
                  </label>
                  <select
                    value={fromUnitId}
                    onChange={(e) => {
                      playSound('toggle');
                      setFromUnitId(e.target.value);
                    }}
                    className="border text-xs font-medium rounded-xl px-2.5 py-1.5 focus:outline-none cursor-pointer"
                    style={{
                      backgroundColor: 'var(--m3-surface-container-high)',
                      borderColor: 'var(--m3-outline-variant)',
                      color: 'var(--m3-on-surface)',
                    }}
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
                    className="w-full bg-transparent text-3xl sm:text-4xl font-light outline-none font-mono pr-8 placeholder:opacity-30"
                    style={{ color: 'var(--m3-on-surface)' }}
                  />
                  {inputValue && (
                    <button
                      type="button"
                      onClick={() => {
                        playSound('clear');
                        setInputValue('');
                      }}
                      className="absolute right-0 top-1/2 -translate-y-1/2 p-2 hover:opacity-100 transition-opacity cursor-pointer"
                      style={{ color: 'var(--m3-on-surface-variant)' }}
                      title="Clear input"
                    >
                      <RotateCcw className="w-4 h-4" />
                    </button>
                  )}
                </div>

                <div className="text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  {fromUnitObj.name} ({fromUnitObj.symbol})
                </div>
              </div>

              {/* Value Presets */}
              <div
                className="flex flex-wrap items-center gap-2 pt-3 mt-4 border-t"
                style={{ borderColor: 'var(--m3-outline-variant)' }}
              >
                <span className="text-[11px] font-medium mr-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Presets:
                </span>
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
                      className="px-3 py-1.5 text-xs font-medium rounded-xl border transition-all cursor-pointer active:scale-95"
                      style={{
                        backgroundColor: isActive ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                        borderColor: isActive ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
                        color: isActive ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)',
                        fontWeight: isActive ? 700 : 500,
                      }}
                    >
                      {p}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Desktop / Tablet Swap Button */}
            <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 hidden md:flex z-20">
              <button
                type="button"
                onClick={handleSwap}
                className="p-3 rounded-full border shadow-xl transition-transform active:scale-90 cursor-pointer"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  borderColor: 'var(--m3-outline-variant)',
                  color: 'var(--m3-on-surface)',
                  transform: isSwapping ? 'rotate(180deg) scale(0.92)' : 'rotate(0deg) scale(1)',
                }}
                title="Swap units"
              >
                <ArrowLeftRight className="w-4 h-4" />
              </button>
            </div>

            {/* Mobile Swap Button */}
            <div className="flex md:hidden justify-center -my-2 z-10">
              <button
                type="button"
                onClick={handleSwap}
                className="p-3 rounded-full border shadow-lg transition-transform active:scale-90 cursor-pointer"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  borderColor: 'var(--m3-outline-variant)',
                  color: 'var(--m3-on-surface)',
                  transform: isSwapping ? 'rotate(180deg) scale(0.92)' : 'rotate(0deg) scale(1)',
                }}
                title="Swap units"
              >
                <ArrowLeftRight className="w-4 h-4" />
              </button>
            </div>

            {/* =========================================================================
                RESULTS CARD (Adaptive M3 surface container)
               ========================================================================= */}
            <div
              className="relative rounded-2xl sm:rounded-3xl p-5 sm:p-6 border shadow-2xl overflow-hidden backdrop-blur-xl flex flex-col justify-between transition-colors"
              style={{
                backgroundColor: 'var(--m3-surface-container-low)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              {/* Subtle Ambient Corner Glow */}
              <div
                className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
                style={{ backgroundColor: currentTheme.accent }}
              />

              <div>
                {/* Target Unit Picker */}
                <div className="flex items-center justify-between mb-3">
                  <span
                    className="text-[11px] font-semibold tracking-wider uppercase"
                    style={{ color: 'var(--m3-on-surface-variant)' }}
                  >
                    Converted Value
                  </span>
                  <select
                    value={toUnitId}
                    onChange={(e) => {
                      playSound('toggle');
                      setToUnitId(e.target.value);
                    }}
                    className="border text-xs font-medium rounded-xl px-2.5 py-1.5 focus:outline-none cursor-pointer"
                    style={{
                      backgroundColor: 'var(--m3-surface-container-high)',
                      borderColor: 'var(--m3-outline-variant)',
                      color: 'var(--m3-on-surface)',
                    }}
                  >
                    {activeCategory.units.map((u) => (
                      <option key={u.id} value={u.id}>
                        {u.name} ({u.symbol})
                      </option>
                    ))}
                  </select>
                </div>

                {/* Result Value */}
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div className="text-3xl sm:text-4xl lg:text-5xl font-light tracking-tight font-mono flex items-baseline gap-2 break-all" style={{ color: 'var(--m3-on-surface)' }}>
                    <span>{formattedResult}</span>
                    <span className="text-xl sm:text-2xl font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      {toUnitObj.symbol}
                    </span>
                  </div>

                  <button
                    type="button"
                    onClick={handleCopy}
                    className="p-2.5 rounded-xl border transition-colors cursor-pointer shrink-0 active:scale-95"
                    style={{
                      backgroundColor: 'var(--m3-surface-container-high)',
                      borderColor: 'var(--m3-outline-variant)',
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
              </div>

              {/* Formula / Relation Tag */}
              {conversion.formula && (
                <div
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-mono self-start mt-2"
                  style={{
                    backgroundColor: 'var(--m3-surface-container)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface-variant)',
                  }}
                >
                  <span>Formula:</span>
                  <span style={{ color: 'var(--m3-primary)', fontWeight: 600 }}>{conversion.formula}</span>
                </div>
              )}
            </div>
          </div>

          {/* Other Units in Category Quick Comparison - Tablet Expanded Grid */}
          <div
            className="rounded-2xl sm:rounded-3xl p-5 sm:p-6 border shadow-2xl backdrop-blur-xl transition-colors"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <span
              className="text-xs font-semibold block mb-3 uppercase tracking-wider"
              style={{ color: 'var(--m3-on-surface-variant)' }}
            >
              All Units Comparison for {numericInput} {fromUnitObj.symbol}
            </span>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2.5">
              {activeCategory.units.map((u) => {
                if (u.id === fromUnitId) return null;
                const res = convertUnit(numericInput, activeCategory, fromUnitId, u.id);
                const str =
                  Math.abs(res.result) >= 1e7 || (Math.abs(res.result) <= 1e-4 && res.result !== 0)
                    ? res.result.toExponential(3)
                    : parseFloat(res.result.toPrecision(5)).toString();
                const isSelected = toUnitId === u.id;
                return (
                  <button
                    key={u.id}
                    type="button"
                    onClick={() => setToUnitId(u.id)}
                    className="p-3 rounded-xl border text-left transition-colors cursor-pointer active:scale-95"
                    style={{
                      backgroundColor: isSelected ? 'var(--m3-primary-container)' : 'var(--m3-surface-container)',
                      borderColor: isSelected ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
                      color: isSelected ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface)',
                    }}
                  >
                    <div className="text-[11px] font-mono truncate" style={{ color: isSelected ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface-variant)' }}>
                      {u.name}
                    </div>
                    <div className="text-sm font-mono font-medium truncate mt-0.5" style={{ color: isSelected ? 'var(--m3-on-primary-container)' : 'var(--m3-on-surface)' }}>
                      {str} <span className="font-normal opacity-75">{u.symbol}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </SwipeableTabContainer>
    </div>
  );
};

export default ConverterScreen;
