import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/casio_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults: Casio style, OmniCalc percent, math display, Norm 1', () {
    const s = CasioSettings();
    expect(s.useCasio, isTrue);
    expect(s.phonePercent, isTrue);
    expect(s.decimalFirst, isFalse);
    expect(s.numberFormat, CasioNumberFormat.norm1);
    expect(s.mixedFractions, isFalse);
    expect(s.recurring, isTrue);
  });

  test('JSON round trip and unreadable values fall back to defaults', () {
    const s = CasioSettings(useCasio: false, numberFormat: CasioNumberFormat.fix, digits: 3, gradians: true);
    final back = CasioSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
    expect(back.toJson(), s.toJson());
    final bad = CasioSettings.fromJson({'useCasio': 5, 'numberFormat': 'nope', 'digits': 99});
    expect(bad.useCasio, isTrue);
    expect(bad.numberFormat, CasioNumberFormat.norm1);
    expect(bad.digits, 9);
  });

  test('the web-parity settings blob is untouched', () {
    expect(const AppSettings().toJson().keys, isNot(contains('useCasio')));
  });

  test('config takes the angle unit and decimal places from AppSettings', () {
    final cfg = const CasioSettings().toConfig(AngleMode.rad, 4);
    expect(cfg.angle, CasioAngle.rad);
    expect(cfg.legacyPrecision, 4);
    expect(const CasioSettings(gradians: true).toConfig(AngleMode.deg, -1).angle, CasioAngle.gra);
  });

  test('the runtime saves under its own key and loads it back', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final rt = CasioRuntime.instance;
    await rt.load(prefs);
    rt.update((c) => c.copyWith(phonePercent: false, recurring: false));
    expect(prefs.getString(casioSettingsStorageKey), contains('"phonePercent":false'));
    rt.update((_) => const CasioSettings());
    await rt.load(prefs);
    expect(rt.settings.toJson(), const CasioSettings().toJson());
    rt.reset();
  });
}
