import 'balancer.dart';
import 'solver_types.dart';
import 'solvers_electro_nuclear.dart';
import 'solvers_equilibrium.dart';
import 'solvers_gas.dart';
import 'solvers_solutions.dart';
import 'solvers_thermo_kinetics.dart';

/// Every numeric solver of the Chemistry screen, in the order of [chemSolverGroups].
final List<ChemSolver> allChemSolvers = [
  ...gasSolvers,
  ...solutionSolvers,
  ...acidBaseSolvers,
  ...thermoSolvers,
  ...kineticsSolvers,
  ...equilibriumSolvers,
  ...electroSolvers,
  molesMassParticles,
  percentYield,
  ...nuclearSolvers,
  ...quantumSolvers,
  ...organicSolvers,
];

List<ChemSolver> solversInGroup(String group) => [for (final s in allChemSolvers) if (s.group == group) s];
