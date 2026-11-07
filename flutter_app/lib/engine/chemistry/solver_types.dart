import '../calc_error.dart';
import 'chem_format.dart';

/// One input field of a solver mode.
class ChemInput {
  const ChemInput(this.id, this.label, this.unit, {this.initial});

  final String id;
  final String label;

  /// Unit shown beside the field (may be empty for pure numbers).
  final String unit;

  /// Value the field starts with (only where a standard value is safe, e.g. water's specific heat); null = empty.
  final double? initial;
}

/// One number of a result.
class ChemOutput {
  const ChemOutput(this.label, this.value, this.unit, {this.note});

  final String label;
  final double value;
  final String unit;
  final String? note;

  String get text => '${chemNum(value)}${unit.isEmpty ? '' : ' $unit'}';
}

/// A solver answer: the numbers plus the working, line by line.
class ChemResult {
  const ChemResult(this.outputs, this.steps, {this.message});

  final List<ChemOutput> outputs;
  final List<String> steps;

  /// A plain sentence for results that are not a number (e.g. "The reaction shifts to the right").
  final String? message;
}

typedef ChemSolveFn = ChemResult Function(Map<String, double> v);

/// One way of using a solver (usually "solve for X").
class ChemMode {
  const ChemMode({
    required this.id,
    required this.label,
    required this.formula,
    required this.inputs,
    required this.solve,
  });

  final String id;
  final String label;

  /// The relation shown above the fields, e.g. `PV = nRT`.
  final String formula;
  final List<ChemInput> inputs;
  final ChemSolveFn solve;

  /// Runs [solve] after checking that every input is a finite number.
  ChemResult run(Map<String, double> values) {
    for (final i in inputs) {
      final v = values[i.id];
      if (v == null) throw CalcError('Enter ${i.label}');
      if (!v.isFinite) throw CalcError('${i.label} is not a number');
    }
    return solve(values);
  }
}

/// A topic of the Chemistry screen with one or more modes.
class ChemSolver {
  const ChemSolver({
    required this.id,
    required this.group,
    required this.title,
    required this.summary,
    required this.modes,
  });

  final String id;

  /// Section of the Formulas list: one of [chemSolverGroups].
  final String group;
  final String title;
  final String summary;
  final List<ChemMode> modes;
}

/// Section names in display order.
const List<String> chemSolverGroups = [
  'Gas laws',
  'Solutions',
  'Acids & bases',
  'Thermochemistry',
  'Kinetics',
  'Equilibrium',
  'Electrochemistry',
  'Stoichiometry',
  'Nuclear',
  'Quantum & atomic',
  'Organic',
];
