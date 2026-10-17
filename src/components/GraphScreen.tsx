import React, { useRef, useEffect, useState, useCallback } from 'react';
import { MathEvaluator } from '../engine/evaluator';
import { soundFx } from '../utils/audio';
import { useTheme } from '../hooks/useTheme';
import { ZoomIn, ZoomOut, RotateCcw, Crosshair } from 'lucide-react';

interface GraphScreenProps {
  soundEnabled: boolean;
  hapticEnabled: boolean;
}

export const GraphScreen: React.FC<GraphScreenProps> = ({
  soundEnabled,
  hapticEnabled,
}) => {
  const { currentTheme } = useTheme();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [expression, setExpression] = useState<string>('sin(x)');
  const [activeExpr, setActiveExpr] = useState<string>('sin(x)');

  // Viewport transformation: scale (pixels per mathematical unit) and origin offset
  const [scale, setScale] = useState<number>(40);
  const [origin, setOrigin] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [dragStart, setDragStart] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [mouseCoord, setMouseCoord] = useState<{ x: number; y: number } | null>(null);

  // Audio helper
  const playSound = (type: 'num' | 'op' | 'toggle' = 'num') => {
    if (soundEnabled) soundFx.playClick(type);
    if (hapticEnabled) soundFx.triggerHaptic();
  };

  // Canvas drawing routine
  const drawGraph = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const width = canvas.width;
    const height = canvas.height;

    // Resolve theme variables dynamically
    const isDark = document.documentElement.getAttribute('data-m3-mode') !== 'light';
    const compStyle = getComputedStyle(document.documentElement);
    const bgColor = compStyle.getPropertyValue('--m3-surface-container-lowest').trim() || (isDark ? '#090d16' : '#ffffff');
    const gridStroke = isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.07)';
    const textFill = isDark ? 'rgba(255, 255, 255, 0.45)' : 'rgba(0, 0, 0, 0.55)';
    const axisStroke = isDark ? 'rgba(255, 255, 255, 0.35)' : 'rgba(0, 0, 0, 0.35)';
    const curveStroke = compStyle.getPropertyValue('--m3-primary').trim() || (isDark ? '#a8c7fa' : '#0b57d0');

    // Clear background
    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, width, height);

    const ox = width / 2 + origin.x;
    const oy = height / 2 + origin.y;

    // Draw Grid Lines
    ctx.lineWidth = 1;
    ctx.strokeStyle = gridStroke;
    ctx.fillStyle = textFill;
    ctx.font = '10px "JetBrains Mono", monospace';

    // Step size based on scale
    const step = scale;

    // Vertical grid
    for (let x = ox % step; x < width; x += step) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();

      const unitVal = ((x - ox) / scale).toFixed(0);
      if (unitVal !== '0') {
        ctx.fillText(unitVal, x + 3, oy - 4);
      }
    }

    // Horizontal grid
    for (let y = oy % step; y < height; y += step) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();

      const unitVal = (-(y - oy) / scale).toFixed(0);
      if (unitVal !== '0') {
        ctx.fillText(unitVal, ox + 4, y - 3);
      }
    }

    // Primary Axes (X and Y)
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = axisStroke;

    // X Axis
    ctx.beginPath();
    ctx.moveTo(0, oy);
    ctx.lineTo(width, oy);
    ctx.stroke();

    // Y Axis
    ctx.beginPath();
    ctx.moveTo(ox, 0);
    ctx.lineTo(ox, height);
    ctx.stroke();

    // Plot Function Curve
    ctx.lineWidth = 2.5;
    ctx.strokeStyle = curveStroke;
    ctx.beginPath();

    let isDrawing = false;

    // Plot across canvas width in 1-pixel increments
    for (let px = 0; px <= width; px += 2) {
      const mathX = (px - ox) / scale;
      const mathY = MathEvaluator.evaluateFunction(activeExpr, mathX, 'rad');

      if (!isNaN(mathY) && isFinite(mathY)) {
        const py = oy - mathY * scale;

        // Clip huge vertical spikes (e.g. near asymptotes)
        if (py >= -100 && py <= height + 100) {
          if (!isDrawing) {
            ctx.moveTo(px, py);
            isDrawing = true;
          } else {
            ctx.lineTo(px, py);
          }
        } else {
          isDrawing = false;
        }
      } else {
        isDrawing = false;
      }
    }
    ctx.stroke();

    // Crosshair for cursor if mouse over
    if (mouseCoord) {
      const mx = mouseCoord.x;
      const my = mouseCoord.y;
      const cursorX = (mx - ox) / scale;
      const cursorY = MathEvaluator.evaluateFunction(activeExpr, cursorX, 'rad');

      if (!isNaN(cursorY) && isFinite(cursorY)) {
        const targetPy = oy - cursorY * scale;

        // Point on curve
        ctx.fillStyle = '#10b981';
        ctx.beginPath();
        ctx.arc(mx, targetPy, 4.5, 0, Math.PI * 2);
        ctx.fill();

        // Cross lines
        ctx.strokeStyle = isDark ? 'rgba(255, 255, 255, 0.2)' : 'rgba(0, 0, 0, 0.2)';
        ctx.lineWidth = 1;
        ctx.setLineDash([3, 3]);
        ctx.beginPath();
        ctx.moveTo(mx, 0);
        ctx.lineTo(mx, height);
        ctx.moveTo(0, targetPy);
        ctx.lineTo(width, targetPy);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }
  }, [activeExpr, origin, scale, mouseCoord]);

  // Handle Resize and Initial Draw
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      canvas.width = rect.width * window.devicePixelRatio;
      canvas.height = rect.height * window.devicePixelRatio;
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
      drawGraph();
    };

    resize();
    window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  }, [drawGraph]);

  // Redraw when state updates
  useEffect(() => {
    drawGraph();
  }, [drawGraph]);

  // Mouse pan handlers
  const handleMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    setIsDragging(true);
    setDragStart({ x: e.clientX - origin.x, y: e.clientY - origin.y });
  };

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    setMouseCoord({ x, y });

    if (isDragging) {
      setOrigin({
        x: e.clientX - dragStart.x,
        y: e.clientY - dragStart.y,
      });
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  // Mobile Touch pan handlers
  const handleTouchStart = (e: React.TouchEvent<HTMLCanvasElement>) => {
    if (e.touches.length === 1) {
      const touch = e.touches[0];
      setIsDragging(true);
      setDragStart({
        x: touch.clientX - origin.x,
        y: touch.clientY - origin.y,
      });
    }
  };

  const handleTouchMove = (e: React.TouchEvent<HTMLCanvasElement>) => {
    if (e.touches.length === 1) {
      const touch = e.touches[0];
      const canvas = canvasRef.current;
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const x = touch.clientX - rect.left;
      const y = touch.clientY - rect.top;

      setMouseCoord({ x, y });

      if (isDragging) {
        setOrigin({
          x: touch.clientX - dragStart.x,
          y: touch.clientY - dragStart.y,
        });
      }
    }
  };

  const handleTouchEnd = () => {
    setIsDragging(false);
  };

  const handleWheel = (e: React.WheelEvent<HTMLCanvasElement>) => {
    e.preventDefault();
    const zoomFactor = e.deltaY < 0 ? 1.15 : 0.85;
    setScale((s) => Math.min(250, Math.max(10, s * zoomFactor)));
  };

  const handlePlot = (e: React.FormEvent) => {
    e.preventDefault();
    playSound('op');
    setActiveExpr(expression);
  };

  const handleReset = () => {
    playSound('toggle');
    setScale(40);
    setOrigin({ x: 0, y: 0 });
  };

  const presets = [
    { label: 'sin(x)', expr: 'sin(x)' },
    { label: 'cos(x)', expr: 'cos(x)' },
    { label: 'tan(x)', expr: 'tan(x)' },
    { label: 'x²', expr: 'x^2' },
    { label: 'x³', expr: 'x^3' },
    { label: '√x', expr: 'sqrt(x)' },
    { label: '1/x', expr: '1/x' },
    { label: 'eˣ', expr: 'e^x' },
    { label: 'ln(x)', expr: 'ln(x)' },
  ];

  return (
    <div className="w-full max-w-4xl mx-auto flex flex-col items-center select-none pb-6">
      <div className="w-full relative bg-zinc-950/80 rounded-3xl p-5 sm:p-7 border border-zinc-800/90 shadow-2xl overflow-hidden backdrop-blur-xl flex flex-col gap-5 text-white">
        {/* Subtle Ambient Corner Glow */}
        <div
          className="absolute -top-16 -right-16 w-48 h-48 rounded-full blur-3xl pointer-events-none opacity-20"
          style={{ backgroundColor: currentTheme.accent }}
        />

        {/* Function Input Bar */}
        <form onSubmit={handlePlot} className="flex flex-col sm:flex-row items-center gap-2.5">
          <div className="relative flex-1 w-full bg-zinc-900/80 rounded-2xl border border-zinc-800/80 p-2.5 flex items-center transition-all focus-within:border-zinc-700">
            <span
              className="pl-2 pr-1.5 text-sm font-mono text-zinc-400 font-semibold"
            >
              f(x) =
            </span>
            <input
              type="text"
              value={expression}
              onChange={(e) => setExpression(e.target.value)}
              placeholder="e.g. sin(x) * 2"
              className="w-full bg-transparent font-mono text-base text-white outline-none"
            />
          </div>

          <div className="flex items-center gap-2 w-full sm:w-auto">
            <button
              type="submit"
              className="flex-1 sm:flex-none px-6 py-3 rounded-xl font-semibold text-xs transition-all shadow-md active:scale-95 whitespace-nowrap cursor-pointer text-white"
              style={{
                backgroundColor: currentTheme.accent,
              }}
            >
              Plot Function
            </button>
            <button
              type="button"
              onClick={handleReset}
              className="w-11 h-11 rounded-xl flex items-center justify-center bg-zinc-900 border border-zinc-800 text-zinc-400 hover:text-white transition-all active:scale-90 cursor-pointer"
              title="Reset View"
            >
              <RotateCcw className="w-4 h-4" />
            </button>
          </div>
        </form>

        {/* Quick Presets matching SWP chip style */}
        <div className="flex flex-wrap items-center gap-2 text-xs">
          <span className="text-zinc-400 text-xs font-medium mr-1">
            Function Presets:
          </span>
          {presets.map((p) => {
            const isPresetActive = activeExpr === p.expr;
            return (
              <button
                key={p.label}
                type="button"
                onClick={() => {
                  playSound('toggle');
                  setExpression(p.expr);
                  setActiveExpr(p.expr);
                }}
                className={`px-3 py-1.5 rounded-xl font-mono text-xs border transition-all active:scale-95 cursor-pointer ${
                  isPresetActive
                    ? 'bg-zinc-800 text-white border-zinc-600 shadow-sm'
                    : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/60 border-zinc-800'
                }`}
                style={
                  isPresetActive
                    ? { borderColor: currentTheme.accent, color: currentTheme.accent }
                    : {}
                }
              >
                {p.label}
              </button>
            );
          })}
        </div>

        {/* Canvas Plotter Container */}
        <div className="relative w-full h-[360px] sm:h-[420px] rounded-2xl overflow-hidden border border-zinc-800/90 bg-zinc-950 select-none">
          <canvas
            ref={canvasRef}
            onMouseDown={handleMouseDown}
            onMouseMove={handleMouseMove}
            onMouseUp={handleMouseUp}
            onTouchStart={handleTouchStart}
            onTouchMove={handleTouchMove}
            onTouchEnd={handleTouchEnd}
            onMouseLeave={() => {
              handleMouseUp();
              setMouseCoord(null);
            }}
            onWheel={handleWheel}
            className="w-full h-full cursor-grab active:cursor-grabbing block touch-none"
          />

          {/* Floating Controls Overlay */}
          <div
            className="absolute bottom-3 right-3 flex items-center gap-1.5 p-1 rounded-full backdrop-blur border"
            style={{
              backgroundColor: 'var(--m3-surface-container-high)',
              borderColor: 'var(--m3-outline-variant)',
            }}
          >
            <button
              onClick={() => {
                playSound('toggle');
                setScale((s) => Math.min(250, s * 1.25));
              }}
              className="p-2 rounded-full transition-colors active:scale-90 cursor-pointer"
              style={{ color: 'var(--m3-on-surface)' }}
              title="Zoom In"
            >
              <ZoomIn className="w-4 h-4" />
            </button>
            <button
              onClick={() => {
                playSound('toggle');
                setScale((s) => Math.max(10, s / 1.25));
              }}
              className="p-2 rounded-full transition-colors active:scale-90 cursor-pointer"
              style={{ color: 'var(--m3-on-surface)' }}
              title="Zoom Out"
            >
              <ZoomOut className="w-4 h-4" />
            </button>
          </div>

          {/* Coordinates Tooltip */}
          {mouseCoord && canvasRef.current && (
            <div
              className="absolute top-3 left-3 px-3 py-1.5 rounded-full backdrop-blur border font-mono text-xs flex items-center gap-2"
              style={{
                backgroundColor: 'var(--m3-surface-container-high)',
                borderColor: 'var(--m3-outline-variant)',
                color: 'var(--m3-on-surface)',
              }}
            >
              <Crosshair className="w-3.5 h-3.5" style={{ color: 'var(--m3-primary)' }} />
              <span>
                x: {(((mouseCoord.x - (canvasRef.current.clientWidth / 2 + origin.x)) / scale)).toFixed(2)}
              </span>
              <span>·</span>
              <span>
                y: {MathEvaluator.evaluateFunction(
                  activeExpr,
                  (mouseCoord.x - (canvasRef.current.clientWidth / 2 + origin.x)) / scale,
                  'rad'
                ).toFixed(2)}
              </span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
