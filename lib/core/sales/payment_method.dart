enum PaymentMethod {
  cash('cash'),

  ewallet('ewallet'),

  utang('utang');

  new(this.storageName);

  final String storageName;

  static PaymentMethod? tryParse(String storageName) {
    for (final method in PaymentMethod.values) {
      if (method.storageName == storageName) return method;
    }
    return null;
  }
}
