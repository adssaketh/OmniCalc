import 'js_number.dart';

/// `x.toLocaleString(undefined, { minimumFractionDigits, maximumFractionDigits })`, always with en-US conventions
/// (`,` between thousands, `.` as the decimal point). The web app uses the device locale; the Flutter app never does,
/// so a result reads the same on every device (rule "never use locale-dependent formatting for results").
///
/// Rounding is `Intl`'s half-expand on the exact value of the double, which is what `toFixed` does for the digits
/// that matter here, so the digits come from [jsToFixed]. With no options JavaScript uses 0 to 3 fraction digits.
String jsToLocaleString(double x, {int minFrac = 0, int maxFrac = 3}) {
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? '∞' : '-∞';
  final fixed = jsToFixed(x, maxFrac);
  // 1e21 and above: toFixed falls back to exponent notation and Intl prints every digit. Not reachable from the
  // currency screen (an amount that large is already `Infinity` after conversion), so keep the plain string.
  if (fixed.contains('e')) return fixed;
  final neg = fixed.startsWith('-');
  final body = neg ? fixed.substring(1) : fixed;
  final dot = body.indexOf('.');
  var intPart = dot < 0 ? body : body.substring(0, dot);
  var frac = dot < 0 ? '' : body.substring(dot + 1);
  while (frac.length > minFrac && frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  final grouped = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write(',');
    grouped.write(intPart[i]);
  }
  return '${neg ? '-' : ''}$grouped${frac.isEmpty ? '' : '.$frac'}';
}

/// `x.toLocaleString('en-IN')`: the locale is named in the web source (the finance tabs), so it is the same on every
/// device. Indian digit grouping: the last three integer digits, then groups of two (`12,34,567`). With no options
/// JavaScript uses 0 to 3 fraction digits. `-0` keeps its sign, as `Intl` prints it.
String jsToLocaleStringEnIN(double x, {int minFrac = 0, int maxFrac = 3}) {
  if (x.isNaN) return 'NaN';
  if (x.isInfinite) return x > 0 ? '∞' : '-∞';
  if (x == 0 && x.isNegative && minFrac == 0) return '-0';
  final fixed = jsToFixed(x, maxFrac);
  if (fixed.contains('e')) return fixed;
  final neg = fixed.startsWith('-');
  final body = neg ? fixed.substring(1) : fixed;
  final dot = body.indexOf('.');
  final intPart = dot < 0 ? body : body.substring(0, dot);
  var frac = dot < 0 ? '' : body.substring(dot + 1);
  while (frac.length > minFrac && frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  final String grouped;
  if (intPart.length <= 3) {
    grouped = intPart;
  } else {
    final head = intPart.substring(0, intPart.length - 3);
    final tail = intPart.substring(intPart.length - 3);
    final parts = <String>[];
    for (var end = head.length; end > 0; end -= 2) {
      final start = end - 2 < 0 ? 0 : end - 2;
      parts.insert(0, head.substring(start, end));
    }
    grouped = '${parts.join(',')},$tail';
  }
  return '${neg ? '-' : ''}$grouped${frac.isEmpty ? '' : '.$frac'}';
}
