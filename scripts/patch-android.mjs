#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const ROOT_DIR = process.cwd();
const OVERRIDES_DIR = path.join(ROOT_DIR, 'android-overrides');
const ANDROID_DIR = path.join(ROOT_DIR, 'android');

console.log('[patch-android] Starting Android project patching...');

if (!fs.existsSync(ANDROID_DIR)) {
  console.log('[patch-android] Note: android directory not found. Skipping.');
  process.exit(0);
}

// 1. Copy android-overrides/ into android/
function copyRecursive(src, dest) {
  if (!fs.existsSync(src)) return;
  const stats = fs.statSync(src);
  if (stats.isDirectory()) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    const entries = fs.readdirSync(src);
    for (const entry of entries) {
      copyRecursive(path.join(src, entry), path.join(dest, entry));
    }
  } else {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(src, dest);
  }
}

if (fs.existsSync(OVERRIDES_DIR)) {
  copyRecursive(OVERRIDES_DIR, ANDROID_DIR);
  console.log('[patch-android] Copied android-overrides into android directory.');
} else {
  console.log('[patch-android] Warning: android-overrides directory does not exist.');
}

// 2. Patch AndroidManifest.xml
const manifestPath = path.join(ANDROID_DIR, 'app/src/main/AndroidManifest.xml');
if (fs.existsSync(manifestPath)) {
  let manifest = fs.readFileSync(manifestPath, 'utf8');
  let changed = false;

  // Ensure uiMode is present in configChanges
  if (!manifest.includes('uiMode')) {
    manifest = manifest.replace(
      /android:configChanges="([^"]*)"/,
      'android:configChanges="$1|uiMode"'
    );
    changed = true;
    console.log('[patch-android] Added uiMode to MainActivity configChanges.');
  }

  // Ensure shortcuts meta-data is present inside MainActivity
  if (!manifest.includes('android.app.shortcuts')) {
    const metaTag = '            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />\n';
    manifest = manifest.replace(/(<activity[^>]*>)/, `$1\n${metaTag}`);
    changed = true;
    console.log('[patch-android] Added shortcuts meta-data to MainActivity.');
  }

  // Ensure omnicalc://open intent filter is present inside MainActivity
  if (!manifest.includes('android:scheme="omnicalc"')) {
    const intentFilter = `            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="omnicalc" android:host="open" />
            </intent-filter>\n`;
    manifest = manifest.replace(/(<\/activity>)/, `${intentFilter}$1`);
    changed = true;
    console.log('[patch-android] Added deep link intent filter for omnicalc://open.');
  }

  if (changed) {
    fs.writeFileSync(manifestPath, manifest, 'utf8');
    console.log('[patch-android] AndroidManifest.xml updated successfully.');
  } else {
    console.log('[patch-android] AndroidManifest.xml already up to date.');
  }
} else {
  console.log('[patch-android] Warning: AndroidManifest.xml not found.');
}

// 3. Patch styles.xml for DayNight theme support
const stylesPath = path.join(ANDROID_DIR, 'app/src/main/res/values/styles.xml');
if (fs.existsSync(stylesPath)) {
  let styles = fs.readFileSync(stylesPath, 'utf8');
  let stylesChanged = false;

  if (styles.includes('Theme.AppCompat.Light.NoActionBar') || styles.includes('Theme.AppCompat.NoActionBar')) {
    styles = styles.replace(
      /parent="Theme\.AppCompat(\.Light)?\.NoActionBar"/g,
      'parent="Theme.AppCompat.DayNight.NoActionBar"'
    );
    stylesChanged = true;
  }

  if (stylesChanged) {
    fs.writeFileSync(stylesPath, styles, 'utf8');
    console.log('[patch-android] styles.xml updated to Theme.AppCompat.DayNight.');
  } else {
    console.log('[patch-android] styles.xml already uses DayNight theme.');
  }
}

console.log('[patch-android] Android patching complete.');
