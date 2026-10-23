import { Capacitor } from '@capacitor/core';
import { App as CapApp, URLOpenListenerEvent } from '@capacitor/app';
import { CalculatorMode } from '../types';

const ALLOWED_MODES: Set<string> = new Set(['standard', 'converter', 'finance', 'physics', 'scientific', 'grapher']);

/**
 * Extracts CalculatorMode from an omnicalc:// deep link or web query parameter.
 * Returns null if the URL cannot be parsed or does not specify a valid mode.
 */
export function parseDeepLinkMode(urlString: string): CalculatorMode | null {
  if (!urlString) return null;
  try {
    // 1. Check custom scheme: omnicalc://open/<mode>
    if (urlString.startsWith('omnicalc://')) {
      const cleaned = urlString.replace('omnicalc://', '');
      const parts = cleaned.split(/[\/?#]/).filter(Boolean);
      // e.g. "open/standard" -> parts = ["open", "standard"]
      if (parts.length >= 2 && parts[0] === 'open' && ALLOWED_MODES.has(parts[1])) {
        return parts[1] as CalculatorMode;
      }
      if (parts.length >= 1 && ALLOWED_MODES.has(parts[0])) {
        return parts[0] as CalculatorMode;
      }
    }

    // 2. Check standard URL query param ?mode=...
    const url = new URL(urlString, window.location.origin);
    const modeParam = url.searchParams.get('mode');
    if (modeParam && ALLOWED_MODES.has(modeParam)) {
      return modeParam as CalculatorMode;
    }
  } catch {
    // Invalid URL format
  }
  return null;
}

/**
 * Registers deep link listeners for cold start and warm start app launches.
 * Calls onModeChange when a valid shortcut target is detected.
 */
export function initDeepLinks(onModeChange: (mode: CalculatorMode) => void): () => void {
  // 1. Check initial browser URL search params (?mode=...)
  if (typeof window !== 'undefined' && window.location.search) {
    const initialMode = parseDeepLinkMode(window.location.href);
    if (initialMode) {
      onModeChange(initialMode);
    }
  }

  if (!Capacitor.isNativePlatform()) {
    return () => {};
  }

  let cleanupListener: (() => void) | null = null;

  try {
    // 2. Cold start: check if the app was launched by a deep link URL
    CapApp.getLaunchUrl()
      .then((launchUrl) => {
        if (launchUrl?.url) {
          const mode = parseDeepLinkMode(launchUrl.url);
          if (mode) {
            onModeChange(mode);
          }
        }
      })
      .catch(() => {});

    // 3. Warm start: listen for appUrlOpen events when the app is already running
    const handlePromise = CapApp.addListener('appUrlOpen', (event: URLOpenListenerEvent) => {
      try {
        if (event?.url) {
          const mode = parseDeepLinkMode(event.url);
          if (mode) {
            onModeChange(mode);
          }
        }
      } catch {
        // Safe catch for URL parsing
      }
    });

    cleanupListener = () => {
      handlePromise.then((handle) => handle.remove()).catch(() => {});
    };
  } catch {
    // Ignore error if CapApp is not available
  }

  return () => {
    if (cleanupListener) {
      cleanupListener();
    }
  };
}
