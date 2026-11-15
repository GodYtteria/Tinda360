import 'package:tinda360/core/failure.dart';

/// Why the store profile could not be saved.
sealed class StoreFailure extends Failure {
  const StoreFailure();
}

/// The store name is empty.
final class StoreNameRequired extends StoreFailure {
  /// Creates the failure.
  const StoreNameRequired();

  @override
  String get code => 'store.name_required';
}

/// The database could not complete the write.
final class StoreUnavailable extends StoreFailure {
  /// Creates the failure.
  const StoreUnavailable();

  @override
  String get code => 'store.unavailable';
}
