import 'package:flutter/widgets.dart';

import '../../state/navigation_state.dart';
import '../calculator/calculator_screen.dart';
import 'converter_screen.dart';
import 'finance_screen.dart';
import 'graph_screen.dart';
import 'physics_screen.dart';

/// Screen builder of the shell: one screen per mode.
Widget appScreenBuilder(BuildContext context, CalculatorMode mode) {
  return switch (mode) {
    CalculatorMode.standard || CalculatorMode.scientific => const CalculatorScreen(),
    CalculatorMode.converter => const ConverterScreen(),
    CalculatorMode.finance => const FinanceScreen(),
    CalculatorMode.physics => const PhysicsScreen(),
    CalculatorMode.grapher => const GraphScreen(),
  };
}
