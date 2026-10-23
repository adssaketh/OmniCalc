import React, { useRef, useState, useEffect, useCallback } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

export interface TabItem {
  id: string;
  label: string;
  icon?: React.ComponentType<{ className?: string }>;
  badge?: string | number;
}

interface SwipeableTabContainerProps {
  tabs: TabItem[];
  activeTabId: string;
  onSelectTab: (tabId: string) => void;
  children: React.ReactNode;
  className?: string;
  tabBarClassName?: string;
  tabPillClassName?: string;
  compact?: boolean;
  showNavButtons?: boolean;
}

export const SwipeableTabContainer: React.FC<SwipeableTabContainerProps> = ({
  tabs,
  activeTabId,
  onSelectTab,
  children,
  className = '',
  tabBarClassName,
  tabPillClassName,
  compact = false,
  showNavButtons = false,
}) => {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const tabListRef = useRef<HTMLDivElement | null>(null);
  const tabButtonRefs = useRef<Map<string, HTMLButtonElement>>(new Map());

  const activeIndex = tabs.findIndex((t) => t.id === activeTabId);
  const safeActiveIndex = activeIndex >= 0 ? activeIndex : 0;

  // Swipe gesture state
  const [dragOffset, setDragOffset] = useState<number>(0);
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [isTransitioning, setIsTransitioning] = useState<boolean>(false);

  // Gesture tracking refs
  const touchStartRef = useRef<{ x: number; y: number; time: number } | null>(null);
  const touchVelocityRef = useRef<{ x: number; time: number }[]>([]);
  const directionLockedRef = useRef<'horizontal' | 'vertical' | null>(null);
  const isPointerDownRef = useRef<boolean>(false);
  const wasSwipingRef = useRef<boolean>(false);
  const rafIdRef = useRef<number | null>(null);
  const currentOffsetRef = useRef<number>(0);

  // Auto-scroll the tab bar to keep the active tab centered and visible
  const scrollActiveTabIntoView = useCallback((tabId: string, smooth: boolean = true) => {
    const btn = tabButtonRefs.current.get(tabId);
    const scrollContainer = tabListRef.current;
    if (btn && scrollContainer) {
      const containerRect = scrollContainer.getBoundingClientRect();
      const btnRect = btn.getBoundingClientRect();
      const targetScrollLeft =
        scrollContainer.scrollLeft +
        (btnRect.left + btnRect.width / 2) -
        (containerRect.left + containerRect.width / 2);

      scrollContainer.scrollTo({
        left: Math.max(0, targetScrollLeft),
        behavior: smooth ? 'smooth' : 'auto',
      });
    }
  }, []);

  useEffect(() => {
    scrollActiveTabIntoView(activeTabId, true);
  }, [activeTabId, scrollActiveTabIntoView]);

  // Check if touch target should be excluded from tab swiping (sliders, inputs, canvas, etc.)
  const shouldIgnoreSwipe = (target: EventTarget | null): boolean => {
    if (!(target instanceof HTMLElement)) return false;
    const tagName = target.tagName.toLowerCase();
    if (
      tagName === 'input' ||
      tagName === 'textarea' ||
      tagName === 'select' ||
      tagName === 'canvas' ||
      target.closest('input') ||
      target.closest('textarea') ||
      target.closest('select') ||
      target.closest('canvas') ||
      target.closest('.no-swipe') ||
      target.closest('[data-no-swipe="true"]')
    ) {
      return true;
    }
    // Check for horizontally scrollable sub-elements
    let el: HTMLElement | null = target;
    while (el && el !== containerRef.current) {
      if (el.scrollWidth > el.clientWidth && el !== containerRef.current) {
        const style = window.getComputedStyle(el);
        if (style.overflowX === 'auto' || style.overflowX === 'scroll') {
          return true;
        }
      }
      el = el.parentElement;
    }
    return false;
  };

  const lastWheelTimeRef = useRef<number>(0);

  // Pointer event handlers with high-frequency 120Hz tracking
  const handlePointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    // Only primary mouse button or touch/pen
    if (e.button !== 0) return;
    if (shouldIgnoreSwipe(e.target)) return;

    isPointerDownRef.current = true;
    touchStartRef.current = { x: e.clientX, y: e.clientY, time: performance.now() };
    touchVelocityRef.current = [{ x: e.clientX, time: performance.now() }];
    directionLockedRef.current = null;
    currentOffsetRef.current = 0;
    setIsTransitioning(false);
  };

  // Trackpad horizontal swipe / mouse tilt-wheel gesture support
  const handleWheel = (e: React.WheelEvent<HTMLDivElement>) => {
    const now = performance.now();
    if (now - lastWheelTimeRef.current < 350) return;
    if (Math.abs(e.deltaX) > Math.abs(e.deltaY) * 1.5 && Math.abs(e.deltaX) > 35) {
      if (e.deltaX > 35 && safeActiveIndex < tabs.length - 1) {
        lastWheelTimeRef.current = now;
        onSelectTab(tabs[safeActiveIndex + 1].id);
      } else if (e.deltaX < -35 && safeActiveIndex > 0) {
        lastWheelTimeRef.current = now;
        onSelectTab(tabs[safeActiveIndex - 1].id);
      }
    }
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!isPointerDownRef.current || !touchStartRef.current) return;

    const dx = e.clientX - touchStartRef.current.x;
    const dy = e.clientY - touchStartRef.current.y;
    const now = performance.now();

    // Direction locking threshold
    if (!directionLockedRef.current) {
      const absDx = Math.abs(dx);
      const absDy = Math.abs(dy);
      if (absDx > 8 || absDy > 8) {
        if (absDy > absDx * 1.15) {
          directionLockedRef.current = 'vertical';
          return;
        } else {
          directionLockedRef.current = 'horizontal';
          setIsDragging(true);
        }
      } else {
        return;
      }
    }

    if (directionLockedRef.current !== 'horizontal') return;

    // Record velocity data points (keep last 4)
    touchVelocityRef.current.push({ x: e.clientX, time: now });
    if (touchVelocityRef.current.length > 5) {
      touchVelocityRef.current.shift();
    }

    // Apply rubber-band effect at start and end tabs
    let effectiveDx = dx;
    const isFirstTab = safeActiveIndex === 0;
    const isLastTab = safeActiveIndex === tabs.length - 1;

    if (isFirstTab && dx > 0) {
      effectiveDx = dx * 0.35; // Resistance to the right
    } else if (isLastTab && dx < 0) {
      effectiveDx = dx * 0.35; // Resistance to the left
    }

    currentOffsetRef.current = effectiveDx;

    if (rafIdRef.current) cancelAnimationFrame(rafIdRef.current);
    rafIdRef.current = requestAnimationFrame(() => {
      setDragOffset(effectiveDx);
    });
  };

  const handlePointerUpOrCancel = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!isPointerDownRef.current) return;
    isPointerDownRef.current = false;

    if (rafIdRef.current) {
      cancelAnimationFrame(rafIdRef.current);
      rafIdRef.current = null;
    }

    if (directionLockedRef.current === 'horizontal') {
      const points = touchVelocityRef.current;
      let velocity = 0;
      if (points.length >= 2) {
        const oldest = points[0];
        const newest = points[points.length - 1];
        const dt = newest.time - oldest.time;
        if (dt > 0) {
          velocity = (newest.x - oldest.x) / dt; // px/ms
        }
      }

      const dx = currentOffsetRef.current;
      const containerWidth = containerRef.current?.clientWidth || 360;
      const distanceThreshold = containerWidth * 0.22;
      const velocityThreshold = 0.35; // px/ms

      let targetIndex = safeActiveIndex;

      // Swipe to next tab (drag left)
      if ((dx < -distanceThreshold || velocity < -velocityThreshold) && safeActiveIndex < tabs.length - 1) {
        targetIndex = safeActiveIndex + 1;
      }
      // Swipe to previous tab (drag right)
      else if ((dx > distanceThreshold || velocity > velocityThreshold) && safeActiveIndex > 0) {
        targetIndex = safeActiveIndex - 1;
      }

      setIsTransitioning(true);
      setIsDragging(false);
      setDragOffset(0);
      currentOffsetRef.current = 0;

      wasSwipingRef.current = true;
      setTimeout(() => {
        wasSwipingRef.current = false;
      }, 150);

      if (targetIndex !== safeActiveIndex) {
        onSelectTab(tabs[targetIndex].id);
      }
    } else {
      setIsDragging(false);
      setDragOffset(0);
      currentOffsetRef.current = 0;
    }

    touchStartRef.current = null;
    directionLockedRef.current = null;
  };

  // Compute tab pill sliding position & width
  const [pillStyle, setPillStyle] = useState<{ left: number; width: number }>({ left: 0, width: 0 });

  const updatePill = useCallback(() => {
    const btn = tabButtonRefs.current.get(activeTabId);
    const scrollContainer = tabListRef.current;
    if (btn && scrollContainer) {
      const btnRect = btn.getBoundingClientRect();
      const containerRect = scrollContainer.getBoundingClientRect();
      const relativeLeft = btnRect.left - containerRect.left + scrollContainer.scrollLeft;

      setPillStyle({
        left: relativeLeft,
        width: btnRect.width,
      });
    }
  }, [activeTabId]);

  useEffect(() => {
    updatePill();
    window.addEventListener('resize', updatePill);
    return () => window.removeEventListener('resize', updatePill);
  }, [updatePill]);

  // Interpolate pill movement while dragging content
  let dynamicPillLeft = pillStyle.left;
  if (isDragging && dragOffset !== 0) {
    const containerWidth = containerRef.current?.clientWidth || 360;
    const dragRatio = -dragOffset / containerWidth;

    let adjacentIndex = safeActiveIndex;
    if (dragOffset < 0 && safeActiveIndex < tabs.length - 1) {
      adjacentIndex = safeActiveIndex + 1;
    } else if (dragOffset > 0 && safeActiveIndex > 0) {
      adjacentIndex = safeActiveIndex - 1;
    }

    const nextBtn = tabButtonRefs.current.get(tabs[adjacentIndex]?.id);
    const currentBtn = tabButtonRefs.current.get(activeTabId);
    const scrollContainer = tabListRef.current;

    if (nextBtn && currentBtn && scrollContainer) {
      const currentRect = currentBtn.getBoundingClientRect();
      const nextRect = nextBtn.getBoundingClientRect();
      const containerRect = scrollContainer.getBoundingClientRect();

      const currentLeft = currentRect.left - containerRect.left + scrollContainer.scrollLeft;
      const nextLeft = nextRect.left - containerRect.left + scrollContainer.scrollLeft;
      const distance = nextLeft - currentLeft;

      dynamicPillLeft = currentLeft + distance * Math.abs(dragRatio);
    }
  }

  const handleScrollTabs = (direction: 'left' | 'right') => {
    if (!tabListRef.current) return;
    const scrollAmount = 160;
    tabListRef.current.scrollBy({
      left: direction === 'left' ? -scrollAmount : scrollAmount,
      behavior: 'smooth',
    });
  };

  return (
    <div className={`w-full flex flex-col items-center select-none ${className}`}>
      {/* 1. M3 Expressive Gliding Tab Bar with PC / Tablet Navigation Controls */}
      <div className="w-full relative flex items-center group/tabbar">
        {/* Left Scroll Chevron (Tablets / PC mouse navigation) */}
        {showNavButtons && (
          <button
            type="button"
            onClick={() => handleScrollTabs('left')}
            className="hidden sm:flex shrink-0 p-1 mr-1 rounded-full hover:bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface-variant)] transition-all cursor-pointer opacity-80 hover:opacity-100 active:scale-90"
            title="Scroll tabs left"
            aria-label="Scroll tabs left"
          >
            <ChevronLeft className="w-3.5 h-3.5" />
          </button>
        )}

        <div
          className={`w-full overflow-x-auto no-scrollbar relative ${
 tabBarClassName || (compact ? 'pb-1 mb-2' : 'pb-2 mb-3 sm:mb-4')
 }`}
          ref={tabListRef}
          onWheel={(e) => {
            if (tabListRef.current && Math.abs(e.deltaY) > 5 && Math.abs(e.deltaX) < 10) {
              tabListRef.current.scrollLeft += e.deltaY;
            }
          }}
        >
          <div
            className={`relative flex items-center gap-1 rounded-full w-max min-w-full sm:min-w-0 transition-colors ${
 compact ? 'p-1' : 'p-1.5'
 } ${tabPillClassName || ''}`}
            style={{ backgroundColor: 'var(--m3-surface-container)' }}
          >
            {/* Active Gliding Pill with Pop + Glow */}
            {pillStyle.width > 0 && (
              <div
                className={`absolute rounded-full pointer-events-none z-0 ${
 compact ? 'top-1 bottom-1' : 'top-1.5 bottom-1.5'
 } ${
 isTransitioning ? 'transition-all duration-300 ease-[cubic-bezier(0.2,0.9,0.2,1)]' : ''
 }`}
                style={{
                  left: `${dynamicPillLeft}px`,
                  width: `${pillStyle.width}px`,
                  backgroundColor: 'var(--m3-primary)',
                  transform: isDragging ? 'scale(1.06)' : 'scale(1)',
                  boxShadow: isDragging
                    ? '0 0 16px 2px var(--m3-primary), 0 4px 10px rgba(0,0,0,0.25)'
                    : '0 2px 8px color-mix(in srgb, var(--m3-primary) 30%, transparent)',
                  transition: isDragging
                    ? 'transform 180ms cubic-bezier(0.2,0.9,0.2,1), box-shadow 180ms ease'
                    : 'all 300ms cubic-bezier(0.2,0.9,0.2,1)',
                  willChange: 'transform, left, width, box-shadow',
                }}
              />
            )}

            {tabs.map((tab) => {
              const Icon = tab.icon;
              const isActive = tab.id === activeTabId;
              return (
                <button
                  key={tab.id}
                  ref={(el) => {
                    if (el) tabButtonRefs.current.set(tab.id, el);
                    else tabButtonRefs.current.delete(tab.id);
                  }}
                  onClick={() => onSelectTab(tab.id)}
                  className={`relative z-10 rounded-full whitespace-nowrap shrink-0 flex items-center gap-1.5 cursor-pointer transition-colors duration-200 outline-none active:scale-95 ${
 compact ? 'px-3 py-1 text-xs font-semibold' : 'px-4 py-2 text-xs font-semibold'
 }`}
                  style={{
                    color: isActive ? 'var(--m3-on-primary)' : 'var(--m3-on-surface-variant)',
                    fontWeight: isActive ? 700 : 500,
                  }}
                >
                  {Icon && <Icon className={compact ? 'w-3.5 h-3.5' : 'w-4 h-4'} />}
                  <span>{tab.label}</span>
                  {tab.badge !== undefined && (
                    <span
                      className="ml-0.5 px-1.5 py-0.2 rounded-full text-[10px] font-mono leading-tight font-bold"
                      style={{
                        backgroundColor: isActive ? 'var(--m3-on-primary)' : 'var(--m3-surface-container-high)',
                        color: isActive ? 'var(--m3-primary)' : 'var(--m3-on-surface)',
                      }}
                    >
                      {tab.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Right Scroll Chevron (Tablets / PC mouse navigation) */}
        {showNavButtons && (
          <button
            type="button"
            onClick={() => handleScrollTabs('right')}
            className="hidden sm:flex shrink-0 p-1 ml-1 rounded-full hover:bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface-variant)] transition-all cursor-pointer opacity-80 hover:opacity-100 active:scale-90"
            title="Scroll tabs right"
            aria-label="Scroll tabs right"
          >
            <ChevronRight className="w-3.5 h-3.5" />
          </button>
        )}
      </div>

      {/* 2. Interactive Swipeable Content Area (120Hz Direct Finger Tracking & Trackpad Gestures) */}
      <div
        ref={containerRef}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUpOrCancel}
        onPointerCancel={handlePointerUpOrCancel}
        onWheel={handleWheel}
        onClickCapture={(e) => {
          if (wasSwipingRef.current) {
            e.stopPropagation();
            e.preventDefault();
          }
        }}
        className="w-full relative touch-pan-y"
        style={{
          transform: `translate3d(${dragOffset}px, 0, 0)`,
          opacity: isDragging ? Math.max(0.75, 1 - Math.abs(dragOffset) / 800) : 1,
          transition: isTransitioning
            ? 'transform 300ms cubic-bezier(0.2, 0.9, 0.2, 1), opacity 300ms ease'
            : 'none',
          willChange: 'transform, opacity',
        }}
      >
        {children}
      </div>
    </div>
  );
};
