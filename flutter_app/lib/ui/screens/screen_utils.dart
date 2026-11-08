import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../services/feedback_service.dart';
import '../../state/settings_store.dart';

/// Tailwind's `sm` / `md` / `lg` / `xl` breakpoints, read from the window width like the CSS media queries.
class Breakpoints {
  const Breakpoints(this.width);

  factory Breakpoints.of(BuildContext context) => Breakpoints(MediaQuery.sizeOf(context).width);

  final double width;

  bool get sm => width >= 640;
  bool get md => width >= 768;
  bool get lg => width >= 1024;
  bool get xl => width >= 1280;

  /// `a sm:b` and similar: the value for the widest breakpoint that applies.
  T pick<T>(T base, {T? sm, T? md, T? lg, T? xl}) {
    if (this.xl && xl != null) return xl;
    if (this.lg && lg != null) return lg;
    if (this.md && md != null) return md;
    if (this.sm && sm != null) return sm;
    return base;
  }
}

/// `playSound` of the tool screens: the click sound if sound is on, then the haptic tick if haptics are on.
void playScreenSound(BuildContext context, ClickType type) {
  final settings = context.read<SettingsStore>().settings;
  final feedback = context.read<FeedbackService>();
  if (settings.soundEnabled) feedback.playClick(type);
  if (settings.hapticEnabled) feedback.triggerHaptic();
}
