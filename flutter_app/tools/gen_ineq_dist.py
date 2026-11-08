#!/usr/bin/env python3
"""Independent reference values for INEQ and DIST (Phase 7e, source of truth number 3). Polynomial roots, the normal curve,
the binomial and Poisson laws are computed with mpmath at 60 digits, never with the engine's own code.
Writes test/casio/ineq_dist.json.
Run:  python3 tools/gen_ineq_dist.py   (pip install mpmath)"""
import json, pathlib
from fractions import Fraction
from mpmath import mp, mpf, polyroots, exp, sqrt, erfc, factorial, binomial, nstr, findroot, ncdf, npdf

mp.dps = 60
out = {'ineq': [], 'dist': []}


def s(v):
    return nstr(v, 15, min_fixed=-200, max_fixed=200)


# ----- INEQ -------------------------------------------------------------------------------------------------------------
# (coefficients highest power first, relation)
INEQ = [
    ([1, 2, -3], '<'), ([1, 2, -3], '≥'), ([1, 2, -3], '>'), ([1, 2, -3], '≤'),
    ([1, 0, 0], '≥'), ([1, 0, 0], '>'), ([1, 0, 0], '<'), ([1, 0, 0], '≤'),
    ([-1, 0, 0], '≥'), ([-1, 0, 0], '≤'), ([1, 0, 1], '>'), ([1, 0, 1], '<'),
    ([2, -3, -6], '>'), ([2, -3, -6], '≤'), ([-2, 4, 1], '>'), ([1, -2, 1], '>'), ([1, -2, 1], '≥'), ([1, -2, 1], '≤'),
    ([2, -3, 0, 0], '≥'), ([3, 3, -1, 0], '>'), ([1, -2, -1, 2], '>'), ([1, -2, -1, 2], '≤'),
    ([-1, 0, 4, 0], '≥'), ([1, 0, 0, 0], '>'), ([1, 0, 0, 0], '≥'), ([1, -3, 3, -1], '>'), ([1, -3, 3, -1], '≤'),
    ([1, 0, 1, 0], '>'), ([1, 0, 1, 0], '<'),
]


def real_roots(coef):
    rs = polyroots([mpf(c) for c in coef], maxsteps=500, extraprec=200)
    reals = []
    for r in rs:
        if abs(r.imag) < mpf(10) ** -12:
            reals.append(r.real)
    reals.sort()
    distinct = []
    for r in reals:
        if distinct and abs(distinct[-1] - r) < mpf(10) ** -9:
            continue
        distinct.append(r)
    return distinct


def poly(coef, x):
    v = mpf(0)
    for c in coef:
        v = v * x + c
    return v


def solve(coef, rel):
    roots = real_roots(coef)
    pts = []
    if not roots:
        pts = [mpf(0)]
    else:
        pts.append(roots[0] - 1 - abs(roots[0]))
        pts += [(roots[i] + roots[i + 1]) / 2 for i in range(len(roots) - 1)]
        pts.append(roots[-1] + 1 + abs(roots[-1]))
    strict = rel in '<>'
    neg = rel in '<≤'
    inc = []
    for i, p in enumerate(pts):
        v = poly(coef, p)
        inc.append((v < 0) if neg else (v > 0))
        if i < len(roots):
            inc.append(not strict)
    if all(inc):
        return ['All Real Numbers']
    if not any(inc):
        return ['No-Solution']
    parts = []
    i = 0
    while i < len(inc):
        if not inc[i]:
            i += 1
            continue
        j = i
        while j + 1 < len(inc) and inc[j + 1]:
            j += 1
        # lower bound
        if i % 2 == 0:
            k = i // 2
            lo = None if k == 0 else (roots[k - 1], False)
        else:
            lo = (roots[(i - 1) // 2], True)
        if j % 2 == 0:
            k = j // 2
            hi = None if k == len(roots) else (roots[k], False)
        else:
            hi = (roots[(j - 1) // 2], True)
        parts.append({'lo': None if lo is None else {'v': s(lo[0]), 'closed': lo[1]},
                      'hi': None if hi is None else {'v': s(hi[0]), 'closed': hi[1]}})
        i = j + 1
    return parts


for coef, rel in INEQ:
    out['ineq'].append({'coef': coef, 'rel': rel, 'solution': solve(coef, rel)})

# ----- DIST -------------------------------------------------------------------------------------------------------------


def phi(t):
    return erfc(-t / sqrt(2)) / 2


def inv_phi(p):
    return findroot(lambda t: phi(t) - p, mpf(0) if p == mpf('0.5') else (mpf(-1) if p < 0.5 else mpf(1)), tol=mpf(10) ** -40, maxsteps=200)


for x, sg, mu in [(36, 2, 35), (0, 1, 0), (1.5, 0.5, 1), (-2, 3, 1), (10, 4, 8.5)]:
    z = (mpf(str(x)) - mpf(str(mu))) / mpf(str(sg))
    out['dist'].append({'type': 'normalPd', 'args': [x, sg, mu], 'value': s(exp(-z * z / 2) / (mpf(str(sg)) * sqrt(2 * mp.pi)))})
for lo, hi, sg, mu in [(-1, 1, 1, 0), (0, 2, 1, 1), (35, 38, 2, 35), (-5, 0.3, 2, 1), (90, 110, 15, 100)]:
    a = (mpf(str(lo)) - mpf(str(mu))) / mpf(str(sg))
    b = (mpf(str(hi)) - mpf(str(mu))) / mpf(str(sg))
    out['dist'].append({'type': 'normalCd', 'args': [lo, hi, sg, mu], 'value': s(phi(b) - phi(a))})
for area, sg, mu in [(0.5, 1, 0), (0.975, 1, 0), (0.025, 1, 0), (0.9, 2, 35), (0.3, 15, 100), (0.999, 1, 0)]:
    out['dist'].append({'type': 'invNorm', 'args': [area, sg, mu], 'value': s(mpf(str(mu)) + mpf(str(sg)) * inv_phi(mpf(str(area))))})
for x, n, p in [(10, 15, 0.6), (11, 15, 0.6), (12, 15, 0.6), (13, 15, 0.6), (14, 15, 0.6), (0, 10, 0.5), (5, 10, 0.5), (3, 8, 0.25), (40, 100, 0.4), (120, 200, 0.55)]:
    pm = mpf(str(p))
    pmf = binomial(n, x) * pm ** x * (1 - pm) ** (n - x)
    cdf = sum(binomial(n, k) * pm ** k * (1 - pm) ** (n - k) for k in range(x + 1))
    out['dist'].append({'type': 'binomPd', 'args': [x, n, p], 'value': s(pmf)})
    out['dist'].append({'type': 'binomCd', 'args': [x, n, p], 'value': s(cdf)})
for x, mu in [(0, 1), (1, 1), (3, 2.5), (10, 4), (7, 7), (25, 20.5)]:
    m = mpf(str(mu))
    pmf = exp(-m) * m ** x / factorial(x)
    cdf = sum(exp(-m) * m ** k / factorial(k) for k in range(x + 1))
    out['dist'].append({'type': 'poissonPd', 'args': [x, mu], 'value': s(pmf)})
    out['dist'].append({'type': 'poissonCd', 'args': [x, mu], 'value': s(cdf)})

path = pathlib.Path(__file__).resolve().parent.parent / 'test' / 'casio' / 'ineq_dist.json'
path.write_text(json.dumps(out, ensure_ascii=False, indent=1))
print('wrote', path, len(out['ineq']), 'ineq,', len(out['dist']), 'dist')
