// GENERATED FILE - DO NOT EDIT.
// Source of truth: src/guideContent.ts (GUIDE_QUICK_START, GUIDE_SECTIONS, GUIDE_TIPS).
// Regenerate with: npx tsx flutter_app/tools/gen_guide.ts

import '../../engine/types.dart';

/// `GuideExample`.
class GuideExample {
  const GuideExample({required this.expr, required this.note, this.angle, this.setup, this.load});

  /// Exactly what is typed into the calculator (uses the keypad symbols × ÷ −).
  final String expr;
  final String note;

  /// Angle unit the example needs; "Try" switches to it.
  final AngleMode? angle;

  /// Equation (written in x) saved before this example is evaluated, for examples that call y(x).
  final String? setup;

  /// What the Try button types instead of [expr].
  final String? load;
}

/// `GuideSection`.
class GuideSection {
  const GuideSection({
    required this.id,
    required this.badge,
    required this.title,
    required this.summary,
    this.where,
    this.syntax,
    this.steps,
    required this.examples,
    this.tips,
  });

  final String id;
  final String badge;
  final String title;
  final String summary;
  final String? where;
  final String? syntax;
  final List<String>? steps;
  final List<GuideExample> examples;
  final List<String>? tips;
}

const List<String> kGuideQuickStart = <String>[
  'Tap numbers and an operator (+ − × ÷), then press = to see the answer.',
  'The big display at the top stays in view while you scroll the keys below it.',
  'Tap fx ADV (bottom-left of the keypad) to open the advanced keys. Tap fx ON or Hide to close them.',
  'Tap the DEG / RAD badge on the display to switch between degrees and radians.',
];

const List<GuideSection> kGuideSections = <GuideSection>[
  GuideSection(
    id: 'basics',
    badge: '+ −',
    title: 'Everyday calculations',
    summary: 'Normal arithmetic works the way you write it. Brackets and the order of operations are handled for you.',
    where: null,
    syntax: null,
    steps: <String>[
      'Type the numbers and operators in order.',
      'Use the ( ) key for brackets. It opens a bracket, and closes it when one is waiting.',
      'Press = for the answer. Any bracket you left open is closed for you.',
      'AC clears everything. The ⌫ key removes the last step, and a whole function name like sin( at once.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: '12×8+4', note: 'Multiplication is done before addition', angle: null, setup: null, load: null),
      GuideExample(expr: '(2+3)×4', note: 'Brackets go first', angle: null, setup: null, load: null),
      GuideExample(expr: '200×15%', note: '15% of 200', angle: null, setup: null, load: null),
      GuideExample(expr: '200+10%', note: 'Adds 10% of 200 to 200, like a shop discount or tax calculation', angle: null, setup: null, load: null),
      GuideExample(expr: '17 mod 5', note: 'For the remainder after dividing, use mod (fx ADV → Probability)', angle: null, setup: null, load: null),
    ],
    tips: <String>[
      'Tap Recents at the bottom to reuse an earlier calculation.',
    ],
  ),
  GuideSection(
    id: 'diff',
    badge: 'd/dx',
    title: 'Differentiation',
    summary: 'Finds how steeply a function is rising or falling at one point (its slope). The answer is a number, not a formula.',
    where: 'fx ADV → Calculus → d/dx',
    syntax: 'diff(function, point)',
    steps: <String>[
      'Tap d/dx. diff( appears in the display.',
      'Write your function using the x key, for example x then x² to get x^2.',
      'Tap the comma key, then type the point where you want the slope.',
      'Tap ( ) to close the bracket and press =.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: 'diff(x^2, 3)', note: 'Slope of x² at x = 3. The rule 2x gives 6.', angle: null, setup: null, load: null),
      GuideExample(expr: 'diff(x^3, 2)', note: 'Slope of x³ at x = 2. The rule 3x² gives 12.', angle: null, setup: null, load: null),
      GuideExample(expr: 'diff(sqrt(x), 4)', note: 'Slope of √x at x = 4', angle: null, setup: null, load: null),
      GuideExample(expr: 'diff(sin(x), 0)', note: 'Slope of sin(x) at 0. Use RAD for trig.', angle: AngleMode.rad, setup: null, load: null),
    ],
    tips: <String>[
      'The d/dx(x²) key types diff(x^2, for you. Just add the point.',
      'With trig functions, switch to RAD first. In DEG mode the slope is measured per degree.',
    ],
  ),
  GuideSection(
    id: 'integrate',
    badge: '∫',
    title: 'Integration',
    summary: 'Adds up the area under a curve between two points (a definite integral). The answer is a number.',
    where: 'fx ADV → Calculus → ∫ dx',
    syntax: 'integrate(function, from, to)',
    steps: <String>[
      'Tap ∫ dx. integrate( appears.',
      'Write the function using the x key.',
      'Tap the comma key, type the start value, comma again, then the end value.',
      'Tap ( ) to close the bracket and press =.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: 'integrate(x^2, 0, 3)', note: 'Area under x² from 0 to 3', angle: null, setup: null, load: null),
      GuideExample(expr: 'integrate(x, 0, 4)', note: 'A triangle: ½ × 4 × 4 = 8', angle: null, setup: null, load: null),
      GuideExample(expr: 'integrate(1÷x, 1, e)', note: 'Area under 1/x from 1 to e', angle: null, setup: null, load: null),
      GuideExample(expr: 'integrate(sin(x), 0, π)', note: 'One arch of sin(x). Use RAD for trig.', angle: AngleMode.rad, setup: null, load: null),
    ],
    tips: <String>[
      'Swap the two limits and the answer changes sign.',
      'Get π and e from the Constants tab.',
    ],
  ),
  GuideSection(
    id: 'sum',
    badge: 'Σ Π',
    title: 'Sum and product',
    summary: 'Σ adds f(x) for every whole number from a start to an end. Π multiplies them instead.',
    where: 'fx ADV → Calculus → ∑ and ∏',
    syntax: 'sum(function, start, end)   prod(function, start, end)',
    steps: <String>[
      'Tap ∑ (or ∏). sum( appears.',
      'Write what to add, using x as the counter.',
      'Comma, then the first value of x, comma, then the last value.',
      'Close the bracket and press =.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: 'sum(x^2, 1, 5)', note: '1² + 2² + 3² + 4² + 5²', angle: null, setup: null, load: null),
      GuideExample(expr: 'sum(x, 1, 100)', note: 'Add every number from 1 to 100', angle: null, setup: null, load: null),
      GuideExample(expr: 'prod(x, 1, 5)', note: '1 × 2 × 3 × 4 × 5, which is 5 factorial', angle: null, setup: null, load: null),
    ],
    tips: <String>[
      'The ∑(x) and ∏(x) formula keys type the start of the pattern for you.',
    ],
  ),
  GuideSection(
    id: 'limit',
    badge: 'lim',
    title: 'Limits',
    summary: 'Shows the value a function is heading toward as x gets closer to a point, even if the point itself breaks it.',
    where: 'fx ADV → Calculus → lim',
    syntax: 'limit(function, x, point)',
    steps: <String>[
      'Tap lim. limit( appears.',
      'Write the function using the x key.',
      'Comma, the x key, comma, then the point x approaches.',
      'Close the bracket and press =.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: 'limit((x^2−1)÷(x−1), x, 1)', note: 'Plugging in 1 gives 0÷0, but the limit is 2', angle: null, setup: null, load: null),
      GuideExample(expr: 'limit(sin(x)÷x, x, 0)', note: 'A classic: it approaches 1. Use RAD.', angle: AngleMode.rad, setup: null, load: null),
      GuideExample(expr: 'limit(1÷x, x, 0)', note: 'The two sides disagree, so you get an explanation instead', angle: null, setup: null, load: null),
    ],
    tips: <String>[
      'Limits are found numerically from both sides. If they do not meet, you get a message instead of a number.',
    ],
  ),
  GuideSection(
    id: 'equation',
    badge: 'y=',
    title: 'Equations with y (quadratics and more)',
    summary: 'Write an equation like y = x² − 5x + 6 once, then type any x and get y. Works for any formula in x.',
    where: 'fx ADV → Calculus → y',
    syntax: 'y=formula in x     then     x value  =',
    steps: <String>[
      'On an empty display tap the y key. It types y= for you.',
      'Write the formula using the x key, for example x^2−5x+6, then press =. The equation is saved and shown at the top of the display.',
      'Type a value for x, such as 4, and press =. The answer is y at that x.',
      'You can also write y(4) inside a longer calculation, for example y(4)+y(5).',
      'Tap AC on an empty display to forget the equation and start a new one.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: 'y=x^2−5x+6', note: 'Step 1: a quadratic. Press = to save it.', angle: null, setup: null, load: null),
      GuideExample(expr: 'y(4)', note: 'Step 2: y at x = 4. Since 16 − 20 + 6 = 2', angle: null, setup: 'x^2−5x+6', load: 'y=x^2−5x+6'),
      GuideExample(expr: 'y(2)+y(3)', note: 'Both x = 2 and x = 3 give 0, so they are the roots', angle: null, setup: 'x^2−5x+6', load: 'y=x^2−5x+6'),
      GuideExample(expr: 'y(0)', note: 'Where the curve crosses the y axis (the constant term)', angle: null, setup: 'x^2−5x+6', load: 'y=x^2−5x+6'),
    ],
    tips: <String>[
      'Try button on the y(…) examples types the equation first. Press =, then type the x value.',
      'If y comes out as 0 at some x, that x is a root of the equation.',
      'Use only x on the right side. y itself cannot be used inside the formula.',
    ],
  ),
  GuideSection(
    id: 'trig',
    badge: 'sin',
    title: 'Trigonometry',
    summary: 'sin, cos, tan and their reciprocals (sec, csc, cot), inverses (sin⁻¹ …) and hyperbolic versions (sinh …).',
    where: 'fx ADV → Trig & Hyp',
    syntax: 'sin(angle)   asin(ratio)',
    steps: <String>[
      'Check the DEG / RAD badge on the display. DEG means angles are in degrees, RAD in radians.',
      'Tap a function key such as sin. It types sin( for you.',
      'Type the angle, close the bracket and press =.',
      'Inverse keys (sin⁻¹, cos⁻¹, tan⁻¹) go the other way: from a ratio back to an angle.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: 'sin(30)', note: 'In degrees', angle: AngleMode.deg, setup: null, load: null),
      GuideExample(expr: 'cos(60)', note: 'In degrees', angle: AngleMode.deg, setup: null, load: null),
      GuideExample(expr: 'asin(0.5)', note: 'Which angle has a sine of 0.5? In degrees', angle: AngleMode.deg, setup: null, load: null),
      GuideExample(expr: 'tan(π÷4)', note: 'In radians, π÷4 is 45°', angle: AngleMode.rad, setup: null, load: null),
    ],
    tips: <String>[
      'Wrong-looking answers from sin, cos or tan almost always mean the DEG / RAD badge is on the other unit.',
    ],
  ),
  GuideSection(
    id: 'powers',
    badge: 'xʸ',
    title: 'Powers, roots and logs',
    summary: 'Squares, any power, roots of any degree, exponentials and logarithms.',
    where: 'fx ADV → Powers',
    syntax: 'x^y   sqrt(x)   root(degree, x)   logb(base, x)',
    steps: <String>[
      'x² squares a number, and xʸ raises it to any power you type next.',
      'root( takes the degree first: root(3, 27) is the cube root of 27.',
      'logb( takes the base first: logb(2, 8) asks "2 to what power gives 8?".',
      'ln is the natural log (base e), log is base 10.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: '2^10', note: '2 to the power 10', angle: null, setup: null, load: null),
      GuideExample(expr: 'sqrt(144)', note: 'Square root', angle: null, setup: null, load: null),
      GuideExample(expr: 'root(3, 27)', note: 'Cube root', angle: null, setup: null, load: null),
      GuideExample(expr: 'logb(2, 8)', note: '2 to the power 3 is 8', angle: null, setup: null, load: null),
      GuideExample(expr: 'log(1000)', note: 'Base-10 logarithm', angle: null, setup: null, load: null),
      GuideExample(expr: 'exp(2)', note: 'e squared', angle: null, setup: null, load: null),
    ],
    tips: null,
  ),
  GuideSection(
    id: 'prob',
    badge: 'nCr',
    title: 'Combinations and number tools',
    summary: 'Counting, factorials, remainders, gcd and lcm, min, max and average, and random numbers.',
    where: 'fx ADV → Probability',
    syntax: 'nCr(n, r)   nPr(n, r)   n!   gcd(a, b)   max(a, b, …)',
    steps: <String>[
      'nCr counts ways to choose r items from n when order does not matter. nPr counts when order matters.',
      'The ! key gives the factorial of the number before it.',
      'min, max and avg take any number of values separated by commas.',
      'rand gives a random number from 0 to 1, and randInt(min, max) gives a whole number.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: 'nCr(10, 3)', note: 'Ways to pick 3 people from 10', angle: null, setup: null, load: null),
      GuideExample(expr: 'nPr(5, 2)', note: 'Ways to line up 2 of 5 people', angle: null, setup: null, load: null),
      GuideExample(expr: '5!', note: '5 × 4 × 3 × 2 × 1', angle: null, setup: null, load: null),
      GuideExample(expr: 'gcd(12, 18)', note: 'Greatest common divisor', angle: null, setup: null, load: null),
      GuideExample(expr: 'max(3, 9, 4)', note: 'The largest value', angle: null, setup: null, load: null),
      GuideExample(expr: 'avg(2, 4, 9)', note: 'The mean', angle: null, setup: null, load: null),
    ],
    tips: null,
  ),
  GuideSection(
    id: 'constants',
    badge: 'π',
    title: 'Constants',
    summary: 'Tap a constant to insert its value: π, e, φ, the speed of light c, Planck h, G, g and more.',
    where: 'fx ADV → Constants',
    syntax: null,
    steps: <String>[
      'Tap a constant key to type its symbol.',
      'Combine it with other numbers like any value, for example 2×π×5.',
      'Turn on Physics Lab in Settings → Features to see every constant with its full value and unit.',
    ],
    examples: <GuideExample>[
      GuideExample(expr: '2×π×5', note: 'Circumference of a circle with radius 5', angle: null, setup: null, load: null),
      GuideExample(expr: 'c÷1000', note: 'Speed of light in km per second', angle: null, setup: null, load: null),
      GuideExample(expr: 'g×2', note: 'Weight force of a 2 kg mass in newtons', angle: null, setup: null, load: null),
    ],
    tips: null,
  ),
];

const List<String> kGuideTips = <String>[
  'Using trig inside diff, integrate or limit? Switch to RAD first.',
  'You can write 2x or 3(4+5). Multiplication is understood next to x and brackets.',
  'Derivatives, integrals and limits are calculated numerically, accurate to about ten digits.',
  'How many decimals you see is set in Settings → Decimal precision.',
];
