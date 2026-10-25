import { CalculatorMode } from './types';
import { soundFx } from './utils/audio';

export interface NavItem {
  id: CalculatorMode | 'recents';
  label: string;
  /** Shorter label for the navigation rail */
  railLabel: string;
}

/** Destinations in display order. Physics Lab (optional, off by default) sits third. */
export function getNavItems(enableGrapher: boolean, enablePhysics: boolean = false): NavItem[] {
  const items: NavItem[] = [
    { id: 'standard', label: 'Calculator', railLabel: 'Calc' },
    { id: 'converter', label: 'Converter', railLabel: 'Convert' },
    { id: 'finance', label: 'Finance', railLabel: 'Finance' },
    { id: 'recents', label: 'Recents', railLabel: 'Recents' },
  ];
  if (enablePhysics) items.splice(2, 0, { id: 'physics', label: 'Physics Lab', railLabel: 'Physics' });
  if (enableGrapher) items.push({ id: 'grapher', label: 'Grapher', railLabel: 'Graph' });
  return items;
}

export function isNavItemActive(item: NavItem, currentMode: CalculatorMode, isHistoryOpen: boolean): boolean {
  if (item.id === 'recents') return isHistoryOpen;
  return !isHistoryOpen && (currentMode === item.id || (currentMode === 'scientific' && item.id === 'standard'));
}

/** Click sound + haptic tick used by every navigation control. */
export function navFeedback(soundEnabled: boolean, hapticEnabled: boolean): void {
  if (soundEnabled) soundFx.playClick('toggle');
  if (hapticEnabled) soundFx.triggerHaptic();
}
