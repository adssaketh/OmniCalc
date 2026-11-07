# fx-991ES PLUS coverage matrix

Status after **Phase 7c** (COMP engine, calculus, SOLVE, CALC). Rows follow the function inventory of Part 9 (section 9.5, "Function inventory").
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
| A06 | `×10ˣ` (E entry; no dedicated key yet) | Partial | 7e | test/casio/casio_engine_test.dart |
| A07 | `Ans` | Done | 7b | test/casio/casio_engine_test.dart |
| A08 | `PreAns` | Done | 7b | test/casio/casio_engine_test.dart |
| A09 | `AC` | Done | 4 | test/ui/calculator_controller_test.dart |
| A10 | `DEL` | Done | 4 | test/ui/calculator_controller_test.dart |
| A11 | `INS` | Done | 8a | test/ui/calculator_es_test.dart |
| A12 | `ON` | Deferred | 7e | - |
| A13 | `OFF` | Deferred | 7e | - |
| A14 | `SHIFT` | Done | 8a | test/ui/calculator_es_test.dart |
| A15 | `ALPHA` | Done | 8a | test/ui/calculator_es_test.dart |
| A16 | REPLAY pad (◀ ▶ ▲ ▼) | Done | 8a | test/ui/calculator_es_test.dart |
| A17 | `MODE` | Deferred | 7d | - |
| A18 | `SETUP` (display format, angle incl. Gra, number format, fraction format, Rdec; complex, STAT, TABLE, Disp, CONT remain) | Partial | 7d | test/casio/casio_settings_test.dart |
| A19 | `CLR` Setup / Memory / All | Deferred | 7e | - |
| A20 | `STO` | Done | 7b | test/casio/casio_engine_test.dart |
| A21 | `RCL` (a variable can be typed; no RCL key yet) | Partial | 7e | test/casio/casio_engine_test.dart |
| A22 | `M+`, `M−` (existing OmniCalc memory keys; the Casio M variable is not tied to them yet) | Partial | 7e | test/ui/calculator_controller_test.dart |
| A23 | variables `A B C D E F M X Y` | Partial | 7e | test/casio/casio_engine_test.dart |
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
| A34 | `i` | Deferred | 7d | - |
| A35 | `DRG▸` (the ° ʳ ᵍ marks are done; the menu key is not) | Partial | 7e | test/casio/casio_engine_test.dart |
| A36 | `÷R` | Done | 7b | test/casio/guide_examples_test.dart |
| A37 | `GCD(` | Done | 7b | test/casio/guide_examples_test.dart |
| A38 | `LCM(` | Done | 7b | test/casio/guide_examples_test.dart |
| A39 | `Int(` | Done | 7b | test/casio/guide_examples_test.dart |
| A40 | `Intg(` | Done | 7b | test/casio/guide_examples_test.dart |
| A41 | recurring-decimal input | Deferred | 7e | - |
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
| C01 | stacked fraction (input 8a; the result is shown as `a⌟b` text, stacked result layout waits) | Partial | 7e | test/casio/casio_controller_test.dart |
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
| X02 | error messages (Math, Syntax, Argument; the others belong to their modes) | Partial | 7e | test/casio/casio_engine_test.dart |
| X03 | calculation style, percent style, result display settings | Done | 7b | test/casio/casio_settings_test.dart |
| X04 | differences from the legacy engine listed | Done | 7b | test/casio/legacy_diff_test.dart |
| F01 | `∫` | Done | 7c | test/casio/calculus_test.dart |
| F02 | `d/dx` | Done | 7c | test/casio/calculus_test.dart |
| F03 | `Σ` | Done | 7c | test/casio/calculus_test.dart |
| F04 | `∏` | Done | 7c | test/casio/calculus_test.dart |
| F05 | `SOLVE` | Done | 7c | test/casio/solve_calc_test.dart |
| F06 | `CALC` | Done | 7c | test/casio/solve_calc_test.dart |

Sections H to R (CMPLX, STAT, BASE-N, EQN, MATRIX, VECTOR, TABLE, INEQ, VERIF, DIST, persistence) are Deferred to 7d
(H to N) and 7e (O to R). Their rows are added to this file when each phase starts, one row per inventory item.
