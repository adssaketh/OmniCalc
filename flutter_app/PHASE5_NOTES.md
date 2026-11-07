# Phase 5: tool screens (in steps)

Phase 5 is split. **5a (this) is the Converter.** Still to do: 5b Currency, 5c Finance (loan, compound, SWP, tip, ROI),
5d Physics Lab, 5e Grapher, 5f History tape + Settings modal + Guide sheet (these replace `dev_settings_sheet.dart`).

## What is here (5a)
- `lib/ui/screens/converter_screen.dart`: port of `ConverterScreen.tsx` (two cards, swap, presets, copy, formula tag, "all units"
  comparison grid, 1 / 2 column layout at the 768 px breakpoint, tile grid 2/3/4/5 columns). Result formatting is the TS
  `toExponential(4)` / `toPrecision(7)` rule through `js_number.dart`.
- **Category tab icons (requested in Phase 2).** Every converter tab now shows its lucide icon (Ruler, Scale, Thermometer, Square,
  Box, Gauge, HardDrive, Clock, Activity, Zap, Compass, Magnet) from `UnitCategory.iconName`. The web app has the names but never
  draws them. Icons come from `tools/gen_lucide_paths.mjs` (extended with these, ArrowLeftRight and ChevronDown; CI still checks
  the generated file against lucide-react 0.546.0).
- `lib/ui/screens/screens.dart`: `appScreenBuilder` (calculator, converter; the other modes keep the shell stand-in).
- `lib/ui/widgets/pressable.dart` (`active:scale-95` + 150 ms Tailwind transition), `option_select.dart` (the web `<select>`),
  `lib/ui/screens/screen_utils.dart` (Tailwind breakpoints, `playScreenSound`). Reused by 5b to 5f.
- Shell changes: `CachedIntrinsicHeight(measureNatural: true)` lets a screen that is taller than the window report its real
  height, so the page grows and scrolls (the calculator keeps the old mode). `EdgeFade` no longer notifies listeners in the
  middle of a frame; it did when a page changed height (switching converter category).

## Deliberate differences
1. Unit pickers open a dialog list instead of the Android system `<select>` list (same options, same labels); the closed
   button has a small chevron.

## Not done / open
- No screenshot goldens yet (no web baselines at 390x844 for the converter), no device check.
- `<input type="number">` rules (browser-side validation of text like `1e`) are approximated by allowing `0-9 e E + - .` and
  parsing with `parseFloat`, like the TS.
- Value input has no spinner or mouse-wheel handling (browser-only).

## Verification status
CI (analyze, 4,632 tests, APK) is green on the final 5a commit. Not run on a device. Tests: `test/ui/screens/converter_screen_test.dart`
(formatting, icons on every tab, typing, presets, clear, swap, comparison tiles, picker dialog, temperature formula text,
clipboard, tablet layout); `shell_test.dart` now expects the converter instead of the placeholder.
Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

## Parity doubts
1. Select dialog look (see above).
2. `font-mono` text uses the app font with tabular figures, as in the other screens.
3. Press scale uses 150 ms Tailwind ease; the web `active:` state has no release delay either.
