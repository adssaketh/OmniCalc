import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/types.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/state/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const defaultKeys = [
    'soundEnabled',
    'hapticEnabled',
    'vibrationIntensity',
    'angleMode',
    'decimalPrecision',
    'theme',
    'colorMode',
    'currencySymbol',
    'currencyCode',
    'enableGrapher',
    'enablePhysics',
    'enableChemistry',
    'edgeEffect',
    'fadeHeight',
    'barStyle',
    'glassTransparency',
    'glassBlur',
    'glassEdge',
  ];

  test('defaults equal DEFAULT_SETTINGS of App.tsx', () {
    final j = const AppSettings().toJson();
    expect(j.keys.toList(), defaultKeys);
    expect(j, {
      'soundEnabled': true,
      'hapticEnabled': true,
      'vibrationIntensity': 'medium',
      'angleMode': 'deg',
      'decimalPrecision': -1,
      'theme': 'dynamic',
      'colorMode': 'system',
      'currencySymbol': '₹',
      'currencyCode': 'INR',
      'enableGrapher': false,
      'enablePhysics': false,
      'enableChemistry': false,
      'edgeEffect': 'fade',
      'fadeHeight': 'medium',
      'barStyle': 'solid',
      'glassTransparency': 70,
      'glassBlur': 'medium',
      'glassEdge': true,
    });
  });

  test('round trip', () {
    final s = const AppSettings().copyWith(
      theme: ThemeIds.ocean,
      colorMode: ColorMode.dark,
      barStyle: BarStyle.glass,
      edgeEffect: EdgeEffect.blur,
      fadeHeight: FadeHeight.tall,
      glassBlur: GlassBlur.strong,
      glassTransparency: 40,
      angleMode: AngleMode.rad,
      decimalPrecision: 4,
    );
    final back = AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
    expect(back.toJson(), s.toJson());
  });

  test('a partial blob keeps the defaults for what is missing ({...DEFAULT, ...saved})', () {
    final s = AppSettings.fromJson({'theme': 'm3-forest', 'soundEnabled': false});
    expect(s.theme, 'm3-forest');
    expect(s.soundEnabled, isFalse);
    expect(s.barStyle, BarStyle.solid);
    expect(s.currencySymbol, '₹');
  });

  test('unknown keys survive a save', () {
    final s = AppSettings.fromJson({'futureFlag': 7});
    expect(s.toJson()['futureFlag'], 7);
  });

  group('store', () {
    test('update notifies and keeps the new value', () {
      final store = SettingsStore.memory();
      var calls = 0;
      store.addListener(() => calls++);
      store.update((s) => s.copyWith(soundEnabled: false));
      expect(store.settings.soundEnabled, isFalse);
      expect(calls, 1);
    });

    test('persists under the web keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = await SettingsStore.load(prefs);
      store.update((s) => s.copyWith(theme: ThemeIds.sunset));
      store.markThemeUserSet();
      await Future<void>.delayed(Duration.zero);
      final saved = jsonDecode(prefs.getString('omni_calc_settings')!) as Map<String, dynamic>;
      expect(saved['theme'], ThemeIds.sunset);
      expect(prefs.getString('omni_calc_settings_theme_user_set'), 'true');
    });

    test('load reads a saved blob; garbage gives the defaults', () async {
      SharedPreferences.setMockInitialValues({'omni_calc_settings': '{"theme":"m3-amoled"}'});
      var store = await SettingsStore.load(await SharedPreferences.getInstance());
      expect(store.settings.theme, ThemeIds.amoled);

      SharedPreferences.setMockInitialValues({'omni_calc_settings': 'not json'});
      store = await SettingsStore.load(await SharedPreferences.getInstance());
      expect(store.settings.theme, ThemeIds.dynamic);
    });

    group('dynamic colour auto default', () {
      test('switches a never-chosen theme to dynamic', () {
        final store = SettingsStore.memory(const AppSettings().copyWith(theme: ThemeIds.ocean));
        store.applyDynamicAutoDefault();
        expect(store.settings.theme, ThemeIds.dynamic);
      });
      test('keeps amoled', () {
        final store = SettingsStore.memory(const AppSettings().copyWith(theme: ThemeIds.amoled));
        store.applyDynamicAutoDefault();
        expect(store.settings.theme, ThemeIds.amoled);
      });
      test('keeps a theme the user picked', () {
        final store = SettingsStore.memory(const AppSettings().copyWith(theme: ThemeIds.ocean), true);
        store.applyDynamicAutoDefault();
        expect(store.settings.theme, ThemeIds.ocean);
      });
    });
  });
}
