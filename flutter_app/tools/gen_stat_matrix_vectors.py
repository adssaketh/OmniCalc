#!/usr/bin/env python3
"""Independent reference values for STAT, MATRIX and VECTOR (Phase 7d-2, source of truth number 3). Statistics and the normal
curve are computed with mpmath at 60 digits, matrices and vectors with exact fractions, never with the engine's own code.
Writes test/casio/stat_matrix_vectors.json.
Run:  python3 tools/gen_stat_matrix_vectors.py   (pip install mpmath)"""
import json, pathlib
from fractions import Fraction
from mpmath import mp, mpf, log, exp, sqrt, erfc, nstr, matrix, lu_solve

mp.dps = 60
out = {'stat': [], 'normal': [], 'matrix': [], 'vector': []}


def s(v):
    return nstr(v, 15, min_fixed=-200, max_fixed=200)


# ----- STAT -------------------------------------------------------------------------------------------------------------
DATASETS = [
    {'x': [1, 2, 3, 4, 5, 7], 'y': [2.1, 3.9, 6.2, 7.8, 10.1, 14.2], 'f': [1, 2, 1, 3, 1, 2]},
    {'x': [20, 110, 200, 290], 'y': [3150, 7310, 8800, 9310], 'f': [1, 1, 1, 1]},
    {'x': [0.5, 1.5, 2.5, 4, 6], 'y': [1.2, 2.9, 5.1, 11.8, 30.5], 'f': [2, 1, 1, 1, 3]},
]


def linfit(u, v, f):
    S = sum(mpf(w) for w in f)
    Su = sum(mpf(w) * a for w, a in zip(f, u))
    Sv = sum(mpf(w) * a for w, a in zip(f, v))
    Suu = sum(mpf(w) * a * a for w, a in zip(f, u))
    Suv = sum(mpf(w) * a * b for w, a, b in zip(f, u, v))
    Svv = sum(mpf(w) * b * b for w, b in zip(f, v))
    B = (S * Suv - Su * Sv) / (S * Suu - Su ** 2)
    A = (Sv - B * Su) / S
    r = (S * Suv - Su * Sv) / sqrt((S * Suu - Su ** 2) * (S * Svv - Sv ** 2))
    return A, B, r


for ds in DATASETS:
    x = [mpf(str(a)) for a in ds['x']]
    y = [mpf(str(a)) for a in ds['y']]
    f = ds['f']
    n = sum(f)
    entry = {'data': ds, 'n': n}
    sx = sum(mpf(w) * a for w, a in zip(f, x))
    mean = sx / n
    entry['mean'] = s(mean)
    entry['sigx'] = s(sqrt(sum(mpf(w) * (a - mean) ** 2 for w, a in zip(f, x)) / n))
    entry['sx'] = s(sqrt(sum(mpf(w) * (a - mean) ** 2 for w, a in zip(f, x)) / (n - 1)))
    regs = {}
    A, B, r = linfit(x, y, f)
    regs['linear'] = {'A': s(A), 'B': s(B), 'r': s(r), 'yhat': s(A + B * mpf('3.3')), 'xhat': s((mpf('6') - A) / B), 'x0': '3.3', 'y0': '6'}
    A, B, r = linfit([log(a) for a in x], y, f)
    regs['ln'] = {'A': s(A), 'B': s(B), 'r': s(r), 'yhat': s(A + B * log(mpf('3.3'))), 'xhat': s(exp((mpf('6') - A) / B)), 'x0': '3.3', 'y0': '6'}
    a, b, r = linfit(x, [log(c) for c in y], f)
    regs['exp'] = {'A': s(exp(a)), 'B': s(b), 'r': s(r), 'yhat': s(exp(a) * exp(b * mpf('3.3'))), 'xhat': s(log(mpf('6') / exp(a)) / b), 'x0': '3.3', 'y0': '6'}
    regs['abExp'] = {'A': s(exp(a)), 'B': s(exp(b)), 'r': s(r), 'yhat': s(exp(a) * exp(b) ** mpf('3.3')), 'xhat': s(log(mpf('6') / exp(a)) / log(exp(b))), 'x0': '3.3', 'y0': '6'}
    a, b, r = linfit([log(c) for c in x], [log(c) for c in y], f)
    regs['power'] = {'A': s(exp(a)), 'B': s(b), 'r': s(r), 'yhat': s(exp(a) * mpf('3.3') ** b), 'xhat': s((mpf('6') / exp(a)) ** (1 / b)), 'x0': '3.3', 'y0': '6'}
    A, B, r = linfit([1 / c for c in x], y, f)
    regs['inverse'] = {'A': s(A), 'B': s(B), 'r': s(r), 'yhat': s(A + B / mpf('3.3')), 'xhat': s(B / (mpf('6') - A)), 'x0': '3.3', 'y0': '6'}
    S = [sum(mpf(w) * a ** k for w, a in zip(f, x)) for k in range(5)]
    T = [sum(mpf(w) * a ** k * b for w, a, b in zip(f, x, y)) for k in range(3)]
    sol = lu_solve(matrix([[S[0], S[1], S[2]], [S[1], S[2], S[3]], [S[2], S[3], S[4]]]), matrix(T))
    A, B, C = sol[0], sol[1], sol[2]
    disc = B ** 2 - 4 * C * (A - mpf('6'))
    regs['quadratic'] = {'A': s(A), 'B': s(B), 'C': s(C), 'yhat': s(A + B * mpf('3.3') + C * mpf('3.3') ** 2), 'x0': '3.3', 'y0': '6',
                         'xhat1': s((-B + sqrt(disc)) / (2 * C)) if disc > 0 else None, 'xhat2': s((-B - sqrt(disc)) / (2 * C)) if disc > 0 else None}
    entry['reg'] = regs
    out['stat'].append(entry)

for t in ['-3', '-1.5', '-0.762', '0', '0.4', '1', '2.2', '4.5']:
    tv = mpf(t)
    cdf = erfc(-tv / sqrt(2)) / 2
    out['normal'].append({'t': t, 'P': s(cdf), 'Q': s(cdf - mpf('0.5')), 'R': s(1 - cdf)})


# ----- MATRIX / VECTOR (exact fractions) ----------------------------------------------------------------------------------
def fr(m):
    return [[str(Fraction(c)) for c in row] for row in m]


def mmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(len(b))) for j in range(len(b[0]))] for i in range(len(a))]


def det(m):
    n = len(m)
    if n == 1:
        return m[0][0]
    if n == 2:
        return m[0][0] * m[1][1] - m[0][1] * m[1][0]
    return sum((-1) ** j * m[0][j] * det([row[:j] + row[j + 1:] for row in m[1:]]) for j in range(n))


def rref(m, reduced=True):
    m = [[Fraction(c) for c in row] for row in m]
    rows, cols = len(m), len(m[0])
    r = 0
    for c in range(cols):
        p = next((i for i in range(r, rows) if m[i][c] != 0), None)
        if p is None:
            continue
        m[r], m[p] = m[p], m[r]
        pv = m[r][c]
        m[r] = [v / pv for v in m[r]]
        for i in range(rows):
            if i != r and (reduced or i > r) and m[i][c] != 0:
                f = m[i][c]
                m[i] = [a - f * b for a, b in zip(m[i], m[r])]
        r += 1
        if r == rows:
            break
    return m


def inv(m):
    n = len(m)
    aug = [[Fraction(c) for c in row] + [Fraction(int(i == j)) for j in range(n)] for i, row in enumerate(m)]
    red = rref(aug)
    return [row[n:] for row in red]


MATS = [
    [[2, 1], [1, 1]],
    [[2, 1], [1, 2]],
    [[1, 0, 1], [0, 1, 1]],
    [[1, 2, 3], [0, 1, 4], [5, 6, 0]],
    [[2, -1, 0], [-1, 2, -1], [0, -1, 2]],
    [[3, 0, 2], [2, 0, -2], [0, 1, 1]],
    [[1, 2], [3, 4]],
    [[4, 7], [2, 6]],
]
sq = [m for m in MATS if len(m) == len(m[0])]
for m in MATS:
    out['matrix'].append({'op': 'trn', 'a': m, 'result': fr([[m[i][j] for i in range(len(m))] for j in range(len(m[0]))])})
    out['matrix'].append({'op': 'ref', 'a': m, 'result': fr(rref(m, reduced=False))})
    out['matrix'].append({'op': 'rref', 'a': m, 'result': fr(rref(m))})
for m in sq:
    out['matrix'].append({'op': 'det', 'a': m, 'result': str(Fraction(det(m)))})
    if det(m) != 0:
        out['matrix'].append({'op': 'inv', 'a': m, 'result': fr(inv(m))})
    out['matrix'].append({'op': 'sq', 'a': m, 'result': fr(mmul(m, m))})
    out['matrix'].append({'op': 'cube', 'a': m, 'result': fr(mmul(mmul(m, m), m))})
for a in MATS:
    for b in MATS:
        if len(a[0]) == len(b):
            out['matrix'].append({'op': 'mul', 'a': a, 'b': b, 'result': fr(mmul(a, b))})
        if len(a) == len(b) and len(a[0]) == len(b[0]):
            out['matrix'].append({'op': 'add', 'a': a, 'b': b, 'result': fr([[x + y for x, y in zip(r1, r2)] for r1, r2 in zip(a, b)])})
            out['matrix'].append({'op': 'sub', 'a': a, 'b': b, 'result': fr([[x - y for x, y in zip(r1, r2)] for r1, r2 in zip(a, b)])})

VECS = [[1, 2], [3, 4], [2, -1, 2], [1, 0, -1], [-2, 5, 3], [4, 4]]
for a in VECS:
    out['vector'].append({'op': 'abs2', 'a': a, 'result': str(sum(c * c for c in a))})
    for b in VECS:
        if len(a) == len(b):
            out['vector'].append({'op': 'dot', 'a': a, 'b': b, 'result': str(sum(x * y for x, y in zip(a, b)))})
            a3 = a + [0] * (3 - len(a))
            b3 = b + [0] * (3 - len(b))
            cross = [a3[1] * b3[2] - a3[2] * b3[1], a3[2] * b3[0] - a3[0] * b3[2], a3[0] * b3[1] - a3[1] * b3[0]]
            out['vector'].append({'op': 'cross', 'a': a, 'b': b, 'result': [str(c) for c in cross]})
            out['vector'].append({'op': 'add', 'a': a, 'b': b, 'result': [str(x + y) for x, y in zip(a, b)]})
            out['vector'].append({'op': 'sub', 'a': a, 'b': b, 'result': [str(x - y) for x, y in zip(a, b)]})

path = pathlib.Path(__file__).resolve().parent.parent / 'test' / 'casio' / 'stat_matrix_vectors.json'
path.write_text(json.dumps(out, indent=1))
print('wrote', path, {k: len(v) for k, v in out.items()})
