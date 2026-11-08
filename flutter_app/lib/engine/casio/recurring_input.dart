// Recurring-decimal input (manual p.26-30, row A41).
//
// The key before the period types a decimal point (when there is none yet) and marks every following digit with a
// combining overline, exactly how a recurring RESULT is drawn: `0.3̅` is 0.333..., `1.428571̅` is 1.428571428571...
// The engine receives that text and this class turns each such number into the exact fraction: with integer part I,
// non-repeating digits N (k of them) and period P (p digits) the value is (INP − IN) / (10^k × (10^p − 1)), so
// `0.3̅` is (3÷9) = 1/3 and `12.312̅` (period 312) is (12300÷999).

class CasioRecurringInput {
  const CasioRecurringInput._();

  /// U+0305 COMBINING OVERLINE, the mark the result formatter also puts over each digit of a period.
  static const String mark = '̅';

  /// The manual allows a period of at most 14 decimal places; a longer one is a terminating decimal.
  static const int maxPeriod = 14;

  static final RegExp _number = RegExp('(\\d*)\\.(\\d*)((?:\\d$mark)+)');

  static bool contains(String text) => text.contains(mark);

  /// [text] with every recurring number replaced by its exact fraction in parentheses.
  static String expand(String text) {
    if (!contains(text)) return text;
    final out = text.replaceAllMapped(_number, (m) {
      final whole = m[1]!.isEmpty ? '0' : m[1]!;
      final nonRepeating = m[2]!;
      final period = m[3]!.replaceAll(mark, '');
      if (period.length > maxPeriod) return '$whole.$nonRepeating$period';
      final head = BigInt.parse('$whole$nonRepeating');
      final all = BigInt.parse('$whole$nonRepeating$period');
      final ten = BigInt.from(10);
      final numerator = all - head;
      final denominator = ten.pow(nonRepeating.length) * (ten.pow(period.length) - BigInt.one);
      return '($numerator÷$denominator)';
    });
    return out.replaceAll(mark, ''); // a mark with no decimal point before it means nothing
  }
}
