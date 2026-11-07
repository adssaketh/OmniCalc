import 'package:flutter/material.dart';

import '../../engine/casio/complex.dart';
import '../../engine/casio/config.dart';
import '../../engine/casio/cval.dart';
import '../../engine/casio/eqn.dart';
import '../../engine/casio/engine.dart';
import '../../state/casio_settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'calculator_controller.dart';
import 'data_sheets.dart';

/// The MODE menu (manual p.9): COMP, CMPLX, BASE-N, EQN, STAT, MATRIX, VECTOR and TABLE.
Future<void> showModeMenu(BuildContext context, CalculatorController c) {
  final t = M3Theme.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: t.scrim.withValues(alpha: 0.32),
    builder: (ctx) => M3Theme(
      tokens: t,
      child: Dialog(
        backgroundColor: t.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ModeMenu(
            controller: c,
            onPick: (m) {
              Navigator.of(ctx).pop();
              switch (m) {
                case CasioMode.matrix:
                  c.enterMatrix();
                case CasioMode.vector:
                  c.enterVector();
                case CasioMode.table:
                  c.enterTable();
                default:
                  c.setMode(m);
              }
            },
            onStat: () {
              Navigator.of(ctx).pop();
              showStatTypeDialog(context, c);
            },
            onEqn: () {
              Navigator.of(ctx).pop();
              showEqnDialog(context);
            },
          ),
        ),
      ),
    ),
  );
}

class ModeMenu extends StatelessWidget {
  const ModeMenu({super.key, required this.controller, required this.onPick, required this.onEqn, this.onStat});

  final CalculatorController controller;
  final void Function(CasioMode) onPick;
  final VoidCallback onEqn;
  final VoidCallback? onStat;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    Widget item(String key, String label, String sub, {VoidCallback? onTap, bool selected = false}) {
      final enabled = onTap != null;
      return GestureDetector(
        key: ValueKey(key),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: selected ? t.primaryContainer : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: appText(
                      size: 14,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: enabled ? (selected ? t.onPrimaryContainer : t.onSurface) : t.onSurfaceVariant)),
            ),
            Text(sub, style: appText(size: 11, weight: FontWeight.w500, color: t.onSurfaceVariant)),
          ]),
        ),
      );
    }

    final m = controller.mode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text('MODE', style: appText(size: 16, weight: FontWeight.w600, color: t.onSurface)),
        ),
        item('mode-comp', '1  COMP', 'normal calculations', selected: m == CasioMode.comp, onTap: () => onPick(CasioMode.comp)),
        item('mode-cmplx', '2  CMPLX', 'complex numbers', selected: m == CasioMode.cmplx, onTap: () => onPick(CasioMode.cmplx)),
        item('mode-base', '3  BASE-N', 'DEC HEX BIN OCT', selected: m == CasioMode.baseN, onTap: () => onPick(CasioMode.baseN)),
        item('mode-eqn', '4  EQN', 'equations', onTap: onEqn),
        item('mode-stat', '5  STAT', 'statistics', selected: m == CasioMode.stat, onTap: onStat),
        item('mode-matrix', '6  MATRIX', 'MatA MatB MatC', selected: m == CasioMode.matrix, onTap: () => onPick(CasioMode.matrix)),
        item('mode-vector', '7  VECTOR', 'VctA VctB VctC', selected: m == CasioMode.vector, onTap: () => onPick(CasioMode.vector)),
        item('mode-table', '8  TABLE', 'f(x), g(x)', selected: m == CasioMode.table, onTap: () => onPick(CasioMode.table)),
        const SizedBox(height: 12),
      ],
    );
  }
}

Future<void> showEqnDialog(BuildContext context) {
  final t = M3Theme.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: t.scrim.withValues(alpha: 0.32),
    builder: (ctx) => M3Theme(
      tokens: t,
      child: Dialog(
        backgroundColor: t.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: EqnPanel(onClose: () => Navigator.of(ctx).pop()),
        ),
      ),
    ),
  );
}

/// The EQN screens: the type menu, the Coefficient Editor, and the solution lines (one per `=`, scrollable).
class EqnPanel extends StatefulWidget {
  const EqnPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<EqnPanel> createState() => _EqnPanelState();
}

class _EqnPanelState extends State<EqnPanel> {
  EqnType _type = EqnType.simul2;
  late List<TextEditingController> _cells = _newCells();
  List<String>? _solution;
  String? _message;

  List<TextEditingController> _newCells() =>
      [for (var i = 0; i < _type.rows * _type.cols; i++) TextEditingController(text: '0')];

  @override
  void dispose() {
    for (final c in _cells) {
      c.dispose();
    }
    super.dispose();
  }

  void _setType(EqnType t) {
    // changing the equation type sets every coefficient to zero (manual p.71)
    for (final c in _cells) {
      c.dispose();
    }
    setState(() {
      _type = t;
      _cells = _newCells();
      _solution = null;
      _message = null;
    });
  }

  void _solve() {
    final cfg = CasioRuntime.instance.engine.config;
    final cx = CasioComplexEngine(CasioMemory());
    try {
      final coef = <CVal>[for (final c in _cells) cx.evaluateReal(c.text.trim().isEmpty ? '0' : c.text, cfg)];
      final lines = CasioEqn.solve(_type, coef);
      final out = <String>[];
      for (final l in lines) {
        final o = cx.show(l.value, cfg.copyWith(complexFormat: CasioComplexFormat.rect));
        var text = o.forms.first.text;
        if (l.noSqrt && text.contains('√')) text = o.forms.last.text;
        out.add('${l.label} $text');
      }
      setState(() {
        _solution = out;
        _message = null;
      });
    } on EqnMessage catch (e) {
      setState(() {
        _solution = null;
        _message = e.text;
      });
    } catch (e) {
      setState(() {
        _solution = null;
        _message = CasioEngine.messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final names = <String>['a', 'b', 'c', 'd'];
    String cellLabel(int r, int c) {
      switch (_type) {
        case EqnType.simul2:
        case EqnType.simul3:
          final n = _type.rows;
          if (c < n) return '${names[c]}${r + 1}';
          return '${names[n]}${r + 1}';
        case EqnType.quadratic:
        case EqnType.cubic:
          return names[c];
      }
    }

    Widget typeChip(EqnType ty) => GestureDetector(
          key: ValueKey('eqn-type-${ty.name}'),
          onTap: () => _setType(ty),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ty == _type ? t.primaryContainer : t.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(ty.title,
                style: appText(size: 12, weight: FontWeight.w600, color: ty == _type ? t.onPrimaryContainer : t.onSurface)),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EQN', style: appText(size: 16, weight: FontWeight.w600, color: t.onSurface)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final ty in EqnType.values) typeChip(ty)]),
          const SizedBox(height: 14),
          for (var r = 0; r < _type.rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                for (var c = 0; c < _type.cols; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextField(
                        key: ValueKey('eqn-cell-$r-$c'),
                        controller: _cells[r * _type.cols + c],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: InputDecoration(labelText: cellLabel(r, c), isDense: true),
                        style: appText(size: 14, weight: FontWeight.w500, color: t.onSurface),
                      ),
                    ),
                  ),
              ]),
            ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: GestureDetector(
                key: const ValueKey('eqn-solve'),
                onTap: _solve,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Text('Solve', style: appText(size: 14, weight: FontWeight.w700, color: t.onPrimary))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              key: const ValueKey('eqn-close'),
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: BorderRadius.circular(20)),
                child: Text('Close', style: appText(size: 14, weight: FontWeight.w600, color: t.onSurface)),
              ),
            ),
          ]),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, key: const ValueKey('eqn-message'), style: appText(size: 14, weight: FontWeight.w600, color: t.error)),
          ],
          if (_solution != null) ...[
            const SizedBox(height: 12),
            for (final line in _solution!)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, key: ValueKey('eqn-line-$line'), style: appText(size: 15, weight: FontWeight.w600, color: t.onSurface)),
              ),
          ],
        ],
      ),
    );
  }
}
