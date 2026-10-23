import { useState, useEffect } from 'react';

export interface OrientationState {
  isLandscape: boolean;
  isTablet: boolean;
  width: number;
  height: number;
  orientation: 'portrait' | 'landscape';
}

export function useOrientation(): OrientationState {
  const getOrientationState = (): OrientationState => {
    if (typeof window === 'undefined') {
      return {
        isLandscape: false,
        isTablet: false,
        width: 1024,
        height: 768,
        orientation: 'portrait',
      };
    }

    const width = window.innerWidth;
    const height = window.innerHeight;
    // Landscape check: ratio > 1 and width at least 540px so small phone rotated is recognized
    const isLandscape = (width > height && width >= 540) ||
      (window.matchMedia ? window.matchMedia('(orientation: landscape)').matches && width >= 540 : width > height);
    // Tablet: min dimension >= 600px, or screen is large enough in both portrait/landscape
    const isTablet = Math.min(width, height) >= 600 || (Math.max(width, height) >= 900 && Math.min(width, height) >= 540);

    return {
      isLandscape,
      isTablet,
      width,
      height,
      orientation: isLandscape ? 'landscape' : 'portrait',
    };
  };

  const [state, setState] = useState<OrientationState>(getOrientationState);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const handleUpdate = () => {
      setState(getOrientationState());
    };

    window.addEventListener('resize', handleUpdate, { passive: true });
    window.addEventListener('orientationchange', handleUpdate, { passive: true });

    let mq: MediaQueryList | null = null;
    if (window.matchMedia) {
      mq = window.matchMedia('(orientation: landscape)');
      mq.addEventListener('change', handleUpdate);
    }

    return () => {
      window.removeEventListener('resize', handleUpdate);
      window.removeEventListener('orientationchange', handleUpdate);
      if (mq) {
        mq.removeEventListener('change', handleUpdate);
      }
    };
  }, []);

  return state;
}
