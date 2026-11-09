import 'package:tinda360/core/failure.dart';

sealed class Result<T, F extends Failure> {
  const new();
}

final class Ok<T, F extends Failure> extends Result<T, F> {
  const new(this.value);

  final T value;
}

final class Err<T, F extends Failure> extends Result<T, F> {
  const new(this.failure);

  final F failure;
}
