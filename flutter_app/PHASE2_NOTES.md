# Phase 2 - Engines (units, finance, SWP, physics, currency)

## What changed
- `lib/engine/units.dart`, `unit_types.dart`, `units_data.dart`: `convertUnit` (line-by-line port) and the 13 converter categories.
- `lib/engine/finance.dart`: `FinanceEngine` (loan with GST + processing fee, compound with step-up, tip, ROI/CAGR, depreciation).
- `lib/engine/swp.dart`: `calculateSwp` (+ positional form), depletion-month logic and per-row rounding as in the TS.
- `lib/engine/physics.dart`, `physics_constants.dart`: projectile, relativity, photon, electromagnetism solvers + the 29 constants.
- `lib/engine/currency.dart`, `currency_data.dart`: the 37 currencies, fallback rates, `convertCurrency`, and `CurrencyService`
  (4 providers queried in parallel, first valid answer wins, 8 s timeout each, same sanitising and 90 % coverage rule,
  cache under the same key `omni_calc_live_rates_cache` and JSON shape, built-in fallback).
- `tools/gen_engine_data.ts` (new): writes `units_data.dart`, `physics_constants.dart`, `currency_data.dart` from the TS source.
  Nothing in those tables is typed by hand. `--check` fails if the committed files differ.
- `tools/gen_vectors.ts` (extended) + `tools/vector_inputs/*.json` (new): the Phase 2 vectors are now regenerated from the real
  TS engine like the Phase 1 ones.
- `pubspec.yaml`: added `http` and `shared_preferences` (the only packages this phase uses).
- Tests: `units_golden_test`, `finance_golden_test` (loan, compound, tip, roi, depreciation, swp), `physics_golden_test`,
  `currency_golden_test`, `currency_service_test` (provider parsing, sanitising, race, timeout, cache, fallback with a fake network).

## Requested change: logos on the converter tabs (applies in Phase 5, data is ready now)
Every other tab strip (Finance, Physics) has an icon beside each label; the converter had none. Each converter category already
has an `iconName` in the engine data (Ruler, Scale, Thermometer, Square, Box, Gauge, HardDrive, Clock, Activity, Zap, Compass,
Activity, Magnet), carried over unchanged into `unitCategories` and checked by `units_golden_test`. In Phase 5 the converter
tab strip will draw them exactly like the Finance tabs (icon left of the label, same size and spacing).
Open point: Pressure and Frequency both use `Activity`. Say if you want one of them changed.

## Verified here (honest status)
- `npx tsx flutter_app/tools/gen_vectors.ts --check`: the repo's TypeScript engine reproduced all 17 committed golden files
  from your golden.zip exactly before anything was added, so the zip is the oracle for this source. After adding edge cases
  (NaN, Infinity, -0, zero/negative/fractional terms, unknown units and codes) the files hold 3,400 engine vectors + 13 catalog entries.
- `npx tsx flutter_app/tools/gen_engine_data.ts --check`: generated Dart data matches the TS source (87 units parsed = 87 in the source,
  29 constants, 37 currencies).
- **NOT verified: any Dart code.** The sandbox cannot reach the Dart/Flutter SDK hosts, so `flutter analyze` and `flutter test`
  have not been run. I re-read every file against the TS, but nothing here is claimed to compile or pass yet.

## Run it yourself
```
cd flutter_app
flutter pub get && flutter analyze && flutter test
```
Regenerate (repo root): `npx tsx flutter_app/tools/gen_vectors.ts` and `npx tsx flutter_app/tools/gen_engine_data.ts`.

## Not yet ported
Theme/shell (3), calculator screen + rich editor (4), tool screens incl. the converter logos (5), chemistry (6), hardening (7).
Settings persistence and the currency UI state arrive with Phases 3 and 5; `CurrencyService` is UI-free.

## Parity doubts to watch when the tests first run
1. `math.sin/cos/atan2` (projectile, electromagnetism) use the platform libm, V8 uses fdlibm. Raw doubles are compared at
   1e-9 relative, so a last-digit difference passes, but a result that cancels to ~0 could differ.
2. Zeros are also compared by sign (`-0` vs `0`). Both sides follow IEEE for the same formulas, so this should hold, but it is
   the first thing to check if a projectile vector fails.
3. The "last updated" label (`formatStamp`) uses the device locale in the web app (`toLocaleTimeString`). The Dart port defaults
   to 24-hour `HH:mm` and `d MMM, HH:mm` (12-hour available via `StampStyle.h12`). Please tell me what the web app shows on your phone.
4. Network error text in `RatesData.error` (shown only when live rates fail) comes from Dart exceptions, so it will not match the
   browser's wording; the timeout/HTTP/shape messages do match.
5. `jsPow` wraps Dart's `pow`; the SWP schedule rounds to whole rupees, so a 1-ulp pow difference could in theory flip a half-rupee.
6. `golden.zip` in `test/golden/` is your original and is left untouched; the JSON files beside it are the extended vectors.
