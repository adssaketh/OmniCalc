import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

const ROOT_DIR = process.cwd();
const CHROME_PATH = '/ms-playwright/chromium_headless_shell-1247/chrome-headless-shell-linux64/chrome-headless-shell';

// 1. Generate Master SVG matching the new 3D calculator icon design with rounded corners
function getIconSvg({ isMaskable = false, isForegroundOnly = false, isBackgroundOnly = false, roundedCorners = true } = {}) {
  // If maskable, scale down artwork to fit within center 66% (scale 0.82 centered at 512,512)
  const transform = isMaskable
    ? 'transform="translate(512, 512) scale(0.82) translate(-512, -512)"'
    : '';

  const hasRoundedCorners = roundedCorners && !isMaskable && !isBackgroundOnly;

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <!-- Background subtle soft vignette -->
    <radialGradient id="bgVignette" cx="50%" cy="45%" r="65%">
      <stop offset="0%" stop-color="#f4f6f9" />
      <stop offset="60%" stop-color="#edf0f4" />
      <stop offset="100%" stop-color="#e2e6ec" />
    </radialGradient>

    <!-- Clip Path for Squircle Rounded Corners (rx=224 ry=224) -->
    <clipPath id="squircleClip">
      <rect width="1024" height="1024" rx="224" ry="224" />
    </clipPath>

    <!-- Dark button 3D rim stroke gradient -->
    <linearGradient id="darkRimGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#555966" />
      <stop offset="35%" stop-color="#363942" />
      <stop offset="85%" stop-color="#1e2025" />
      <stop offset="100%" stop-color="#121316" />
    </linearGradient>

    <!-- Dark button face radial gradient -->
    <radialGradient id="darkFaceGrad" cx="38%" cy="32%" r="65%">
      <stop offset="0%" stop-color="#3c3f49" />
      <stop offset="45%" stop-color="#2a2c33" />
      <stop offset="80%" stop-color="#212227" />
      <stop offset="100%" stop-color="#18191d" />
    </radialGradient>

    <!-- Vibrant Emerald-to-Lime Pill Gradient -->
    <linearGradient id="greenPillGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#059e4e" />
      <stop offset="25%" stop-color="#08b85b" />
      <stop offset="55%" stop-color="#11cb65" />
      <stop offset="80%" stop-color="#3fe078" />
      <stop offset="100%" stop-color="#6ee787" />
    </linearGradient>

    <!-- Green Pill Rim Specular Stroke -->
    <linearGradient id="pillRimGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="rgba(255, 255, 255, 0.75)" />
      <stop offset="30%" stop-color="rgba(255, 255, 255, 0.35)" />
      <stop offset="70%" stop-color="rgba(255, 255, 255, 0.05)" />
      <stop offset="100%" stop-color="rgba(255, 255, 255, 0.45)" />
    </linearGradient>

    <!-- Green Pill Inner Specular Curved Sheen -->
    <linearGradient id="glassSheen" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="rgba(255, 255, 255, 0.65)" />
      <stop offset="45%" stop-color="rgba(255, 255, 255, 0.15)" />
      <stop offset="100%" stop-color="rgba(255, 255, 255, 0.0)" />
    </linearGradient>

    <!-- White 3D Symbol Capsule Gradient -->
    <linearGradient id="whiteSymbolGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" />
      <stop offset="60%" stop-color="#fdfdfd" />
      <stop offset="100%" stop-color="#eaedf2" />
    </linearGradient>

    <!-- Ambient Shadow for Dark Buttons -->
    <filter id="darkBtnShadow" x="-25%" y="-25%" width="160%" height="160%">
      <feDropShadow dx="0" dy="16" stdDeviation="18" flood-color="#000000" flood-opacity="0.26" />
      <feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#000000" flood-opacity="0.18" />
    </filter>

    <!-- Ambient Shadow for Green Pill with Green Glow -->
    <filter id="greenPillShadow" x="-30%" y="-20%" width="170%" height="150%">
      <feDropShadow dx="0" dy="20" stdDeviation="24" flood-color="#047337" flood-opacity="0.32" />
      <feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#000000" flood-opacity="0.22" />
    </filter>

    <!-- Symbol Drop Shadow -->
    <filter id="symbolShadow" x="-30%" y="-30%" width="170%" height="170%">
      <feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#000000" flood-opacity="0.35" />
    </filter>
  </defs>

  ${
    !isForegroundOnly
      ? hasRoundedCorners
        ? `<rect width="1024" height="1024" rx="224" ry="224" fill="url(#bgVignette)" stroke="#d5dce6" stroke-width="8" />`
        : `<rect width="1024" height="1024" fill="${isBackgroundOnly ? '#edf0f4' : 'url(#bgVignette)'}" />`
      : ''
  }

  ${
    !isBackgroundOnly
      ? `
  <g ${transform}>
    <!-- =================================================================== -->
    <!-- 1. LEFT TOP BUTTON: MINUS (-) -->
    <!-- =================================================================== -->
    <g filter="url(#darkBtnShadow)">
      <!-- Main Outer Circle -->
      <circle cx="328" cy="314" r="158" fill="url(#darkFaceGrad)" stroke="url(#darkRimGrad)" stroke-width="4" />
      <!-- Top Rim Specular Crescent Highlight -->
      <path d="M 180 300 A 150 150 0 0 1 476 300 A 154 146 0 0 0 180 300 Z" fill="rgba(255, 255, 255, 0.16)" />
    </g>

    <!-- Minus Sign 3D Pill -->
    <g filter="url(#symbolShadow)">
      <rect x="244" y="293" width="168" height="42" rx="21" fill="url(#whiteSymbolGrad)" />
      <!-- Specular Highlight Top Edge -->
      <rect x="248" y="294" width="160" height="10" rx="5" fill="rgba(255, 255, 255, 0.7)" />
    </g>

    <!-- =================================================================== -->
    <!-- 2. LEFT BOTTOM BUTTON: PLUS (+) -->
    <!-- =================================================================== -->
    <g filter="url(#darkBtnShadow)">
      <!-- Main Outer Circle -->
      <circle cx="328" cy="710" r="158" fill="url(#darkFaceGrad)" stroke="url(#darkRimGrad)" stroke-width="4" />
      <!-- Top Rim Specular Crescent Highlight -->
      <path d="M 180 696 A 150 150 0 0 1 476 696 A 154 146 0 0 0 180 696 Z" fill="rgba(255, 255, 255, 0.16)" />
    </g>

    <!-- Plus Sign 3D Pill Cross -->
    <g filter="url(#symbolShadow)">
      <!-- Horizontal bar -->
      <rect x="244" y="689" width="168" height="42" rx="21" fill="url(#whiteSymbolGrad)" />
      <!-- Vertical bar -->
      <rect x="307" y="626" width="42" height="168" rx="21" fill="url(#whiteSymbolGrad)" />
      <!-- Top Highlights -->
      <rect x="248" y="690" width="160" height="9" rx="4.5" fill="rgba(255, 255, 255, 0.7)" />
      <rect x="310" y="628" width="36" height="12" rx="6" fill="rgba(255, 255, 255, 0.7)" />
    </g>

    <!-- =================================================================== -->
    <!-- 3. RIGHT BUTTON: TALL GREEN EQUALS CAPSULE (=) -->
    <!-- =================================================================== -->
    <g filter="url(#greenPillShadow)">
      <!-- Main Capsule Pill Body -->
      <rect x="536" y="157" width="320" height="710" rx="160" fill="url(#greenPillGrad)" stroke="url(#pillRimGrad)" stroke-width="3.5" />

      <!-- Inner Glass Sheen / Specular Dome Highlight (Top Arc) -->
      <path d="M 548 310 C 548 200, 620 166, 696 166 C 772 166, 844 200, 844 310 C 844 240, 780 190, 696 190 C 612 190, 548 240, 548 310 Z" fill="url(#glassSheen)" />

      <!-- Bottom Edge Inner Reflection Curve -->
      <path d="M 566 740 C 600 810, 650 850, 696 850 C 742 850, 792 810, 826 740 C 786 790, 742 815, 696 815 C 650 815, 606 790, 566 740 Z" fill="rgba(255, 255, 255, 0.28)" />
    </g>

    <!-- Equals Sign 3D Pills inside Green Capsule -->
    <g filter="url(#symbolShadow)">
      <!-- Top Bar -->
      <rect x="612" y="464" width="168" height="42" rx="21" fill="url(#whiteSymbolGrad)" />
      <rect x="616" y="465" width="160" height="9" rx="4.5" fill="rgba(255, 255, 255, 0.75)" />

      <!-- Bottom Bar -->
      <rect x="612" y="534" width="168" height="42" rx="21" fill="url(#whiteSymbolGrad)" />
      <rect x="616" y="535" width="160" height="9" rx="4.5" fill="rgba(255, 255, 255, 0.75)" />
    </g>
  </g>
  `
      : ''
  }
</svg>`;
}

async function renderSvgToPng(svgContent, outputPath, size = 1024, transparent = false) {
  const tmpHtml = path.join('/tmp', `render_${Date.now()}_${Math.random().toString(36).substring(2)}.html`);
  const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: ${size}px; height: ${size}px; overflow: hidden; background: ${transparent ? 'transparent' : '#edf0f4'}; }
  svg { width: ${size}px; height: ${size}px; display: block; }
</style>
</head>
<body>
${svgContent}
</body>
</html>`;

  fs.writeFileSync(tmpHtml, html, 'utf8');

  const bgOpt = transparent ? '--default-background-color=00000000' : '--default-background-color=ffeeeff4';
  const cmd = `${CHROME_PATH} --headless --no-sandbox ${bgOpt} --screenshot="${outputPath}" --window-size=${size},${size} file://${tmpHtml}`;
  execSync(cmd, { stdio: 'ignore' });
  fs.unlinkSync(tmpHtml);
}

async function main() {
  console.log('[build-icon-assets] Generating SVG designs...');

  // 1. Update public/icon.svg
  const mainSvg = getIconSvg();
  fs.writeFileSync(path.join(ROOT_DIR, 'public/icon.svg'), mainSvg, 'utf8');
  console.log('[build-icon-assets] Created public/icon.svg');

  // 2. Render 1024x1024 assets
  console.log('[build-icon-assets] Rendering master PNGs at 1024x1024...');
  const iconPngPath = path.join(ROOT_DIR, 'assets/icon.png');
  const iconOnlyPngPath = path.join(ROOT_DIR, 'assets/icon-only.png');
  const iconForegroundPngPath = path.join(ROOT_DIR, 'assets/icon-foreground.png');
  const iconBackgroundPngPath = path.join(ROOT_DIR, 'assets/icon-background.png');

  // Master icon with rounded corners (transparent corners outside squircle)
  await renderSvgToPng(mainSvg, iconPngPath, 1024, true);
  fs.copyFileSync(iconPngPath, iconOnlyPngPath);
  console.log('[build-icon-assets] Created assets/icon.png & assets/icon-only.png (1024x1024)');

  // Foreground artwork only (transparent background)
  const foregroundSvg = getIconSvg({ isForegroundOnly: true });
  await renderSvgToPng(foregroundSvg, iconForegroundPngPath, 1024, true);
  console.log('[build-icon-assets] Created assets/icon-foreground.png (1024x1024, transparent)');

  // Solid background only
  const backgroundSvg = getIconSvg({ isBackgroundOnly: true });
  await renderSvgToPng(backgroundSvg, iconBackgroundPngPath, 1024, false);
  console.log('[build-icon-assets] Created assets/icon-background.png (1024x1024, solid)');

  // Maskable icon (artwork within center 66%)
  const maskableSvg = getIconSvg({ isMaskable: true });
  const tmpMaskable1024 = '/tmp/maskable_1024.png';
  await renderSvgToPng(maskableSvg, tmpMaskable1024, 1024, false);

  // 3. Resize with ImageMagick for PWA, Apple Touch Icon, and Favicon
  console.log('[build-icon-assets] Generating PWA and Web icons with ImageMagick convert...');

  // public/pwa-512x512.png
  execSync(`convert "${iconPngPath}" -resize 512x512 "${path.join(ROOT_DIR, 'public/pwa-512x512.png')}"`);

  // public/pwa-192x192.png
  execSync(`convert "${iconPngPath}" -resize 192x192 "${path.join(ROOT_DIR, 'public/pwa-192x192.png')}"`);

  // public/pwa-maskable-512x512.png (from 66% centered artwork)
  execSync(`convert "${tmpMaskable1024}" -resize 512x512 "${path.join(ROOT_DIR, 'public/pwa-maskable-512x512.png')}"`);

  // public/apple-touch-icon.png (180x180)
  execSync(`convert "${iconPngPath}" -resize 180x180 "${path.join(ROOT_DIR, 'public/apple-touch-icon.png')}"`);

  // public/favicon.ico (multisize 16, 32, 48)
  execSync(`convert "${iconPngPath}" -define icon:auto-resize=48,32,16 "${path.join(ROOT_DIR, 'public/favicon.ico')}"`);

  fs.unlinkSync(tmpMaskable1024);
  console.log('[build-icon-assets] Web and PWA icons generated successfully.');

  // 4. Generate Android Adaptive Icons via @capacitor/assets
  console.log('[build-icon-assets] Running @capacitor/assets to generate Android mipmap icons...');
  execSync('npx @capacitor/assets generate --android', { stdio: 'inherit' });
  console.log('[build-icon-assets] Android mipmap icons regenerated successfully!');
}

main().catch((err) => {
  console.error('[build-icon-assets] Error:', err);
  process.exit(1);
});
