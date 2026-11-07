# Phase 4b: rich expression editor (Part 2)

The calculator display is now a node tree with a caret instead of a plain string. Superscripts and subscripts are drawn
raised and lowered, typed characters go inside them, and the engine still receives the same kind of text as before.

## What is here
**Editor** (`lib/editor/`)
- `nodes.dart`: `CharNode`, `SupNode`, `SubNode` (sealed, so the Part 9 structured nodes can be added in 8a), compact JSON.
- `linear.dart`: `parseLinear` / `serializeNodes`. **Lossless for every string**: `serializeNodes(parseLinear(s).nodes) == s`.
  A superscript becomes `^x` for a plain number or word, `^(...)` otherwise. A bare exponent that a following character
  would run into is parenthesised (`x²` then `3` is `x^(2)3`, never `x^23`), and an unclosed `(` in a group that is not
  last is closed. `normalizeUnicodeScripts` (paste only): `x²` -> `x^2`, `x⁻¹` -> `x^(-1)`, `H₂O` -> `H_2O`.
- `expr_doc.dart`: the document plus caret `(path, offset)`: insert, enter/leave groups, left/right, exit, backspace
  (token-aware), 3 nesting levels at most, JSON, spoken form for screen readers.
- `rich_layout.dart`: layout of rows with raised/lowered groups (0.62x first level, then smaller, floor 0.45x; raised
  0.38 em, lowered 0.25 em), caret geometry, tap hit testing.
- `rich_expression_view.dart`: `RichExpressionView`. In `fit` mode it is `AutoFitText` (same fit rule, same style);
  text without groups is one run, so size and look equal the old display (a test compares it with `RenderAutoFitText`).
  Blinking caret, tap to place the caret, `Semantics` label.

**Controller / screen / history**
- `CalculatorController` holds an `ExprDoc`; `_expression` is a getter/setter pair (serialize / parse), so every existing
  string handler is unchanged. Typing at the end of the line appends the new tail (a group the user just left stays
  closed). Typing while the caret is inside a group or away from the end works on the tree (`_treeInput`,
  `_treeCall`, `_treeParentheses`). Backspace works on the tree. Results and messages are plain (never parsed).
- Screen: portrait uses `RichExpressionView(fit)`, landscape `RichExpressionView(fixed)` with the old Tailwind line box.
  An exit chip (`→`) appears in the badge row while the caret is inside a group. Hardware keys: ArrowLeft/Right move the
  caret, `_` starts a subscript. History tape (landscape) draws entries that have a tree with real sup/sub.
- History: `HistoryItem.rich` (optional, same storage key). Entries from before 4b load from their text.

## Deliberate behaviour changes (Part 2)
1. After `^` (or the `xʸ` key) the caret is inside the superscript and everything typed stays there until the exit chip,
   the right arrow or a tap moves out. `2 ^ 3 + 4 =` therefore gives `2^(3+4)` = 128 (it was 12). `x²`, `x³`, `x⁻¹`,
   `10ˣ`-style keys still insert a finished power and leave the caret after it.
2. `x²` then a digit gives `x^(2)3` (x squared, then 3). The old text field gave `x^23`. Old strings such as `x^23` still
   load as exponent 23.
3. Backspace after a power: first enters it, then deletes its content, then removes the empty group (one more press than before).
4. Pasting Unicode superscripts/subscripts is now accepted (it was ignored).

## Not done / open
- **Subscript has no keypad key**: reachable by the hardware `_` and by paste. The keys `log₂`, `log_b` still insert the
  text `log2(` / `logb(` and show it as before (showing them as real subscripts would change the display; say if you want it).
- **No exit key on the keypad** (adding one changes the grid). The chip in the badge row is the touch way out; please check it feels right.
- Selection, drag, cut/copy of part of an expression: not done. Whole-expression copy gives the linear string.
- The screenshot goldens of Part 2 (`2^(3+x²)`, `x₁+x₂`, `log₂(8)`, `H₂SO₄`) are not added: they need baselines.
- Speed of editing a 200-character expression is not measured.
- The `lastQuestion` line above the answer is still plain text (`2^(3+4) =`).
- `parse(serialize(tree)) == tree` holds for the trees the tests build, not for every tree (`Sup[3,+,4]` and
  `Sup[(3+4)]` print the same text). The text itself never changes, which is the property that matters to the engine.
- Structured nodes (fraction, root, integral...), placeholders and wrap-in-function are Part 9 / Phase 8a.

## Verification status
**Not compiled in the authoring sandbox** (no Dart SDK reachable). CI is the check: the first push (`41c5177`) failed 5 tests whose
expectations were wrong (test-font ascent/descent, display tracking of -0.025 em, landscape display lookup); fixed in `fef56dc`,
and Flutter CI (analyze, all tests) is green on it. Not yet tried on a device.
Tests added: `test/editor/linear_test.dart` (round trip over all golden expressions, 4000 random strings, structure,
caret rules, JSON, Unicode), `expr_doc_test.dart`, `rich_layout_test.dart` (exact numbers with the Ahem test font),
`rich_expression_view_test.dart` (parity with `AutoFitText`, taps, blink, semantics), `test/ui/calculator_rich_test.dart`
(controller flows), `test/state/history_rich_test.dart`. `test/ui/calculator_screen_test.dart` now finds the display via
`RichExpressionLeaf` instead of `AutoFitText`.
Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

## Parity doubts
1. The caret bar size (0.82 em above, 0.22 em below the baseline) and the 530 ms blink are mine, not from the web app (it has no caret).
2. At the smallest size a long line is clipped on the left; the view scrolls so the caret stays visible, plain text behaves as in 4a.
3. Line box with groups: raised groups can make the display taller than before; the box grows only when a group is present.
