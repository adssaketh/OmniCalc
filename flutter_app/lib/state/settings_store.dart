import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// localStorage keys of the web app, reused unchanged as SharedPreferences keys.
const String settingsStorageKey = 'omni_calc_settings';
const String themeUserSetStorageKey = 'omni_calc_settings_theme_user_set';

/// Persisted settings (App.tsx: `settings` state + the effect that saves it).
///
/// The web app writes the whole settings object after every change and once on start-up; this does the same.
/// `handleUpdateSettings(partial)` is [update].
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs, this._settings, this._themeUserSet);

  final SharedPreferences? _prefs;
  AppSettings _settings;
  bool _themeUserSet;

  AppSettings get settings => _settings;

  /// `omni_calc_settings_theme_user_set` ('true' once the user picked a theme in Settings).
  bool get themeUserSet => _themeUserSet;

  /// Loads settings; a missing or unreadable blob gives the defaults (the TS `catch` branch).
  static Future<SettingsStore> load([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    var settings = const AppSettings();
    try {
      final saved = p.getString(settingsStorageKey);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is Map<String, dynamic>) settings = AppSettings.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {
      settings = const AppSettings();
    }
    final store = SettingsStore._(p, settings, p.getString(themeUserSetStorageKey) != null);
    await store._persist(); // the web app's save effect also runs once on mount
    return store;
  }

  /// In-memory store for tests and previews (nothing is written anywhere).
  factory SettingsStore.memory([AppSettings settings = const AppSettings(), bool themeUserSet = false]) =>
      SettingsStore._(null, settings, themeUserSet);

  /// `handleUpdateSettings`: replaces the given fields, saves, notifies.
  void update(AppSettings Function(AppSettings current) change) {
    final next = change(_settings);
    _settings = next;
    _persist();
    notifyListeners();
  }

  /// `localStorage.setItem('omni_calc_settings_theme_user_set', 'true')`.
  void markThemeUserSet() {
    if (_themeUserSet) return;
    _themeUserSet = true;
    _prefs?.setString(themeUserSetStorageKey, 'true');
  }

  /// The dynamic-colour auto-default of App.tsx, run when the system reports Material You colours:
  /// only if the user never picked a theme, and the saved theme is not already m3-amoled or dynamic, switch to dynamic.
  void applyDynamicAutoDefault() {
    if (_themeUserSet) return;
    if (_settings.theme == ThemeIds.amoled || _settings.theme == ThemeIds.dynamic) return;
    update((s) => s.copyWith(theme: ThemeIds.dynamic));
  }

  Future<void> _persist() async {
    try {
      await _prefs?.setString(settingsStorageKey, jsonEncode(_settings.toJson()));
    } catch (_) {
      // storage full or blocked: ignored, like the TS
    }
  }
}
