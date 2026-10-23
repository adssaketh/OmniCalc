import { AngleMode } from '../types';

export class MathEvaluator {
  /** The equation saved with `y = ...` (written in x). `y(4)` then gives its value at x = 4. */
  private static yDefinition: string | null = null;

  public static setYDefinition(def: string | null): void {
    this.yDefinition = def;
  }

  public static getYDefinition(): string | null {
    return this.yDefinition;
  }

  private static sanitizeExpression(expr: string): string {
    return expr
      .replace(/\bsgn\s*\(/gi, 'sign(')
      .replace(/×/g, '*')
      .replace(/÷/g, '/')
      .replace(/−/g, '-')
      .replace(/√\(/g, 'sqrt(')
      .replace(/√([0-9.a-zA-Zπe]+)/g, 'sqrt($1)')
      .replace(/³√\(/g, 'cbrt(')
      .replace(/³√([0-9.a-zA-Zπe]+)/g, 'cbrt($1)')
      .replace(/π/g, ' PI ')
      .replace(/\bhbar\b|ħ/g, ' 1.054571817e-34 ')
      .replace(/\bh\b/g, ' 6.62607015e-34 ')
      .replace(/\bc\b/g, ' 299792458 ')
      .replace(/\bG\b/g, ' 6.67430e-11 ')
      .replace(/\bqe\b|\bq_e\b/g, ' 1.602176634e-19 ')
      .replace(/\bme\b|\bm_e\b/g, ' 9.1093837e-31 ')
      .replace(/\bmp\b|\bm_p\b/g, ' 1.67262192e-27 ')
      .replace(/\bkB\b|\bk_B\b/g, ' 1.380649e-23 ')
      .replace(/\bNA\b|\bN_A\b/g, ' 6.02214076e23 ')
      .replace(/\beps0\b|ε₀|ε0/g, ' 8.8541878128e-12 ')
      .replace(/\bmu0\b|μ₀|μ0/g, ' 1.256637062e-6 ')
      .replace(/\bke\b/g, ' 8.9875517923e9 ')
      .replace(/\bmn\b|\bm_n\b/g, ' 1.67492749804e-27 ')
      .replace(/\bR\b/g, ' 8.314462618 ')
      .replace(/\bsigma\b|σ/g, ' 5.670374419e-8 ')
      .replace(/\batm\b/g, ' 101325 ')
      .replace(/\bau\b/g, ' 1.495978707e11 ')
      .replace(/\bg\b/g, ' 9.80665 ')
      .replace(/\be\b/g, ' E ')
      .replace(/φ/g, ' PHI ')
      .trim();
  }

  /**
   * Percent, the way phone calculators do it:
   *   50%          -> 0.5          200×15%  -> 30
   *   200+10%      -> 220          200−10%  -> 180   (adds / takes off a percentage of everything before it)
   * Remainder is no longer `%`; use `mod(17, 5)` or `17 mod 5`.
   */
  private static applyPercent(expr: string): string {
    if (!expr.includes('%')) return expr;
    let current = expr.trim();

    // Trailing "+ N%" or "− N%": N percent of the whole left-hand side
    const trailing = current.match(/^(.*[^+\-−×÷*\/^(,\s])\s*([+\-−])\s*(\d+(?:\.\d+)?)%$/);
    if (trailing) {
      const sign = trailing[2] === '+' ? '+' : '-';
      return this.applyPercent(`(${trailing[1]})×(1${sign}${trailing[3]}÷100)`);
    }

    // Any other "x%" means x / 100. A bracketed group is divided as a whole.
    for (let guard = 0; guard < 50; guard++) {
      const idx = current.indexOf('%');
      if (idx === -1) break;
      let start = idx;
      if (current[idx - 1] === ')') {
        let depth = 0;
        for (let i = idx - 1; i >= 0; i--) {
          if (current[i] === ')') depth++;
          else if (current[i] === '(') {
            depth--;
            if (depth === 0) {
              start = i;
              break;
            }
          }
        }
        if (start === idx) throw new Error('Mismatched parentheses');
      } else {
        const m = current.slice(0, idx).match(/(\d+(?:\.\d+)?|π|\be)$/);
        if (!m) throw new Error('Invalid syntax: % needs a number before it');
        start = idx - m[0].length;
      }
      current = `${current.slice(0, start)}(${current.slice(start, idx)}÷100)${current.slice(idx + 1)}`;
    }
    return current;
  }

  // Preprocess implicit multiplications like "2(3)" -> "2*(3)", "5sin(30)" -> "5*sin(30)"
  private static addImplicitMultiplication(tokens: string[]): string[] {
    const output: string[] = [];
    const isNumOrConst = (t: string) => /^(\d+(\.\d+)?([eE][+-]?\d+)?|PI|E|PHI)$/.test(t);
    const isCloseParen = (t: string) => t === ')';
    const isOpenParen = (t: string) => t === '(';
    const isFunc = (t: string) =>
      /^(sin|cos|tan|asin|acos|atan|sinh|cosh|tanh|asinh|acosh|atanh|sec|csc|cot|sech|csch|coth|ln|log|log2|exp|sqrt|cbrt|abs|round|floor|ceil|sign)$/i.test(t);

    for (let i = 0; i < tokens.length; i++) {
      const curr = tokens[i];
      output.push(curr);

      if (i < tokens.length - 1) {
        const next = tokens[i + 1];
        if (
          (isNumOrConst(curr) && (isOpenParen(next) || isFunc(next) || isNumOrConst(next))) ||
          (isCloseParen(curr) && (isOpenParen(next) || isNumOrConst(next) || isFunc(next))) ||
          (curr === '!' && (isOpenParen(next) || isNumOrConst(next) || isFunc(next)))
        ) {
          output.push('*');
        }
      }
    }
    return output;
  }

  // Tokenize math expression into tokens
  private static tokenize(expr: string): string[] {
    const raw = this.sanitizeExpression(expr);
    const regex =
      /\d+(\.\d+)?([eE][+-]?\d+)?|exp|PI|E|PHI|asinh|acosh|atanh|sech|csch|coth|sinh|cosh|tanh|asin|acos|atan|sec|csc|cot|sin|cos|tan|log2|log|ln|exp|cbrt|sqrt|round|floor|ceil|sign|abs|\+|-|\*|\/|\^|%|!|\(|\)/gi;
    const matches = raw.match(regex);
    if (!matches) return [];
    return this.addImplicitMultiplication(matches);
  }

  public static factorial(n: number): number {
    if (n < 0 || !Number.isInteger(n)) throw new Error('Factorial requires non-negative integer');
    if (n === 0 || n === 1) return 1;
    if (n > 170) return Infinity; // JS number overflow
    let res = 1;
    for (let i = 2; i <= n; i++) res *= i;
    return res;
  }

  public static permutations(n: number, r: number): number {
    if (n < 0 || r < 0 || !Number.isInteger(n) || !Number.isInteger(r) || r > n) {
      throw new Error('nPr requires integers with 0 <= r <= n');
    }
    let res = 1;
    for (let i = 0; i < r; i++) {
      res *= n - i;
    }
    return res;
  }

  public static combinations(n: number, r: number): number {
    if (n < 0 || r < 0 || !Number.isInteger(n) || !Number.isInteger(r) || r > n) {
      throw new Error('nCr requires integers with 0 <= r <= n');
    }
    if (r === 0 || r === n) return 1;
    const k = Math.min(r, n - r);
    let res = 1;
    for (let i = 1; i <= k; i++) {
      res = (res * (n - k + i)) / i;
    }
    return Math.round(res);
  }

  public static gcd(a: number, b: number): number {
    let x = Math.abs(Math.round(a));
    let y = Math.abs(Math.round(b));
    while (y !== 0) {
      const t = y;
      y = x % y;
      x = t;
    }
    return x;
  }

  public static lcm(a: number, b: number): number {
    const x = Math.round(a);
    const y = Math.round(b);
    if (x === 0 || y === 0) return 0;
    return Math.abs(x * y) / this.gcd(x, y);
  }

  // Numerical derivative d/dx f(x) evaluated at xVal using 5-point stencil
  public static numericalDerivative(
    funcExpr: string,
    xVal: number,
    angleMode: AngleMode = 'rad'
  ): number {
    // 1e-3 keeps round-off small (diff(x^2, 3) gives 6, not 6.00000000005); near zero the step shrinks
    // so points like x = 0.002 stay inside the domain of ln(x), sqrt(x) ...
    let h = 1e-3 * Math.max(1, Math.abs(xVal));
    if (xVal !== 0 && Math.abs(xVal) < 4 * h) h = Math.max(Math.abs(xVal) / 4, 1e-6);
    const f = (x: number) => this.evaluateFunction(funcExpr, x, angleMode);

    const f_plus_2h = f(xVal + 2 * h);
    const f_plus_h = f(xVal + h);
    const f_minus_h = f(xVal - h);
    const f_minus_2h = f(xVal - 2 * h);

    if (isNaN(f_plus_h) || isNaN(f_minus_h)) {
      // Fallback to one-sided forward difference
      const f_curr = f(xVal);
      const f_fwd = f(xVal + h);
      return (f_fwd - f_curr) / h;
    }

    return (-f_plus_2h + 8 * f_plus_h - 8 * f_minus_h + f_minus_2h) / (12 * h);
  }

  // Definite numerical integration using composite Simpson's 1/3 rule (N = 1000)
  public static numericalIntegration(
    funcExpr: string,
    a: number,
    b: number,
    angleMode: AngleMode = 'rad'
  ): number {
    if (a === b) return 0;
    const isReversed = a > b;
    const start = isReversed ? b : a;
    const end = isReversed ? a : b;

    const N = 1000; // Must be even
    const h = (end - start) / N;
    const f = (x: number) => this.evaluateFunction(funcExpr, x, angleMode);

    let sum = f(start) + f(end);
    for (let i = 1; i < N; i++) {
      const x = start + i * h;
      const fx = f(x);
      if (isNaN(fx)) throw new Error(`Integration error at x = ${x}`);
      sum += (i % 2 === 1 ? 4 : 2) * fx;
    }

    const result = (h / 3) * sum;
    return isReversed ? -result : result;
  }

  // Limit of f(x) as x -> a (two-sided). Looks at both sides at two distances: for a real limit the two
  // sides close in on each other and the average settles; a jump or a pole keeps them apart.
  public static numericalLimit(funcExpr: string, a: number, angleMode: AngleMode = 'rad'): number {
    const f = (x: number) => this.evaluateFunction(funcExpr, x, angleMode);
    const sides = (h: number) => [f(a - h), f(a + h)] as const;

    const [l1, r1] = sides(2e-3);
    const [l2, r2] = sides(1e-3);
    if (![l1, r1, l2, r2].every((v) => Number.isFinite(v))) {
      throw new Error('Limit does not exist (function is undefined near this point)');
    }

    const g1 = (l1 + r1) / 2;
    const g2 = (l2 + r2) / 2;
    const scale = Math.max(1, Math.abs(g2));
    const closing = Math.abs(l2 - r2) <= 0.75 * Math.abs(l1 - r1) + 1e-9 * scale;
    const settled = Math.abs(g2 - g1) <= 1e-3 * scale;

    if (closing && settled) {
      return (4 * g2 - g1) / 3; // Richardson extrapolation removes the O(h^2) error
    }

    // Not settling: both sides may run off to the same infinity (like 1/x^2 at 0)
    const [lb, rb] = sides(1e-7);
    if (Number.isFinite(lb) && Number.isFinite(rb) && Math.abs(lb) > 1e5 && Math.abs(rb) > 1e5 && Math.sign(lb) === Math.sign(rb)) {
      throw new Error(lb > 0 ? 'Limit is +∞ (grows without bound)' : 'Limit is −∞ (falls without bound)');
    }
    throw new Error('Limit does not exist (left and right values differ)');
  }

  // Finite series summation sum(f(x), a, b)
  public static numericalSummation(
    funcExpr: string,
    a: number,
    b: number,
    angleMode: AngleMode = 'rad'
  ): number {
    const start = Math.round(a);
    const end = Math.round(b);
    if (start > end) return 0;
    if (end - start > 100000) throw new Error('Summation range exceeds safety limit of 100,000 steps');

    let sum = 0;
    for (let k = start; k <= end; k++) {
      const val = this.evaluateFunction(funcExpr, k, angleMode);
      if (isNaN(val)) throw new Error(`Summation evaluation failed at x = ${k}`);
      sum += val;
    }
    return sum;
  }

  // Finite series product prod(f(x), a, b)
  public static numericalProduct(
    funcExpr: string,
    a: number,
    b: number,
    angleMode: AngleMode = 'rad'
  ): number {
    const start = Math.round(a);
    const end = Math.round(b);
    if (start > end) return 1;
    if (end - start > 50000) throw new Error('Product range exceeds safety limit of 50,000 steps');

    let prod = 1;
    for (let k = start; k <= end; k++) {
      const val = this.evaluateFunction(funcExpr, k, angleMode);
      if (isNaN(val)) throw new Error(`Product evaluation failed at x = ${k}`);
      prod *= val;
    }
    return prod;
  }

  // Pre-process multi-argument calculus and discrete functions
  private static preprocessMultiArgFunctions(expr: string, angleMode: AngleMode): string {
    let current = expr;

    // Convert infix "10 nCr 3" -> "nCr(10, 3)", "5 nPr 2" -> "nPr(5, 2)", "17 mod 5" -> "mod(17, 5)"
    current = current
      .replace(/([0-9.a-zA-Zπe)]+)\s*nCr\s*([0-9.a-zA-Zπe(]+)/gi, 'nCr($1, $2)')
      .replace(/([0-9.a-zA-Zπe)]+)\s*nPr\s*([0-9.a-zA-Zπe(]+)/gi, 'nPr($1, $2)')
      .replace(/([0-9.a-zA-Zπe)]+)\s*mod\s*([0-9.a-zA-Zπe(]+)/gi, 'mod($1, $2)')
      .replace(/rand\(\)/gi, () => Math.random().toString());

    const funcNames = [
      'diff',
      'integrate',
      'int',
      'sum',
      'prod',
      'nCr',
      'nPr',
      'gcd',
      'lcm',
      'mod',
      'root',
      'logb',
      'randInt',
      'y',
      'limit',
      'min',
      'max',
      'mean',
      'avg',
    ];

    let safety = 0;
    while (safety++ < 30) {
      // Find the first multi-arg function
      let foundIndex = -1;
      let matchedFunc = '';

      for (const name of funcNames) {
        const regex = new RegExp(`\\b${name}\\s*\\(`, 'i');
        const match = regex.exec(current);
        if (match && (foundIndex === -1 || match.index < foundIndex)) {
          foundIndex = match.index;
          matchedFunc = name.toLowerCase();
        }
      }

      if (foundIndex === -1) break;

      // Find matching closing parenthesis
      const openParenIdx = current.indexOf('(', foundIndex);
      let depth = 0;
      let closeParenIdx = -1;

      for (let i = openParenIdx; i < current.length; i++) {
        if (current[i] === '(') depth++;
        else if (current[i] === ')') {
          depth--;
          if (depth === 0) {
            closeParenIdx = i;
            break;
          }
        }
      }

      if (closeParenIdx === -1) break; // Incomplete expression, continue

      const argsStr = current.substring(openParenIdx + 1, closeParenIdx);

      // Split arguments by top-level commas
      const args: string[] = [];
      let currentArg = '';
      let parenDepth = 0;

      for (let i = 0; i < argsStr.length; i++) {
        const char = argsStr[i];
        if (char === '(') parenDepth++;
        else if (char === ')') parenDepth--;

        if (char === ',' && parenDepth === 0) {
          args.push(currentArg.trim());
          currentArg = '';
        } else {
          currentArg += char;
        }
      }
      if (currentArg.trim()) args.push(currentArg.trim());

      let result = 0;
      const fName = matchedFunc;

      if (fName === 'diff') {
        if (args.length < 2) throw new Error('diff requires: diff(function, x_value)');
        const fExpr = args[0];
        const xVal = this.evaluate(args[1], angleMode);
        result = this.numericalDerivative(fExpr, xVal, angleMode);
      } else if (fName === 'integrate' || fName === 'int') {
        if (args.length < 3) throw new Error('integrate requires: integrate(function, lower_limit, upper_limit)');
        const fExpr = args[0];
        const aVal = this.evaluate(args[1], angleMode);
        const bVal = this.evaluate(args[2], angleMode);
        result = this.numericalIntegration(fExpr, aVal, bVal, angleMode);
      } else if (fName === 'sum') {
        if (args.length < 3) throw new Error('sum requires: sum(function, start, end)');
        const fExpr = args[0];
        const aVal = this.evaluate(args[1], angleMode);
        const bVal = this.evaluate(args[2], angleMode);
        result = this.numericalSummation(fExpr, aVal, bVal, angleMode);
      } else if (fName === 'prod') {
        if (args.length < 3) throw new Error('prod requires: prod(function, start, end)');
        const fExpr = args[0];
        const aVal = this.evaluate(args[1], angleMode);
        const bVal = this.evaluate(args[2], angleMode);
        result = this.numericalProduct(fExpr, aVal, bVal, angleMode);
      } else if (fName === 'ncr') {
        if (args.length < 2) throw new Error('nCr requires: nCr(n, r)');
        const n = this.evaluate(args[0], angleMode);
        const r = this.evaluate(args[1], angleMode);
        result = this.combinations(n, r);
      } else if (fName === 'npr') {
        if (args.length < 2) throw new Error('nPr requires: nPr(n, r)');
        const n = this.evaluate(args[0], angleMode);
        const r = this.evaluate(args[1], angleMode);
        result = this.permutations(n, r);
      } else if (fName === 'gcd') {
        if (args.length < 2) throw new Error('gcd requires: gcd(a, b)');
        const a = this.evaluate(args[0], angleMode);
        const b = this.evaluate(args[1], angleMode);
        result = this.gcd(a, b);
      } else if (fName === 'lcm') {
        if (args.length < 2) throw new Error('lcm requires: lcm(a, b)');
        const a = this.evaluate(args[0], angleMode);
        const b = this.evaluate(args[1], angleMode);
        result = this.lcm(a, b);
      } else if (fName === 'mod') {
        if (args.length < 2) throw new Error('mod requires: mod(a, b)');
        const a = this.evaluate(args[0], angleMode);
        const b = this.evaluate(args[1], angleMode);
        result = ((a % b) + b) % b;
      } else if (fName === 'root') {
        if (args.length < 2) throw new Error('root requires: root(degree, x)');
        const deg = this.evaluate(args[0], angleMode);
        const val = this.evaluate(args[1], angleMode);
        if (deg === 0) throw new Error('0th root is undefined');
        result = Math.pow(val, 1 / deg);
      } else if (fName === 'logb') {
        if (args.length < 2) throw new Error('logb requires: logb(base, x)');
        const base = this.evaluate(args[0], angleMode);
        const val = this.evaluate(args[1], angleMode);
        result = Math.log(val) / Math.log(base);
      } else if (fName === 'y') {
        if (!this.yDefinition) throw new Error('No equation saved yet. Write one first, like y=x^2−5x+6, then press =');
        if (args.length < 1) throw new Error('y needs an x value: y(4)');
        const xVal = this.evaluate(args[0], angleMode);
        result = this.evaluateFunction(this.yDefinition, xVal, angleMode);
        if (Number.isNaN(result)) throw new Error(`y is not defined at x = ${xVal}`);
      } else if (fName === 'limit') {
        if (args.length < 3) throw new Error('limit requires: limit(function, x, approach_value)');
        // args[1] is the variable name (kept so the call reads naturally); args[2] is the point x approaches
        const aVal = this.evaluate(args[2], angleMode);
        result = this.numericalLimit(args[0], aVal, angleMode);
      } else if (fName === 'min' || fName === 'max' || fName === 'mean' || fName === 'avg') {
        if (args.length < 1) throw new Error(`${fName} needs at least one value`);
        const vals = args.map((a) => this.evaluate(a, angleMode));
        if (fName === 'min') result = Math.min(...vals);
        else if (fName === 'max') result = Math.max(...vals);
        else result = vals.reduce((sum, v) => sum + v, 0) / vals.length;
      } else if (fName === 'randint') {
        if (args.length < 2) throw new Error('randInt requires: randInt(min, max)');
        const min = Math.round(this.evaluate(args[0], angleMode));
        const max = Math.round(this.evaluate(args[1], angleMode));
        result = Math.floor(Math.random() * (max - min + 1)) + min;
      }

      const formattedVal = Math.abs(result) < 1e-12 ? '0' : result.toString();
      current = current.substring(0, foundIndex) + formattedVal + current.substring(closeParenIdx + 1);
    }

    return current;
  }

  // Shunting-Yard Parser to RPN
  private static toRPN(tokens: string[], angleMode: AngleMode): (string | number)[] {
    const output: (string | number)[] = [];
    const opStack: string[] = [];

    const precedence: Record<string, number> = {
      '+': 1,
      '-': 1,
      '*': 2,
      '/': 2,
      '%': 2,
      '^': 4,
      'u-': 5, // unary minus
      '!': 6,
    };

    const isRightAssociative = (op: string) => op === '^' || op === 'u-';

    const isFunc = (t: string) =>
      /^(sin|cos|tan|asin|acos|atan|sinh|cosh|tanh|asinh|acosh|atanh|sec|csc|cot|sech|csch|coth|ln|log|log2|exp|sqrt|cbrt|abs|round|floor|ceil|sign)$/i.test(t);

    let prevToken: string | null = null;

    for (let i = 0; i < tokens.length; i++) {
      let token = tokens[i];

      // Handle constants
      if (token === 'PI') {
        output.push(Math.PI);
        prevToken = token;
        continue;
      }
      if (token === 'E') {
        output.push(Math.E);
        prevToken = token;
        continue;
      }
      if (token === 'PHI') {
        output.push(1.618033988749895);
        prevToken = token;
        continue;
      }

      // Handle numbers (including scientific notation like 6.626e-34)
      if (/^\d+(\.\d+)?([eE][+-]?\d+)?$/i.test(token)) {
        const num = parseFloat(token);
        if (isNaN(num)) throw new Error(`Invalid number: ${token}`);
        output.push(num);
        prevToken = token;
        continue;
      }

      // Handle unary minus
      if (token === '-' && (prevToken === null || prevToken === '(' || '+-*/^%'.includes(prevToken))) {
        token = 'u-';
      }

      // Handle functions
      if (isFunc(token)) {
        opStack.push(token.toLowerCase());
        prevToken = token;
        continue;
      }

      // Handle factorial postfix
      if (token === '!') {
        output.push('!');
        prevToken = token;
        continue;
      }

      // Handle operators
      if (token in precedence) {
        while (
          opStack.length > 0 &&
          opStack[opStack.length - 1] !== '(' &&
          (isFunc(opStack[opStack.length - 1]) ||
            precedence[opStack[opStack.length - 1]] > precedence[token] ||
            (precedence[opStack[opStack.length - 1]] === precedence[token] && !isRightAssociative(token)))
        ) {
          output.push(opStack.pop()!);
        }
        opStack.push(token);
        prevToken = token;
        continue;
      }

      if (token === '(') {
        opStack.push('(');
        prevToken = token;
        continue;
      }

      if (token === ')') {
        while (opStack.length > 0 && opStack[opStack.length - 1] !== '(') {
          output.push(opStack.pop()!);
        }
        if (opStack.length === 0) {
          throw new Error('Mismatched parentheses');
        }
        opStack.pop(); // remove '('

        if (opStack.length > 0 && isFunc(opStack[opStack.length - 1])) {
          output.push(opStack.pop()!);
        }
        prevToken = token;
        continue;
      }

      throw new Error(`Unexpected token: ${token}`);
    }

    while (opStack.length > 0) {
      const top = opStack.pop()!;
      if (top === '(' || top === ')') {
        throw new Error('Mismatched parentheses');
      }
      output.push(top);
    }

    return output;
  }

  // Evaluate RPN expression
  private static evaluateRPN(rpn: (string | number)[], angleMode: AngleMode): number {
    const stack: number[] = [];

    const toRad = (val: number) => (angleMode === 'deg' ? (val * Math.PI) / 180 : val);
    const toAngle = (radVal: number) => (angleMode === 'deg' ? (radVal * 180) / Math.PI : radVal);

    for (const token of rpn) {
      if (typeof token === 'number') {
        stack.push(token);
      } else if (token === 'u-') {
        if (stack.length < 1) throw new Error('Invalid syntax');
        const a = stack.pop()!;
        stack.push(-a);
      } else if (token === '!') {
        if (stack.length < 1) throw new Error('Invalid syntax');
        const a = stack.pop()!;
        stack.push(this.factorial(a));
      } else if (['+', '-', '*', '/', '^', '%'].includes(token)) {
        if (stack.length < 2) throw new Error('Invalid syntax');
        const b = stack.pop()!;
        const a = stack.pop()!;
        let res = 0;
        switch (token) {
          case '+':
            res = a + b;
            break;
          case '-':
            res = a - b;
            break;
          case '*':
            res = a * b;
            break;
          case '/':
            if (b === 0) throw new Error('Division by zero');
            res = a / b;
            break;
          case '^':
            res = Math.pow(a, b);
            break;
          case '%':
            res = a % b;
            break;
        }
        stack.push(res);
      } else {
        // Unary functions
        if (stack.length < 1) throw new Error('Invalid function call');
        const a = stack.pop()!;
        let res = 0;
        switch (token) {
          case 'sin':
            res = Math.sin(toRad(a));
            if (Math.abs(res) < 1e-14) res = 0;
            break;
          case 'cos':
            res = Math.cos(toRad(a));
            if (Math.abs(res) < 1e-14) res = 0;
            break;
          case 'tan': {
            const rad = toRad(a);
            const cosVal = Math.cos(rad);
            if (Math.abs(cosVal) < 1e-14) throw new Error('Undefined (tan 90°)');
            res = Math.tan(rad);
            if (Math.abs(res) < 1e-14) res = 0;
            break;
          }
          case 'sec': {
            const cosVal = Math.cos(toRad(a));
            if (Math.abs(cosVal) < 1e-14) throw new Error('Undefined (sec 90°)');
            res = 1 / cosVal;
            break;
          }
          case 'csc': {
            const sinVal = Math.sin(toRad(a));
            if (Math.abs(sinVal) < 1e-14) throw new Error('Undefined (csc 0°)');
            res = 1 / sinVal;
            break;
          }
          case 'cot': {
            const tanVal = Math.tan(toRad(a));
            if (Math.abs(tanVal) < 1e-14) throw new Error('Undefined (cot 0°)');
            res = 1 / tanVal;
            break;
          }
          case 'asin':
            if (a < -1 || a > 1) throw new Error('Domain error (asin)');
            res = toAngle(Math.asin(a));
            break;
          case 'acos':
            if (a < -1 || a > 1) throw new Error('Domain error (acos)');
            res = toAngle(Math.acos(a));
            break;
          case 'atan':
            res = toAngle(Math.atan(a));
            break;
          case 'sinh':
            res = Math.sinh(a);
            break;
          case 'cosh':
            res = Math.cosh(a);
            break;
          case 'tanh':
            res = Math.tanh(a);
            break;
          case 'asinh':
            res = Math.asinh ? Math.asinh(a) : Math.log(a + Math.sqrt(a * a + 1));
            break;
          case 'acosh':
            if (a < 1) throw new Error('Domain error: acosh(x) requires x >= 1');
            res = Math.acosh ? Math.acosh(a) : Math.log(a + Math.sqrt(a * a - 1));
            break;
          case 'atanh':
            if (Math.abs(a) >= 1) throw new Error('Domain error: atanh(x) requires -1 < x < 1');
            res = Math.atanh ? Math.atanh(a) : 0.5 * Math.log((1 + a) / (1 - a));
            break;
          case 'sech':
            res = 1 / Math.cosh(a);
            break;
          case 'csch':
            if (a === 0) throw new Error('Division by zero in csch(0)');
            res = 1 / Math.sinh(a);
            break;
          case 'coth':
            if (a === 0) throw new Error('Division by zero in coth(0)');
            res = 1 / Math.tanh(a);
            break;
          case 'ln':
            if (a <= 0) throw new Error('Domain error (ln <= 0)');
            res = Math.log(a);
            break;
          case 'log':
            if (a <= 0) throw new Error('Domain error (log <= 0)');
            res = Math.log10(a);
            break;
          case 'log2':
            if (a <= 0) throw new Error('Domain error (log2 <= 0)');
            res = Math.log2(a);
            break;
          case 'exp':
            res = Math.exp(a);
            break;
          case 'sqrt':
            if (a < 0) throw new Error('Domain error (sqrt negative)');
            res = Math.sqrt(a);
            break;
          case 'cbrt':
            res = Math.cbrt(a);
            break;
          case 'abs':
            res = Math.abs(a);
            break;
          case 'round':
            res = Math.round(a);
            break;
          case 'floor':
            res = Math.floor(a);
            break;
          case 'ceil':
            res = Math.ceil(a);
            break;
          case 'sign':
            res = Math.sign(a);
            break;
          default:
            throw new Error(`Unknown function: ${token}`);
        }
        stack.push(res);
      }
    }

    if (stack.length !== 1) {
      throw new Error('Evaluation error');
    }

    return stack[0];
  }

  // Public evaluation method with multi-argument calculus preprocessor
  public static evaluate(expr: string, angleMode: AngleMode = 'deg'): number {
    const clean = this.applyPercent(expr.trim());
    if (!clean) return 0;

    // 1. Process multi-argument calculus and discrete functions (diff, integrate, sum, prod, nCr, nPr, gcd, lcm, mod, root)
    const preprocessed = this.preprocessMultiArgFunctions(clean, angleMode);

    // 2. Tokenize and evaluate standard expression
    const tokens = this.tokenize(preprocessed);
    if (tokens.length === 0) return 0;
    const rpn = this.toRPN(tokens, angleMode);
    return this.evaluateRPN(rpn, angleMode);
  }

  // Format numerical result cleanly avoiding floating point glitches (like 0.1 + 0.2)
  public static formatResult(val: number, precision: number = -1): string {
    if (!isFinite(val)) {
      if (isNaN(val)) return 'Error';
      return val > 0 ? 'Infinity' : '-Infinity';
    }

    // Fix precision if specific precision requested
    if (precision > 0) {
      return parseFloat(val.toFixed(precision)).toString();
    }

    // Auto cleanup floating point drift
    const rounded = parseFloat(val.toPrecision(12));
    if (Math.abs(rounded) < 1e-12 && Math.abs(rounded) > 0) {
      return rounded.toExponential(4);
    }
    if (Math.abs(rounded) >= 1e14) {
      return rounded.toExponential(6);
    }
    return rounded.toString();
  }

  // Evaluate for graphing f(x) or calculus kernels
  public static evaluateFunction(expr: string, xVal: number, angleMode: AngleMode = 'rad'): number {
    try {
      // Replace independent variable x safely without breaking function names e.g. "exp", "floor"
      const formattedX = `(${xVal})`;
      // (lookahead, so "x*x" and "2x" both work; a digit before x means implicit multiplication)
      const replaced = expr.replace(/(^|[^a-zA-Z_])x(?![a-zA-Z0-9_])/gi, `$1${formattedX}`);
      return this.evaluate(replaced, angleMode);
    } catch {
      return NaN;
    }
  }
}
