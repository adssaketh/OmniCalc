import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/physics.dart';

import 'golden_expect.dart';
import 'golden_loader.dart';

// Vectors produced by running the real TypeScript engine (see tools/gen_vectors.ts). raw doubles: 1e-9 relative.
void main() {
  group('projectile', () {
    final vectors = (loadGolden('projectile') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(8)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = (v['in'] as List).map(toD).toList();
      test('#$i ${v['in']}', () {
        final r = switch (a.length) {
          2 => PhysicsSolver.solveProjectile(a[0], a[1]),
          3 => PhysicsSolver.solveProjectile(a[0], a[1], a[2]),
          _ => PhysicsSolver.solveProjectile(a[0], a[1], a[2], a[3]),
        };
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.timeOfFlight, want['timeOfFlight'], 'timeOfFlight');
        expectNum(r.maxHeight, want['maxHeight'], 'maxHeight');
        expectNum(r.range, want['range'], 'range');
        expectNum(r.timeToPeak, want['timeToPeak'], 'timeToPeak');
        expectNum(r.impactVelocity, want['impactVelocity'], 'impactVelocity');
        expectNum(r.impactAngleDeg, want['impactAngleDeg'], 'impactAngleDeg');
        final pts = (want['trajectoryPoints'] as List).cast<Map<String, dynamic>>();
        expect(r.trajectoryPoints.length, pts.length, reason: 'trajectoryPoints length');
        for (var k = 0; k < pts.length; k++) {
          expectNum(r.trajectoryPoints[k].x, pts[k]['x'], 'point[$k].x');
          expectNum(r.trajectoryPoints[k].y, pts[k]['y'], 'point[$k].y');
        }
      });
    }
  });

  group('relativity', () {
    final vectors = (loadGolden('relativity') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(10)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = (v['in'] as List).map(toD).toList();
      test('#$i ${v['in']}', () {
        final r = a.length == 1
            ? PhysicsSolver.solveRelativity(a[0])
            : PhysicsSolver.solveRelativity(a[0], a[1], a[2], a[3]);
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.beta, want['beta'], 'beta');
        expectNum(r.gamma, want['gamma'], 'gamma');
        expectNum(r.dilatedTime, want['dilatedTime'], 'dilatedTime');
        expectNum(r.contractedLength, want['contractedLength'], 'contractedLength');
        expectNum(r.momentum, want['momentum'], 'momentum');
        expectNum(r.restEnergy, want['restEnergy'], 'restEnergy');
        expectNum(r.totalEnergy, want['totalEnergy'], 'totalEnergy');
        expectNum(r.kineticEnergy, want['kineticEnergy'], 'kineticEnergy');
      });
    }
  });

  group('photon', () {
    final vectors = (loadGolden('photon') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(10)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = v['in'] as List;
      test('#$i $a', () {
        final mode = PhotonMode.parse(a[0] as String);
        final r = a.length > 2
            ? PhysicsSolver.solvePhotonWave(mode, toD(a[1]), toD(a[2]))
            : PhysicsSolver.solvePhotonWave(mode, toD(a[1]));
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.wavelengthNm, want['wavelengthNm'], 'wavelengthNm');
        expectNum(r.frequencyHz, want['frequencyHz'], 'frequencyHz');
        expectNum(r.energyJoules, want['energyJoules'], 'energyJoules');
        expectNum(r.energyEv, want['energyEv'], 'energyEv');
        expectNum(r.momentum, want['momentum'], 'momentum');
        expectNum(r.cutoffFrequencyHz, want['cutoffFrequencyHz'], 'cutoffFrequencyHz');
        expectNum(r.maxKineticEnergyEv, want['maxKineticEnergyEv'], 'maxKineticEnergyEv');
        expectNum(r.stoppingPotentialV, want['stoppingPotentialV'], 'stoppingPotentialV');
      });
    }
  });

  group('electromagnetism', () {
    final vectors = (loadGolden('electromagnetism') as List).cast<Map<String, dynamic>>();
    test('golden file is present', () => expect(vectors.length, greaterThanOrEqualTo(7)));

    for (var i = 0; i < vectors.length; i++) {
      final v = vectors[i];
      final a = (v['in'] as List).map(toD).toList();
      test('#$i ${v['in']}', () {
        final r = switch (a.length) {
          3 => PhysicsSolver.solveElectromagnetism(a[0], a[1], a[2]),
          4 => PhysicsSolver.solveElectromagnetism(a[0], a[1], a[2], a[3]),
          5 => PhysicsSolver.solveElectromagnetism(a[0], a[1], a[2], a[3], a[4]),
          _ => PhysicsSolver.solveElectromagnetism(a[0], a[1], a[2], a[3], a[4], a[5]),
        };
        final want = v['out'] as Map<String, dynamic>;
        expectNum(r.coulombForceN, want['coulombForceN'], 'coulombForceN');
        expectNum(r.cyclotronRadiusM, want['cyclotronRadiusM'], 'cyclotronRadiusM');
        expectNum(r.cyclotronFreqHz, want['cyclotronFreqHz'], 'cyclotronFreqHz');
        expectNum(r.magneticForceN, want['magneticForceN'], 'magneticForceN');
      });
    }
  });

  group('physical constants (generated from physics.ts)', () {
    test('29 constants with unique ids, in the web app order', () {
      expect(physicalConstants.length, 29);
      expect(physicalConstants.map((c) => c.id).toSet().length, physicalConstants.length);
      expect(physicalConstants.first.id, 'c');
      expect(physicalConstants.last.id, 'R_earth');
    });

    test('spot values', () {
      final byId = {for (final c in physicalConstants) c.id: c};
      expect(byId['c']!.value, 299792458.0);
      expect(byId['h']!.value, 6.62607015e-34);
      expect(byId['NA']!.value, 6.02214076e23);
      expect(byId['kB']!.value, 1.380649e-23);
      expect(byId['Rydberg']!.value, 10973731.56816);
      expect(byId['mu0']!.value, 1.25663706212e-6);
      expect(byId['M_sun']!.value, 1.98847e30);
      expect(byId['hbar']!.symbol, 'ℏ');
      expect(byId['g']!.category, 'Mechanics');
    });
  });
}
