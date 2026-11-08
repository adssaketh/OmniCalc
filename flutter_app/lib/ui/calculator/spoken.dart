// Phase 8b: what a screen reader says for a key. Most keys are a glyph (÷ ▭/▭ ◀ Σ▭▭) that TalkBack reads badly or not at
// all, so each key's Text gets a `semanticsLabel` built here. The visible text does not change.

const Map<String, String> _whole = <String, String>{
  '÷': 'divide',
  '×': 'multiply',
  '−': 'minus',
  '+': 'plus',
  '%': 'percent',
  '.': 'decimal point',
  ',': 'comma',
  '=': 'equals',
  '( )': 'parentheses',
  '→': 'exit group',
  '◀': 'left',
  '▶': 'right',
  '▲': 'up',
  '▼': 'down',
  'x²': 'x squared',
  'x³': 'x cubed',
  'x⁻¹': 'x inverse',
  'xʸ': 'x to the power y',
  'eˣ': 'e to the x',
  '10ˣ': '10 to the x',
  '2ˣ': '2 to the x',
  '×10ˣ': 'times 10 to the x',
  '√x': 'square root',
  '³√x': 'cube root',
  'ʸ√x': 'y-th root',
  '√▭': 'square root',
  'ⁿ√▭': 'n-th root',
  '▭/▭': 'fraction',
  '|▭|': 'absolute value',
  '|x|': 'absolute value',
  'log▭▭': 'log with base',
  'log_b': 'log with base',
  'log₁₀': 'log base 10',
  'log₂': 'log base 2',
  'sin⁻¹': 'inverse sine',
  'cos⁻¹': 'inverse cosine',
  'tan⁻¹': 'inverse tangent',
  'sinh⁻¹': 'inverse hyperbolic sine',
  'cosh⁻¹': 'inverse hyperbolic cosine',
  'tanh⁻¹': 'inverse hyperbolic tangent',
  'd/dx': 'derivative',
  '∫▭▭': 'integral',
  'Σ▭▭': 'sum',
  '∏▭▭': 'product',
  'π': 'pi',
  'φ': 'golden ratio',
  'ħ': 'h bar',
  'ε₀': 'epsilon zero',
  'μ₀': 'mu zero',
  'σ': 'sigma',
  'S⇔D': 'switch fraction and decimal',
  '÷R': 'divide with remainder',
  '▸r∠θ': 'to polar form',
  '▸a+bi': 'to rectangular form',
  '∠': 'angle',
  '°': 'degrees',
  'ʳ': 'radians',
  'ᵍ': 'gradians',
  'M−': 'M minus',
  'M-': 'M minus',
  'M+': 'M plus',
};

const Map<String, String> _parts = <String, String>{
  '▭': ' box ',
  '∫': 'integral ',
  'Σ': 'sum ',
  '∏': 'product ',
  '√': 'square root ',
  '²': ' squared',
  '³': ' cubed',
  '⁻¹': ' inverse',
  '₂': ' 2',
  '₀': ' 0',
  '−': ' minus ',
  '×': ' times ',
  '÷': ' divided by ',
  '⇔': ' to ',
  '←': ' left arrow',
  '▸': ' to ',
};

/// What a screen reader should say for [label]; null when the visible text already reads well.
String? spokenKey(String label) {
  final whole = _whole[label];
  if (whole != null) return whole;
  var needs = false;
  for (final p in _parts.keys) {
    if (label.contains(p)) {
      needs = true;
      break;
    }
  }
  if (!needs) return null;
  var out = label;
  _parts.forEach((k, v) => out = out.replaceAll(k, v));
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}
