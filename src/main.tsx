import { createRoot } from 'react-dom/client';
import { Capacitor } from '@capacitor/core';
import { SplashScreen } from '@capacitor/splash-screen';
import App from './App.tsx';
import './index.css';

// Guard Service Worker:
// In native Android Capacitor app, all assets are bundled locally into the APK.
// Service workers are skipped / unregistered to prevent webview caching conflicts.
if (Capacitor.isNativePlatform()) {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then((registrations) => {
      for (const registration of registrations) {
        registration.unregister().catch(() => {});
      }
    }).catch(() => {});
  }
  // Hide splash screen after app initialization
  window.addEventListener('load', () => {
    SplashScreen.hide().catch(() => {});
  });
} else {
  // Safe PWA Service Worker registration for browser environments
  if ('serviceWorker' in navigator && !(window as any).Capacitor?.isNativePlatform?.()) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(() => {});
    });
  }
}

createRoot(document.getElementById('root')!).render(<App />);
