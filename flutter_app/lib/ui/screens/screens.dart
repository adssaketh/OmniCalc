import 'package:flutter/widgets.dart';

import '../../state/navigation_state.dart';
import '../calculator/calculator_screen.dart';
import '../shell/app_shell.dart' show placeholderScreen;
import 'converter_screen.dart';

/// Screen builder of the shell: one screen per mode. Modes whose screen has not been ported yet still show the
/// stand-in from the shell.
Widget appScreenBuilder(BuildContext context, CalculatorMode mode) {
  return switch (mode) {
    CalculatorMode.standard || CalculatorMode.scientific => const CalculatorScreen(),
    CalculatorMode.converter => const ConverterScreen(),
    _ => placeholderScreen(context, mode),
  };
}
