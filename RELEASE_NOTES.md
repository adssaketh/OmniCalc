# OmniCalc 1.1.0

A big update to the look and feel of OmniCalc, plus a built-in guide for the advanced functions and a round of calculation fixes.

## Highlights

- **Bigger, pinned answer display.** The header now sits inside the display card, numbers shrink automatically so they never get cut off, and the advanced keys scroll underneath while your answer stays in view.
- **Liquid-glass look.** Choose Solid or Glass bars, with adjustable transparency, blur strength and a light rim. Scroll edges can fade or fade and blur, and the fade only appears when content really slides under a bar.
- **Header that splits as you scroll.** On Converter, Physics Lab and Finance, the header splits into a round logo, a centre pill with the name and an action pill, with a small rubber-band motion. Tap the round logo to go back to the top.
- **Built-in user guide.** The book icon next to the sound icon explains differentiation, integration, sum and product, limits, trigonometry, powers, combinations and constants. Every example has a **Try** button.
- **Equations with y.** Tap `y` on an empty display, write a formula in x, press `=`, then type any x and press `=` to get y. Works for quadratics and any other formula in x.
- **Percent that works like a calculator.** `200×15%` is 30 and `200+10%` is 220. For the remainder, use `mod`.

## Also new

- Animated advanced drawer: it slides open and the keys pop in, again on each tab change.
- The back gesture steps back through your screens and closes open sheets first. From the first screen, press back twice to leave the app.
- One font for every number in the app, in lighter and bolder weights, with aligned digits.
- Error messages are shown small and in full, in the error colour, instead of as a giant answer.
- **Open source.** Settings → About now links to the source code on GitHub (github.com/adssaketh/OmniCalc), and OmniCalc is licensed under Apache-2.0.

## Fixed

- `exp(`, `limit(`, `min`, `max`, `avg` and `sgn` now work.
- The constants R, σ, atm, au and m_n now work.
- `x*x` and `2x` now work inside `diff`, `integrate` and `sum`.
- Derivatives and integrals are more accurate: `diff(x^2, 3)` gives 6 and `integrate(sin(x), 0, π)` gives 2.
- Cards are visible in dark mode.
- The year-by-year tables no longer trap your scrolling.
- Keys no longer stay dark after you tap them.

## Removed

- The web-app (PWA) install option, service worker and web manifest. OmniCalc is a native app, so they did nothing useful.

## Install

1. Download **OmniCalc-1.1.0.apk** from the assets below.
2. If you have an older OmniCalc debug build installed, **uninstall it first**. Android won't install over a build signed with a different key. This clears saved history and settings once.
3. Open the APK and allow installs from your browser or file manager if asked.

This APK is signed with the OmniCalc release key. Future updates signed with the same key will install over it. Requires Android 7.0 (API 24) or newer.

## Privacy

No microphone, camera, contacts or location access is requested. Currency rates are fetched from public exchange-rate APIs when online. See `public/privacy-policy.html`.

## License

Apache License 2.0. See the LICENSE file in the repository.
