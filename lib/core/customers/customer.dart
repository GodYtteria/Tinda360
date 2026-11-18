import 'package:tinda360/core/money/money.dart';

final class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.creditLimit,
    this.interestPercentTenths,
  });

  final String id;

  final String name;

  final String? phone;

  final Money? creditLimit;

  final int? interestPercentTenths;

  @override
  bool operator ==(Object other) =>
      other is Customer &&
      other.id == id &&
      other.name == name &&
      other.phone == phone &&
      other.creditLimit == creditLimit &&
      other.interestPercentTenths == interestPercentTenths;

  @override
  int get hashCode =>
      Object.hash(id, name, phone, creditLimit, interestPercentTenths);
}
