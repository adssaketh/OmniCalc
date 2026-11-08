import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/calculator/calculator_controller.dart' show AdvancedTab, advancedTabDefs;

const String drawerLayoutStorageKey = 'omni_calc_drawer_layout';

/// The user's own order of the pills (tabs) and of the keys inside each tab of the Advanced Scientific Operations drawer.
/// Anything missing from a saved order (a key added by an update) is appended at the end, anything unknown is dropped.
class DrawerLayout extends ChangeNotifier {
  DrawerLayout._();
  static final DrawerLayout instance = DrawerLayout._();

  SharedPreferences? _prefs;
  List<String> _tabOrder = const [];
  Map<String, List<String>> _keyOrder = const {};

  bool get isCustom => _tabOrder.isNotEmpty || _keyOrder.isNotEmpty;
  bool isTabCustom(AdvancedTab tab) => _keyOrder[tab.name]?.isNotEmpty ?? false;

  Future<void> load([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    try {
      final raw = _prefs!.getString(drawerLayoutStorageKey);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map<String, dynamic>) {
          _tabOrder = [for (final e in (j['tabs'] as List? ?? const [])) e.toString()];
          final keys = j['keys'];
          _keyOrder = keys is Map ? {for (final e in keys.entries) e.key.toString(): [for (final k in e.value as List) k.toString()]} : const {};
        }
      }
    } catch (_) {
      _tabOrder = const [];
      _keyOrder = const {};
    }
    notifyListeners();
  }

  void _save() {
    try {
      _prefs?.setString(drawerLayoutStorageKey, jsonEncode({'tabs': _tabOrder, 'keys': _keyOrder}));
    } catch (_) {}
    notifyListeners();
  }

  /// The tabs in the user's order (new tabs at the end).
  List<AdvancedTab> get tabs {
    final all = [for (final d in advancedTabDefs) d.id];
    final out = <AdvancedTab>[];
    for (final n in _tabOrder) {
      for (final t in all) {
        if (t.name == n && !out.contains(t)) out.add(t);
      }
    }
    for (final t in all) {
      if (!out.contains(t)) out.add(t);
    }
    return out;
  }

  void setTabOrder(List<AdvancedTab> order) {
    _tabOrder = [for (final t in order) t.name];
    _save();
  }

  /// Stable ids for a tab's keys in the default order: `label|sub`, with `#n` added to repeated ones.
  static List<String> idsOf(List<({String label, String sub})> keys) {
    final seen = <String, int>{};
    return [
      for (final k in keys)
        () {
          final base = '${k.label}|${k.sub}';
          final n = seen[base] = (seen[base] ?? 0) + 1;
          return n == 1 ? base : '$base#$n';
        }()
    ];
  }

  /// Indexes of the default key list in the user's order.
  List<int> keyIndexes(AdvancedTab tab, List<String> defaultIds) {
    final saved = _keyOrder[tab.name] ?? const [];
    final out = <int>[];
    for (final id in saved) {
      final i = defaultIds.indexOf(id);
      if (i >= 0 && !out.contains(i)) out.add(i);
    }
    for (var i = 0; i < defaultIds.length; i++) {
      if (!out.contains(i)) out.add(i);
    }
    return out;
  }

  void setKeyOrder(AdvancedTab tab, List<String> idsInOrder) {
    _keyOrder = {..._keyOrder, tab.name: idsInOrder};
    _save();
  }

  void resetTab(AdvancedTab tab) {
    _keyOrder = {..._keyOrder}..remove(tab.name);
    _save();
  }

  void resetAll() {
    _tabOrder = const [];
    _keyOrder = const {};
    _save();
  }
}
