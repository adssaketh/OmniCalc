# OmniCalc

**A calculator suite for scientists, engineers, students and everyday money maths** — standard and scientific calculator, unit converter, finance tools, a physics lab and an optional function grapher, in one offline-capable app. Ships as a native Android app (Capacitor) and also runs in a browser.

- **App ID:** `com.saketh.omnicalc`
- **Stack:** React 19 · Vite · TypeScript · Tailwind CSS 4 · Capacitor (Android)

---

## Features

### Calculator (Standard & Scientific)
- Expression evaluator with trigonometric, inverse trig, hyperbolic, `ln`, `log`, `exp` and `sqrt` functions
- Calculus and discrete functions: `diff`, `integrate`, `sum`, `prod`, `limit`, `root`, `gcd`, `lcm`, `mod`, `min`, `max`, `avg`
- Combinatorics: `nCr` and `nPr`, including infix form (`10 nCr 3`, `17 mod 5`)
- Percent works like a handheld calculator: `200×15%` is 30, `200+10%` is 220
- Equations with `y`: write `y=x^2−5x+6`, press `=`, then type any x to get y
- Large answer display pinned at the top; the advanced keys scroll underneath it, and long expressions shrink to fit
- Degree / radian angle modes and configurable decimal precision
- Persistent history tape
- Built-in user guide (book icon in the header) with a *Try* button on every example

### Unit Converter
Length, Mass & Weight, Temperature, Area, Volume, Speed, Digital Data and Time (plus further categories in `src/engine/units.ts`).

### Finance
| Tab | What it does |
| --- | --- |
| Currency | Live exchange rates with a cached / offline fallback |
| Loan / EMI | Monthly payment, total interest, full amortisation schedule |
| SIP & Compound | SIP and compound growth with annual step-up and yearly breakdown |
| Tip | Bill splitting and tip calculation |
| ROI & CAGR | Return on investment and compound annual growth rate |

### Physics Lab
- **Constants:** fundamental constants grouped by Universal, Mechanics, Electromagnetism, Quantum & Atomic, Thermodynamics and Astrophysics
- **Solvers:** Kinematics & Projectiles, Special Relativity, Quantum & Waves, Electromagnetism

### Grapher (optional)
Canvas-based function plotter with pan, zoom and reset. Disabled by default; enable it in **Settings**.

### Experience
- Material 3 Expressive theming: Iris, Oceanic, Botanical Sage, Sunset Terracotta and AMOLED
- System / light / dark colour mode
- Liquid-glass or solid floating bars, soft scroll-edge fade and blur, and a header that splits into a logo, a name pill and an action pill as you scroll
- Key-click sounds (generated with Web Audio) and haptic feedback
- Swipeable tabs, responsive layout (bottom nav on phones, navigation rail on larger screens)
- The back gesture steps back through your screens
- Settings and history saved locally on the device

---

## Download

Get the latest signed APK from the [**Releases**](https://github.com/adssaketh/OmniCalc/releases) page. If you have an older debug build installed, uninstall it first: Android will not install over a build signed with a different key.

---

## Getting Started

### Prerequisites
- [Node.js](https://nodejs.org/) 20+ (matches the CI workflow)
- npm

### Run locally
```bash
git clone https://github.com/adssaketh/OmniCalc.git
cd OmniCalc
npm install
npm run dev
```
The dev server starts on **http://localhost:3000**.

### Scripts
| Command | Description |
| --- | --- |
| `npm run dev` | Start the Vite dev server (port 3000) |
| `npm run build` | Production build to `dist/` |
| `npm run preview` | Preview the production build |
| `npm run lint` | Type-check with `tsc --noEmit` |
| `npm run cap:sync` | Sync web assets into the Android project |
| `npm run cap:build` | Build the web app, then sync to Android |
| `npm run clean` | Remove `dist` |

---

## Android

The native app is built with Capacitor.

```bash
npm install
npm run build
npx cap sync android
cd android
./gradlew assembleDebug
# Output: android/app/build/outputs/apk/debug/app-debug.apk
```

Requirements: JDK 17 or 21, Android SDK 36, and `ANDROID_HOME` set. The project targets SDK 36 with a minimum of SDK 24.

For Play Store publishing see [GOOGLE_PLAY_STORE_GUIDE.md](./GOOGLE_PLAY_STORE_GUIDE.md).

### CI and signed releases
`.github/workflows/build-apk.yml` runs on every push to `main`/`master` and on version tags. It builds the web app and a debug APK, and, when the signing secrets exist, a signed release APK. Both are uploaded as artifacts (`OmniCalc-Debug-APK`, `OmniCalc-Release-Signed-APK`). Every build gets a higher `versionCode` from the run number, so newer builds install over older ones.

Signing needs four repository secrets (Settings → Secrets and variables → Actions). Without them the signed release step is skipped and the debug APK is still built.

| Secret | Value |
| --- | --- |
| `OMNI_KEYSTORE_B64` | the release keystore (`.jks`), base64 encoded: `base64 -w0 omnicalc-release.jks` |
| `OMNI_KEY_ALIAS` | key alias inside the keystore |
| `OMNI_KEYSTORE_PASSWORD` | keystore password |
| `OMNI_KEY_PASSWORD` | key password (the same as the keystore password for a PKCS12 keystore) |

Create the key once with `keytool -genkeypair -storetype PKCS12 -keystore omnicalc-release.jks -alias omnicalc -keyalg RSA -keysize 2048 -validity 10000`, keep the `.jks` file and its password backed up, and **never commit them** (`*.jks`, `*.keystore` and `*.b64` are git-ignored). Losing the key means you can no longer ship updates that install over existing installs.

### Releasing
1. Update the version in three places: `package.json` (`version`), `android/app/build.gradle` (`versionName`) and `src/version.ts` (`APP_VERSION`).
2. Update `RELEASE_NOTES.md`.
3. Commit and push to `main`, then push a tag that matches the version:
   ```bash
   git tag 1.1.0
   git push origin 1.1.0
   ```
4. The workflow builds the signed APK and publishes a GitHub Release named after the tag, with `OmniCalc-<tag>.apk` attached and `RELEASE_NOTES.md` as its description.

---

## Bars, scrolling and the user guide
- **Settings → Bars & scrolling:** scroll edge effect (Off / Fade / Fade + blur), fade height, solid or glass bars, glass transparency, glass blur and glass edge.
- **User guide:** the book icon next to the sound icon explains differentiation, integration, sum/product, limits, trig, powers, combinations and constants, with a *Try* button on every example.

---

## Project Structure
```
├── src/
│   ├── App.tsx            # App shell, floating bars, scroll-edge fade, settings and history state
│   ├── edgeEffects.ts     # Scroll-edge fade / blur geometry and glass settings
│   ├── guideContent.ts    # Text and examples of the in-app user guide
│   ├── version.ts         # App version shown in Settings
│   ├── navigation.ts      # Shared destinations for the bottom bar and the rail
│   ├── motion.ts          # Shared spring / easing presets
│   ├── components/        # Screens (Calculator, Converter, Finance, Physics, Graph), Sheet, settings, navigation
│   ├── engine/            # evaluator, units, finance, physics, currency logic
│   ├── hooks/             # theme, orientation
│   ├── utils/audio.ts     # Key-click sounds
│   └── types/             # Shared TypeScript types
├── public/                # icons, privacy policy
├── android/               # Capacitor Android project
├── assets/                # Icon and splash source images
├── .github/workflows/     # CI: debug + signed release APK, GitHub Releases
├── RELEASE_NOTES.md       # Description used for the GitHub Release
├── LICENSE                # Apache License 2.0
├── capacitor.config.json
└── vite.config.ts
```

---

## Privacy
No microphone, camera, contacts or location access is requested. Currency rates are fetched from public exchange-rate APIs when online. See `public/privacy-policy.html`.

## License
Licensed under the [Apache License, Version 2.0](./LICENSE). Copyright 2026 Saketh. See [NOTICE](./NOTICE).

## Author
Built by **Saketh** ([@adssaketh](https://github.com/adssaketh)).
