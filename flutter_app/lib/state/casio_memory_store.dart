// Saving the memory of the Casio engine (Phase 7e, Part 9 section R): Ans, PreAns, the variables A–F, M, X, Y and the mode survive
// an app restart, as the real calculator keeps its memory when it is switched off (manual p.35). History is not saved.
//
// Values keep their exact form (fractions, √, π multiples), so `1⌟3` is still `1⌟3` after a restart.

import 'dart:convert';

import '../engine/casio/config.dart';
import '../engine/casio/cval.dart';
import '../engine/casio/exact.dart';
import '../engine/casio/rat.dart';

/// Own key; the web-parity blobs are not touched.
const String casioMemoryStorageKey = 'omni_calc_casio_memory';

/// What a restart restores besides the memory.
class SavedCasioState {
  const SavedCasioState({this.mode, this.baseMode, this.statType});

  /// Names of the `CasioMode`, `BaseMode` and `StatType` values (the screen maps them back).
  final String? mode;
  final String? baseMode;
  final String? statType;
}

class CasioMemoryStore {
  const CasioMemoryStore._();

  static String _rat(Rat r) => '${r.n}/${r.d}';

  static Rat _ratFrom(Object? s) {
    final parts = '$s'.split('/');
    return Rat(BigInt.parse(parts[0]), parts.length > 1 ? BigInt.parse(parts[1]) : BigInt.one);
  }

  static Map<String, Object?> cvalToJson(CVal v) => <String, Object?>{
        'v': v.v,
        if (v.dms) 'dms': true,
        if (v.ex != null)
          'ex': <String, Object?>{
            'terms': <String, Object?>{for (final e in v.ex!.terms.entries) '${e.key}': _rat(e.value)},
            'pi': _rat(v.ex!.pi),
          },
      };

  static CVal cvalFromJson(Object? j) {
    if (j is! Map) return CVal.zero;
    final d = (j['v'] as num?)?.toDouble() ?? 0;
    final dms = j['dms'] == true;
    final exj = j['ex'];
    if (exj is Map) {
      try {
        Ex? ex = Ex.zero;
        final terms = exj['terms'];
        if (terms is Map) {
          for (final e in terms.entries) {
            final radicand = int.parse('${e.key}');
            final coef = _ratFrom(e.value);
            final root = radicand == 1 ? null : Ex.sqrtRational(Rat.fromInt(radicand));
            final part = radicand == 1 ? Ex.rational(coef) : (root == null ? null : Ex.rational(coef) * root);
            ex = part == null || ex == null ? null : ex + part;
          }
        }
        final pi = _ratFrom(exj['pi'] ?? '0/1');
        if (!pi.isZero && ex != null) ex = ex + Ex.piMultiple(pi);
        if (ex != null) return CVal(d, ex, dms);
      } catch (_) {
        // an unreadable exact form falls back to the decimal
      }
    }
    return CVal(d, null, dms);
  }

  static String encode(CasioMemory m, {String? mode, String? baseMode, String? statType}) => jsonEncode(<String, Object?>{
        'ans': cvalToJson(m.ans),
        'preAns': cvalToJson(m.preAns),
        'vars': <String, Object?>{for (final e in m.vars.entries) e.key: cvalToJson(e.value)},
        if (mode != null) 'mode': mode,
        if (baseMode != null) 'baseMode': baseMode,
        if (statType != null) 'statType': statType,
      });

  /// Reads [text] into [into]; an unreadable or missing blob leaves the memory as it is.
  static SavedCasioState decode(String? text, CasioMemory into) {
    if (text == null) return const SavedCasioState();
    try {
      final j = jsonDecode(text);
      if (j is! Map) return const SavedCasioState();
      if (j['ans'] != null) into.ans = cvalFromJson(j['ans']);
      if (j['preAns'] != null) into.preAns = cvalFromJson(j['preAns']);
      final vars = j['vars'];
      if (vars is Map) {
        for (final k in kVariableNames) {
          if (vars[k] != null) into.vars[k] = cvalFromJson(vars[k]);
        }
      }
      into.ansText = null;
      return SavedCasioState(
        mode: j['mode'] is String ? j['mode'] as String : null,
        baseMode: j['baseMode'] is String ? j['baseMode'] as String : null,
        statType: j['statType'] is String ? j['statType'] as String : null,
      );
    } catch (_) {
      return const SavedCasioState();
    }
  }
}
