# Phase 8e notes: O04, the INEQ header and Linear Display layout

Branch `flutter-rewrite`. Version bumped to 1.2.0+3. I did not run `flutter analyze` or `flutter test` in this chat (no Flutter SDK in the sandbox). The last measured numbers are still the 8c ones: 6141 passed, 8 skipped, 0 failed, 42 analyze infos. This phase adds 9 engine tests, 6 widget tests and 1 golden (skipped until its baseline exists), so expect 6156 passed if nothing else moves. That is an expectation, not a result.

## Done
- `lib/engine/casio/ineq.dart`: `IneqResult.layout()` returns the header (`A<X<B`, `X≤A,B≤X`, `X=A,B≤X`, `A<X<B,C<X`) and the named endpoints A, B, C in order along the number line. `lines()` is unchanged. `All Real Numbers` and `No-Solution` return no layout.
- `lib/ui/calculator/ineq_dist_panels.dart`: the header is drawn above the solution in both displays (key `ineq-header`). When SETUP display format is LineIO at the moment Solve is pressed, the solution lines are replaced by one row per endpoint (`ineq-ep-name-i` on the left, `ineq-ep-value-i` on the right) with the decimal value to 10 digits. Changing the type or the relation hides the old answer.
- O04 is Done in `docs/FX991ES_COVERAGE.md` (149 Done, 4 Partial, 0 Deferred), the QA checklist has a new "Phase 8e" section, and the release notes have a 1.2.0+3 entry.

## Decisions taken from the user
- Header also in MathO (the 8d notes said it was already drawn there; it was not).
- Values are the normal 10 significant digits (`-1.263762616`, `0.2637626158`), not 10 decimals.
- Linear layout only for LineIO. LineO (MthIO-LineO) keeps the MathO layout.
- Version bump to 1.2.0+3.

## Unverified on a real device
- Examples 1 and 3 in Linear Display (read only by the same rule as Examples 2 and 4, which the user's page screenshots show).
- A root that is left out between two parts, such as `(x−1)²>0`, is written `X<A,A<X` (one name for one root). The manual shows no such case.

## Not done, on purpose
- MathO keeps one line per part (`X≤-3` and `1≤X` on two lines) as the dialog always did (D-MODE-3). The manual writes the parts on one line separated by commas, with a `▶` scroll indicator when long.
- p.82: AC on the solution returns to the Coefficient Editor with the coefficients kept. The dialog's AC button still zeroes the coefficients.
- The golden `ineq_linear_example4` has no baseline (`test/goldens/casio/` is not committed). Create it with `flutter test --tags golden --update-goldens test/ui/golden_casio_7e_test.dart`. The existing `ineq_example1` baseline, once created, will include the new header.

## Commands
`cd flutter_app && flutter pub get && flutter analyze && flutter test`
