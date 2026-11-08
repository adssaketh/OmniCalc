// Coverage gate (Part 9, section 9.7): docs/FX991ES_COVERAGE.md must have a test file for every Done / Partial row and a
// phase for every Deferred row, and every test file it names must exist.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final lines = File('../docs/FX991ES_COVERAGE.md').readAsLinesSync();
  final rows = <List<String>>[];
  for (final l in lines) {
    if (!l.startsWith('| ')) continue;
    final cells = l.split('|').map((c) => c.trim()).toList()..removeAt(0);
    if (cells.length < 5 || cells[0] == 'Row' || cells[0].startsWith('---')) continue;
    rows.add(cells);
  }

  test('the matrix lists the inventory rows of every section A to R', () {
    final ids = rows.map((r) => r[0]).toSet();
    for (final prefix in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R']) {
      expect(ids.any((i) => i.startsWith(prefix)), isTrue, reason: 'section $prefix');
    }
    expect(rows.length, greaterThanOrEqualTo(150));
  });

  test('row ids are unique', () {
    final ids = rows.map((r) => r[0]).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every section of the inventory has the rows the plan lists (counts of section 9.5)', () {
    int count(String prefix) => rows.where((r) => r[0].startsWith(prefix)).length;
    const minimum = <String, int>{
      'A': 41, 'B': 14, 'C': 7, 'D': 8, 'E': 5, 'F': 6, 'G': 2, 'H': 11, 'I': 8, 'J': 7, 'K': 6, 'L': 5, 'M': 4, 'N': 6,
      'O': 4, 'P': 5, 'Q': 7, 'R': 3,
    };
    minimum.forEach((prefix, n) => expect(count(prefix), greaterThanOrEqualTo(n), reason: 'section $prefix'));
  });

  test('no row is still waiting for a Phase 7 sub-phase: what is open is handed to Phase 8 by name', () {
    for (final r in rows.where((r) => r[2] == 'Deferred')) {
      expect(r[3], '8', reason: '${r[0]} is Deferred but not to Phase 8');
    }
  });

  test('every row has a valid status, and Done / Partial rows name an existing test, Deferred rows a phase', () {
    for (final r in rows) {
      final status = r[2];
      expect(['Done', 'Partial', 'Deferred'], contains(status), reason: r[0]);
      if (status == 'Deferred') {
        expect(RegExp(r'^(7[a-e]|8)$').hasMatch(r[3]), isTrue, reason: '${r[0]} needs a phase');
      } else {
        expect(File(r[4]).existsSync(), isTrue, reason: '${r[0]} names a missing test: ${r[4]}');
      }
    }
  });

  test('Phase 7b scope (A to E and G) has no empty row', () {
    for (final r in rows.where((r) => 'ABCDEG'.contains(r[0][0]))) {
      expect(r[2] == 'Deferred' && r[3] == '7b', isFalse, reason: '${r[0]} is 7b scope');
    }
  });
}
