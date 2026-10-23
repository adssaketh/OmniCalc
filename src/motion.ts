/**
 * Shared motion language (Material 3 Expressive), same as Ping: springs with a little overshoot for
 * things that move, short emphasized-easing fades for things that appear in place.
 */
export const spring = { type: 'spring', stiffness: 420, damping: 36, mass: 0.9 } as const;
export const springBouncy = { type: 'spring', stiffness: 520, damping: 26, mass: 0.85 } as const;

const emphasized: [number, number, number, number] = [0.2, 0, 0, 1];
export const fadeFast = { duration: 0.18, ease: emphasized };
