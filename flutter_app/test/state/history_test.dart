import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('newest first, capped at 100', () {
    final h = HistoryStore.memory();
    for (var i = 0; i < 105; i++) {
      h.add(expression: '$i+1', result: '${i + 1}');
    }
    expect(h.count, 100);
    expect(h.items.first.expression, '104+1');
    expect(h.items.last.expression, '5+1');
  });

  test('ids are seven base-36 characters', () {
    for (var i = 0; i < 50; i++) {
      expect(HistoryStore.newId(), matches(RegExp(r'^[0-9a-z]{7}$')));
    }
  });

  test('clear empties and notifies', () {
    final h = HistoryStore.memory();
    h.add(expression: '1+1', result: '2');
    var calls = 0;
    h.addListener(() => calls++);
    h.clear();
    expect(h.count, 0);
    expect(calls, 1);
  });

  test('persists under omni_calc_history and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final h = await HistoryStore.load(prefs);
    h.add(expression: '2+2', result: '4');
    await Future<void>.delayed(Duration.zero);
    final saved = jsonDecode(prefs.getString('omni_calc_history')!) as List;
    expect(saved.length, 1);
    expect((saved.first as Map)['expression'], '2+2');
    final again = await HistoryStore.load(prefs);
    expect(again.count, 1);
  });

  test('a corrupt blob gives an empty history', () async {
    SharedPreferences.setMockInitialValues({'omni_calc_history': '{oops'});
    final h = await HistoryStore.load(await SharedPreferences.getInstance());
    expect(h.count, 0);
  });
}
