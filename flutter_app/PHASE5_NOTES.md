# Phase 5: tool screens (in steps)

Phase 5 is split. **5a is the Converter, 5b (below) is Currency.** Still to do: 5c Finance (loan, compound, SWP, tip, ROI),
5d Physics Lab, 5e Grapher, 5f History tape + Settings modal + Guide sheet (these replace `dev_settings_sheet.dart`).

# Phase 5b: Currency

The web app has no Currency screen of its own: `CurrencyConverter.tsx` is the first tab of `FinanceScreen.tsx`. So 5b ports that
tab **and the Finance screen around it** (tab strip with its six icons, tab-switch click, same page width and padding). The other
five Finance tabs show a "(Phase 5c)" stand-in until 5c replaces them.

## What is here (5b)
- `lib/ui/screens/currency_screen.dart`: port of `CurrencyConverter.tsx`: live status bar (dot with the `animate-ping` halo while
  live, label Live / Built-in / Cached, "Updated ..." stamp, Refresh Rates button with the spinning icon and `Updating...`),
  the "couldn't reach a live provider" notice, From card (amount field, six presets, currency picker), swap button, Target card,
  result card (amount, copy with the tick for 2 s, direct and inverse rate badges) and the six-currency watchlist.
  Layout is 1 column below 768 px and 2 columns from there. The engine (`engine/currency.dart`, four providers in parallel,
  cache, built-in fallback) was ported in Phase 2; the screen only calls it.
- `lib/ui/screens/finance_screen.dart`: port of `FinanceScreen.tsx` (tabs Currency, Loan / EMI, SIP & Compound, SWP, Tip & Bill,
  ROI & CAGR with Globe, Landmark, PiggyBank, Wallet, Receipt, LineChart icons; plays the `toggle` click on a tab change).
- `lib/engine/js_locale.dart`: `toLocaleString(undefined, {minimumFractionDigits, maximumFractionDigits})` with en-US grouping.
  Digits come from `jsToFixed`, so rounding is the same as `toFixed`.
- Icons: Globe, Landmark, PiggyBank, Wallet, Receipt, LineChart (lucide `chart-line`, which is what `LineChart` aliases),
  RefreshCw, TrendingUp added to `tools/gen_lucide_paths.mjs`; the generated file was rebuilt from lucide-react 0.546.0.
- `main.dart`: `OmniCalcApp` takes an optional `currencyService` and provides it (`Provider<CurrencyService>`). Tests pass a fake
  (`test/support/fake_currency.dart`) so no request leaves a test; `shell_test.dart` now does too, because it opens Finance.
- `screens.dart`: Finance now builds `FinanceScreen`.

## Deliberate differences (5b)
1. **Number grouping is always en-US** (`1,234.50`). The web app uses the device locale (an Indian-locale phone would show
   `1,234.50` the same way, but a German one `1.234,50`). Rule from Part 1: no locale-dependent formatting of results.
2. **Retry on app resume instead of on the `online` event.** The web screen reloads when the browser fires `online`. Flutter has no
   such event without another package, so coming back to the app retries when the rates are not live.
3. **"Updated" time is 24-hour `HH:mm`** (the engine's default `StampStyle`). The web app follows the device locale (12/24 h).
4. Currency pickers open a dialog list (same as 5a); the closed button is as wide as its current label, the web `<select>` is as
   wide as its longest option.
5. Not ported (browser-only): the `title` tooltip with the provider error on the notice, `position: sticky` on the result card
   (it cannot stick when the result card is the taller column), and the number input's spinner / wheel.

## Not done / open (5b)
- No screenshot goldens and no device check. **Not run in this session: there is no Flutter SDK in the chat sandbox**, so
  `flutter analyze` and `flutter test` were not run here; CI on the branch is the first run. See "Verification status (5b)".
- The unit check of the amount field: `<input type="number">` is approximated as in 5a (allow `0-9 e E + - .`, parse with `parseFloat`).
- Placeholder colour is the Tailwind 4 default (text colour at 50%); not compared against a device.

## Verification status (5b)
Written but not executed locally. Tests: `test/ui/screens/currency_screen_test.dart` (formatting, six tabs and icons, tab-switch
click, built-in rates render, watchlist values, typing and presets, empty input, swap, tile tap, pickers, copy text and tick,
tablet and phone layouts, live status and cache write, cached fallback label, refresh button disabled while updating).
Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

## Parity doubts (5b)
1. The status bar's two texts split a narrow row by their own width (like CSS `flex-shrink`); checked by reasoning, not on a device.
2. `font-mono` is the app font with tabular figures, as in the other screens.
3. The long amount breaks between any two characters only when it does not fit (CSS `break-all`).
4. The converter's swap button (5a) is laid out with an `OverflowBox`; the currency one uses two 8 px gaps (16 px gap minus the
   `-my-2` margin). Same geometry, but the 5a button's outer 8 px are not tappable. Worth changing in a later cleanup.

# Phase 5a: Converter

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
