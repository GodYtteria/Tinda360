import 'package:tinda360/core/money/money.dart';
import 'package:tinda360/core/sales/payment_method.dart';
import 'package:tinda360/core/sales/sale_draft.dart';
import 'package:tinda360/core/sales/sale_line_draft.dart';

Money? cashShortfallOf({
  required PaymentMethod method,
  required Money total,
  required Money? cashReceived,
}) {
  if (method != PaymentMethod.cash || cashReceived == null) return null;
  if (!cashReceived.isPositive || !(cashReceived < total)) return null;
  return total - cashReceived;
}

bool canRecordCashShortfall({
  required Money? shortfall,
  required String? customerId,
}) => shortfall != null && customerId != null;

SaleDraft buildCashShortfallDraft({
  required List<SaleLineDraft> lines,
  required Money cashReceived,
  required String customerId,
  Money? interest,
  String? cashierName,
}) => SaleDraft(
  method: PaymentMethod.utang,
  lines: lines,
  customerId: customerId,
  paidNow: cashReceived,
  interest: interest,
  cashierName: cashierName,
);

bool isNearOrOverCreditLimit({
  required Money balance,
  required Money? creditLimit,
  required Money additionalUtang,
}) {
  final projectedBalance = balance + additionalUtang;
  if (!projectedBalance.isPositive || creditLimit == null) return false;
  return projectedBalance.minorUnits * 100 >= creditLimit.minorUnits * 80;
}
