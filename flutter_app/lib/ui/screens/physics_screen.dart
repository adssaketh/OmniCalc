import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' show InputBorder, InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../engine/js_number.dart';
import '../../engine/physics.dart';
import '../../services/feedback_service.dart';
import '../../state/navigation_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../icons/lucide_icon.dart';
import '../shell/intrinsic_cache.dart';
import '../shell/swipeable_tab_container.dart';
import '../widgets/option_select.dart';
import '../widgets/pressable.dart';
import 'finance_widgets.dart' show emeraldColor, flexFor, measureText, orElse, parseFloatOr0;
import 'screen_utils.dart';

/// `PhysicsTab` of PhysicsScreen.tsx.
enum PhysicsTab { constants, projectile, relativity, quantum, em }

/// The tab strip of PhysicsScreen.tsx: label and lucide icon per tab, in order.
const List<({PhysicsTab tab, String label, LucideIconId icon})> physicsTabs = [
  (tab: PhysicsTab.constants, label: 'Constants', icon: LucideIconId.atom),
  (tab: PhysicsTab.projectile, label: 'Kinematics & Projectiles', icon: LucideIconId.orbit),
  (tab: PhysicsTab.relativity, label: 'Special Relativity', icon: LucideIconId.sparkles),
  (tab: PhysicsTab.quantum, label: 'Quantum & Waves', icon: LucideIconId.flame),
  (tab: PhysicsTab.em, label: 'Electromagnetism', icon: LucideIconId.zap),
];

/// `categories` of PhysicsScreen.tsx.
const List<String> physicsCategories = [
  'All',
  'Universal',
  'Mechanics',
  'Electromagnetism',
  'Quantum & Atomic',
  'Thermodynamics',
  'Astrophysics',
];

/// The value column of the constants table: `c.value >= 1e4 || (c.value <= 1e-3 && c.value !== 0) ? c.value.toExponential(6) : c.value`.
String formatConstantValue(double v) => (v >= 1e4 || (v <= 1e-3 && v != 0)) ? jsToExponential(v, 6) : jsToString(v);

/// The `filteredConstants` filter: category, then a case-insensitive substring match on name, symbol, id and unit.
List<PhysicalConstant> filterConstants(String query, String category) {
  final q = query.toLowerCase();
  return [
    for (final c in physicalConstants)
      if ((category == 'All' || c.category == category) &&
          (c.name.toLowerCase().contains(q) ||
              c.symbol.toLowerCase().contains(q) ||
              c.id.toLowerCase().contains(q) ||
              c.unit.toLowerCase().contains(q)))
        c,
  ];
}

/// The points of the trajectory `<path>` in the 400 x 120 SVG user space (`M`/`L` list). A point that is not a finite
/// number ends the path there: the browser stops drawing at the first bad number of a `d` string.
List<Offset> trajectorySvgPoints(ProjectileResult r) {
  final out = <Offset>[];
  if (r.trajectoryPoints.length <= 1) return out;
  for (final pt in r.trajectoryPoints) {
    final px = r.range > 0 ? (pt.x / r.range) * 380 + 10 : 10.0;
    final py = 115 - (r.maxHeight > 0 ? (pt.y / (r.maxHeight * 1.15)) * 105 : 0.0);
    if (!px.isFinite || !py.isFinite) break;
    out.add(Offset(px, py));
  }
  return out;
}

/// The apex `<circle>`: `cx = ((range * (timeToPeak / timeOfFlight)) / range) * 380 + 10` (10 when `range` is not above 0),
/// `cy = 115 - 105 / 1.15`.
Offset trajectoryApex(ProjectileResult r) {
  final cx = r.range > 0 ? ((r.range * (r.timeToPeak / r.timeOfFlight)) / r.range) * 380 + 10 : 10.0;
  return Offset(cx, 115 - (105 / 1.15));
}

/// Port of PhysicsScreen.tsx (Physics Lab): the constants table and the four solver tabs.
class PhysicsScreen extends StatefulWidget {
  const PhysicsScreen({super.key});

  @override
  State<PhysicsScreen> createState() => _PhysicsScreenState();
}

class _PhysicsScreenState extends State<PhysicsScreen> {
  PhysicsTab _active = PhysicsTab.constants;
  final TextEditingController _search = TextEditingController();
  String _category = 'All';
  String? _copiedId;
  Timer? _copyTimer;

  // 1. Projectile motion
  double _projV0 = 30;
  double _projAngle = 45;
  double _projH0 = 0;
  double _projG = 9.80665;

  // 2. Relativity
  double _relBeta = 0.8;
  double _relT0 = 10;
  double _relL0 = 100;
  double _relM0 = 1;

  // 3. Quantum / waves
  PhotonMode _quantumMode = PhotonMode.wavelength;
  double _quantumInput = 550;
  double _quantumPhi = 2.3;

  // 4. Electromagnetism
  double _emQ1 = 1e-6;
  double _emQ2 = 2e-6;
  double _emDist = 0.05;
  double _emB = 0.5;
  double _emVel = 2e6;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _sound(ClickType type) => playScreenSound(context, type);

  void _copy(String id, String text) {
    _sound(ClickType.op);
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedId = id);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copiedId = null);
    });
  }

  void _selectTab(String id) {
    _sound(ClickType.toggle);
    setState(() => _active = PhysicsTab.values.firstWhere((t) => t.name == id));
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final bp = Breakpoints.of(context);
    final tabs = [
      for (final f in physicsTabs)
        TabItem(
          id: f.tab.name,
          label: f.label,
          iconBuilder: (color, size) => LucideIcon(f.icon, color: color, size: size),
        ),
    ];

    final Widget body = switch (_active) {
      PhysicsTab.constants => _constantsTab(context, t, bp),
      PhysicsTab.projectile => _projectileTab(context, t, bp),
      PhysicsTab.relativity => _relativityTab(context, t, bp),
      PhysicsTab.quantum => _quantumTab(context, t, bp),
      PhysicsTab.em => _emTab(context, t, bp),
    };

    return CachedIntrinsicHeight(
      estimate: 760,
      measureNatural: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: bp.xl ? 1152 : 1024),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SwipeableTabContainer(
              tabs: tabs,
              activeTabId: _active.name,
              onSelectTab: _selectTab,
              child: Container(
                // `w-full relative rounded-3xl p-4 sm:p-7 overflow-hidden` on surface-container-low
                clipBehavior: Clip.hardEdge,
                padding: EdgeInsets.all(bp.pick(16.0, sm: 28.0)),
                decoration: BoxDecoration(color: t.surfaceContainerLow, borderRadius: const BorderRadius.all(Radius.circular(24))),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Shared pieces
  // -------------------------------------------------------------------------------------------------------------------

  /// A CSS grid with equal columns, rows as tall as their tallest cell, cells at the top.
  Widget _grid(int cols, double gap, List<Widget> cells) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += cols) {
      final row = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) row.add(SizedBox(width: gap));
        row.add(Expanded(child: i + j < cells.length ? cells[i + j] : const SizedBox.shrink()));
      }
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: row));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  /// `flex flex-col gap-6`.
  Widget _tabColumn(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          children[i],
        ],
      ],
    );
  }

  /// A number field with its label (the `<label>` + `<input type="number">` pair of the solver tabs).
  Widget _field(
    String key,
    String label,
    double value,
    double Function(String) parse,
    ValueChanged<double> onChanged,
  ) {
    return _PhysField(fieldKey: ValueKey(key), label: label, value: value, parse: parse, onChanged: onChanged);
  }

  /// One result: `text-xs font-sans` caption over a bold mono value (`mt-1`).
  Widget _result(
    M3Tokens t,
    String key,
    String caption,
    String value,
    Color color, {
    double size = 20,
    double lineHeight = 28,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12)),
        const SizedBox(height: 4),
        Text(
          value,
          key: ValueKey(key),
          style: appText(size: size, weight: FontWeight.w700, color: color, height: lineHeight / size, tabular: true),
        ),
      ],
    );
  }

  /// `grid ... gap-3 p-4 sm:p-5 rounded-[24px] font-mono` on surface-container.
  Widget _resultsPanel(M3Tokens t, Breakpoints bp, int cols, List<Widget> cells) {
    return Container(
      padding: EdgeInsets.all(bp.pick(16.0, sm: 20.0)),
      decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(24))),
      child: _grid(cols, 12, cells),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Tab 1: constants
  // -------------------------------------------------------------------------------------------------------------------

  Widget _constantsTab(BuildContext context, M3Tokens t, Breakpoints bp) {
    final filtered = filterConstants(_search.text, _category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _constantsHeader(context, t, bp),
        const SizedBox(height: 16),
        _constantsTable(context, t, filtered),
      ],
    );
  }

  TextStyle _chipStyle(M3Tokens t, bool selected) => appText(
        size: 12,
        weight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? t.onPrimary : t.onSurfaceVariant,
        height: 16 / 12,
      );

  Widget _chip(M3Tokens t, String cat) {
    final selected = _category == cat;
    return Pressable(
      key: ValueKey('constants-category-$cat'),
      onTap: () {
        _sound(ClickType.toggle);
        setState(() => _category = cat);
      },
      child: AnimatedContainer(
        duration: kTailwindDuration,
        curve: kTailwindEase,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.primary : t.surfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
        child: Text(cat, maxLines: 1, softWrap: false, style: _chipStyle(t, selected)),
      ),
    );
  }

  Widget _constantsHeader(BuildContext context, M3Tokens t, Breakpoints bp) {
    final search = _SearchBox(controller: _search);
    final chips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < physicsCategories.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _chip(t, physicsCategories[i]),
        ],
      ],
    );
    Widget scrollingChips() => SingleChildScrollView(
          key: const ValueKey('constants-chips'),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: chips,
        );

    // `flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pb-3 border-b`
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.outlineVariant))),
      child: bp.sm
          ? LayoutBuilder(
              builder: (context, box) {
                // The search box is `flex-1`, the chip strip keeps its own width and shrinks (scrolls) only when the
                // search box is down to its padding (`pl-10 pr-4` = 56 px, the input's minimum).
                var natural = 6.0 * (physicsCategories.length - 1);
                for (final c in physicsCategories) {
                  natural += 24 + measureText(context, c, _chipStyle(t, _category == c));
                }
                final avail = box.maxWidth - 12;
                final chipsW = math.min(natural, math.max(0.0, avail - 56));
                final searchW = avail - chipsW;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: searchW, child: search),
                    const SizedBox(width: 12),
                    SizedBox(width: chipsW, child: scrollingChips()),
                  ],
                );
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 12), scrollingChips()],
            ),
    );
  }

  Widget _constantsTable(BuildContext context, M3Tokens t, List<PhysicalConstant> rows) {
    final symbolStyle = appText(size: 14, weight: FontWeight.w700, color: t.primary, height: 20 / 14, tabular: true);
    final nameStyle = appText(size: 12, weight: FontWeight.w500, color: t.onSurface, height: 16 / 12);
    final descStyle = appText(size: 10, color: t.onSurfaceVariant, height: 4 / 3, tabular: true);
    final valueStyle = appText(size: 12, weight: FontWeight.w600, color: emeraldColor(t), height: 16 / 12, tabular: true);
    final unitStyle = appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true);
    final headStyle = appText(size: 12, weight: FontWeight.w700, color: t.onSurface, height: 16 / 12, tabular: true);
    final calcStyle = appText(size: 12, color: t.onPrimaryContainer, height: 16 / 12, tabular: true);
    const headers = ['Symbol', 'Constant Name', 'Value', 'Units', 'Actions'];
    const padX = 12.0;

    // Column widths, the way CSS `table-layout: auto` finds them: every column is as wide as its widest cell, except the
    // name column, which can shrink down to its longest word (its text wraps and the description is clipped to a line).
    final natural = List<double>.filled(5, 0);
    for (var i = 0; i < 5; i++) {
      natural[i] = measureText(context, headers[i], headStyle);
    }
    var nameMin = 0.0;
    for (final h in headers[1].split(' ')) {
      nameMin = math.max(nameMin, measureText(context, h, headStyle));
    }
    final calcW = 10 + 12 + 4 + measureText(context, 'Calc', calcStyle) + 10;
    for (final c in rows) {
      natural[0] = math.max(natural[0], measureText(context, c.symbol, symbolStyle));
      natural[1] = math.max(natural[1], math.max(measureText(context, c.name, nameStyle), measureText(context, c.description, descStyle)));
      natural[2] = math.max(natural[2], measureText(context, formatConstantValue(c.value), valueStyle));
      natural[3] = math.max(natural[3], measureText(context, c.unit, unitStyle));
      for (final w in c.name.split(' ')) {
        nameMin = math.max(nameMin, measureText(context, w, nameStyle));
      }
      for (final w in c.description.split(' ')) {
        nameMin = math.max(nameMin, measureText(context, w, descStyle));
      }
    }
    natural[4] = math.max(natural[4], 26 + 6 + calcW);
    for (var i = 0; i < 5; i++) {
      natural[i] += 2 * padX;
    }
    nameMin += 2 * padX;

    Widget cell(double w, Widget child) => SizedBox(
          width: w,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: padX, vertical: 10), child: child),
        );

    return Container(
      key: const ValueKey('constants-table'),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: t.surfaceContainerLowest, borderRadius: const BorderRadius.all(Radius.circular(22))),
      child: LayoutBuilder(
        builder: (context, box) {
          // `w-full min-w-[620px]`
          var tableW = math.max(box.maxWidth, 620.0);
          var total = 0.0;
          for (final w in natural) {
            total += w;
          }
          final widths = List<double>.from(natural);
          if (tableW >= total) {
            final extra = tableW - total;
            for (var i = 0; i < 5; i++) {
              widths[i] = natural[i] + extra * natural[i] / total;
            }
          } else {
            widths[1] = math.max(nameMin, natural[1] - (total - tableW));
            var sum = 0.0;
            for (final w in widths) {
              sum += w;
            }
            tableW = math.max(tableW, sum);
          }

          final header = Container(
            color: t.surfaceContainerHigh,
            child: Row(
              children: [
                cell(widths[0], Text(headers[0], style: headStyle)),
                cell(widths[1], Text(headers[1], style: headStyle)),
                cell(widths[2], Text(headers[2], style: headStyle)),
                cell(widths[3], Text(headers[3], style: headStyle)),
                cell(widths[4], Align(alignment: Alignment.centerRight, child: Text(headers[4], style: headStyle))),
              ],
            ),
          );

          Widget row(PhysicalConstant c, int index) {
            final copied = _copiedId == c.id;
            return Container(
              key: ValueKey('constant-row-${c.id}'),
              decoration: BoxDecoration(border: index == 0 ? null : Border(top: BorderSide(color: t.outlineVariant))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  cell(widths[0], Text(c.symbol, maxLines: 1, softWrap: false, style: symbolStyle)),
                  cell(
                    widths[1],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.name, style: nameStyle),
                        Text(c.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: descStyle),
                      ],
                    ),
                  ),
                  cell(
                    widths[2],
                    Text(formatConstantValue(c.value), key: ValueKey('constant-value-${c.id}'), maxLines: 1, softWrap: false, style: valueStyle),
                  ),
                  cell(widths[3], Text(c.unit, maxLines: 1, softWrap: false, style: unitStyle)),
                  cell(
                    widths[4],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Pressable(
                          key: ValueKey('constant-copy-${c.id}'),
                          onTap: () => _copy(c.id, jsToString(c.value)),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: t.surfaceContainerHigh, shape: BoxShape.circle),
                            child: LucideIcon(copied ? LucideIconId.check : LucideIconId.copy, color: copied ? emeraldColor(t) : t.onSurface, size: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Pressable(
                          key: ValueKey('constant-insert-${c.id}'),
                          onTap: () {
                            _sound(ClickType.op);
                            context.read<NavigationState>().selectResult(jsToString(c.value));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: t.primaryContainer, borderRadius: const BorderRadius.all(Radius.circular(999))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LucideIcon(LucideIconId.cornerDownLeft, color: t.onPrimaryContainer, size: 12),
                                const SizedBox(width: 4),
                                Text('Calc', style: calcStyle),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: tableW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.outlineVariant))),
                    child: header,
                  ),
                  for (var i = 0; i < rows.length; i++) row(rows[i], i),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Tab 2: projectile motion
  // -------------------------------------------------------------------------------------------------------------------

  Widget _projectileTab(BuildContext context, M3Tokens t, Breakpoints bp) {
    final r = PhysicsSolver.solveProjectile(_projV0, _projAngle, _projH0, _projG);
    final inputCols = bp.pick(1, sm: 2, md: 4);
    final statsStyle = appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true);
    const title = 'Trajectory Curve y(x)';
    final stats = 'Max H: ${jsToFixed(r.maxHeight, 2)} m · Range: ${jsToFixed(r.range, 2)} m';

    return _tabColumn([
      _grid(inputCols, 14, [
        _field('proj-v0', 'Launch Speed v₀ (m/s)', _projV0, parseFloatOr0, (v) => setState(() => _projV0 = v)),
        _field('proj-angle', 'Launch Angle θ (deg)', _projAngle, parseFloatOr0, (v) => setState(() => _projAngle = v)),
        _field('proj-h0', 'Initial Height h₀ (m)', _projH0, parseFloatOr0, (v) => setState(() => _projH0 = v)),
        _field('proj-g', 'Gravity g (m/s²)', _projG, (s) => orElse(jsParseFloat(s), 9.81), (v) => setState(() => _projG = v)),
      ]),
      // Trajectory card: `rounded-[24px] p-4 flex flex-col gap-2` on surface-container
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(24))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(flex: flexFor(measureText(context, title, statsStyle)), child: Text(title, style: statsStyle)),
                const SizedBox(width: 8),
                Flexible(
                  flex: flexFor(measureText(context, stats, statsStyle)),
                  child: Text(stats, key: const ValueKey('proj-stats'), textAlign: TextAlign.end, style: statsStyle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 144,
              child: CustomPaint(
                key: const ValueKey('trajectory-svg'),
                painter: _TrajectoryPainter(r, ground: t.outlineVariant, line: t.primary),
              ),
            ),
          ],
        ),
      ),
      _resultsPanel(t, bp, bp.pick(2, sm: 4), [
        _result(t, 'proj-range', 'Range R', '${jsToFixed(r.range, 2)} m', t.primary),
        _result(t, 'proj-max-height', 'Max Height H', '${jsToFixed(r.maxHeight, 2)} m', emeraldColor(t)),
        _result(t, 'proj-time', 'Flight Time T', '${jsToFixed(r.timeOfFlight, 2)} s', t.onSurface),
        _result(t, 'proj-impact', 'Impact Speed', '${jsToFixed(r.impactVelocity, 2)} m/s', t.tertiary),
      ]),
    ]);
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Tab 3: special relativity
  // -------------------------------------------------------------------------------------------------------------------

  Widget _relativityTab(BuildContext context, M3Tokens t, Breakpoints bp) {
    final r = PhysicsSolver.solveRelativity(_relBeta, _relT0, _relL0, _relM0);
    final inputCols = bp.pick(1, sm: 2, md: 4);

    return _tabColumn([
      _grid(inputCols, 14, [
        _field('rel-beta', 'Velocity β = v/c', _relBeta, parseFloatOr0, (v) => setState(() => _relBeta = v)),
        _field('rel-t0', 'Proper Time t₀ (s)', _relT0, parseFloatOr0, (v) => setState(() => _relT0 = v)),
        _field('rel-l0', 'Proper Length L₀ (m)', _relL0, parseFloatOr0, (v) => setState(() => _relL0 = v)),
        _field('rel-m0', 'Rest Mass m₀ (kg)', _relM0, parseFloatOr0, (v) => setState(() => _relM0 = v)),
      ]),
      _resultsPanel(t, bp, bp.pick(2, sm: 4), [
        _result(t, 'rel-gamma', 'Lorentz Factor γ', jsToFixed(r.gamma, 4), t.primary, size: 24, lineHeight: 32),
        _result(t, 'rel-time', 'Dilated Time t', '${jsToFixed(r.dilatedTime, 3)} s', emeraldColor(t)),
        _result(t, 'rel-length', 'Contracted Length L', '${jsToFixed(r.contractedLength, 3)} m', t.tertiary),
        _result(t, 'rel-momentum', 'Relativistic Momentum p', '${jsToExponential(r.momentum, 3)} kg·m/s', t.onSurface),
      ]),
      _resultsPanel(t, bp, bp.pick(1, sm: 3), [
        _result(t, 'rel-rest-energy', 'Rest Energy E₀ = m₀c²', '${jsToExponential(r.restEnergy, 4)} J', t.onSurface, size: 18),
        _result(t, 'rel-kinetic-energy', 'Kinetic Energy K = (γ - 1)m₀c²', '${jsToExponential(r.kineticEnergy, 4)} J', t.primary, size: 18),
        _result(t, 'rel-total-energy', 'Total Energy E = γm₀c²', '${jsToExponential(r.totalEnergy, 4)} J', emeraldColor(t), size: 18),
      ]),
    ]);
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Tab 4: quantum and waves
  // -------------------------------------------------------------------------------------------------------------------

  String get _quantumUnit => switch (_quantumMode) {
        PhotonMode.wavelength => 'nm',
        PhotonMode.frequency => 'Hz',
        PhotonMode.energyEv => 'eV',
      };

  Widget _quantumTab(BuildContext context, M3Tokens t, Breakpoints bp) {
    final r = PhysicsSolver.solvePhotonWave(_quantumMode, _quantumInput, _quantumPhi);
    final labelStyle = appText(size: 12, weight: FontWeight.w600, color: t.onSurfaceVariant, height: 16 / 12);

    final modeField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Input Mode', style: labelStyle)),
        OptionSelect(
          key: const ValueKey('q-mode'),
          value: _quantumMode.name,
          dialogTitle: 'Input Mode',
          fill: true,
          background: t.surfaceContainer,
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          options: const [
            SelectOption(value: 'wavelength', label: 'Wavelength λ (nm)'),
            SelectOption(value: 'frequency', label: 'Frequency f (Hz)'),
            SelectOption(value: 'energyEv', label: 'Photon Energy E (eV)'),
          ],
          onChanged: (v) {
            _sound(ClickType.toggle);
            setState(() => _quantumMode = PhotonMode.parse(v));
          },
        ),
      ],
    );

    return _tabColumn([
      _grid(bp.pick(1, sm: 3), 16, [
        modeField,
        _field('q-input', 'Value ($_quantumUnit)', _quantumInput, parseFloatOr0, (v) => setState(() => _quantumInput = v)),
        _field('q-phi', 'Work Function Φ (eV)', _quantumPhi, parseFloatOr0, (v) => setState(() => _quantumPhi = v)),
      ]),
      _resultsPanel(t, bp, bp.pick(2, sm: 4), [
        _result(t, 'q-wavelength', 'Wavelength λ', '${jsToFixed(r.wavelengthNm, 2)} nm', t.primary),
        _result(t, 'q-frequency', 'Frequency f', '${jsToExponential(r.frequencyHz, 3)} Hz', emeraldColor(t)),
        _result(t, 'q-energy', 'Photon Energy', '${jsToFixed(r.energyEv, 3)} eV', t.tertiary),
        _result(t, 'q-momentum', 'Photon Momentum', '${jsToExponential(r.momentum, 3)} kg·m/s', t.onSurface),
      ]),
      // Photoelectric effect card: `p-4 sm:p-5 rounded-[24px] flex flex-col gap-2 font-mono`
      Container(
        padding: EdgeInsets.all(bp.pick(16.0, sm: 20.0)),
        decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(24))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Photoelectric Effect Evaluation',
              style: appText(size: 12, weight: FontWeight.w600, color: t.onSurface, height: 16 / 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.outlineVariant))),
              child: _grid(bp.pick(1, sm: 3), 12, [
                _photoCell(t, 'q-cutoff', 'Cutoff Frequency f₀:', '${jsToExponential(r.cutoffFrequencyHz, 3)} Hz', t.onSurface),
                _photoCell(t, 'q-kmax', 'Max Kinetic Energy K_max:', '${jsToFixed(r.maxKineticEnergyEv, 3)} eV', emeraldColor(t)),
                _photoCell(t, 'q-stopping', 'Stopping Potential V₀:', '${jsToFixed(r.stoppingPotentialV, 3)} V', t.primary),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _photoCell(M3Tokens t, String key, String caption, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: appText(size: 12, color: t.onSurfaceVariant, height: 16 / 12, tabular: true)),
        Text(value, key: ValueKey(key), style: appText(size: 16, weight: FontWeight.w700, color: color, height: 24 / 16, tabular: true)),
      ],
    );
  }

  // -------------------------------------------------------------------------------------------------------------------
  // Tab 5: electromagnetism
  // -------------------------------------------------------------------------------------------------------------------

  Widget _emTab(BuildContext context, M3Tokens t, Breakpoints bp) {
    final r = PhysicsSolver.solveElectromagnetism(_emQ1, _emQ2, _emDist, _emB, 9.109e-31, _emVel);

    return _tabColumn([
      _grid(bp.pick(1, sm: 2, md: 3), 14, [
        _field('em-q1', 'Charge q₁ (Coulombs)', _emQ1, parseFloatOr0, (v) => setState(() => _emQ1 = v)),
        _field('em-q2', 'Charge q₂ (Coulombs)', _emQ2, parseFloatOr0, (v) => setState(() => _emQ2 = v)),
        _field('em-dist', 'Separation Distance r (m)', _emDist, (s) => orElse(jsParseFloat(s), 0.01), (v) => setState(() => _emDist = v)),
        _field('em-b', 'Magnetic Field B (Tesla)', _emB, parseFloatOr0, (v) => setState(() => _emB = v)),
        _field('em-vel', 'Particle Velocity v (m/s)', _emVel, parseFloatOr0, (v) => setState(() => _emVel = v)),
      ]),
      _resultsPanel(t, bp, bp.pick(1, sm: 3), [
        _result(t, 'em-force', 'Coulomb Force Fₑ', '${jsToExponential(r.coulombForceN, 3)} N', t.primary),
        _result(t, 'em-radius', 'Cyclotron Radius r', '${jsToExponential(r.cyclotronRadiusM, 3)} m', emeraldColor(t)),
        _result(t, 'em-freq', 'Cyclotron Frequency f_c', '${jsToExponential(r.cyclotronFreqHz, 3)} Hz', t.tertiary),
      ]),
    ]);
  }
}

// =====================================================================================================================
// Trajectory drawing
// =====================================================================================================================

/// The `<svg viewBox="0 0 400 120" preserveAspectRatio="none">`: user units are stretched separately in x and y, so strokes
/// and the apex dot are stretched with them, exactly as the browser draws it.
class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter(this.r, {required this.ground, required this.line});

  final ProjectileResult r;
  final Color ground;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 120);

    // Ground line
    canvas.drawLine(
      const Offset(0, 115),
      const Offset(400, 115),
      Paint()
        ..color = ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Trajectory path
    final pts = trajectorySvgPoints(r);
    if (pts.isNotEmpty) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Apex indicator
    final apex = trajectoryApex(r);
    if (apex.dx.isFinite && apex.dy.isFinite) {
      canvas.drawCircle(apex, 4, Paint()..color = const Color(0xFF10B981));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) => old.r != r || old.ground != ground || old.line != line;
}

// =====================================================================================================================
// Fields
// =====================================================================================================================

/// What the browser reports as `e.target.value` for text that is a valid number (anything else reads '').
final RegExp _validNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

/// `Number(s)` for the strings the field can hold ('' is 0).
double _jsNumber(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  return _validNumber.hasMatch(t) ? jsParseFloat(t) : double.nan;
}

/// `<label className="block text-xs font-semibold mb-1.5">` over
/// `<input type="number" className="w-full rounded-[18px] px-3.5 py-2.5 font-mono text-base focus:outline-none focus:ring-2
/// focus:ring-[var(--m3-primary)]">` on surface-container.
///
/// The state is a number and the input is controlled, so after each keystroke React writes the number back unless the text
/// already means the same number (clearing the field reads 0 and puts back "0", or the fallback of that field).
class _PhysField extends StatefulWidget {
  const _PhysField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.parse,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final double value;
  final double Function(String browserValue) parse;
  final ValueChanged<double> onChanged;

  @override
  State<_PhysField> createState() => _PhysFieldState();
}

class _PhysFieldState extends State<_PhysField> {
  late final TextEditingController _c = TextEditingController(text: jsToString(widget.value));
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PhysField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && _jsNumber(_c.text) != widget.value) _setText(jsToString(widget.value));
  }

  void _setText(String s) {
    _c.value = TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }

  void _onChanged(String text) {
    final bv = _validNumber.hasMatch(text.trim()) ? text.trim() : '';
    final v = widget.parse(bv);
    if ((v == 0 && bv.isEmpty) || _jsNumber(bv) != v) _setText(jsToString(v));
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final style = appText(size: 16, color: t.onSurface, height: 24 / 16, tabular: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.label, style: appText(size: 12, weight: FontWeight.w600, color: t.onSurfaceVariant, height: 16 / 12)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.surfaceContainer,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            // `focus:ring-2`
            boxShadow: _focused ? [BoxShadow(color: t.primary, spreadRadius: 2)] : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              key: widget.fieldKey,
              controller: _c,
              focusNode: _focus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9eE+\-.]'))],
              cursorColor: t.onSurface,
              style: style,
              onChanged: _onChanged,
              decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
            ),
          ),
        ),
      ],
    );
  }
}

/// The constants search box: `rounded-full pl-10 pr-4 py-2 text-xs font-mono` on surface-container with the search icon at
/// `left-3.5`, a primary focus ring and a placeholder at `opacity-60` of the browser's 50 % (so 30 % of the text colour).
class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.controller});

  final TextEditingController controller;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final style = appText(size: 12, color: t.onSurface, height: 16 / 12, tabular: true);
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        boxShadow: _focused ? [BoxShadow(color: t.primary, spreadRadius: 2)] : null,
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 16, 8),
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                key: const ValueKey('constants-search'),
                controller: widget.controller,
                focusNode: _focus,
                cursorColor: t.onSurface,
                style: style,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search constant (e.g. Planck, c, G, electron, gas)...',
                  hintMaxLines: 1,
                  hintStyle: style.copyWith(color: t.onSurface.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
          Positioned(left: 14, child: LucideIcon(LucideIconId.search, color: t.onSurfaceVariant, size: 16)),
        ],
      ),
    );
  }
}
