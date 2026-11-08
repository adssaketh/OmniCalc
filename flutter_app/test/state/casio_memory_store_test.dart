// Part 9, R: Ans, PreAns, the variables and the mode survive a restart, with their exact forms.

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';
import 'package:omnicalc/state/casio_memory_store.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  String shown(CasioEngine e, String expr) => e.evaluate(expr, commit: false).shown.display;

  test('values keep their exact form: fraction, √ and π multiples', () {
    final src = CasioEngine();
    src.evaluate('1÷3');
    src.memory.vars['A'] = src.evaluate('√(2)×3', commit: false).value!;
    src.memory.vars['B'] = src.evaluate('2π', commit: false).value!;
    final text = CasioMemoryStore.encode(src.memory, mode: 'stat', baseMode: 'hex', statType: 'linear');

    final dst = CasioEngine();
    final saved = CasioMemoryStore.decode(text, dst.memory);
    expect(saved.mode, 'stat');
    expect(saved.baseMode, 'hex');
    expect(saved.statType, 'linear');
    expect(shown(dst, 'Ans'), '1⌟3');
    expect(shown(dst, 'A'), '3√2');
    expect(shown(dst, 'B'), '2π');
    expect(dst.memory.vars['M']!.v, 0);
  });

  test('PreAns and the independent memory come back', () {
    final src = CasioEngine();
    src.evaluate('5');
    src.evaluate('8');
    src.memory.vars['M'] = CVal.int(11);
    final dst = CasioEngine();
    CasioMemoryStore.decode(CasioMemoryStore.encode(src.memory), dst.memory);
    expect(dst.memory.ans.v, 8);
    expect(dst.memory.preAns.v, 5);
    expect(dst.memory.vars['M']!.v, 11);
    expect(dst.memory.independentMemoryUsed, isTrue);
  });

  test('a degrees-minutes-seconds value stays one', () {
    final v = CasioMemoryStore.cvalFromJson(CasioMemoryStore.cvalToJson(CVal.dec(1.5, dms: true)));
    expect(v.dms, isTrue);
    expect(v.v, 1.5);
  });

  test('a missing or unreadable blob leaves the memory alone', () {
    final m = CasioMemory()..vars['A'] = CVal.int(4);
    expect(CasioMemoryStore.decode(null, m).mode, isNull);
    expect(CasioMemoryStore.decode('not json', m).mode, isNull);
    expect(CasioMemoryStore.decode('[1,2]', m).mode, isNull);
    expect(m.vars['A']!.v, 4);
  });

  test('an unreadable exact form falls back to the decimal', () {
    final v = CasioMemoryStore.cvalFromJson(<String, Object?>{
      'v': 0.5,
      'ex': <String, Object?>{'terms': <String, Object?>{'x': 'oops'}, 'pi': '0/1'},
    });
    expect(v.v, 0.5);
    expect(v.ex, isNull);
  });

  group('CasioRuntime', () {
    test('saveMemory writes the blob and load reads it back into the engine', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final rt = CasioRuntime.instance;
      await rt.load(prefs);
      rt.engine.memory.vars['C'] = CVal.int(21);
      rt.engine.memory.setAns(CVal.int(34));
      rt.saveMemory(mode: 'verif');
      expect(prefs.getString(casioMemoryStorageKey), isNotNull);

      rt.engine.memory.clearVariables();
      expect(rt.engine.memory.vars['C']!.v, 0);
      await rt.load(prefs);
      expect(rt.engine.memory.vars['C']!.v, 21);
      expect(rt.engine.memory.ans.v, 34);
      expect(rt.saved.mode, 'verif');
      rt.engine.memory.clearVariables();
    });

    test('a first start has no saved mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await CasioRuntime.instance.load(prefs);
      expect(CasioRuntime.instance.saved.mode, isNull);
    });
  });
}
