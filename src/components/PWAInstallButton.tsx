import React, { useState } from 'react';
import { Download, Check, Share2, PlusSquare, Monitor, Smartphone, X } from 'lucide-react';
import { usePWAInstall } from '../hooks/usePWAInstall';
import { OmniCalcLogo } from './OmniCalcLogo';

interface PWAInstallButtonProps {
  className?: string;
  variant?: 'header' | 'banner' | 'button';
}

export const PWAInstallButton: React.FC<PWAInstallButtonProps> = ({
  className = '',
  variant = 'header',
}) => {
  const { isInstallable, isInstalled, install } = usePWAInstall();
  const [showGuide, setShowGuide] = useState<boolean>(false);
  const [justInstalled, setJustInstalled] = useState<boolean>(false);

  // If already installed, hide the button so the UI remains pristine
  if (isInstalled && !justInstalled) {
    return null;
  }

  const handleInstallClick = async () => {
    if (isInstallable) {
      const installed = await install();
      if (installed) {
        setJustInstalled(true);
        setTimeout(() => setJustInstalled(false), 3000);
      }
    } else {
      setShowGuide(true);
    }
  };

  // Device detection for tailored install guides
  const isIOS =
    typeof navigator !== 'undefined' &&
    (/iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1));

  return (
    <>
      {variant === 'header' && (
        <button
          onClick={handleInstallClick}
          aria-label="Install OmniCalc as PWA"
          title="Install OmniCalc on your device for offline use"
          className={`flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-full border transition-all active:scale-95 cursor-pointer ${className}`}
          style={{
            backgroundColor: isInstallable
              ? 'var(--m3-primary-container)'
              : 'var(--m3-surface-container)',
            borderColor: isInstallable
              ? 'var(--m3-primary)'
              : 'var(--m3-outline-variant)',
            color: isInstallable
              ? 'var(--m3-on-primary-container)'
              : 'var(--m3-on-surface)',
          }}
        >
          {justInstalled ? (
            <>
              <Check className="w-3.5 h-3.5 text-emerald-500" />
              <span className="hidden sm:inline">Installed!</span>
            </>
          ) : (
            <>
              <Download className="w-3.5 h-3.5 animate-pulse" style={{ color: 'var(--m3-primary)' }} />
              <span className="whitespace-nowrap">Install App</span>
            </>
          )}
        </button>
      )}

      {variant === 'banner' && (
        <div
          className={`w-full border rounded-[24px] p-4 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs transition-colors ${className}`}
          style={{
            backgroundColor: 'var(--m3-surface-container)',
            borderColor: 'var(--m3-outline-variant)',
            color: 'var(--m3-on-surface)',
          }}
        >
          <div className="flex items-center gap-2.5">
            <OmniCalcLogo className="w-9 h-9 drop-shadow-md" />
            <div>
              <div className="font-semibold text-sm">Install OmniCalc</div>
              <div className="text-[11px] opacity-75" style={{ color: 'var(--m3-on-surface-variant)' }}>
                Add to your home screen or desktop with adaptive icon and 1-tap offline access
              </div>
            </div>
          </div>
          <button
            onClick={handleInstallClick}
            className="w-full sm:w-auto px-4 py-2 rounded-full font-semibold transition-all flex items-center justify-center gap-1.5 shrink-0 shadow-sm active:scale-95 cursor-pointer"
            style={{
              backgroundColor: 'var(--m3-primary)',
              color: 'var(--m3-on-primary)',
            }}
          >
            <Download className="w-4 h-4" />
            <span>Install Now</span>
          </button>
        </div>
      )}

      {variant === 'button' && (
        <button
          onClick={handleInstallClick}
          className={`flex items-center justify-center gap-2 px-5 py-2.5 rounded-full text-xs font-semibold shadow-md transition-all active:scale-95 cursor-pointer ${className}`}
          style={{
            backgroundColor: 'var(--m3-primary)',
            color: 'var(--m3-on-primary)',
          }}
        >
          <Download className="w-4 h-4" />
          <span>Install OmniCalc App</span>
        </button>
      )}

      {/* Guided Installation Modal */}
      {showGuide && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center backdrop-blur-md p-4 animate-in fade-in duration-200"
          style={{ backgroundColor: 'var(--m3-scrim)' }}
          onClick={() => setShowGuide(false)}
        >
          <div
            className="w-full max-w-md border rounded-[32px] p-5 sm:p-6 shadow-2xl relative text-left"
            style={{
              backgroundColor: 'var(--m3-surface-container-low)',
              borderColor: 'var(--m3-outline-variant)',
              color: 'var(--m3-on-surface)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setShowGuide(false)}
              className="absolute right-4 top-4 p-1.5 rounded-full border transition-colors cursor-pointer active:scale-90"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                borderColor: 'var(--m3-outline-variant)',
                color: 'var(--m3-on-surface-variant)',
              }}
            >
              <X className="w-4 h-4" />
            </button>

            <div className="flex items-center gap-3 mb-4">
              <OmniCalcLogo className="w-11 h-11 drop-shadow-lg" />
              <div>
                <h3 className="text-base font-bold">Install OmniCalc</h3>
                <p className="text-xs opacity-75" style={{ color: 'var(--m3-on-surface-variant)' }}>
                  Adaptive icon automatically matches your device shape
                </p>
              </div>
            </div>

            {isIOS ? (
              /* iOS Safari instructions */
              <div
                className="space-y-3 p-4 rounded-[20px] border text-xs"
                style={{
                  backgroundColor: 'var(--m3-surface-container)',
                  borderColor: 'var(--m3-outline-variant)',
                }}
              >
                <div className="flex items-start gap-2.5">
                  <span
                    className="w-5 h-5 rounded-full flex items-center justify-center shrink-0 font-bold text-[11px]"
                    style={{
                      backgroundColor: 'var(--m3-primary-container)',
                      color: 'var(--m3-on-primary-container)',
                    }}
                  >
                    1
                  </span>
                  <div>
                    Tap the <strong>Share</strong> button (
                    <Share2 className="w-3.5 h-3.5 inline mx-1" style={{ color: 'var(--m3-primary)' }} />
                    ) at the bottom toolbar of Safari.
                  </div>
                </div>
                <div className="flex items-start gap-2.5">
                  <span
                    className="w-5 h-5 rounded-full flex items-center justify-center shrink-0 font-bold text-[11px]"
                    style={{
                      backgroundColor: 'var(--m3-primary-container)',
                      color: 'var(--m3-on-primary-container)',
                    }}
                  >
                    2
                  </span>
                  <div>
                    Scroll down and tap <strong>Add to Home Screen</strong> (
                    <PlusSquare className="w-3.5 h-3.5 inline mx-1" style={{ color: 'var(--m3-primary)' }} />
                    ).
                  </div>
                </div>
                <div className="flex items-start gap-2.5">
                  <span
                    className="w-5 h-5 rounded-full flex items-center justify-center shrink-0 font-bold text-[11px]"
                    style={{
                      backgroundColor: 'var(--m3-primary-container)',
                      color: 'var(--m3-on-primary-container)',
                    }}
                  >
                    3
                  </span>
                  <div>
                    Tap <strong>Add</strong> in top-right. OmniCalc is now installed on your home screen!
                  </div>
                </div>
              </div>
            ) : (
              /* Desktop / Android Chrome / Edge instructions */
              <div className="space-y-3 text-xs">
                <div
                  className="p-3.5 rounded-[20px] border"
                  style={{
                    backgroundColor: 'var(--m3-surface-container)',
                    borderColor: 'var(--m3-outline-variant)',
                  }}
                >
                  <div className="flex items-center gap-2 font-semibold mb-1.5">
                    <Monitor className="w-4 h-4" style={{ color: 'var(--m3-primary)' }} />
                    <span>Chrome / Edge / Brave on Desktop</span>
                  </div>
                  <p className="text-[11px] leading-relaxed opacity-80" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    Click the <strong>Install</strong> icon (
                    <Download className="w-3 h-3 inline mx-0.5" style={{ color: 'var(--m3-primary)' }} />
                    ) in the browser address bar on the right side, or click <strong>Settings (⋮) → Cast, save and share → Install OmniCalc</strong>.
                  </p>
                </div>

                <div
                  className="p-3.5 rounded-[20px] border"
                  style={{
                    backgroundColor: 'var(--m3-surface-container)',
                    borderColor: 'var(--m3-outline-variant)',
                  }}
                >
                  <div className="flex items-center gap-2 font-semibold mb-1.5">
                    <Smartphone className="w-4 h-4 text-emerald-500" />
                    <span>Android / Chrome Mobile</span>
                  </div>
                  <p className="text-[11px] leading-relaxed opacity-80" style={{ color: 'var(--m3-on-surface-variant)' }}>
                    Tap the browser menu <strong>(⋮)</strong> at top right and choose <strong>Install app</strong> or <strong>Add to Home screen</strong>.
                  </p>
                </div>
              </div>
            )}

            <div
              className="mt-5 flex items-center justify-between gap-3 pt-3 border-t text-xs"
              style={{ borderColor: 'var(--m3-outline-variant)' }}
            >
              <span className="text-[11px] opacity-75" style={{ color: 'var(--m3-on-surface-variant)' }}>
                Works 100% offline once installed
              </span>
              <button
                onClick={() => setShowGuide(false)}
                className="px-5 py-2 rounded-full font-semibold transition-all active:scale-95 cursor-pointer shadow-sm"
                style={{
                  backgroundColor: 'var(--m3-primary)',
                  color: 'var(--m3-on-primary)',
                }}
              >
                Got it
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};
