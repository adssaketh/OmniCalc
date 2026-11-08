# Phase 8c notes

Done: A18 (Disp + CONT), A41 recurring input, C01 stacked fraction results, H10 two-line results (complex, Pol/Rec). Version 1.2.0+2, docs/RELEASE_NOTES.md.
Not done: O04 (the manual's Linear Display layout is only an image; not drawn, row stays Partial).

Tests: analyze 42 infos (unchanged baseline), flutter test 6141 passed / 8 skipped / 0 failed (before: 6118/8/0).

Screenshots: test/screenshots (tag `screenshots`), 118 baselines in test/goldens/regression, rendered by this app in the Flutter test font
(glyphs are boxes), so they catch layout changes only; they are NOT a diff against the web app (no Chrome here). Compare:
  OMNI_SCREENSHOTS=1 flutter test test/screenshots
Refresh: flutter test test/screenshots --update-goldens   (CI job `screenshots`, Flutter 3.47.9; failures upload images).
Parity goldens (tag `golden`) still have no baselines.

Signing: CI already signs when OMNI_KEYSTORE_B64 (+ alias and two passwords) are set; it now writes signed/unsigned to the job summary.
Whether the secrets exist cannot be read from here: check the CI summary.

Known caveats: recurring marks expand only in COMP; MathO Pol/Rec is on one line; changing display format while a result is shown may refresh on next interaction.
