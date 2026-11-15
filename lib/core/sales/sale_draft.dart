import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';

/// A sale ready to be recorded.
final class SaleDraft {
  /// Creates a sale draft.
  const SaleDraft({
    required this.method,
    required this.lines,
    this.cashTendered,
    this.customerId,
    this.ewalletReference,
  });

  /// How the customer pays.
  final PaymentMethod method;

  /// The cart lines; must not be empty.
  final List<SaleLineDraft> lines;

  /// Cash handed over; required for [PaymentMethod.cash].
  final Money? cashTendered;

  /// The customer; required for [PaymentMethod.utang].
  final String? customerId;

  /// Optional e-wallet reference number.
  final String? ewalletReference;
}
