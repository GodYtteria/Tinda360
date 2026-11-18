import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';

final class SaleDraft {
  const SaleDraft({
    required this.method,
    required this.lines,
    this.cashTendered,
    this.customerId,
    this.ewalletReference,
    this.paidNow,
    this.interest,
    this.cashierName,
  });

  final String? cashierName;

  final PaymentMethod method;

  final List<SaleLineDraft> lines;

  final Money? cashTendered;

  final String? customerId;

  final String? ewalletReference;

  final Money? paidNow;

  final Money? interest;
}
