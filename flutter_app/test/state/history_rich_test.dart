import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/history_store.dart';

void main() {
  test('an entry from before the rich editor has no tree and loads as it was', () {
    final item = HistoryItem.fromJson({'id': 'a', 'expression': '1+1', 'result': '2', 'timestamp': 5, 'mode': 'standard'})!;
    expect(item.rich, isNull);
    expect(item.toJson().containsKey('rich'), isFalse);
    expect(item.toJson(), {'id': 'a', 'expression': '1+1', 'result': '2', 'timestamp': 5, 'mode': 'standard'});
  });

  test('the tree survives JSON', () {
    const tree = <Object>[
      '2',
      {
        'sup': ['3'],
      },
      '+4',
    ];
    final item = HistoryItem(id: 'a', expression: '2^3+4', result: '12', timestamp: 5, rich: tree);
    final back = HistoryItem.fromJson(jsonDecode(jsonEncode(item.toJson())))!;
    expect(back.rich, tree);
    expect(back.expression, '2^3+4');
  });

  test('a rich value that is not a list is ignored', () {
    final item = HistoryItem.fromJson({
      'id': 'a',
      'expression': '1',
      'result': '1',
      'timestamp': 1,
      'rich': 'junk',
    })!;
    expect(item.rich, isNull);
  });

  test('add stores the tree with the newest entry', () {
    final store = HistoryStore.memory();
    store.add(expression: '2^3', result: '8', rich: const ['2', {'sup': ['3']}]);
    store.add(expression: '1+1', result: '2');
    expect(store.items.first.rich, isNull);
    expect(store.items.last.rich, isNotNull);
  });
}
