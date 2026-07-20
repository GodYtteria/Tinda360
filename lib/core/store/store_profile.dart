import 'package:tinda360/core/money/currency.dart';

/// The store's own settings. There is exactly one.
final class StoreProfile {
  /// Creates a profile.
  const StoreProfile({
    required this.name,
    required this.currency,
    required this.onboardingDone,
  });

  /// The store name shown in reports; empty until setup.
  final String name;

  /// The currency every amount in the store uses.
  final Currency currency;

  /// Whether first-run setup has been completed.
  final bool onboardingDone;

  @override
  bool operator ==(Object other) =>
      other is StoreProfile &&
      other.name == name &&
      other.currency == currency &&
      other.onboardingDone == onboardingDone;

  @override
  int get hashCode => Object.hash(name, currency, onboardingDone);
}
