# Phase 4a: calculator screen (plain behaviour)

Phase 4 is split. 4a (this) is the existing calculator behaviour on the Flutter screen. 4b (rich sub/superscript editor,
Part 2, plus the Part 9 structured node model) is NOT done yet.

## What is here
- `lib/ui/calculator/calculator_controller.dart`: handlers ported line by line from the React screen (input, functions,
  templates, parentheses, backspace token list, y=f(x) mode, live preview, memory, history stepping, shortcuts, paste).
- `calculator_screen.dart`, `advanced_keys.dart`, `calc_style.dart`, `auto_fit_text.dart`: portrait and landscape layouts,
  the fx ADV drawer with its five tabs.
- `lib/ui/icons/lucide_icon*.dart` + `tools/gen_lucide_paths.mjs`: icon paths generated from lucide-react 0.546.0
  (CI runs `--check` against that version).
- `lib/ui/shell/intrinsic_cache.dart`, `SwipeableTabContainer` got `tabPillColor` and `fillHeight`.

## Not ported / not done
- Rich editor (4b), Casio fx-991ES work (Part 9, Phases 8a-8e).
- Key click sound is still silent (`PlatformFeedbackService.playClick` is empty).

## Verification status
Nothing was compiled or run in the authoring sandbox (no Dart SDK). CI (analyze, test, APK) is the only check. Tests
for the controller pin behaviour read from the TSX source; there is no executable oracle for the React handlers.
Run: `cd flutter_app && flutter pub get && flutter analyze && flutter test`.

## Known parity doubts
- `=` key radius for 640-767 px wide.
- AutoFitText at its minimum size clips on the left instead of scrolling sideways.
- Row-height floor `max(rowMin, keyMinH)` vs CSS grid overflow.
- Result entry animation is a 380 ms tween, not the web spring.
- Haptics are approximations; keyboard handler never consumes events; first-frame drawer height uses an estimate.
