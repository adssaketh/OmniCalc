import 'package:flutter/widgets.dart';

/// Tailwind's default `transition` curve: `cubic-bezier(0.4, 0, 0.2, 1)`.
const Cubic kTailwindEase = Cubic(0.4, 0, 0.2, 1);

/// Duration of Tailwind's default `transition-*` utilities.
const Duration kTailwindDuration = Duration(milliseconds: 150);

/// A tap target that shrinks while it is held, the CSS `active:scale-95` (or `active:scale-90`) plus
/// `transition-all` / `transition-transform` (150 ms, Tailwind's ease). Nothing else is drawn: the child brings its own
/// background, as the buttons of the web app do.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child, this.pressedScale = 0.95});

  final VoidCallback? onTap;
  final Widget child;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: kTailwindDuration,
        curve: kTailwindEase,
        child: widget.child,
      ),
    );
  }
}
