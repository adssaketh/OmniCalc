# Phase 5: tool screens (in steps)

Phase 5 is split. **5a is the Converter, 5b is Currency, 5c is the other five Finance tabs plus the converter swap-button fix, 5d is Physics Lab, 5e is the Grapher, 5f (below) is History tape + Settings + Guide.**
Phase 5 is complete with 5f. Still to do: Phase 6 (see the master prompt).

# Phase 5f: History tape, Settings, Guide

## What is here (5f)
- `lib/ui/widgets/m3_sheet.dart`: `Sheet.tsx` (`M3Sheet`): scrim at 45 %, spring slide, panel `surface-container-low`, radius 32 (top only on
  phones), handle with drag-to-close (6 px to start, closes past 110 px or a flick over 0.6 px/ms after 24 px, else springs back in 260 ms),
  centred card from 640 px wide, `fixedHeight` (88vh, 880 max from sm) for Settings and Guide. Also `SpringReveal`.
- `lib/ui/overlays/history_tape_sheet.dart`: `HistoryTapeModal.tsx`: filters All / Calculator / Physics with counts, cards (time, mode badge,
  plain or rich expression, result, Copy, Formula, Use), export, two-step clear, empty state.
- `lib/ui/overlays/settings_sheet.dart`: `SettingsModal.tsx`: theme, colour mode, AMOLED switch, bar preview, scroll edge effect, fade
  height, bar style with the glass options (transparency slider, blur, edge), angle unit, precision, sound, haptic, vibration strength
  and test buttons, Physics / Grapher switches, About (version, guide, GitHub, privacy sheet), reset with the confirm sheet and the toast.
  Sub-lists close first on back (`NavigationState.innerBack`).
- `lib/ui/overlays/guide_sheet.dart` + generated `guide_content.dart`: `GuideSheet.tsx` and `guideContent.ts`: accordion (starts on "diff"),
  live results through the Dart engine, Try (switches the angle unit, loads the expression, closes guide and history).
- `tools/gen_guide.ts`: writes `guide_content.dart` and `test/golden/guide.json` (42 examples run through the real TS engine the way
  `runExample` does). `--check` mode like the other generators. `gen_lucide_paths.mjs` (now 54 icons) and `gen_svg_paths.mjs` were extended.
- `lib/services/link_service.dart` (`url_launcher`, plus `RecordingLinkService` for tests), `lib/ui/overlays/overlays.dart` (`appOverlays`).
- `dev_settings_sheet.dart` is deleted. `AppShell` defaults to no overlays; `main.dart` passes `appOverlays`.

## Deliberate differences (5f)
1. **Export history** copies the text to the clipboard (`clipboardHistoryExporter`); the web app starts a `.txt` download from a blob, which
   most likely does nothing inside the Capacitor WebView. The text is byte for byte the same (`[time] expr = result (mode)` per line).
2. **Time** on history cards and in the export is 24-hour `HH:mm:ss`; the web app uses `toLocaleTimeString`, i.e. the device locale.
3. **Links** (GitHub, privacy "Standalone Policy" -> PRIVACY.md on GitHub) open with `url_launcher`; the web app uses `<a href>` / `window.open`.
4. No text selection inside the guide examples and no `break-all`; the history result text may wrap on a very narrow phone.
5. Semantic labels of settings rows are simplified (the subtitle is read as the row's value).

## Not done / open (5f)
- Phase 6 items in the master prompt.
- No screenshot goldens and no device check.

## Verification status (5f)
Flutter 3.47.9 in the chat sandbox: `flutter analyze` has no errors or warnings (20 infos, none in 5f files; the others were there before),
the **full suite ran locally: 4,859 passed and 6 skipped** (was 4,770: +89 new). New: guide golden (46: all 42 guide results equal the TS
engine, plus the y(x) setup, the define-an-equation example and angle handling), history sheet (13), settings sheet (17), guide sheet (7),
`M3Sheet` (6). `gen_guide.ts --check`, `gen_lucide_paths.mjs --check` and `gen_svg_paths.mjs --check` pass. CI and a device run are still to do.
The overlay tests use the Flutter test font (wider than the real one), so two use a 630 px wide view; the real phone layout is not compared.
Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

## Parity doubts (5f)
1. **Export on Capacitor.** If the web blob download does work in the Android WebView, the file route (share sheet or Downloads) should replace the clipboard.
2. **Narrow header.** With the "Clear All?" pill showing, the history title column gets narrow on a 360 px phone; the web markup is the same
   (`min-w-0 flex-1`, no truncation) so I kept it, but I did not see it on a device.
3. **Spring and drag feel** of the sheet handle, and the glass preview and blur on a real GPU, are not compared with the web app.
4. **Time format** (difference 2): confirm 24-hour is acceptable, or tell me to follow the device locale.

# Phase 5e: Grapher

## What is here (5e)
- `lib/ui/screens/graph_screen.dart`: port of `GraphScreen.tsx`. `screens.dart` now builds it for `CalculatorMode.grapher`; the shell
  stand-in (`placeholderScreen`) is no longer used by the app, so the `_` case of `appScreenBuilder` is gone.
  - Function bar: `f(x) =` box (default `sin(x)`, placeholder `e.g. sin(x) * 2`), **Plot Function** (op click), Reset View (toggle click,
    scale 40 and origin 0). Enter in the box plots like the form submit does. One column below `sm`, one row from `sm`.
  - Nine presets (`sin(x)`, `cos(x)`, `tan(x)`, `x²`, `x³`, `√x`, `1/x`, `eˣ`, `ln(x)`): fill the box and plot at once (toggle click); the one
    whose expression equals the plotted text is the active chip (primary-container, weight 700).
  - Plot area 360 / 420 / 500 / 560 px tall (base / sm / md / lg). Drawing follows `drawGraph` step by step: background, vertical grid (line,
    then its `toFixed(0)` label at `x + 3, oy - 4`), horizontal grid (label at `ox + 4, y - 3`), axes at 1.5 px, the curve at 2.5 px
    (every second pixel column, `evaluateFunction(expr, x, 'rad')`, a non-finite value or `py` outside `[-100, height + 100]` ends the
    piece), then the `#10b981` dot and the two `[3, 3]` dashed lines. Grid loops use JS `%` semantics (`double.remainder`) and repeated addition.
  - Pan with one finger / the mouse, zoom with the two buttons (x1.25 and /1.25, clamped 10..250) and the wheel (up x1.15, otherwise x0.85,
    same clamp, `deltaY` 0 zooms out as in the browser). A drag that starts on the plot never scrolls the page (`touch-none`): the plot claims
    the pointer with an eager recognizer. A second finger is ignored while two are down, as `handleTouchStart/Move` do.
  - Coordinates tooltip (top-left): crosshair icon, `x: ...`, `·`, `y: ...` with `toFixed(2)` (so `NaN`, `-0.00` and `Infinity` read as in
    the browser). Mouse: shown on hover, hidden on leave. Touch: stays at the point where the finger lifted (the web app never clears it on
    `touchend`).
- `engine`: nothing new; `MathEvaluator.evaluateFunction` is the Phase 1 port.
- Lucide: ZoomIn, ZoomOut, Crosshair added to the generator (RotateCcw was there); 37 icons, `--check` passes against lucide-react 0.546.0.
- `Pressable` got `animated` (default true). The zoom buttons only have `transition-colors`, so their `active:scale-90` jumps at once.
- Vectors: `tools/gen_vectors.ts` now writes `test/golden/graph.json` (37 cases: every preset, pans with negative and fractional origins,
  fractional scales after zoom steps, cursor on / at an asymptote / off the curve, evaluator quirks such as `2x+1`, `x^x`, `bad((`, empty).
  `genGraph()` copies the arithmetic of `drawGraph` and the tooltip with collectors instead of canvas calls and runs the real `MathEvaluator`.
- Tests: `test/golden/graph_golden_test.dart` (every vector: grid positions and label strings, curve pieces point by point, cursor point,
  tooltip strings) and `test/ui/screens/graph_screen_test.dart` (22 widget tests: first view, sizes, icons, Plot / Enter / bad expression /
  presets with their clicks, zoom buttons and clamps, Reset, wheel, drag, drag does not scroll the page, two fingers, hover / pan /
  NaN / leave / touch tooltip, phone / sm / md / lg layouts).

## Deliberate differences (5e)
1. **Pixel-ratio layout (see parity doubt 1).** The plane is laid out at the CSS size of the plot, not at `size * devicePixelRatio`.
   `kGraphReproduceWebPixelRatioQuirk` (top of `graph_screen.dart`) switches the literal behaviour back on.
2. The plot's grid labels use the app font list (`Google Sans`, `Google Sans Text`, `Roboto Flex`, `Roboto`), not the canvas font string.
3. `backdrop-blur` on the zoom pill and the tooltip is not drawn: both sit on opaque `surface-container-high`, so it is invisible.
4. `touchcancel` ends the drag here; the web app never handles it (the drag would stay on until the next `touchend` / `mouseup`).
5. No cursor spinner or focus ring: the input has `outline-none` in the web app too.

## Not done / open (5e)
- 5f History / Settings / Guide.
- No screenshot goldens and no device check. I rendered the painter to a PNG once (dark and light) and looked at it; that is not a golden.

## Verification status (5e)
Flutter 3.47.9 was installed in the chat sandbox this time (the Flutter download host was reachable), so analyze and the **full suite ran
locally**: 4,770 passed and 6 skipped, no analyzer errors or warnings. CI (gen checks, lucide check, analyze, 4,770 tests passed and 6
skipped, APK) is green on `4c167a9`. Not run on a device.
Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

To run them in a new chat sandbox (nothing is kept between chats): `bash flutter_app/tools/setup_flutter_sandbox.sh`, then
`export PATH=/opt/fl/flutter/bin:$PATH CI=true`. It downloads the current stable SDK (about 1.5 GB, a minute or two) and runs `flutter pub get`.

## Parity doubts (5e)
1. **High-density screens.** `resize()` sets `canvas.width = rect.width * devicePixelRatio` and scales the context by the same ratio, but
   `drawGraph` then reads `canvas.width` / `canvas.height` (device pixels) as if they were CSS pixels: the origin goes to
   `width * ratio / 2` and the grid and curve are laid out over `width * ratio` units, of which only the first `width` are visible. On an
   Android WebView with a ratio of 2.6 the axes and the curve would be off the visible canvas, while the tooltip uses `clientWidth / 2`.
   I ported the layout the page has at a ratio of 1 (what the code evidently intends). If the Capacitor app really shows the plane like
   that, set `kGraphReproduceWebPixelRatioQuirk = true`; `GraphFrame` and the painter already take the buffer size.
2. **`-0` labels.** `toFixed(0)` of a tiny negative number is `"-0"`, which the web app draws (only the exact string `"0"` is skipped).
   `jsToFixed` does the same; none of the 37 vectors happens to hit it, so only the `js_number` tests cover it.
3. Label baseline and 1 px line anti-aliasing on a real device are not compared with the browser.
4. The first layout uses an estimated page height of 700 before the natural height is measured (same mechanism as 5a to 5d).

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

## Verification status (5d)
CI (gen checks, lucide check, analyze, 4,711 tests passed and 6 skipped, APK) is green on `dc17d04`. Not run on a device. The first run
(`7f54b50`) failed on tests: two wrong expectations of mine (a value just above 1e-3 prints plain; the test font is wide enough to squeeze
the search box to its minimum) and a **shell bug the new screen exposed**: `SwipeableTabContainer._shouldIgnoreSwipe` cast every scroll
viewport under the content to `RenderViewportBase`, which throws for the private viewport of `SingleChildScrollView`. It now reads `axis` and
`offset` from that one too, with two regression tests in `swipeable_tab_container_test.dart` (the Finance tables and Physics chip strip/table
are `SingleChildScrollView`s). Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

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
