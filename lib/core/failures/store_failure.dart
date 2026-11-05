import 'package:tinda360/core/failure.dart';

sealed class StoreFailure extends Failure {
  const StoreFailure();
}

final class StoreNameRequired extends StoreFailure {
  const StoreNameRequired();

  @override
  String get code => 'store.name_required';
}

final class StoreUnavailable extends StoreFailure {
  const StoreUnavailable();

  @override
  String get code => 'store.unavailable';
}
