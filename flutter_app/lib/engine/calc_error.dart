/// The Dart counterpart of `throw new Error(message)` in the TypeScript engine.
///
/// The calculator shows `message` verbatim, so every message must match the TS source character for character.
class CalcError implements Exception {
  final String message;
  const CalcError(this.message);

  @override
  String toString() => message;
}
