# OmniCalc

A phone-first calculator suite for Android: a scientific calculator with the full function set of the Casio fx-991ES PLUS (2nd edition), a unit and currency converter, finance tools, a physics lab, chemistry tools and a function grapher.

- **App ID:** `com.saketh.omnicalc`
- **Stack:** Flutter (Android), code in [`flutter_app/`](flutter_app)
- **Offline:** everything works without a network except live currency rates (cached rates are used offline)

## What it is

- **Calculator:** natural input (stacked fractions, roots, powers), decimal results by default (S⇔D shows the fraction, √ or π form), CMPLX, BASE-N, EQN, STAT, MATRIX, VECTOR and TABLE modes, Ans and variables, a recents tape.
- **Converter, Finance, Physics Lab, Chemistry, Graph:** separate screens, reachable from the bottom bar.
- **Made for a phone:** it is not a Casio emulator. The calculator's hardware limits and behaviours (auto power-off, OFF key, display contrast, stack depth, small STAT and TABLE sizes, reopening in the last mode) are gone. The remaining differences from the calculator are listed in [`docs/INTENDED_DIFFERENCES.md`](docs/INTENDED_DIFFERENCES.md).
- **Settings:** themes (including Material You and AMOLED), glass or solid bars, angle unit, number format, result display, sound and haptics.

## Build

The app is built by GitHub Actions (`.github/workflows/build-apk.yml`): every push to `main` runs the tests, the screenshot comparison and a build, and uploads the APK as an artifact. Pushing a tag such as `1.2.1` (matching the `version:` in `flutter_app/pubspec.yaml`) publishes a release with `RELEASE_NOTES.md`.

To work on it locally:

```bash
cd flutter_app
flutter pub get
flutter test
flutter run
```

## Repository

| Path | What it is |
|---|---|
| `flutter_app/` | the app, its tests and its phase notes |
| `docs/` | function coverage of the fx-991ES PLUS, intended differences, QA checklist, release notes |
| `src/` | five small files of the earlier web version (`index.css`, `App.tsx`, `NavIcons.tsx`, `OmniCalcLogo.tsx`, `SettingsModal.tsx`). `flutter_app/tools/gen_theme_data.mjs` and `gen_svg_paths.mjs` check the Flutter colours and icon paths against them in CI. They are not part of the app |
| `PRIVACY.md` | the privacy policy the app links to |

The earlier Capacitor/React version is kept in the `capacitor-backup` branch and the `capacitor-final` tag.

## Privacy

See [PRIVACY.md](PRIVACY.md).

## Licence

GNU General Public License v3.0, see [LICENSE](LICENSE).
