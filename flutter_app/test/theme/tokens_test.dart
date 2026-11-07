import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/theme/dynamic_colors.dart';
import 'package:omnicalc/theme/tokens.dart';

// Literal values are read from src/index.css and src/App.tsx.
void main() {
  group('static themes (CSS cascade)', () {
    final cases = <(String, bool, int, int)>[
      // theme id, dark, primary, surface
      (ThemeIds.iris, true, 0xFFA8C7FA, 0xFF111318),
      (ThemeIds.iris, false, 0xFF0B57D0, 0xFFF8F9FA),
      (ThemeIds.ocean, true, 0xFF7BD0FF, 0xFF0E1417),
      (ThemeIds.ocean, false, 0xFF006874, 0xFFF5FBFA),
      (ThemeIds.forest, true, 0xFF9CD67D, 0xFF101510),
      (ThemeIds.forest, false, 0xFF2E6A24, 0xFFF7FBF2),
      (ThemeIds.cyberEmerald, true, 0xFF9CD67D, 0xFF101510),
      (ThemeIds.sunset, true, 0xFFFFB59D, 0xFF171210),
      (ThemeIds.sunset, false, 0xFF9C4323, 0xFFFFF8F6),
      (ThemeIds.amoled, true, 0xFFC2C1FF, 0xFF000000),
      (ThemeIds.oledMidnight, true, 0xFFC2C1FF, 0xFF000000),
      (ThemeIds.amoled, false, 0xFF5548C8, 0xFFFFFFFF),
      (ThemeIds.darkObsidian, true, 0xFFA8C7FA, 0xFF111318),
      (ThemeIds.warmPaper, false, 0xFF0B57D0, 0xFFF8F9FA),
    ];
    for (final (id, dark, primary, surface) in cases) {
      test('$id ${dark ? 'dark' : 'light'}', () {
        final t = staticTokens(id, isDark: dark);
        expect(t.primary, Color(primary));
        expect(t.surface, Color(surface));
        expect(t.isDark, dark);
      });
    }

    test('page surface matches DARK_SURFACES / LIGHT_SURFACES and falls back', () {
      expect(pageSurface(ThemeIds.amoled, isDark: true), const Color(0xFF000000));
      expect(pageSurface(ThemeIds.amoled, isDark: false), const Color(0xFFFFFFFF));
      expect(pageSurface(ThemeIds.ocean, isDark: true), const Color(0xFF0E1417));
      expect(pageSurface('unknown', isDark: true), const Color(0xFF111318));
      expect(pageSurface('unknown', isDark: false), const Color(0xFFF8F9FA));
    });

    test('theme id to data-m3-theme', () {
      expect(themeDataAttr(ThemeIds.ocean), 'oceanic');
      expect(themeDataAttr(ThemeIds.forest), 'forest');
      expect(themeDataAttr(ThemeIds.cyberEmerald), 'forest');
      expect(themeDataAttr(ThemeIds.sunset), 'sunset');
      expect(themeDataAttr(ThemeIds.amoled), 'amoled');
      expect(themeDataAttr(ThemeIds.oledMidnight), 'amoled');
      expect(themeDataAttr(ThemeIds.dynamic), 'iris');
      expect(themeDataAttr(ThemeIds.warmPaper), 'iris');
    });

    test('toMap / fromMap round trip', () {
      final t = staticTokens(ThemeIds.sunset, isDark: false);
      expect(M3Tokens.fromMap(t.toMap(), isDark: false), t);
    });
  });

  group('Material You', () {
    SystemColors palette(Map<String, int> m) => SystemColors(m);

    test('uses the system roles', () {
      final t = applyDynamicTokens(
        palette({
          'system_accent1_200': 0x112233,
          'system_neutral1_900': 0x202020,
          'system_neutral1_100': 0xF0F0F0,
        }),
        isDark: true,
      );
      expect(t.primary, const Color(0xFF112233));
      expect(t.surface, const Color(0xFF202020));
      expect(t.onSurface, const Color(0xFFF0F0F0));
    });

    test('missing keys fall back to the Iris values of the web app', () {
      final t = applyDynamicTokens(palette({}), isDark: true);
      expect(t.primary, const Color(0xFFA8C7FA));
      expect(t.onPrimary, const Color(0xFF062E6F));
      expect(t.surface, const Color(0xFF111318));
    });

    test('surface-container-lowest is surface 82% + black (color-mix in sRGB)', () {
      final t = applyDynamicTokens(palette({'system_neutral1_900': 0x202020}), isDark: true);
      // 0x20 = 32; 32 * 0.82 = 26.24
      expect((t.surfaceContainerLowest.r * 255).round(), closeTo(26, 1));
      expect((t.surfaceContainerLowest.g * 255).round(), closeTo(26, 1));
    });

    test('resolveTheme: dynamic with colours uses them; every other theme ignores them', () {
      final sys = palette({'system_accent1_200': 0x112233, 'system_neutral1_900': 0x202020});
      final dyn = resolveTheme(themeId: ThemeIds.dynamic, isDark: true, system: sys);
      expect(dyn.tokens.primary, const Color(0xFF112233));
      expect(dyn.pageSurface, const Color(0xFF202020));
      final ocean = resolveTheme(themeId: ThemeIds.ocean, isDark: true, system: sys);
      expect(ocean.tokens.primary, const Color(0xFF7BD0FF));
      expect(ocean.pageSurface, const Color(0xFF0E1417));
      final none = resolveTheme(themeId: ThemeIds.dynamic, isDark: true);
      expect(none.tokens.primary, const Color(0xFFA8C7FA));
      expect(none.pageSurface, const Color(0xFF111318));
    });

    test('palette list parsing: 5 palettes x 13 tones', () {
      expect(SystemColors.fromPaletteList(null), isNull);
      expect(SystemColors.fromPaletteList(const [1, 2, 3]), isNull);
      final list = List<Object?>.generate(65, (i) => i);
      final s = SystemColors.fromPaletteList(list)!;
      expect(s.colors['system_accent1_1000'], 0);
      expect(s.colors['system_accent1_0'], 12);
      expect(s.colors['system_accent2_1000'], 13);
      expect(s.colors['system_neutral2_0'], 64);
    });
  });
}
