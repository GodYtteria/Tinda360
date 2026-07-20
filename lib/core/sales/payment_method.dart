/// How a sale was paid.
///
/// [storageName] values are mirrored by the `sales.method` CHECK constraint.
enum PaymentMethod {
  /// Paid in cash; change may be due.
  cash('cash'),

  /// Paid through an e-wallet; always exact.
  ewallet('ewallet'),

  /// Added to a customer's utang (credit).
  utang('utang');

  const PaymentMethod(this.storageName);

  /// The value stored in the database.
  final String storageName;

  /// Returns the method stored as [storageName], or null if none matches.
  static PaymentMethod? tryParse(String storageName) {
    for (final method in PaymentMethod.values) {
      if (method.storageName == storageName) return method;
    }
    return null;
  }
}
