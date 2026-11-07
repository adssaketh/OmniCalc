import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `HistoryItem` (src/types/index.ts).
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.expression,
    required this.result,
    required this.timestamp,
    this.mode,
    this.rich,
  });

  final String id;
  final String expression;
  final String result;

  /// Milliseconds since the epoch (`Date.now()`).
  final int timestamp;
  final String? mode;

  /// The expression as a rich node tree (see `nodesToJson`), saved when it has superscripts or subscripts. Entries from
  /// before the rich editor have none and show their plain text.
  final List<Object>? rich;

  static HistoryItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final expression = raw['expression'];
    final result = raw['result'];
    final timestamp = raw['timestamp'];
    if (id is! String || expression is! String || result is! String || timestamp is! num) return null;
    final mode = raw['mode'];
    final rich = raw['rich'];
    return HistoryItem(
      id: id,
      expression: expression,
      result: result,
      timestamp: timestamp.round(),
      mode: mode is String ? mode : null,
      rich: rich is List ? List<Object>.from(rich) : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'expression': expression,
        'result': result,
        'timestamp': timestamp,
        if (mode != null) 'mode': mode,
        if (rich != null) 'rich': rich,
      };
}

/// localStorage key of the web app.
const String historyStorageKey = 'omni_calc_history';

/// Persisted history tape (App.tsx: `history`, `handleAddHistory`, `handleClearHistory`).
class HistoryStore extends ChangeNotifier {
  HistoryStore._(this._prefs, this._items);

  final SharedPreferences? _prefs;
  List<HistoryItem> _items;

  /// Newest first.
  List<HistoryItem> get items => List.unmodifiable(_items);
  int get count => _items.length;

  static Future<HistoryStore> load([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    var items = <HistoryItem>[];
    try {
      final saved = p.getString(historyStorageKey);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is List) {
          items = [
            for (final e in decoded)
              if (HistoryItem.fromJson(e) case final item?) item,
          ];
        }
      }
    } catch (_) {
      items = <HistoryItem>[];
    }
    final store = HistoryStore._(p, items);
    await store._persist(); // the web app's save effect also runs once on mount
    return store;
  }

  factory HistoryStore.memory([List<HistoryItem> items = const []]) => HistoryStore._(null, List.of(items));

  static final math.Random _rng = math.Random();

  /// `Math.random().toString(36).substring(2, 9)`: seven base-36 characters.
  static String newId() {
    const digits = '0123456789abcdefghijklmnopqrstuvwxyz';
    return String.fromCharCodes([for (var i = 0; i < 7; i++) digits.codeUnitAt(_rng.nextInt(36))]);
  }

  /// `handleAddHistory`: newest first, at most 100 entries (`[newItem, ...prev.slice(0, 99)]`).
  void add({
    required String expression,
    required String result,
    String? mode,
    String? id,
    int? timestamp,
    List<Object>? rich,
  }) {
    final item = HistoryItem(
      id: id ?? newId(),
      expression: expression,
      result: result,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      mode: mode,
      rich: rich,
    );
    _items = [item, ..._items.take(99)];
    _persist();
    notifyListeners();
  }

  void clear() {
    _items = <HistoryItem>[];
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(historyStorageKey, jsonEncode([for (final i in _items) i.toJson()]));
    } catch (_) {
      // storage full or blocked: ignored, like the TS
    }
  }
}
