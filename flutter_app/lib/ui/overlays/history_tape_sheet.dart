import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../editor/expr_doc.dart';
import '../../editor/rich_expression_view.dart';
import '../../state/history_store.dart';
import '../../state/navigation_state.dart';
import '../../theme/tokens.dart';
import '../calculator/calc_style.dart';
import '../icons/lucide_icon.dart';
import '../widgets/m3_sheet.dart';
import '../widgets/pressable.dart';

/// The categories of the filter chips (`activeFilter`).
enum HistoryFilter { all, calc, physics }

/// `isCalcItem`: calculator entries, including the old `standard` and `scientific` modes and entries without a mode.
bool isCalcHistoryItem(HistoryItem h) => h.mode == 'calc' || h.mode == 'standard' || h.mode == 'scientific' || h.mode == null;

/// `isPhysicsItem`.
bool isPhysicsHistoryItem(HistoryItem h) => h.mode == 'physics';

/// `new Date(ts).toLocaleTimeString(...)`, written the same way on every phone: 24-hour `HH:mm:ss` (see
/// PHASE5_NOTES.md, the web app follows the device locale).
String historyTimeText(int timestamp) {
  final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// `handleExport`: one line per entry, `[time] expression = result (mode)`.
String historyExportText(List<HistoryItem> items) =>
    items.map((h) => '[${historyTimeText(h.timestamp)}] ${h.expression} = ${h.result} (${h.mode ?? 'calc'})').join('\n');

/// Where the exported text goes. The web app starts a file download (`omnicalc-history-<ms>.txt`); the Android app
/// puts the text on the clipboard (see PHASE5_NOTES.md).
typedef HistoryExporter = Future<void> Function(String fileName, String text);

Future<void> clipboardHistoryExporter(String fileName, String text) => Clipboard.setData(ClipboardData(text: text));

/// Port of `HistoryTapeModal.tsx`: the "Recent Calculations" sheet (also what the Recents tab opens).
class HistoryTapeSheet extends StatefulWidget {
  const HistoryTapeSheet({super.key, this.exporter = clipboardHistoryExporter});

  final HistoryExporter exporter;

  @override
  State<HistoryTapeSheet> createState() => _HistoryTapeSheetState();
}

class _HistoryTapeSheetState extends State<HistoryTapeSheet> {
  // The web component stays mounted while the sheet is closed, so these survive closing and re-opening it.
  String? _copiedId;
  HistoryFilter _filter = HistoryFilter.all;
  bool _confirmClear = false;

  void _copy(HistoryItem item) {
    Clipboard.setData(ClipboardData(text: '${item.expression} = ${item.result}'));
    setState(() => _copiedId = item.id);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _copiedId == item.id) setState(() => _copiedId = null);
    });
  }

  void _export(List<HistoryItem> items) {
    widget.exporter('omnicalc-history-${DateTime.now().millisecondsSinceEpoch}.txt', historyExportText(items));
  }

  void _useResult(NavigationState nav, String value) {
    nav.selectResult(value);
    nav.setHistoryOpen(false);
  }

  void _useFormula(NavigationState nav, String expr) {
    nav.selectExpression(expr);
    nav.setHistoryOpen(false);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final nav = context.watch<NavigationState>();
    final store = context.watch<HistoryStore>();
    final history = store.items;
    final w = MediaQuery.sizeOf(context).width;

    final calcCount = history.where(isCalcHistoryItem).length;
    final physicsCount = history.where(isPhysicsHistoryItem).length;
    final shown = history.where((h) {
      switch (_filter) {
        case HistoryFilter.all:
          return true;
        case HistoryFilter.calc:
          return isCalcHistoryItem(h);
        case HistoryFilter.physics:
          return isPhysicsHistoryItem(h);
      }
    }).toList();

    final filters = <(HistoryFilter, String, int, LucideIconId)>[
      (HistoryFilter.all, 'All', history.length, LucideIconId.rotateCcw),
      (HistoryFilter.calc, 'Calculator', calcCount, LucideIconId.calculator),
      (HistoryFilter.physics, 'Physics', physicsCount, LucideIconId.atom),
    ];

    return M3Sheet(
      isOpen: nav.isHistoryOpen,
      onClose: () => nav.setHistoryOpen(false),
      label: 'Recent calculations',
      maxWidth: 576,
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.primaryContainer, borderRadius: const BorderRadius.all(Radius.circular(16))),
                child: LucideIcon(LucideIconId.rotateCcw, color: t.onPrimaryContainer, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Calculations',
                        style: calcText(size: 18, weight: FontWeight.w700, color: t.onSurface, lineHeight: 22.5)),
                    Text('${history.length} saved on this device',
                        style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (history.isNotEmpty) ...[
                    _IconButton(
                      key: const ValueKey('history-export'),
                      label: 'Export history as text',
                      icon: LucideIconId.download,
                      color: t.onSurfaceVariant,
                      onTap: () => _export(history),
                    ),
                    const SizedBox(width: 4),
                    if (_confirmClear)
                      Pressable(
                        key: const ValueKey('history-clear-confirm'),
                        onTap: () {
                          store.clear();
                          setState(() => _confirmClear = false);
                        },
                        child: Semantics(
                          button: true,
                          label: 'Confirm Clear All',
                          excludeSemantics: true,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: t.errorContainer, borderRadius: pillRadiusAll),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LucideIcon(LucideIconId.trash2, color: t.onErrorContainer, size: 16),
                                const SizedBox(width: 6),
                                Text('Clear All?',
                                    style: calcText(size: 12, weight: FontWeight.w700, color: t.onErrorContainer, lineHeight: 16)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      _IconButton(
                        key: const ValueKey('history-clear'),
                        label: 'Clear history tape',
                        icon: LucideIconId.trash2,
                        color: t.onSurfaceVariant,
                        onTap: () => setState(() => _confirmClear = true),
                      ),
                    const SizedBox(width: 4),
                  ],
                  _IconButton(
                    key: const ValueKey('history-close-x'),
                    label: 'Close Recents',
                    icon: LucideIconId.x,
                    color: t.onSurfaceVariant,
                    onTap: () => nav.setHistoryOpen(false),
                  ),
                ],
              ),
            ],
          ),
        ),
        // category filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Row(
            children: [
              for (final (i, f) in filters.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                GestureDetector(
                  key: ValueKey('history-filter-${f.$1.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _filter = f.$1),
                  child: Semantics(
                    button: true,
                    selected: _filter == f.$1,
                    excludeSemantics: true,
                    label: '${f.$2} (${f.$3})',
                    onTap: () => setState(() => _filter = f.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _filter == f.$1 ? t.primaryContainer : t.surfaceContainer,
                        borderRadius: pillRadiusAll,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LucideIcon(f.$4, color: _filter == f.$1 ? t.onPrimaryContainer : t.onSurfaceVariant, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${f.$2} (${f.$3})',
                            maxLines: 1,
                            style: calcText(
                              size: 12,
                              weight: FontWeight.w600,
                              color: _filter == f.$1 ? t.onPrimaryContainer : t.onSurfaceVariant,
                              lineHeight: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // history list
        Flexible(
          child: SingleChildScrollView(
            key: const ValueKey('history-list'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: shown.isEmpty
                ? _EmptyState(t: t)
                : Column(
                    children: [
                      for (final (i, item) in shown.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _HistoryCard(
                          key: ValueKey('history-item-${item.id}'),
                          item: item,
                          wide: w >= 640,
                          copied: _copiedId == item.id,
                          onUse: () => _useResult(nav, item.result),
                          onCopy: () => _copy(item),
                          onFormula: () => _useFormula(nav, item.expression),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        // footer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text('Tap any item to load into calculator',
                    style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16)),
              ),
              const SizedBox(width: 8),
              Pressable(
                key: const ValueKey('history-close'),
                onTap: () => nav.setHistoryOpen(false),
                child: Semantics(
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: t.primaryContainer, borderRadius: pillRadiusAll),
                    child: Text('Close',
                        style: calcText(size: 12, weight: FontWeight.w600, color: t.onPrimaryContainer, lineHeight: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const BorderRadius pillRadiusAll = BorderRadius.all(Radius.circular(9999));

/// `iconButton`: 40 px circle, `active:scale-90 transition-transform`.
class _IconButton extends StatelessWidget {
  const _IconButton({super.key, required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final LucideIconId icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: SizedBox(width: 40, height: 40, child: Center(child: LucideIcon(icon, color: color, size: 20))),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});

  final M3Tokens t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(16))),
              child: Opacity(opacity: 0.6, child: LucideIcon(LucideIconId.rotateCcw, color: t.onSurfaceVariant, size: 24)),
            ),
            const SizedBox(height: 8),
            Text('No calculations here yet',
                textAlign: TextAlign.center, style: calcText(size: 14, weight: FontWeight.w600, color: t.onSurface, lineHeight: 20)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Calculate expressions in the Calculator or Physics Lab and your recent history will appear here instantly.',
                textAlign: TextAlign.center,
                style: calcText(size: 12, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({
    super.key,
    required this.item,
    required this.wide,
    required this.copied,
    required this.onUse,
    required this.onCopy,
    required this.onFormula,
  });

  final HistoryItem item;
  final bool wide;
  final bool copied;
  final VoidCallback onUse;
  final VoidCallback onCopy;
  final VoidCallback onFormula;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final item = widget.item;
    final mode = item.mode ?? 'calc';
    final rich = item.rich;

    final expression = rich != null
        ? Align(
            alignment: Alignment.centerLeft,
            child: RichExpressionView(
              doc: ExprDoc.fromJson(rich) ?? ExprDoc.plain(item.expression),
              fit: false,
              max: 14,
              lineHeightPx: 20,
              weight: FontWeight.w400,
              letterSpacingEm: 0.025,
              color: t.onSurface,
            ),
          )
        : Text(
            item.expression,
            maxLines: 1,
            softWrap: false,
            style: calcText(size: 14, weight: FontWeight.w400, color: t.onSurface, lineHeight: 20, letterSpacingEm: 0.025, mono: true),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onUse,
      child: Semantics(
        button: true,
        label: 'Tap to load this result into calculator',
        child: AnimatedScale(
          scale: _down ? 0.985 : 1,
          duration: kTailwindDuration,
          curve: kTailwindEase,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: const BorderRadius.all(Radius.circular(24))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(historyTimeText(item.timestamp),
                        style: calcText(size: 11, weight: FontWeight.w400, color: t.onSurfaceVariant, lineHeight: 16.5, mono: true)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: t.surfaceContainerHigh, borderRadius: pillRadiusAll),
                      child: Text(
                        mode.toUpperCase(),
                        style: calcText(size: 10, weight: FontWeight.w600, color: t.primary, lineHeight: 15, letterSpacingEm: 0.05),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: expression),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '= ${item.result}',
                          style: calcText(
                            size: widget.wide ? 18 : 16,
                            weight: FontWeight.w700,
                            color: t.primary,
                            lineHeight: widget.wide ? 28 : 24,
                            letterSpacingEm: -0.025,
                            mono: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Pressable(
                            key: ValueKey('history-copy-${item.id}'),
                            onTap: widget.onCopy,
                            pressedScale: 0.9,
                            child: Semantics(
                              button: true,
                              label: 'Copy calculation',
                              excludeSemantics: true,
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: t.surfaceContainerHigh, shape: BoxShape.circle),
                                child: widget.copied
                                    ? const LucideIcon(LucideIconId.check, color: Color(0xFF10B981), size: 16)
                                    : LucideIcon(LucideIconId.copy, color: t.onSurfaceVariant, size: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Pressable(
                            key: ValueKey('history-formula-${item.id}'),
                            onTap: widget.onFormula,
                            child: Semantics(
                              button: true,
                              label: 'Load entire formula into calculator',
                              excludeSemantics: true,
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(color: t.surfaceContainerHighest, borderRadius: pillRadiusAll),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Opacity(opacity: 0.7, child: LucideIcon(LucideIconId.fileText, color: t.onSurface, size: 14)),
                                    const SizedBox(width: 6),
                                    Text('Formula',
                                        style: calcText(size: 11, weight: FontWeight.w600, color: t.onSurface, lineHeight: 16.5)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Pressable(
                            key: ValueKey('history-use-${item.id}'),
                            onTap: widget.onUse,
                            child: Semantics(
                              button: true,
                              label: 'Load result value into calculator',
                              excludeSemantics: true,
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(color: t.primary, borderRadius: pillRadiusAll),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LucideIcon(LucideIconId.cornerDownLeft, color: t.onPrimary, size: 14),
                                    const SizedBox(width: 6),
                                    Text('Use', style: calcText(size: 12, weight: FontWeight.w700, color: t.onPrimary, lineHeight: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
