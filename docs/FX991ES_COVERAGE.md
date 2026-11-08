# fx-991ES PLUS coverage matrix

Status after **Phase 8d** (everything through INEQ, VERIF, DIST, persistence and the Phase 8 hardening rows; only O04 and the four sheet rows I02, L05, M04, N06 are Partial). Rows follow the function inventory of Part 9 (section 9.5, "Function inventory").
`test/casio/coverage_test.dart` reads this table: a row marked Done or Partial must name an existing test file, and a row
marked Deferred must name the phase that will do it.

Status: **Done** = implemented and tested as the manual describes. **Partial** = the engine part is done and tested, a key or
screen part waits for the phase named in the Phase column. **Deferred** = not started, phase named.

Sections A to E and G are the Phase 7b scope. F and H to R belong to 7c to 7e and are listed at the end as Deferred so the
total is the whole inventory.

| Row | Item | Status | Phase | Test |
|---|---|---|---|---|
| A01 | `+ − × ÷` | Done | 7b | test/casio/casio_engine_test.dart |
| A02 | `=` | Done | 7b | test/casio/casio_controller_test.dart |
| A03 | `(−)` negative sign | Done | 7b | test/casio/casio_engine_test.dart |
| A04 | `( )`, closing parenthesis optional at the end | Done | 7b | test/casio/casio_engine_test.dart |
| A05 | `.` decimal point | Done | 7b | test/casio/casio_engine_test.dart |
| A06 | `×10ˣ` (types ×10 and opens the raised exponent group) | Done | 7e | test/ui/verif_clr_power_test.dart |
| A07 | `Ans` | Done | 7b | test/casio/casio_engine_test.dart |
| A08 | `PreAns` | Done | 7b | test/casio/casio_engine_test.dart |
| A09 | `AC` | Done | 4 | test/ui/calculator_controller_test.dart |
| A10 | `DEL` | Done | 4 | test/ui/calculator_controller_test.dart |
| A11 | `INS` | Done | 8a | test/ui/calculator_es_test.dart |
| A12 | `ON` (a tap on the dark screen wakes the unit; memory is kept) | Done | 7e | test/ui/verif_clr_power_test.dart |
| A13 | `OFF` (OFF key in the Modes tab and ten idle minutes darken the screen) | Done | 7e | test/ui/verif_clr_power_test.dart |
| A14 | `SHIFT` | Done | 8a | test/ui/calculator_es_test.dart |
| A15 | `ALPHA` | Done | 8a | test/ui/calculator_es_test.dart |
| A16 | REPLAY pad (◀ ▶ ▲ ▼) | Done | 8a | test/ui/calculator_es_test.dart |
| A17 | `MODE` menu (COMP, CMPLX, BASE-N, EQN, STAT, MATRIX, VECTOR, TABLE; the last four open sheets instead of Casio screens) | Done | 7d-2 | test/ui/data_modes_test.dart |
| A18 | `SETUP` (display format, angle incl. Gra, number format, fraction format, Rdec, complex format, STAT frequency and TABLE format settings, Disp dot or comma, CONT 1-5 as display brightness) | Done | 8c | test/ui/overlays/settings_disp_cont_test.dart |
| A19 | `CLR` Setup / Memory / All, each with Yes / Cancel (Modes tab) | Done | 7e | test/ui/verif_clr_power_test.dart |
| A20 | `STO` | Done | 7b | test/casio/casio_engine_test.dart |
| A21 | `RCL` (ES tab key, RCL annunciator; recalls the exact value into the line) | Done | - | test/casio/variables_test.dart |
| A22 | `M+`, `M−` (ES tab keys; the OmniCalc memory keys and the Casio M are one store, saved with the other variables) | Done | - | test/casio/variables_test.dart |
| A23 | variables `A B C D E F M X Y` (ES tab keys; STO stores the line or Ans, plain key types the variable) | Done | - | test/casio/variables_test.dart |
| A24 | `:` multi-statements | Done | 7b | test/casio/guide_examples_test.dart |
| A25 | `,` | Done | 7b | test/casio/guide_examples_test.dart |
| A26 | `%` | Done | 7b | test/casio/guide_examples_test.dart |
| A27 | `Rnd` | Done | 7b | test/casio/guide_examples_test.dart |
| A28 | `Ran#` | Done | 7b | test/casio/casio_engine_test.dart |
| A29 | `RanInt#(a,b)` | Done | 7b | test/casio/casio_engine_test.dart |
| A30 | `ENG` | Done | 7b | test/casio/casio_controller_test.dart |
| A31 | `←` (ENG left shift) | Done | 7b | test/casio/casio_controller_test.dart |
| A32 | `π` | Done | 7b | test/casio/casio_engine_test.dart |
| A33 | `e` | Done | 7b | test/casio/casio_engine_test.dart |
| A34 | `i` | Done | 7d-1 | test/casio/complex_test.dart |
| A35 | `DRG▸` (three keys ° ʳ ᵍ in the ES tab instead of a menu) | Done | - | test/casio/input_limit_test.dart |
| A36 | `÷R` | Done | 7b | test/casio/guide_examples_test.dart |
| A37 | `GCD(` | Done | 7b | test/casio/guide_examples_test.dart |
| A38 | `LCM(` | Done | 7b | test/casio/guide_examples_test.dart |
| A39 | `Int(` | Done | 7b | test/casio/guide_examples_test.dart |
| A40 | `Intg(` | Done | 7b | test/casio/guide_examples_test.dart |
| A41 | recurring-decimal input (SHIFT on `×10ˣ` = `0.ṅ`; COMP mode, period up to 14 digits; DEL removes a digit and its mark) | Done | 8c | test/casio/phase8c_display_test.dart |
| B01 | `x²` | Done | 7b | test/casio/guide_examples_test.dart |
| B02 | `x³` | Done | 7b | test/casio/guide_examples_test.dart |
| B03 | `xʸ` / `^` | Done | 7b | test/casio/casio_engine_test.dart |
| B04 | `x⁻¹` | Done | 7b | test/casio/casio_engine_test.dart |
| B05 | `√` | Done | 7b | test/casio/casio_engine_test.dart |
| B06 | `∛` | Done | 7b | test/casio/guide_examples_test.dart |
| B07 | `ˣ√` | Done | 7b | test/casio/guide_examples_test.dart |
| B08 | `10ˣ` | Done | 7b | test/casio/casio_engine_test.dart |
| B09 | `eˣ` | Done | 7b | test/casio/guide_examples_test.dart |
| B10 | `log` base 10 and `log(a,b)` | Done | 7b | test/casio/guide_examples_test.dart |
| B11 | `logₐb` template | Done | 7b | test/casio/guide_examples_test.dart |
| B12 | `ln` | Done | 7b | test/casio/guide_examples_test.dart |
| B13 | `x!` | Done | 7b | test/casio/guide_examples_test.dart |
| B14 | `Abs` | Done | 7b | test/casio/guide_examples_test.dart |
| C01 | stacked fraction (input 8a; MathO results are drawn stacked, LineIO keeps `a⌟b`) | Done | 8c | test/casio/phase8c_display_test.dart |
| C02 | mixed fraction | Done | 7b | test/casio/casio_engine_test.dart |
| C03 | `S⇔D` | Done | 7b | test/casio/casio_controller_test.dart |
| C04 | `ab/c ⇔ d/c` | Done | 7b | test/casio/casio_controller_test.dart |
| C05 | √ form, π form, fraction form results | Done | 7b | test/casio/casio_engine_test.dart |
| C06 | recurring-decimal toggle | Done | 7b | test/casio/casio_controller_test.dart |
| C07 | results in engineering form | Done | 7b | test/casio/casio_engine_test.dart |
| D01 | `sin cos tan` | Done | 7b | test/casio/vectors_test.dart |
| D02 | `sin⁻¹ cos⁻¹ tan⁻¹` | Done | 7b | test/casio/vectors_test.dart |
| D03 | `sinh cosh tanh` | Done | 7b | test/casio/vectors_test.dart |
| D04 | `sinh⁻¹ cosh⁻¹ tanh⁻¹` | Done | 7b | test/casio/vectors_test.dart |
| D05 | Deg / Rad / Gra | Done | 7b | test/casio/vectors_test.dart |
| D06 | `°′″` entry | Done | 7b | test/casio/guide_examples_test.dart |
| D07 | `▸DMS` conversion (S⇔D shows the decimal and the DMS form) | Done | 7b | test/casio/guide_examples_test.dart |
| D08 | `DRG▸` conversion of ° ʳ ᵍ marks | Done | 7b | test/casio/casio_engine_test.dart |
| E01 | `nPr` | Done | 7b | test/casio/guide_examples_test.dart |
| E02 | `nCr` | Done | 7b | test/casio/guide_examples_test.dart |
| E03 | `Pol(x,y)` | Done | 7b | test/casio/guide_examples_test.dart |
| E04 | `Rec(r,θ)` | Done | 7b | test/casio/guide_examples_test.dart |
| E05 | `FACT` | Done | 7b | test/casio/casio_engine_test.dart |
| G01 | CONST (40 entries, CODATA 2014) | Done | 7b | test/casio/casio_engine_test.dart |
| G02 | CONV (40 entries, NIST SP 811) | Done | 7b | test/casio/casio_engine_test.dart |
| X01 | input-range checks, every row of manual p.97-100 | Done | 7b | test/casio/casio_engine_test.dart |
| X02 | error messages (Math, Syntax, Argument, Stack; the others belong to their modes. Stack ERROR sizes are not in the guide, unverified) | Done | - | test/casio/stack_error_test.dart |
| X03 | calculation style, percent style, result display settings | Done | 7b | test/casio/casio_settings_test.dart |
| X04 | differences from the legacy engine listed | Done | 7b | test/casio/legacy_diff_test.dart |
| F01 | `∫` | Done | 7c | test/casio/calculus_test.dart |
| F02 | `d/dx` | Done | 7c | test/casio/calculus_test.dart |
| F03 | `Σ` | Done | 7c | test/casio/calculus_test.dart |
| F04 | `∏` | Done | 7c | test/casio/calculus_test.dart |
| F05 | `SOLVE` | Done | 7c | test/casio/solve_calc_test.dart |
| F06 | `CALC` | Done | 7c | test/casio/solve_calc_test.dart |
| H01 | CMPLX `+ − × ÷` with exact parts | Done | 7d-1 | test/casio/complex_test.dart |
| H02 | CMPLX powers (integer exponents exact, others principal value) and √ of a complex number | Done | 7d-1 | test/casio/complex_test.dart |
| H03 | `∠` polar entry (priority 8) | Done | 7d-1 | test/casio/complex_test.dart |
| H04 | `Abs(` of a complex number | Done | 7d-1 | test/casio/complex_test.dart |
| H05 | `arg(` (−180° < θ ≤ 180°) | Done | 7d-1 | test/casio/complex_test.dart |
| H06 | `Conjg(` | Done | 7d-1 | test/casio/complex_test.dart |
| H07 | `▸r∠θ` | Done | 7d-1 | test/casio/complex_test.dart |
| H08 | `▸a+bi` | Done | 7d-1 | test/casio/complex_test.dart |
| H09 | SETUP complex format a+bi / r∠θ | Done | 7d-1 | test/casio/complex_test.dart |
| H10 | Linear Display: a and bi (or r and θ) on separate lines (Pol/Rec too; MathO shows both on one line) | Done | 8c | test/casio/phase8c_display_test.dart |
| H11 | CALC in CMPLX (p.47-48 example 2) | Done | - | test/casio/calc_cmplx_test.dart |
| J01 | DEC, HEX, BIN, OCT calculation and result conversion | Done | 7d-1 | test/casio/base_n_test.dart |
| J02 | number-mode prefixes `d h b o` | Done | 7d-1 | test/casio/base_n_test.dart |
| J03 | `and or xor xnor` | Done | 7d-1 | test/casio/base_n_test.dart |
| J04 | `Not(` | Done | 7d-1 | test/casio/base_n_test.dart |
| J05 | `Neg(` | Done | 7d-1 | test/casio/base_n_test.dart |
| J06 | ranges (BIN 16 bits, others 32 bits), two's complement, zero-padded output | Done | 7d-1 | test/casio/base_n_test.dart |
| J07 | letters A–F, no fractions (quotient cut off) | Done | 7d-1 | test/casio/base_n_test.dart |
| K01 | EQN simultaneous, 2 unknowns | Done | 7d-1 | test/casio/eqn_test.dart |
| K02 | EQN simultaneous, 3 unknowns | Done | 7d-1 | test/casio/eqn_test.dart |
| K03 | EQN quadratic with X/Y-Value Minimum or Maximum | Done | 7d-1 | test/casio/eqn_test.dart |
| K04 | EQN cubic | Done | 7d-1 | test/casio/eqn_test.dart |
| K05 | no-solution and infinite-solutions messages | Done | 7d-1 | test/casio/eqn_test.dart |
| K06 | Coefficient Editor, one solution per `=` with ▲▼ scrolling (dialog with `=`, ▲, ▼ and AC buttons) | Done | - | test/ui/eqn_panel_test.dart |

| I01 | STAT types: 1-VAR, A+BX, _+CX², ln X, e^X, A·B^X, A·X^B, 1/X | Done | 7d-2 | test/casio/stat_test.dart |
| I02 | Statistics Editor: x, y, FREQ columns (40/20/26 lines), Ins, Del, Del-A (a full-height sheet) | Partial | 7d-2 | test/ui/data_modes_test.dart |
| I03 | 1-VAR results: n, Σx, Σx², x̄, σx, sx, minX, maxX, Q1, Med, Q3 | Done | 7d-2 | test/casio/stat_test.dart |
| I04 | Paired results: Σy, Σy², Σxy, Σx³, Σx²y, Σx⁴, ȳ, σy, sy, minY, maxY | Done | 7d-2 | test/casio/stat_test.dart |
| I05 | Regression coefficients A, B, C and r for the seven regression types, x̂, x̂₁, x̂₂, ŷ | Done | 7d-2 | test/casio/stat_test.dart |
| I06 | Normal distribution P(, Q(, R(, ▸t | Done | 7d-2 | test/casio/stat_test.dart |
| I07 | Changing the type keeps the data between paired types and clears it between 1-VAR and paired; leaving STAT clears it | Done | 7d-2 | test/ui/data_modes_test.dart |
| I08 | Errors: Argument ERROR for an incomplete row or a bad FREQ | Done | 7d-2 | test/casio/stat_test.dart |
| L01 | MATRIX: MatA, MatB, MatC, MatAns, Dim up to 3×3 | Done | 7d-2 | test/casio/matrix_vector_test.dart |
| L02 | MatA+MatB, MatA−MatB, MatA×MatB, k·MatA | Done | 7d-2 | test/casio/matrix_vector_test.dart |
| L03 | det, Trn, Ref, Rref, Abs, MatA², MatA³, MatA⁻¹ (exact fractions) | Done | 7d-2 | test/casio/matrix_vector_test.dart |
| L04 | Dimension ERROR, Math ERROR (singular), Syntax ERROR (wrong power or wrong mode names) | Done | 7d-2 | test/casio/matrix_vector_test.dart |
| L05 | Matrix editor and MatAns screen with STO (full-height sheets) | Partial | 7d-2 | test/ui/data_modes_test.dart |
| M01 | VECTOR: VctA, VctB, VctC, VctAns, Dim 2 or 3 | Done | 7d-2 | test/casio/matrix_vector_test.dart |
| M02 | VctA+VctB, VctA−VctB, k·VctA, Dot, cross product, Abs | Done | 7d-2 | test/casio/matrix_vector_test.dart |
| M03 | Angle between vectors, unit vector through Abs | Done | 7d-2 | test/casio/matrix_vector_test.dart |
| M04 | Vector editor and VctAns screen with STO (full-height sheets) | Partial | 7d-2 | test/ui/data_modes_test.dart |
| N01 | TABLE f(x) with Start, End, Step (defaults 1, 5, 1) | Done | 7d-2 | test/casio/table_test.dart |
| N02 | TABLE f(x) and g(x) (SETUP table format) | Done | 7d-2 | test/casio/table_test.dart |
| N03 | Row limits 30 (f) and 20 (f and g), Insufficient MEM above them | Done | 7d-2 | test/casio/table_test.dart |
| N04 | Argument ERROR for End ≤ Start or Step ≤ 0; Pol, Rec, ∫, d/dx, Σ, ∏ not allowed | Done | 7d-2 | test/casio/table_test.dart |
| N05 | A cell that cannot be calculated shows ERROR; X takes the last x | Done | 7d-2 | test/casio/table_test.dart |
| N06 | Table sheet (a full-height sheet; the ▲▼ scrolling of the Casio screen is a scrolling list) | Partial | 7d-2 | test/ui/data_modes_test.dart |
| O01 | INEQ quadratic `aX²+bX+c` with `<` `>` `≤` `≥` | Done | 7e | test/casio/ineq_test.dart |
| O02 | INEQ cubic `aX³+bX²+cX+d` with `<` `>` `≤` `≥` | Done | 7e | test/casio/ineq_test.dart |
| O03 | Results in interval form (exact endpoints), `All Real Numbers`, `No-Solution` | Done | 7e | test/casio/ineq_test.dart |
| O04 | Coefficient Editor; changing the type zeroes the coefficients; a = 0 is Math ERROR (a dialog; the Linear Display layout of the manual note is not drawn) | Partial | 8 | test/ui/ineq_dist_panels_test.dart |
| P01 | VERIF with one relational operator `=` `≠` `>` `<` `≥` `≤` | Done | 7e | test/casio/verif_test.dart |
| P02 | VERIF chained relations of one direction (`1≤1<1+1`, `3<π<4`, `2²=2+2=4<6`) | Done | 7e | test/casio/verif_test.dart |
| P03 | TRUE / FALSE with Ans = 1 or 0; variables read as their values | Done | 7e | test/casio/verif_test.dart |
| P04 | Syntax ERROR forms of p.86 (empty side, relation inside parentheses / fraction / function, mixed directions, `≠` with an ordering relation, consecutive operators, ÷R / Pol / Rec) | Done | 7e | test/casio/verif_test.dart |
| P05 | VERIF mode on the main line: MODE menu entry, relational keys in the Data tab, `=` answers, 99-byte limit (function sizes unverified) | Done | - | test/casio/input_limit_test.dart |
| Q01 | Normal PD (x, σ, μ) | Done | 7e | test/casio/dist_test.dart |
| Q02 | Normal CD (Lower, Upper, σ, μ) | Done | 7e | test/casio/dist_test.dart |
| Q03 | Inverse Normal (Area, σ, μ; tail always left) | Done | 7e | test/casio/dist_test.dart |
| Q04 | Binomial PD / CD (x or List, N, p) | Done | 7e | test/casio/dist_test.dart |
| Q05 | Poisson PD / CD (x or List, μ) | Done | 7e | test/casio/dist_test.dart |
| Q06 | List screen: up to 25 samples, edit, Ins, Del, Del-A, one result per sample to five digits | Done | 7e | test/ui/ineq_dist_panels_test.dart |
| Q07 | Var format result stored in Ans; `ERROR` in the Ans cell for a sample out of range; Argument ERROR for a Var input out of range | Done | 7e | test/ui/ineq_dist_panels_test.dart |
| R01 | Ans, PreAns, variables A–F, M, X, Y persist across restarts with their exact forms | Done | 7e | test/state/casio_memory_store_test.dart |
| R02 | SETUP choices and the mode (with BASE-N base and STAT type) persist across restarts | Done | 7e | test/state/casio_memory_store_test.dart |
| R03 | Calculation replay history (▲▼, about 200 bytes) cleared by ON, mode change, display-format change and CLR Setup/All | Done | - | test/casio/replay_history_test.dart |
