# Phase 7d-2 notes: STAT, MATRIX, VECTOR, TABLE

Branch: `flutter-rewrite`. Coverage rows added: I01–I08, L01–L05, M01–M04, N01–N06 (A17 now Done).
Verification (sandbox, Flutter 3.47.9): `flutter analyze` has no errors or warnings (42 infos, style only); `flutter test`: 5,886 passed, 6 skipped, 0 failed (baseline 5,564 passed, 6 skipped; this phase adds 322 tests: 49 stat, 243 matrix/vector, 15 table, 15 UI/controller).

## What is here
- `lib/engine/casio/stat.dart`: `StatType` (8 types), `StatData` (editor rows 40/20/26 with FREQ), `CasioStat` (every statistic and regression value, `estimateX/Y`), `NormalDist` (P, Q, R, ▸t), `StatCalc.evaluate` (substitutes stat symbols and commands, then the normal engine).
- `lib/engine/casio/matrix.dart`: `MatVecStore` (MatA–C, VctA–C, MatAns, VctAns), `CasioMatVec` (exact arithmetic with fractions; det, Trn, Ref, Rref, inverse, powers, Dot, cross, Abs).
- `lib/engine/casio/table.dart`: `CasioTable.generate` (f, f and g; caps 30/20; X ends at the last x).
- `parser.dart`: optional `matvec` mode (default off) for the words MatA…, VctA…, Dot, det, Trn, Ref, Rref.
- `lib/ui/calculator/data_sheets.dart`: type dialog, Statistics Editor, matrix/vector editor, MatAns/VctAns result sheet, table sheet.
- Controller: `CasioMode` gains stat, matrix, vector, table; annunciators STAT, MAT, VCT; `=` per mode; MODE menu items 5–8 work.
- New last Advanced tab `Data` (badge STAT). Its keys follow the mode: entry keys in COMP/CMPLX/BASE-N, the statistics keys in STAT, matrix keys, vector keys, and X in TABLE.
- References: `tools/gen_stat_matrix_vectors.py` writes `test/casio/stat_matrix_vectors.json` (mpmath 60 digits for statistics and the normal curve, Python `Fraction` for matrices and vectors): 3 datasets × 7 regressions, 8 normal points, 136 matrix cases, 78 vector cases.

## Not done / differs from the plan
- No automatic switch to Linear display (the display follows the typed structure; see D-MODE-2).
- Mode-changing key rows of the Casio (STAT/DIST menus, OPTN) are replaced by the Data tab and the sheets.
- Fraction display of statistics (for example x̄ = 7⌟3) comes from the exact data path.

## Unverified on a real device
- Exact-fraction display of means and sums in STAT.
- The quartile method (medians excluded from the halves).
- Order of x̂₁ and x̂₂ for the quadratic regression, and that r is not available for it.
- A blank FREQ counts as 1; the error kinds for an incomplete row.
- 2D×2D cross product giving a 3-vector.
- Matrix or vector divided by a scalar, and scalar plus matrix errors.
- Pivot choice of Ref (first non-zero entry).
- TABLE: ERROR cells, and the error kind for forbidden functions (Syntax ERROR assumed).
- Layouts of all sheets and the MatAns screen.
