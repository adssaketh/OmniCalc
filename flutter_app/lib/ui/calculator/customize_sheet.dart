import 'package:flutter/material.dart';

import '../../state/drawer_layout.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'advanced_keys.dart';
import 'calculator_controller.dart';

/// "Customize" of the Advanced Scientific Operations drawer: drag the pills (tabs) and the keys of each tab into the order
/// you want. Saved on the phone; Reset puts everything back.
Future<void> showCustomizeDrawerSheet(BuildContext context, CalculatorController c) {
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
      child: SizedBox(height: MediaQuery.of(ctx).size.height * 0.9, child: CustomizeDrawerSheet(controller: c)),
    ),
  );
}

class CustomizeDrawerSheet extends StatefulWidget {
  const CustomizeDrawerSheet({super.key, required this.controller});
  final CalculatorController controller;

  @override
  State<CustomizeDrawerSheet> createState() => _CustomizeDrawerSheetState();
}

class _CustomizeDrawerSheetState extends State<CustomizeDrawerSheet> {
  late AdvancedTab _tab = widget.controller.advancedTab;
  final _layout = DrawerLayout.instance;

  String _tabLabel(AdvancedTab t) => advancedTabDefs.firstWhere((d) => d.id == t).label;

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    return ListenableBuilder(
      listenable: _layout,
      builder: (context, _) {
        final tabs = _layout.tabs;
        final entries = advancedKeyEntries(_tab, widget.controller);
        final ordered = [for (final i in _layout.keyIndexes(_tab, [for (final e in entries) e.id])) entries[i]];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
              child: Row(children: [
                Expanded(child: Text('Customize keys', style: appText(size: 18, weight: FontWeight.w600, color: t.onSurface))),
                TextButton(key: const ValueKey('customize-reset-all'), onPressed: _layout.isCustom ? _layout.resetAll : null, child: const Text('Reset all')),
                IconButton(key: const ValueKey('sheet-close'), icon: Icon(Icons.close, color: t.onSurfaceVariant), onPressed: () => Navigator.of(context).pop()),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _heading(t, 'Pills — hold and drag the handle to reorder'),
                  ReorderableListView(
                    key: const ValueKey('customize-tabs'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (o, n) {
                      final list = [...tabs];
                      if (n > o) n -= 1;
                      list.insert(n, list.removeAt(o));
                      _layout.setTabOrder(list);
                    },
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        _row(t, ValueKey('tab-${tabs[i].name}'), i, _tabLabel(tabs[i]), null, handleKey: ValueKey('customize-tab-handle-${tabs[i].name}')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _heading(t, 'Keys — pick a pill, then drag its keys'),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final x in tabs)
                      ChoiceChip(
                        key: ValueKey('customize-pick-${x.name}'),
                        label: Text(_tabLabel(x)),
                        selected: x == _tab,
                        onSelected: (_) => setState(() => _tab = x),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(key: const ValueKey('customize-reset-tab'), onPressed: _layout.isTabCustom(_tab) ? () => _layout.resetTab(_tab) : null, child: Text('Reset ${_tabLabel(_tab)}')),
                  ),
                  ReorderableListView(
                    key: ValueKey('customize-keys-${_tab.name}'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (o, n) {
                      final list = [...ordered];
                      if (n > o) n -= 1;
                      list.insert(n, list.removeAt(o));
                      _layout.setKeyOrder(_tab, [for (final e in list) e.id]);
                    },
                    children: [
                      for (var i = 0; i < ordered.length; i++)
                        _row(t, ValueKey('key-${ordered[i].id}'), i, ordered[i].label.isEmpty ? ordered[i].sub : ordered[i].label, ordered[i].label.isEmpty ? null : ordered[i].sub,
                            handleKey: ValueKey('customize-key-handle-$i')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _heading(M3Tokens t, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Text(text, style: appText(size: 13, weight: FontWeight.w600, color: t.onSurfaceVariant)),
      );

  Widget _row(M3Tokens t, Key key, int index, String title, String? sub, {required Key handleKey}) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: t.surfaceContainer, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.only(left: 16),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(sub == null || sub.isEmpty ? title : '$title   $sub',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(size: 15, weight: FontWeight.w500, color: t.onSurface)),
            ),
          ),
          ReorderableDragStartListener(
            key: handleKey,
            index: index,
            child: Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.drag_handle, color: t.onSurfaceVariant)),
          ),
        ]),
      );
}
