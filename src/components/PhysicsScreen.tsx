import React, { useState } from 'react';
import { PHYSICAL_CONSTANTS, PhysicalConstant, PhysicsSolver } from '../engine/physics';
import { soundFx } from '../utils/audio';
import { useTheme } from '../hooks/useTheme';
import { Search, Copy, Check, CornerDownLeft, Atom, Sparkles, Orbit, Zap, Compass, Flame } from 'lucide-react';
import { SwipeableTabContainer, TabItem } from './SwipeableTabContainer';

interface PhysicsScreenProps {
  soundEnabled: boolean;
  hapticEnabled: boolean;
  onInsertToCalculator: (val: string) => void;
}

type PhysicsTab = 'constants' | 'projectile' | 'relativity' | 'quantum' | 'em';

export const PhysicsScreen: React.FC<PhysicsScreenProps> = ({
  soundEnabled,
  hapticEnabled,
  onInsertToCalculator,
}) => {
  const { currentTheme } = useTheme();
  const [activeTab, setActiveTab] = useState<PhysicsTab>('constants');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const playSound = (type: 'num' | 'op' | 'toggle' = 'num') => {
    if (soundEnabled) soundFx.playClick(type);
    if (hapticEnabled) soundFx.triggerHaptic();
  };

  // 1. Projectile Motion State
  const [projV0, setProjV0] = useState<number>(30); // m/s
  const [projAngle, setProjAngle] = useState<number>(45); // deg
  const [projH0, setProjH0] = useState<number>(0); // m
  const [projG, setProjG] = useState<number>(9.80665); // m/s²

  // 2. Relativity State
  const [relBeta, setRelBeta] = useState<number>(0.8); // fraction of c
  const [relT0, setRelT0] = useState<number>(10); // s
  const [relL0, setRelL0] = useState<number>(100); // m
  const [relM0, setRelM0] = useState<number>(1); // kg

  // 3. Quantum / Wave State
  const [quantumMode, setQuantumMode] = useState<'wavelength' | 'frequency' | 'energyEv'>('wavelength');
  const [quantumInput, setQuantumInput] = useState<number>(550); // nm
  const [quantumPhi, setQuantumPhi] = useState<number>(2.3); // eV (Sodium)

  // 4. Electromagnetism State
  const [emQ1, setEmQ1] = useState<number>(1e-6); // 1 µC
  const [emQ2, setEmQ2] = useState<number>(2e-6); // 2 µC
  const [emDist, setEmDist] = useState<number>(0.05); // 5 cm
  const [emB, setEmB] = useState<number>(0.5); // 0.5 T
  const [emVel, setEmVel] = useState<number>(2e6); // 2e6 m/s

  // Calculations
  const projResult = PhysicsSolver.solveProjectile(projV0, projAngle, projH0, projG);
  const relResult = PhysicsSolver.solveRelativity(relBeta, relT0, relL0, relM0);
  const quantumResult = PhysicsSolver.solvePhotonWave(quantumMode, quantumInput, quantumPhi);
  const emResult = PhysicsSolver.solveElectromagnetism(emQ1, emQ2, emDist, emB, 9.109e-31, emVel);

  // Copy helper
  const handleCopy = (id: string, text: string) => {
    playSound('op');
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 1800);
  };

  // Filter constants
  const categories = ['All', 'Universal', 'Mechanics', 'Electromagnetism', 'Quantum & Atomic', 'Thermodynamics', 'Astrophysics'];

  const filteredConstants = PHYSICAL_CONSTANTS.filter((c) => {
    const matchesCat = selectedCategory === 'All' || c.category === selectedCategory;
    const matchesSearch =
      c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.unit.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCat && matchesSearch;
  });

  const physicsTabs: TabItem[] = [
    { id: 'constants', label: 'Constants', icon: Atom },
    { id: 'projectile', label: 'Kinematics & Projectiles', icon: Orbit },
    { id: 'relativity', label: 'Special Relativity', icon: Sparkles },
    { id: 'quantum', label: 'Quantum & Waves', icon: Flame },
    { id: 'em', label: 'Electromagnetism', icon: Zap },
  ];

  return (
    <div className="w-full max-w-4xl mx-auto flex flex-col items-center select-none">
      <SwipeableTabContainer
        tabs={physicsTabs}
        activeTabId={activeTab}
        onSelectTab={(tabId) => {
          playSound('toggle');
          setActiveTab(tabId as PhysicsTab);
        }}
      >
        {/* Surface Container matching SWP design language */}
        <div className="w-full relative bg-zinc-950/80 rounded-3xl p-4 sm:p-7 border border-zinc-800/90 shadow-2xl overflow-hidden backdrop-blur-xl text-white">
          {/* Subtle Ambient Corner Glow */}
          <div
            className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
            style={{ backgroundColor: currentTheme.accent }}
          />
        {/* TAB 1: PHYSICAL CONSTANTS TABLE */}
        {activeTab === 'constants' && (
          <div className="flex flex-col gap-4">
            {/* Search and Category Filter */}
            <div
              className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pb-3 border-b"
              style={{ borderColor: 'var(--m3-outline-variant)' }}
            >
              <div className="relative flex-1">
                <Search
                  className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2"
                  style={{ color: 'var(--m3-on-surface-variant)' }}
                />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search constant (e.g. Planck, c, G, electron, gas)..."
                  className="w-full border rounded-full pl-10 pr-4 py-2 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div className="overflow-x-auto scrollbar-none flex items-center gap-1.5">
                {categories.map((cat) => {
                  const isCatSelected = selectedCategory === cat;
                  return (
                    <button
                      key={cat}
                      onClick={() => {
                        playSound('toggle');
                        setSelectedCategory(cat);
                      }}
                      className="px-3 py-1.5 text-xs font-medium rounded-full border transition-all whitespace-nowrap shrink-0 active:scale-95 cursor-pointer"
                      style={{
                        backgroundColor: isCatSelected ? 'var(--m3-primary)' : 'var(--m3-surface-container-high)',
                        color: isCatSelected ? 'var(--m3-on-primary)' : 'var(--m3-on-surface-variant)',
                        borderColor: isCatSelected ? 'var(--m3-primary)' : 'var(--m3-outline-variant)',
                        fontWeight: isCatSelected ? 700 : 500,
                      }}
                    >
                      {cat}
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Constants List */}
            <div
              className="overflow-x-auto max-h-[500px] scrollbar-thin border rounded-[22px]"
              style={{ borderColor: 'var(--m3-outline-variant)' }}
            >
              <table className="w-full min-w-[620px] text-left text-xs font-mono">
                <thead
                  className="sticky top-0 border-b z-10"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-high)',
                    color: 'var(--m3-on-surface-variant)',
                    borderColor: 'var(--m3-outline-variant)',
                  }}
                >
                  <tr>
                    <th className="py-2.5 px-3">Symbol</th>
                    <th className="py-2.5 px-3">Constant Name</th>
                    <th className="py-2.5 px-3">Value</th>
                    <th className="py-2.5 px-3">Units</th>
                    <th className="py-2.5 px-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y" style={{ borderColor: 'var(--m3-outline-variant)' }}>
                  {filteredConstants.map((c) => (
                    <tr
                      key={c.id}
                      className="transition-colors group hover:bg-[var(--m3-surface-container-highest)]/40"
                      style={{ color: 'var(--m3-on-surface)' }}
                    >
                      <td className="py-2.5 px-3 font-bold text-sm whitespace-nowrap" style={{ color: 'var(--m3-primary)' }}>
                        {c.symbol}
                      </td>
                      <td className="py-2.5 px-3">
                        <div className="font-sans font-medium" style={{ color: 'var(--m3-on-surface)' }}>{c.name}</div>
                        <div className="text-[10px] line-clamp-1" style={{ color: 'var(--m3-on-surface-variant)' }}>{c.description}</div>
                      </td>
                      <td className="py-2.5 px-3 font-semibold text-emerald-500 select-all whitespace-nowrap">
                        {c.value >= 1e4 || (c.value <= 1e-3 && c.value !== 0)
                          ? c.value.toExponential(6)
                          : c.value}
                      </td>
                      <td className="py-2.5 px-3 whitespace-nowrap" style={{ color: 'var(--m3-on-surface-variant)' }}>
                        {c.unit}
                      </td>
                      <td className="py-2.5 px-3 text-right whitespace-nowrap">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => handleCopy(c.id, c.value.toString())}
                            title="Copy numeric value"
                            className="p-1.5 rounded-full border transition-colors cursor-pointer active:scale-95"
                            style={{
                              backgroundColor: 'var(--m3-surface-container-high)',
                              borderColor: 'var(--m3-outline-variant)',
                              color: 'var(--m3-on-surface)',
                            }}
                          >
                            {copiedId === c.id ? (
                              <Check className="w-3.5 h-3.5 text-emerald-500" />
                            ) : (
                              <Copy className="w-3.5 h-3.5" />
                            )}
                          </button>
                          <button
                            onClick={() => {
                              playSound('op');
                              onInsertToCalculator(c.value.toString());
                            }}
                            title="Insert into Calculator"
                            className="px-2.5 py-1 rounded-full text-xs border flex items-center gap-1 transition-colors cursor-pointer active:scale-95"
                            style={{
                              backgroundColor: 'var(--m3-primary-container)',
                              color: 'var(--m3-on-primary-container)',
                              borderColor: 'var(--m3-outline-variant)',
                            }}
                          >
                            <CornerDownLeft className="w-3 h-3" />
                            <span>Calc</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB 2: PROJECTILE MOTION */}
        {activeTab === 'projectile' && (
          <div className="flex flex-col gap-6">
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3.5">
              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Launch Speed v₀ (m/s)
                </label>
                <input
                  type="number"
                  step="1"
                  value={projV0}
                  onChange={(e) => setProjV0(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Launch Angle θ (deg)
                </label>
                <input
                  type="number"
                  step="1"
                  min="0"
                  max="90"
                  value={projAngle}
                  onChange={(e) => setProjAngle(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Initial Height h₀ (m)
                </label>
                <input
                  type="number"
                  step="0.5"
                  value={projH0}
                  onChange={(e) => setProjH0(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Gravity g (m/s²)
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={projG}
                  onChange={(e) => setProjG(parseFloat(e.target.value) || 9.81)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>
            </div>

            {/* Trajectory SVG Parabola Simulation */}
            <div
              className="border rounded-[24px] p-4 flex flex-col gap-2 transition-colors"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div className="flex items-center justify-between text-xs font-mono" style={{ color: 'var(--m3-on-surface-variant)' }}>
                <span>Trajectory Curve y(x)</span>
                <span>
                  Max H: {projResult.maxHeight.toFixed(2)} m · Range: {projResult.range.toFixed(2)} m
                </span>
              </div>
              <div className="w-full h-36 relative">
                <svg className="w-full h-full overflow-visible" viewBox="0 0 400 120" preserveAspectRatio="none">
                  {/* Ground line */}
                  <line x1="0" y1="115" x2="400" y2="115" stroke="var(--m3-outline-variant)" strokeWidth="1.5" />
                  {/* Trajectory path */}
                  {projResult.trajectoryPoints.length > 1 && (
                    <path
                      d={projResult.trajectoryPoints
                        .map((pt, idx) => {
                          const px = projResult.range > 0 ? (pt.x / projResult.range) * 380 + 10 : 10;
                          const py = 115 - (projResult.maxHeight > 0 ? (pt.y / (projResult.maxHeight * 1.15)) * 105 : 0);
                          return `${idx === 0 ? 'M' : 'L'} ${px} ${py}`;
                        })
                        .join(' ')}
                      fill="none"
                      stroke="var(--m3-primary)"
                      strokeWidth="3"
                    />
                  )}
                  {/* Apex indicator */}
                  <circle
                    cx={projResult.range > 0 ? ((projResult.range * (projResult.timeToPeak / projResult.timeOfFlight)) / projResult.range) * 380 + 10 : 10}
                    cy={115 - (105 / 1.15)}
                    r="4"
                    fill="#10b981"
                  />
                </svg>
              </div>
            </div>

            {/* Results Grid */}
            <div
              className="grid grid-cols-2 sm:grid-cols-4 gap-3 p-4 sm:p-5 rounded-[24px] border font-mono"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Range R</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-primary)' }}>
                  {projResult.range.toFixed(2)} m
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Max Height H</span>
                <span className="text-xl font-bold text-emerald-500 mt-1">
                  {projResult.maxHeight.toFixed(2)} m
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Flight Time T</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-on-surface)' }}>
                  {projResult.timeOfFlight.toFixed(2)} s
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Impact Speed</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-tertiary)' }}>
                  {projResult.impactVelocity.toFixed(2)} m/s
                </span>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: SPECIAL RELATIVITY */}
        {activeTab === 'relativity' && (
          <div className="flex flex-col gap-6">
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-3.5">
              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Velocity β = v/c
                </label>
                <input
                  type="number"
                  step="0.05"
                  min="0"
                  max="0.9999"
                  value={relBeta}
                  onChange={(e) => setRelBeta(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Proper Time t₀ (s)
                </label>
                <input
                  type="number"
                  step="1"
                  value={relT0}
                  onChange={(e) => setRelT0(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Proper Length L₀ (m)
                </label>
                <input
                  type="number"
                  step="1"
                  value={relL0}
                  onChange={(e) => setRelL0(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Rest Mass m₀ (kg)
                </label>
                <input
                  type="number"
                  step="0.1"
                  value={relM0}
                  onChange={(e) => setRelM0(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>
            </div>

            {/* Relativistic Results Grid */}
            <div
              className="grid grid-cols-2 sm:grid-cols-4 gap-3 p-4 sm:p-5 rounded-[24px] border font-mono"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Lorentz Factor γ</span>
                <span className="text-2xl font-bold mt-1" style={{ color: 'var(--m3-primary)' }}>
                  {relResult.gamma.toFixed(4)}
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Dilated Time t</span>
                <span className="text-xl font-bold text-emerald-500 mt-1">
                  {relResult.dilatedTime.toFixed(3)} s
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Contracted Length L</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-tertiary)' }}>
                  {relResult.contractedLength.toFixed(3)} m
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Relativistic Momentum p</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-on-surface)' }}>
                  {relResult.momentum.toExponential(3)} kg·m/s
                </span>
              </div>
            </div>

            {/* Energy Breakdown */}
            <div
              className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-4 sm:p-5 rounded-[24px] border font-mono"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Rest Energy E₀ = m₀c²</span>
                <span className="text-lg font-bold mt-1" style={{ color: 'var(--m3-on-surface)' }}>
                  {relResult.restEnergy.toExponential(4)} J
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Kinetic Energy K = (γ - 1)m₀c²</span>
                <span className="text-lg font-bold mt-1" style={{ color: 'var(--m3-primary)' }}>
                  {relResult.kineticEnergy.toExponential(4)} J
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Total Energy E = γm₀c²</span>
                <span className="text-lg font-bold text-emerald-500 mt-1">
                  {relResult.totalEnergy.toExponential(4)} J
                </span>
              </div>
            </div>
          </div>
        )}

        {/* TAB 4: QUANTUM & WAVES */}
        {activeTab === 'quantum' && (
          <div className="flex flex-col gap-6">
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Input Mode
                </label>
                <select
                  value={quantumMode}
                  onChange={(e) => {
                    playSound('toggle');
                    setQuantumMode(e.target.value as 'wavelength' | 'frequency' | 'energyEv');
                  }}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)] cursor-pointer"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                >
                  <option value="wavelength">Wavelength λ (nm)</option>
                  <option value="frequency">Frequency f (Hz)</option>
                  <option value="energyEv">Photon Energy E (eV)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Value ({quantumMode === 'wavelength' ? 'nm' : quantumMode === 'frequency' ? 'Hz' : 'eV'})
                </label>
                <input
                  type="number"
                  step="any"
                  value={quantumInput}
                  onChange={(e) => setQuantumInput(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Work Function Φ (eV)
                </label>
                <input
                  type="number"
                  step="0.1"
                  value={quantumPhi}
                  onChange={(e) => setQuantumPhi(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>
            </div>

            {/* Quantum Results */}
            <div
              className="grid grid-cols-2 sm:grid-cols-4 gap-3 p-4 sm:p-5 rounded-[24px] border font-mono"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Wavelength λ</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-primary)' }}>
                  {quantumResult.wavelengthNm.toFixed(2)} nm
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Frequency f</span>
                <span className="text-xl font-bold text-emerald-500 mt-1">
                  {quantumResult.frequencyHz.toExponential(3)} Hz
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Photon Energy</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-tertiary)' }}>
                  {quantumResult.energyEv.toFixed(3)} eV
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Photon Momentum</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-on-surface)' }}>
                  {quantumResult.momentum.toExponential(3)} kg·m/s
                </span>
              </div>
            </div>

            {/* Photoelectric Effect Section */}
            <div
              className="p-4 sm:p-5 rounded-[24px] border flex flex-col gap-2 font-mono"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <span className="text-xs font-semibold font-sans" style={{ color: 'var(--m3-on-surface)' }}>
                Photoelectric Effect Evaluation
              </span>
              <div
                className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2 border-t"
                style={{ borderColor: 'var(--m3-outline-variant)' }}
              >
                <div>
                  <span className="text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>Cutoff Frequency f₀:</span>
                  <div className="text-base font-bold" style={{ color: 'var(--m3-on-surface)' }}>
                    {quantumResult.cutoffFrequencyHz.toExponential(3)} Hz
                  </div>
                </div>
                <div>
                  <span className="text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>Max Kinetic Energy K_max:</span>
                  <div className="text-base text-emerald-500 font-bold">
                    {quantumResult.maxKineticEnergyEv.toFixed(3)} eV
                  </div>
                </div>
                <div>
                  <span className="text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>Stopping Potential V₀:</span>
                  <div className="text-base font-bold" style={{ color: 'var(--m3-primary)' }}>
                    {quantumResult.stoppingPotentialV.toFixed(3)} V
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 5: ELECTROMAGNETISM */}
        {activeTab === 'em' && (
          <div className="flex flex-col gap-6">
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3.5">
              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Charge q₁ (Coulombs)
                </label>
                <input
                  type="number"
                  step="any"
                  value={emQ1}
                  onChange={(e) => setEmQ1(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Charge q₂ (Coulombs)
                </label>
                <input
                  type="number"
                  step="any"
                  value={emQ2}
                  onChange={(e) => setEmQ2(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Separation Distance r (m)
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={emDist}
                  onChange={(e) => setEmDist(parseFloat(e.target.value) || 0.01)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Magnetic Field B (Tesla)
                </label>
                <input
                  type="number"
                  step="0.1"
                  value={emB}
                  onChange={(e) => setEmB(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>

              <div>
                <label className="block text-xs font-semibold mb-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Particle Velocity v (m/s)
                </label>
                <input
                  type="number"
                  step="1000"
                  value={emVel}
                  onChange={(e) => setEmVel(parseFloat(e.target.value) || 0)}
                  className="w-full border rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2 focus:ring-[var(--m3-primary)]"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-highest)',
                    borderColor: 'var(--m3-outline-variant)',
                    color: 'var(--m3-on-surface)',
                  }}
                />
              </div>
            </div>

            {/* Results Grid */}
            <div
              className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-4 sm:p-5 rounded-[24px] border font-mono"
              style={{
                backgroundColor: 'var(--m3-surface-container)',
                borderColor: 'var(--m3-outline-variant)',
              }}
            >
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Coulomb Force Fₑ</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-primary)' }}>
                  {emResult.coulombForceN.toExponential(3)} N
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Cyclotron Radius r</span>
                <span className="text-xl font-bold text-emerald-500 mt-1">
                  {emResult.cyclotronRadiusM.toExponential(3)} m
                </span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-sans" style={{ color: 'var(--m3-on-surface-variant)' }}>Cyclotron Frequency f_c</span>
                <span className="text-xl font-bold mt-1" style={{ color: 'var(--m3-tertiary)' }}>
                  {emResult.cyclotronFreqHz.toExponential(3)} Hz
                </span>
              </div>
            </div>
          </div>
        )}
      </div>
    </SwipeableTabContainer>
    </div>
  );
};
