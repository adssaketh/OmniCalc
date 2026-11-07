import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/js_number.dart';

// Expected values are what V8 prints for the same call.
void main() {
  group('jsToString', () {
    final cases = <(double, String)>[
      (0.0, '0'),
      (1.0, '1'),
      (-1.5, '-1.5'),
      (0.1, '0.1'),
      (0.30000000000000004, '0.30000000000000004'),
      (100.0, '100'),
      (1e20, '100000000000000000000'),
      (1e21, '1e+21'),
      (1.5e21, '1.5e+21'),
      (1.2345678901234568e20, '123456789012345680000'),
      (0.000001, '0.000001'),
      (1e-7, '1e-7'),
      (1.5e-7, '1.5e-7'),
      (5e-324, '5e-324'),
      (1.7976931348623157e308, '1.7976931348623157e+308'),
    ];
    for (final (x, s) in cases) {
      test(s, () => expect(jsToString(x), s));
    }
    test('-0 prints 0', () => expect(jsToString(-0.0), '0'));
    test('NaN / Infinity', () {
      expect(jsToString(double.nan), 'NaN');
      expect(jsToString(double.infinity), 'Infinity');
      expect(jsToString(double.negativeInfinity), '-Infinity');
    });
  });

  group('jsToFixed', () {
    test('ties and binary representation', () {
      expect(jsToFixed(1.005, 2), '1.00');
      expect(jsToFixed(2.5, 0), '3');
      expect(jsToFixed(-1.5, 0), '-2');
      expect(jsToFixed(0.5, 0), '1');
      expect(jsToFixed(2.675, 2), '2.67');
      expect(jsToFixed(-0.001, 2), '-0.00');
      expect(jsToFixed(-0.0, 2), '0.00');
      expect(jsToFixed(1e21, 2), '1e+21');
      expect(jsToFixed(0.000001, 8), '0.00000100');
    });
  });

  group('jsToPrecision / jsToExponential', () {
    test('toPrecision', () {
      expect(jsToPrecision(123.456, 4), '123.5');
      expect(jsToPrecision(0.000123, 2), '0.00012');
      expect(jsToPrecision(1e21, 3), '1.00e+21');
      expect(jsToPrecision(0, 3), '0.00');
      expect(jsToPrecision(99.99, 3), '100');
      expect(jsToPrecision(1e-7, 3), '1.00e-7');
      expect(jsToPrecision(0.1 + 0.2, 12), '0.300000000000');
    });
    test('toExponential', () {
      expect(jsToExponential(12345, 2), '1.23e+4');
      expect(jsToExponential(0, 4), '0.0000e+0');
      expect(jsToExponential(9.99999, 2), '1.00e+1');
    });
  });

  group('jsParseFloat', () {
    test('prefix parsing', () {
      expect(jsParseFloat('3.14abc'), 3.14);
      expect(jsParseFloat('abc').isNaN, isTrue);
      expect(jsParseFloat('-0').isNegative, isTrue);
      expect(jsParseFloat('.5'), 0.5);
      expect(jsParseFloat('5.'), 5);
      expect(jsParseFloat('1e3x'), 1000);
      expect(jsParseFloat('1e'), 1);
      expect(jsParseFloat('  42  '), 42);
      expect(jsParseFloat('-Infinityx'), double.negativeInfinity);
      expect(jsParseFloat('1.00e+21'), 1e21);
    });
  });

  group('Math / operators', () {
    test('Math.round', () {
      expect(jsRound(2.5), 3);
      expect(jsRound(-2.5), -2);
      expect(jsRound(0.49999999999999994), 0);
      expect(jsRound(-0.5).isNegative, isTrue);
      expect(jsRound(-0.5), 0);
    });
    test('% takes the sign of the dividend', () {
      expect(jsMod(-7, 3), -1);
      expect(jsMod(7, -3), 1);
      expect(jsMod(5.5, 2), 1.5);
      expect(jsMod(5, 0).isNaN, isTrue);
    });
    test('Math.pow edge cases', () {
      expect(jsPow(0, 0), 1);
      expect(jsPow(1, double.nan).isNaN, isTrue);
      expect(jsPow(1, double.infinity).isNaN, isTrue);
      expect(jsPow(-8, 1 / 3).isNaN, isTrue);
      expect(jsPow(2, 10), 1024);
      expect(jsPow(2, 1024), double.infinity);
    });
    test('Math.sign', () {
      expect(jsSign(-0.1), -1);
      expect(jsSign(-0.0).isNegative, isTrue);
      expect(jsSign(double.nan).isNaN, isTrue);
    });
    test('cbrt, log10, log2 are exact on exact inputs', () {
      expect(jsCbrt(27), 3);
      expect(jsCbrt(-8), -2);
      expect(jsCbrt(0.001), closeTo(0.1, 1e-16));
      for (var n = 0; n <= 22; n++) {
        expect(jsLog10(double.parse('1e$n')), n.toDouble(), reason: 'log10(1e$n)');
      }
      expect(jsLog10(2), closeTo(0.3010299956639812, 1e-15));
      expect(jsLog2(1024), 10);
      expect(jsLog2(0.125), -3);
      expect(jsLog2(10), closeTo(3.321928094887362, 1e-14));
    });
    test('hyperbolic family', () {
      expect(jsSinh(0), 0);
      expect(jsSinh(1), closeTo(1.1752011936438014, 1e-15));
      expect(jsCosh(1), closeTo(1.5430806348152437, 1e-15));
      expect(jsTanh(1), closeTo(0.7615941559557649, 1e-15));
      expect(jsTanh(10), closeTo(0.9999999958776927, 1e-15));
      expect(jsAsinh(1), closeTo(0.881373587019543, 1e-15));
      expect(jsAcosh(2), closeTo(1.3169578969248166, 1e-15));
      expect(jsAtanh(0.5), closeTo(0.5493061443340548, 1e-15));
      expect(jsSinh(-1), closeTo(-1.1752011936438014, 1e-15));
    });
  });
}
