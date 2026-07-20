import 'package:tinda360/core/failure.dart';

/// The outcome of an operation that can fail for an expected, recoverable
/// reason. Callers switch over [Ok] and [Err] exhaustively.
sealed class Result<T, F extends Failure> {
  const Result();
}

/// A successful [Result] carrying [value].
final class Ok<T, F extends Failure> extends Result<T, F> {
  /// Wraps a successful [value].
  const Ok(this.value);

  /// The produced value.
  final T value;
}

/// A failed [Result] carrying a typed [failure].
final class Err<T, F extends Failure> extends Result<T, F> {
  /// Wraps a typed [failure].
  const Err(this.failure);

  /// Why the operation failed.
  final F failure;
}
