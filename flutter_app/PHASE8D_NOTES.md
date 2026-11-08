# Phase 8d notes: closing Phase 8 (docs only)

Branch `flutter-rewrite`. No code changed, so no new tests and no version bump (still 1.2.0+2). I did not run `flutter analyze` or `flutter test` in this phase (docs only); the last measured numbers are the 8c ones: 6141 passed, 8 skipped, 0 failed, 42 analyze infos.

## Done
- Signing confirmed from the user's CI screenshot: the run produced the artifact `OmniCalc-Flutter-Release-Signed-APK` (25.5 MB), so the four OMNI_* secrets exist. Two CI warnings remain (setup-java v4 deprecated, ubuntu-latest label migration); neither blocks the build.
- `docs/QA_CHECKLIST.md`: added the Phase 8b and 8c phone checks and a "Known open items" list.
- `docs/FX991ES_COVERAGE.md`: status line updated (rows unchanged).

## Not done
- O04 (INEQ Linear Display layout): the manual text extracts only "Solutions are displayed as shown here when Linear Display is selected" (guide p.83-84); the layouts are images and the PDF could not be opened as images here. Stays Partial. To close it: send photos or screenshots of guide pages 83 and 84.

## Next
- Phase 9 (the user's request after 8d). Phase 8 itself has no code work left apart from O04.
