# OmniCalc — Android APK & Google Play Store Guide

**App ID**: `com.saketh.omnicalc`  
**App Name**: `OmniCalc`  
**Architecture**: Capacitor 8 + React 19 + Vite 8 + Tailwind CSS  
**Offline Capability**: 100% Fully Offline (all JS, CSS, icons, and fonts bundled in APK)

---

## 🚀 1. Building Locally via Command Line

### Prerequisites
- **JDK 17 or 21** installed (`java -version`)
- **Android Studio** with Android SDK 36 (or command-line tools)
- Environment variables: `ANDROID_HOME` pointing to your Android SDK directory.

### Quick Build Commands

#### A. Produce a Debug APK (`app-debug.apk`)
```bash
# 1. Install dependencies (if not already done)
npm install

# 2. Build the web app and sync native assets to Android
npm run build
npx cap sync android

# 3. Compile the debug APK using Gradle
cd android
./gradlew assembleDebug

# Output location:
# android/app/build/outputs/apk/debug/app-debug.apk
```
You can transfer `app-debug.apk` directly to your Android device via USB/ADB:
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

---

#### B. Generate a Release Signing Keystore (One-Time)
Run the Java `keytool` command to create your production keystore:
```bash
keytool -genkey -v -keystore omnicalc-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias omnicalc \
  -storetype JKS
```
*Keep `omnicalc-release-key.jks` and your keystore password safe. Google Play requires this key to sign future app updates.*

---

#### C. Produce a Signed Release APK
To sign via Gradle, configure `android/app/build.gradle` or sign the unsigned release APK directly:
```bash
cd android
./gradlew assembleRelease

# Sign using apksigner (part of Android SDK build-tools):
$ANDROID_HOME/build-tools/36.0.0/apksigner sign \
  --ks omnicalc-release-key.jks \
  --ks-key-alias omnicalc \
  --out app/build/outputs/apk/release/app-release-signed.apk \
  app/build/outputs/apk/release/app-release-unsigned.apk
```

---

#### D. Produce an Android App Bundle (.aab) for Google Play Console
Google Play requires `.aab` format for all new app submissions:
```bash
cd android
./gradlew bundleRelease

# Sign the release bundle:
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore omnicalc-release-key.jks \
  app/build/outputs/bundle/release/app-release.aab \
  omnicalc

# Output location ready for Play Store:
# android/app/build/outputs/bundle/release/app-release.aab
```

---

## 🤖 2. Automated Build with GitHub Actions

The repository includes a ready-to-run workflow at `.github/workflows/build-apk.yml`.

Whenever you push to `main` or trigger a `workflow_dispatch` on GitHub:
1. It installs Node.js and builds the web app with Vite.
2. Runs `npx cap sync android`.
3. Sets up JDK 17 and Android SDK.
4. Executes `./gradlew assembleDebug` and `./gradlew bundleRelease`.
5. Uploads `OmniCalc-Debug-APK` (`app-debug.apk`) and `OmniCalc-Release-AAB` as downloadable artifacts right from your GitHub Actions run page.

---

## 📱 3. Android Polish & WebView Adaptations Summary

1. **No service worker / PWA**:
   - The app is native-only. All assets load locally from `android/app/src/main/assets/public/`; any service worker left by older builds is unregistered on start.
2. **Local Fonts & Icons**:
   - The app uses the phone's own UI font for text and numbers (no font files are bundled, no network requests for styling).
3. **Adaptive Launcher Icons & Splash**:
   - Generated 105 adaptive icon and splash screen assets across all densities (`ldpi`, `mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) matching the Material 3 Expressive theme `#111318`.
4. **Android Back Button Handling**:
   - Dismisses Settings or History modals first. If no modals are active, cleanly calls `CapApp.exitApp()`.
5. **Dynamic Status Bar & Navigation Bar**:
   - Dark theme `#111318` applied across `styles.xml`, `colors.xml`, and dynamically updated with `@capacitor/status-bar`.
6. **Robust Offline Currency Converter**:
   - When offline, currency conversions instantly use last-cached or default rates without crashing or throwing fetch errors.
7. **Clean Shipped Dependencies**:
   - Stripped unused backend/server dependencies (`express`, `dotenv`, `@types/express`) and unused AI packages (`@google/genai`).

---

## 🔗 4. `assetlinks.json` / TWA

Not used. This Capacitor build is self-contained, so no hosted domain verification file is needed (the old TWA files were removed with the PWA).
