import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// OmniCalc ships as a Capacitor Android app: every asset is bundled into the APK, so there is no
// service worker or web manifest (the old PWA setup was removed).
export default defineConfig(() => {
  return {
    plugins: [react(), tailwindcss()],
  };
});
