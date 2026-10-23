export interface PhysicalConstant {
  id: string;
  name: string;
  symbol: string;
  value: number;
  unit: string;
  category: 'Universal' | 'Mechanics' | 'Electromagnetism' | 'Quantum & Atomic' | 'Thermodynamics' | 'Astrophysics';
  description: string;
}

export const PHYSICAL_CONSTANTS: PhysicalConstant[] = [
  // Universal
  {
    id: 'c',
    name: 'Speed of Light in Vacuum',
    symbol: 'c',
    value: 299792458,
    unit: 'm / s',
    category: 'Universal',
    description: 'Exact speed of electromagnetic radiation in free space',
  },
  {
    id: 'G',
    name: 'Newtonian Constant of Gravitation',
    symbol: 'G',
    value: 6.67430e-11,
    unit: 'N · m² / kg²',
    category: 'Universal',
    description: 'Universal gravitational coupling constant',
  },
  {
    id: 'g',
    name: 'Standard Acceleration of Gravity',
    symbol: 'g',
    value: 9.80665,
    unit: 'm / s²',
    category: 'Mechanics',
    description: 'Nominal gravitational acceleration at Earth sea level',
  },
  {
    id: 'h',
    name: 'Planck Constant',
    symbol: 'h',
    value: 6.62607015e-34,
    unit: 'J · s',
    category: 'Quantum & Atomic',
    description: 'Quantum of electromagnetic action',
  },
  {
    id: 'hbar',
    name: 'Reduced Planck Constant (Dirac constant)',
    symbol: 'ℏ',
    value: 1.054571817e-34,
    unit: 'J · s',
    category: 'Quantum & Atomic',
    description: 'h / (2π), fundamental unit of angular momentum',
  },
  {
    id: 'e',
    name: 'Elementary Charge',
    symbol: 'e',
    value: 1.602176634e-19,
    unit: 'C',
    category: 'Electromagnetism',
    description: 'Electric charge carried by a single proton or electron',
  },
  {
    id: 'eps0',
    name: 'Vacuum Electric Permittivity',
    symbol: 'ε₀',
    value: 8.8541878128e-12,
    unit: 'F / m',
    category: 'Electromagnetism',
    description: 'Permittivity of free space / electric constant',
  },
  {
    id: 'mu0',
    name: 'Vacuum Magnetic Permeability',
    symbol: 'μ₀',
    value: 1.25663706212e-6,
    unit: 'N / A²',
    category: 'Electromagnetism',
    description: 'Magnetic constant in vacuum (4π × 10⁻⁷ approx)',
  },
  {
    id: 'ke',
    name: 'Coulomb Constant',
    symbol: 'kₑ',
    value: 8.9875517923e9,
    unit: 'N · m² / C²',
    category: 'Electromagnetism',
    description: '1 / (4πε₀), electrostatic constant',
  },
  {
    id: 'Z0',
    name: 'Characteristic Impedance of Vacuum',
    symbol: 'Z₀',
    value: 376.730313668,
    unit: 'Ω',
    category: 'Electromagnetism',
    description: 'Wave impedance in vacuum (μ₀ · c)',
  },
  {
    id: 'me',
    name: 'Electron Rest Mass',
    symbol: 'mₑ',
    value: 9.1093837015e-31,
    unit: 'kg',
    category: 'Quantum & Atomic',
    description: 'Invariant rest mass of an electron (0.511 MeV/c²)',
  },
  {
    id: 'mp',
    name: 'Proton Rest Mass',
    symbol: 'mₚ',
    value: 1.67262192369e-27,
    unit: 'kg',
    category: 'Quantum & Atomic',
    description: 'Invariant rest mass of a proton (938.272 MeV/c²)',
  },
  {
    id: 'mn',
    name: 'Neutron Rest Mass',
    symbol: 'mₙ',
    value: 1.67492749804e-27,
    unit: 'kg',
    category: 'Quantum & Atomic',
    description: 'Invariant rest mass of a neutron (939.565 MeV/c²)',
  },
  {
    id: 'u',
    name: 'Unified Atomic Mass Unit (Dalton)',
    symbol: 'u',
    value: 1.66053906660e-27,
    unit: 'kg',
    category: 'Quantum & Atomic',
    description: '1/12 of mass of unbound neutral carbon-12 atom',
  },
  {
    id: 'alpha',
    name: 'Fine-Structure Constant',
    symbol: 'α',
    value: 7.2973525693e-3,
    unit: 'dimensionless',
    category: 'Quantum & Atomic',
    description: '1 / 137.035999, strength of electromagnetic coupling',
  },
  {
    id: 'Rydberg',
    name: 'Rydberg Constant',
    symbol: 'R∞',
    value: 10973731.568160,
    unit: 'm⁻¹',
    category: 'Quantum & Atomic',
    description: 'Limiting wavenumber of atomic hydrogen spectra',
  },
  {
    id: 'a0',
    name: 'Bohr Radius',
    symbol: 'a₀',
    value: 5.29177210903e-11,
    unit: 'm',
    category: 'Quantum & Atomic',
    description: 'Most probable distance between nucleus and electron in ground state H',
  },
  {
    id: 'muB',
    name: 'Bohr Magneton',
    symbol: 'μ_B',
    value: 9.2740100783e-24,
    unit: 'J / T',
    category: 'Quantum & Atomic',
    description: 'Natural unit for magnetic moment of an electron',
  },
  {
    id: 'kB',
    name: 'Boltzmann Constant',
    symbol: 'k_B',
    value: 1.380649e-23,
    unit: 'J / K',
    category: 'Thermodynamics',
    description: 'Relates thermal energy to thermodynamic temperature',
  },
  {
    id: 'NA',
    name: 'Avogadro Constant',
    symbol: 'N_A',
    value: 6.02214076e23,
    unit: 'mol⁻¹',
    category: 'Thermodynamics',
    description: 'Number of constituent particles in one mole',
  },
  {
    id: 'R',
    name: 'Molar Gas Constant',
    symbol: 'R',
    value: 8.314462618,
    unit: 'J / (mol · K)',
    category: 'Thermodynamics',
    description: 'N_A × k_B, gas constant in ideal gas law PV = nRT',
  },
  {
    id: 'sigma',
    name: 'Stefan-Boltzmann Constant',
    symbol: 'σ',
    value: 5.670374419e-8,
    unit: 'W / (m² · K⁴)',
    category: 'Thermodynamics',
    description: 'Blackbody radiant emittance per unit temperature to the 4th power',
  },
  {
    id: 'b_wien',
    name: 'Wien Displacement Constant',
    symbol: 'b',
    value: 2.897771955e-3,
    unit: 'm · K',
    category: 'Thermodynamics',
    description: 'λ_max × T = b for blackbody peak radiation',
  },
  {
    id: 'AU',
    name: 'Astronomical Unit',
    symbol: 'AU',
    value: 1.495978707e11,
    unit: 'm',
    category: 'Astrophysics',
    description: 'Mean Earth-Sun distance',
  },
  {
    id: 'ly',
    name: 'Light-Year',
    symbol: 'ly',
    value: 9.4607304725808e15,
    unit: 'm',
    category: 'Astrophysics',
    description: 'Distance traversed by light in vacuum in one Julian year',
  },
  {
    id: 'pc',
    name: 'Parsec',
    symbol: 'pc',
    value: 3.08567758149137e16,
    unit: 'm',
    category: 'Astrophysics',
    description: 'Distance at which 1 AU subtends an angle of 1 arcsecond',
  },
  {
    id: 'M_sun',
    name: 'Solar Mass',
    symbol: 'M☉',
    value: 1.98847e30,
    unit: 'kg',
    category: 'Astrophysics',
    description: 'Mass of the Sun',
  },
  {
    id: 'M_earth',
    name: 'Earth Mass',
    symbol: 'M⊕',
    value: 5.9722e24,
    unit: 'kg',
    category: 'Astrophysics',
    description: 'Mass of planet Earth',
  },
  {
    id: 'R_earth',
    name: 'Earth Mean Radius',
    symbol: 'R⊕',
    value: 6.371e6,
    unit: 'm',
    category: 'Astrophysics',
    description: 'Mean volumetric radius of planet Earth',
  },
];

// Physics Solver Classes
export class PhysicsSolver {
  /**
   * Projectile Motion Kinematics
   */
  public static solveProjectile(
    v0: number,
    thetaDeg: number,
    h0: number = 0,
    g: number = 9.80665
  ): {
    timeOfFlight: number;
    maxHeight: number;
    range: number;
    timeToPeak: number;
    impactVelocity: number;
    impactAngleDeg: number;
    trajectoryPoints: Array<{ x: number; y: number }>;
  } {
    const thetaRad = (thetaDeg * Math.PI) / 180;
    const vx0 = v0 * Math.cos(thetaRad);
    const vy0 = v0 * Math.sin(thetaRad);

    const timeToPeak = vy0 / g;
    const maxHeight = h0 + (vy0 * vy0) / (2 * g);

    // Quadratic solution for y(t) = h0 + vy0*t - 0.5*g*t^2 = 0
    const discriminant = vy0 * vy0 + 2 * g * h0;
    const timeOfFlight = (vy0 + Math.sqrt(Math.max(0, discriminant))) / g;
    const range = vx0 * timeOfFlight;

    // Final velocity components at impact
    const vxf = vx0;
    const vyf = vy0 - g * timeOfFlight;
    const impactVelocity = Math.sqrt(vxf * vxf + vyf * vyf);
    const impactAngleDeg = (Math.atan2(Math.abs(vyf), vxf) * 180) / Math.PI;

    // Generate trajectory points for plotting
    const pointsCount = 40;
    const trajectoryPoints: Array<{ x: number; y: number }> = [];
    for (let i = 0; i <= pointsCount; i++) {
      const t = (timeOfFlight * i) / pointsCount;
      const x = vx0 * t;
      const y = Math.max(0, h0 + vy0 * t - 0.5 * g * t * t);
      trajectoryPoints.push({ x, y });
    }

    return {
      timeOfFlight,
      maxHeight,
      range,
      timeToPeak,
      impactVelocity,
      impactAngleDeg,
      trajectoryPoints,
    };
  }

  /**
   * Special Relativity (Lorentz Transformations)
   */
  public static solveRelativity(
    betaOrV: number, // velocity as fraction of c (e.g. 0.8) or m/s
    t0: number = 1, // proper time in seconds
    L0: number = 1, // proper length in meters
    m0: number = 1 // rest mass in kg
  ): {
    beta: number;
    gamma: number;
    dilatedTime: number;
    contractedLength: number;
    momentum: number;
    restEnergy: number;
    totalEnergy: number;
    kineticEnergy: number;
  } {
    const c = 299792458;
    let beta = betaOrV;
    if (beta > 1) {
      beta = betaOrV / c;
    }
    beta = Math.max(0, Math.min(0.999999999, beta));

    const gamma = 1 / Math.sqrt(1 - beta * beta);
    const dilatedTime = gamma * t0;
    const contractedLength = L0 / gamma;
    const v = beta * c;
    const momentum = gamma * m0 * v;
    const restEnergy = m0 * c * c;
    const totalEnergy = gamma * m0 * c * c;
    const kineticEnergy = (gamma - 1) * m0 * c * c;

    return {
      beta,
      gamma,
      dilatedTime,
      contractedLength,
      momentum,
      restEnergy,
      totalEnergy,
      kineticEnergy,
    };
  }

  /**
   * Quantum & Wave-Particle Duality
   */
  public static solvePhotonWave(
    mode: 'wavelength' | 'frequency' | 'energyEv',
    inputVal: number,
    workFunctionEv: number = 2.3 // e.g. Sodium = 2.3 eV
  ): {
    wavelengthNm: number;
    frequencyHz: number;
    energyJoules: number;
    energyEv: number;
    momentum: number;
    cutoffFrequencyHz: number;
    maxKineticEnergyEv: number;
    stoppingPotentialV: number;
  } {
    const c = 299792458;
    const h = 6.62607015e-34;
    const qe = 1.602176634e-19;

    let wavelengthM = 500e-9;
    let frequencyHz = 6e14;
    let energyJoules = 4e-19;

    if (mode === 'wavelength') {
      wavelengthM = Math.max(1e-15, inputVal * 1e-9);
      frequencyHz = c / wavelengthM;
      energyJoules = h * frequencyHz;
    } else if (mode === 'frequency') {
      frequencyHz = Math.max(1, inputVal);
      wavelengthM = c / frequencyHz;
      energyJoules = h * frequencyHz;
    } else {
      const energyEv = Math.max(1e-6, inputVal);
      energyJoules = energyEv * qe;
      frequencyHz = energyJoules / h;
      wavelengthM = c / frequencyHz;
    }

    const energyEv = energyJoules / qe;
    const momentum = h / wavelengthM;
    const cutoffFrequencyHz = (workFunctionEv * qe) / h;
    const maxKineticEnergyEv = Math.max(0, energyEv - workFunctionEv);
    const stoppingPotentialV = maxKineticEnergyEv;

    return {
      wavelengthNm: wavelengthM * 1e9,
      frequencyHz,
      energyJoules,
      energyEv,
      momentum,
      cutoffFrequencyHz,
      maxKineticEnergyEv,
      stoppingPotentialV,
    };
  }

  /**
   * Electromagnetism (RLC, Cyclotron, Coulomb)
   */
  public static solveElectromagnetism(
    q1: number, // Coulombs
    q2: number, // Coulombs
    distanceM: number, // meters
    BFieldT: number = 0.5, // Tesla
    particleMassKg: number = 9.109e-31, // electron
    velocityMps: number = 1e6
  ): {
    coulombForceN: number;
    cyclotronRadiusM: number;
    cyclotronFreqHz: number;
    magneticForceN: number;
  } {
    const ke = 8.98755e9;
    const dist = Math.max(1e-12, distanceM);
    const coulombForceN = (ke * Math.abs(q1 * q2)) / (dist * dist);

    const q = Math.abs(q1) || 1.602e-19;
    const cyclotronRadiusM = (particleMassKg * velocityMps) / (q * Math.max(1e-9, BFieldT));
    const cyclotronFreqHz = (q * BFieldT) / (2 * Math.PI * particleMassKg);
    const magneticForceN = q * velocityMps * BFieldT;

    return {
      coulombForceN,
      cyclotronRadiusM,
      cyclotronFreqHz,
      magneticForceN,
    };
  }
}
