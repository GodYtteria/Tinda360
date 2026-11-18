import 'package:tinda360/core/money/money.dart';

final class CustomerDraft {
  const new({
    required this.name,
    this.phone,
    this.creditLimit,
    this.interestPercentTenths,
  });

  final String name;

  final String? phone;

  final Money? creditLimit;

  final int? interestPercentTenths;
}
