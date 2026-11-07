// BASE-N mode of the Casio engine (Phase 7d, manual p.66-70): DEC / HEX / BIN / OCT calculation on integers, the number-mode
// prefixes d h b o, the logical operators and, or, xor, xnor and the functions Not( and Neg(.
//
// Ranges (manual p.67-68): binary 16 bits, octal / decimal / hexadecimal 32 bits. A negative binary, octal or hexadecimal
// number is its two's complement; a decimal number just has a minus sign. There are no fractions and no exponents: a
// quotient has its fractional part cut off. Priority (manual p.96): the negative sign and d h b o (5), implicit
// multiplication (7), × ÷ (10), + − (11), and (12), or xor xnor (13).

import 'cval.dart';

enum BaseMode {
  dec(10, 'DEC', 'd'),
  hex(16, 'HEX', 'h'),
  bin(2, 'BIN', 'b'),
  oct(8, 'OCT', 'o');

  const BaseMode(this.radix, this.label, this.prefix);

  final int radix;
  final String label;

  /// The one-letter number-mode command (`d`, `h`, `b`, `o`).
  final String prefix;

  /// The smallest and largest value of this mode (binary 16 bits, the others 32 bits).
  int get minValue => this == BaseMode.bin ? -32768 : -2147483648;
  int get maxValue => this == BaseMode.bin ? 32767 : 2147483647;
}

/// A result: one integer that can be shown in all four number modes.
class BaseNOutcome {
  const BaseNOutcome(this.value, this.mode);

  final int value;

  /// The number mode the line was calculated in.
  final BaseMode mode;

  /// The value shown in [m] (manual p.68). A value outside that mode's range cannot be converted: Math ERROR.
  String textIn(BaseMode m) => CasioBaseN.format(value, m);

  String get text => textIn(mode);
}

class CasioBaseN {
  CasioBaseN();

  /// Ans of the BASE-N mode.
  int ans = 0;

  /// The display text of [v] in [m]: binary 16 digits, octal 11, hexadecimal 8 (zero padded), decimal plain.
  static String format(int v, BaseMode m) {
    if (v < m.minValue || v > m.maxValue) throw kMathError;
    switch (m) {
      case BaseMode.dec:
        return '$v';
      case BaseMode.bin:
        return (v & 0xFFFF).toRadixString(2).padLeft(16, '0');
      case BaseMode.oct:
        return (v & 0xFFFFFFFF).toRadixString(8).padLeft(11, '0');
      case BaseMode.hex:
        return (v & 0xFFFFFFFF).toRadixString(16).toUpperCase().padLeft(8, '0');
    }
  }

  /// Calculates [input] in the number mode [mode]. [commit] false (a preview) leaves Ans alone.
  BaseNOutcome evaluate(String input, BaseMode mode, {bool commit = true}) {
    final p = _Parser(input, mode, ans);
    final v = p.parse();
    if (v < mode.minValue || v > mode.maxValue) throw kMathError;
    if (commit) ans = v;
    return BaseNOutcome(v, mode);
  }
}

const int _int32Min = -2147483648;
const int _int32Max = 2147483647;

int _wrap32(int v) {
  final w = v & 0xFFFFFFFF;
  return w >= 0x80000000 ? w - 0x100000000 : w;
}

class _Parser {
  _Parser(this.src, this.mode, this.ans);

  final String src;
  final BaseMode mode;
  final int ans;
  int _i = 0;

  static final RegExp _digitDec = RegExp(r'[0-9]');
  static final RegExp _digitHex = RegExp(r'[0-9A-F]');
  static final RegExp _digitBin = RegExp(r'[01]');
  static final RegExp _digitOct = RegExp(r'[0-7]');

  int parse() {
    final v = _or();
    _skip();
    if (_i < src.length) throw CasioError(CasioErrorKind.syntax, _i);
    return v;
  }

  // ----- lexing helpers ------------------------------------------------------------------------------------------------

  void _skip() {
    while (_i < src.length && (src[_i] == ' ' || src[_i] == '\t')) {
      _i++;
    }
  }

  bool _at(String s) {
    _skip();
    return src.startsWith(s, _i);
  }

  bool _eat(String s) {
    if (_at(s)) {
      _i += s.length;
      return true;
    }
    return false;
  }

  bool get _end {
    _skip();
    return _i >= src.length;
  }

  RegExp _digitsOf(BaseMode m) {
    switch (m) {
      case BaseMode.dec:
        return _digitDec;
      case BaseMode.hex:
        return _digitHex;
      case BaseMode.bin:
        return _digitBin;
      case BaseMode.oct:
        return _digitOct;
    }
  }

  // ----- grammar --------------------------------------------------------------------------------------------------------

  // 13: or, xor, xnor
  int _or() {
    var left = _and();
    while (true) {
      if (_eat('xnor')) {
        left = _wrap32(~(left ^ _and()));
      } else if (_eat('xor')) {
        left = _wrap32(left ^ _and());
      } else if (_eat('or')) {
        left = _wrap32(left | _and());
      } else {
        return left;
      }
    }
  }

  // 12: and
  int _and() {
    var left = _add();
    while (_eat('and')) {
      left = _wrap32(left & _add());
    }
    return left;
  }

  int _range(int v) {
    if (v < _int32Min || v > _int32Max) throw kMathError;
    return v;
  }

  // 11: + -
  int _add() {
    var left = _mul();
    while (true) {
      if (_eat('+')) {
        left = _range(left + _mul());
      } else if (_eat('-') || _eat('−')) {
        left = _range(left - _mul());
      } else {
        return left;
      }
    }
  }

  // 10: × ÷ (the quotient's fractional part is cut off)
  int _mul() {
    var left = _implicit();
    while (true) {
      if (_eat('×') || _eat('*')) {
        left = _range(left * _implicit());
      } else if (_eat('÷') || _eat('/')) {
        final r = _implicit();
        if (r == 0) throw kMathError;
        left = left ~/ r;
      } else {
        return left;
      }
    }
  }

  // 7: multiplication with the sign omitted (before an opening parenthesis, Not( or Neg( )
  int _implicit() {
    var left = _unary();
    while (_at('(') || _at('Not') || _at('Neg') || _at('Ans')) {
      left = _range(left * _unary());
    }
    return left;
  }

  // 5: negative sign, number-mode prefixes
  int _unary({bool negated = false}) {
    if (_eat('-') || _eat('−')) return _range(-_unary(negated: true));
    return _atom(negated: negated);
  }

  int _atom({required bool negated}) {
    _skip();
    if (_i >= src.length) throw CasioError(CasioErrorKind.syntax, _i);
    if (_eat('(')) {
      final v = _or();
      if (_at(')')) {
        _i++;
      } else if (!_end) {
        throw CasioError(CasioErrorKind.syntax, _i);
      }
      return v;
    }
    if (_at('Ans')) {
      _i += 3;
      return ans;
    }
    if (_at('Not') || _at('Neg')) {
      final neg = src.startsWith('Neg', _i);
      _i += 3;
      if (!_eat('(')) throw CasioError(CasioErrorKind.syntax, _i);
      final v = _or();
      if (_at(')')) {
        _i++;
      } else if (!_end) {
        throw CasioError(CasioErrorKind.syntax, _i);
      }
      return neg ? _wrap32(-v) : _wrap32(~v);
    }
    // a number, optionally with a number-mode command in front (d h b o)
    var m = mode;
    final c = src[_i];
    if (c == 'd' || c == 'h' || c == 'b' || c == 'o') {
      final base = BaseMode.values.firstWhere((b) => b.prefix == c);
      if (_i + 1 < src.length && _digitsOf(base).hasMatch(src[_i + 1])) {
        m = base;
        _i++;
      }
    }
    return _number(m, negated: negated);
  }

  int _number(BaseMode m, {required bool negated}) {
    final start = _i;
    final ok = _digitsOf(m);
    while (_i < src.length && ok.hasMatch(src[_i])) {
      _i++;
    }
    if (_i == start) throw CasioError(CasioErrorKind.syntax, start);
    // a digit that does not belong to the number mode, a point, an exponent: not allowed in BASE-N
    if (_i < src.length && RegExp(r'[0-9A-F.E]').hasMatch(src[_i])) throw CasioError(CasioErrorKind.syntax, _i);
    final text = src.substring(start, _i);
    if (text.length > 12) throw kMathError;
    final raw = int.parse(text, radix: m.radix);
    switch (m) {
      case BaseMode.bin:
        if (raw > 0xFFFF) throw kMathError;
        return raw >= 0x8000 ? raw - 0x10000 : raw;
      case BaseMode.oct:
      case BaseMode.hex:
        if (raw > 0xFFFFFFFF) throw kMathError;
        return raw >= 0x80000000 ? raw - 0x100000000 : raw;
      case BaseMode.dec:
        // 2147483648 is only allowed as the magnitude of -2147483648
        if (raw > 2147483648 || (raw == 2147483648 && !negated)) throw kMathError;
        return raw;
    }
  }
}
