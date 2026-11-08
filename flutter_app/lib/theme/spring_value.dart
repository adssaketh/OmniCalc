import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// A number that chases its target with a spring, keeping its velocity when the target changes mid-flight. This is how
/// motion's shared-layout pill (`layoutId`) travels between navigation destinations (src/motion.ts `springBouncy`).
class SpringValue extends ChangeNotifier {
  SpringValue({required TickerProvider vsync, required this.spring, double initial = 0})
      : _value = initial,
        _target = initial {
    _ticker = vsync.createTicker(_onTick);
  }

  final SpringDescription spring;

  late final Ticker _ticker;
  SpringSimulation? _sim;
  double _value;
  double _velocity = 0;
  double _target;

  double get value => _value;
  double get target => _target;
  bool get isAnimating => _ticker.isActive;

  /// When true the value jumps to every new target (the phone's "remove animations" setting).
  bool instant = false;

  void animateTo(double target) {
    if (target == _target) return;
    if (instant) {
      jumpTo(target);
      return;
    }
    _target = target;
    _sim = SpringSimulation(spring, _value, target, _velocity);
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void jumpTo(double v) {
    if (_ticker.isActive) _ticker.stop();
    _value = v;
    _target = v;
    _velocity = 0;
    _sim = null;
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final sim = _sim;
    if (sim == null) return;
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _value = sim.x(t);
    _velocity = sim.dx(t);
    if (sim.isDone(t)) {
      _value = _target;
      _velocity = 0;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
