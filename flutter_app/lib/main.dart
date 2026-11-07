import 'package:flutter/material.dart';

// Phase 1 stub so the project compiles. The real shell arrives in Phase 3, the calculator screen in Phase 4.
void main() => runApp(const _Phase1App());

class _Phase1App extends StatelessWidget {
  const _Phase1App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('OmniCalc (Flutter) - Phase 1: engine only'))),
    );
  }
}
