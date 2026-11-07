# Phase 3 - Shell (tokens, glass, edge effects, motion, header, bottom bar, tabs, settings store)

## What changed
**State** (`lib/state/`)
- `app_settings.dart`, `settings_store.dart`: all 17 settings with the web defaults and key order, tolerant load, same storage keys
  (`omni_calc_settings`, `omni_calc_settings_theme_user_set`), dynamic-colour auto default.
- `history_store.dart` (newest first, max 100, key `omni_calc_history`), `navigation_state.dart` (nav items, mode trail of 20,
  back-button priority guide > settings (inner back first) > history > trail > "press back again" 2 s, deep-link entry).

**Theme** (`lib/theme/`)
- `theme_data_generated.dart` is generated from `src/index.css` + `App.tsx` by `tools/gen_theme_data.mjs` (`--check` supported):
  5 themes x dark/light, 29 roles. `tokens.dart` rebuilds the CSS cascade; `dynamic_colors.dart` ports `applyDynamicTokens`.
- `glass.dart` (`BarSurface`: solid and liquid-glass bars), `edge_effects.dart` (`buildEdgeMask`, `buildBlurLayers`, glass fill),
  `motion.dart` (curves, springs, enter animations, key press), `css_transition.dart`, `spring_value.dart`, `app_theme.dart`.

**UI** (`lib/ui/`)
- Icons: `svg_paths_generated.dart` (from `NavIcons.tsx` / `OmniCalcLogo.tsx` by `tools/gen_svg_paths.mjs`), `nav_icon.dart`, `omnicalc_logo.dart`.
- Shell: `header.dart` (split pill with the four timed transitions + rubber-band name), `bottom_nav_bar.dart`, `navigation_rail.dart`,
  `swipeable_tab_container.dart`, `app_shell.dart` (layout, edge mask, header collapse hysteresis 36/10, back, shortcuts, exit hint),
  `pinned_slot.dart`, `measure_size.dart`.
- `dev_settings_sheet.dart`: **scaffolding only**, a small sheet so the themes and bar/edge options can be switched before the real
  Settings modal arrives in Phase 5. `placeholderScreen` in `app_shell.dart` likewise stands in for the Phase 4/5 screens.
- `lib/main.dart`: real app root (stores, providers, theme resolution, status bar colour, system-colour refresh on resume/brightness change).
- `pubspec.yaml`: added `provider` and `dynamic_color` (its native plugin gives the Material You palette over a method channel).
- `.github/workflows/flutter-ci.yml`: one new step runs the two generator `--check`s.

**Tests** (`test/`)
- `theme/edge_effects_test.dart`: 29 fill values, 90 edge masks, 6 blur sets against vectors from the real `src/edgeEffects.ts`
  (`tools/gen_shell_vectors.ts`, `test/golden/edge_effects.json`), plus the fade-strength quantisation.
- `theme/tokens_test.dart`, `state/*_test.dart`, `ui/shell_test.dart`, `ui/swipeable_tab_container_test.dart`.
- `ui/golden_shell_test.dart` (tag `golden`): 6 shell screenshots. Baselines are not committed, so these report as skipped, not passed.

## Not yet ported
- Calculator, Converter, Finance, Physics, Grapher screens (Phases 4/5), History tape, Settings modal, Guide sheet (Phase 5).
- Key click sound (needs an audio package; arrives with the calculator keys in Phase 4). Haptics are an approximation, see below.
- Launcher shortcuts / deep links (`initDeepLinks`): `NavigationState.openFromDeepLink` is ready, the Android side is not wired.
- Converter tab icons (Phase 5, unchanged open point: Pressure and Frequency both use `Activity`).

## Verified (honest status)
- GitHub Actions run on `b813b36` (branch `flutter-rewrite`) is green: generator `--check`s, `flutter analyze`, `flutter test`
  (4,466 tests passing, 6 skipped = the shell goldens without baselines), release APK build and signing.
- It took five CI rounds to get there. Real bugs found and fixed: the bottom bar had unbounded height, the header stayed collapsed
  after a screen change, and an unused field failed analyze. The rest were test mistakes (entrance spring needs two frames, a wrong
  0.2 expectation, empty areas that cannot be hit in tests).
- **Not verified: pixel parity.** No screenshot of the web app or the Flutter app was compared, and nothing ran on a device.
  The shell goldens (`flutter test --tags golden`) still need baselines from the web app at 390 x 844.

## Parity doubts (please check on a device)
1. **Masked progressive blur** ("Fade + blur"): done by painting the mask with `dstIn` inside a `BackdropFilter`. Unverified on device.
2. **Glass filter**: `blur + saturate(1.9) + brightness(1.05)` is built as `ImageFilter.compose` of a colour-matrix filter over a blur.
3. **Green equals pill** in the logo: the two CSS drop-shadows are drawn as two independent blurred shapes.
4. **System bars**: the web app (Capacitor) lets the status bar take its own space. I wrapped the shell in a top `SafeArea`; the bottom
   bar still adds the bottom inset itself like `env(safe-area-inset-bottom)`. If your Android build draws edge-to-edge, tell me.
5. **Haptics**: the web app vibrates for 10/25/45/75 ms; Flutter's `HapticFeedback` has no duration, so light/medium/heavy/vibrate are used.
6. **Swipe click suppression**: the web app swallows the click that ends a swipe (150 ms). A Flutter tap resolves on pointer-up, so a
   short horizontal drag of 8-18 px can still tap a child. Longer drags cancel taps on their own.
7. **Fonts**: `Google Sans` is only used if it exists on the device; otherwise the fallback list (Roboto) applies, as in the CSS.
8. **Edge mask rounding**: alphas use `toFixed(3)` and positions `toFixed(1)` exactly like the generated CSS strings.
9. APIs used need a recent Flutter (3.27+): `Color.withValues`, `Color.r`, `toARGB32`.
10. A stored setting of the wrong type falls back to its default (the web app would keep the bad value).
11. `glassTransparency` is stored as an int.

## Run it yourself
```
cd flutter_app
flutter pub get && flutter analyze && flutter test
flutter test --tags golden        # after baselines exist in test/goldens/shell/
```
Regenerate (repo root): `node flutter_app/tools/gen_theme_data.mjs`, `node flutter_app/tools/gen_svg_paths.mjs`,
`npx tsx flutter_app/tools/gen_shell_vectors.ts`.
