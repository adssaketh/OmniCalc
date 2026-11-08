# Phase 7c notes: calculus, SOLVE, CALC

Branch: `flutter-rewrite`. Coverage rows done: F01–F06 (6/6 of this phase).
Verification (run in the sandbox with Flutter 3.47.9): see the numbers at the end of this file.

## What is here
- `lib/engine/casio/calculus.dart`: adaptive Gauss–Kronrod G7K15 (∫), Ridders central difference (d/dx), `CasioCancel` (AC interrupt).
- `lib/engine/casio/evaluator.dart`, `parser.dart`: `∫(f,a,b,tol)`, `d/dx(f,a,tol)`, `Σ(f,a,b)`, `∏(f,a,b)` (manual linear syntax, p.39–43). `X` is the variable inside f. Σ and ∏ add up exactly (fractions stay fractions).
- `lib/engine/casio/solve_calc.dart`: `CasioSolver` (Newton, p.49–51) and `CasioCalc` (p.47–49).
- `lib/engine/casio/engine.dart`: the four symbols reach the Casio engine in both calculation styles; legacy words `integrate/diff/sum/prod` keep the legacy meaning.
- Editor: `IntegralNode`, `DerivNode`, `SigmaNode`, `ProdNode` (slots: f, lower/at, upper). Linear form `∫(f,a,b)`, `d/dx(f,a)`, `Σ(f,a,b)`, `∏(f,a,b)`; JSON keys `integral`, `deriv`, `sigma`, `prod`; drawn with a large symbol and small limits.
- Calculus tab: the first four keys now insert the structures `d/dx`, `∫▭▭`, `Σ▭▭`, `∏▭▭` (they replaced the keys that typed `diff(`, `integrate(`, `sum(`, `prod(`; those words still work when typed). ES tab: the CALC key (SHIFT = SOLVE, ALPHA = `=`) now works. A fifth row on the ES tab pushed the keypad off the test screen, which is why the keys are not there.
- Controller: SOLVE/CALC sessions (prompt `A?`, `=` advances, AC leaves and restores the line); `=` on a line with ∫ d/dx Σ ∏ runs in a background isolate and AC kills it; no live preview for such lines.
- Tests: `test/casio/calculus_test.dart`, `solve_calc_test.dart`, `calculus_ui_test.dart`; 40 new mpmath vectors in `vectors.json` (`tools/gen_casio_vectors.py`).

## Choices to know about
- Σ is typed `Σ(f,a,b)` as the manual's linear form says, not the master prompt's `Σ(f,x=a..b)`.
- Anything the manual does not state is marked below as unverified.

## Unverified on a real device
- Time Out threshold for ∫ / d/dx (limit of 400 subintervals; internal accuracy 1e-10).
- SOLVE: 30 Newton steps per round and 8 rounds before `Can't Solve`; layout of the `Continue: [=]` and `Can't Solve` screens.
- Prompt text `A?`, and that typing at a prompt replaces the shown value.
- `=` on a CALC/SOLVE result screen goes back through the prompts (the manual shows `5 = 10 =` then `7 = 20 =`; SOLVE assumed the same).
- Forbidden constructs inside an equation or f(x) give Syntax ERROR (the manual names the functions, not the error).
- ∫ result snapped to a π-multiple when it is one (shows `π`), derivative snapped to 0 when below 1e-9 of the function size, L−R snapped to 0 below 1e-13 relative.
- tol below 1e-14 gives Argument ERROR.
- Layout of the four new structures (symbol size, limit placement).
- The 9 unverified items of Phase 7b stay open.

## Not done / limits
- CALC with ∫ inside runs on the UI thread (SOLVE and CALC sessions themselves are synchronous; ∫ d/dx Σ ∏ are not allowed in SOLVE).
- CALC and SOLVE results are not added to the history tape.
- CMPLX in CALC (manual example 2) waits for the CMPLX mode.
- Bottom-bar 14px overflow at 360 width (Phase 6) still unresolved.

## Result
`flutter analyze`: 0 errors, 0 warnings (41 infos, style only). `flutter test`: 5,542 passed, 6 skipped, 0 failed (baseline 5,448 passed). Run in the sandbox.
