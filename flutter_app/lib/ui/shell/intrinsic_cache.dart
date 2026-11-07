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
  const CachedIntrinsicHeight({super.key, this.estimate = 0, super.child});

  /// Height reported before the child has been laid out once.
  final double estimate;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderCachedIntrinsicHeight(estimate);

  @override
  void updateRenderObject(BuildContext context, RenderCachedIntrinsicHeight renderObject) {
    renderObject.estimate = estimate;
  }
}

class RenderCachedIntrinsicHeight extends RenderProxyBox {
  RenderCachedIntrinsicHeight(this._estimate);

  double _estimate;
  double? _measured;

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
    super.performLayout();
    final h = size.height;
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
