import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Gives a subtree that cannot answer intrinsic-size questions (anything containing a `LayoutBuilder`, such as the
/// tab container) a stable intrinsic height.
///
/// The shell sizes a screen with `SliverFillRemaining(hasScrollBody: false)`, which asks the screen for its maximum
/// intrinsic height. A `LayoutBuilder` refuses that question. This wrapper answers it with the height the child had
/// the last time it was laid out ([estimate] before the first layout) and asks for one more layout when that height
/// changes, so the page grows with the content exactly like the CSS `min-h-full` column does.
class CachedIntrinsicHeight extends SingleChildRenderObjectWidget {
  const CachedIntrinsicHeight({super.key, this.estimate = 0, this.measureNatural = false, super.child});

  /// Height reported before the child has been laid out once.
  final double estimate;

  /// Lay the child out with an unbounded height and report the height it asks for. For a screen that is as tall as
  /// its content (the tool screens: the page scrolls when the content is taller than the window). The default, false,
  /// keeps the child inside the height it is given, which is what the keypad of the calculator needs.
  final bool measureNatural;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderCachedIntrinsicHeight(estimate, measureNatural);

  @override
  void updateRenderObject(BuildContext context, RenderCachedIntrinsicHeight renderObject) {
    renderObject.estimate = estimate;
    renderObject.measureNatural = measureNatural;
  }
}

class RenderCachedIntrinsicHeight extends RenderProxyBox {
  RenderCachedIntrinsicHeight(this._estimate, [this._measureNatural = false]);

  double _estimate;
  bool _measureNatural;
  double? _measured;

  set measureNatural(bool v) {
    if (v == _measureNatural) return;
    _measureNatural = v;
    markNeedsLayout();
  }

  set estimate(double v) {
    if (v == _estimate) return;
    _estimate = v;
  }

  double get _height => _measured ?? _estimate;

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  void performLayout() {
    final double h;
    if (_measureNatural && child != null) {
      child!.layout(constraints.copyWith(minHeight: 0, maxHeight: double.infinity), parentUsesSize: true);
      h = child!.size.height;
      size = constraints.constrain(Size(child!.size.width, h));
    } else {
      super.performLayout();
      h = size.height;
    }
    final previous = _measured;
    if (previous == null || (previous - h).abs() > 0.5) {
      _measured = h;
      // Ask the ancestors (which asked for the intrinsic height before this layout) to measure again.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) markParentNeedsLayout();
      });
    }
  }
}
