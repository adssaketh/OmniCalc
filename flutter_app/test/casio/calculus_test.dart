// ∫, d/dx, Σ, ∏ of the Casio engine (Phase 7c). Worked examples are the guide's (page numbers in the names); the reference
// values are exact or from mpmath (tools/gen_casio_vectors.py).

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/engine/casio/calculus.dart';
import 'package:omnicalc/engine/casio/config.dart';
import 'package:omnicalc/engine/casio/cval.dart';
import 'package:omnicalc/engine/casio/engine.dart';

const rad = CasioConfig(angle: CasioAngle.rad);

CasioEngine make([CasioConfig cfg = rad]) => CasioEngine(config: cfg);

String shown(String expr, [CasioConfig cfg = rad]) => make(cfg).evaluate(expr).text;

String? err(String expr, [CasioConfig cfg = rad]) {
  try {
    make(cfg).evaluate(expr);
    return null;
  } on CasioError catch (e) {
    return e.message;
  }
}

void main() {
  group('integration (manual p.39-40)', () {
    test('p.39 example 1: ∫₁ᵉ ln(x) dx = 1', () {
      expect(shown('∫(ln(X),1,e)'), '1');
    });
    test('p.39 example 2: ∫(1÷X², 1, 5, 1×10⁻⁷) = 0.8', () {
      expect(shown('∫(1÷X²,1,5,1E-7)'), '0.8');
    });
    test('p.39 example 3: ∫₀^π (sin x + cos x)² dx = π (Rad, tol not specified)', () {
      expect(shown('∫((sin(X)+cos(X))²,0,π)'), 'π');
    });
    test('the photo: ∫₀^(π/2) cos(X) dX = 1 (Rad)', () {
      expect(shown('∫(cos(X),0,π÷2)'), '1');
    });
    test('a trigonometric f(x) follows the angle unit (the manual says to use Rad)', () {
      // in Deg the integrand is in degrees, so this is not 1
      expect(shown('∫(cos(X),0,90)', const CasioConfig()), isNot('1'));
    });
    test('reversed limits give the negative; equal limits give 0', () {
      expect(shown('∫(X²,2,0)'), '-2.666666667');
      expect(shown('∫(X²,3,3)'), '0');
    });
    test('polynomial and exponential reference values', () {
      expect(shown('∫(X²,0,2)'), '2.666666667');
      expect(shown('∫(e^X,0,1)'), '1.718281828');
      expect(shown('∫(1÷X,1,10)'), '2.302585093');
      expect(shown('∫(√(X),0,4)'), '5.333333333');
    });
    test('a log singularity at an end point still converges', () {
      expect(shown('∫(ln(X),0,1)'), '-1');
    });
    test('cancelling parts leave exactly 0 (not rounding noise)', () {
      expect(shown('∫(sin(X),0,2π)'), '0');
    });
    test('the integral takes part in arithmetic', () {
      expect(shown('2×∫(X,0,3)+1'), '10');
    });
    test('forbidden inside: ∫ d/dx Σ ∏ in f(x), a, b or tol; Pol, Rec, ÷R in f(x)', () {
      expect(err('∫(∫(X,0,1),0,1)'), 'Syntax ERROR');
      expect(err('∫(X,0,Σ(X,1,2))'), 'Syntax ERROR');
      expect(err('∫(X,0,1,d/dx(X,1))'), 'Syntax ERROR');
      expect(err('∫(Pol(X,1),0,1)'), 'Syntax ERROR');
      expect(err('∫(5÷R2,0,1)'), 'Syntax ERROR');
    });
    test('a domain error inside f(x) is the unit\'s own error', () {
      expect(err('∫(ln(X),-1,1)'), 'Math ERROR');
      expect(err('∫(1÷X,-1,1)'), 'Math ERROR');
    });
    test('tol: must be at least 1e-14', () {
      expect(err('∫(X,0,1,1E-15)'), 'Argument ERROR');
      expect(err('∫(X,0,1,0)'), 'Argument ERROR');
    });
    test('an integrand that does not converge ends in Time Out', () {
      expect(err('∫(sin(1÷X),0.0000001,1)'), 'Time Out');
    });
    test('syntax: wrong argument count, missing parenthesis', () {
      expect(err('∫(X,0)'), 'Syntax ERROR');
      expect(err('∫ X'), 'Syntax ERROR');
    });
    test('a cancel token stops the calculation', () {
      final e = make();
      final c = CasioCancel()..cancelled = true;
      e.cancel = c;
      expect(() => e.evaluate('∫(sin(1÷X),0.0000001,1)'), throwsA(isA<CasioCancelled>()));
    });
    test('the legacy calculation style still reaches the Casio calculus for the new symbols', () {
      expect(shown('∫(X²,0,2)', const CasioConfig(angle: CasioAngle.rad, useCasio: false)), '2.666666667');
    });
  });

  group('differentiation (manual p.41-42)', () {
    test('p.41 example 1: d/dx sin(x) at π/2 = 0 (Rad)', () {
      expect(shown('d/dx(sin(X),π÷2)'), '0');
    });
    test('p.41 example 2: d/dx(3x²−5x+2, 2, 1×10⁻¹²) = 7', () {
      expect(shown('d/dx(3X²−5X+2,2,1E-12)'), '7');
    });
    test('more derivatives', () {
      expect(shown('d/dx(X³,2)'), '12');
      expect(shown('d/dx(e^X,0)'), '1');
      expect(shown('d/dx(ln(X),2)'), '0.5');
      expect(shown('d/dx(sin(X),0)'), '1');
      expect(shown('d/dx(X²,0)'), '0');
    });
    test('the derivative of a big function at a big point stays relative', () {
      expect(shown('d/dx(X²,1000)'), '2000');
    });
    test('forbidden inside, like ∫', () {
      expect(err('d/dx(∫(X,0,1),1)'), 'Syntax ERROR');
      expect(err('d/dx(Rec(X,1),1)'), 'Syntax ERROR');
    });
    test('tol that cannot be met ends in Time Out; omitted tol adjusts itself', () {
      expect(err('d/dx(abs(X)+sin(1÷X),0.0001,1E-14)'), isNotNull);
      expect(shown('d/dx(abs(X),0)'), '0');
    });
    test('tol must be at least 1e-14', () {
      expect(err('d/dx(X,1,1E-15)'), 'Argument ERROR');
    });
  });

  group('Σ and ∏ (manual p.42-43)', () {
    test('p.42: Σ(x+1) for x=1..5 = 20', () {
      expect(shown('Σ(X+1,1,5)'), '20');
    });
    test('p.43: ∏(x+1) for x=1..5 = 720', () {
      expect(shown('∏(X+1,1,5)'), '720');
    });
    test('sums stay exact: Σ(1÷X,1,3) = 11/6', () {
      expect(shown('Σ(1÷X,1,3)'), '11⌟6');
    });
    test('a sum with a negative start and a single term', () {
      expect(shown('Σ(X²,-2,2)'), '10');
      expect(shown('Σ(X,4,4)'), '4');
    });
    test('the ∑ sign works as Σ', () {
      expect(shown('∑(X,1,100)'), '5050');
    });
    test('limits: −1e10 < a ≤ b < 1e10 for Σ; a < 1e10, b < 1e10, a ≤ b for ∏', () {
      expect(err('Σ(X,5,1)'), 'Argument ERROR');
      expect(err('Σ(X,-10000000000,1)'), 'Argument ERROR');
      expect(err('Σ(X,1,10000000000)'), 'Argument ERROR');
      expect(err('∏(X,5,1)'), 'Argument ERROR');
      expect(err('∏(X,1,10000000000)'), 'Argument ERROR');
      expect(err('Σ(X,1.5,3)'), 'Argument ERROR');
    });
    test('forbidden inside f(x), a, b', () {
      expect(err('Σ(Σ(X,1,2),1,2)'), 'Syntax ERROR');
      expect(err('Σ(X,1,∏(X,1,2))'), 'Syntax ERROR');
      expect(err('Σ(Pol(X,1),1,2)'), 'Syntax ERROR');
    });
    test('a product beyond the range of the unit is a Math ERROR', () {
      expect(err('∏(X,1,100)'), 'Math ERROR');
    });
    test('f(x) can use other variables (they are constants)', () {
      final e = make();
      e.evaluate('3→A');
      expect(e.evaluate('Σ(A×X,1,4)').text, '30');
    });
    test('Σ does not change the variable X of the memory', () {
      final e = make();
      e.evaluate('7→X');
      e.evaluate('Σ(X,1,3)');
      expect(e.memory.vars['X']!.v, 7);
    });
    test('an interrupted sum stops', () {
      final e = make();
      final c = CasioCancel()..cancelled = true;
      e.cancel = c;
      expect(() => e.evaluate('Σ(X,1,9999999)'), throwsA(isA<CasioCancelled>()));
    });
  });
}
