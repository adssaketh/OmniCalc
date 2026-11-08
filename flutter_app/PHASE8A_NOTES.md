# Phase 8a notes: Hardening, the leftover Casio rows

Branch `flutter-rewrite`. Measured in the sandbox (Flutter 3.47.9): `flutter test` 6,085 passed, 8 skipped, 0 failed (7e: 6,034 / 8 / 0, so 51 new tests). `flutter analyze --no-fatal-infos`: 42 infos, 0 warnings, 0 errors (unchanged). GitHub CI: not run by me, check the Actions tab after the push.

## Closed (9 of 14 rows)
- A21 RCL, A22 M+/M−, A23 variables: STO and RCL prefix keys (annunciators STO / RCL), keys A B C D E F M X Y, M+ and M− in the ES tab. The OmniCalc memory keys and the Casio M are now one store, saved with the other variables.
- A35 DRG▸: three keys ° ʳ ᵍ.
- X02 Stack ERROR (`lib/engine/casio/stack_check.dart`).
- H11 CALC in CMPLX (`CasioCalc(..., complex:)`).
- K06 EQN: one solution per `=`, ▲ ▼ AC buttons, position counter.
- P05 VERIF 99-byte limit (`CasioInputBytes`).
- R03 Replay history: ▲ ▼ on the ES tab, about 200 bytes, ▼▲ annunciator, cleared by ON, mode change, display-format change, CLR Setup/All.

## Still open (carried on, all five stay "phase 8" in the coverage matrix)
- A41 recurring-decimal input (needs a new editor node and a serializer step).
- C01 stacked fraction in the result, H10 complex a / bi on separate lines in Linear Display, O04 INEQ Linear Display layout (layout rows: best done together with the screenshot goldens).
- A18 SETUP Disp (comma shows only in results) and CONT (contrast).
- I02, L05, M04, N06 stay Partial by design (sheets, D-MODE-1).

## Honest flags (unverified on a real device, no Casio available)
- Stack ERROR sizes (10 numeric, 24 command levels) are NOT in the user's guide; they come from older Casio guides. Listed as D-ERR-2.
- Byte size of each function for the 99-byte limit and the 200-byte replay history: the guide says "3 to 13 bytes" without a table, so every function name counts 3. D-VERIF-1, D-HIST-1.
- How the real unit shows a RCL value in the line (value vs. variable name) is not in the guide; the value is inserted, exact form kept. D-KEY-1.
- Two ES-tab widget tests got a taller viewport (1900) because the new keys added rows to the ES tab.
- Replayed line cannot be edited with ◀ ▶ yet.
- Code comments in the editor files still say "Phase 8a" for what is really Phase 7a (the project doc was renamed to PHASE7A_NOTES.md); left alone to keep this diff small.
- Release signing: `flutter-ci.yml` already signs the APK when the repository secrets OMNI_KEYSTORE_B64, OMNI_KEY_ALIAS, OMNI_KEYSTORE_PASSWORD and OMNI_KEY_PASSWORD exist and skips quietly otherwise. I cannot read the secrets from here, so whether they are set is unknown (the check is for 8c).

## Next (user's split)
- 8b: performance (200-character editing, background isolate check for ∫ Σ SOLVE DIST, AC interrupt), accessibility (TalkBack labels, font scaling, the 14px bottom-bar overflow at 360 width).
- 8c: screenshot goldens and the diff report, signing check, version bump and release notes, and the five open rows above that are display work.
