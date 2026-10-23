import React, { useState, useEffect, useCallback } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'motion/react';
import { AngleMode, HistoryItem } from '../types';
import { MathEvaluator } from '../engine/evaluator';
import { soundFx } from '../utils/audio';
import { Copy, Check, Delete, CornerDownLeft, ChevronUp, RotateCcw } from 'lucide-react';
import { OmniCalcLogo } from './OmniCalcLogo';
import { useOrientation } from '../hooks/useOrientation';
import { SwipeableTabContainer } from './SwipeableTabContainer';
import { AutoFitText } from './AutoFitText';
import { spring } from '../motion';

interface CalculatorScreenProps {
  angleMode: AngleMode;
  onToggleAngleMode: () => void;
  decimalPrecision: number;
  soundEnabled: boolean;
  hapticEnabled: boolean;
  onAddHistory: (item: Omit<HistoryItem, 'id' | 'timestamp'>) => void;
  externalExpression?: string;
  /** Changes every time an expression is loaded from outside, so loading the same text twice still works */
  externalSeq?: number;
  /** Element in the app's top bar where the display is pinned (phone portrait); the display flows inline without it */
  pinnedSlot?: HTMLElement | null;
  /** The app header row (logo, name, guide, sound, settings), shown at the top of the display card on phones */
  headerRow?: React.ReactNode;
  history?: HistoryItem[];
  onOpenHistory?: () => void;
  onSelectHistoryItem?: (expr: string) => void;
}

type AdvancedTab = 'calculus' | 'trig' | 'powers' | 'prob' | 'constants';

interface TabDef {
  id: AdvancedTab;
  label: string;
  badge: string;
}

const ADVANCED_TABS: TabDef[] = [
  { id: 'calculus', label: 'Calculus', badge: '∫' },
  { id: 'trig', label: 'Trig & Hyp', badge: 'sin' },
  { id: 'powers', label: 'Powers', badge: 'xʸ' },
  { id: 'prob', label: 'Probability', badge: 'nCr' },
  { id: 'constants', label: 'Constants', badge: 'π' },
];

/** Keypad key styles shared by many buttons (digits, operators, scientific keys). */
const KEY_DIGIT_LARGE =
  'h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] text-2xl sm:text-3xl md:text-4xl font-mono font-medium rounded-[16px] sm:rounded-[24px] md:rounded-[32px] m3-key flex items-center justify-center cursor-pointer active:scale-95 transition-transform';

const KEY_DIGIT =
  'h-full w-full min-h-[46px] sm:min-h-[54px] md:min-h-[62px] text-xl sm:text-2xl font-mono font-medium rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface)] flex items-center justify-center cursor-pointer active:scale-95 transition-transform';

const KEY_OPERATOR =
  'h-full w-full min-h-[46px] sm:min-h-[54px] md:min-h-[62px] text-2xl font-bold rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-secondary-container)] text-[var(--m3-on-secondary-container)] flex items-center justify-center cursor-pointer active:scale-95 transition-transform';

const KEY_OPERATOR_LARGE =
  'h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] text-2xl sm:text-3xl md:text-4xl font-semibold rounded-[16px] sm:rounded-[24px] md:rounded-[32px] m3-key flex items-center justify-center cursor-pointer active:scale-95 transition-transform';

const KEY_FUNCTION =
  'h-full w-full min-h-[46px] sm:min-h-[54px] md:min-h-[62px] text-base font-semibold rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-surface-container)] text-[var(--m3-on-surface)] flex items-center justify-center cursor-pointer active:scale-95 transition-transform';

export const CalculatorScreen: React.FC<CalculatorScreenProps> = ({
  angleMode,
  onToggleAngleMode,
  decimalPrecision,
  soundEnabled,
  hapticEnabled,
  onAddHistory,
  externalExpression,
  externalSeq = 0,
  pinnedSlot = null,
  headerRow,
  history,
  onOpenHistory,
  onSelectHistoryItem,
}) => {
  const { isLandscape } = useOrientation();
  const [expression, setExpression] = useState<string>('0');
  const [lastQuestion, setLastQuestion] = useState<string>('');
  const [lastAnswer, setLastAnswer] = useState<string>('');
  /** Equation saved with y = ... ; while it is set, typing a number and pressing = gives y at that x */
  const [equation, setEquation] = useState<string | null>(MathEvaluator.getYDefinition());
  const [memory, setMemory] = useState<number>(0);
  const [isScientific, setIsScientific] = useState<boolean>(false);
  const [advancedTab, setAdvancedTab] = useState<AdvancedTab>('calculus');
  const [copied, setCopied] = useState<boolean>(false);
  const [hasEvaluated, setHasEvaluated] = useState<boolean>(false);
  const [isEqualsPressed, setIsEqualsPressed] = useState<boolean>(false);
  const [historyIndex, setHistoryIndex] = useState<number>(-1);

  // Play sound helper
  const playSound = (type: 'num' | 'op' | 'eval' | 'clear' | 'toggle' = 'num') => {
    if (soundEnabled) soundFx.playClick(type);
    if (hapticEnabled) soundFx.triggerHaptic();
  };

  // Sync external expression if loaded from history
  useEffect(() => {
    if (externalExpression !== undefined && externalExpression !== '') {
      setExpression(externalExpression);
      setLastQuestion('');
      setLastAnswer('');
      setHasEvaluated(false);
    }
  }, [externalExpression, externalSeq]);

  // Count unmatched open parentheses
  const getOpenParensCount = (expr: string): number => {
    let count = 0;
    for (const char of expr) {
      if (char === '(') count++;
      else if (char === ')') count--;
    }
    return Math.max(0, count);
  };

  const openParensCount = getOpenParensCount(expression);

  // After pressing = the display holds either a number or an error message; messages are shown small and in full
  const isErrorResult = hasEvaluated && !/^[−-]?(\d[\d.,]*(e[+-]?\d+)?|Infinity)$/i.test(expression.trim());

  // Insert token into expression
  const handleInput = useCallback((token: string) => {
    playSound('num');
    setExpression((prev) => {
      if (hasEvaluated) {
        setHasEvaluated(false);
        setLastQuestion('');
        setLastAnswer('');
        if (['+', '−', '×', '÷', '^', '%'].includes(token) || token.startsWith('^')) {
          return prev + token;
        }
        return token;
      }

      if (prev === '0' && !['.', '+', '−', '×', '÷', '^', '%', '!', ')'].includes(token) && !token.startsWith('^')) {
        return token;
      }

      if (token === '.') {
        const segments = prev.split(/[\+\−\×\÷\^\(\)\%,]/);
        const lastSegment = segments[segments.length - 1];
        if (lastSegment.includes('.')) return prev;
      }

      return prev + token;
    });
  }, [hasEvaluated, soundEnabled, hapticEnabled]);

  // Insert functions e.g. "sin("
  const handleFunction = useCallback((fnName: string) => {
    playSound('op');
    setExpression((prev) => {
      if (hasEvaluated) {
        setHasEvaluated(false);
        setLastQuestion('');
        setLastAnswer('');
        return `${fnName}(${prev})`;
      }

      if (prev === '0') {
        return `${fnName}(`;
      }

      const lastChar = prev.slice(-1);
      if (['+', '−', '×', '÷', '(', '^', ',', ' '].includes(lastChar)) {
        return `${prev}${fnName}(`;
      }

      return `${prev}×${fnName}(`;
    });
  }, [hasEvaluated, soundEnabled, hapticEnabled]);

  // Insert template e.g. "diff(", "integrate(", "sum("
  const handleInsertTemplate = useCallback((template: string) => {
    playSound('op');
    setExpression((prev) => {
      if (hasEvaluated || prev === '0') {
        setHasEvaluated(false);
        setLastQuestion('');
        setLastAnswer('');
        return template;
      }

      const lastChar = prev.slice(-1);
      if (['+', '−', '×', '÷', '(', '^', ',', ' '].includes(lastChar)) {
        return `${prev}${template}`;
      }

      return `${prev}×${template}`;
    });
  }, [hasEvaluated, soundEnabled, hapticEnabled]);

  // Handle Parentheses
  const handleParentheses = useCallback(() => {
    playSound('op');
    setExpression((prev) => {
      if (hasEvaluated) {
        setHasEvaluated(false);
        return '(';
      }

      const openCount = (prev.match(/\(/g) || []).length;
      const closeCount = (prev.match(/\)/g) || []).length;
      const lastChar = prev.slice(-1);

      if (openCount > closeCount && !['+', '−', '×', '÷', '(', '^', ',', ' '].includes(lastChar)) {
        return prev + ')';
      }

      if (['+', '−', '×', '÷', '(', '^', '%', ',', ' '].includes(lastChar) || prev === '0') {
        return prev === '0' ? '(' : prev + '(';
      }

      return prev + '×(';
    });
  }, [hasEvaluated, soundEnabled, hapticEnabled]);

  // Clear All
  const handleClear = useCallback(() => {
    playSound('clear');
    // AC on an already empty display also forgets the saved y = ... equation
    if (expression === '0' && !hasEvaluated && equation) {
      MathEvaluator.setYDefinition(null);
      setEquation(null);
    }
    setExpression('0');
    setLastQuestion('');
    setLastAnswer('');
    setHasEvaluated(false);
  }, [expression, hasEvaluated, equation, soundEnabled, hapticEnabled]);

  // Backspace
  const handleBackspace = useCallback(() => {
    playSound('op');
    setExpression((prev) => {
      if (hasEvaluated) {
        setHasEvaluated(false);
        return '0';
      }
      if (prev.length <= 1) return '0';

      const multiCharTokens = [
        'integrate(', 'randInt(', 'diff(', 'limit(', 'y=', 'y(', 'sum(', 'prod(', 'nCr(', 'nPr(',
        'gcd(', 'lcm(', 'mod(', 'root(', 'logb(', 'rand()',
        'asinh(', 'acosh(', 'atanh(', 'sech(', 'csch(', 'coth(',
        'sinh(', 'cosh(', 'tanh(', 'asin(', 'acos(', 'atan(',
        'sec(', 'csc(', 'cot(',
        'sin(', 'cos(', 'tan(', 'log2(', 'log(', 'ln(', 'exp(',
        'sqrt(', 'cbrt(', 'round(', 'floor(', 'ceil(', 'sign(', 'abs('
      ];

      for (const token of multiCharTokens) {
        if (prev.endsWith(token)) {
          const cut = prev.slice(0, -token.length);
          return cut.length === 0 ? '0' : cut;
        }
      }

      return prev.slice(0, -1);
    });
  }, [hasEvaluated, soundEnabled, hapticEnabled]);

  // Evaluate Expression
  const handleEvaluate = useCallback(() => {
    playSound('eval');
    try {
      let exprToEval = expression;
      const openCount = (exprToEval.match(/\(/g) || []).length;
      const closeCount = (exprToEval.match(/\)/g) || []).length;
      if (openCount > closeCount) {
        exprToEval = exprToEval + ')'.repeat(openCount - closeCount);
      }

      // y = f(x): save the equation (nothing is calculated yet)
      const defMatch = exprToEval.match(/^\s*y\s*=\s*(.+)$/i);
      if (defMatch) {
        const def = defMatch[1].trim();
        if (/y/i.test(def.replace(/\b(asinh|acosh|atanh|sinh|cosh|tanh|sech|csch|coth|sqrt|cbrt|log2)\b/gi, ''))) {
          throw new Error('Use only x on the right of y =');
        }
        const probes = [1, 2, 0.5, -1].map((x) => MathEvaluator.evaluateFunction(def, x, angleMode));
        if (probes.every((v) => Number.isNaN(v))) {
          throw new Error('Could not read that equation. Example: y=x^2−5x+6');
        }
        MathEvaluator.setYDefinition(def);
        setEquation(def);
        setLastQuestion('');
        setLastAnswer('');
        setExpression('0');
        setHasEvaluated(false);
        return;
      }

      // With an equation saved, a plain number means "give me y at this x"
      let shown = expression;
      if (equation && !hasEvaluated && /^[−-]?\d+(\.\d+)?$/.test(exprToEval.trim())) {
        exprToEval = `y(${exprToEval.trim()})`;
        shown = exprToEval;
      }

      const result = MathEvaluator.evaluate(exprToEval, angleMode);
      const formatted = MathEvaluator.formatResult(result, decimalPrecision);

      setLastQuestion(shown);
      setLastAnswer(formatted);

      onAddHistory({
        expression: shown,
        result: formatted,
        mode: isScientific ? 'scientific' : 'standard',
      });

      setExpression(formatted);
      setHasEvaluated(true);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Error';
      setLastQuestion(expression);
      setLastAnswer(msg);
      setExpression(msg);
      setHasEvaluated(true);
    }
  }, [expression, equation, hasEvaluated, angleMode, decimalPrecision, isScientific, onAddHistory, soundEnabled, hapticEnabled]);

  // Memory operations
  const handleMemory = useCallback((action: 'MC' | 'MR' | 'M+' | 'M-' | 'MS') => {
    playSound('op');
    try {
      const currentVal = MathEvaluator.evaluate(expression, angleMode);
      switch (action) {
        case 'MC':
          setMemory(0);
          break;
        case 'MR':
          setExpression(MathEvaluator.formatResult(memory, decimalPrecision));
          setHasEvaluated(true);
          break;
        case 'MS':
          setMemory(currentVal);
          break;
        case 'M+':
          setMemory((m) => m + currentVal);
          break;
        case 'M-':
          setMemory((m) => m - currentVal);
          break;
      }
    } catch {
      // ignore
    }
  }, [expression, angleMode, memory, decimalPrecision, soundEnabled, hapticEnabled]);

  // Copy result
  const handleCopy = useCallback(() => {
    const textToCopy = hasEvaluated ? lastAnswer : expression;
    navigator.clipboard.writeText(textToCopy);
    setCopied(true);
    playSound('toggle');
    setTimeout(() => setCopied(false), 2000);
  }, [hasEvaluated, lastAnswer, expression, playSound]);

  // Navigate through calculation history tape with Up/Down arrow keys
  const handleHistoryStep = useCallback(
    (direction: -1 | 1) => {
      if (!history || history.length === 0) return;
      const nextIdx = historyIndex + direction;
      if (nextIdx >= 0 && nextIdx < history.length) {
        setHistoryIndex(nextIdx);
        setExpression(history[nextIdx].expression);
        setLastQuestion('');
        setLastAnswer(history[nextIdx].result);
        setHasEvaluated(false);
        playSound('toggle');
      } else if (nextIdx < 0) {
        setHistoryIndex(-1);
        setExpression('0');
        setLastQuestion('');
        setLastAnswer('');
        setHasEvaluated(false);
      }
    },
    [history, historyIndex, playSound]
  );

  // Global Physical / External Keyboard Input Handler (PC, Mac, Tablets with external keyboard)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // 1. If user is currently typing in an input, textarea, or select element, do not intercept
      const target = e.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.tagName === 'SELECT' ||
          target.isContentEditable)
      ) {
        return;
      }

      // 2. Handle Ctrl / Cmd combinations
      if (e.ctrlKey || e.metaKey) {
        if (e.key === 'c' || e.key === 'C') {
          handleCopy();
          return;
        }
        if (e.key === 'z' || e.key === 'Z') {
          e.preventDefault();
          handleBackspace();
          return;
        }
        return; // Pass through browser keys (Ctrl+R, Ctrl+Shift+I, etc.)
      }

      // 3. Numbers 0-9 (standard keyboard & numpad)
      if (e.key >= '0' && e.key <= '9') {
        e.preventDefault();
        handleInput(e.key);
        return;
      }

      // 4. Decimal point or comma (international keyboards)
      if (e.key === '.' || e.key === ',') {
        e.preventDefault();
        if (e.key === ',' && expression.includes('(')) {
          handleInput(',');
        } else {
          handleInput('.');
        }
        return;
      }

      // 5. Arithmetic operators
      if (e.key === '+') {
        e.preventDefault();
        handleInput('+');
        return;
      }
      if (e.key === '-') {
        e.preventDefault();
        handleInput('−');
        return;
      }
      if (e.key === '*' || e.code === 'NumpadMultiply') {
        e.preventDefault();
        handleInput('×');
        return;
      }
      if (e.key === '/' || e.code === 'NumpadDivide') {
        e.preventDefault();
        handleInput('÷');
        return;
      }
      if (e.key === '%') {
        e.preventDefault();
        handleInput('%');
        return;
      }
      if (e.key === '^') {
        e.preventDefault();
        handleInput('^');
        return;
      }
      if (e.key === '!') {
        e.preventDefault();
        handleInput('!');
        return;
      }

      // 6. Parentheses & Comma
      if (e.key === '(') {
        e.preventDefault();
        handleInput('(');
        return;
      }
      if (e.key === ')') {
        e.preventDefault();
        handleInput(')');
        return;
      }
      if (e.key === ',') {
        e.preventDefault();
        handleInput(', ');
        return;
      }

      // Tab switcher brackets [ and ] for quick external keyboard tab navigation
      if (e.key === '[' || e.key === ']') {
        e.preventDefault();
        const tabList: AdvancedTab[] = ['calculus', 'trig', 'powers', 'prob', 'constants'];
        const curIdx = tabList.indexOf(advancedTab);
        if (e.key === '[') {
          const prevIdx = curIdx > 0 ? curIdx - 1 : tabList.length - 1;
          setAdvancedTab(tabList[prevIdx]);
        } else {
          const nextIdx = curIdx < tabList.length - 1 ? curIdx + 1 : 0;
          setAdvancedTab(tabList[nextIdx]);
        }
        playSound('toggle');
        return;
      }

      // 7. Equals & Enter (Evaluate)
      if (e.key === 'Enter' || e.key === '=') {
        e.preventDefault();
        setIsEqualsPressed(true);
        setTimeout(() => setIsEqualsPressed(false), 160);
        handleEvaluate();
        return;
      }

      // 8. Backspace & Deletion
      if (e.key === 'Backspace') {
        e.preventDefault();
        handleBackspace();
        return;
      }

      // 9. Clear / Escape / Delete
      if (e.key === 'Escape' || e.key === 'Delete') {
        e.preventDefault();
        handleClear();
        return;
      }

      // 10. History navigation (Arrow Up / Down)
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        handleHistoryStep(1);
        return;
      }
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        handleHistoryStep(-1);
        return;
      }

      // 11. Mathematical letter shortcuts
      const lower = e.key.toLowerCase();
      if (lower === 'x') {
        e.preventDefault();
        const last = expression.slice(-1);
        if (['+', '−', '×', '÷', '(', '^', ',', ' '].includes(last) || expression === '0') {
          handleInput('x');
        } else {
          handleInput('×');
        }
        return;
      }
      if (lower === 'y') {
        e.preventDefault();
        handleInput('y');
        return;
      }
      if (lower === 's') {
        e.preventDefault();
        handleFunction('sin');
        return;
      }
      if (lower === 'c') {
        e.preventDefault();
        handleFunction('cos');
        return;
      }
      if (lower === 't') {
        e.preventDefault();
        handleFunction('tan');
        return;
      }
      if (lower === 'l') {
        e.preventDefault();
        handleFunction('ln');
        return;
      }
      if (lower === 'p') {
        e.preventDefault();
        handleInput('PI');
        return;
      }
      if (lower === 'e' && !/[0-9]/.test(expression.slice(-1))) {
        e.preventDefault();
        handleInput('E');
        return;
      }
      if (lower === 'r' || lower === 'q') {
        e.preventDefault();
        handleFunction('sqrt');
        return;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [
    handleInput,
    handleFunction,
    handleBackspace,
    handleClear,
    handleEvaluate,
    handleCopy,
    handleHistoryStep,
    expression,
    advancedTab,
    playSound,
  ]);

  // Clipboard Paste handler (Ctrl+V directly into calculator)
  useEffect(() => {
    const handlePaste = (e: ClipboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.tagName === 'SELECT' ||
          target.isContentEditable)
      ) {
        return;
      }

      const pastedText = e.clipboardData?.getData('text');
      if (pastedText) {
        const cleaned = pastedText.trim().replace(/\s+/g, '');
        if (/^[0-9+\-*/÷×^().,%!a-zA-Z_]+$/.test(cleaned)) {
          e.preventDefault();
          const mapped = cleaned
            .replace(/\*/g, '×')
            .replace(/\//g, '÷')
            .replace(/-/g, '−');
          setExpression(mapped);
          setHasEvaluated(false);
          playSound('num');
        }
      }
    };

    window.addEventListener('paste', handlePaste);
    return () => window.removeEventListener('paste', handlePaste);
  }, [playSound]);

  // Render Advanced Tab Content for portrait & landscape
  const renderAdvancedTabContent = (isLandscapeMode: boolean = false) => {
    const gridClass = isLandscapeMode
      ? "adv-grid grid grid-cols-4 grid-rows-5 gap-1.5 sm:gap-2 h-full w-full"
      : "adv-grid grid grid-cols-4 sm:grid-cols-6 gap-1.5 sm:gap-2";

    const btnClass = isLandscapeMode
      ? "h-full w-full min-h-[48px] sm:min-h-[54px] md:min-h-[62px] text-xs sm:text-sm font-semibold rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-surface-container)] text-[var(--m3-on-surface)] transition-all cursor-pointer flex flex-col items-center justify-center p-1.5 select-none active:scale-95"
      : "py-2.5 sm:py-3.5 px-2 sm:px-3 text-xs sm:text-sm font-semibold rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface)] transition-all cursor-pointer flex flex-col items-center justify-center select-none active:scale-95";

    switch (advancedTab) {
      case 'calculus':
        return (
          <div className="flex flex-col h-full w-full justify-between">
            <div className={gridClass}>
              {/* Row 1: Core Calculus Operators */}
              <button onClick={() => handleInsertTemplate('diff(')} className={btnClass} title="Numerical Derivative: diff(expr, var)">
                <span className="font-bold">d/dx</span>
                <span className="text-[10px] opacity-70">derivative</span>
              </button>
              <button onClick={() => handleInsertTemplate('integrate(')} className={btnClass} title="Definite Integral: integrate(expr, a, b)">
                <span className="font-bold">∫ dx</span>
                <span className="text-[10px] opacity-70">integral</span>
              </button>
              <button onClick={() => handleInsertTemplate('sum(')} className={btnClass} title="Series Summation: sum(expr, start, end)">
                <span className="font-bold">∑</span>
                <span className="text-[10px] opacity-70">sum</span>
              </button>
              <button onClick={() => handleInsertTemplate('prod(')} className={btnClass} title="Series Product: prod(expr, start, end)">
                <span className="font-bold">∏</span>
                <span className="text-[10px] opacity-70">product</span>
              </button>

              {/* Row 2: Limit, Abs, Sign, Natural Log */}
              <button onClick={() => handleInsertTemplate('limit(')} className={btnClass} title="Limit: limit(expr, x, a)">
                <span className="font-bold">lim</span>
                <span className="text-[10px] opacity-70">limit</span>
              </button>
              <button onClick={() => handleFunction('abs')} className={btnClass} title="Absolute Value: |x|">
                <span className="font-bold">|x|</span>
                <span className="text-[10px] opacity-70">abs</span>
              </button>
              <button onClick={() => handleFunction('sign')} className={btnClass} title="Sign Function: sgn(x)">
                <span className="font-bold">sgn</span>
                <span className="text-[10px] opacity-70">sign</span>
              </button>
              <button onClick={() => handleFunction('ln')} className={btnClass} title="Natural Logarithm: ln(x)">
                <span className="font-bold">ln</span>
                <span className="text-[10px] opacity-70">base e</span>
              </button>

              {/* Row 3: Variables & Syntax Symbols */}
              <button onClick={() => handleInput('x')} className={btnClass} title="Variable x">
                <span className="font-mono font-bold text-sm text-[var(--m3-primary)]">x</span>
                <span className="text-[10px] opacity-70">var x</span>
              </button>
              <button
                onClick={() => (expression === '0' || hasEvaluated ? handleInsertTemplate('y=') : handleInsertTemplate('y('))}
                className={btnClass}
                title="Equation: tap on an empty display to write y = f(x), then type x and press =. Later, y(4) gives y at x = 4"
              >
                <span className="font-mono font-bold text-sm text-[var(--m3-tertiary)]">y</span>
                <span className="text-[10px] opacity-70">y = f(x)</span>
              </button>
              <button onClick={() => handleInput(', ')} className={btnClass} title="Argument Separator (Comma)">
                <span className="font-bold text-sm">,</span>
                <span className="text-[10px] opacity-70">comma</span>
              </button>
              <button onClick={() => handleParentheses()} className={btnClass} title="Parentheses ()">
                <span className="font-bold text-sm">( )</span>
                <span className="text-[10px] opacity-70">parens</span>
              </button>

              {/* Row 4: Power and Roots */}
              <button onClick={() => handleInput('^2')} className={btnClass} title="Square: x²">
                <span className="font-bold">x²</span>
                <span className="text-[10px] opacity-70">square</span>
              </button>
              <button onClick={() => handleInput('^')} className={btnClass} title="Power: xʸ">
                <span className="font-bold">xʸ</span>
                <span className="text-[10px] opacity-70">power</span>
              </button>
              <button onClick={() => handleFunction('sqrt')} className={btnClass} title="Square Root: √x">
                <span className="font-bold">√x</span>
                <span className="text-[10px] opacity-70">root</span>
              </button>
              <button onClick={() => handleInsertTemplate('exp(')} className={btnClass} title="Exponential: eˣ">
                <span className="font-bold">eˣ</span>
                <span className="text-[10px] opacity-70">exp</span>
              </button>

              {/* Row 5: Quick Formula Templates aligned with Row 5 of Keypad */}
              <button
                onClick={() => handleInsertTemplate('diff(x^2, ')}
                className={`${btnClass} bg-[var(--m3-surface-container-high)] border-[var(--m3-primary)]/40`}
                title="Quick Template: diff(x², x)"
              >
                <span className="font-bold text-[11px] text-[var(--m3-primary)]">d/dx(x²)</span>
                <span className="text-[9px] opacity-75">formula</span>
              </button>
              <button
                onClick={() => handleInsertTemplate('integrate(x^2, 0, ')}
                className={`${btnClass} bg-[var(--m3-surface-container-high)] border-[var(--m3-primary)]/40`}
                title="Quick Template: integrate(x², 0, 1)"
              >
                <span className="font-bold text-[11px] text-[var(--m3-primary)]">∫(x²)</span>
                <span className="text-[9px] opacity-75">formula</span>
              </button>
              <button
                onClick={() => handleInsertTemplate('sum(x, 1, ')}
                className={`${btnClass} bg-[var(--m3-surface-container-high)] border-[var(--m3-primary)]/40`}
                title="Quick Template: sum(x, 1, n)"
              >
                <span className="font-bold text-[11px] text-[var(--m3-primary)]">∑(x)</span>
                <span className="text-[9px] opacity-75">formula</span>
              </button>
              <button
                onClick={() => handleInsertTemplate('prod(x, 1, ')}
                className={`${btnClass} bg-[var(--m3-surface-container-high)] border-[var(--m3-primary)]/40`}
                title="Quick Template: prod(x, 1, n)"
              >
                <span className="font-bold text-[11px] text-[var(--m3-primary)]">∏(x)</span>
                <span className="text-[9px] opacity-75">formula</span>
              </button>
            </div>

            {!isLandscapeMode && (
              <div className="text-[10px] text-center opacity-75 font-mono text-[var(--m3-on-surface-variant)] truncate pt-1">
                Format: diff(f(x), x_val) • integrate(f(x), a, b) • sum(f(x), 1, n)
              </div>
            )}
          </div>
        );

      case 'trig':
        return (
          <div className="flex flex-col h-full w-full justify-between">
            <div className={gridClass}>
              {/* Row 1: Primary Trig */}
              <button onClick={() => handleFunction('sin')} className={btnClass}><span className="font-bold">sin</span><span className="text-[10px] opacity-70">sine</span></button>
              <button onClick={() => handleFunction('cos')} className={btnClass}><span className="font-bold">cos</span><span className="text-[10px] opacity-70">cosine</span></button>
              <button onClick={() => handleFunction('tan')} className={btnClass}><span className="font-bold">tan</span><span className="text-[10px] opacity-70">tangent</span></button>
              <button onClick={() => handleFunction('sec')} className={btnClass}><span className="font-bold">sec</span><span className="text-[10px] opacity-70">secant</span></button>

              {/* Row 2: Secondary & Inverse Trig */}
              <button onClick={() => handleFunction('csc')} className={btnClass}><span className="font-bold">csc</span><span className="text-[10px] opacity-70">cosecant</span></button>
              <button onClick={() => handleFunction('cot')} className={btnClass}><span className="font-bold">cot</span><span className="text-[10px] opacity-70">cotangent</span></button>
              <button onClick={() => handleFunction('asin')} className={btnClass}><span className="font-bold">sin⁻¹</span><span className="text-[10px] opacity-70">arcsin</span></button>
              <button onClick={() => handleFunction('acos')} className={btnClass}><span className="font-bold">cos⁻¹</span><span className="text-[10px] opacity-70">arccos</span></button>

              {/* Row 3: Inverse & Hyperbolic */}
              <button onClick={() => handleFunction('atan')} className={btnClass}><span className="font-bold">tan⁻¹</span><span className="text-[10px] opacity-70">arctan</span></button>
              <button onClick={() => handleFunction('sinh')} className={btnClass}><span className="font-bold">sinh</span><span className="text-[10px] opacity-70">hyp sin</span></button>
              <button onClick={() => handleFunction('cosh')} className={btnClass}><span className="font-bold">cosh</span><span className="text-[10px] opacity-70">hyp cos</span></button>
              <button onClick={() => handleFunction('tanh')} className={btnClass}><span className="font-bold">tanh</span><span className="text-[10px] opacity-70">hyp tan</span></button>

              {/* Row 4: Inverse Hyperbolic & Reciprocals */}
              <button onClick={() => handleFunction('asinh')} className={btnClass}><span className="font-bold">sinh⁻¹</span><span className="text-[10px] opacity-70">arsinh</span></button>
              <button onClick={() => handleFunction('acosh')} className={btnClass}><span className="font-bold">cosh⁻¹</span><span className="text-[10px] opacity-70">arcosh</span></button>
              <button onClick={() => handleFunction('atanh')} className={btnClass}><span className="font-bold">tanh⁻¹</span><span className="text-[10px] opacity-70">artanh</span></button>
              <button onClick={() => handleFunction('sech')} className={btnClass}><span className="font-bold">sech</span><span className="text-[10px] opacity-70">hyp sec</span></button>

              {/* Row 5: csch, coth, Pi, and Angle Mode Switcher */}
              <button onClick={() => handleFunction('csch')} className={btnClass}><span className="font-bold">csch</span><span className="text-[10px] opacity-70">hyp csc</span></button>
              <button onClick={() => handleFunction('coth')} className={btnClass}><span className="font-bold">coth</span><span className="text-[10px] opacity-70">hyp cot</span></button>
              <button onClick={() => handleInput('π')} className={btnClass} title="Pi π ≈ 3.14159">
                <span className="font-bold text-sm">π</span>
                <span className="text-[10px] opacity-70">3.14159</span>
              </button>
              <button
                onClick={onToggleAngleMode}
                className={`${btnClass} bg-[var(--m3-primary-container)] text-[var(--m3-on-primary-container)] border-[var(--m3-primary)]/50`}
                title="Toggle Angle Mode (DEG/RAD/GRAD)"
              >
                <span className="font-bold font-mono text-xs">{angleMode.toUpperCase()}</span>
                <span className="text-[9px] opacity-80">switch mode</span>
              </button>
            </div>
          </div>
        );

      case 'powers':
        return (
          <div className="flex flex-col h-full w-full justify-between">
            <div className={gridClass}>
              {/* Row 1: Common Powers */}
              <button onClick={() => handleInput('^2')} className={btnClass}>
                <span className="font-bold">x²</span>
                <span className="text-[10px] opacity-70">square</span>
              </button>
              <button onClick={() => handleInput('^3')} className={btnClass}>
                <span className="font-bold">x³</span>
                <span className="text-[10px] opacity-70">cube</span>
              </button>
              <button onClick={() => handleInput('^')} className={btnClass}>
                <span className="font-bold">xʸ</span>
                <span className="text-[10px] opacity-70">power</span>
              </button>
              <button onClick={() => handleInput('^(-1)')} className={btnClass}>
                <span className="font-bold">x⁻¹</span>
                <span className="text-[10px] opacity-70">1/x</span>
              </button>

              {/* Row 2: Roots */}
              <button onClick={() => handleFunction('sqrt')} className={btnClass}>
                <span className="font-bold">√x</span>
                <span className="text-[10px] opacity-70">sq root</span>
              </button>
              <button onClick={() => handleFunction('cbrt')} className={btnClass}>
                <span className="font-bold">³√x</span>
                <span className="text-[10px] opacity-70">cube root</span>
              </button>
              <button onClick={() => handleInsertTemplate('root(')} className={btnClass} title="Arbitrary root(deg, x)">
                <span className="font-bold">ʸ√x</span>
                <span className="text-[10px] opacity-70">root(y,x)</span>
              </button>
              <button onClick={() => handleFunction('abs')} className={btnClass}>
                <span className="font-bold">|x|</span>
                <span className="text-[10px] opacity-70">absolute</span>
              </button>

              {/* Row 3: Exponential Functions */}
              <button onClick={() => handleInsertTemplate('10^(')} className={btnClass}>
                <span className="font-bold">10ˣ</span>
                <span className="text-[10px] opacity-70">10^x</span>
              </button>
              <button onClick={() => handleInsertTemplate('2^(')} className={btnClass}>
                <span className="font-bold">2ˣ</span>
                <span className="text-[10px] opacity-70">2^x</span>
              </button>
              <button onClick={() => handleInsertTemplate('exp(')} className={btnClass}>
                <span className="font-bold">eˣ</span>
                <span className="text-[10px] opacity-70">exp(x)</span>
              </button>
              <button onClick={() => handleInput('e')} className={btnClass}>
                <span className="font-bold text-sm">e</span>
                <span className="text-[10px] opacity-70">2.71828</span>
              </button>

              {/* Row 4: Logarithms */}
              <button onClick={() => handleFunction('ln')} className={btnClass}>
                <span className="font-bold">ln</span>
                <span className="text-[10px] opacity-70">base e</span>
              </button>
              <button onClick={() => handleFunction('log')} className={btnClass}>
                <span className="font-bold">log₁₀</span>
                <span className="text-[10px] opacity-70">base 10</span>
              </button>
              <button onClick={() => handleFunction('log2')} className={btnClass}>
                <span className="font-bold">log₂</span>
                <span className="text-[10px] opacity-70">base 2</span>
              </button>
              <button onClick={() => handleInsertTemplate('logb(')} className={btnClass} title="logb(base, x)">
                <span className="font-bold">log_b</span>
                <span className="text-[10px] opacity-70">any base</span>
              </button>

              {/* Row 5: Mathematical Helpers */}
              <button onClick={() => handleFunction('sign')} className={btnClass}>
                <span className="font-bold">sgn</span>
                <span className="text-[10px] opacity-70">sign</span>
              </button>
              <button onClick={() => handleInput('%')} className={btnClass}>
                <span className="font-bold">%</span>
                <span className="text-[10px] opacity-70">percent</span>
              </button>
              <button onClick={() => handleParentheses()} className={btnClass}>
                <span className="font-bold">( )</span>
                <span className="text-[10px] opacity-70">brackets</span>
              </button>
              <button onClick={() => handleInput(', ')} className={btnClass}>
                <span className="font-bold text-sm">,</span>
                <span className="text-[10px] opacity-70">comma</span>
              </button>
            </div>
          </div>
        );

      case 'prob':
        return (
          <div className="flex flex-col h-full w-full justify-between">
            <div className={gridClass}>
              {/* Row 1: Permutations, Combinations, Factorial, Modulo */}
              <button onClick={() => handleInsertTemplate('nPr(')} className={btnClass} title="Permutations: nPr(n, r)">
                <span className="font-bold">nPr</span>
                <span className="text-[10px] opacity-70">permutation</span>
              </button>
              <button onClick={() => handleInsertTemplate('nCr(')} className={btnClass} title="Combinations: nCr(n, r)">
                <span className="font-bold">nCr</span>
                <span className="text-[10px] opacity-70">combination</span>
              </button>
              <button onClick={() => handleInput('!')} className={btnClass} title="Factorial: x!">
                <span className="font-bold">x!</span>
                <span className="text-[10px] opacity-70">factorial</span>
              </button>
              <button onClick={() => handleInsertTemplate('mod(')} className={btnClass} title="Modulo: mod(a, b)">
                <span className="font-bold">mod</span>
                <span className="text-[10px] opacity-70">modulo</span>
              </button>

              {/* Row 2: GCD, LCM, Rounding, Sign */}
              <button onClick={() => handleInsertTemplate('gcd(')} className={btnClass} title="Greatest Common Divisor">
                <span className="font-bold">gcd</span>
                <span className="text-[10px] opacity-70">greatest div</span>
              </button>
              <button onClick={() => handleInsertTemplate('lcm(')} className={btnClass} title="Least Common Multiple">
                <span className="font-bold">lcm</span>
                <span className="text-[10px] opacity-70">least mult</span>
              </button>
              <button onClick={() => handleFunction('round')} className={btnClass} title="Round to nearest integer">
                <span className="font-bold">round</span>
                <span className="text-[10px] opacity-70">nearest</span>
              </button>
              <button onClick={() => handleFunction('sign')} className={btnClass}>
                <span className="font-bold">sgn</span>
                <span className="text-[10px] opacity-70">sign</span>
              </button>

              {/* Row 3: Floor, Ceil, Random Generators */}
              <button onClick={() => handleFunction('floor')} className={btnClass} title="Floor: greatest integer <= x">
                <span className="font-bold">floor</span>
                <span className="text-[10px] opacity-70">round down</span>
              </button>
              <button onClick={() => handleFunction('ceil')} className={btnClass} title="Ceil: least integer >= x">
                <span className="font-bold">ceil</span>
                <span className="text-[10px] opacity-70">round up</span>
              </button>
              <button onClick={() => handleInsertTemplate('rand()')} className={btnClass} title="Random number 0..1">
                <span className="font-bold">rand()</span>
                <span className="text-[10px] opacity-70">0 ... 1</span>
              </button>
              <button onClick={() => handleInsertTemplate('randInt(')} className={btnClass} title="Random integer: randInt(min, max)">
                <span className="font-bold">randInt</span>
                <span className="text-[10px] opacity-70">min, max</span>
              </button>

              {/* Row 4: Statistics & Comparisons */}
              <button onClick={() => handleInsertTemplate('min(')} className={btnClass} title="Minimum: min(a, b)">
                <span className="font-bold">min</span>
                <span className="text-[10px] opacity-70">minimum</span>
              </button>
              <button onClick={() => handleInsertTemplate('max(')} className={btnClass} title="Maximum: max(a, b)">
                <span className="font-bold">max</span>
                <span className="text-[10px] opacity-70">maximum</span>
              </button>
              <button onClick={() => handleInsertTemplate('mean(')} className={btnClass} title="Average / Mean: mean(a, b)">
                <span className="font-bold">avg</span>
                <span className="text-[10px] opacity-70">average</span>
              </button>
              <button onClick={() => handleFunction('abs')} className={btnClass} title="Absolute Value: |x|">
                <span className="font-bold">|x|</span>
                <span className="text-[10px] opacity-70">absolute</span>
              </button>

              {/* Row 5: Symbols & Comma */}
              <button onClick={() => handleInput(', ')} className={btnClass} title="Comma Separator">
                <span className="font-bold text-sm">,</span>
                <span className="text-[10px] opacity-70">comma</span>
              </button>
              <button onClick={() => handleParentheses()} className={btnClass}>
                <span className="font-bold text-sm">( )</span>
                <span className="text-[10px] opacity-70">parens</span>
              </button>
              <button onClick={() => handleInput('%')} className={btnClass}>
                <span className="font-bold">%</span>
                <span className="text-[10px] opacity-70">percent</span>
              </button>
              <button onClick={() => handleInput('π')} className={btnClass}>
                <span className="font-bold text-sm">π</span>
                <span className="text-[10px] opacity-70">3.14159</span>
              </button>
            </div>

            {!isLandscapeMode && (
              <div className="text-[10px] text-center opacity-75 font-mono text-[var(--m3-on-surface-variant)] truncate pt-1">
                Syntax: nCr(n, r) • nPr(n, r) • gcd(a, b) • lcm(a, b) • randInt(1, 100)
              </div>
            )}
          </div>
        );

      case 'constants':
        return (
          <div className="flex flex-col h-full w-full justify-between">
            <div className={gridClass}>
              {/* Row 1: Mathematical & Relativistic Constants */}
              <button onClick={() => handleInput('π')} className={btnClass} title="Pi ≈ 3.1415926535">
                <span className="font-bold text-sm">π</span>
                <span className="text-[10px] opacity-70">3.14159</span>
              </button>
              <button onClick={() => handleInput('e')} className={btnClass} title="Euler's number ≈ 2.7182818284">
                <span className="font-bold text-sm">e</span>
                <span className="text-[10px] opacity-70">2.71828</span>
              </button>
              <button onClick={() => handleInput('φ')} className={btnClass} title="Golden Ratio φ ≈ 1.6180339887">
                <span className="font-bold text-sm">φ</span>
                <span className="text-[10px] opacity-70">1.61803</span>
              </button>
              <button onClick={() => handleInput('c')} className={btnClass} title="Speed of light c = 299,792,458 m/s">
                <span className="font-bold">c</span>
                <span className="text-[10px] opacity-70">light speed</span>
              </button>

              {/* Row 2: Quantum & Gravitational Constants */}
              <button onClick={() => handleInput('h')} className={btnClass} title="Planck constant h = 6.62607015×10⁻³⁴ J·s">
                <span className="font-bold">h</span>
                <span className="text-[10px] opacity-70">planck</span>
              </button>
              <button onClick={() => handleInput('hbar')} className={btnClass} title="Reduced Planck constant ħ = 1.05457×10⁻³⁴ J·s">
                <span className="font-bold">ħ</span>
                <span className="text-[10px] opacity-70">h / 2π</span>
              </button>
              <button onClick={() => handleInput('G')} className={btnClass} title="Gravitational constant G = 6.67430×10⁻¹¹ N·m²/kg²">
                <span className="font-bold">G</span>
                <span className="text-[10px] opacity-70">gravity</span>
              </button>
              <button onClick={() => handleInput('kB')} className={btnClass} title="Boltzmann constant kB = 1.380649×10⁻²³ J/K">
                <span className="font-bold">k_B</span>
                <span className="text-[10px] opacity-70">boltzmann</span>
              </button>

              {/* Row 3: Atomic & Fundamental Constants */}
              <button onClick={() => handleInput('NA')} className={btnClass} title="Avogadro constant NA = 6.02214076×10²³ mol⁻¹">
                <span className="font-bold">N_A</span>
                <span className="text-[10px] opacity-70">avogadro</span>
              </button>
              <button onClick={() => handleInput('qe')} className={btnClass} title="Elementary charge e = 1.602176634×10⁻¹⁹ C">
                <span className="font-bold">q_e</span>
                <span className="text-[10px] opacity-70">elem charge</span>
              </button>
              <button onClick={() => handleInput('me')} className={btnClass} title="Electron mass me = 9.1093837×10⁻³¹ kg">
                <span className="font-bold">m_e</span>
                <span className="text-[10px] opacity-70">electron</span>
              </button>
              <button onClick={() => handleInput('g')} className={btnClass} title="Standard gravity g = 9.80665 m/s²">
                <span className="font-bold">g</span>
                <span className="text-[10px] opacity-70">9.80665 m/s²</span>
              </button>

              {/* Row 4: Subatomic & Electrodynamic Constants */}
              <button onClick={() => handleInput('mp')} className={btnClass} title="Proton mass mp = 1.67262×10⁻²⁷ kg">
                <span className="font-bold">m_p</span>
                <span className="text-[10px] opacity-70">proton mass</span>
              </button>
              <button onClick={() => handleInput('mn')} className={btnClass} title="Neutron mass mn = 1.67493×10⁻²⁷ kg">
                <span className="font-bold">m_n</span>
                <span className="text-[10px] opacity-70">neutron mass</span>
              </button>
              <button onClick={() => handleInput('eps0')} className={btnClass} title="Permittivity ε₀ = 8.85418×10⁻¹² F/m">
                <span className="font-bold">ε₀</span>
                <span className="text-[10px] opacity-70">permittivity</span>
              </button>
              <button onClick={() => handleInput('mu0')} className={btnClass} title="Permeability μ₀ = 1.25663×10⁻⁶ N/A²">
                <span className="font-bold">μ₀</span>
                <span className="text-[10px] opacity-70">permeability</span>
              </button>

              {/* Row 5: Thermodynamic & Planetary Constants */}
              <button onClick={() => handleInput('R')} className={btnClass} title="Molar Gas constant R = 8.31446 J/(mol·K)">
                <span className="font-bold">R</span>
                <span className="text-[10px] opacity-70">gas const</span>
              </button>
              <button onClick={() => handleInput('sigma')} className={btnClass} title="Stefan-Boltzmann constant σ = 5.67037×10⁻⁸ W/(m²·K⁴)">
                <span className="font-bold">σ</span>
                <span className="text-[10px] opacity-70">stefan-boltz</span>
              </button>
              <button onClick={() => handleInput('atm')} className={btnClass} title="Standard Atmosphere = 101,325 Pa">
                <span className="font-bold">atm</span>
                <span className="text-[10px] opacity-70">101325 Pa</span>
              </button>
              <button onClick={() => handleInput('au')} className={btnClass} title="Astronomical Unit au = 1.49597×10¹¹ m">
                <span className="font-bold">au</span>
                <span className="text-[10px] opacity-70">astron unit</span>
              </button>
            </div>
          </div>
        );
    }
  };

  // =========================================================================
  // LANDSCAPE LAYOUT (Pixel Complete Dual-Pane / Unified Tablet Experience)
  // =========================================================================
  if (isLandscape) {
    return (
      <div className="w-full max-w-[1600px] mx-auto flex gap-3.5 sm:gap-5 h-full flex-1 min-h-[500px] min-h-0 select-none">
        {/* Left Side: Display, Angle Status, Recent Tape preview */}
        <div
          className="w-[320px] sm:w-[360px] md:w-[400px] lg:w-[440px] xl:w-[480px] shrink-0 rounded-[32px] p-4 sm:p-6 flex flex-col justify-between min-h-0"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          {/* Top Status Badges */}
          <div className="flex items-center justify-between shrink-0">
            <button
              onClick={onToggleAngleMode}
              className="px-3 py-1.5 text-xs font-mono font-bold rounded-full transition-all active:scale-95 cursor-pointer "
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                color: 'var(--m3-primary)',
              }}
              title="Click to toggle angle mode (DEG/RAD/GRAD)"
            >
              {angleMode.toUpperCase()}
            </button>

            <div className="flex items-center gap-2">
              {onOpenHistory && (
                <button
                  onClick={onOpenHistory}
                  className="p-2 rounded-full transition-all active:scale-90 cursor-pointer flex items-center gap-1.5"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-high)',
                    color: 'var(--m3-on-surface-variant)',
                  }}
                  title="View Calculation History"
                >
                  <RotateCcw className="w-4 h-4" />
                  {history && history.length > 0 && (
                    <span className="text-[10px] font-mono font-bold px-1.5 py-0.5 rounded-full bg-[var(--m3-primary)] text-[var(--m3-on-primary)]">
                      {history.length > 9 ? '9+' : history.length}
                    </span>
                  )}
                </button>
              )}

              <button
                onClick={handleCopy}
                className="p-2 rounded-full transition-all active:scale-90 cursor-pointer"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-on-surface-variant)',
                }}
                title="Copy Result"
              >
                {copied ? (
                  <Check className="w-4 h-4 text-green-500" />
                ) : (
                  <Copy className="w-4 h-4" />
                )}
              </button>
            </div>
          </div>

          {/* Numbers Output Display with History Tape Preview */}
          <div className="flex flex-col justify-end text-right my-auto overflow-hidden py-2">
            {/* Tablet Context: Previous Calculation Tape preview */}
            {history && history.length > 0 && (
              <div className="flex flex-col gap-1 mb-3 opacity-60 overflow-hidden">
                {history.slice(0, 2).reverse().map((h) => (
                  <button
                    key={h.id}
                    onClick={() => onSelectHistoryItem?.(h.expression)}
                    className="text-right font-mono text-xs text-[var(--m3-on-surface-variant)] hover:opacity-100 transition-opacity truncate cursor-pointer"
                    title={`Click to load: ${h.expression}`}
                  >
                    <span className="opacity-70">{h.expression}</span> = <span className="font-semibold">{h.result}</span>
                  </button>
                ))}
              </div>
            )}

            {equation && (
              <div className="text-xs sm:text-sm font-semibold truncate mb-0.5" style={{ color: 'var(--m3-tertiary)' }}>
                y = {equation}{' '}
                <span className="font-normal opacity-80">{lastQuestion || expression !== '0' ? '' : '· type x, then ='}</span>
              </div>
            )}
                        {lastQuestion && (
              <div
                className="font-mono text-sm tracking-wide truncate mb-1 opacity-70"
                style={{ color: 'var(--m3-outline)' }}
              >
                {lastQuestion} =
              </div>
            )}
            <div
              className={`font-mono font-bold tracking-tight overflow-x-auto whitespace-nowrap no-scrollbar py-1 select-all ${
 expression.length > 14
 ? 'text-2xl sm:text-3xl'
 : expression.length > 8
 ? 'text-3xl sm:text-4xl lg:text-5xl'
 : 'text-4xl sm:text-5xl lg:text-6xl'
 }`}
              style={{ color: 'var(--m3-on-surface)' }}
            >
              {expression}
            </div>

            {lastAnswer && hasEvaluated && (
              <div
                className="font-mono font-bold text-2xl sm:text-3xl lg:text-4xl mt-1.5 tracking-tight truncate animate-m3-result-update"
                style={{ color: 'var(--m3-primary)' }}
              >
                = {lastAnswer}
              </div>
            )}
          </div>

          {/* Memory Row */}
          <div className="grid grid-cols-4 gap-2 pt-3 border-t border-[var(--m3-outline-variant)]/30 shrink-0">
            {(['MC', 'MR', 'M+', 'M-'] as const).map((mAct) => (
              <button
                key={mAct}
                onClick={() => handleMemory(mAct)}
                className="h-10 sm:h-11 text-xs font-mono font-bold rounded-2xl transition-all active:scale-95 cursor-pointer flex items-center justify-center"
                style={{
                  backgroundColor: 'var(--m3-surface-container)',
                  color: 'var(--m3-on-surface-variant)',
                }}
              >
                {mAct}
              </button>
            ))}
          </div>
        </div>

        {/* Right Side: Pixel Complete Keypad with Dedicated Category Tabs */}
        <div
          className="flex-1 rounded-[32px] p-3.5 sm:p-5 flex flex-col justify-between overflow-hidden min-h-0"
          style={{
            backgroundColor: 'var(--m3-surface-container-low)',
          }}
        >
          {/* Keypad Grid: Columns 1-4 for selected tab functions; Columns 5-8 for standard numbers & operations */}
          <div className="grid grid-cols-8 gap-2.5 sm:gap-3 flex-1 h-full min-h-0">
            {/* Left 4 columns: Advanced Category Tab Functions (Swipeable + Wheel + Chevron buttons) */}
            <div className="col-span-4 h-full flex flex-col justify-between min-h-0">
              <SwipeableTabContainer
                tabs={ADVANCED_TABS}
                activeTabId={advancedTab}
                onSelectTab={(id) => {
                  playSound('toggle');
                  setAdvancedTab(id as AdvancedTab);
                }}
                compact={true}
                showNavButtons={true}
                tabBarClassName="pb-1 mb-2"
                className="w-full h-full flex-1 flex flex-col justify-between min-h-0"
              >
                <div className="w-full h-full flex-1 flex flex-col min-h-0">
                  <div key={advancedTab} className="h-full w-full">{renderAdvancedTabContent(true)}</div>
                </div>
              </SwipeableTabContainer>
            </div>

            {/* Right 4 columns: Numbers & Standard Arithmetic Keypad */}
            <div className="col-span-4 grid grid-cols-4 grid-rows-5 gap-2 sm:gap-2.5 h-full min-h-0">
              {/* Row 1 */}
              <button onClick={handleClear} className="h-full w-full min-h-[46px] sm:min-h-[54px] md:min-h-[62px] text-base font-bold rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-tertiary-container)] text-[var(--m3-on-tertiary-container)] flex items-center justify-center cursor-pointer active:scale-95 transition-transform">AC</button>
              <button onClick={handleBackspace} className={KEY_FUNCTION}><Delete className="w-5 h-5" /></button>
              <button onClick={() => handleInput('%')} className={KEY_FUNCTION}>%</button>
              <button onClick={() => handleInput('÷')} className={KEY_OPERATOR}>÷</button>

              {/* Row 2 */}
              <button onClick={() => handleInput('7')} className={KEY_DIGIT}>7</button>
              <button onClick={() => handleInput('8')} className={KEY_DIGIT}>8</button>
              <button onClick={() => handleInput('9')} className={KEY_DIGIT}>9</button>
              <button onClick={() => handleInput('×')} className={KEY_OPERATOR}>×</button>

              {/* Row 3 */}
              <button onClick={() => handleInput('4')} className={KEY_DIGIT}>4</button>
              <button onClick={() => handleInput('5')} className={KEY_DIGIT}>5</button>
              <button onClick={() => handleInput('6')} className={KEY_DIGIT}>6</button>
              <button onClick={() => handleInput('−')} className={KEY_OPERATOR}>−</button>

              {/* Row 4 */}
              <button onClick={() => handleInput('1')} className={KEY_DIGIT}>1</button>
              <button onClick={() => handleInput('2')} className={KEY_DIGIT}>2</button>
              <button onClick={() => handleInput('3')} className={KEY_DIGIT}>3</button>
              <button onClick={() => handleInput('+')} className={KEY_OPERATOR}>+</button>

              {/* Row 5 */}
              <button onClick={() => handleInput('0')} className="h-full w-full min-h-[46px] sm:min-h-[54px] md:min-h-[62px] col-span-2 text-xl sm:text-2xl font-mono font-medium rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface)] flex items-center justify-center cursor-pointer active:scale-95 transition-transform">0</button>
              <button onClick={() => handleInput('.')} className="h-full w-full min-h-[46px] sm:min-h-[54px] md:min-h-[62px] text-xl sm:text-2xl font-mono font-bold rounded-[22px] sm:rounded-[26px] m3-key bg-[var(--m3-surface-container-high)] text-[var(--m3-on-surface)] flex items-center justify-center cursor-pointer active:scale-95 transition-transform">.</button>
              {/* Landscape Equals Key */}
              <button
                onClick={handleEvaluate}
                className={`h-full w-full min-h-[46px] sm:min-h-[54px] md:min-h-[62px] text-2xl font-bold rounded-[22px] sm:rounded-[26px] m3-key flex items-center justify-center gap-1.5 cursor-pointer transition-all duration-150 ${
 isEqualsPressed ? 'scale-[0.93] brightness-125 shadow-[0_0_32px_6px_color-mix(in_srgb,var(--m3-primary)_85%,transparent)]' : ''
 }`}
                style={{
                  backgroundColor: 'var(--m3-primary)',
                  color: 'var(--m3-on-primary)',
                }}
              >
                <span>=</span>
                <CornerDownLeft className="w-4 h-4 opacity-80" />
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // =========================================================================
  // PORTRAIT LAYOUT (Google Pixel Portrait & Tablet Expressive Grid)
  // =========================================================================
  // Phone portrait: the answer display is pinned under the header (App puts it in its top bar), so the
  // advanced keys and the keypad scroll underneath it and the answer never leaves the screen.
  const portraitDisplay = (
    <motion.div
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={spring}
      className="bar-surface bar-surface-strong pointer-events-auto w-full max-w-xl sm:max-w-2xl md:max-w-3xl lg:max-w-4xl mx-auto rounded-[28px] sm:rounded-[32px] p-3.5 sm:p-5 flex flex-col"
      style={
        {
          minHeight: 'clamp(214px, 30dvh, 330px)',
          '--bar-tone': 'var(--m3-surface-container-highest)',
        } as React.CSSProperties
      }
    >
          {/* App header row, part of this card */}
          {headerRow && (
            <div
              className="mb-2.5 pb-2 shrink-0"
              style={{ borderBottom: '1px solid color-mix(in srgb, var(--m3-on-surface) 10%, transparent)' }}
            >
              {headerRow}
            </div>
          )}

          {/* Header Row of Screen: Angle mode badge, Open parens counter, History & Copy */}
          <div className="flex items-center justify-between mb-2 shrink-0">
            <div className="flex items-center gap-2">
              <button
                onClick={onToggleAngleMode}
                className="px-3 py-1 text-xs sm:text-sm font-mono font-bold rounded-full transition-all duration-150 active:scale-95 cursor-pointer "
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-primary)',
                }}
                title="Click to toggle angle mode (DEG/RAD/GRAD)"
              >
                {angleMode.toUpperCase()}
              </button>

              {openParensCount > 0 && (
                <span
                  className="px-2.5 py-0.5 text-xs sm:text-sm font-mono rounded-full animate-pulse"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-high)',
                    color: 'var(--m3-tertiary)',
                  }}
                  title="Unclosed parentheses"
                >
                  {openParensCount} unclosed (
                </span>
              )}
            </div>

            <div className="flex items-center gap-2">
              {onOpenHistory && (
                <button
                  onClick={onOpenHistory}
                  className="p-2 rounded-full transition-all duration-150 active:scale-90 cursor-pointer flex items-center gap-1.5"
                  style={{
                    backgroundColor: 'var(--m3-surface-container-high)',
                    color: 'var(--m3-on-surface-variant)',
                  }}
                  title="View History Tape"
                >
                  <RotateCcw className="w-4 h-4" />
                  {history && history.length > 0 && (
                    <span className="text-[10px] font-mono font-bold px-1.5 py-0.5 rounded-full bg-[var(--m3-primary)] text-[var(--m3-on-primary)]">
                      {history.length > 9 ? '9+' : history.length}
                    </span>
                  )}
                </button>
              )}

              <button
                onClick={handleCopy}
                className="p-2 rounded-full transition-all duration-150 active:scale-90 cursor-pointer"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-on-surface-variant)',
                }}
                title="Copy current result or expression"
              >
                {copied ? (
                  <Check className="w-4 h-4 text-green-500" />
                ) : (
                  <Copy className="w-4 h-4" />
                )}
              </button>
            </div>
          </div>


      {/* Expression and answer: big, and it shrinks smoothly instead of getting cut off */}
      <div className="flex-1 flex flex-col justify-end text-right min-h-0 pt-2">
        {equation && (
          <div className="text-xs sm:text-sm font-semibold truncate mb-0.5" style={{ color: 'var(--m3-tertiary)' }}>
            y = {equation}{' '}
            <span className="font-normal opacity-80">{lastQuestion || expression !== '0' ? '' : '· type x, then ='}</span>
          </div>
        )}
        {lastQuestion && (
          <div
            className="text-sm sm:text-base tracking-wide truncate mb-0.5 opacity-70"
            style={{ color: 'var(--m3-outline)' }}
          >
            {lastQuestion} =
          </div>
        )}
        {isErrorResult ? (
          <div
            className="text-base sm:text-lg font-semibold leading-snug break-words py-1 max-h-[7.5rem] overflow-y-auto animate-m3-result-update"
            style={{ color: 'var(--m3-error)' }}
            role="alert"
          >
            {expression}
          </div>
        ) : (
          <AutoFitText
            text={expression}
            max={72}
            min={26}
            className={`font-bold tracking-tight py-1 select-all ${hasEvaluated ? 'animate-m3-result-update' : ''}`}
            style={{ color: hasEvaluated ? 'var(--m3-primary)' : 'var(--m3-on-surface)' }}
          />
        )}
      </div>
    </motion.div>
  );

  return (
    <div className="w-full max-w-xl sm:max-w-2xl md:max-w-3xl lg:max-w-4xl xl:max-w-5xl mx-auto flex-1 flex flex-col select-none min-h-0">
      {pinnedSlot ? createPortal(portraitDisplay, pinnedSlot) : portraitDisplay}

      {/* Keys card: scrolls under the pinned display */}
      <div
        className="w-full flex-1 flex flex-col rounded-[28px] sm:rounded-[36px] md:rounded-[44px] p-2.5 sm:p-5 md:p-6 lg:p-7 transition-colors min-h-0"
        style={{
          backgroundColor: 'color-mix(in srgb, var(--m3-surface-container-low) 96%, transparent)',
        }}
      >
        {/* M3 Expressive Quick Memory Ribbon Bar */}
        <div className="grid grid-cols-4 gap-1.5 sm:gap-2.5 mb-2 sm:mb-3 shrink-0">
          {(['MC', 'MR', 'M+', 'M-'] as const).map((mAct) => (
            <button
              key={mAct}
              onClick={() => handleMemory(mAct)}
              className="h-8 sm:h-10 md:h-11 text-xs sm:text-sm font-mono font-bold rounded-full transition-all active:scale-95 cursor-pointer flex items-center justify-center"
              style={{
                backgroundColor: mAct === 'MR' && memory !== 0 ? 'var(--m3-secondary-container)' : 'var(--m3-surface-container)',
                color: mAct === 'MR' && memory !== 0 ? 'var(--m3-on-secondary-container)' : 'var(--m3-on-surface-variant)',
              }}
            >
              {mAct}
            </button>
          ))}
        </div>

        {/* Scientific Advanced Drawer: slides open and the keys pop in one after another */}
        <AnimatePresence initial={false}>
          {isScientific && (
            <motion.div
              key="advanced-drawer"
              className="shrink-0"
              initial={{ height: 0, opacity: 0, marginBottom: 0, scale: 0.97 }}
              animate={{ height: 'auto', opacity: 1, marginBottom: 12, scale: 1 }}
              exit={{ height: 0, opacity: 0, marginBottom: 0, scale: 0.97 }}
              transition={{
                height: spring,
                marginBottom: spring,
                scale: spring,
                opacity: { duration: 0.22 },
              }}
              style={{ overflow: 'hidden', transformOrigin: 'top center' }}
            >
              <div className="p-3 sm:p-4 rounded-[28px]" style={{ backgroundColor: 'var(--m3-surface-container)' }}>
            {/* Drawer Sub-Header */}
            <div className="flex items-center justify-between pb-2 mb-2 border-b border-[var(--m3-outline-variant)]/40">
              <div className="flex items-center gap-2">
                <OmniCalcLogo className="w-4 h-4" />
                <span className="text-xs sm:text-sm font-semibold" style={{ color: 'var(--m3-on-surface)' }}>
                  Advanced Scientific Operations
                </span>
              </div>
              <button
                onClick={() => {
                  playSound('toggle');
                  setIsScientific(false);
                }}
                className="flex items-center gap-1.5 px-3 py-1 rounded-full transition-all duration-150 active:scale-90 cursor-pointer"
                style={{
                  backgroundColor: 'var(--m3-surface-container-high)',
                  color: 'var(--m3-primary)',
                }}
              >
                <span className="text-xs font-semibold">Hide</span>
                <ChevronUp className="w-3.5 h-3.5" />
              </button>
            </div>

            {/* Category Tab Selector Strip with 120Hz Direct Swipe Gestures */}
            <SwipeableTabContainer
              tabs={ADVANCED_TABS}
              activeTabId={advancedTab}
              onSelectTab={(id) => {
                playSound('toggle');
                setAdvancedTab(id as AdvancedTab);
              }}
              compact={true}
              showNavButtons={true}
              tabBarClassName="pb-1 mb-2"
              tabPillClassName="bg-[var(--m3-surface-container-high)]"
              className="w-full"
            >
              <div key={advancedTab} className="w-full">
                {renderAdvancedTabContent(false)}
              </div>
            </SwipeableTabContainer>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Primary Calculator Keypad: Full-Height Proportional Tablet & Mobile Squircle Keypad */}
        <div
          className="flex-1 grid grid-cols-4 gap-1.5 sm:gap-2.5 md:gap-3.5 lg:gap-4"
          style={{
            gridTemplateRows: `repeat(5, minmax(${isScientific ? 58 : 44}px, 1fr))`,
            minHeight: `${5 * (isScientific ? 58 : 44) + 32}px`,
          }}
        >
          {/* Row 1: Function / Clear Row */}
          <button
            onClick={handleClear}
            className="h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] text-base sm:text-xl md:text-2xl font-bold rounded-[16px] sm:rounded-[24px] md:rounded-[32px] m3-key flex items-center justify-center cursor-pointer active:scale-95 transition-transform"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              color: 'var(--m3-tertiary)',
            }}
          >
            AC
          </button>
          <button
            onClick={handleBackspace}
            className="h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] text-sm sm:text-base font-semibold rounded-[16px] sm:rounded-[24px] md:rounded-[32px] m3-key flex items-center justify-center cursor-pointer active:scale-95 transition-transform"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              color: 'var(--m3-on-surface-variant)',
            }}
            title="Backspace"
          >
            <Delete className="w-5 h-5 sm:w-6 sm:h-6 md:w-7 md:h-7" />
          </button>
          <button
            onClick={() => handleInput('%')}
            className="h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] text-base sm:text-xl md:text-2xl font-semibold rounded-[16px] sm:rounded-[24px] md:rounded-[32px] m3-key flex items-center justify-center cursor-pointer active:scale-95 transition-transform"
            style={{
              backgroundColor: 'var(--m3-surface-container)',
              color: 'var(--m3-on-surface-variant)',
            }}
          >
            %
          </button>
          <button
            onClick={() => handleInput('÷')}
            className={KEY_OPERATOR_LARGE}
            style={{
              backgroundColor: 'var(--m3-secondary-container)',
              color: 'var(--m3-on-secondary-container)',
            }}
          >
            ÷
          </button>

          {/* Row 2: 7, 8, 9, × */}
          <button
            onClick={() => handleInput('7')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            7
          </button>
          <button
            onClick={() => handleInput('8')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            8
          </button>
          <button
            onClick={() => handleInput('9')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            9
          </button>
          <button
            onClick={() => handleInput('×')}
            className={KEY_OPERATOR_LARGE}
            style={{
              backgroundColor: 'var(--m3-secondary-container)',
              color: 'var(--m3-on-secondary-container)',
            }}
          >
            ×
          </button>

          {/* Row 3: 4, 5, 6, − */}
          <button
            onClick={() => handleInput('4')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            4
          </button>
          <button
            onClick={() => handleInput('5')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            5
          </button>
          <button
            onClick={() => handleInput('6')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            6
          </button>
          <button
            onClick={() => handleInput('−')}
            className={KEY_OPERATOR_LARGE}
            style={{
              backgroundColor: 'var(--m3-secondary-container)',
              color: 'var(--m3-on-secondary-container)',
            }}
          >
            −
          </button>

          {/* Row 4: 1, 2, 3, + */}
          <button
            onClick={() => handleInput('1')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            1
          </button>
          <button
            onClick={() => handleInput('2')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            2
          </button>
          <button
            onClick={() => handleInput('3')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            3
          </button>
          <button
            onClick={() => handleInput('+')}
            className={KEY_OPERATOR_LARGE}
            style={{
              backgroundColor: 'var(--m3-secondary-container)',
              color: 'var(--m3-on-secondary-container)',
            }}
          >
            +
          </button>

          {/* Row 5: fx ADV Drawer Toggle + 0 + . + Hero Equals Pill */}
          <button
            onClick={() => {
              playSound('toggle');
              setIsScientific(!isScientific);
            }}
            className="h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] px-2 text-xs sm:text-base font-semibold rounded-[16px] sm:rounded-[24px] md:rounded-[32px] m3-key flex items-center justify-center gap-1.5 transition-all cursor-pointer active:scale-95"
            style={{
              backgroundColor: isScientific
                ? 'var(--m3-tertiary-container)'
                : 'var(--m3-surface-container)',
              color: isScientific
                ? 'var(--m3-on-tertiary-container)'
                : 'var(--m3-primary)',
            }}
            title={isScientific ? 'Hide advanced symbols keys' : 'Show advanced symbols keys (calculus, trig, powers, prob, constants)'}
          >
            <OmniCalcLogo key={String(isScientific)} className="fx-turn w-4 h-4 sm:w-5 sm:h-5 shrink-0" />
            <span className="font-mono font-bold tracking-tight">{isScientific ? 'fx ON' : 'fx ADV'}</span>
          </button>

          <button
            onClick={() => handleInput('0')}
            className={KEY_DIGIT_LARGE}
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            0
          </button>
          <button
            onClick={() => handleInput('.')}
            className="h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] text-2xl sm:text-3xl md:text-4xl font-mono font-bold rounded-[16px] sm:rounded-[24px] md:rounded-[32px] m3-key flex items-center justify-center cursor-pointer active:scale-95 transition-transform"
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              color: 'var(--m3-on-surface)',
            }}
          >
            .
          </button>

          {/* Material 3 HERO Equals Button Pill */}
          <button
            onClick={handleEvaluate}
            className={`h-full w-full min-h-[40px] sm:min-h-[64px] md:min-h-[78px] lg:min-h-[92px] xl:min-h-[105px] text-2xl sm:text-3xl md:text-4xl font-bold rounded-[16px] sm:rounded-[24px] md:rounded-[32px] sm:rounded-full m3-key flex items-center justify-center gap-2 cursor-pointer transition-all duration-150 active:scale-95 ${
 isEqualsPressed ? 'scale-[0.93] brightness-125 shadow-[0_0_32px_6px_color-mix(in_srgb,var(--m3-primary)_85%,transparent)]' : ''
 }`}
            style={{
              backgroundColor: 'var(--m3-primary)',
              color: 'var(--m3-on-primary)',
            }}
          >
            <span>=</span>
            <CornerDownLeft className="w-5 h-5 sm:w-6 sm:h-6 opacity-75" />
          </button>
        </div>
      </div>
    </div>
  );
};
