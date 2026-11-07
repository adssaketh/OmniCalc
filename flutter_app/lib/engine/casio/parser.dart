// Lexer and parser of the Casio engine (Phase 8b). Priority sequence: manual p.96 (levels quoted below).
//
//   1 parentheses            2 functions with an argument and ")"     3 postfix (x² x³ x⁻¹ x! ° ʳ ᵍ %), powers ^, roots
//   4 fractions              5 negative sign (−)                      6 metric conversion, estimated values
//   7 multiplication with omitted sign                                8 nPr nCr ∠
//   9 dot product            10 × ÷ ÷R                                11 + −
//
// Same priority is evaluated left to right. A closing parenthesis is only optional at the very end of the input, never in
// the middle (`sin(30+15` is sin 45; manual p.102 FAQ).

import 'cval.dart';

enum _T { num, id, op, lp, rp, comma, colon, end }

class _Tok {
  const _Tok(this.t, this.s, this.pos, [this.decimal = false]);
  final _T t;
  final String s;
  final int pos;
  final bool decimal;
  @override
  String toString() => '$t:$s';
}

// ---------------------------------------------------------------------------------------------------------------------
// AST
// ---------------------------------------------------------------------------------------------------------------------

sealed class Node {
  const Node(this.pos);
  final int pos;
}

class NNum extends Node {
  const NNum(this.text, this.decimal, super.pos);
  final String text;

  /// Written with a decimal point or an exponent: results that involve it are decimals, never fractions.
  final bool decimal;
}

class NName extends Node {
  const NName(this.name, super.pos);

  /// `π`, `e`, a variable letter, `Ans`, `PreAns`, `Ran#` or a legacy constant word.
  final String name;
}

class NNeg extends Node {
  const NNeg(this.a, super.pos);
  final Node a;
}

class NBin extends Node {
  const NBin(this.op, this.a, this.b, super.pos, {this.implicit = false});

  /// `+ − × ÷ ÷R nPr nCr`
  final String op;
  final Node a;
  final Node b;
  final bool implicit;
}

class NPow extends Node {
  const NPow(this.a, this.b, super.pos);
  final Node a;
  final Node b;
}

class NPost extends Node {
  const NPost(this.op, this.a, super.pos);

  /// `! ° r g %`
  final String op;
  final Node a;
}

class NCall extends Node {
  const NCall(this.name, this.args, super.pos);
  final String name;
  final List<Node> args;
}

/// `expr → X` (STO).
class NSto extends Node {
  const NSto(this.a, this.name, super.pos);
  final Node a;
  final String name;
}

class NSeq extends Node {
  const NSeq(this.stmts, super.pos);
  final List<Node> stmts;
}

/// `a°b′c″` (degrees, minutes, seconds).
class NDms extends Node {
  const NDms(this.d, this.m, this.s, super.pos);
  final Node d;
  final Node? m;
  final Node? s;
}

// ---------------------------------------------------------------------------------------------------------------------
// Lexer
// ---------------------------------------------------------------------------------------------------------------------

const Map<String, String> _supDigits = <String, String>{
  '⁰': '0',
  '¹': '1',
  '²': '2',
  '³': '3',
  '⁴': '4',
  '⁵': '5',
  '⁶': '6',
  '⁷': '7',
  '⁸': '8',
  '⁹': '9',
  '⁻': '-',
  '⁺': '+',
};

/// Function names the engine knows (lower case compare, except the capitalised Casio names that are checked as written).
const List<String> _names = <String>[
  'asinh', 'acosh', 'atanh', 'sech', 'csch', 'coth', 'sinh', 'cosh', 'tanh', 'asin', 'acos', 'atan', 'sec', 'csc', 'cot',
  'sin', 'cos', 'tan', 'log2', 'logb', 'log', 'ln', 'exp', 'sqrt', 'cbrt', 'root', 'abs', 'round', 'floor', 'ceil', 'sign',
  'sgn', 'nPr', 'nCr', 'mod', 'gcd', 'lcm', 'Pol', 'Rec', 'Rnd', 'Intg', 'Int', 'GCD', 'LCM', 'CONST', 'CONV', 'RanInt#',
  'Ran#', 'PreAns', 'Ans', 'hbar', 'eps0', 'mu0', 'sigma', 'atm', 'phi', 'ke', 'NA', 'kB', 'qe', 'me', 'mp', 'mn', 'au', 'DMS',
  'm_e', 'm_p', 'm_n', 'k_B', 'N_A', 'q_e',
];

const Set<String> _constWords = <String>{
  'c', 'h', 'hbar', 'G', 'qe', 'me', 'mp', 'mn', 'kB', 'NA', 'eps0', 'mu0', 'ke', 'R', 'sigma', 'atm', 'au', 'g', 'phi',
};

const Set<String> _variables = <String>{'A', 'B', 'C', 'D', 'E', 'F', 'M', 'X', 'Y'};

const Set<String> _funcSet = <String>{
  'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh', 'sec', 'csc', 'cot',
  'sech', 'csch', 'coth', 'ln', 'log', 'log2', 'logb', 'exp', 'sqrt', 'cbrt', 'root', 'abs', 'round', 'floor', 'ceil',
  'sign', 'sgn', 'npr', 'ncr', 'mod', 'gcd', 'lcm', 'pol', 'rec', 'rnd', 'intg', 'int', 'const', 'conv', 'ranint#', 'dms',
  'integral', 'deriv', 'sumx', 'prodx',
};

/// ∫, d/dx, Σ and ∏ (Phase 7c). They always have their argument list in parentheses.
const Set<String> kCalculusNames = <String>{'integral', 'deriv', 'sumx', 'prodx'};

List<_Tok> _lex(String src) {
  final out = <_Tok>[];
  var i = 0;
  final n = src.length;
  bool isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool isLetter(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
  }

  while (i < n) {
    final c = src[i];
    if (c == ' ' || c == '\t' || c == '\n' || c == ' ') {
      i++;
      continue;
    }
    // ---- numbers
    if (isDigit(c) || (c == '.' && i + 1 < n && isDigit(src[i + 1]))) {
      final start = i;
      var decimal = false;
      while (i < n && isDigit(src[i])) {
        i++;
      }
      if (i < n && src[i] == '.') {
        decimal = true;
        i++;
        while (i < n && isDigit(src[i])) {
          i++;
        }
      }
      // exponent: the E key (also a lower case e, as the legacy evaluator reads `1e10`), only when digits follow
      if (i < n && (src[i] == 'E' || src[i] == 'e')) {
        var j = i + 1;
        if (j < n && (src[j] == '+' || src[j] == '-' || src[j] == '−')) j++;
        if (j < n && isDigit(src[j])) {
          while (j < n && isDigit(src[j])) {
            j++;
          }
          decimal = true;
          out.add(_Tok(_T.num, src.substring(start, i) + 'E' + src.substring(i + 1, j).replaceAll('−', '-'), start, true));
          i = j;
          continue;
        }
      }
      out.add(_Tok(_T.num, src.substring(start, i), start, decimal));
      continue;
    }
    // ---- superscript digits become ^(...)
    if (_supDigits.containsKey(c)) {
      final start = i;
      final sb = StringBuffer();
      while (i < n && _supDigits.containsKey(src[i])) {
        sb.write(_supDigits[src[i]]);
        i++;
      }
      var text = sb.toString();
      if (text == '3' && i < n && src[i] == '√') {
        out.add(_Tok(_T.id, 'cbrt', start)); // ³√ is the cube-root prefix
        i++;
        continue;
      }
      if (text == '-1' || text == '2' || text == '3' || RegExp(r'^[+-]?\d+$').hasMatch(text)) {
        text = text.replaceFirst('+', '');
        out
          ..add(_Tok(_T.op, '^', start))
          ..add(_Tok(_T.lp, '(', start))
          ..add(_Tok(_T.num, text.replaceFirst('-', ''), start))
          ..add(_Tok(_T.rp, ')', start));
        if (text.startsWith('-')) {
          // insert the minus sign after the opening parenthesis
          out.insert(out.length - 2, _Tok(_T.op, '-', start));
        }
        continue;
      }
      throw CasioError(CasioErrorKind.syntax, start);
    }
    // ---- single characters
    switch (c) {
      case '(':
        out.add(_Tok(_T.lp, c, i++));
        continue;
      case ')':
        out.add(_Tok(_T.rp, c, i++));
        continue;
      case ',':
      case ';':
        out.add(_Tok(_T.comma, ',', i++));
        continue;
      case ':':
        out.add(_Tok(_T.colon, c, i++));
        continue;
      case '+':
        out.add(_Tok(_T.op, '+', i++));
        continue;
      case '-':
      case '−':
      case '–':
        out.add(_Tok(_T.op, '-', i++));
        continue;
      case '×':
      case '*':
      case '·':
        out.add(_Tok(_T.op, '*', i++));
        continue;
      case '/':
        out.add(_Tok(_T.op, '/', i++));
        continue;
      case '÷':
        if (i + 1 < n && src[i + 1] == 'R' && (i + 2 >= n || !isLetter(src[i + 2]))) {
          out.add(_Tok(_T.op, '÷R', i));
          i += 2;
        } else {
          out.add(_Tok(_T.op, '/', i++));
        }
        continue;
      case '^':
        out.add(_Tok(_T.op, '^', i++));
        continue;
      case '!':
        out.add(_Tok(_T.op, '!', i++));
        continue;
      case '%':
        out.add(_Tok(_T.op, '%', i++));
        continue;
      case '°':
        out.add(_Tok(_T.op, '°', i++));
        continue;
      case '′':
      case "'":
        out.add(_Tok(_T.op, "'", i++));
        continue;
      case '″':
      case '"':
        out.add(_Tok(_T.op, '"', i++));
        continue;
      case 'ʳ':
        out.add(_Tok(_T.op, 'r', i++));
        continue;
      case 'ᵍ':
        out.add(_Tok(_T.op, 'g', i++));
        continue;
      case 'π':
        out.add(_Tok(_T.id, 'π', i++));
        continue;
      case 'φ':
        out.add(_Tok(_T.id, 'phi', i++));
        continue;
      case 'ħ':
        out.add(_Tok(_T.id, 'hbar', i++));
        continue;
      case 'σ':
        out.add(_Tok(_T.id, 'sigma', i++));
        continue;
      case 'ε':
        // ε₀ / ε0
        out.add(_Tok(_T.id, 'eps0', i));
        i++;
        if (i < n && (src[i] == '₀' || src[i] == '0')) i++;
        continue;
      case 'μ':
        out.add(_Tok(_T.id, 'mu0', i));
        i++;
        if (i < n && (src[i] == '₀' || src[i] == '0')) i++;
        continue;
      case '∛':
      case '³':
        // never reached for ³ (handled above); ∛ is a cube root prefix
        out.add(_Tok(_T.id, 'cbrt', i++));
        continue;
      case '√':
        out.add(_Tok(_T.id, 'sqrt', i++));
        continue;
      // Phase 7c, linear syntax of the manual (p.39-43): ∫(f(x), a, b, tol), d/dx(f(x), a, tol), Σ(f(x), a, b), ∏(f(x), a, b)
      case '∫':
        out.add(_Tok(_T.id, 'integral', i++));
        continue;
      case 'Σ':
      case '∑':
        out.add(_Tok(_T.id, 'sumx', i++));
        continue;
      case '∏':
        out.add(_Tok(_T.id, 'prodx', i++));
        continue;
      case '→':
        out.add(_Tok(_T.op, '→', i++));
        // the letter after STO names a variable, so `→E` is the variable E (not Euler's e)
        while (i < n && src[i] == ' ') {
          i++;
        }
        if (i < n && _variables.contains(src[i])) {
          out.add(_Tok(_T.id, src[i], i));
          i++;
        }
        continue;
      case '=':
      case '<':
      case '>':
      case '≤':
      case '≥':
      case '≠':
        throw CasioError(CasioErrorKind.syntax, i);
    }
    // ---- words
    if (c == 'd' && src.startsWith('d/dx', i)) {
      out.add(_Tok(_T.id, 'deriv', i));
      i += 4;
      continue;
    }
    if (isLetter(c)) {
      // longest known name first (case sensitive for the capitalised Casio names, insensitive for the rest)
      String? best;
      for (final name in _names) {
        if (src.startsWith(name, i) || (_isLowerName(name) && src.substring(i).toLowerCase().startsWith(name))) {
          if (best == null || name.length > best.length) best = name;
        }
      }
      if (best != null) {
        final raw = src.substring(i, i + best.length);
        // `Ran#` and `RanInt#` end in '#', everything else must not run into more letters when it is a constant word
        out.add(_Tok(_T.id, _canonical(best, raw), i));
        i += best.length;
        continue;
      }
      // single letters: variables, e, E, c, h, g, G, R
      if (c == 'e') {
        out.add(_Tok(_T.id, 'e', i++));
        continue;
      }
      if (_variables.contains(c) || _constWords.contains(c)) {
        out.add(_Tok(_T.id, c, i++));
        continue;
      }
      // legacy tokens that must not be tried here
      throw CasioError(CasioErrorKind.syntax, i);
    }
    throw CasioError(CasioErrorKind.syntax, i);
  }
  out.add(_Tok(_T.end, '', n));
  return out;
}

bool _isLowerName(String name) => name == name.toLowerCase() && !name.contains('#');

const Map<String, String> _aliases = <String, String>{
  'm_e': 'me', 'm_p': 'mp', 'm_n': 'mn', 'k_B': 'kB', 'N_A': 'NA', 'q_e': 'qe',
};

String _canonical(String name, String raw) {
  final alias = _aliases[name];
  if (alias != null) return alias;
  if (name == name.toLowerCase()) return name; // lower case names compare insensitively
  return name; // capitalised Casio names are used as written
}

// ---------------------------------------------------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------------------------------------------------

class CasioParser {
  CasioParser._(this._toks);

  final List<_Tok> _toks;
  var _p = 0;

  static Node parse(String src) {
    final parser = CasioParser._(_lex(src));
    final node = parser._parseSequence();
    if (parser._cur.t != _T.end) throw CasioError(CasioErrorKind.syntax, parser._cur.pos);
    return node;
  }

  _Tok get _cur => _toks[_p];
  _Tok _peek([int k = 1]) => _toks[(_p + k).clamp(0, _toks.length - 1)];
  _Tok _next() => _toks[_p++];

  bool _isOp(String s) => _cur.t == _T.op && _cur.s == s;

  Node _parseSequence() {
    final first = _cur.pos;
    final stmts = <Node>[_parseStatement()];
    while (_cur.t == _T.colon) {
      _next();
      stmts.add(_parseStatement());
    }
    return stmts.length == 1 ? stmts.first : NSeq(stmts, first);
  }

  Node _parseStatement() {
    var node = _parseAdd();
    while (_isOp('→')) {
      final arrow = _next();
      final v = _cur;
      if (v.t != _T.id || !_variables.contains(v.s)) throw CasioError(CasioErrorKind.syntax, v.pos);
      _next();
      node = NSto(node, v.s, arrow.pos);
    }
    return node;
  }

  // 11: + -
  Node _parseAdd() {
    var left = _parseMul();
    while (_cur.t == _T.op && (_cur.s == '+' || _cur.s == '-')) {
      final op = _next();
      final right = _parseMul();
      left = NBin(op.s == '+' ? '+' : '-', left, right, op.pos);
    }
    return left;
  }

  // 10: × ÷ ÷R
  Node _parseMul() {
    var left = _parsePerm();
    while (_cur.t == _T.op && (_cur.s == '*' || _cur.s == '/' || _cur.s == '÷R')) {
      final op = _next();
      final right = _parsePerm();
      left = NBin(op.s == '*' ? '*' : (op.s == '/' ? '/' : '÷R'), left, right, op.pos);
    }
    return left;
  }

  // 8: nPr nCr (infix)
  Node _parsePerm() {
    var left = _parseImplicit();
    while (_cur.t == _T.id && (_cur.s == 'nPr' || _cur.s == 'nCr')) {
      final op = _next();
      final right = _parseImplicit();
      left = NBin(op.s, left, right, op.pos);
    }
    return left;
  }

  bool _startsOperand(_Tok t, {required bool afterNumber}) {
    if (t.t == _T.lp) return true;
    if (t.t == _T.num) return !afterNumber; // "(2)3", "π2": a number may follow a closing parenthesis or a constant
    if (t.t == _T.id) return true;
    return false;
  }

  // 7: multiplication with the × omitted
  Node _parseImplicit() {
    var left = _parseNeg();
    while (true) {
      final t = _cur;
      if (!_startsOperand(t, afterNumber: _lastWasNumber)) break;
      if (t.t == _T.id && (t.s == 'nPr' || t.s == 'nCr')) break;
      final right = _parseNegNoSign();
      left = NBin('*', left, right, t.pos, implicit: true);
    }
    return left;
  }

  bool get _lastWasNumber => _p > 0 && _toks[_p - 1].t == _T.num;

  // 5: negative sign
  Node _parseNeg() {
    if (_isOp('-')) {
      final t = _next();
      return NNeg(_parseNeg(), t.pos);
    }
    if (_isOp('+')) {
      _next();
      return _parseNeg();
    }
    return _parsePower();
  }

  Node _parseNegNoSign() => _parsePower();

  // 3: postfix, powers (left to right)
  Node _parsePower() {
    var left = _parseAtom();
    while (true) {
      final t = _cur;
      if (t.t == _T.op && (t.s == '!' || t.s == '%' || t.s == '°' || t.s == 'r' || t.s == 'g')) {
        _next();
        if (t.s == '°') {
          left = _maybeDms(left, t.pos);
        } else {
          left = NPost(t.s, left, t.pos);
        }
        continue;
      }
      if (t.t == _T.op && t.s == '^') {
        _next();
        final exp = _parseExponent();
        left = NPow(left, exp, t.pos);
        continue;
      }
      break;
    }
    return left;
  }

  /// After `°`: optional `minutes ′` and `seconds ″`.
  Node _maybeDms(Node deg, int pos) {
    Node? m;
    Node? s;
    if (_cur.t == _T.num && _peek().t == _T.op && _peek().s == "'") {
      m = _parseAtom();
      _next();
      if (_cur.t == _T.num && _peek().t == _T.op && _peek().s == '"') {
        s = _parseAtom();
        _next();
      }
    }
    if (m == null && s == null) return NPost('°', deg, pos); // a bare ° is the angle-unit mark
    return NDms(deg, m, s, pos);
  }

  // exponent of ^ : optional sign and one atom (no postfix: `2^3!` is (2^3)!)
  Node _parseExponent() {
    if (_isOp('-')) {
      final t = _next();
      return NNeg(_parseExponent(), t.pos);
    }
    if (_isOp('+')) {
      _next();
      return _parseExponent();
    }
    return _parseAtom();
  }

  // 1, 2: atoms, parentheses, functions
  Node _parseAtom() {
    final t = _cur;
    switch (t.t) {
      case _T.num:
        _next();
        return NNum(t.s, t.decimal, t.pos);
      case _T.lp:
        _next();
        final inner = _parseSequenceInParens();
        if (_cur.t == _T.rp) {
          _next();
        } else if (_cur.t != _T.end) {
          throw CasioError(CasioErrorKind.syntax, _cur.pos);
        }
        return inner;
      case _T.id:
        return _parseIdentifier();
      default:
        throw CasioError(CasioErrorKind.syntax, t.pos);
    }
  }

  Node _parseSequenceInParens() {
    final first = _cur.pos;
    final stmts = <Node>[_parseAdd()];
    while (_cur.t == _T.colon) {
      _next();
      stmts.add(_parseAdd());
    }
    return stmts.length == 1 ? stmts.first : NSeq(stmts, first);
  }

  Node _parseIdentifier() {
    final t = _next();
    final name = t.s;
    final lower = name.toLowerCase();
    // plain names
    if (name == 'π' || name == 'e' || name == 'Ans' || name == 'PreAns' || name == 'Ran#' || _variables.contains(name) ||
        _constWords.contains(name)) {
      return NName(name, t.pos);
    }
    if (!_funcSet.contains(lower)) throw CasioError(CasioErrorKind.syntax, t.pos);
    final canonical = _canonicalFunc(name, lower);
    if (kCalculusNames.contains(canonical) && _cur.t != _T.lp) throw CasioError(CasioErrorKind.syntax, _cur.pos);
    // with parentheses
    if (_cur.t == _T.lp) {
      _next();
      final args = <Node>[];
      if (_cur.t == _T.rp) {
        _next();
        return NCall(canonical, args, t.pos);
      }
      args.add(_parseAdd());
      while (_cur.t == _T.comma) {
        _next();
        args.add(_parseAdd());
      }
      if (_cur.t == _T.rp) {
        _next();
      } else if (_cur.t != _T.end) {
        throw CasioError(CasioErrorKind.syntax, _cur.pos);
      }
      return NCall(canonical, args, t.pos);
    }
    // "sin30", "√9": the argument is the power-level operand that follows
    if (_cur.t == _T.end || _cur.t == _T.rp || _cur.t == _T.comma || _cur.t == _T.colon) {
      throw CasioError(CasioErrorKind.syntax, _cur.pos);
    }
    final neg = _isOp('-');
    if (neg) _next();
    final arg = _parsePowerNoImplicit();
    return NCall(canonical, <Node>[neg ? NNeg(arg, t.pos) : arg], t.pos);
  }

  Node _parsePowerNoImplicit() => _parsePower();

  static String _canonicalFunc(String name, String lower) {
    // the capitalised Casio names keep their spelling so that `Int(` and the legacy `int(` can be told apart
    if (name == 'Int' || name == 'Intg' || name == 'GCD' || name == 'LCM' || name == 'Pol' || name == 'Rec' ||
        name == 'Rnd' || name == 'CONST' || name == 'CONV' || name == 'RanInt#') {
      return name.toLowerCase().replaceAll('#', '');
    }
    switch (lower) {
      case 'sgn':
        return 'sign';
      case 'ncr':
        return 'nCr';
      case 'npr':
        return 'nPr';
    }
    return lower;
  }
}
