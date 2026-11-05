import 'package:tinda360/core/money/currency.dart';

final class StoreProfile {
  const StoreProfile({
    required this.name,
    required this.currency,
    required this.onboardingDone,
    this.address,
    this.phone,
  });

  final String name;

  final Currency currency;

  final bool onboardingDone;

  final String? address;

  final String? phone;

  @override
  bool operator ==(Object other) =>
      other is StoreProfile &&
      other.name == name &&
      other.currency == currency &&
      other.onboardingDone == onboardingDone &&
      other.address == address &&
      other.phone == phone;

  @override
  int get hashCode =>
      Object.hash(name, currency, onboardingDone, address, phone);
}
