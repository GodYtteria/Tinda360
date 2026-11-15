import 'package:tinda360/core/money/money.dart';

/// The fields entered to add a customer.
final class CustomerDraft {
  /// Creates a draft.
  const CustomerDraft({required this.name, this.phone, this.creditLimit});

  /// Display name.
  final String name;

  /// Optional mobile number.
  final String? phone;

  /// Optional credit limit.
  final Money? creditLimit;
}
