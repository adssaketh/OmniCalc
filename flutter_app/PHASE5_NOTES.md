# Phase 5: tool screens (in steps)

Phase 5 is split. **5a is the Converter, 5b is Currency, 5c is the other five Finance tabs plus the converter swap-button fix, 5d (below) is Physics Lab.**
Still to do: 5e Grapher, 5f History tape + Settings modal + Guide sheet (these replace `dev_settings_sheet.dart`).

# Phase 5d: Physics Lab

## What is here (5d)
- `lib/ui/screens/physics_screen.dart`: port of `PhysicsScreen.tsx` (five tabs: Constants, Kinematics & Projectiles, Special Relativity,
  Quantum & Waves, Electromagnetism, with Atom / Orbit / Sparkles / Flame / Zap icons). `screens.dart` now builds it for
  `CalculatorMode.physics`; the shell stand-in is no longer used by the app.
  - Constants: search box (name, symbol, id, unit, case-insensitive), seven category chips (scrolling strip), the 29-row table
    (symbol, name + one-line description, value, units, Copy and Calc buttons). Value column rule is the TS one
    (`toExponential(6)` at >= 1e4 or <= 1e-3, else the plain number). Copy puts `value.toString()` on the clipboard and shows the
    tick for 1.8 s; **Calc** goes through `NavigationState.selectResult` (loads the calculator with the number, as `handleSelectResult`).
  - Projectile: four number fields, the trajectory card (ground line, 3 px path, apex dot) and the four results. The `<svg viewBox="0 0 400 120"
    preserveAspectRatio="none">` is reproduced with a `CustomPainter` that scales x and y separately, so the strokes and the dot
    stretch exactly like in the browser. Path and apex maths are `trajectorySvgPoints` / `trajectoryApex` (unit-tested).
  - Relativity, Quantum (mode select, photon results, photoelectric card) and Electromagnetism: same fields, labels, colours, formats.
  - Number fields keep the React controlled `type="number"` rules (clearing reads `0`; gravity falls back to 9.81, distance to 0.01;
    text that is not a valid number reads as empty), same as the Finance fields.
- `OptionSelect` got optional `fill`, `background`, `radius`, `padding` (defaults unchanged) for the full-width Quantum mode select.
- Lucide: Search, Atom, Orbit, Sparkles, Flame added to the generator; 34 icons, `--check` passes against lucide-react 0.546.0.
- Tests: `test/ui/screens/physics_screen_test.dart` (expected strings come from running `src/engine/physics.ts` and the screen's formulas
  with tsx): value formatting, filter, trajectory geometry, every tab's defaults and edited values, mode picker, copy / Calc, layouts.

## Deliberate differences (5d)
- The Quantum mode picker opens a dialog list instead of the Android `<select>` list (same options), like the other pickers.
- No number-input spinner / wheel; no row hover colour; the value cell is not `select-all`; `thead` is not sticky (in the web app it cannot
  stick either: the table wrapper has no fixed height).
- Focus ring (`focus:ring-2`) is drawn as a 2 px primary box-shadow ring.

## Not done / open (5d)
- 5e Grapher, 5f History / Settings / Guide.
- No screenshot goldens and no device check.

## Parity doubts (5d)
1. **Search box and chip strip on sm and wider.** In CSS the strip keeps its natural width and the `flex-1` search box gets the rest,
   but the box cannot go below its own padding (56 px); between 640 and about 900 px the strip therefore scrolls and the search box is
   narrow. The width split is computed by hand to match this; not compared on a device.
2. **Table column widths** are the content-proportional approximation of `table-layout: auto` used in 5c (name column takes the rest
   and shrinks to its longest word; table at least 620 px wide, scrolls sideways below that).
3. **Row divider colour.** The TSX sets `borderColor` on `<tbody className="divide-y">`; `border-color` is not inherited, so a browser may
   draw the dividers in the row's text colour instead of `--m3-outline-variant`. Ported as `outline-variant`, like the Finance tables.
4. The description line (`text-[10px]`) is assumed to inherit the table's `text-xs` line height (1.333) and to be mono, because only the
   name has `font-sans`.
5. Placeholder is the text colour at 30 % (Tailwind's 50 % times `placeholder:opacity-60`).


# Phase 5c: Finance tabs (Loan, SIP & Compound, SWP, Tip, ROI) + swap button fix

## What is here (5c)
- `lib/ui/screens/finance_widgets.dart`: shared pieces ported from the repeated markup of the five TSX calculators: `FinanceLayout`
  (1 column below md, 2 from md), `InputCard`, `CardHeader`, `FinanceNumberInput` (React controlled number-input quirks),
  `PresetChips`, `FinanceCheckbox`, `ResultsCard`, `HeadlineRow`, `RatioBar` (500 ms width transition) / `RatioLegend`,
  `MetricGrid`, `Footnote`, `CollapsibleTable` / `FinanceTable`, `formatMoney` (`Math.round` then en-IN grouping), parse helpers.
- `loan_screen.dart` (Loan / EMI, optional GST + processing-fee taxes, amortisation schedule), `compound_screen.dart`
  (SIP & Compound, year-by-year table), `swp_screen.dart` (depletion warning, timeline), `tip_screen.dart`, `roi_screen.dart`.
  `finance_screen.dart` now shows them; the "(Phase 5c)" stand-in is gone.
- `engine/js_locale.dart`: `jsToLocaleStringEnIN` (Indian digit grouping, `toLocaleString('en-IN')`).
- Lucide: `triangle-alert` (`AlertTriangle`) added to the generator; 29 icons now, `--check` passes against lucide-react 0.546.0.
- Converter swap button: phone layout is now `SizedBox(gap - 8)`, `Center(_swapButton)`, `SizedBox(gap - 8)` like Currency; the
  `OverflowBox` is gone, so the whole 40 px circle takes touches. md layout unchanged. New test taps the top and bottom edges.
- Tests: `test/ui/screens/finance_tabs_test.dart` (expected numbers come from running the TS engine with tsx), the swap test, and
  the Currency test's stand-in assertion now checks the real SWP screen.

## Deliberate differences (5c)
- The results card is not sticky on md+ (`sticky md:top-4` in the web app).
- The checkbox is an approximation of the browser one (16 px, accent fill, tick black/white by luminance, `outline` border unchecked).
- Table column widths approximate CSS `table-layout: auto` (content-proportional; horizontal scroll when too wide).
- No number-input spinner / mouse wheel handling.
- Placeholder colour is the text colour at 50 %.
- `HeadlineRow` clips instead of overflowing when a value is too wide; `RatioBar` clips the brief over-100% sum during a transition (CSS shrinks the items instead).

## Not done / open (5c)
- 5d Physics Lab, 5e Grapher, 5f History / Settings / Guide.

## Verification status (5c)
CI (gen checks, lucide check, analyze, all tests, APK) is green on the final 5c commit. Not run on a device. Three CI rounds: the first
had 16 failing tests (my test helper resized the window after switching tab, which remounts the screen and resets the tab), the second
4 (a transient ratio-bar overflow while a new segment appears during the 500 ms width transition, now clipped; two assertions that
forgot legitimately repeated table values), the third passed. Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

## Parity doubts (5c)
- Line height of the `text-[11.5px]` table text below sm is assumed to be 1.5.
- Table column widths and the checkbox look can differ by a few pixels from the browser.
- Tip's round-up flag has no visible numeric effect in the TS engine either (checked), so none here.

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
- No screenshot goldens and no device check. There is no Flutter SDK in the chat sandbox, so everything below was verified by CI
  on the branch, not locally. See "Verification status (5b)".
- The unit check of the amount field: `<input type="number">` is approximated as in 5a (allow `0-9 e E + - .`, parse with `parseFloat`).
- Placeholder colour is the Tailwind 4 default (text colour at 50%); not compared against a device.

## Verification status (5b)
CI (analyze, 4,650 tests passed and 6 skipped, APK) is green on the final 5b commit `d93c6db`. Not run on a device. Two CI
rounds were needed: the first failed analyze (a missing `TextField` import in the new test), the second failed one test
(the tablet layout test compared an amount that the wide test font made wrap; the test now strips the `break-all` spaces, the app
code was unchanged). Tests: `test/ui/screens/currency_screen_test.dart` (formatting, six tabs and icons, tab-switch click,
built-in rates render, watchlist values, typing and presets, empty input, swap, tile tap, pickers, copy text and tick, tablet and
phone layouts, live status and cache write, cached fallback label, refresh button disabled while updating).
Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

## Parity doubts (5b)
1. The status bar's two texts split a narrow row by their own width (like CSS `flex-shrink`); checked by reasoning, not on a device.
2. `font-mono` is the app font with tabular figures, as in the other screens.
3. The long amount breaks between any two characters only when it does not fit (CSS `break-all`).
4. (Fixed in 5c.) The converter's swap button used an `OverflowBox`; it now uses the same two 8 px gaps as Currency.

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
