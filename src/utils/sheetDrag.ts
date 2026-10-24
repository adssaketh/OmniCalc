/**
 * Drag handle behaviour for bottom sheets (the little pill at the top of a sheet):
 *   - drag it down: the sheet follows your finger; let go past a distance (or with a quick flick) and it closes,
 *     otherwise it springs back;
 *   - tap it: the sheet closes.
 * Plain pointer events, no layout changes: the sheet itself is moved with the CSS `translate` property, which is
 * separate from the `transform` the open / close animation uses, so the two never fight.
 */
export interface SheetDragCallbacks {
  /** Finger moved: how far down the sheet should be (px, never negative) */
  onMove: (dy: number) => void;
  /** Finger lifted after a drag: final distance (px) and speed (px per ms, positive = downward) */
  onRelease: (dy: number, velocity: number) => void;
  /** Touch that never turned into a drag */
  onTap: () => void;
}

const DRAG_START_PX = 6;
export const DISMISS_DISTANCE_PX = 110;
export const DISMISS_FLICK_PX_PER_MS = 0.6;

/** Past a distance, or a quick downward flick that has moved a little */
export function shouldDismiss(dy: number, velocity: number): boolean {
  return dy > DISMISS_DISTANCE_PX || (dy > 24 && velocity > DISMISS_FLICK_PX_PER_MS);
}

export function attachSheetDrag(handle: HTMLElement, cb: SheetDragCallbacks): () => void {
  let active = false;
  let moved = false;
  let pointerId = -1;
  let startY = 0;
  let lastY = 0;
  let lastT = 0;
  let velocity = 0;

  const down = (e: PointerEvent) => {
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    active = true;
    moved = false;
    pointerId = e.pointerId;
    startY = lastY = e.clientY;
    lastT = e.timeStamp;
    velocity = 0;
    try {
      handle.setPointerCapture(pointerId);
    } catch {
      /* some browsers refuse capture for synthetic events; the drag still works while the pointer stays on the handle */
    }
  };

  const move = (e: PointerEvent) => {
    if (!active || e.pointerId !== pointerId) return;
    const dy = e.clientY - startY;
    if (!moved && Math.abs(dy) > DRAG_START_PX) moved = true;
    if (!moved) return;
    const dt = e.timeStamp - lastT;
    if (dt > 0) {
      // smoothed speed, so one jittery sample does not decide a flick
      velocity = 0.7 * velocity + 0.3 * ((e.clientY - lastY) / dt);
      lastY = e.clientY;
      lastT = e.timeStamp;
    }
    cb.onMove(Math.max(0, dy));
  };

  const finish = (e: PointerEvent, cancelled: boolean) => {
    if (!active || e.pointerId !== pointerId) return;
    active = false;
    try {
      handle.releasePointerCapture(pointerId);
    } catch {
      /* already released */
    }
    if (cancelled) {
      cb.onRelease(0, 0); // system took the touch away: just spring back
      return;
    }
    if (!moved) {
      cb.onTap();
      return;
    }
    cb.onRelease(Math.max(0, e.clientY - startY), velocity);
  };

  const up = (e: PointerEvent) => finish(e, false);
  const cancel = (e: PointerEvent) => finish(e, true);

  handle.addEventListener('pointerdown', down);
  handle.addEventListener('pointermove', move);
  handle.addEventListener('pointerup', up);
  handle.addEventListener('pointercancel', cancel);
  return () => {
    handle.removeEventListener('pointerdown', down);
    handle.removeEventListener('pointermove', move);
    handle.removeEventListener('pointerup', up);
    handle.removeEventListener('pointercancel', cancel);
  };
}
