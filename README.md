# OmniCalc

**A calculator suite for scientists, engineers, students and everyday money maths** — standard and scientific calculator, unit converter, finance tools, a physics lab and an optional function grapher, in one offline-capable app. Ships as a native Android app (Capacitor) and also runs in a browser.

- **App ID:** `com.saketh.omnicalc`
- **Stack:** React 19 · Vite · TypeScript · Tailwind CSS 4 · Capacitor (Android)

---

## Features

### Calculator (Standard & Scientific)
- Expression evaluator with trigonometric, inverse trig, hyperbolic, `ln`, `log` and `sqrt` functions
- Calculus and discrete functions: `diff`, `integrate`, `sum`, `prod`, `root`, `gcd`, `lcm`, `mod`
- Combinatorics: `nCr` and `nPr`, including infix form (`10 nCr 3`, `17 mod 5`)
- Degree / radian angle modes and configurable decimal precision
- Persistent history tape

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
- Key-click sounds (generated with Web Audio) and haptic feedback
- Swipeable tabs, responsive layout (bottom nav on phones, navigation rail on larger screens)
- Settings and history saved locally in the browser

---

## Getting Started

### Prerequisites
- [Node.js](https://nodejs.org/) 20+ (matches the CI workflow)
- npm (or Bun — a `bun.lock` is included)

### Run locally
```bash
git clone https://github.com/adssaketh/OmniCalc2.git
cd OmniCalc2
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

For release signing, Play Store publishing see [GOOGLE_PLAY_STORE_GUIDE.md](./GOOGLE_PLAY_STORE_GUIDE.md).

### CI
`.github/workflows/build-apk.yml` builds the web app and a debug APK on every push and pull request to `main`/`master`, uploads the APK as an artifact, and also attempts a release bundle (AAB).

---

## Bars, scrolling and the user guide
- **Settings → Bars & scrolling:** scroll edge effect (Off / Fade / Fade + blur), fade height, solid or glass bars, glass transparency, glass blur and glass edge.
- **User guide:** the book icon next to the sound icon explains differentiation, integration, sum/product, limits, trig, powers, combinations and constants, with a *Try* button on every example.

---

## Project Structure
```
├── src/
│   ├── App.tsx            # App shell, settings and history state
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
├── capacitor.config.json
└── vite.config.ts
```

---

## Privacy
No microphone, camera, contacts or location access is requested. Currency rates are fetched from public exchange-rate APIs when online. See `public/privacy-policy.html`.

## License
Source files carry an Apache-2.0 SPDX header, but the repository has no `LICENSE` file. Add one if you want the license to be explicit.

## Author
Built by **Saketh** ([@adssaketh](https://github.com/adssaketh)).
