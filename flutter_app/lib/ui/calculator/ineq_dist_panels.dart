// The INEQ and DIST screens of the MODE menu (Phase 7e, manual p.82-84 and p.87-91). Like EQN they open as dialogs in the
// app's sheet style: a type menu, the Coefficient Editor (INEQ) or the variable inputs / List screen (DIST), and the answer.

import 'package:flutter/material.dart';

import '../../engine/casio/complex.dart';
import '../../engine/casio/config.dart';
import '../../engine/casio/cval.dart';
import '../../engine/casio/dist.dart';
import '../../engine/casio/engine.dart';
import '../../engine/casio/format.dart';
import '../../engine/casio/ineq.dart';
import '../../engine/js_number.dart';
import '../../state/casio_settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

Future<void> _showPanel(BuildContext context, Widget Function(VoidCallback close) build) {
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
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: build(() => Navigator.of(ctx).pop())),
      ),
    ),
  );
}

Future<void> showIneqDialog(BuildContext context) => _showPanel(context, (close) => IneqPanel(onClose: close));

Future<void> showDistDialog(BuildContext context) => _showPanel(context, (close) => DistPanel(onClose: close));

Widget _chip(M3Tokens t, Key key, String label, bool on, VoidCallback tap) => GestureDetector(
      key: key,
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: on ? t.primaryContainer : t.surfaceContainer, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: appText(size: 12, weight: FontWeight.w600, color: on ? t.onPrimaryContainer : t.onSurface)),
      ),
    );

Widget _button(M3Tokens t, Key key, String label, VoidCallback tap, {bool primary = false, EdgeInsets? pad}) => GestureDetector(
      key: key,
      onTap: tap,
      child: Container(
        padding: pad ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(color: primary ? t.primary : t.surfaceContainer, borderRadius: BorderRadius.circular(20)),
        child: Center(
            child: Text(label, style: appText(size: 14, weight: primary ? FontWeight.w700 : FontWeight.w600, color: primary ? t.onPrimary : t.onSurface))),
      ),
    );

/// A calculator value typed into a cell: the Casio engine reads it (fractions, √, π and variables work), blank is 0.
CVal _cell(String text, CasioConfig cfg) => CasioComplexEngine(CasioRuntime.instance.engine.memory).evaluateReal(text.trim().isEmpty ? '0' : text, cfg);

// ----- INEQ ---------------------------------------------------------------------------------------------------------------

class IneqPanel extends StatefulWidget {
  const IneqPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<IneqPanel> createState() => _IneqPanelState();
}

class _IneqPanelState extends State<IneqPanel> {
  IneqType _type = IneqType.quadratic;
  IneqRel _rel = IneqRel.lt;
  late List<TextEditingController> _cells = _newCells();
  List<String>? _lines;
  String? _error;

  List<TextEditingController> _newCells() => [for (var i = 0; i < _type.cols; i++) TextEditingController(text: '0')];

  @override
  void dispose() {
    for (final c in _cells) {
      c.dispose();
    }
    super.dispose();
  }

  /// Changing the inequality type sets every coefficient to zero (manual p.83).
  void _setType(IneqType t) {
    for (final c in _cells) {
      c.dispose();
    }
    setState(() {
      _type = t;
      _cells = _newCells();
      _lines = null;
      _error = null;
    });
  }

  void _clearCells() {
    for (final c in _cells) {
      c.text = '0';
    }
    setState(() {
      _lines = null;
      _error = null;
    });
  }

  void _solve() {
    final cfg = CasioRuntime.instance.engine.config;
    final cx = CasioComplexEngine(CasioMemory());
    try {
      final coef = <CVal>[for (final c in _cells) _cell(c.text, cfg)];
      final res = CasioIneq.solve(_type, _rel, coef);
      final rect = cfg.copyWith(complexFormat: CasioComplexFormat.rect);
      String fmt(CVal v) => cx.show(CComplex(v), rect).forms.first.text;
      setState(() {
        _lines = res.lines(fmt);
        _error = null;
      });
    } catch (e) {
      setState(() {
        _lines = null;
        _error = CasioEngine.messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final names = <String>['a', 'b', 'c', 'd'];
    final relText = _type == IneqType.quadratic ? 'aX²+bX+c' : 'aX³+bX²+cX+d';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('INEQ', style: appText(size: 16, weight: FontWeight.w600, color: t.onSurface)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final ty in IneqType.values) _chip(t, ValueKey('ineq-type-${ty.name}'), ty.title, ty == _type, () => _setType(ty)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in IneqRel.values)
              _chip(t, ValueKey('ineq-rel-${r.name}'), '$relText ${r.symbol} 0', r == _rel, () => setState(() {
                    _rel = r;
                    _lines = null;
                    _error = null;
                  })),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            for (var c = 0; c < _type.cols; c++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextField(
                    key: ValueKey('ineq-cell-$c'),
                    controller: _cells[c],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(labelText: names[c], isDense: true),
                    style: appText(size: 14, weight: FontWeight.w500, color: t.onSurface),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _button(t, const ValueKey('ineq-solve'), 'Solve', _solve, primary: true, pad: const EdgeInsets.symmetric(vertical: 12))),
            const SizedBox(width: 10),
            _button(t, const ValueKey('ineq-clear'), 'AC', _clearCells),
            const SizedBox(width: 10),
            _button(t, const ValueKey('ineq-close'), 'Close', widget.onClose),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const ValueKey('ineq-message'), style: appText(size: 14, weight: FontWeight.w600, color: t.error)),
          ],
          if (_lines != null) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _lines!.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(_lines![i], key: ValueKey('ineq-line-$i'), style: appText(size: 15, weight: FontWeight.w600, color: t.onSurface)),
              ),
          ],
        ],
      ),
    );
  }
}

// ----- DIST ---------------------------------------------------------------------------------------------------------------

class DistPanel extends StatefulWidget {
  const DistPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<DistPanel> createState() => _DistPanelState();
}

class _DistPanelState extends State<DistPanel> {
  DistType _type = DistType.normalPd;

  /// The `x` of the four list types: a single value ("Var") or the List screen.
  bool _useList = false;
  late List<TextEditingController> _vars = _newVars();
  final List<TextEditingController> _samples = <TextEditingController>[TextEditingController(text: '0')];
  String? _single;
  List<String>? _listResults;
  String? _error;

  List<TextEditingController> _newVars() => [for (var i = 0; i < _type.variables.length; i++) TextEditingController(text: '0')];

  @override
  void dispose() {
    for (final c in _vars) {
      c.dispose();
    }
    for (final c in _samples) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetResults() {
    _single = null;
    _listResults = null;
    _error = null;
  }

  void _setType(DistType ty) {
    for (final c in _vars) {
      c.dispose();
    }
    setState(() {
      _type = ty;
      _vars = _newVars();
      if (!ty.hasList) _useList = false;
      _resetResults();
    });
  }

  String _show(double v, {int? significant}) {
    final cfg = CasioRuntime.instance.engine.config;
    var d = v;
    if (significant != null) d = jsParseFloat(jsToPrecision(v, significant));
    return CasioFormatter(cfg).first(CVal.dec(d)).display;
  }

  void _calculate() {
    final cfg = CasioRuntime.instance.engine.config;
    try {
      final vars = <double>[for (final c in _vars) _cell(c.text, cfg).v];
      if (_type.hasList && _useList) {
        // the List screen: one result per sample, `ERROR` in the Ans column for a value out of range (manual p.90-91)
        final xs = <double>[for (final c in _samples) _cell(c.text, cfg).v];
        final out = <String>[];
        for (final x in xs) {
          try {
            // the first variable is the sample, the others come from the input screens
            out.add(_show(CasioDist.compute(_type, <double>[x, ...vars.sublist(1)]), significant: 5));
          } catch (_) {
            out.add('ERROR');
          }
        }
        setState(() {
          _resetResults();
          _listResults = out;
        });
        return;
      }
      final v = CasioDist.compute(_type, vars);
      // a result in parameter (Var) format is stored in Ans (manual p.90)
      CasioRuntime.instance.engine.memory.setAns(CVal.dec(v));
      setState(() {
        _resetResults();
        _single = _show(v);
      });
    } catch (e) {
      setState(() {
        _resetResults();
        _error = CasioEngine.messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    Widget field(Key key, TextEditingController c, String label) => TextField(
          key: key,
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: label, isDense: true),
          style: appText(size: 14, weight: FontWeight.w500, color: t.onSurface),
        );

    final varFields = <Widget>[];
    for (var i = 0; i < _type.variables.length; i++) {
      if (i == 0 && _type.hasList && _useList) continue; // x comes from the List screen
      varFields.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: field(ValueKey('dist-var-$i'), _vars[i], _type.variables[i]),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('DIST', style: appText(size: 16, weight: FontWeight.w600, color: t.onSurface)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final ty in DistType.values) _chip(t, ValueKey('dist-type-${ty.name}'), ty.title, ty == _type, () => _setType(ty)),
          ]),
          if (_type.hasList) ...[
            const SizedBox(height: 10),
            Row(children: [
              _chip(t, const ValueKey('dist-mode-var'), 'Var', !_useList, () => setState(() {
                    _useList = false;
                    _resetResults();
                  })),
              const SizedBox(width: 8),
              _chip(t, const ValueKey('dist-mode-list'), 'List', _useList, () => setState(() {
                    _useList = true;
                    _resetResults();
                  })),
            ]),
          ],
          const SizedBox(height: 14),
          ...varFields,
          if (_type.hasList && _useList) ...[
            Text('x  (up to $kDistListMax samples)', style: appText(size: 12, weight: FontWeight.w600, color: t.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (var i = 0; i < _samples.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: field(ValueKey('dist-sample-$i'), _samples[i], 'x${i + 1}')),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: Text(
                      _listResults != null && i < _listResults!.length ? _listResults![i] : '',
                      key: ValueKey('dist-result-$i'),
                      style: appText(size: 14, weight: FontWeight.w600, color: _listResults?[i] == 'ERROR' ? t.error : t.onSurface),
                    ),
                  ),
                ]),
              ),
            Row(children: [
              _button(t, const ValueKey('dist-ins'), 'Ins', () {
                if (_samples.length >= kDistListMax) return;
                setState(() {
                  _samples.add(TextEditingController(text: '0'));
                  _resetResults();
                });
              }, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              const SizedBox(width: 8),
              _button(t, const ValueKey('dist-del'), 'Del', () {
                if (_samples.length <= 1) return;
                setState(() {
                  _samples.removeLast().dispose();
                  _resetResults();
                });
              }, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              const SizedBox(width: 8),
              _button(t, const ValueKey('dist-delall'), 'Del-A', () {
                setState(() {
                  while (_samples.length > 1) {
                    _samples.removeLast().dispose();
                  }
                  _samples.first.text = '0';
                  _resetResults();
                });
              }, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            ]),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(child: _button(t, const ValueKey('dist-calc'), '=', _calculate, primary: true, pad: const EdgeInsets.symmetric(vertical: 12))),
            const SizedBox(width: 10),
            _button(t, const ValueKey('dist-close'), 'Close', widget.onClose),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const ValueKey('dist-message'), style: appText(size: 14, weight: FontWeight.w600, color: t.error)),
          ],
          if (_single != null) ...[
            const SizedBox(height: 12),
            Text(_single!, key: const ValueKey('dist-result'), style: appText(size: 18, weight: FontWeight.w700, color: t.onSurface)),
          ],
        ],
      ),
    );
  }
}
