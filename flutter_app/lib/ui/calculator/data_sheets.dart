// Phase 7d-2: the full-height sheets of STAT (Statistics Editor), MATRIX and VECTOR (editors and the MatAns / VctAns screen) and
// TABLE (manual sections I, L, M, N). The Casio screens are replaced by sheets; the arithmetic is in the engine files.

import 'package:flutter/material.dart';

import '../../engine/casio/config.dart';
import '../../engine/casio/cval.dart';
import '../../engine/casio/engine.dart';
import '../../engine/casio/format.dart';
import '../../engine/casio/matrix.dart';
import '../../engine/casio/stat.dart';
import '../../engine/casio/table.dart';
import '../../state/casio_settings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'calculator_controller.dart';

CasioEngine get _eng => CasioRuntime.instance.engine;
CasioConfig get _cfg => _eng.config;

/// Text of a cell value for the editors.
String cellDisplay(CVal? v) => v == null ? '' : CasioFormatter(_cfg).first(v).display;

/// Parses a cell: empty is null; otherwise the value of the expression (the way the calculator would calculate it).
CVal? parseCell(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final v = _eng.evaluate(t, commit: false).value;
  if (v == null) throw kSyntaxError;
  return v;
}

Future<void> _sheet(BuildContext context, Widget Function(BuildContext) builder) {
  final t = M3Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.surfaceContainerHigh,
    barrierColor: t.scrim.withValues(alpha: 0.32),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => M3Theme(
      tokens: t,
      child: SizedBox(height: MediaQuery.of(ctx).size.height * 0.92, child: builder(ctx)),
    ),
  );
}

Widget _title(M3Tokens t, String text, VoidCallback onClose) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
      child: Row(children: [
        Expanded(child: Text(text, style: appText(size: 18, weight: FontWeight.w600, color: t.onSurface))),
        IconButton(key: const ValueKey('sheet-close'), icon: Icon(Icons.close, color: t.onSurfaceVariant), onPressed: onClose),
      ]),
    );

Widget _chip(M3Tokens t, String label, VoidCallback? onTap, {bool selected = false, Key? key}) => Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? t.primaryContainer : t.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: appText(
                  size: 13,
                  weight: FontWeight.w600,
                  color: onTap == null ? t.onSurfaceVariant : (selected ? t.onPrimaryContainer : t.onSurface))),
        ),
      ),
    );

Widget _field(M3Tokens t, TextEditingController c, {Key? key, String? hint, VoidCallback? onTap, ValueChanged<String>? onChanged, double? width}) {
  final f = TextField(
    key: key,
    controller: c,
    onTap: onTap,
    onChanged: onChanged,
    keyboardType: TextInputType.text,
    style: appText(size: 14, weight: FontWeight.w500, color: t.onSurface),
    decoration: InputDecoration(
      isDense: true,
      hintText: hint,
      filled: true,
      fillColor: t.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
  );
  return width == null ? f : SizedBox(width: width, child: f);
}

// ---------------------------------------------------------------------------------------------------------------------
// STAT

Future<void> showStatTypeDialog(BuildContext context, CalculatorController c) {
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('STAT', style: appText(size: 16, weight: FontWeight.w600, color: t.onSurface)),
            ),
            for (final (i, ty) in StatType.values.indexed)
              GestureDetector(
                key: ValueKey('stat-type-${ty.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(ctx).pop();
                  if (c.mode == CasioMode.stat) {
                    c.changeStatType(ty);
                    c.openStatEditor();
                  } else {
                    c.enterStat(ty);
                  }
                },
                child: Container(
                  color: c.mode == CasioMode.stat && c.statType == ty ? t.primaryContainer : null,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(children: [
                    Expanded(child: Text('${i + 1}  ${ty.title}', style: appText(size: 14, weight: FontWeight.w500, color: t.onSurface))),
                    Text(ty.paired ? 'x, y' : 'x', style: appText(size: 11, weight: FontWeight.w500, color: t.onSurfaceVariant)),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    ),
  );
}

Future<void> showStatEditor(BuildContext context, CalculatorController c) =>
    _sheet(context, (ctx) => StatEditor(controller: c, onClose: () => Navigator.of(ctx).pop()));

class StatEditor extends StatefulWidget {
  const StatEditor({super.key, required this.controller, required this.onClose});

  final CalculatorController controller;
  final VoidCallback onClose;

  @override
  State<StatEditor> createState() => _StatEditorState();
}

class _StatEditorState extends State<StatEditor> {
  late StatData _d = widget.controller.statData;
  late List<List<TextEditingController>> _cells = _build();
  int _sel = 0;
  String? _message;

  int get _cols => _d.type.paired ? (_d.freqColumn ? 3 : 2) : (_d.freqColumn ? 2 : 1);

  List<List<TextEditingController>> _build() => [
        for (var r = 0; r < _d.rows; r++)
          [
            TextEditingController(text: cellDisplay(_d.xs[r])),
            if (_d.type.paired) TextEditingController(text: cellDisplay(_d.ys[r])),
            if (_d.freqColumn) TextEditingController(text: cellDisplay(_d.fs[r])),
          ],
      ];

  void _dispose() {
    for (final row in _cells) {
      for (final c in row) {
        c.dispose();
      }
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _refresh() {
    _dispose();
    setState(() {
      _d = widget.controller.statData;
      _cells = _build();
      _message = null;
    });
  }

  void _edit(int r, int col, String text) {
    try {
      final v = parseCell(text);
      final isY = _d.type.paired && col == 1;
      final isF = _d.freqColumn && col == _cols - 1 && (col > 0);
      if (isF) {
        _d.fs[r] = v;
      } else if (isY) {
        _d.ys[r] = v;
      } else {
        _d.xs[r] = v;
      }
      setState(() => _message = null);
    } catch (e) {
      setState(() => _message = CasioEngine.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final heads = <String>['x', if (_d.type.paired) 'y', if (_d.freqColumn) 'FREQ'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(t, 'STAT  ${_d.type.title}', widget.onClose),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(children: [
          _chip(t, 'Type', () => showStatTypeDialog(context, widget.controller).then((_) => _refresh()), key: const ValueKey('stat-type')),
          _chip(t, 'Ins', () {
            _d.insertRow(_sel);
            _refresh();
          }, key: const ValueKey('stat-ins')),
          _chip(t, 'Del', () {
            _d.deleteRow(_sel);
            _refresh();
          }, key: const ValueKey('stat-del')),
          _chip(t, 'Del-A', () {
            _d.clear();
            _refresh();
          }, key: const ValueKey('stat-delall')),
        ]),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(_message!, key: const ValueKey('stat-msg'), style: appText(size: 13, weight: FontWeight.w600, color: t.error)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        child: Row(children: [
          SizedBox(width: 28, child: Text('', style: appText(size: 12, color: t.onSurfaceVariant))),
          for (final h in heads)
            Expanded(child: Text(h, style: appText(size: 12, weight: FontWeight.w700, color: t.onSurfaceVariant))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          key: const ValueKey('stat-rows'),
          itemCount: _d.rows,
          itemBuilder: (ctx, r) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
            child: Row(children: [
              SizedBox(width: 28, child: Text('${r + 1}', style: appText(size: 12, color: r == _sel ? t.primary : t.onSurfaceVariant))),
              for (var col = 0; col < _cols; col++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _field(t, _cells[r][col],
                        key: ValueKey('stat-cell-$r-$col'), onTap: () => _sel = r, onChanged: (s) {
                      _sel = r;
                      _edit(r, col, s);
                    }),
                  ),
                ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Text('Press the STAT keys on the Data tab to use the results. Rows without x are ignored.',
            style: appText(size: 12, color: t.onSurfaceVariant)),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// MATRIX and VECTOR

Future<void> showMatrixEditor(BuildContext context, CalculatorController c) =>
    _sheet(context, (ctx) => MatVecEditor(controller: c, vector: false, onClose: () => Navigator.of(ctx).pop()));

Future<void> showVectorEditor(BuildContext context, CalculatorController c) =>
    _sheet(context, (ctx) => MatVecEditor(controller: c, vector: true, onClose: () => Navigator.of(ctx).pop()));

class MatVecEditor extends StatefulWidget {
  const MatVecEditor({super.key, required this.controller, required this.vector, required this.onClose});

  final CalculatorController controller;
  final bool vector;
  final VoidCallback onClose;

  @override
  State<MatVecEditor> createState() => _MatVecEditorState();
}

class _MatVecEditorState extends State<MatVecEditor> {
  late String _name = widget.vector ? 'VctA' : 'MatA';
  List<TextEditingController> _cells = [];
  String? _message;

  MatVecStore get _s => widget.controller.matVec;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _disposeCells() {
    for (final c in _cells) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeCells();
    super.dispose();
  }

  List<CVal>? get _values => widget.vector ? _s.vecs[_name]?.cells : _s.mats[_name]?.cells;
  int get _rows => widget.vector ? (_s.vecs[_name]?.dim ?? 0) : (_s.mats[_name]?.rows ?? 0);
  int get _cols => widget.vector ? 1 : (_s.mats[_name]?.cols ?? 0);

  void _load() {
    _disposeCells();
    _cells = [for (final v in _values ?? const <CVal>[]) TextEditingController(text: cellDisplay(v))];
  }

  void _dim(int r, int c) {
    try {
      if (widget.vector) {
        _s.dimVector(_name, r);
      } else {
        _s.dimMatrix(_name, r, c);
      }
      setState(() {
        _load();
        _message = null;
      });
    } catch (e) {
      setState(() => _message = CasioEngine.messageOf(e));
    }
  }

  void _store() {
    try {
      final vals = [for (final c in _cells) parseCell(c.text) ?? CVal.int(0)];
      if (widget.vector) {
        _s.vecs[_name] = CVector(vals);
      } else {
        _s.mats[_name] = CMatrix(_rows, _cols, vals);
      }
      setState(() => _message = null);
    } catch (e) {
      setState(() => _message = CasioEngine.messageOf(e));
    }
  }

  void _sto() {
    try {
      if (widget.vector) {
        final a = _s.vctAns;
        if (a == null) throw const CasioError(CasioErrorKind.dimension);
        _s.copyVector(a, _name);
      } else {
        final a = _s.matAns;
        if (a == null) throw const CasioError(CasioErrorKind.dimension);
        _s.copyMatrix(a, _name);
      }
      setState(() {
        _load();
        _message = null;
      });
    } catch (e) {
      setState(() => _message = CasioEngine.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final names = widget.vector ? kVectorNames : kMatrixNames;
    final set = _values != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(t, widget.vector ? 'VECTOR' : 'MATRIX', widget.onClose),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(children: [
          for (final n in names)
            _chip(t, n, () {
              setState(() {
                _name = n;
                _load();
                _message = null;
              });
            }, selected: n == _name, key: ValueKey('mv-name-$n')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        child: Text(set ? '$_name  ${widget.vector ? 'Dim $_rows' : '$_rows×$_cols'}' : '$_name  Dim: not set',
            key: const ValueKey('mv-dim'), style: appText(size: 14, weight: FontWeight.w600, color: t.onSurface)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(children: [
          if (widget.vector)
            for (final d in [2, 3]) _chip(t, 'Dim $d', () => _dim(d, 1), selected: set && _rows == d, key: ValueKey('mv-dim-$d'))
          else
            for (final r in [1, 2, 3])
              for (final c in [1, 2, 3])
                _chip(t, '$r×$c', () => _dim(r, c), selected: set && _rows == r && _cols == c, key: ValueKey('mv-dim-$r-$c')),
        ]),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(_message!, key: const ValueKey('mv-msg'), style: appText(size: 13, weight: FontWeight.w600, color: t.error)),
        ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: set
              ? Column(children: [
                  for (var r = 0; r < _rows; r++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        for (var c = 0; c < _cols; c++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _field(t, _cells[r * _cols + c], key: ValueKey('mv-cell-$r-$c'), onChanged: (_) => _store()),
                            ),
                          ),
                      ]),
                    ),
                ])
              : Text('Choose a size to set up $_name.', style: appText(size: 13, color: t.onSurfaceVariant)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Wrap(children: [
          _chip(t, widget.vector ? 'VctAns ▸ $_name' : 'MatAns ▸ $_name', _sto, key: const ValueKey('mv-sto')),
        ]),
      ),
    ]);
  }
}

/// The result of a matrix / vector calculation (MatAns / VctAns) with the STO keys.
Future<void> showMatVecResult(BuildContext context, CalculatorController c) =>
    _sheet(context, (ctx) => MatVecResult(controller: c, onClose: () => Navigator.of(ctx).pop()));

class MatVecResult extends StatefulWidget {
  const MatVecResult({super.key, required this.controller, required this.onClose});

  final CalculatorController controller;
  final VoidCallback onClose;

  @override
  State<MatVecResult> createState() => _MatVecResultState();
}

class _MatVecResultState extends State<MatVecResult> {
  String? _message;

  void _sto(String name) {
    final c = widget.controller;
    try {
      final m = c.matrixResult;
      final v = c.vectorResult;
      if (m != null) {
        c.matVec.copyMatrix(m, name);
      } else if (v != null) {
        c.matVec.copyVector(v, name);
      }
      setState(() => _message = '$name ← ${m != null ? 'MatAns' : 'VctAns'}');
    } catch (e) {
      setState(() => _message = CasioEngine.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final m = widget.controller.matrixResult;
    final v = widget.controller.vectorResult;
    final isMat = m != null;
    final res = m ?? v;
    final texts = res == null ? const <String>[] : CasioMatVec.cellTexts(res, _cfg);
    final rows = isMat ? m.rows : (v?.dim ?? 0);
    final cols = isMat ? m.cols : 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(t, isMat ? 'MatAns' : 'VctAns', widget.onClose),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(children: [
            for (var r = 0; r < rows; r++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  for (var c = 0; c < cols; c++)
                    Expanded(
                      child: Text(texts[r * cols + c],
                          key: ValueKey('res-cell-$r-$c'),
                          textAlign: TextAlign.center,
                          style: appText(size: 18, weight: FontWeight.w600, color: t.onSurface)),
                    ),
                ]),
              ),
          ]),
        ),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(_message!, style: appText(size: 13, weight: FontWeight.w600, color: t.onSurfaceVariant)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Wrap(children: [
          for (final n in (isMat ? kMatrixNames : kVectorNames)) _chip(t, 'STO ▸ $n', () => _sto(n), key: ValueKey('res-sto-$n')),
        ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// TABLE

Future<void> showTableSheet(BuildContext context, CalculatorController c) =>
    _sheet(context, (ctx) => TableSheet(controller: c, onClose: () => Navigator.of(ctx).pop()));

class TableSheet extends StatefulWidget {
  const TableSheet({super.key, required this.controller, required this.onClose});

  final CalculatorController controller;
  final VoidCallback onClose;

  @override
  State<TableSheet> createState() => _TableSheetState();
}

class _TableSheetState extends State<TableSheet> {
  late final TextEditingController _f = TextEditingController(text: widget.controller.tableF);
  late final TextEditingController _g = TextEditingController(text: widget.controller.tableG);
  final TextEditingController _start = TextEditingController(text: '${kTableDefaultStart.toInt()}');
  final TextEditingController _end = TextEditingController(text: '${kTableDefaultEnd.toInt()}');
  final TextEditingController _step = TextEditingController(text: '${kTableDefaultStep.toInt()}');
  List<CasioTableRow>? _rows;
  String? _message;

  @override
  void dispose() {
    for (final c in [_f, _g, _start, _end, _step]) {
      c.dispose();
    }
    super.dispose();
  }

  /// A standalone lowercase x is the variable X.
  static String _fix(String s) => s.replaceAllMapped(RegExp(r'(?<![A-Za-z])x(?![A-Za-z])'), (_) => 'X');

  void _generate() {
    final fg = _cfg.tableFg;
    try {
      final s = parseCell(_start.text) ?? CVal.int(kTableDefaultStart.toInt());
      final e = parseCell(_end.text) ?? CVal.int(kTableDefaultEnd.toInt());
      final st = parseCell(_step.text) ?? CVal.int(kTableDefaultStep.toInt());
      widget.controller.setTableFunctions(_f.text, _g.text);
      final rows = CasioTable.generate(
        f: _fix(_f.text),
        g: _fix(_g.text),
        fg: fg,
        start: s,
        end: e,
        step: st,
        config: _cfg,
        memory: _eng.memory,
      );
      setState(() {
        _rows = rows;
        _message = null;
      });
    } catch (e) {
      setState(() {
        _rows = null;
        _message = CasioEngine.messageOf(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final fg = _cfg.tableFg;
    final rows = _rows;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(t, 'TABLE', widget.onClose),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(children: [
          Row(children: [
            SizedBox(width: 44, child: Text('f(x)=', style: appText(size: 13, weight: FontWeight.w600, color: t.onSurface))),
            Expanded(child: _field(t, _f, key: const ValueKey('table-f'), hint: 'e.g. x²+1÷2')),
          ]),
          if (fg) ...[
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(width: 44, child: Text('g(x)=', style: appText(size: 13, weight: FontWeight.w600, color: t.onSurface))),
              Expanded(child: _field(t, _g, key: const ValueKey('table-g'), hint: 'optional')),
            ]),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _labeled(t, 'Start', _start, 'table-start')),
            const SizedBox(width: 6),
            Expanded(child: _labeled(t, 'End', _end, 'table-end')),
            const SizedBox(width: 6),
            Expanded(child: _labeled(t, 'Step', _step, 'table-step')),
          ]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Wrap(children: [_chip(t, 'Generate  =', _generate, key: const ValueKey('table-go'))]),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Text(_message!, key: const ValueKey('table-msg'), style: appText(size: 13, weight: FontWeight.w600, color: t.error)),
        ),
      Expanded(
        child: rows == null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Rows: up to ${tableMaxRows(fg: fg)} for the table format in SETUP.',
                    style: appText(size: 12, color: t.onSurfaceVariant)),
              )
            : ListView(
                key: const ValueKey('table-rows'),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                children: [
                  Row(children: [
                    Expanded(child: Text('x', style: appText(size: 12, weight: FontWeight.w700, color: t.onSurfaceVariant))),
                    Expanded(child: Text('f(x)', style: appText(size: 12, weight: FontWeight.w700, color: t.onSurfaceVariant))),
                    if (fg && rows.any((r) => r.g != null || r.gError != null))
                      Expanded(child: Text('g(x)', style: appText(size: 12, weight: FontWeight.w700, color: t.onSurfaceVariant))),
                  ]),
                  for (final (i, r) in rows.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(child: Text(cellDisplay(r.x), key: ValueKey('table-x-$i'), style: appText(size: 14, color: t.onSurface))),
                        Expanded(
                            child: Text(CasioTable.cellText(r.f, r.fError, _cfg),
                                key: ValueKey('table-f-$i'), style: appText(size: 14, weight: FontWeight.w600, color: t.onSurface))),
                        if (fg && rows.any((r) => r.g != null || r.gError != null))
                          Expanded(
                              child: Text(CasioTable.cellText(r.g, r.gError, _cfg),
                                  key: ValueKey('table-g-$i'), style: appText(size: 14, weight: FontWeight.w600, color: t.onSurface))),
                      ]),
                    ),
                ],
              ),
      ),
    ]);
  }

  Widget _labeled(M3Tokens t, String label, TextEditingController c, String key) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: appText(size: 11, weight: FontWeight.w600, color: t.onSurfaceVariant)),
          const SizedBox(height: 2),
          _field(t, c, key: ValueKey(key)),
        ],
      );
}
