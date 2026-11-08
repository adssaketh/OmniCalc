import 'guide_content.dart';

/// Guide topics for the features added after the original calculator: the natural display, the Casio modes and the live
/// exchange rates. They are written by hand (guide_content.dart is generated from the original app's guide and is
/// checked against it), carry no runnable examples, and are listed after the generated topics.
const List<GuideSection> kGuideSectionsExtra = <GuideSection>[
  GuideSection(
    id: 'natural',
    badge: 'a/b',
    title: 'Natural display and structure keys',
    summary: 'Type fractions, roots, powers, integrals, sums and products the way they are written on paper.',
    where: 'fx ADV → ES, and Calculus',
    syntax: null,
    steps: <String>[
      'Each structure key shows its shape: a box over a bar over a box for a fraction, a box under a root sign, limit boxes above and below ∫, Σ and ∏ with a box after the sign for what is integrated, summed or multiplied.',
      'Tap a structure key and a box appears in the display for every part to fill in. The blinking cursor is in the first box.',
      'Move between the boxes with the arrow keys (◀ ▶ ▲ ▼ on the ES tab). A box you leave empty gives a Syntax ERROR when you press =.',
      'Press SHIFT first for the second job of a key, such as a mixed fraction or a cube root (the small label above the key). SOLVE is SHIFT then CALC. ALPHA gives the letters and variables.',
      'Results appear as exact fractions, roots and π when they can. Tap the S⇔D key to switch between the exact form and the decimal.',
    ],
    examples: <GuideExample>[],
    tips: <String>[
      'The Math badge on the display shows the expression has a natural-display structure. Angle unit, number format, fraction format, complex format, decimal point and contrast are in Settings (the gear).',
    ],
  ),
  GuideSection(
    id: 'modes',
    badge: 'MODE',
    title: 'Casio modes: STAT, MATRIX, EQN, INEQ and more',
    summary: 'The MODE key switches the calculator to a specific job, as on a Casio fx-991ES PLUS.',
    where: 'fx ADV → Modes, and Data',
    syntax: null,
    steps: <String>[
      'Tap the MODE key (Modes tab) and choose COMP, CMPLX, STAT, BASE-N, EQN, MATRIX, VECTOR, TABLE, INEQ, VERIF or DIST.',
      'COMP is everyday calculation. CMPLX works with complex numbers. BASE-N works in binary, octal, decimal and hexadecimal.',
      'STAT, MATRIX, VECTOR and TABLE open an editor sheet for the data. EQN, INEQ and DIST open a dialog. The keys on the Data tab follow the mode you are in.',
      'CALC (ES tab) evaluates an expression for values you enter, and SHIFT then CALC is SOLVE, which solves for a variable.',
      'Angle unit, number format and the other SETUP choices, and the calculation style (Casio or OmniCalc), are in Settings (the gear).',
    ],
    examples: <GuideExample>[],
    tips: <String>[
      'To go back to everyday arithmetic, choose COMP in the MODE menu.',
    ],
  ),
  GuideSection(
    id: 'rates',
    badge: '₹ \$',
    title: 'Live exchange rates',
    summary: 'The Currency tab in Finance converts with live rates when the phone is online.',
    where: 'Finance → Currency',
    syntax: null,
    steps: <String>[
      'Open Finance, then Currency. The dot and the line above the list say where the rates came from: live, saved from the last time, or built-in.',
      'Tap Refresh Rates to fetch new rates. Several providers are asked at once and the first good answer is used.',
      'Without a connection the last rates you fetched are used. If you never fetched any, approximate built-in rates are used and a note says so.',
    ],
    examples: <GuideExample>[],
    tips: <String>[
      'Rates are for reference. Banks and card networks add their own margin.',
    ],
  ),
];
