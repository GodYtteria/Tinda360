import 'package:tinda360/core/money/money.dart';

/// A suki who can buy on credit.
final class Customer {
  /// Creates a customer.
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.creditLimit,
  });

  /// Stable identifier.
  final String id;

  /// Display name.
  final String name;

  /// Optional mobile number.
  final String? phone;

  /// Optional maximum utang; the app warns, it does not block.
  final Money? creditLimit;

  @override
  bool operator ==(Object other) =>
      other is Customer &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.creditLimit == creditLimit;

  @override
  int get hashCode => Object.hash(id, name, phone, creditLimit);
}
