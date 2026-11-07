import 'package:flutter_test/flutter_test.dart';
import 'package:omnicalc/state/app_settings.dart';
import 'package:omnicalc/theme/edge_effects.dart';

import '../golden/golden_loader.dart';

// Vectors produced by running the real src/edgeEffects.ts (tools/gen_shell_vectors.ts).
void main() {
  final data = loadGolden('edge_effects') as Map<String, dynamic>;
  final fills = (data['fills'] as List).cast<Map<String, dynamic>>();
  final masks = (data['masks'] as List).cast<Map<String, dynamic>>();
  final blurs = (data['blur'] as List).cast<Map<String, dynamic>>();

  test('golden file is present and non-trivial', () {
    expect(fills.length, greaterThanOrEqualTo(20));
    expect(masks.length, 90);
    expect(blurs.length, 6);
  });

  group('glass fill', () {
    for (final f in fills) {
      final t = f['t'] as num;
      test('transparency $t', () {
        expect(glassFillPercent(t), f['fill']);
        expect(glassFillStrongPercent(t), f['strong']);
      });
    }
  });

  group('edge mask', () {
    for (final m in masks) {
      final effect = EdgeEffect.values.byName(m['effect'] as String);
      final bar = BarStyle.values.byName(m['bar'] as String);
      final fade = FadeHeight.values.byName(m['fadeHeight'] as String);
      final label = '${m['effect']}/${m['bar']}/${m['fadeHeight']} '
          'topEdge=${m['topEdge']} topGlow=${m['topGlow']} bottomH=${m['bottomH']}';
      test(label, () {
        final spec = EdgeMaskSpec.build(
          EdgeGeometry(
            topEdge: (m['topEdge'] as num).toDouble(),
            topGlow: (m['topGlow'] as num).toDouble(),
            bottomH: (m['bottomH'] as num).toDouble(),
            fadePx: fadePx[fade]!,
          ),
          effect,
          bar,
        );
        final expected = m['stops'] as List?;
        if (expected == null) {
          expect(spec, isNull);
          return;
        }
        expect(spec, isNotNull);
        expect(spec!.stops.length, expected.length);
        for (var i = 0; i < expected.length; i++) {
          final e = expected[i] as List;
          final s = spec.stops[i];
          expect(s.fromBottom, e[0], reason: 'stop $i side');
          expect(s.offset, closeTo((e[1] as num).toDouble(), 1e-9), reason: 'stop $i position');
          expect(1 - s.alpha, closeTo((e[2] as num).toDouble(), 1e-9), reason: 'stop $i alpha');
        }
      });
    }
  });

  group('blur layers', () {
    for (final b in blurs) {
      test('barH=${b['barH']} fade=${b['fade']}', () {
        final layers = buildBlurLayers((b['barH'] as num).toDouble(), (b['fade'] as num).toDouble());
        final expected = (b['layers'] as List).cast<Map<String, dynamic>>();
        expect(layers.length, expected.length);
        for (var k = 0; k < expected.length; k++) {
          expect(layers[k].blurPx, (expected[k]['blurPx'] as num).toDouble());
          expect(layers[k].height, expected[k]['height']);
          final stops = expected[k]['stops'] as List;
          expect(layers[k].stops.length, stops.length);
          for (var i = 0; i < stops.length; i++) {
            expect(layers[k].stops[i].$1, closeTo((stops[i][0] as num).toDouble(), 1e-9));
            expect(layers[k].stops[i].$2, closeTo((stops[i][1] as num).toDouble(), 1e-9));
          }
        }
      });
    }
  });

  test('edge fade strengths: quantised to 0.02 over 48 px', () {
    final f = EdgeFade();
    f.updateFromScroll(pixels: 0, maxScrollExtent: 1000);
    expect(f.top, 0);
    expect(f.bottom, 1);
    f.updateFromScroll(pixels: 24, maxScrollExtent: 1000);
    expect(f.top, 0.5);
    f.updateFromScroll(pixels: 10, maxScrollExtent: 1000); // 10 / 48 = 0.2083 -> 0.2
    expect(f.top, 0.2);
    f.updateFromScroll(pixels: 990, maxScrollExtent: 1000); // 10 / 48 from the end
    expect(f.bottom, 0.2);
    f.updateFromScroll(pixels: 1000, maxScrollExtent: 1000);
    expect(f.bottom, 0);
    f.updateFromScroll(pixels: -30, maxScrollExtent: 1000); // overscroll never goes negative
    expect(f.top, 0);
  });
}
