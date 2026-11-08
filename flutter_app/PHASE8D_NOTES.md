# Phase 8d notes: closing Phase 8 (docs only)

Branch `flutter-rewrite`. No code changed, so no new tests and no version bump (still 1.2.0+2). I did not run `flutter analyze` or `flutter test` in this phase (docs only); the last measured numbers are the 8c ones: 6141 passed, 8 skipped, 0 failed, 42 analyze infos.

## Done
- Signing confirmed from the user's CI screenshot: the run produced the artifact `OmniCalc-Flutter-Release-Signed-APK` (25.5 MB), so the four OMNI_* secrets exist. Two CI warnings remain (setup-java v4 deprecated, ubuntu-latest label migration); neither blocks the build.
- `docs/QA_CHECKLIST.md`: added the Phase 8b and 8c phone checks and a "Known open items" list.
- `docs/FX991ES_COVERAGE.md`: status line updated (rows unchanged).

## Not done
- O04 (INEQ Linear Display layout): the manual text has only the image captions, so it stayed Partial in 8d until the user sent screenshots of guide pp. 82-84 (spec below). To be built in the leftovers chat.

## Next
- Phase 9 (the user's request after 8d). Phase 8 itself has no code work left apart from O04.

## O04 spec, read from the user's screenshots of guide pp. 82-84 (to build next)
MathO (as drawn today): header line names the shape, the solution is on the line below.
- Quadratic `<`/`>`: header `A<X<B`, result `-3<X<1` (Example 1). `≤`/`≥` outside: header `X≤A,B≤X`, result `X≤-3,1≤X` (Example 2).
- Cubic: Ex. 3 header `X=A,B≤X`, result `X=0, 3/2≤X` (stacked fraction). Ex. 4 header `A<X<B,C<X`, result `(-3-√21)/6<X<0, (-3+√21)/6<X` with a `▶` scroll indicator (long result scrolls with ▶ ◀).
Linear Display (the part not drawn yet): header line is the same shape text, then one line per endpoint, name left, value right, decimals to 10 digits:
- Ex. 2 (quadratic outside): `X≤A,B≤X` then `A=` -3 and `B=` 1.
- Ex. 4 (cubic): `A<X<B,C<X` then `A=` -1.263762616, `B=` 0, `C=` 0.2637626158 (three lines, screen holds the header plus the lines).
- Special results unchanged: `All Real Numbers`, `No-Solution` (same in both displays).
Also on p.82: AC returns from the solution to the Coefficient Editor; solutions cannot be converted to engineering notation; changing the type zeroes the coefficients.
Plan for the new chat: draw this in the INEQ solution dialog (Linear when SETUP display is LineIO), add widget tests and a screenshot golden, flip O04 to Done, update coverage, QA checklist and release notes.
