import 'dart:math' as math;

import '../calc_error.dart';
import 'chem_format.dart';
import 'solver_types.dart';

String f(double v) => chemNum(v);

ChemInput inp(String id, String label, String unit, {double? initial}) => ChemInput(id, label, unit, initial: initial);

ChemOutput out(String label, double value, String unit, {String? note}) => ChemOutput(label, value, unit, note: note);

ChemResult one(String label, double value, String unit, List<String> steps) =>
    ChemResult([ChemOutput(label, value, unit)], steps);

void need(bool ok, String message) {
  if (!ok) throw CalcError(message);
}

void positive(double v, String name) => need(v > 0, '$name must be greater than 0');

void nonNegative(double v, String name) => need(v >= 0, '$name cannot be negative');

double log10(double x) => math.log(x) / math.ln10;

/// Raises when a calculation produced something that is not a number.
double finite(double v, [String what = 'The result']) {
  need(v.isFinite, '$what is not a finite number. Check the inputs');
  return v;
}
