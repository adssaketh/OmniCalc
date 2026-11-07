import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A number that moves like a CSS `transition` on a registered custom property:
/// when the target changes it eases from the *current* value to the new target over [delay] + [duration], applying
/// [curve] to the progress of [duration] only (the delay holds the start value). A new target mid-flight restarts
/// from wherever the value is right now, the same as the browser.
///
/// Used by the collapsing header, whose four numbers (`--hc`, `--hl`, `--hr`, `--hn` in src/index.css) each have
/// their own duration, delay and overshooting curve.
class CssTransitionValue extends ChangeNotifier {
  CssTransitionValue({
    required TickerProvider vsync,
    required this.duration,
    required this.curve,
    this.delay = Duration.zero,
    double initial = 0,
  })  : _value = initial,
        _from = initial,
        _target = initial {
    _ticker = vsync.createTicker(_onTick);
  }

  final Duration duration;
  final Duration delay;
  final Curve curve;

  late final Ticker _ticker;
  double _value;
  double _from;
  double _target;

  /// When true the value jumps straight to every new target (the phone's "remove animations" setting).
  bool instant = false;

  double get value => _value;
  double get target => _target;

  void animateTo(double target) {
    if (target == _target) return;
    if (instant) {
      jumpTo(target);
      return;
    }
    _from = _value;
    _target = target;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void jumpTo(double v) {
    if (_ticker.isActive) _ticker.stop();
    _value = v;
    _from = v;
    _target = v;
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final total = delay + duration;
    if (elapsed >= total) {
      _ticker.stop();
      _value = _target;
      _from = _target;
      notifyListeners();
      return;
    }
    if (elapsed <= delay) {
      _value = _from;
    } else {
      final p = (elapsed - delay).inMicroseconds / duration.inMicroseconds;
      _value = _from + (_target - _from) * curve.transform(p.clamp(0.0, 1.0));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
