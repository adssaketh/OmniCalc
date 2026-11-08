#!/usr/bin/env python3
"""Independent reference values for the Casio engine (source of truth number 3). Computed with mpmath at 60 digits, never with
the engine's own code. Writes test/casio/vectors.json: {expr, angle, value} where value is the exact result to 15 digits.
Run:  python3 tools/gen_casio_vectors.py   (pip install mpmath)"""
import json, pathlib
from mpmath import mp, mpf, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, asinh, acosh, atanh, log, exp, sqrt, cbrt, factorial, pi, nstr, binomial, root

mp.dps = 60
out = []

def add(expr, value, angle='deg'):
    out.append({'expr': expr, 'angle': angle, 'value': nstr(value, 15, min_fixed=-200, max_fixed=200)})

to_rad = {'deg': pi / 180, 'rad': mpf(1), 'gra': pi / 200}
for angle in ('deg', 'rad', 'gra'):
    for x in ['1', '7', '12.5', '33', '89', '100', '123.456', '250', '1000', '0.5']:
        r = mpf(x) * to_rad[angle]
        if angle == 'deg' and x in ('90',):
            continue
        add('sin(%s)' % x, sin(r), angle)
        add('cos(%s)' % x, cos(r), angle)
        if abs(cos(r)) > mpf('1e-6'):
            add('tan(%s)' % x, tan(r), angle)
    for x in ['0.1', '0.5', '0.9', '-0.3']:
        v = mpf(x)
        f = 1 / to_rad[angle]
        add('asin(%s)' % x, asin(v) * f, angle)
        add('acos(%s)' % x, acos(v) * f, angle)
    for x in ['0.5', '2', '10', '-7', '1000']:
        add('atan(%s)' % x, atan(mpf(x)) / to_rad[angle], angle)

for x in ['0.5', '1', '2', '3.7', '-1.5', '10']:
    add('sinh(%s)' % x, sinh(mpf(x)))
    add('cosh(%s)' % x, cosh(mpf(x)))
    add('tanh(%s)' % x, tanh(mpf(x)))
    add('asinh(%s)' % x, asinh(mpf(x)))
for x in ['1.5', '2', '10', '100']:
    add('acosh(%s)' % x, acosh(mpf(x)))
for x in ['0.5', '-0.9', '0.1']:
    add('atanh(%s)' % x, atanh(mpf(x)))
for x in ['0.5', '2', '10', '123.456', '1e-5', '9e50']:
    add('ln(%s)' % x, log(mpf(x)))
    add('log(%s)' % x, log(mpf(x), 10))
for x in ['0', '1', '2.5', '-3', '10', '100', '-100']:
    add('e^(%s)' % x, exp(mpf(x)))
for x in ['0.5', '2', '3', '7', '99.5', '1234.5678']:
    add('√(%s)' % x, sqrt(mpf(x)))
    add('³√(%s)' % x, cbrt(mpf(x)))
for a, b in [('2', '0.5'), ('2', '10.5'), ('7', '3'), ('0.5', '3'), ('10', '-2'), ('1.5', '2.5'), ('3', '13'), ('9', '0.5')]:
    add('%s^%s' % (a, b), mpf(a) ** mpf(b))
for n in [0, 1, 5, 10, 20, 30, 50, 69]:
    add('%d!' % n, factorial(n))
for n, r in [(10, 4), (52, 5), (30, 15), (100, 3), (7, 7), (7, 0)]:
    add('%dnCr%d' % (n, r), binomial(n, r))
    add('%dnPr%d' % (n, r), factorial(n) / factorial(n - r))
for expr, v in [('1÷3', mpf(1) / 3), ('22÷7', mpf(22) / 7), ('2÷3+5÷7', mpf(2) / 3 + mpf(5) / 7), ('√2+√3', sqrt(2) + sqrt(3)),
                ('π', pi), ('π×π', pi * pi), ('e', exp(1)), ('2π', 2 * pi), ('√(2)×√(8)', mpf(4)), ('log(2,1024)', mpf(10))]:
    add(expr, v)

# Phase 7c: calculus (rad). mpmath quad / diff / nsum are independent of the engine's Gauss-Kronrod and Ridders code.
from mpmath import quad, diff, mpf as _m, nsum, nprod, inf
def calc(expr, value):
    add(expr, value, 'rad')
for f, ftxt, a, b in [(lambda x: x**2, 'X²', 0, 2), (lambda x: exp(x), 'e^(X)', 0, 1), (lambda x: 1 / x, '1÷X', 1, 10),
                      (lambda x: sqrt(x), '√(X)', 0, 4), (lambda x: sin(x), 'sin(X)', 0, 1), (lambda x: cos(x) ** 2, 'cos(X)²', 0, 3),
                      (lambda x: log(x), 'ln(X)', 1, 5), (lambda x: x * exp(-x), 'X×e^(-X)', 0, 4),
                      (lambda x: 1 / (1 + x ** 2), '1÷(1+X²)', -3, 3), (lambda x: x ** 3 - 2 * x, 'X³−2X', -1, 2.5)]:
    calc('∫(%s,%s,%s)' % (ftxt, a, b), quad(f, [a, b]))
for f, ftxt, a in [(lambda x: x ** 3, 'X³', 2), (lambda x: exp(x), 'e^(X)', 1.5), (lambda x: log(x), 'ln(X)', 3),
                   (lambda x: sin(x), 'sin(X)', 0.7), (lambda x: x ** 2 * cos(x), 'X²cos(X)', 1.2), (lambda x: 1 / x, '1÷X', 4)]:
    calc('d/dx(%s,%s)' % (ftxt, a), diff(f, mpf(str(a))))
for ftxt, f, a, b in [('X²', lambda k: k ** 2, 1, 10), ('1÷X', lambda k: _m(1) / k, 1, 8), ('X+1', lambda k: k + 1, 1, 5)]:
    calc('Σ(%s,%d,%d)' % (ftxt, a, b), sum(f(_m(k)) for k in range(a, b + 1)))
for ftxt, f, a, b in [('X+1', lambda k: k + 1, 1, 5), ('X', lambda k: k, 1, 10), ('1+1÷X', lambda k: 1 + _m(1) / k, 1, 6)]:
    p = _m(1)
    for k in range(a, b + 1):
        p *= f(_m(k))
    calc('∏(%s,%d,%d)' % (ftxt, a, b), p)
# the unit holds pi and e with 15 digits (manual p.36): the reference values are the rounded ones
for o in out:
    if o['expr'] in ('π', 'e'):
        o['value'] = {'π': '3.1415926535898', 'e': '2.71828182845904'}[o['expr']]
json.dump(out, open(pathlib.Path(__file__).resolve().parent.parent / 'test/casio/vectors.json', 'w'), ensure_ascii=False, indent=0)
print(len(out), 'vectors')
