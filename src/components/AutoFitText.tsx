import React, { useLayoutEffect, useRef, useState } from 'react';

interface AutoFitTextProps {
  text: string;
  /** Largest font size in px (used while the text fits on one line) */
  max: number;
  /** Smallest font size in px; below this the line scrolls sideways instead */
  min: number;
  className?: string;
  style?: React.CSSProperties;
}

/**
 * One line of text that is as large as possible: it shrinks smoothly as it gets longer
 * so the number never gets cut off, then grows back when digits are deleted.
 */
export const AutoFitText: React.FC<AutoFitTextProps> = ({ text, max, min, className = '', style }) => {
  const boxRef = useRef<HTMLDivElement>(null);
  const spanRef = useRef<HTMLSpanElement>(null);
  const [size, setSize] = useState<number>(max);

  useLayoutEffect(() => {
    const box = boxRef.current;
    const span = spanRef.current;
    if (!box || !span) return;

    const fit = () => {
      const available = box.clientWidth;
      if (available <= 0) return;
      span.style.fontSize = `${max}px`;
      const natural = span.offsetWidth;
      const next = natural > available ? Math.max(min, Math.floor((max * available) / natural)) : max;
      span.style.fontSize = `${next}px`;
      setSize(next);
      // If it still does not fit at the smallest size, show the end of the line (the newest digits)
      box.scrollLeft = box.scrollWidth;
    };

    fit();
    const observer = new ResizeObserver(fit);
    observer.observe(box);
    return () => observer.disconnect();
  }, [text, max, min]);

  return (
    <div ref={boxRef} className={`overflow-x-auto whitespace-nowrap no-scrollbar text-right ${className}`} style={style}>
      <span
        ref={spanRef}
        className="inline-block tabular-nums"
        style={{ fontSize: size, lineHeight: 1.12, transition: 'font-size 120ms var(--ease-emphasized)' }}
      >
        {text}
      </span>
    </div>
  );
};
