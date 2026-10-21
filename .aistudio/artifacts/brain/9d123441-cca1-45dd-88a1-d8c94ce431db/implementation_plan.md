# Full-Fledged Scientific Calculator & Dynamic Press-Only Equals Glow

Deliver a comprehensive scientific mathematics suite inside OmniCalc's advanced section (`fx ADV`) with categorized tabs for Calculus, Trigonometry & Hyperbolics, Powers & Roots, Probability & Discrete math, and Universal Constants, while replacing the permanent glow on the equals button with a high-tactile dynamic press-only glow.

## User Review & Critical Decisions

> [!IMPORTANT]
> **Confirmed from User Feedback:**
> - **Equals Glow**: Remove the permanent ambient glow from the `=` button; trigger the luminous glow strictly while the button is actively pressed (`active:scale-95 active:shadow-[...]`).
> - **Advanced Mathematics Scope**: Incorporate calculus (numerical derivative $\frac{d}{dx}$, definite integral $\int_a^b$, summation $\sum$, and product $\prod$), full hyperbolic and inverse trigonometric functions ($\text{asinh}, \text{acosh}, \text{atanh}, \sec, \csc, \cot$), advanced powers and arbitrary roots ($\sqrt[y]{x}, \sqrt[3]{x}, x^2, x^3, x^{-1}, 10^x, 2^x$), and discrete/probability operations ($nPr, nCr, x!, \text{gcd}, \text{lcm}, \text{mod}, \text{rand}$).
> - **Layout Structure**: Organize the advanced keypad into clean, dedicated category tabs inside the collapsible drawer so users can instantly switch domains without clutter.

---

## 1. Overview & Core Concept

- **What It Does**: Upgrades OmniCalc from a standard/basic scientific calculator into a professional engineering and collegiate-grade scientific computing environment matching modern physical calculators (e.g. Casio fx-991EX, TI-84 Plus, HP Prime).
- **Target Audience**: Students, scientists, engineers, and financial professionals who need calculus tools, high-precision trigonometry, probability calculations, and physical constants in their daily workflows.
- **Key Value**: Everything is available right inside the calculator keypad without needing to navigate away or open separate tools.

---

## 2. User Experience & Visual Design

### A. Dynamic Press-Only Equals Glow
- **Default State**: Clean, solid Material 3 primary key pill (`var(--m3-primary)`) with crisp hairline outline and zero ambient glow or shadow blur.
- **Pressed State (`:active`)**: Luminous energetic pop burst (`box-shadow: 0 0 24px 4px var(--m3-primary)`), subtle tactile inward scale (`scale-[0.96]`), and instant click audio + haptic pulse.

### B. Categorized Advanced (`fx ADV`) Drawer
A sleek tabbed sub-header sitting at the top of the expandable advanced drawer:
1. **Calculus (`d/dx, ∫, ∑, ∏`)**:
   - $\frac{d}{dx}$: Numerical central-difference derivative $\frac{f(x+h) - f(x-h)}{2h}$.
   - $\int_a^b$: Definite numerical integration using adaptive composite Simpson's 1/3 and Gauss-Kronrod quadrature.
   - $\sum_{n=a}^b$: Finite series summation.
   - $\prod_{n=a}^b$: Finite series product.
   - Variable token $x$ for expressions.
2. **Trigonometry & Hyperbolics**:
   - Direct: $\sin, \cos, \tan, \sec, \csc, \cot$.
   - Inverses: $\sin^{-1}, \cos^{-1}, \tan^{-1}$.
   - Hyperbolic: $\sinh, \cosh, \tanh, \text{sech}, \text{csch}, \text{coth}$.
   - Inverse Hyperbolic: $\sinh^{-1}, \cosh^{-1}, \tanh^{-1}$.
   - Angle conversion: DEG, RAD, GRAD.
3. **Powers & Roots**:
   - Powers: $x^2, x^3, x^y, 10^x, 2^x, e^x$.
   - Roots: $\sqrt{x}, \sqrt[3]{x}, \sqrt[y]{x}$ (arbitrary root).
   - Reciprocal: $x^{-1}$, percent $\%$, absolute $|x|$.
   - Logarithms: $\ln(x), \log_{10}(x), \log_2(x), \log_b(x)$.
4. **Probability & Discrete**:
   - Permutations $nPr(n, r) = \frac{n!}{(n-r)!}$.
   - Combinations $nCr(n, r) = \frac{n!}{r!(n-r)!}$.
   - Factorial $x!$, Modulo $A \pmod B$.
   - Number Theory: $\text{gcd}(a, b)$, $\text{lcm}(a, b)$, $\text{floor}(x)$, $\text{ceil}(x)$, $\text{round}(x)$.
   - Random: $\text{rand}()$ (float $0 \dots 1$), $\text{randInt}(a, b)$.
5. **Universal Constants**:
   - Mathematical: $\pi, e, \phi$ (Golden ratio).
   - Physical: $c$ (light), $h$ (Planck), $\hbar$, $G$ (gravitation), $k_B$ (Boltzmann), $N_A$ (Avogadro), $q_e$ (elementary charge), $m_e$ (electron mass), $g$ (standard gravity).

---

## 3. Key Product Decisions & Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      CalculatorScreen                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Display: Question / Live Answer / Angle & History     │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Advanced Drawer (Collapsible via fx ADV)              │  │
│  │  Tabs: [Calculus] [Trig & Hyp] [Powers] [Prob] [Const]│  │
│  │  Interactive Function Grid (4-6 columns, squircle)    │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Primary Keypad: Numbers & Operations                  │  │
│  │ Equals (=) Pill: Clean flat -> Glow strictly on press │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 MathEvaluator Engine                        │
│  • Tokenizer & Shunting-Yard Parser                         │
│  • Extended Grammar: multi-arg functions nCr, nPr, gcd, lcm │
│  • Numerical Calculus Engine:                               │
│      - diff(expr, xVal)                                     │
│      - integrate(expr, lower, upper)                        │
│      - sum(expr, start, end)                                │
│      - prod(expr, start, end)                               │
└─────────────────────────────────────────────────────────────┘
```

- **Decision 1: Calculus Syntax & Evaluation Model**:
  - Functions are entered cleanly as `diff(x^2, 3)` (evaluates to $6$), `integrate(x^2, 0, 3)` (evaluates to $9$), `sum(x, 1, 10)` (evaluates to $55$), and `nCr(10, 3)` (evaluates to $120$).
  - When the user presses the $\int$ or $\frac{d}{dx}$ button, OmniCalc inserts the ready-to-fill template so users don't have to guess syntax.
- **Decision 2: Elimination of Persistent Equals Glow**:
  - Remove `.m3-pop-glow` from the static equals button classes in `CalculatorScreen.tsx`.
  - Add active state shadow classes: `active:shadow-[0_0_24px_4px_var(--m3-primary)] active:brightness-110 active:scale-[0.96]`.

---

## 4. Execution Steps

1. **Update `src/engine/evaluator.ts`**:
   - Add multi-parameter function evaluation to Shunting-Yard / RPN parser (`diff`, `integrate`, `sum`, `prod`, `nCr`, `nPr`, `gcd`, `lcm`, `mod`, `root`, `logb`).
   - Implement accurate numerical differentiation (step $h = 10^{-6}$ with 5-point stencil) and numerical integration (adaptive composite Simpson's rule with safety iteration guards).
   - Support extended hyperbolic inverses ($\text{asinh}, \text{acosh}, \text{atanh}$) and reciprocal trigs ($\sec, \csc, \cot$).
2. **Update `src/components/CalculatorScreen.tsx`**:
   - Replace always-on `.m3-pop-glow` on the equals button with active-press glow.
   - Redesign the Advanced Drawer with five clean category tabs:
     `Calculus`, `Trig & Hyp`, `Powers & Roots`, `Probability`, and `Constants`.
   - Implement function template insertion (e.g. tapping $\int$ inserts `integrate(`, tapping $d/dx$ inserts `diff(`).
3. **Verification**:
   - Run `compile_applet` and `lint_applet` to guarantee complete type-safety and pristine builds.
   - Verify sample calculus problems ($\frac{d}{dx}(x^3)|_{x=2} = 12$, $\int_0^{\pi}\sin(x)dx = 2$, $\sum_{x=1}^5 x = 15$) and discrete combinations ($10\text{C}3 = 120$).
