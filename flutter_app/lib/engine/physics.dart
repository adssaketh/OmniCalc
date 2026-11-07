import 'dart:math' as math;

import 'js_number.dart';

export 'physics_constants.dart';

class TrajectoryPoint {
  final double x;
  final double y;

  const TrajectoryPoint(this.x, this.y);
}

class ProjectileResult {
  final double timeOfFlight;
  final double maxHeight;
  final double range;
  final double timeToPeak;
  final double impactVelocity;
  final double impactAngleDeg;
  final List<TrajectoryPoint> trajectoryPoints;

  const ProjectileResult({
    required this.timeOfFlight,
    required this.maxHeight,
    required this.range,
    required this.timeToPeak,
    required this.impactVelocity,
    required this.impactAngleDeg,
    required this.trajectoryPoints,
  });
}

class RelativityResult {
  final double beta;
  final double gamma;
  final double dilatedTime;
  final double contractedLength;
  final double momentum;
  final double restEnergy;
  final double totalEnergy;
  final double kineticEnergy;

  const RelativityResult({
    required this.beta,
    required this.gamma,
    required this.dilatedTime,
    required this.contractedLength,
    required this.momentum,
    required this.restEnergy,
    required this.totalEnergy,
    required this.kineticEnergy,
  });
}

/// 'wavelength' | 'frequency' | 'energyEv'
enum PhotonMode {
  wavelength,
  frequency,
  energyEv;

  static PhotonMode parse(String s) => PhotonMode.values.firstWhere((m) => m.name == s);
}

class PhotonResult {
  final double wavelengthNm;
  final double frequencyHz;
  final double energyJoules;
  final double energyEv;
  final double momentum;
  final double cutoffFrequencyHz;
  final double maxKineticEnergyEv;
  final double stoppingPotentialV;

  const PhotonResult({
    required this.wavelengthNm,
    required this.frequencyHz,
    required this.energyJoules,
    required this.energyEv,
    required this.momentum,
    required this.cutoffFrequencyHz,
    required this.maxKineticEnergyEv,
    required this.stoppingPotentialV,
  });
}

class ElectromagnetismResult {
  final double coulombForceN;
  final double cyclotronRadiusM;
  final double cyclotronFreqHz;
  final double magneticForceN;

  const ElectromagnetismResult({
    required this.coulombForceN,
    required this.cyclotronRadiusM,
    required this.cyclotronFreqHz,
    required this.magneticForceN,
  });
}

/// Port of `PhysicsSolver` in `src/engine/physics.ts` (the constants table is generated, see physics_constants.dart).
class PhysicsSolver {
  PhysicsSolver._();

  /// Projectile motion kinematics.
  static ProjectileResult solveProjectile(
    double v0,
    double thetaDeg, [
    double h0 = 0,
    double g = 9.80665,
  ]) {
    final thetaRad = (thetaDeg * math.pi) / 180;
    final vx0 = v0 * math.cos(thetaRad);
    final vy0 = v0 * math.sin(thetaRad);

    final timeToPeak = vy0 / g;
    final maxHeight = h0 + (vy0 * vy0) / (2 * g);

    // Quadratic solution for y(t) = h0 + vy0*t - 0.5*g*t^2 = 0
    final discriminant = vy0 * vy0 + 2 * g * h0;
    final timeOfFlight = (vy0 + math.sqrt(jsMax([0, discriminant]))) / g;
    final range = vx0 * timeOfFlight;

    // Final velocity components at impact
    final vxf = vx0;
    final vyf = vy0 - g * timeOfFlight;
    final impactVelocity = math.sqrt(vxf * vxf + vyf * vyf);
    final impactAngleDeg = (math.atan2(vyf.abs(), vxf) * 180) / math.pi;

    // Generate trajectory points for plotting
    const pointsCount = 40;
    final trajectoryPoints = <TrajectoryPoint>[];
    for (var i = 0; i <= pointsCount; i++) {
      final t = (timeOfFlight * i) / pointsCount;
      final x = vx0 * t;
      final y = jsMax([0, h0 + vy0 * t - 0.5 * g * t * t]);
      trajectoryPoints.add(TrajectoryPoint(x, y));
    }

    return ProjectileResult(
      timeOfFlight: timeOfFlight,
      maxHeight: maxHeight,
      range: range,
      timeToPeak: timeToPeak,
      impactVelocity: impactVelocity,
      impactAngleDeg: impactAngleDeg,
      trajectoryPoints: trajectoryPoints,
    );
  }

  /// Special relativity (Lorentz transformations).
  /// [betaOrV] is a velocity as a fraction of c (e.g. 0.8) or in m/s; [t0] proper time (s), [L0] proper length (m),
  /// [m0] rest mass (kg).
  static RelativityResult solveRelativity(
    double betaOrV, [
    double t0 = 1,
    double L0 = 1,
    double m0 = 1,
  ]) {
    const c = 299792458.0;
    var beta = betaOrV;
    if (beta > 1) {
      beta = betaOrV / c;
    }
    beta = jsMax([0, jsMin([0.999999999, beta])]);

    final gamma = 1 / math.sqrt(1 - beta * beta);
    final dilatedTime = gamma * t0;
    final contractedLength = L0 / gamma;
    final v = beta * c;
    final momentum = gamma * m0 * v;
    final restEnergy = m0 * c * c;
    final totalEnergy = gamma * m0 * c * c;
    final kineticEnergy = (gamma - 1) * m0 * c * c;

    return RelativityResult(
      beta: beta,
      gamma: gamma,
      dilatedTime: dilatedTime,
      contractedLength: contractedLength,
      momentum: momentum,
      restEnergy: restEnergy,
      totalEnergy: totalEnergy,
      kineticEnergy: kineticEnergy,
    );
  }

  /// Quantum and wave-particle duality. [workFunctionEv] defaults to 2.3 eV (sodium).
  static PhotonResult solvePhotonWave(
    PhotonMode mode,
    double inputVal, [
    double workFunctionEv = 2.3,
  ]) {
    const c = 299792458.0;
    const h = 6.62607015e-34;
    const qe = 1.602176634e-19;

    var wavelengthM = 500e-9;
    var frequencyHz = 6e14;
    var energyJoules = 4e-19;

    if (mode == PhotonMode.wavelength) {
      wavelengthM = jsMax([1e-15, inputVal * 1e-9]);
      frequencyHz = c / wavelengthM;
      energyJoules = h * frequencyHz;
    } else if (mode == PhotonMode.frequency) {
      frequencyHz = jsMax([1, inputVal]);
      wavelengthM = c / frequencyHz;
      energyJoules = h * frequencyHz;
    } else {
      final energyEvIn = jsMax([1e-6, inputVal]);
      energyJoules = energyEvIn * qe;
      frequencyHz = energyJoules / h;
      wavelengthM = c / frequencyHz;
    }

    final energyEv = energyJoules / qe;
    final momentum = h / wavelengthM;
    final cutoffFrequencyHz = (workFunctionEv * qe) / h;
    final maxKineticEnergyEv = jsMax([0, energyEv - workFunctionEv]);
    final stoppingPotentialV = maxKineticEnergyEv;

    return PhotonResult(
      wavelengthNm: wavelengthM * 1e9,
      frequencyHz: frequencyHz,
      energyJoules: energyJoules,
      energyEv: energyEv,
      momentum: momentum,
      cutoffFrequencyHz: cutoffFrequencyHz,
      maxKineticEnergyEv: maxKineticEnergyEv,
      stoppingPotentialV: stoppingPotentialV,
    );
  }

  /// Electromagnetism (Coulomb force, cyclotron motion). Charges in C, distance in m, B in T.
  static ElectromagnetismResult solveElectromagnetism(
    double q1,
    double q2,
    double distanceM, [
    double bFieldT = 0.5,
    double particleMassKg = 9.109e-31,
    double velocityMps = 1e6,
  ]) {
    const ke = 8.98755e9;
    final dist = jsMax([1e-12, distanceM]);
    final coulombForceN = (ke * (q1 * q2).abs()) / (dist * dist);

    // `Math.abs(q1) || 1.602e-19`: 0 and NaN are falsy in JavaScript.
    final absQ1 = q1.abs();
    final q = (absQ1 == 0 || absQ1.isNaN) ? 1.602e-19 : absQ1;
    final cyclotronRadiusM = (particleMassKg * velocityMps) / (q * jsMax([1e-9, bFieldT]));
    final cyclotronFreqHz = (q * bFieldT) / (2 * math.pi * particleMassKg);
    final magneticForceN = q * velocityMps * bFieldT;

    return ElectromagnetismResult(
      coulombForceN: coulombForceN,
      cyclotronRadiusM: cyclotronRadiusM,
      cyclotronFreqHz: cyclotronFreqHz,
      magneticForceN: magneticForceN,
    );
  }
}
