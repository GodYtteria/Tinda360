import 'package:tinda360/core/failure.dart';

sealed class StoreFailure extends Failure {
  const new();
}

final class StoreNameRequired extends StoreFailure {
  const new();

  @override
  String get code => 'store.name_required';
}

final class StoreUnavailable extends StoreFailure {
  const new();

  @override
  String get code => 'store.unavailable';
}
