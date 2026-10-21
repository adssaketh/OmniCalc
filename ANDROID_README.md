# OmniCalc Android APK Build Guide

Follow these steps to build and install OmniCalc as an offline native Android APK:

1. **Export to GitHub**: Export this project to a new GitHub repository (make sure the hidden `.github` folder and workflow files are included).
2. **Run GitHub Actions**: Open the repository on GitHub, navigate to the **Actions** tab, select the **Build Android APK** workflow, and click **Run workflow**.
3. **Download APK**: Once the workflow run finishes successfully, scroll to the **Artifacts** section at the bottom, download the `OmniCalc-Debug-APK` artifact zip, unzip it, copy `app-debug.apk` to your Android device, and install it (allow "Install unknown apps" if prompted).
4. **Test Offline**: Launch OmniCalc directly from your phone's app launcher. Test with Airplane mode enabled—all calculators, scientific functions, physics formulas, constants, loan & SIP calculations, and unit conversions work completely offline without needing an internet connection (live currency rates will seamlessly fall back to cached/built-in rates).
