#!/usr/bin/env python3
"""Generates lib/engine/chemistry/elements.dart (Phase 6, Part 3.1).

Atomic masses: Appendix A of the master prompt (Z|symbol|name|mass, kept verbatim so the molar-mass tests stay stable).
Everything else: the `mendeleev` Python package (pip install mendeleev==1.3.0), copied as is. A value the dataset does
not have is written as null, never filled in. Deliberate omissions are listed in docs/CHEMISTRY_DATA.md notes:
  * Z >= 104: melting/boiling point, density, radius, electronegativity, electron affinity and ionisation energy are
    predicted or unmeasured, so they are null.
  * Gases: density depends on temperature and pressure, so it is null.
  * Electron affinity <= 0 (unbound anion) and noble gases: null.
  * Group, block, category, period and standard state are fixed facts derived from Z here, not from the dataset.

Run:  python3 -I flutter_app/tools/gen_elements.py > flutter_app/lib/engine/chemistry/elements.dart
"""
import re
import sys

from mendeleev import element

APPENDIX_A = """1|H|Hydrogen|1.008
2|He|Helium|4.0026
3|Li|Lithium|7
4|Be|Beryllium|9.012183
5|B|Boron|10.81
6|C|Carbon|12.011
7|N|Nitrogen|14.007
8|O|Oxygen|15.999
9|F|Fluorine|18.99840316
10|Ne|Neon|20.18
11|Na|Sodium|22.9897693
12|Mg|Magnesium|24.305
13|Al|Aluminum|26.981538
14|Si|Silicon|28.085
15|P|Phosphorus|30.973762
16|S|Sulfur|32.07
17|Cl|Chlorine|35.45
18|Ar|Argon|39.9
19|K|Potassium|39.0983
20|Ca|Calcium|40.08
21|Sc|Scandium|44.95591
22|Ti|Titanium|47.867
23|V|Vanadium|50.9415
24|Cr|Chromium|51.996
25|Mn|Manganese|54.93804
26|Fe|Iron|55.84
27|Co|Cobalt|58.93319
28|Ni|Nickel|58.693
29|Cu|Copper|63.55
30|Zn|Zinc|65.4
31|Ga|Gallium|69.723
32|Ge|Germanium|72.63
33|As|Arsenic|74.92159
34|Se|Selenium|78.97
35|Br|Bromine|79.9
36|Kr|Krypton|83.8
37|Rb|Rubidium|85.468
38|Sr|Strontium|87.62
39|Y|Yttrium|88.90584
40|Zr|Zirconium|91.22
41|Nb|Niobium|92.90637
42|Mo|Molybdenum|95.95
43|Tc|Technetium|96.90636
44|Ru|Ruthenium|101.1
45|Rh|Rhodium|102.9055
46|Pd|Palladium|106.42
47|Ag|Silver|107.868
48|Cd|Cadmium|112.41
49|In|Indium|114.818
50|Sn|Tin|118.71
51|Sb|Antimony|121.76
52|Te|Tellurium|127.6
53|I|Iodine|126.9045
54|Xe|Xenon|131.29
55|Cs|Cesium|132.905452
56|Ba|Barium|137.33
57|La|Lanthanum|138.9055
58|Ce|Cerium|140.116
59|Pr|Praseodymium|140.90766
60|Nd|Neodymium|144.24
61|Pm|Promethium|144.91276
62|Sm|Samarium|150.4
63|Eu|Europium|151.964
64|Gd|Gadolinium|157.2
65|Tb|Terbium|158.92535
66|Dy|Dysprosium|162.5
67|Ho|Holmium|164.93033
68|Er|Erbium|167.26
69|Tm|Thulium|168.93422
70|Yb|Ytterbium|173.05
71|Lu|Lutetium|174.9668
72|Hf|Hafnium|178.49
73|Ta|Tantalum|180.9479
74|W|Tungsten|183.84
75|Re|Rhenium|186.207
76|Os|Osmium|190.2
77|Ir|Iridium|192.22
78|Pt|Platinum|195.08
79|Au|Gold|196.96657
80|Hg|Mercury|200.59
81|Tl|Thallium|204.383
82|Pb|Lead|207
83|Bi|Bismuth|208.9804
84|Po|Polonium|208.98243
85|At|Astatine|209.98715
86|Rn|Radon|222.01758
87|Fr|Francium|223.01973
88|Ra|Radium|226.02541
89|Ac|Actinium|227.02775
90|Th|Thorium|232.038
91|Pa|Protactinium|231.03588
92|U|Uranium|238.0289
93|Np|Neptunium|237.048172
94|Pu|Plutonium|244.0642
95|Am|Americium|243.06138
96|Cm|Curium|247.07035
97|Bk|Berkelium|247.07031
98|Cf|Californium|251.07959
99|Es|Einsteinium|252.083
100|Fm|Fermium|257.09511
101|Md|Mendelevium|258.09843
102|No|Nobelium|259.101
103|Lr|Lawrencium|266.12
104|Rf|Rutherfordium|267.122
105|Db|Dubnium|268.126
106|Sg|Seaborgium|269.128
107|Bh|Bohrium|270.133
108|Hs|Hassium|269.1336
109|Mt|Meitnerium|277.154
110|Ds|Darmstadtium|282.166
111|Rg|Roentgenium|282.169
112|Cn|Copernicium|286.179
113|Nh|Nihonium|286.182
114|Fl|Flerovium|290.192
115|Mc|Moscovium|290.196
116|Lv|Livermorium|293.205
117|Ts|Tennessine|294.211
118|Og|Oganesson|295.216"""

SUP = str.maketrans('0123456789', '⁰¹²³⁴⁵⁶⁷⁸⁹')
GASES = {1, 2, 7, 8, 9, 10, 17, 18, 36, 54, 86}
LIQUIDS = {35, 80}
NOBLE = {2, 10, 18, 36, 54, 86, 118}
HALOGEN = {9, 17, 35, 53, 85, 117}
METALLOID = {5, 14, 32, 33, 51, 52}
NONMETAL = {1, 6, 7, 8, 15, 16, 34}
ALKALI = {3, 11, 19, 37, 55, 87}
ALKALINE = {4, 12, 20, 38, 56, 88}
POST = {13, 31, 49, 50, 81, 82, 83, 84, 113, 114, 115, 116}


def period(z):
    for p, last in enumerate((2, 10, 18, 36, 54, 86, 118), 1):
        if z <= last:
            return p


def group(z):
    if 57 <= z <= 71 or 89 <= z <= 103:
        return None
    if z == 1:
        return 1
    if z == 2:
        return 18
    p = period(z)
    first = {2: 3, 3: 11, 4: 19, 5: 37, 6: 55, 7: 87}[p] if p >= 2 else 1
    # offset inside the period, skipping the f-row for periods 6 and 7
    off = z - first
    if p in (6, 7):
        base = 55 if p == 6 else 87
        n = z - base
        if n <= 1:
            return n + 1
        # after the f-row: Hf (72) / Rf (104) is group 4
        f_end = 71 if p == 6 else 103
        return 4 + (z - (f_end + 1))
    if p == 2 or p == 3:
        return off + 1 if off < 2 else off + 11
    return off + 1


def block(z):
    if z in (1, 2) or group(z) in (1, 2):
        return 's'
    if 57 <= z <= 70 or 89 <= z <= 102:
        return 'f'
    if z in (71, 103):
        return 'd'
    g = group(z)
    return 'p' if g is not None and g >= 13 else 'd'


def category(z):
    if z in NOBLE: return 'Noble gas'
    if z in HALOGEN: return 'Halogen'
    if z in ALKALI: return 'Alkali metal'
    if z in ALKALINE: return 'Alkaline earth metal'
    if z in METALLOID: return 'Metalloid'
    if z in NONMETAL: return 'Nonmetal'
    if 57 <= z <= 71: return 'Lanthanide'
    if 89 <= z <= 103: return 'Actinide'
    if z in POST: return 'Post-transition metal'
    return 'Transition metal'


def sup_config(raw):
    if not raw:
        return None
    out = []
    for tok in raw.split():
        if tok.startswith('['):
            out.append(tok)
            continue
        m = re.fullmatch(r'(\d[spdfg])(\d*)', tok)
        if not m:
            raise SystemExit('unparsed econf token %r in %r' % (tok, raw))
        out.append(m.group(1) + (m.group(2) or '1').translate(SUP))
    return ' '.join(out)


def num(v, nd=None):
    if v is None:
        return 'null'
    v = float(v)
    s = repr(round(v, nd)) if nd is not None else repr(v)
    return s


def q(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"


rows = [r.split('|') for r in APPENDIX_A.splitlines()]
assert len(rows) == 118 and [int(r[0]) for r in rows] == list(range(1, 119))

out = []
w = out.append
w('// GENERATED FILE - DO NOT EDIT.')
w('// Source: flutter_app/tools/gen_elements.py (masses: master prompt Appendix A; other fields: mendeleev 1.3.0).')
w('// Regenerate: python3 -I flutter_app/tools/gen_elements.py > flutter_app/lib/engine/chemistry/elements.dart')
w('// A value the dataset does not have is null. Nothing is invented.')
w('')
w("import 'element_types.dart';")
w('')
w('const List<ChemElement> chemElements = [')
for z_s, sym, name, mass in rows:
    z = int(z_s)
    e = element(z)
    assert e.symbol == sym, (z, e.symbol, sym)
    superheavy = z >= 104
    std = None if superheavy else ('gas' if z in GASES else 'liquid' if z in LIQUIDS else 'solid')
    mp = None if superheavy else e.melting_point
    bp = None if superheavy else e.boiling_point
    dens = None if (superheavy or z in GASES) else e.density
    rad = None if superheavy else e.atomic_radius
    en = None if superheavy else e.en_pauling
    ie = None if superheavy else e.ionenergies.get(1)
    ea = e.electron_affinity
    if superheavy or z in NOBLE or ea is None or ea <= 0:
        ea = None
    ox = sorted(set(int(x) for x in (e.oxistates or [])))
    cpk = e.cpk_color
    cpk_v = 'null'
    if cpk and re.fullmatch(r'#[0-9a-fA-F]{6}', cpk):
        cpk_v = '0xFF' + cpk[1:].upper()
    year = e.discovery_year
    w('  ChemElement(')
    w('    z: %d,' % z)
    w('    symbol: %s,' % q(sym))
    w('    name: %s,' % q(name))
    w('    mass: %s,' % mass)
    w('    group: %s,' % (group(z) if group(z) is not None else 'null'))
    w('    period: %d,' % period(z))
    w("    block: %s," % q(block(z)))
    w('    category: %s,' % q(category(z)))
    w('    electronConfig: %s,' % (q(sup_config(e.econf)) if e.econf else 'null'))
    w('    electronegativity: %s,' % num(en))
    w('    atomicRadiusPm: %s,' % num(rad))
    w('    ionizationEnergyEv: %s,' % num(ie, 6))
    w('    electronAffinityEv: %s,' % num(ea, 6))
    w('    oxidationStates: [%s],' % ', '.join(str(x) for x in ox))
    w('    standardState: %s,' % (q(std) if std else 'null'))
    w('    meltingPointK: %s,' % num(mp, 3))
    w('    boilingPointK: %s,' % num(bp, 3))
    w('    densityGcm3: %s,' % num(dens))
    w('    yearDiscovered: %s,' % (int(year) if isinstance(year, (int, float)) or (isinstance(year, str) and year.isdigit()) else 'null'))
    w('    cpkColor: %s,' % cpk_v)
    w('  ),')
w('];')
sys.stdout.write('\n'.join(out) + '\n')
