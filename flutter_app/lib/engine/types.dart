/// Mirrors `src/types/index.ts` (engine-facing parts only; the rest arrives with the phase that uses it).
enum AngleMode {
  deg,
  rad;

  /// 'deg' | 'rad', the same strings the web app stores in settings.
  static AngleMode parse(String s) => s == 'rad' ? AngleMode.rad : AngleMode.deg;

  String get id => name;
}
