import React, { useMemo, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';
import { ArrowLeft, ChevronDown, Play } from 'lucide-react';
import { AngleMode } from '../types';
import { MathEvaluator } from '../engine/evaluator';
import { GUIDE_QUICK_START, GUIDE_SECTIONS, GUIDE_TIPS, GuideExample, GuideSection } from '../guideContent';
import { NavIcon } from './NavIcons';
import { Sheet } from './Sheet';
import { spring } from '../motion';

interface GuideSheetProps {
  isOpen: boolean;
  onClose: () => void;
  angleMode: AngleMode;
  /** Loads an example into the calculator (and switches DEG / RAD when the example needs it) */
  onTryExample: (expr: string, angle?: AngleMode) => void;
}

interface ExampleResult {
  text: string;
  isError: boolean;
  /** Show the text as is, without the "= " in front */
  plain?: boolean;
}

/** The answer is computed by the real calculator engine, so the guide always matches the calculator. */
function runExample(ex: GuideExample): ExampleResult {
  // Defining an equation is not a calculation: just show what will be saved
  if (/^y\s*=/i.test(ex.expr)) return { text: 'Saved. Now type an x value and press =', isError: false, plain: true };
  // Examples that call y(x) use their own equation, then put the user's saved one back
  const previous = MathEvaluator.getYDefinition();
  try {
    if (ex.setup) MathEvaluator.setYDefinition(ex.setup);
    const value = MathEvaluator.evaluate(ex.expr, ex.angle ?? 'deg');
    return { text: MathEvaluator.formatResult(value, -1), isError: false };
  } catch (err) {
    return { text: err instanceof Error ? err.message : 'Error', isError: true };
  } finally {
    if (ex.setup) MathEvaluator.setYDefinition(previous);
  }
}

const StepList: React.FC<{ steps: string[] }> = ({ steps }) => (
  <ol className="space-y-2">
    {steps.map((step, i) => (
      <li key={step} className="guide-step flex items-start gap-3" style={{ animationDelay: `${i * 45}ms` }}>
        <span
          className="w-6 h-6 rounded-full text-[11px] font-bold flex items-center justify-center shrink-0 mt-px"
          style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}
        >
          {i + 1}
        </span>
        <span className="text-[13px] leading-snug" style={{ color: 'var(--m3-on-surface)' }}>
          {step}
        </span>
      </li>
    ))}
  </ol>
);

const ExampleRow: React.FC<{
  example: GuideExample;
  result: ExampleResult;
  angleMode: AngleMode;
  onTry: () => void;
}> = ({ example, result, angleMode, onTry }) => {
  const switches = example.angle !== undefined && example.angle !== angleMode;
  return (
    <div className="rounded-[20px] p-3" style={{ backgroundColor: 'var(--m3-surface-container-high)' }}>
      <div className="flex items-start gap-2">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5 flex-wrap">
            <span className="text-[15px] font-semibold break-all select-text" style={{ color: 'var(--m3-on-surface)' }}>
              {example.expr}
            </span>
            {example.angle && (
              <span
                className="text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                style={{ backgroundColor: 'var(--m3-tertiary-container)', color: 'var(--m3-on-tertiary-container)' }}
              >
                {example.angle.toUpperCase()}
              </span>
            )}
          </div>
          <div
            className="text-sm font-bold mt-0.5 break-words"
            style={{ color: result.isError ? 'var(--m3-error)' : 'var(--m3-primary)' }}
          >
            {result.isError || result.plain ? result.text : `= ${result.text}`}
          </div>
          <div className="text-[11.5px] mt-0.5 leading-snug" style={{ color: 'var(--m3-on-surface-variant)' }}>
            {example.note}
          </div>
        </div>
        <button
          type="button"
          onClick={onTry}
          className="shrink-0 h-9 pl-2.5 pr-3 rounded-full text-xs font-semibold flex items-center gap-1 cursor-pointer active:scale-90 transition-transform"
          style={{ backgroundColor: 'var(--m3-primary)', color: 'var(--m3-on-primary)' }}
          title={switches ? `Loads this example and switches to ${example.angle?.toUpperCase()}` : 'Load this example into the calculator'}
        >
          <Play className="w-3.5 h-3.5" fill="currentColor" />
          Try
        </button>
      </div>
      {switches && (
        <div className="text-[10.5px] mt-1.5" style={{ color: 'var(--m3-on-surface-variant)' }}>
          Switches the calculator to {example.angle?.toUpperCase()}.
        </div>
      )}
    </div>
  );
};

const SectionCard: React.FC<{
  section: GuideSection;
  open: boolean;
  onToggle: () => void;
  angleMode: AngleMode;
  onTry: (expr: string, angle?: AngleMode) => void;
}> = ({ section, open, onToggle, angleMode, onTry }) => {
  // Only evaluated once the card is opened (integrals take a few milliseconds each)
  const results = useMemo(() => (open ? section.examples.map(runExample) : []), [open, section]);

  return (
    <div className="rounded-[28px] overflow-hidden" style={{ backgroundColor: 'var(--m3-surface-container)' }}>
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        className="w-full min-h-[64px] px-4 py-3 flex items-center gap-3.5 text-left cursor-pointer active:scale-[0.99] transition-transform"
      >
        <span
          className="w-12 h-12 rounded-2xl flex items-center justify-center shrink-0 text-[15px] font-bold tracking-tight"
          style={{
            backgroundColor: open ? 'var(--m3-primary)' : 'var(--m3-surface-container-high)',
            color: open ? 'var(--m3-on-primary)' : 'var(--m3-primary)',
            transition: 'background-color 250ms var(--ease-emphasized), color 250ms var(--ease-emphasized)',
          }}
        >
          {section.badge}
        </span>
        <span className="min-w-0 flex-1">
          <span className="block font-semibold text-sm leading-snug">{section.title}</span>
          {!open && (
            <span className="block text-[11.5px] line-clamp-1" style={{ color: 'var(--m3-on-surface-variant)' }}>
              {section.summary}
            </span>
          )}
        </span>
        <motion.span animate={{ rotate: open ? 180 : 0 }} transition={spring} style={{ color: 'var(--m3-on-surface-variant)' }}>
          <ChevronDown className="w-5 h-5" />
        </motion.span>
      </button>

      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            key="body"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ height: spring, opacity: { duration: 0.2 } }}
            style={{ overflow: 'hidden' }}
          >
            <div className="px-4 pb-4 space-y-3.5">
              <p className="text-[13px] leading-relaxed" style={{ color: 'var(--m3-on-surface-variant)' }}>
                {section.summary}
              </p>

              {(section.where || section.syntax) && (
                <div className="flex flex-col gap-1.5">
                  {section.where && (
                    <div className="text-xs">
                      <span className="font-bold" style={{ color: 'var(--m3-primary)' }}>
                        Find it:{' '}
                      </span>
                      {section.where}
                    </div>
                  )}
                  {section.syntax && (
                    <div className="text-xs">
                      <span className="font-bold" style={{ color: 'var(--m3-primary)' }}>
                        Pattern:{' '}
                      </span>
                      <span
                        className="inline-block px-2 py-0.5 rounded-lg font-semibold break-all"
                        style={{ backgroundColor: 'var(--m3-surface-container-high)' }}
                      >
                        {section.syntax}
                      </span>
                    </div>
                  )}
                </div>
              )}

              {section.steps && <StepList steps={section.steps} />}

              <div className="space-y-2">
                <div className="text-[11px] font-bold tracking-wider uppercase" style={{ color: 'var(--m3-primary)' }}>
                  Examples
                </div>
                {section.examples.map((ex, i) => (
                  <ExampleRow
                    key={ex.expr}
                    example={ex}
                    result={results[i] ?? { text: '', isError: false }}
                    angleMode={angleMode}
                    onTry={() => onTry(ex.load ?? ex.expr, ex.angle)}
                  />
                ))}
              </div>

              {section.tips && (
                <ul className="space-y-1.5">
                  {section.tips.map((tip) => (
                    <li key={tip} className="text-xs leading-snug flex gap-2" style={{ color: 'var(--m3-on-surface-variant)' }}>
                      <span style={{ color: 'var(--m3-tertiary)' }}>●</span>
                      <span>{tip}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

/** Beginner-friendly "how to use" sheet, opened from the book icon next to the sound icon. */
export const GuideSheet: React.FC<GuideSheetProps> = ({ isOpen, onClose, angleMode, onTryExample }) => {
  const [openId, setOpenId] = useState<string | null>('diff');

  return (
    <Sheet
      isOpen={isOpen}
      onClose={onClose}
      label="User guide"
      widthClass="sm:max-w-2xl"
      className="h-[92vh] sm:h-[88vh] sm:max-h-[880px]"
    >
      <div className="px-4 sm:px-5 py-3 flex items-center gap-2 shrink-0">
        <button
          onClick={onClose}
          className="w-11 h-11 rounded-full flex items-center justify-center cursor-pointer active:scale-90 transition-transform"
          aria-label="Close guide"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div className="min-w-0 flex-1">
          <h1 className="text-xl font-bold tracking-tight leading-tight">How to use OmniCalc</h1>
          <p className="text-xs" style={{ color: 'var(--m3-on-surface-variant)' }}>
            Tap a topic. Every example has a Try button.
          </p>
        </div>
        <span
          className="w-11 h-11 rounded-2xl flex items-center justify-center shrink-0"
          style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}
        >
          <NavIcon id="guide" active size={22} />
        </span>
      </div>

      <div
        className="flex-1 overflow-y-auto min-h-0 px-4 sm:px-5 pt-1 pb-6 space-y-3"
        style={{
          WebkitMaskImage: 'linear-gradient(to bottom, transparent 0, #000 12px, #000 calc(100% - 22px), transparent 100%)',
          maskImage: 'linear-gradient(to bottom, transparent 0, #000 12px, #000 calc(100% - 22px), transparent 100%)',
        }}
      >
        <div className="rounded-[28px] p-4" style={{ backgroundColor: 'var(--m3-primary-container)', color: 'var(--m3-on-primary-container)' }}>
          <div className="text-xs font-bold tracking-wider uppercase mb-2 opacity-80">Quick start</div>
          <ul className="space-y-1.5">
            {GUIDE_QUICK_START.map((line) => (
              <li key={line} className="text-[13px] leading-snug flex gap-2">
                <span className="opacity-60">●</span>
                <span>{line}</span>
              </li>
            ))}
          </ul>
        </div>

        {GUIDE_SECTIONS.map((section) => (
          <SectionCard
            key={section.id}
            section={section}
            open={openId === section.id}
            onToggle={() => setOpenId((prev) => (prev === section.id ? null : section.id))}
            angleMode={angleMode}
            onTry={onTryExample}
          />
        ))}

        <div className="rounded-[28px] p-4" style={{ backgroundColor: 'var(--m3-surface-container)' }}>
          <div className="text-xs font-bold tracking-wider uppercase mb-2" style={{ color: 'var(--m3-primary)' }}>
            Good to know
          </div>
          <ul className="space-y-1.5">
            {GUIDE_TIPS.map((tip) => (
              <li key={tip} className="text-[13px] leading-snug flex gap-2" style={{ color: 'var(--m3-on-surface-variant)' }}>
                <span style={{ color: 'var(--m3-tertiary)' }}>●</span>
                <span>{tip}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </Sheet>
  );
};
