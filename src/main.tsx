import { createRoot } from 'react-dom/client';
import { Capacitor } from '@capacitor/core';
import { SplashScreen } from '@capacitor/splash-screen';
import App from './App.tsx';
import './index.css';

// OmniCalc is a native app and bundles everything it needs, so it has no service worker.
// Earlier builds registered one; remove it and its caches so nothing stale is ever served.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker
    .getRegistrations()
    .then((registrations) => {
      for (const registration of registrations) {
        registration.unregister().catch(() => {});
      }
    })
    .catch(() => {});
}
if ('caches' in window) {
  caches
    .keys()
    .then((keys) => keys.forEach((key) => caches.delete(key)))
    .catch(() => {});
}

if (Capacitor.isNativePlatform()) {
  // Hide splash screen after app initialization
  window.addEventListener('load', () => {
    SplashScreen.hide().catch(() => {});
  });
}

createRoot(document.getElementById('root')!).render(<App />);
