/// Base of every typed, recoverable failure.
///
/// A failure carries a stable [code] that the presentation layer maps to a
/// localized message. It never carries display text.
abstract class Failure {
  /// Const base constructor for failure subtypes.
  const Failure();

  /// A stable, localization-key-like identifier, e.g. `sale.no_lines`.
  String get code;
}
