# Phase 8b notes: Hardening, performance and accessibility

Branch `flutter-rewrite`. Measured in the sandbox (Flutter 3.47.9): `flutter test` 6,118 passed, 8 skipped, 0 failed (8a: 6,085 / 8 / 0, so 33 new tests, all in `test/perf/`). `flutter analyze --no-fatal-infos`: 42 infos, 0 warnings, 0 errors (unchanged). GitHub CI: not run by me, check the Actions tab after the push.

## Performance
- **Already in a background isolate (7c):** ∫, d/dx, Σ, ∏ on `=`. AC kills the isolate. Checked, nothing to change.
- **CALC with ∫ d/dx Σ ∏ now runs in the background too** (it used to run on the UI thread). `CasioCalc` got `expression`, `canRunInBackground`, `store()` and `finish()`; the controller reuses the `=` isolate path. AC stops it and leaves the session on its last prompt. CMPLX CALC and CALC without calculus still answer in place (they are instant).
- **DIST: a real freeze fixed.** Binomial CD and Poisson CD summed term by term from 0 to x, and x may be up to 9,999,999,999, so a large x would have hung the UI thread for minutes. Up to x = 100,000 the sum is unchanged (same values as before, so the 48 mpmath vectors still pass). Above that the sum starts at x and walks away from the mean only while terms still matter (lower tail directly, upper tail as 1 − tail). SOLVE and the DIST dialog stay on the UI thread: SOLVE is capped at 30 × 8 iterations of a plain expression (∫ Σ are forbidden in it), and DIST is now bounded.
- **200-character editing:** typing 200 characters and pressing `=` is covered by a test on the controller, and the cost per key does not grow with line length. Frame time on a device was not measured.

## Accessibility
- **TalkBack names for keys.** New `lib/ui/calculator/spoken.dart`: ÷ → "divide", − → "minus", . → "decimal point", ▭/▭ → "fraction", ◀ ▶ ▲ ▼ → "left/right/up/down", Σ▭▭ → "sum", and so on; any other label containing ▭ ∫ Σ ∏ √ ² ³ gets its symbols spelled out. Applied through `Text.semanticsLabel` on the main keys and every Advanced key; the visible text is unchanged. Digits and words (sin, AC) are left as they are.
- **Result is a live region** (portrait display): TalkBack reads the answer after `=` without a swipe, and nothing is announced while typing.
- **Font scaling:** every main screen (Calculator, Converter, Finance, Physics, Chemistry, Grapher, Recents) is checked at 360 wide at 1× and 2× system font, and the calculator at 280, 320 and 360 wide at 1.3×, 1.6×, 2×. No overflow found apart from the header below.
- **The "14px bottom-bar overflow at 360" was not the bottom bar.** It is the OmniCalc header row inside the display card (`header.dart`, embedded mode): logo + name + three buttons did not fit in the 308 px card (14 px at 360, 54 px at 320, in the test font). The name now sits in an `Expanded` + `FittedBox(scaleDown)`: exactly the old size when it fits, smaller only when it does not. The web header has the same fixed row; this is a deliberate difference only on very narrow screens or a large system font (Part 7 rule: report it).

## Honest flags (unverified on a real device)
- All timings are from the sandbox, with generous limits; they catch a hang, not a few milliseconds. No profile on a phone.
- Labels were checked in Flutter's semantics tree, not with a real TalkBack. The wording ("fraction", "box", "left") is my choice, not from any guide.
- The sandbox test font is wider than Roboto, so an overflow can show in a test and not on the phone, and the other way round is possible with another system font. The header fix covers both.
- The Binomial / Poisson CD change above 100,000 was checked at mean, far below and far above the mean (0.5 within 1e-3 for Binomial, within 1e-2 for Poisson, ≈0, ≈1), not against mpmath. The upper tail is 1 − tail, so a result extremely close to 1 loses digits there.
- The landscape display is not a live region yet (only the portrait one).
- CALC asks for the integration variable X as well as the limits (`X?` then `A?` for `∫(X,0,A)`); I did not change this, and I cannot confirm what the real fx-991ES does.

## Next
- 8c: screenshot goldens and the diff report, signing check (secrets OMNI_KEYSTORE_B64, OMNI_KEY_ALIAS, OMNI_KEYSTORE_PASSWORD, OMNI_KEY_PASSWORD), version bump and release notes, and the five open display rows (A41, C01, H10, O04, A18).
