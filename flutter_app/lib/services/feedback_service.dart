import 'package:flutter/services.dart';

import '../state/app_settings.dart';

/// Which synthesized click `soundFx.playClick` plays (src/utils/audio.ts).
enum ClickType { num, op, eval, clear, toggle }

/// Key click sound and haptic tick (`soundFx` in src/utils/audio.ts).
abstract class FeedbackService {
  void setVibrationIntensity(VibrationIntensity intensity);
  VibrationIntensity get vibrationIntensity;

  void playClick(ClickType type);

  /// One haptic tick; [customIntensity] overrides the stored intensity for this tick.
  void triggerHaptic([VibrationIntensity? customIntensity]);
}

/// `navFeedback` (src/navigation.ts): click sound and haptic tick used by every navigation control.
void navFeedback(FeedbackService feedback, {required bool soundEnabled, required bool hapticEnabled}) {
  if (soundEnabled) feedback.playClick(ClickType.toggle);
  if (hapticEnabled) feedback.triggerHaptic();
}

/// Android implementation.
///
/// Haptics: the web app calls `navigator.vibrate(ms)` with 10 / 25 / 45 / 75 ms. Flutter's built-in `HapticFeedback`
/// has no duration, so the four intensities map to its light, medium and heavy impacts and the system vibration; this
/// is an approximation of the durations, not an exact match (see PHASE3_NOTES.md, open question).
///
/// Sound: the web app synthesizes a short mechanical click with the Web Audio API. Reproducing it needs an audio
/// package, which arrives with the calculator keys in Phase 4, so [playClick] is silent until then.
class PlatformFeedbackService implements FeedbackService {
  VibrationIntensity _intensity = VibrationIntensity.medium;

  @override
  VibrationIntensity get vibrationIntensity => _intensity;

  @override
  void setVibrationIntensity(VibrationIntensity intensity) => _intensity = intensity;

  @override
  void playClick(ClickType type) {}

  @override
  void triggerHaptic([VibrationIntensity? customIntensity]) {
    switch (customIntensity ?? _intensity) {
      case VibrationIntensity.light:
        HapticFeedback.lightImpact();
      case VibrationIntensity.medium:
        HapticFeedback.mediumImpact();
      case VibrationIntensity.strong:
        HapticFeedback.heavyImpact();
      case VibrationIntensity.intense:
        HapticFeedback.vibrate();
    }
  }
}

/// Records calls instead of producing sound or vibration. For tests and previews.
class SilentFeedbackService implements FeedbackService {
  VibrationIntensity _intensity = VibrationIntensity.medium;
  final List<String> log = <String>[];

  @override
  VibrationIntensity get vibrationIntensity => _intensity;

  @override
  void setVibrationIntensity(VibrationIntensity intensity) => _intensity = intensity;

  @override
  void playClick(ClickType type) => log.add('click:${type.name}');

  @override
  void triggerHaptic([VibrationIntensity? customIntensity]) => log.add('haptic:${(customIntensity ?? _intensity).name}');
}
